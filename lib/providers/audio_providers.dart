import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/song_media_resolver.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/player/audio_handler.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/providers/download_provider.dart';
import 'server_config_provider.dart';

// ============================================================
// Subsonic 客户端 & 播放服务
// ============================================================

/// AudioHandler provider — 在 main.dart 中 override
final audioHandlerProvider = Provider<NavidromeAudioHandler>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Subsonic 客户端 provider
final subsonicClientProvider = Provider<SubsonicClient>((ref) {
  final config = ref.watch(serverConfigProvider);
  final client = SubsonicClient();
  if (config.isConfigured) {
    client.configure(
      serverUrl: config.url,
      username: config.username,
      password: config.password,
    );
  }
  return client;
});

/// navidrome-backend 客户端 provider
final backendClientProvider = Provider<BackendClient>((ref) {
  final config = ref.watch(serverConfigProvider);
  final client = BackendClient();
  client.configure(
    cloudBaseUrl: config.backendUrl,
    cloudApiKey: config.backendApiKey,
    nasAgentUrl: config.nasAgentUrl.isNotEmpty
        ? config.nasAgentUrl
        : (config.url.isNotEmpty ? BackendClient.inferBaseUrl(config.url) : ''),
    nasAgentKey: config.nasAgentKey.isNotEmpty
        ? config.nasAgentKey
        : config.backendApiKey,
  );
  return client;
});

final songMediaResolverProvider = Provider<SongMediaResolver>((ref) {
  return SongMediaResolver(
    subsonicClient: ref.watch(subsonicClientProvider),
    backendClient: ref.watch(backendClientProvider),
  );
});

/// 播放服务 provider — 委托 AudioHandler，并同步 client / 音质设置
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final config = ref.watch(serverConfigProvider);
  final client = ref.watch(subsonicClientProvider);
  final backendClient = ref.watch(backendClientProvider);
  final quality = ref.watch(audioQualityProvider);
  final downloads = ref.watch(downloadManagerProvider);

  // 服务器切换时同步 client 到 handler
  handler.updateClients(client, backendClient, serverId: config.serverId);
  // 音质变更时同步 maxBitRate
  handler.setMaxBitRate(quality);
  // 离线回退：查看已下载文件
  handler.setLocalPathLookup((song) {
    final task = downloads.where(
      (t) => t.id == song.storageKey && t.status == DownloadStatus.completed,
    );
    return task.isNotEmpty ? task.first.localPath : null;
  });

  return AudioPlayerService(handler);
});

// ============================================================
// 音质
// ============================================================

final audioQualityProvider = NotifierProvider<AudioQualityNotifier, int>(
  AudioQualityNotifier.new,
);

class AudioQualityNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt('audio_quality') ?? 0;
  }

  Future<void> setQuality(int maxBitRate) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('audio_quality', maxBitRate);
    state = maxBitRate;
  }
}
