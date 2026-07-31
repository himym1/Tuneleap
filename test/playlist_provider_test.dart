import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/providers.dart';

const _song = Song(
  id: 's1',
  title: 'Spring',
  album: 'Album',
  albumId: 'a1',
  artist: 'Artist',
  artistId: 'ar1',
);

class _RecordingClient extends SubsonicClient {
  _RecordingClient() {
    configure(serverUrl: 'http://server', username: 'user', password: 'pass');
  }

  final playlists = [
    const Playlist(id: 'p1', name: 'Morning', songCount: 1, songs: [_song]),
  ];
  String? createdName;
  List<String>? createdSongIds;
  String? updatedId;
  String? updatedName;
  List<String>? updatedSongIds;
  List<int>? removedIndexes;
  String? deletedId;
  String? searchedQuery;
  int? searchedSongCount;
  int? searchedSongOffset;
  Object? error;

  void _throwIfNeeded() {
    if (error != null) throw error!;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    _throwIfNeeded();
    return playlists;
  }

  @override
  Future<Playlist> getPlaylist(String id) async {
    _throwIfNeeded();
    return playlists.firstWhere((playlist) => playlist.id == id);
  }

  @override
  Future<void> createPlaylist(String name, {List<String>? songIds}) async {
    _throwIfNeeded();
    createdName = name;
    createdSongIds = songIds;
  }

  @override
  Future<void> updatePlaylist(
    String id, {
    String? name,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    _throwIfNeeded();
    updatedId = id;
    updatedName = name;
    updatedSongIds = songIdsToAdd;
    removedIndexes = songIndexesToRemove;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    _throwIfNeeded();
    deletedId = id;
  }

  @override
  Future<SearchResult> search3(
    String query, {
    int artistCount = 10,
    int albumCount = 10,
    int songCount = 20,
    int artistOffset = 0,
    int albumOffset = 0,
    int songOffset = 0,
  }) async {
    _throwIfNeeded();
    searchedQuery = query;
    searchedSongCount = songCount;
    searchedSongOffset = songOffset;
    return const SearchResult(songs: [_song]);
  }
}

void main() {
  test('playlist provider service delegates CRUD parameters', () async {
    final client = _RecordingClient();
    final container = ProviderContainer(
      overrides: [subsonicClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final service = container.read(playlistServiceProvider);

    expect(await service.getPlaylists(), client.playlists);
    expect(await service.getPlaylist('p1'), client.playlists.single);

    await service.createPlaylist('Focus', songIds: ['s1', 's2']);
    expect(client.createdName, 'Focus');
    expect(client.createdSongIds, ['s1', 's2']);

    await service.updatePlaylist(
      'p1',
      name: 'Focus',
      songIdsToAdd: ['s3'],
      songIndexesToRemove: [0, 2],
    );
    expect(client.updatedId, 'p1');
    expect(client.updatedName, 'Focus');
    expect(client.updatedSongIds, ['s3']);
    expect(client.removedIndexes, [0, 2]);

    await service.deletePlaylist('p1');
    expect(client.deletedId, 'p1');
  });

  test(
    'playlist service searches songs with normalized query and pagination',
    () async {
      final client = _RecordingClient();
      final container = ProviderContainer(
        overrides: [subsonicClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final songs = await container
          .read(playlistServiceProvider)
          .searchSongs('  Spring  ', songCount: 25, songOffset: 50);

      expect(songs, [_song]);
      expect(client.searchedQuery, 'Spring');
      expect(client.searchedSongCount, 25);
      expect(client.searchedSongOffset, 50);
    },
  );

  test('playlist service propagates client errors', () async {
    final client = _RecordingClient()..error = StateError('playlist failed');
    final container = ProviderContainer(
      overrides: [subsonicClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final service = container.read(playlistServiceProvider);
    await expectLater(service.getPlaylists(), throwsA(isA<StateError>()));
    await expectLater(service.getPlaylist('p1'), throwsA(isA<StateError>()));
    await expectLater(
      service.createPlaylist('Focus'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.updatePlaylist('p1', name: 'Focus'),
      throwsA(isA<StateError>()),
    );
    await expectLater(service.deletePlaylist('p1'), throwsA(isA<StateError>()));
    await expectLater(service.searchSongs('query'), throwsA(isA<StateError>()));
  });
}
