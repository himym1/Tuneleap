import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/l10n/localization_utils.dart';

import 'server_scope.dart';

class ServerConfig {
  final String serverId;
  final String url;
  final String username;
  final String password;
  final String backendUrl;
  final String backendApiKey;

  const ServerConfig({
    required this.serverId,
    required this.url,
    required this.username,
    required this.password,
    required this.backendUrl,
    required this.backendApiKey,
  });

  bool get isConfigured => url.isNotEmpty && username.isNotEmpty;
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

const _secureStorage = FlutterSecureStorage();
bool _secureStorageAvailable = true;

String backendUrlPreferenceKey(String serverId) =>
    'backend_url_${normalizeServerId(serverId)}';
String backendApiKeyPreferenceKey(String serverId) =>
    'backend_api_key_${normalizeServerId(serverId)}';
String backendMigrationPreferenceKey(String serverId) =>
    'backend_config_migrated_${normalizeServerId(serverId)}';
String _serverPasswordKey(String serverId) =>
    'server_pw_${normalizeServerId(serverId)}';
String _serverBackendApiKey(String serverId) =>
    'server_backend_api_key_${normalizeServerId(serverId)}';

String inferBackendUrl(String serverUrl, {int port = 8503}) {
  final uri = Uri.tryParse(serverUrl);
  if (uri == null || uri.host.isEmpty) return '';
  return Uri(
    scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
    host: uri.host,
    port: port,
  ).toString();
}

Future<bool> _safeSecureWrite(String key, String value) async {
  if (!_secureStorageAvailable) return false;
  try {
    await _secureStorage.write(key: key, value: value);
    return true;
  } on Exception {
    _secureStorageAvailable = false;
    return false;
  }
}

Future<String?> _safeSecureRead(String key) async {
  if (!_secureStorageAvailable) return null;
  try {
    return await _secureStorage.read(key: key);
  } on Exception {
    _secureStorageAvailable = false;
    return null;
  }
}

Future<void> _safeSecureDelete(String key) async {
  if (!_secureStorageAvailable) return;
  try {
    await _secureStorage.delete(key: key);
  } on Exception {
    _secureStorageAvailable = false;
  }
}

Future<void> migratePasswordsToSecureStorage(SharedPreferences prefs) async {
  final legacyPwd = prefs.getString('server_password');
  if (legacyPwd != null && legacyPwd.isNotEmpty) {
    if (await _safeSecureWrite('server_password', legacyPwd)) {
      await prefs.remove('server_password');
    }
  }

  final json = prefs.getString('servers_list');
  if (json == null) return;
  try {
    final list = jsonDecode(json) as List<dynamic>;
    var dirty = false;
    for (final value in list) {
      final map = value as Map<String, dynamic>;
      final id = normalizeServerId(map['id'] as String?);
      final password = map['password'] as String?;
      if (password != null && password.isNotEmpty) {
        if (await _safeSecureWrite(_serverPasswordKey(id), password)) {
          map.remove('password');
          dirty = true;
        }
      }
      final backendApiKey = map['backendApiKey'] as String?;
      if (backendApiKey != null && backendApiKey.isNotEmpty) {
        if (await _safeSecureWrite(_serverBackendApiKey(id), backendApiKey)) {
          map.remove('backendApiKey');
          dirty = true;
        }
      }
    }
    if (dirty) await prefs.setString('servers_list', jsonEncode(list));
  } catch (e) {
    debugPrint('Failed to migrate server secrets: $e');
  }
}

String _serverListBackendApiKey(SharedPreferences prefs, String serverId) {
  final json = prefs.getString('servers_list');
  if (json == null) return '';
  try {
    final servers = jsonDecode(json) as List<dynamic>;
    for (final value in servers) {
      final server = value as Map<String, dynamic>;
      if (normalizeServerId(server['id'] as String?) ==
          normalizeServerId(serverId)) {
        return server['backendApiKey'] as String? ?? '';
      }
    }
  } catch (_) {}
  return '';
}

Future<void> migrateActiveBackendConfiguration(
  SharedPreferences prefs, {
  required String serverId,
  required String serverUrl,
  required String serverPassword,
}) async {
  if (serverUrl.isEmpty) return;
  final backendUrlKey = backendUrlPreferenceKey(serverId);
  if ((prefs.getString(backendUrlKey) ?? '').isEmpty) {
    final inferred = inferBackendUrl(serverUrl);
    if (inferred.isNotEmpty) await prefs.setString(backendUrlKey, inferred);
  }

  final migrationKey = backendMigrationPreferenceKey(serverId);
  if (prefs.getBool(migrationKey) == true) return;
  final secureKey = _serverBackendApiKey(serverId);
  final existing =
      await _safeSecureRead(secureKey) ??
      prefs.getString(backendApiKeyPreferenceKey(serverId)) ??
      _serverListBackendApiKey(prefs, serverId);
  if (existing.isNotEmpty) {
    if (!await _safeSecureWrite(secureKey, existing)) {
      await prefs.setString(backendApiKeyPreferenceKey(serverId), existing);
    }
    await prefs.setBool(migrationKey, true);
    return;
  }
  if (serverPassword.isEmpty) return;

  if (!await _safeSecureWrite(secureKey, serverPassword)) {
    await prefs.setString(backendApiKeyPreferenceKey(serverId), serverPassword);
  }
  await prefs.setBool(migrationKey, true);
}

final cachedPasswordProvider = NotifierProvider<CachedPasswordNotifier, String>(
  CachedPasswordNotifier.new,
);

class CachedPasswordNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String password) => state = password;
}

final cachedBackendApiKeyProvider =
    NotifierProvider<CachedBackendApiKeyNotifier, String>(
      CachedBackendApiKeyNotifier.new,
    );

class CachedBackendApiKeyNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String apiKey) => state = apiKey;
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig>(
      ServerConfigNotifier.new,
    );

class ServerConfigNotifier extends Notifier<ServerConfig> {
  @override
  ServerConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final serverId = resolveActiveServerId(prefs);
    return ServerConfig(
      serverId: serverId,
      url: prefs.getString('server_url') ?? '',
      username: prefs.getString('server_username') ?? '',
      password: ref.watch(cachedPasswordProvider),
      backendUrl: prefs.getString(backendUrlPreferenceKey(serverId)) ?? '',
      backendApiKey: ref.watch(cachedBackendApiKeyProvider),
    );
  }

  Future<void> save({
    String? serverId,
    required String url,
    required String username,
    required String password,
    String? backendUrl,
    String? backendApiKey,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final id = normalizeServerId(serverId ?? state.serverId);
    final resolvedBackendUrl = (backendUrl ?? '').trim().isEmpty
        ? inferBackendUrl(url)
        : backendUrl!.trim();
    final resolvedBackendApiKey = backendApiKey ?? state.backendApiKey;

    await prefs.setString(activeServerIdPreferenceKey, id);
    await prefs.setString('server_url', url);
    await prefs.setString('server_username', username);
    await prefs.setString(backendUrlPreferenceKey(id), resolvedBackendUrl);
    await prefs.setBool(backendMigrationPreferenceKey(id), true);

    if (await _safeSecureWrite('server_password', password)) {
      await prefs.remove('server_password');
    } else {
      await prefs.setString('server_password', password);
    }
    if (await _safeSecureWrite(
      _serverBackendApiKey(id),
      resolvedBackendApiKey,
    )) {
      await prefs.remove(backendApiKeyPreferenceKey(id));
    } else {
      await prefs.setString(
        backendApiKeyPreferenceKey(id),
        resolvedBackendApiKey,
      );
    }

    ref.read(cachedPasswordProvider.notifier).set(password);
    ref.read(cachedBackendApiKeyProvider.notifier).set(resolvedBackendApiKey);
    state = ServerConfig(
      serverId: id,
      url: url,
      username: username,
      password: password,
      backendUrl: resolvedBackendUrl,
      backendApiKey: resolvedBackendApiKey,
    );
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final id = state.serverId;
    await prefs.remove('server_url');
    await prefs.remove('server_username');
    await prefs.remove(backendUrlPreferenceKey(id));
    await _safeSecureDelete('server_password');
    await _safeSecureDelete(_serverBackendApiKey(id));
    await prefs.remove('server_password');
    await prefs.remove(backendApiKeyPreferenceKey(id));
    await ref.read(serversListProvider.notifier).clearSecrets(id);
    ref.read(cachedPasswordProvider.notifier).set('');
    ref.read(cachedBackendApiKeyProvider.notifier).set('');
    state = ServerConfig(
      serverId: id,
      url: '',
      username: '',
      password: '',
      backendUrl: '',
      backendApiKey: '',
    );
  }
}

Future<String> preloadServerPassword() async =>
    await _safeSecureRead('server_password') ?? '';

Future<String> preloadServerEntryPassword(String serverId) async =>
    await _safeSecureRead(_serverPasswordKey(serverId)) ?? '';

Future<bool> saveServerEntryPassword(String serverId, String password) =>
    _safeSecureWrite(_serverPasswordKey(serverId), password);

Future<void> deleteServerEntryPassword(String serverId) =>
    _safeSecureDelete(_serverPasswordKey(serverId));

Future<String> preloadServerBackendApiKey(
  SharedPreferences prefs,
  String serverId,
) async =>
    await _safeSecureRead(_serverBackendApiKey(serverId)) ??
    prefs.getString(backendApiKeyPreferenceKey(serverId)) ??
    '';

Future<bool> saveServerBackendApiKey(String serverId, String apiKey) =>
    _safeSecureWrite(_serverBackendApiKey(serverId), apiKey);

Future<void> deleteServerBackendApiKey(String serverId) =>
    _safeSecureDelete(_serverBackendApiKey(serverId));

class ServerEntry {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final String backendUrl;
  final String backendApiKey;
  final bool isActive;

  const ServerEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.backendUrl = '',
    this.backendApiKey = '',
    this.isActive = false,
  });

  ServerEntry copyWith({
    String? name,
    String? url,
    String? username,
    String? password,
    String? backendUrl,
    String? backendApiKey,
    bool? isActive,
  }) => ServerEntry(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    username: username ?? this.username,
    password: password ?? this.password,
    backendUrl: backendUrl ?? this.backendUrl,
    backendApiKey: backendApiKey ?? this.backendApiKey,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'backendUrl': backendUrl,
    'isActive': isActive,
    if (!_secureStorageAvailable && password.isNotEmpty) 'password': password,
    if (!_secureStorageAvailable && backendApiKey.isNotEmpty)
      'backendApiKey': backendApiKey,
  };

  factory ServerEntry.fromJson(Map<String, dynamic> json) => ServerEntry(
    id: normalizeServerId(json['id'] as String?),
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    backendUrl: json['backendUrl'] as String? ?? '',
    backendApiKey: json['backendApiKey'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? false,
  );
}

final serversListProvider =
    NotifierProvider<ServersListNotifier, List<ServerEntry>>(
      ServersListNotifier.new,
    );

class ServersListNotifier extends Notifier<List<ServerEntry>> {
  static const _key = 'servers_list';
  Future<void> _mutationTail = Future.value();

  @override
  List<ServerEntry> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        return list
            .map((e) => ServerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to parse servers list: $e');
      }
    }

    final url = prefs.getString('server_url') ?? '';
    if (url.isEmpty) return [];
    final id = resolveActiveServerId(prefs);
    return [
      ServerEntry(
        id: id,
        name: systemLocalizations().defaultServerName,
        url: url,
        username: prefs.getString('server_username') ?? '',
        password: ref.read(cachedPasswordProvider),
        backendUrl: prefs.getString(backendUrlPreferenceKey(id)) ?? '',
        backendApiKey: ref.read(cachedBackendApiKeyProvider),
        isActive: true,
      ),
    ];
  }

  Future<void> _mutate(Future<void> Function() action) {
    final result = _mutationTail.then((_) => action());
    _mutationTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _persist(List<ServerEntry> servers) async {
    final prefs = ref.read(sharedPreferencesProvider);
    for (final server in servers) {
      if (server.password.isNotEmpty &&
          !await saveServerEntryPassword(server.id, server.password)) {
        _secureStorageAvailable = false;
      }
      if (server.backendApiKey.isNotEmpty &&
          !await saveServerBackendApiKey(server.id, server.backendApiKey)) {
        _secureStorageAvailable = false;
      }
      await prefs.setBool(backendMigrationPreferenceKey(server.id), true);
    }
    await prefs.setString(
      _key,
      jsonEncode(servers.map((s) => s.toJson()).toList()),
    );
    state = servers;
  }

  Future<void> addServer({
    required String name,
    required String url,
    required String username,
    required String password,
    required String backendUrl,
    required String backendApiKey,
  }) => _mutate(() async {
    final entry = ServerEntry(
      id: _nextServerId(),
      name: name,
      url: url,
      username: username,
      password: password,
      backendUrl: backendUrl.trim().isEmpty ? inferBackendUrl(url) : backendUrl,
      backendApiKey: backendApiKey,
    );
    await _persist([...state, entry]);
  });

  Future<void> updateServer(
    String id, {
    String? name,
    String? url,
    String? username,
    String? password,
    String? backendUrl,
    String? backendApiKey,
  }) => _mutate(() async {
    final updated = state.map((server) {
      if (server.id != id) return server;
      final nextUrl = url ?? server.url;
      return server.copyWith(
        name: name,
        url: nextUrl,
        username: username,
        password: password,
        backendUrl: backendUrl?.trim().isEmpty == true
            ? inferBackendUrl(nextUrl)
            : backendUrl,
        backendApiKey: backendApiKey,
      );
    }).toList();
    await _persist(updated);
    final active = updated.firstWhere((server) => server.id == id);
    if (active.isActive) {
      await ref
          .read(serverConfigProvider.notifier)
          .save(
            serverId: active.id,
            url: active.url,
            username: active.username,
            password: active.password,
            backendUrl: active.backendUrl,
            backendApiKey: active.backendApiKey,
          );
    }
  });

  Future<void> removeServer(String id) => _mutate(() async {
    final target = state.firstWhere((server) => server.id == id);
    if (target.isActive) return;
    await deleteServerEntryPassword(id);
    await deleteServerBackendApiKey(id);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(backendUrlPreferenceKey(id));
    await prefs.remove(backendApiKeyPreferenceKey(id));
    await prefs.remove(backendMigrationPreferenceKey(id));
    await _persist(state.where((s) => s.id != id).toList());
  });

  Future<void> clearSecrets(String id) => _mutate(() async {
    await deleteServerEntryPassword(id);
    await deleteServerBackendApiKey(id);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(backendApiKeyPreferenceKey(id));
    final updated = state
        .map(
          (server) => server.id == id
              ? server.copyWith(password: '', backendApiKey: '')
              : server,
        )
        .toList();
    await _persist(updated);
  });

  Future<void> setActive(String id) => _mutate(() async {
    final prefs = ref.read(sharedPreferencesProvider);
    var server = state.firstWhere((s) => s.id == id);
    var password = server.password;
    if (password.isEmpty) password = await preloadServerEntryPassword(id);
    var backendApiKey = server.backendApiKey;
    if (backendApiKey.isEmpty) {
      backendApiKey = await preloadServerBackendApiKey(prefs, id);
    }

    server = server.copyWith(
      password: password,
      backendApiKey: backendApiKey,
      backendUrl: server.backendUrl.isEmpty
          ? inferBackendUrl(server.url)
          : server.backendUrl,
    );
    await ref
        .read(serverConfigProvider.notifier)
        .save(
          serverId: id,
          url: server.url,
          username: server.username,
          password: password,
          backendUrl: server.backendUrl,
          backendApiKey: backendApiKey,
        );
    await _persist(
      state
          .map(
            (s) => s.id == id
                ? server.copyWith(isActive: true)
                : s.copyWith(isActive: false),
          )
          .toList(),
    );
  });

  Future<void> loadPasswords() => _mutate(() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final loaded = <ServerEntry>[];
    for (final server in state) {
      var password = server.password;
      if (password.isEmpty) {
        password = await preloadServerEntryPassword(server.id);
      }
      var backendUrl = server.backendUrl;
      var backendApiKey = server.backendApiKey;
      final legacyEntry = backendUrl.isEmpty;
      if (backendUrl.isEmpty) backendUrl = inferBackendUrl(server.url);
      if (backendApiKey.isEmpty) {
        backendApiKey = await preloadServerBackendApiKey(prefs, server.id);
      }
      if (legacyEntry && backendApiKey.isEmpty && password.isNotEmpty) {
        backendApiKey = password;
      }
      loaded.add(
        server.copyWith(
          password: password,
          backendUrl: backendUrl,
          backendApiKey: backendApiKey,
        ),
      );
    }
    await _persist(loaded);
  });

  String _nextServerId() {
    var id = DateTime.now().microsecondsSinceEpoch.toString();
    while (state.any((server) => server.id == id)) {
      id = '${id}_';
    }
    return id;
  }
}
