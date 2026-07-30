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

  /// Cloud control plane URL (navidrome-cloud). Kept as [backendUrl] for prefs key stability.
  final String backendUrl;
  final String backendApiKey;

  /// NAS agent URL (import/delete). Defaults to same-host :8504 when empty.
  final String nasAgentUrl;
  final String nasAgentKey;

  const ServerConfig({
    required this.serverId,
    required this.url,
    required this.username,
    required this.password,
    required this.backendUrl,
    required this.backendApiKey,
    this.nasAgentUrl = '',
    this.nasAgentKey = '',
  });

  bool get isConfigured => url.isNotEmpty && username.isNotEmpty;
  String get cloudApiUrl => backendUrl;
  String get cloudApiKey => backendApiKey;
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
String nasAgentUrlPreferenceKey(String serverId) =>
    'nas_agent_url_${normalizeServerId(serverId)}';
String nasAgentKeyPreferenceKey(String serverId) =>
    'nas_agent_key_${normalizeServerId(serverId)}';
String _serverPasswordKey(String serverId) =>
    'server_pw_${normalizeServerId(serverId)}';
String _serverBackendApiKey(String serverId) =>
    'server_backend_api_key_${normalizeServerId(serverId)}';
String _serverNasAgentKey(String serverId) =>
    'server_nas_agent_key_${normalizeServerId(serverId)}';

/// Infer NAS agent URL from Navidrome host (production LAN port 8504).
String inferBackendUrl(String serverUrl, {int port = 8504}) {
  final uri = Uri.tryParse(serverUrl);
  if (uri == null || uri.host.isEmpty) return '';
  return Uri(
    scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
    host: uri.host,
    port: port,
  ).toString();
}

/// Alias kept for ADR-0004 naming.
String inferNasAgentUrl(String serverUrl, {int port = 8504}) =>
    inferBackendUrl(serverUrl, port: port);

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
      await _safeSecureDelete(_serverBackendApiKey(id));
      await prefs.remove(backendApiKeyPreferenceKey(id));
      if (map.remove('backendApiKey') != null) dirty = true;
      if (map.remove('cloudApiKey') != null) dirty = true;
      final nasAgentKey = map['nasAgentKey'] as String?;
      if (nasAgentKey != null && nasAgentKey.isNotEmpty) {
        if (await _safeSecureWrite(_serverNasAgentKey(id), nasAgentKey)) {
          map.remove('nasAgentKey');
          dirty = true;
        }
      }
    }
    if (dirty) await prefs.setString('servers_list', jsonEncode(list));
  } catch (e) {
    debugPrint('Failed to migrate server secrets: $e');
  }
}

Future<void> migrateActiveBackendConfiguration(
  SharedPreferences prefs, {
  required String serverId,
  required String serverUrl,
  required String serverPassword,
}) async {
  if (serverUrl.isNotEmpty) {
    final nasUrlKey = nasAgentUrlPreferenceKey(serverId);
    if ((prefs.getString(nasUrlKey) ?? '').isEmpty) {
      final inferredNas = inferNasAgentUrl(serverUrl);
      if (inferredNas.isNotEmpty) {
        await prefs.setString(nasUrlKey, inferredNas);
      }
    }
  }

  // Shared Cloud API keys are server-side only. Remove all client remnants.
  await _safeSecureDelete(_serverBackendApiKey(serverId));
  await prefs.remove(backendApiKeyPreferenceKey(serverId));
  await prefs.setBool(backendMigrationPreferenceKey(serverId), true);
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

final cachedNasAgentKeyProvider =
    NotifierProvider<CachedNasAgentKeyNotifier, String>(
      CachedNasAgentKeyNotifier.new,
    );

class CachedNasAgentKeyNotifier extends Notifier<String> {
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
      nasAgentUrl: prefs.getString(nasAgentUrlPreferenceKey(serverId)) ?? '',
      nasAgentKey: ref.watch(cachedNasAgentKeyProvider),
    );
  }

  Future<void> save({
    String? serverId,
    required String url,
    required String username,
    required String password,
    String? backendUrl,
    String? backendApiKey,
    String? nasAgentUrl,
    String? nasAgentKey,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final id = normalizeServerId(serverId ?? state.serverId);
    // Cloud URL is explicit; empty means "not configured".
    final resolvedBackendUrl = (backendUrl ?? state.backendUrl).trim();
    const resolvedBackendApiKey = '';
    final resolvedNasAgentUrl =
        (nasAgentUrl ?? state.nasAgentUrl).trim().isEmpty
        ? inferNasAgentUrl(url)
        : (nasAgentUrl ?? state.nasAgentUrl).trim();
    final resolvedNasAgentKey = nasAgentKey ?? state.nasAgentKey;

    await prefs.setString(activeServerIdPreferenceKey, id);
    await prefs.setString('server_url', url);
    await prefs.setString('server_username', username);
    await prefs.setString(backendUrlPreferenceKey(id), resolvedBackendUrl);
    await prefs.setString(nasAgentUrlPreferenceKey(id), resolvedNasAgentUrl);
    await prefs.setBool(backendMigrationPreferenceKey(id), true);

    if (await _safeSecureWrite('server_password', password)) {
      await prefs.remove('server_password');
    } else {
      await prefs.setString('server_password', password);
    }
    await _safeSecureDelete(_serverBackendApiKey(id));
    await prefs.remove(backendApiKeyPreferenceKey(id));

    ref.read(cachedPasswordProvider.notifier).set(password);
    ref.read(cachedBackendApiKeyProvider.notifier).set('');
    if (await _safeSecureWrite(_serverNasAgentKey(id), resolvedNasAgentKey)) {
      await prefs.remove(nasAgentKeyPreferenceKey(id));
    } else {
      await prefs.setString(nasAgentKeyPreferenceKey(id), resolvedNasAgentKey);
    }
    ref.read(cachedNasAgentKeyProvider.notifier).set(resolvedNasAgentKey);
    state = ServerConfig(
      serverId: id,
      url: url,
      username: username,
      password: password,
      backendUrl: resolvedBackendUrl,
      backendApiKey: resolvedBackendApiKey,
      nasAgentUrl: resolvedNasAgentUrl,
      nasAgentKey: resolvedNasAgentKey,
    );
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final id = state.serverId;
    await prefs.remove('server_url');
    await prefs.remove('server_username');
    await prefs.remove(backendUrlPreferenceKey(id));
    await prefs.remove(nasAgentUrlPreferenceKey(id));
    await _safeSecureDelete('server_password');
    await _safeSecureDelete(_serverBackendApiKey(id));
    await _safeSecureDelete(_serverNasAgentKey(id));
    await prefs.remove('server_password');
    await prefs.remove(backendApiKeyPreferenceKey(id));
    await prefs.remove(nasAgentKeyPreferenceKey(id));
    await ref.read(serversListProvider.notifier).clearSecrets(id);
    ref.read(cachedPasswordProvider.notifier).set('');
    ref.read(cachedBackendApiKeyProvider.notifier).set('');
    ref.read(cachedNasAgentKeyProvider.notifier).set('');
    state = ServerConfig(
      serverId: id,
      url: '',
      username: '',
      password: '',
      backendUrl: '',
      backendApiKey: '',
      nasAgentUrl: '',
      nasAgentKey: '',
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

Future<String> preloadServerNasAgentKey(
  SharedPreferences prefs,
  String serverId,
) async =>
    await _safeSecureRead(_serverNasAgentKey(serverId)) ??
    prefs.getString(nasAgentKeyPreferenceKey(serverId)) ??
    '';

Future<bool> saveServerNasAgentKey(String serverId, String apiKey) =>
    _safeSecureWrite(_serverNasAgentKey(serverId), apiKey);

Future<void> deleteServerNasAgentKey(String serverId) =>
    _safeSecureDelete(_serverNasAgentKey(serverId));

class ServerEntry {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final String backendUrl;
  final String backendApiKey;
  final String nasAgentUrl;
  final String nasAgentKey;
  final bool isActive;

  const ServerEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.backendUrl = '',
    this.backendApiKey = '',
    this.nasAgentUrl = '',
    this.nasAgentKey = '',
    this.isActive = false,
  });

  ServerEntry copyWith({
    String? name,
    String? url,
    String? username,
    String? password,
    String? backendUrl,
    String? backendApiKey,
    String? nasAgentUrl,
    String? nasAgentKey,
    bool? isActive,
  }) => ServerEntry(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    username: username ?? this.username,
    password: password ?? this.password,
    backendUrl: backendUrl ?? this.backendUrl,
    backendApiKey: backendApiKey ?? this.backendApiKey,
    nasAgentUrl: nasAgentUrl ?? this.nasAgentUrl,
    nasAgentKey: nasAgentKey ?? this.nasAgentKey,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'backendUrl': backendUrl,
    'nasAgentUrl': nasAgentUrl,
    'isActive': isActive,
    if (!_secureStorageAvailable && password.isNotEmpty) 'password': password,
    if (!_secureStorageAvailable && nasAgentKey.isNotEmpty)
      'nasAgentKey': nasAgentKey,
  };

  factory ServerEntry.fromJson(Map<String, dynamic> json) => ServerEntry(
    id: normalizeServerId(json['id'] as String?),
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    backendUrl:
        json['backendUrl'] as String? ?? json['cloudApiUrl'] as String? ?? '',
    backendApiKey: '',
    nasAgentUrl: json['nasAgentUrl'] as String? ?? '',
    nasAgentKey: json['nasAgentKey'] as String? ?? '',
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
        backendApiKey: '',
        nasAgentUrl: prefs.getString(nasAgentUrlPreferenceKey(id)) ?? '',
        nasAgentKey: ref.read(cachedNasAgentKeyProvider),
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
      await deleteServerBackendApiKey(server.id);
      await prefs.remove(backendApiKeyPreferenceKey(server.id));
      if (server.nasAgentKey.isNotEmpty &&
          !await saveServerNasAgentKey(server.id, server.nasAgentKey)) {
        _secureStorageAvailable = false;
      }
      if (server.nasAgentUrl.isNotEmpty) {
        await prefs.setString(
          nasAgentUrlPreferenceKey(server.id),
          server.nasAgentUrl,
        );
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
    String nasAgentUrl = '',
    String nasAgentKey = '',
  }) => _mutate(() async {
    final entry = ServerEntry(
      id: _nextServerId(),
      name: name,
      url: url,
      username: username,
      password: password,
      backendUrl: backendUrl.trim(),
      backendApiKey: '',
      nasAgentUrl: nasAgentUrl.trim().isEmpty
          ? inferNasAgentUrl(url)
          : nasAgentUrl.trim(),
      nasAgentKey: nasAgentKey,
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
    String? nasAgentUrl,
    String? nasAgentKey,
  }) => _mutate(() async {
    final updated = state.map((server) {
      if (server.id != id) return server;
      final nextUrl = url ?? server.url;
      return server.copyWith(
        name: name,
        url: nextUrl,
        username: username,
        password: password,
        backendUrl: backendUrl,
        backendApiKey: '',
        nasAgentUrl: nasAgentUrl?.trim().isEmpty == true
            ? inferNasAgentUrl(nextUrl)
            : nasAgentUrl,
        nasAgentKey: nasAgentKey,
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
            backendApiKey: '',
            nasAgentUrl: active.nasAgentUrl,
            nasAgentKey: active.nasAgentKey,
          );
    }
  });

  Future<void> removeServer(String id) => _mutate(() async {
    final target = state.firstWhere((server) => server.id == id);
    if (target.isActive) return;
    await deleteServerEntryPassword(id);
    await deleteServerBackendApiKey(id);
    await deleteServerNasAgentKey(id);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(backendUrlPreferenceKey(id));
    await prefs.remove(backendApiKeyPreferenceKey(id));
    await prefs.remove(nasAgentUrlPreferenceKey(id));
    await prefs.remove(nasAgentKeyPreferenceKey(id));
    await prefs.remove(backendMigrationPreferenceKey(id));
    await _persist(state.where((s) => s.id != id).toList());
  });

  Future<void> clearSecrets(String id) => _mutate(() async {
    await deleteServerEntryPassword(id);
    await deleteServerBackendApiKey(id);
    await deleteServerNasAgentKey(id);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(backendApiKeyPreferenceKey(id));
    await prefs.remove(nasAgentKeyPreferenceKey(id));
    final updated = state
        .map(
          (server) => server.id == id
              ? server.copyWith(
                  password: '',
                  backendApiKey: '',
                  nasAgentKey: '',
                )
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
    var nasAgentKey = server.nasAgentKey;
    if (nasAgentKey.isEmpty) {
      nasAgentKey = await preloadServerNasAgentKey(prefs, id);
    }
    var nasAgentUrl = server.nasAgentUrl;
    if (nasAgentUrl.isEmpty) {
      nasAgentUrl = prefs.getString(nasAgentUrlPreferenceKey(id)) ?? '';
    }
    if (nasAgentUrl.isEmpty) nasAgentUrl = inferNasAgentUrl(server.url);

    server = server.copyWith(
      password: password,
      backendApiKey: '',
      backendUrl: server.backendUrl,
      nasAgentUrl: nasAgentUrl,
      nasAgentKey: nasAgentKey,
    );
    await ref
        .read(serverConfigProvider.notifier)
        .save(
          serverId: id,
          url: server.url,
          username: server.username,
          password: password,
          backendUrl: server.backendUrl,
          backendApiKey: '',
          nasAgentUrl: nasAgentUrl,
          nasAgentKey: nasAgentKey,
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
      const backendApiKey = '';
      var nasAgentUrl = server.nasAgentUrl;
      var nasAgentKey = server.nasAgentKey;
      if (backendUrl.isEmpty) {
        backendUrl = prefs.getString(backendUrlPreferenceKey(server.id)) ?? '';
      }
      if (nasAgentUrl.isEmpty) {
        nasAgentUrl =
            prefs.getString(nasAgentUrlPreferenceKey(server.id)) ?? '';
      }
      if (nasAgentUrl.isEmpty) nasAgentUrl = inferNasAgentUrl(server.url);
      if (nasAgentKey.isEmpty) {
        nasAgentKey = await preloadServerNasAgentKey(prefs, server.id);
      }
      loaded.add(
        server.copyWith(
          password: password,
          backendUrl: backendUrl,
          backendApiKey: backendApiKey,
          nasAgentUrl: nasAgentUrl,
          nasAgentKey: nasAgentKey,
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
