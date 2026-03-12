import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/audio_providers.dart';

class AlbumDetailState {
  final Album? album;
  final bool loading;

  const AlbumDetailState({
    this.album,
    this.loading = true,
  });

  AlbumDetailState copyWith({
    Album? album,
    bool? loading,
  }) {
    return AlbumDetailState(
      album: album ?? this.album,
      loading: loading ?? this.loading,
    );
  }
}

class AlbumDetailNotifier extends Notifier<AlbumDetailState> {
  final String albumId;
  AlbumDetailNotifier(this.albumId);

  @override
  AlbumDetailState build() {
    _load();
    return const AlbumDetailState();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final album = await client.getAlbum(albumId);
      state = AlbumDetailState(
        album: album,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false);
    }
  }
}

final albumDetailProvider = NotifierProvider.family<AlbumDetailNotifier,
    AlbumDetailState, String>(AlbumDetailNotifier.new);
