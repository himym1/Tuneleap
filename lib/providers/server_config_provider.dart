import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/l10n/localization_utils.dart';

// ============================================================
// 服务器配置
// ============================================================

class ServerConfig {
  final String url;
  final String username;
  final String password;

  const ServerConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  bool get isConfigured => url.isNotEmpty && username.isNotEmpty;
}

/// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// FlutterSecureStorage 单例
const _secureStorage = FlutterSecureStorage();

/// macOS 沙盒环境下 Keychain 可能不可用（需要签名证书），
/// 此时降级到 SharedPreferences 存储密码。
bool _secureStorageAvailable = true;

Future<void> _safeSecureWrite(String key, String value) async {
  if (!_secureStorageAvailable) {
    return; // 降级：密码保留在 SharedPreferences
  }
  try {
    await _secureStorage.write(key: key, value: value);
  } on PlatformException {
    _secureStorageAvailable = false;
  }
}

Future<String?> _safeSecureRead(String key) async {
  if (!_secureStorageAvailable) return null;
  try {
    return await _secureStorage.read(key: key);
  } on PlatformException {
    _secureStorageAvailable = false;
    return null;
  }
}

Future<void> _safeSecureDelete(String key) async {
  if (!_secureStorageAvailable) return;
  try {
    await _secureStorage.delete(key: key);
  } on PlatformException {
    _secureStorageAvailable = false;
  }
}

/// 在 main.dart 中调用，将旧的明文密码迁移到 secure storage
Future<void> migratePasswordsToSecureStorage(SharedPreferences prefs) async {
  // 迁移主服务器密码
  final legacyPwd = prefs.getString('server_password');
  if (legacyPwd != null && legacyPwd.isNotEmpty) {
    await _safeSecureWrite('server_password', legacyPwd);
    if (_secureStorageAvailable) {
      await prefs.remove('server_password');
    }
  }

  // 迁移多服务器列表中的密码
  final json = prefs.getString('servers_list');
  if (json != null) {
    try {
      final list = jsonDecode(json) as List;
      bool dirty = false;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        final pw = map['password'] as String?;
        if (pw != null && pw.isNotEmpty && id.isNotEmpty) {
          await _safeSecureWrite('server_pw_$id', pw);
          if (_secureStorageAvailable) {
            map.remove('password');
            dirty = true;
          }
        }
      }
      if (dirty) {
        await prefs.setString('servers_list', jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Failed to save servers list: $e');
    }
  }
}

/// 同步读取服务器密码（先尝试内存缓存，再降级到 prefs 向后兼容）
///
/// 由于 FlutterSecureStorage 只有 async API，我们在 main.dart 启动阶段
/// 预读密码到 SharedPreferences 的内存标记 `_secure_pw_cache_*` 中。
/// 但更实际的方案是：在 main() 中预读后通过 ProviderScope.overrides 注入。
///
/// 当前方案：使用 StateProvider 承载预读到内存的密码。
/// 内存中的密码缓存 — 在 main.dart 中通过 ProviderScope.overrides 注入
final cachedPasswordProvider = NotifierProvider<CachedPasswordNotifier, String>(
  CachedPasswordNotifier.new,
);

class CachedPasswordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String password) {
    state = password;
  }
}

/// 服务器配置 provider（当前激活服务器）
final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig>(
      ServerConfigNotifier.new,
    );

class ServerConfigNotifier extends Notifier<ServerConfig> {
  @override
  ServerConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final cachedPw = ref.watch(cachedPasswordProvider);
    return ServerConfig(
      url: prefs.getString('server_url') ?? '',
      username: prefs.getString('server_username') ?? '',
      password: cachedPw,
    );
  }

  Future<void> save({
    required String url,
    required String username,
    required String password,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('server_url', url);
    await prefs.setString('server_username', username);
    // 密码存入 secure storage（不可用时保留在 prefs）
    await _safeSecureWrite('server_password', password);
    if (_secureStorageAvailable) {
      await prefs.remove('server_password');
    } else {
      await prefs.setString('server_password', password);
    }
    // 更新内存缓存
    ref.read(cachedPasswordProvider.notifier).set(password);
    state = ServerConfig(url: url, username: username, password: password);
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('server_url');
    await prefs.remove('server_username');
    await _safeSecureDelete('server_password');
    await prefs.remove('server_password');
    ref.read(cachedPasswordProvider.notifier).set('');
    state = const ServerConfig(url: '', username: '', password: '');
  }
}

/// 在 main.dart 中调用，预读密码到内存（ProviderContainer 版）
Future<String> preloadServerPassword() async {
  return await _safeSecureRead('server_password') ?? '';
}

/// 预读指定服务器的密码
Future<String> preloadServerEntryPassword(String serverId) async {
  return await _safeSecureRead('server_pw_$serverId') ?? '';
}

/// 保存服务器条目密码到 secure storage
Future<void> saveServerEntryPassword(String serverId, String password) async {
  await _safeSecureWrite('server_pw_$serverId', password);
}

/// 删除服务器条目密码
Future<void> deleteServerEntryPassword(String serverId) async {
  await _safeSecureDelete('server_pw_$serverId');
}

// ============================================================
// 多服务器列表
// ============================================================

class ServerEntry {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final bool isActive;

  const ServerEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    this.isActive = false,
  });

  ServerEntry copyWith({
    String? name,
    String? url,
    String? username,
    String? password,
    bool? isActive,
  }) {
    return ServerEntry(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'isActive': isActive,
    if (!_secureStorageAvailable && password.isNotEmpty) 'password': password,
  };

  factory ServerEntry.fromJson(Map<String, dynamic> json) => ServerEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? false,
  );
}

final serversListProvider =
    NotifierProvider<ServersListNotifier, List<ServerEntry>>(
      ServersListNotifier.new,
    );

class ServersListNotifier extends Notifier<List<ServerEntry>> {
  static const _key = 'servers_list';

  @override
  List<ServerEntry> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final json = prefs.getString(_key);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        return list
            .map((e) => ServerEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Failed to parse servers list: $e');
      }
    }
    // 从当前激活服务器构建默认列表（向后兼容）
    final url = prefs.getString('server_url') ?? '';
    if (url.isEmpty) return [];
    final strings = systemLocalizations();
    return [
      ServerEntry(
        id: 'default',
        name: strings.defaultServerName,
        url: url,
        username: prefs.getString('server_username') ?? '',
        password: ref.read(cachedPasswordProvider),
        isActive: true,
      ),
    ];
  }

  Future<void> _persist(List<ServerEntry> servers) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _key,
      jsonEncode(servers.map((s) => s.toJson()).toList()),
    );
    // 密码单独存 secure storage
    for (final s in servers) {
      if (s.password.isNotEmpty) {
        await saveServerEntryPassword(s.id, s.password);
      }
    }
    state = servers;
  }

  Future<void> addServer({
    required String name,
    required String url,
    required String username,
    required String password,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = ServerEntry(
      id: id,
      name: name,
      url: url,
      username: username,
      password: password,
    );
    await _persist([...state, entry]);
  }

  Future<void> updateServer(
    String id, {
    String? name,
    String? url,
    String? username,
    String? password,
  }) async {
    final updated = state
        .map(
          (s) => s.id == id
              ? s.copyWith(
                  name: name,
                  url: url,
                  username: username,
                  password: password,
                )
              : s,
        )
        .toList();
    await _persist(updated);
  }

  Future<void> removeServer(String id) async {
    await deleteServerEntryPassword(id);
    await _persist(state.where((s) => s.id != id).toList());
  }

  Future<void> setActive(String id) async {
    // 需要先加载密码
    String password = state.firstWhere((s) => s.id == id).password;
    if (password.isEmpty) {
      password = await preloadServerEntryPassword(id);
    }
    final server = state.firstWhere((s) => s.id == id);
    await ref
        .read(serverConfigProvider.notifier)
        .save(url: server.url, username: server.username, password: password);
    final updated = state.map((s) => s.copyWith(isActive: s.id == id)).toList();
    await _persist(updated);
  }

  /// 加载所有服务器的密码（在 main.dart 启动时调用一次）
  Future<void> loadPasswords() async {
    final loaded = <ServerEntry>[];
    for (final s in state) {
      if (s.password.isEmpty) {
        final pw = await preloadServerEntryPassword(s.id);
        loaded.add(s.copyWith(password: pw));
      } else {
        loaded.add(s);
      }
    }
    state = loaded;
  }
}
