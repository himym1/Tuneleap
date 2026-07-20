import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:navidrome_player/utils/request_generation.dart';

class AlbumDetailState {
  final Album? album;
  final bool loading;

  const AlbumDetailState({this.album, this.loading = true});

  AlbumDetailState copyWith({Album? album, bool? loading}) {
    return AlbumDetailState(
      album: album ?? this.album,
      loading: loading ?? this.loading,
    );
  }
}

class AlbumDetailNotifier extends Notifier<AlbumDetailState> {
  final String albumId;
  AlbumDetailNotifier(this.albumId);
  final RequestGeneration _requests = RequestGeneration();

  @override
  AlbumDetailState build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    final request = _requests.begin();
    ref.onDispose(_requests.invalidate);
    _load(request);
    return const AlbumDetailState();
  }

  Future<void> _load(int request) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final album = await client.getAlbum(albumId);
      if (!_requests.isCurrent(request)) return;
      state = AlbumDetailState(album: album, loading: false);
    } catch (e) {
      if (_requests.isCurrent(request)) {
        state = state.copyWith(loading: false);
      }
    }
  }
}

final albumDetailProvider =
    NotifierProvider.family<AlbumDetailNotifier, AlbumDetailState, String>(
      AlbumDetailNotifier.new,
    );
