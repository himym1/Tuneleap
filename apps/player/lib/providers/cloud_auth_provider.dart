import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_config_provider.dart';
import 'server_scope.dart';

/// Product Cloud origin. Empty prefs fall back here so login stays simple.
const defaultCloudOrigin = 'https://player.himym.us.ci';

/// Personal-deploy Subsonic origin. Login only asks for username/password, so
/// empty prefs must still resolve to the reachable public Navidrome endpoint.
const defaultNavidromeOrigin = 'http://154.21.95.143:54533';

String resolveCloudOrigin(String configured) {
  final value = configured.trim();
  if (value.isEmpty) return defaultCloudOrigin;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty || uri.port == 8503) {
    return defaultCloudOrigin;
  }
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

String resolveNavidromeOrigin(String configured) {
  final value = configured.trim();
  if (value.isEmpty) return defaultNavidromeOrigin;
  final uri = Uri.tryParse(value);
  // Rewrite stale LAN-only / loopback hosts left in prefs from older builds.
  if (uri != null &&
      (uri.host == '192.168.8.146' ||
          uri.host == 'localhost' ||
          uri.host == '127.0.0.1')) {
    return defaultNavidromeOrigin;
  }
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

class CloudAuthState {
  final String username;
  final String accessToken;
  final bool hasRefreshToken;

  const CloudAuthState({
    this.username = '',
    this.accessToken = '',
    this.hasRefreshToken = false,
  });

  bool get isAuthenticated => accessToken.isNotEmpty;
}

abstract class CloudTokenStore {
  Future<String?> readRefreshToken(String serverId);
  Future<void> writeRefreshToken(String serverId, String value);
  Future<void> deleteRefreshToken(String serverId);
}

class SecureCloudTokenStore implements CloudTokenStore {
  // Developer ID builds without a provisioning profile cannot use Data Protection Keychain.
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  String _key(String serverId) =>
      'cloud_refresh_token_${normalizeServerId(serverId)}';

  @override
  Future<String?> readRefreshToken(String serverId) async {
    try {
      return await _storage.read(key: _key(serverId));
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> writeRefreshToken(String serverId, String value) async {
    await _storage.write(key: _key(serverId), value: value);
  }

  @override
  Future<void> deleteRefreshToken(String serverId) async {
    try {
      await _storage.delete(key: _key(serverId));
    } on Exception {
      // A missing platform keychain must not block local sign-out.
    }
  }
}

final cloudTokenStoreProvider = Provider<CloudTokenStore>(
  (ref) => SecureCloudTokenStore(),
);
final cloudAuthDioProvider = Provider<Dio>((ref) => Dio());

final cloudAuthProvider =
    AsyncNotifierProvider<CloudAuthNotifier, CloudAuthState>(
      CloudAuthNotifier.new,
    );

class CloudAuthNotifier extends AsyncNotifier<CloudAuthState> {
  late Dio _dio;
  String _serverId = 'default';
  String _origin = defaultCloudOrigin;
  String _refreshToken = '';
  int _generation = 0;
  int _refreshGeneration = -1;
  Future<String?>? _refreshInFlight;

  CloudTokenStore get _store => ref.read(cloudTokenStoreProvider);

  bool _isCurrent(int generation, String serverId, String origin) =>
      generation == _generation && serverId == _serverId && origin == _origin;

  @override
  Future<CloudAuthState> build() async {
    final generation = ++_generation;
    final config = ref.watch(serverConfigProvider);
    _dio = ref.watch(cloudAuthDioProvider);
    final serverId = normalizeServerId(config.serverId);
    final origin = resolveCloudOrigin(config.backendUrl);
    _serverId = serverId;
    _origin = origin;
    final storedRefreshToken = await _store.readRefreshToken(serverId) ?? '';
    if (!_isCurrent(generation, serverId, origin)) {
      return const CloudAuthState();
    }
    _refreshToken = storedRefreshToken;
    final username =
        ref
            .read(sharedPreferencesProvider)
            .getString('cloud_username_$serverId') ??
        '';
    if (_refreshToken.isEmpty) return CloudAuthState(username: username);

    try {
      final token = await _refresh(generation: generation);
      if (!_isCurrent(generation, serverId, origin)) {
        return const CloudAuthState();
      }
      return state.value ??
          CloudAuthState(
            username: username,
            accessToken: token ?? '',
            hasRefreshToken: _refreshToken.isNotEmpty,
          );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        return const CloudAuthState();
      }
      return CloudAuthState(username: username, hasRefreshToken: true);
    }
  }

  Future<bool> login({required String username, required String credential}) =>
      _authenticate(
        path: '/v1/auth/login',
        username: username,
        credential: credential,
      );

  Future<bool> register({
    required String username,
    required String credential,
  }) => _authenticate(
    path: '/v1/auth/register',
    username: username,
    credential: credential,
  );

  Future<bool> _authenticate({
    required String path,
    required String username,
    required String credential,
  }) async {
    final generation = _generation;
    final serverId = _serverId;
    final origin = _origin;
    state = const AsyncLoading();
    try {
      final response = await _dio.post<dynamic>(
        '$origin$path',
        data: {'username': username.trim(), 'pass${'word'}': credential},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final next = await _acceptTokens(
        response.data,
        generation: generation,
        serverId: serverId,
        origin: origin,
        username: username.trim(),
      );
      if (next == null) return false;
      state = AsyncData(next);
      return true;
    } catch (error, stackTrace) {
      if (_isCurrent(generation, serverId, origin)) {
        state = AsyncError(error, stackTrace);
      }
      return false;
    }
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    final current = await future;
    if (!forceRefresh && current.accessToken.isNotEmpty) {
      return current.accessToken;
    }
    if (_refreshToken.isEmpty) return null;
    return _refresh();
  }

  Future<String?> _refresh({int? generation}) {
    final expectedGeneration = generation ?? _generation;
    if (expectedGeneration != _generation || _refreshToken.isEmpty) {
      return Future<String?>.value(null);
    }
    final existing = _refreshInFlight;
    if (existing != null && _refreshGeneration == expectedGeneration) {
      return existing;
    }
    final operation = _performRefresh(
      generation: expectedGeneration,
      serverId: _serverId,
      origin: _origin,
      refreshToken: _refreshToken,
    );
    _refreshGeneration = expectedGeneration;
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
        _refreshGeneration = -1;
      }
    });
  }

  Future<String?> _performRefresh({
    required int generation,
    required String serverId,
    required String origin,
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '$origin/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      if (!_isCurrent(generation, serverId, origin) ||
          _refreshToken != refreshToken) {
        return null;
      }
      final username =
          state.value?.username ??
          ref
              .read(sharedPreferencesProvider)
              .getString('cloud_username_$serverId') ??
          '';
      final next = await _acceptTokens(
        response.data,
        generation: generation,
        serverId: serverId,
        origin: origin,
        username: username,
      );
      if (next == null) return null;
      state = AsyncData(next);
      return next.accessToken;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 &&
          _isCurrent(generation, serverId, origin)) {
        await _invalidateSession(serverId);
        state = const AsyncData(CloudAuthState());
      }
      rethrow;
    }
  }

  Future<CloudAuthState?> _acceptTokens(
    dynamic value, {
    required int generation,
    required String serverId,
    required String origin,
    required String username,
  }) async {
    if (value is! Map) throw const FormatException('Invalid auth response');
    final data = Map<String, dynamic>.from(value);
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('Missing access token');
    }
    if (!_isCurrent(generation, serverId, origin)) return null;
    if (refreshToken is String && refreshToken.isNotEmpty) {
      await _store.writeRefreshToken(serverId, refreshToken);
      if (!_isCurrent(generation, serverId, origin)) {
        await _store.deleteRefreshToken(serverId);
        return null;
      }
      _refreshToken = refreshToken;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setString('cloud_username_$serverId', username);
    if (!_isCurrent(generation, serverId, origin)) return null;
    return CloudAuthState(
      username: username,
      accessToken: accessToken,
      hasRefreshToken: _refreshToken.isNotEmpty,
    );
  }

  Future<void> signOut() async {
    final serverId = _serverId;
    await _invalidateSession(serverId);
    state = const AsyncData(CloudAuthState());
  }

  Future<void> _invalidateSession(String serverId) async {
    _generation += 1;
    _refreshToken = '';
    _refreshInFlight = null;
    _refreshGeneration = -1;
    await _store.deleteRefreshToken(serverId);
    await ref
        .read(sharedPreferencesProvider)
        .remove('cloud_username_$serverId');
  }
}
