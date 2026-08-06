import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'audio_providers.dart';
import 'server_config_provider.dart';

// ============================================================
// 搜索状态管理 - cloud first-success (ADR-0004)
// ============================================================

String searchSongMatchKey(Song song) =>
    '${song.title.trim().toLowerCase()}|${song.artist.trim().toLowerCase()}|${song.album.trim().toLowerCase()}';

class SearchState {
  final List<Song> songs;
  final bool searching;
  final bool loadingMore;
  final bool hasMore;
  final String? provider;
  final String? error;
  final Set<String> localSongKeys;

  const SearchState({
    this.songs = const [],
    this.searching = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.provider,
    this.error,
    this.localSongKeys = const {},
  });

  SearchState copyWith({
    List<Song>? songs,
    bool? searching,
    bool? loadingMore,
    bool? hasMore,
    String? provider,
    String? error,
    Set<String>? localSongKeys,
    bool clearResult = false,
  }) {
    return SearchState(
      songs: clearResult ? const [] : (songs ?? this.songs),
      searching: clearResult ? false : (searching ?? this.searching),
      loadingMore: clearResult ? false : (loadingMore ?? this.loadingMore),
      hasMore: clearResult ? true : (hasMore ?? this.hasMore),
      provider: clearResult ? null : (provider ?? this.provider),
      error: clearResult ? null : error,
      localSongKeys: clearResult
          ? const {}
          : (localSongKeys ?? this.localSongKeys),
    );
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  static const _pageSize = 30;
  CancelToken? _cancelToken;
  String _query = '';
  int _page = 0;

  @override
  SearchState build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    _cancelToken?.cancel();
    _cancelToken = null;
    ref.onDispose(() => _cancelToken?.cancel());
    return const SearchState();
  }

  void clearResult() {
    _cancelToken?.cancel();
    _query = '';
    _page = 0;
    state = state.copyWith(clearResult: true);
  }

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      clearResult();
      return;
    }

    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _query = normalizedQuery;
    _page = 1;
    state = state.copyWith(
      searching: true,
      loadingMore: false,
      hasMore: true,
      error: null,
    );

    try {
      final result = await _fetchPage(
        normalizedQuery,
        page: _page,
        cancelToken: cancelToken,
      );
      final localSongs = await _findLocalSongs(normalizedQuery);
      final localKeys = localSongs.map(searchSongMatchKey).toSet();
      if (!cancelToken.isCancelled && _query == normalizedQuery) {
        state = state.copyWith(
          songs: result,
          searching: false,
          hasMore: result.isNotEmpty,
          provider: result.isEmpty ? null : result.first.onlineSource,
          localSongKeys: localKeys,
          error: null,
        );
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!cancelToken.isCancelled && _query == normalizedQuery) {
        state = state.copyWith(searching: false, error: e.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (_query.isEmpty ||
        state.searching ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    final requestQuery = _query;
    final nextPage = _page + 1;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = state.copyWith(loadingMore: true, error: null);

    try {
      final result = await _fetchPage(
        requestQuery,
        page: nextPage,
        cancelToken: cancelToken,
      );
      if (!cancelToken.isCancelled && _query == requestQuery) {
        final existing = state.songs.map((song) => song.storageKey).toSet();
        final appended = result
            .where((song) => existing.add(song.storageKey))
            .toList();
        _page = nextPage;
        state = state.copyWith(
          songs: [...state.songs, ...appended],
          loadingMore: false,
          // Continue until the backend returns an empty page or no new songs.
          hasMore: result.isNotEmpty && appended.isNotEmpty,
          error: null,
        );
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!cancelToken.isCancelled && _query == requestQuery) {
        state = state.copyWith(loadingMore: false, error: e.toString());
      }
    }
  }

  Future<List<Song>> _fetchPage(
    String query, {
    required int page,
    required CancelToken cancelToken,
  }) {
    final client = ref.read(backendClientProvider);
    return client.searchSongs(
      query,
      count: _pageSize,
      page: page,
      cancelToken: cancelToken,
    );
  }

  Future<List<Song>> _findLocalSongs(String query) async {
    try {
      final result = await ref
          .read(subsonicClientProvider)
          .search3(query, songCount: 100, artistCount: 0, albumCount: 0);
      return result.songs;
    } catch (_) {
      return const [];
    }
  }
}
