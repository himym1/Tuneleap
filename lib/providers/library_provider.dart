import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'audio_providers.dart';

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

  const LibraryState({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMoreAlbums = true,
    this.hasMoreSongs = true,
  });

  LibraryState copyWith({
    List<Artist>? artists,
    List<Album>? albums,
    List<Song>? songs,
    bool? loading,
    bool? loadingMore,
    bool? hasMoreAlbums,
    bool? hasMoreSongs,
  }) {
    return LibraryState(
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      songs: songs ?? this.songs,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMoreAlbums: hasMoreAlbums ?? this.hasMoreAlbums,
      hasMoreSongs: hasMoreSongs ?? this.hasMoreSongs,
    );
  }
}

final libraryProvider =
    NotifierProvider<LibraryNotifier, LibraryState>(
      LibraryNotifier.new,
    );

class LibraryNotifier extends Notifier<LibraryState> {
  static const _pageSize = 50;

  @override
  LibraryState build() {
    _loadInitialData();
    return const LibraryState();
  }

  Future<void> _loadInitialData() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final results = await Future.wait([
        client.getArtists(),
        client.getAlbumList2(type: 'newest', size: _pageSize, offset: 0),
        client.search3('', songCount: _pageSize, songOffset: 0, artistCount: 0, albumCount: 0).then((r) => r.songs),
      ]);
      final albums = results[1] as List<Album>;
      final songs = results[2] as List<Song>;
      state = state.copyWith(
        artists: results[0] as List<Artist>,
        albums: albums,
        songs: songs,
        hasMoreAlbums: albums.length >= _pageSize,
        hasMoreSongs: songs.length >= _pageSize,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> loadMoreAlbums() async {
    if (state.loadingMore || !state.hasMoreAlbums) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    try {
      final client = ref.read(subsonicClientProvider);
      final more = await client.getAlbumList2(
        type: 'newest',
        size: _pageSize,
        offset: state.albums.length,
      );
      state = state.copyWith(
        albums: [...state.albums, ...more],
        hasMoreAlbums: more.length >= _pageSize,
        loadingMore: false,
      );
    } catch (e) {
      debugPrint('Failed to load more albums: $e');
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> loadMoreSongs() async {
    if (state.loadingMore || !state.hasMoreSongs) {
      return;
    }
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
      final more = result.songs;
      state = state.copyWith(
        songs: [...state.songs, ...more],
        hasMoreSongs: more.length >= _pageSize,
        loadingMore: false,
      );
    } catch (e) {
      debugPrint('Failed to load more songs: $e');
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> playArtist(Artist artist) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getArtist(artist.id);
      if (detail.albums.isNotEmpty) {
        final album = await client.getAlbum(detail.albums.first.id);
        if (album.songs.isNotEmpty) {
          ref.read(audioPlayerServiceProvider).playAll(album.songs);
        }
      }
    } catch (e) {
      debugPrint('Failed to play artist: $e');
    }
  }
}
