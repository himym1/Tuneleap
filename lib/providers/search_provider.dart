import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'audio_providers.dart';
import 'server_config_provider.dart';

// ============================================================
// 搜索状态管理 — cloud first-success（ADR-0004）
// ============================================================

class SearchState {
  final List<Song> songs;
  final bool searching;
  final String? provider;
  final String? error;

  const SearchState({
    this.songs = const [],
    this.searching = false,
    this.provider,
    this.error,
  });

  SearchState copyWith({
    List<Song>? songs,
    bool? searching,
    String? provider,
    String? error,
    bool clearResult = false,
  }) {
    return SearchState(
      songs: clearResult ? const [] : (songs ?? this.songs),
      searching: clearResult ? false : (searching ?? this.searching),
      provider: clearResult ? null : (provider ?? this.provider),
      error: clearResult ? null : error,
    );
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

class SearchNotifier extends Notifier<SearchState> {
  CancelToken? _cancelToken;

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
    state = state.copyWith(clearResult: true);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _cancelToken?.cancel();
      state = state.copyWith(clearResult: true);
      return;
    }

    // Cancel previous in-flight search
    _cancelToken?.cancel();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = state.copyWith(searching: true, error: null);
    try {
      final client = ref.read(backendClientProvider);
      // One query → one provider list (cloud first-success). Optional source
      // hint only; do not serial-merge netease+kuwo+joox.
      final result = await client.searchSongs(
        query,
        source: 'netease',
        count: 30,
        page: 1,
        cancelToken: cancelToken,
      );
      if (!cancelToken.isCancelled) {
        state = state.copyWith(
          songs: result,
          searching: false,
          provider: result.isEmpty ? null : result.first.onlineSource,
          error: null,
        );
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!cancelToken.isCancelled) {
        state = state.copyWith(searching: false, error: e.toString());
      }
    }
  }
}
