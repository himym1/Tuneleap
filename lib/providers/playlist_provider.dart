import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'audio_providers.dart';

final playlistServiceProvider = Provider<PlaylistService>((ref) {
  final client = ref.watch(subsonicClientProvider);
  return PlaylistService(
    client,
    isCurrent: () {
      try {
        return identical(ref.read(subsonicClientProvider), client);
      } catch (_) {
        return false;
      }
    },
  );
});

class StaleServerOperationException implements Exception {
  const StaleServerOperationException();

  @override
  String toString() => 'Server changed during playlist operation';
}

class PlaylistService {
  PlaylistService(this._client, {bool Function()? isCurrent})
    : _isCurrent = isCurrent ?? _alwaysCurrent;

  final SubsonicClient _client;
  final bool Function() _isCurrent;

  static bool _alwaysCurrent() => true;

  void _ensureCurrent() {
    if (!_isCurrent()) throw const StaleServerOperationException();
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    _ensureCurrent();
    final result = await operation();
    _ensureCurrent();
    return result;
  }

  Future<List<Playlist>> getPlaylists() => _guard(_client.getPlaylists);

  Future<Playlist> getPlaylist(String id) {
    return _guard(() => _client.getPlaylist(id));
  }

  Future<void> createPlaylist(String name, {List<String>? songIds}) {
    return _guard(() => _client.createPlaylist(name, songIds: songIds));
  }

  Future<void> updatePlaylist(
    String id, {
    String? name,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) {
    return _guard(
      () => _client.updatePlaylist(
        id,
        name: name,
        songIdsToAdd: songIdsToAdd,
        songIndexesToRemove: songIndexesToRemove,
      ),
    );
  }

  Future<void> deletePlaylist(String id) {
    return _guard(() => _client.deletePlaylist(id));
  }

  Future<List<Song>> searchSongs(
    String query, {
    int songCount = 50,
    int songOffset = 0,
  }) {
    final normalized = query.trim();
    return _guard(() async {
      final result = await _client.search3(
        normalized,
        songCount: songCount,
        songOffset: songOffset,
        artistCount: 0,
        albumCount: 0,
      );
      return result.songs;
    });
  }
}
