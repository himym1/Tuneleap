import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'audio_providers.dart';
import 'server_config_provider.dart';
import 'package:navidrome_player/utils/request_generation.dart';

// ============================================================
// 音乐库页面状态管理
// ============================================================

class LibraryState {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;
  final bool loading;
  final bool loadingMore;
  final bool hasMoreAlbums;
  final bool hasMoreSongs;
  final Object? error;

  const LibraryState({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMoreAlbums = true,
    this.hasMoreSongs = true,
    this.error,
  });

  LibraryState copyWith({
    List<Artist>? artists,
    List<Album>? albums,
    List<Song>? songs,
    bool? loading,
    bool? loadingMore,
    bool? hasMoreAlbums,
    bool? hasMoreSongs,
    Object? error,
    bool clearError = false,
  }) {
    return LibraryState(
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      songs: songs ?? this.songs,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMoreAlbums: hasMoreAlbums ?? this.hasMoreAlbums,
      hasMoreSongs: hasMoreSongs ?? this.hasMoreSongs,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

class LibraryNotifier extends Notifier<LibraryState> {
  static const _pageSize = 50;
  final RequestGeneration _requests = RequestGeneration();
  final RequestGeneration _playbackRequests = RequestGeneration();

  @override
  LibraryState build() {
    ref.watch(serverConfigProvider);
    final request = _requests.begin();
    _playbackRequests.begin();
    ref.onDispose(() {
      _requests.invalidate();
      _playbackRequests.invalidate();
    });
    _loadInitialData(request);
    return const LibraryState();
  }

  Future<void> _loadInitialData(int request) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final results = await Future.wait([
        client.getArtists(),
        client.getAlbumList2(type: 'newest', size: _pageSize, offset: 0),
        client
            .search3(
              '',
              songCount: _pageSize,
              songOffset: 0,
              artistCount: 0,
              albumCount: 0,
            )
            .then((r) => r.songs),
      ]);
      if (!_requests.isCurrent(request)) return;
      final albums = results[1] as List<Album>;
      final songs = results[2] as List<Song>;
      state = state.copyWith(
        artists: results[0] as List<Artist>,
        albums: albums,
        songs: songs,
        hasMoreAlbums: albums.length >= _pageSize,
        hasMoreSongs: songs.length >= _pageSize,
        loading: false,
        clearError: true,
      );
    } catch (e) {
      if (_requests.isCurrent(request)) {
        state = state.copyWith(loading: false, error: e);
      }
    }
  }

  Future<void> loadMoreAlbums() async {
    if (state.loadingMore || !state.hasMoreAlbums) {
      return;
    }
    final request = _requests.current;
    state = state.copyWith(loadingMore: true);
    try {
      final client = ref.read(subsonicClientProvider);
      final more = await client.getAlbumList2(
        type: 'newest',
        size: _pageSize,
        offset: state.albums.length,
      );
      if (!_requests.isCurrent(request)) return;
      state = state.copyWith(
        albums: [...state.albums, ...more],
        hasMoreAlbums: more.length >= _pageSize,
        loadingMore: false,
      );
    } catch (e) {
      if (_requests.isCurrent(request)) {
        debugPrint('Failed to load more albums: ${e.runtimeType}');
        state = state.copyWith(loadingMore: false);
      }
    }
  }

  Future<void> loadMoreSongs() async {
    if (state.loadingMore || !state.hasMoreSongs) {
      return;
    }
    final request = _requests.current;
    state = state.copyWith(loadingMore: true);
    try {
      final client = ref.read(subsonicClientProvider);
      final result = await client.search3(
        '',
        songCount: _pageSize,
        songOffset: state.songs.length,
        artistCount: 0,
        albumCount: 0,
      );
      if (!_requests.isCurrent(request)) return;
      final more = result.songs;
      state = state.copyWith(
        songs: [...state.songs, ...more],
        hasMoreSongs: more.length >= _pageSize,
        loadingMore: false,
      );
    } catch (e) {
      if (_requests.isCurrent(request)) {
        debugPrint('Failed to load more songs: ${e.runtimeType}');
        state = state.copyWith(loadingMore: false);
      }
    }
  }

  /// 刷新所有库数据
  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      hasMoreAlbums: true,
      hasMoreSongs: true,
      clearError: true,
    );
    await _loadInitialData(_requests.begin());
  }

  /// 获取艺术家全部专辑歌曲并开始播放。
  Future<void> playAllAlbums(List<Album> albums) async {
    final request = _playbackRequests.begin();
    final config = ref.read(serverConfigProvider);
    try {
      final client = ref.read(subsonicClientProvider);
      final albumDetails = await Future.wait(
        albums.map((album) => client.getAlbum(album.id)),
      );
      if (!_playbackRequests.isCurrent(request) ||
          !identical(ref.read(serverConfigProvider), config)) {
        return;
      }
      final allSongs = albumDetails.expand((album) => album.songs).toList();
      if (allSongs.isNotEmpty) {
        await ref.read(audioPlayerServiceProvider).playAll(allSongs);
      }
    } catch (e) {
      debugPrint('Failed to play all albums: ${e.runtimeType}');
    }
  }

  Future<void> playArtist(Artist artist) async {
    final request = _playbackRequests.begin();
    final config = ref.read(serverConfigProvider);
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getArtist(artist.id);
      if (!_playbackRequests.isCurrent(request) ||
          !identical(ref.read(serverConfigProvider), config)) {
        return;
      }
      if (detail.albums.isNotEmpty) {
        final album = await client.getAlbum(detail.albums.first.id);
        if (!_playbackRequests.isCurrent(request) ||
            !identical(ref.read(serverConfigProvider), config)) {
          return;
        }
        if (album.songs.isNotEmpty) {
          ref.read(audioPlayerServiceProvider).playAll(album.songs);
        }
      }
    } catch (e) {
      debugPrint('Failed to play artist: ${e.runtimeType}');
    }
  }
}
