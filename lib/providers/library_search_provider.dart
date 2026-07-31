import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:navidrome_player/utils/request_generation.dart';

enum LibrarySearchType { albums, artists }

class LibrarySearchState {
  final List<Album>? albums;
  final List<Artist>? artists;
  final String query;
  final String? serverId;

  const LibrarySearchState({
    this.albums,
    this.artists,
    this.query = '',
    this.serverId,
  });
}

final librarySearchProvider =
    NotifierProvider.family<
      LibrarySearchNotifier,
      LibrarySearchState,
      LibrarySearchType
    >(LibrarySearchNotifier.new);

class LibrarySearchNotifier extends Notifier<LibrarySearchState> {
  LibrarySearchNotifier(this.type);

  static const _debounceDuration = Duration(milliseconds: 500);
  final LibrarySearchType type;
  final RequestGeneration _requests = RequestGeneration();
  Timer? _debounce;

  @override
  LibrarySearchState build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    _debounce?.cancel();
    _requests.begin();
    ref.onDispose(() {
      _debounce?.cancel();
      _requests.invalidate();
    });
    return const LibrarySearchState();
  }

  void onQueryChanged(String value, {bool composing = false}) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _requests.begin();
      state = const LibrarySearchState();
      return;
    }
    final request = _requests.begin();
    state = LibrarySearchState(
      albums: state.albums,
      artists: state.artists,
      query: query,
      serverId: state.serverId,
    );
    if (composing) return;
    _debounce = Timer(_debounceDuration, () => _search(query, request));
  }

  Future<void> _search(String query, int request) async {
    if (!_requests.isCurrent(request)) return;
    final serverId = ref.read(serverConfigProvider).serverId;
    try {
      final result = await ref
          .read(subsonicClientProvider)
          .search3(
            query,
            artistCount: type == LibrarySearchType.artists ? 50 : 0,
            albumCount: type == LibrarySearchType.albums ? 50 : 0,
            songCount: 0,
          );
      if (!_requests.isCurrent(request) ||
          ref.read(serverConfigProvider).serverId != serverId) {
        return;
      }
      state = type == LibrarySearchType.albums
          ? LibrarySearchState(
              albums: result.albums,
              query: query,
              serverId: serverId,
            )
          : LibrarySearchState(
              artists: result.artists,
              query: query,
              serverId: serverId,
            );
    } catch (_) {
      if (_requests.isCurrent(request)) {
        state = LibrarySearchState(
          albums: state.albums,
          artists: state.artists,
          query: query,
          serverId: state.serverId,
        );
      }
    }
  }
}
