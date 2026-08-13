import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';

import 'audio_providers.dart';
import 'server_config_provider.dart';
import 'online_source_preferences.dart';

const _searchPageSize = 30;

class SearchState {
  final List<Song> songs;
  final bool searching;
  final bool loadingMore;
  final bool hasMore;
  final String? source;
  final String? error;

  const SearchState({
    this.songs = const [],
    this.searching = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.source,
    this.error,
  });

  SearchState copyWith({
    List<Song>? songs,
    bool? searching,
    bool? loadingMore,
    bool? hasMore,
    String? source,
    String? error,
    bool clearResult = false,
  }) {
    return SearchState(
      songs: clearResult ? const [] : (songs ?? this.songs),
      searching: clearResult ? false : (searching ?? this.searching),
      loadingMore: clearResult ? false : (loadingMore ?? this.loadingMore),
      hasMore: clearResult ? false : (hasMore ?? this.hasMore),
      source: clearResult ? null : (source ?? this.source),
      error: clearResult ? null : error,
    );
  }
}

final searchProvider =
    NotifierProvider.family<SearchNotifier, SearchState, String>(
      SearchNotifier.new,
    );

class SearchNotifier extends Notifier<SearchState> {
  SearchNotifier(this.source);

  final String source;
  String? _provider;
  CancelToken? _cancelToken;
  String _query = '';
  int _page = 0;
  int _generation = 0;

  @override
  SearchState build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    _provider = ref.watch(effectiveOnlineSearchAdapterProvider);
    _cancelToken?.cancel();
    _cancelToken = null;
    _query = '';
    _page = 0;
    _generation++;
    ref.onDispose(() => _cancelToken?.cancel());
    return const SearchState();
  }

  void clearResult() {
    _cancelToken?.cancel();
    _query = '';
    _page = 0;
    _generation++;
    state = state.copyWith(clearResult: true);
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearResult();
      return;
    }

    _query = trimmed;
    _page = 0;
    final generation = ++_generation;
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = const SearchState(searching: true);
    try {
      final result = await ref
          .read(backendClientProvider)
          .searchSongs(
            trimmed,
            source: source,
            provider: _provider,
            count: _searchPageSize,
            page: 1,
            cancelToken: cancelToken,
          );
      if (!cancelToken.isCancelled &&
          _cancelToken == cancelToken &&
          generation == _generation) {
        _page = 1;
        state = SearchState(
          songs: result,
          source: result.isEmpty ? null : result.first.onlineSource,
          hasMore: result.isNotEmpty,
        );
      }
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      if (!cancelToken.isCancelled &&
          _cancelToken == cancelToken &&
          generation == _generation) {
        state = SearchState(error: error.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (_query.isEmpty || !state.hasMore || state.loadingMore) return;

    final existing = state.songs;
    final nextPage = _page + 1;
    final query = _query;
    final generation = _generation;
    state = state.copyWith(loadingMore: true, error: null);
    try {
      final result = await ref
          .read(backendClientProvider)
          .searchSongs(
            query,
            source: source,
            provider: _provider,
            count: _searchPageSize,
            page: nextPage,
          );
      if (generation != _generation || query != _query) return;
      final seen = existing.map((song) => song.storageKey).toSet();
      final appended = result
          .where((song) => seen.add(song.storageKey))
          .toList();
      _page = nextPage;
      state = state.copyWith(
        songs: [...existing, ...appended],
        loadingMore: false,
        hasMore: result.isNotEmpty && appended.isNotEmpty,
        error: null,
      );
    } catch (error) {
      if (generation != _generation || query != _query) return;
      state = state.copyWith(loadingMore: false, error: error.toString());
      rethrow;
    }
  }
}
