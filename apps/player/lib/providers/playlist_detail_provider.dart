import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/playlist_provider.dart';
import 'package:navidrome_player/utils/request_generation.dart';

class PlaylistDetailState {
  const PlaylistDetailState({this.playlist, this.loading = true, this.error});

  final Playlist? playlist;
  final bool loading;
  final String? error;

  PlaylistDetailState copyWith({
    Playlist? playlist,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return PlaylistDetailState(
      playlist: playlist ?? this.playlist,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PlaylistDetailNotifier extends Notifier<PlaylistDetailState> {
  PlaylistDetailNotifier(this.playlistId);

  final String playlistId;
  final RequestGeneration _requests = RequestGeneration();

  @override
  PlaylistDetailState build() {
    // Rebuild when the active Subsonic client changes (server switch).
    ref.watch(subsonicClientProvider);
    final request = _requests.begin();
    ref.onDispose(_requests.invalidate);
    _load(request);
    return const PlaylistDetailState();
  }

  Future<void> refresh() async {
    final request = _requests.begin();
    state = state.copyWith(loading: true, clearError: true);
    await _load(request);
  }

  void setPlaylist(Playlist playlist) {
    state = PlaylistDetailState(playlist: playlist, loading: false);
  }

  Future<void> _load(int request) async {
    try {
      final playlist = await ref
          .read(playlistServiceProvider)
          .getPlaylist(playlistId);
      if (!_requests.isCurrent(request)) return;
      state = PlaylistDetailState(playlist: playlist, loading: false);
    } catch (error) {
      if (!_requests.isCurrent(request)) return;
      state = PlaylistDetailState(
        playlist: state.playlist,
        loading: false,
        error: error.toString(),
      );
    }
  }
}

final playlistDetailProvider =
    NotifierProvider.family<
      PlaylistDetailNotifier,
      PlaylistDetailState,
      String
    >(PlaylistDetailNotifier.new);
