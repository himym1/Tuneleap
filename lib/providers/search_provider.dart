import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'audio_providers.dart';

// ============================================================
// 搜索状态管理 — 仅在线搜索（网易云/酷我/JOOX）
// ============================================================

class SearchState {
  final List<Song> songs;
  final bool searching;

  const SearchState({
    this.songs = const [],
    this.searching = false,
  });

  SearchState copyWith({
    List<Song>? songs,
    bool? searching,
    bool clearResult = false,
  }) {
    return SearchState(
      songs: clearResult ? const [] : (songs ?? this.songs),
      searching: searching ?? this.searching,
    );
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(
      SearchNotifier.new,
    );

class SearchNotifier extends Notifier<SearchState> {
  CancelToken? _cancelToken;

  @override
  SearchState build() => const SearchState();

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

    state = state.copyWith(searching: true);
    try {
      final client = ref.read(backendClientProvider);
      final songs = <Song>[];
      for (final source in ['netease', 'kuwo', 'joox']) {
        if (cancelToken.isCancelled) return;
        try {
          final result = await client.searchSongs(
            query,
            source: source,
            count: 30,
            page: 1,
            cancelToken: cancelToken,
          );
          songs.addAll(result);
        } catch (e) {
          if (e is DioException && e.type == DioExceptionType.cancel) return;
          // Individual source failure doesn't affect others
        }
      }
      if (!cancelToken.isCancelled) {
        state = state.copyWith(songs: songs, searching: false);
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      state = state.copyWith(searching: false);
    }
  }
}
