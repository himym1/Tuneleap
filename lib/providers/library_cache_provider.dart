import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'audio_providers.dart';

// ============================================================
// 音乐库数据缓存层 — 用 Riverpod keepAlive 实现内存缓存
// ============================================================

/// 最新专辑列表（首页 + 专辑页）
final newestAlbumsProvider = FutureProvider.autoDispose<List<Album>>((
  ref,
) async {
  ref.keepAlive(); // 保持缓存直到手动失效
  final client = ref.watch(subsonicClientProvider);
  return await client.getAlbumList2(type: 'newest', size: 50);
});

/// 最近播放专辑（首页）
final recentAlbumsProvider = FutureProvider.autoDispose<List<Album>>((
  ref,
) async {
  ref.keepAlive();
  final client = ref.watch(subsonicClientProvider);
  return await client.getAlbumList2(type: 'recent', size: 20);
});

/// 艺术家列表（艺术家页 + 专辑艺术家页）
final artistsProvider = FutureProvider.autoDispose<List<Artist>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(subsonicClientProvider);
  return await client.getArtists();
});

/// 流派列表（流派页）
final genresProvider = FutureProvider.autoDispose<List<Genre>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(subsonicClientProvider);
  return await client.getGenres();
});

/// 电台列表（电台页）
final radioStationsProvider = FutureProvider.autoDispose<List<RadioStation>>((
  ref,
) async {
  ref.keepAlive();
  final client = ref.watch(subsonicClientProvider);
  return await client.getInternetRadioStations();
});

/// 流派歌曲列表（流派详情页）— family provider 按流派名缓存
final genreSongsProvider = FutureProvider.autoDispose
    .family<List<Song>, String>((ref, genreName) async {
      ref.keepAlive();
      final client = ref.watch(subsonicClientProvider);
      return await client.getSongsByGenre(genreName, size: 100);
    });

/// 艺术家详情（艺术家详情页）— family provider 按艺术家 ID 缓存
final artistDetailProvider = FutureProvider.autoDispose
    .family<ArtistDetail, String>((ref, artistId) async {
      ref.keepAlive();
      final client = ref.watch(subsonicClientProvider);
      return await client.getArtist(artistId);
    });

/// 播放列表列表（播放列表页）
final playlistsProvider = FutureProvider.autoDispose<List<Playlist>>((
  ref,
) async {
  ref.keepAlive();
  final client = ref.watch(subsonicClientProvider);
  return await client.getPlaylists();
});
