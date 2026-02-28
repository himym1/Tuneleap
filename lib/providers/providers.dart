import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/player/audio_player_service.dart';

/// 服务器配置
class ServerConfig {
  final String url;
  final String username;
  final String password;

  const ServerConfig({required this.url, required this.username, required this.password});

  bool get isConfigured => url.isNotEmpty && username.isNotEmpty;
}

/// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// 服务器配置 provider
final serverConfigProvider = NotifierProvider<ServerConfigNotifier, ServerConfig>(
  ServerConfigNotifier.new,
);

class ServerConfigNotifier extends Notifier<ServerConfig> {
  @override
  ServerConfig build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ServerConfig(
      url: prefs.getString('server_url') ?? '',
      username: prefs.getString('server_username') ?? '',
      password: prefs.getString('server_password') ?? '',
    );
  }

  Future<void> save({required String url, required String username, required String password}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('server_url', url);
    await prefs.setString('server_username', username);
    await prefs.setString('server_password', password);
    state = ServerConfig(url: url, username: username, password: password);
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('server_url');
    await prefs.remove('server_username');
    await prefs.remove('server_password');
    state = const ServerConfig(url: '', username: '', password: '');
  }
}

/// Subsonic 客户端 provider
final subsonicClientProvider = Provider<SubsonicClient>((ref) {
  final config = ref.watch(serverConfigProvider);
  final client = SubsonicClient();
  if (config.isConfigured) {
    client.configure(serverUrl: config.url, username: config.username, password: config.password);
  }
  return client;
});

/// 播放服务 provider
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final client = ref.watch(subsonicClientProvider);
  final service = AudioPlayerService(client);
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});
