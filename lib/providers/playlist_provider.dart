import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'audio_providers.dart';

final playlistServiceProvider = Provider<PlaylistService>((ref) {
  return PlaylistService(ref.watch(subsonicClientProvider));
});

class PlaylistService {
  const PlaylistService(this._client);

  final SubsonicClient _client;

  Future<List<Playlist>> getPlaylists() => _client.getPlaylists();

  Future<Playlist> getPlaylist(String id) => _client.getPlaylist(id);

  Future<void> createPlaylist(String name, {List<String>? songIds}) {
    return _client.createPlaylist(name, songIds: songIds);
  }

  Future<void> updatePlaylist(
    String id, {
    String? name,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) {
    return _client.updatePlaylist(
      id,
      name: name,
      songIdsToAdd: songIdsToAdd,
      songIndexesToRemove: songIndexesToRemove,
    );
  }

  Future<void> deletePlaylist(String id) => _client.deletePlaylist(id);

  Future<List<Song>> searchSongs(
    String query, {
    int songCount = 50,
    int songOffset = 0,
  }) async {
    final result = await _client.search3(
      query.trim().isEmpty ? '' : query.trim(),
      songCount: songCount,
      songOffset: songOffset,
      artistCount: 0,
      albumCount: 0,
    );
    return result.songs;
  }
}
