import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'audio_providers.dart';

// ============================================================
// 搜索状态管理
// ============================================================

enum SearchBackend { local, netease, kuwo, joox }

extension SearchBackendExt on SearchBackend {
  bool get isOnline => this != SearchBackend.local;

  String? get source => switch (this) {
    SearchBackend.local => null,
    SearchBackend.netease => 'netease',
    SearchBackend.kuwo => 'kuwo',
    SearchBackend.joox => 'joox',
  };
}

class SearchState {
  final SearchResult? result;
  final bool searching;
  final int selectedFilter;
  final SearchBackend selectedBackend;

  const SearchState({
    this.result,
    this.searching = false,
    this.selectedFilter = 0,
    this.selectedBackend = SearchBackend.local,
  });

  SearchState copyWith({
    SearchResult? result,
    bool? searching,
    int? selectedFilter,
    SearchBackend? selectedBackend,
    bool clearResult = false,
  }) {
    return SearchState(
      result: clearResult ? null : (result ?? this.result),
      searching: searching ?? this.searching,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedBackend: selectedBackend ?? this.selectedBackend,
    );
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(
      SearchNotifier.new,
    );

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  void setFilter(int index) {
    state = state.copyWith(selectedFilter: index);
  }

  void setBackend(SearchBackend backend) {
    if (state.selectedBackend == backend) return;
    var newFilter = state.selectedFilter;
    if (backend.isOnline && newFilter > 1) {
      newFilter = 0;
    }
    state = state.copyWith(selectedBackend: backend, selectedFilter: newFilter);
  }

  void clearResult() {
    state = state.copyWith(clearResult: true);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(clearResult: true);
      return;
    }
    state = state.copyWith(searching: true);
    try {
      final backend = state.selectedBackend;
      final result = switch (backend) {
        SearchBackend.local => await ref
            .read(subsonicClientProvider)
            .search3(query, artistCount: 20, albumCount: 20, songCount: 30),
        _ => SearchResult(
          songs: await ref
              .read(solaraClientProvider)
              .searchSongs(
                query,
                source: backend.source!,
                count: 30,
                page: 1,
              ),
        ),
      };
      state = state.copyWith(result: result, searching: false);
    } catch (_) {
      state = state.copyWith(searching: false);
    }
  }
}
