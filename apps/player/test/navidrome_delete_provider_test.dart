import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/navidrome_delete_provider.dart';

class _FakeBackendClient extends BackendClient {
  _FakeBackendClient({this.canMutate = true, this.missingIds = const {}});

  final bool canMutate;
  final Set<String> missingIds;
  final List<List<String>> chunks = [];

  @override
  bool get canMutateNas => canMutate;

  @override
  Future<NasDeleteResult> deleteLibrarySongs(List<String> navidromeIds) async {
    chunks.add(List<String>.from(navidromeIds));
    if (navidromeIds.every(missingIds.contains)) {
      throw const NasDeleteException('song not found in the Navidrome library');
    }
    final deleted = [
      for (final id in navidromeIds)
        if (!missingIds.contains(id)) id,
    ];
    return NasDeleteResult(
      deleted: deleted.length,
      skipped: navidromeIds.length - deleted.length,
    );
  }
}

void main() {
  const librarySong = Song(
    id: 'local-1',
    title: '晴天',
    album: '叶惠美',
    albumId: 'album-1',
    artist: '周杰伦',
    artistId: 'artist-1',
    backend: SongBackend.subsonic,
  );
  const onlineSong = Song(
    id: 'netease-1',
    title: '晴天',
    album: '叶惠美',
    albumId: '',
    artist: '周杰伦',
    artistId: '',
    backend: SongBackend.solara,
    onlineSource: 'netease',
  );

  test('deleteLibrarySong posts the Navidrome id to NAS agent', () async {
    final backend = _FakeBackendClient();
    final service = NavidromeDeleteService(backendClient: backend);

    final result = await service.deleteLibrarySong(librarySong);

    expect(result.ok, isTrue);
    expect(backend.chunks, [
      ['local-1'],
    ]);
  });

  test(
    'deleteLibrarySongIds posts 50-id chunks and keeps going after skips',
    () async {
      final backend = _FakeBackendClient(
        missingIds: {for (var i = 0; i < 50; i++) 'missing-$i'},
      );
      final service = NavidromeDeleteService(backendClient: backend);
      final ids = [
        for (var i = 0; i < 50; i++) 'missing-$i',
        for (var i = 0; i < 12; i++) 'keep-$i',
      ];

      final result = await service.deleteLibrarySongIds(ids);

      expect(backend.chunks.length, 2);
      expect(backend.chunks.first.length, 50);
      expect(backend.chunks.last.length, 12);
      expect(result.deleted, 12);
      expect(result.skipped, 50);
    },
  );

  test('deleteLibrarySong rejects online songs', () async {
    final service = NavidromeDeleteService(backendClient: _FakeBackendClient());

    expect(
      () => service.deleteLibrarySong(onlineSong),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('deleteLibrarySong requires a configured NAS agent', () async {
    final service = NavidromeDeleteService(
      backendClient: _FakeBackendClient(canMutate: false),
    );

    expect(
      () => service.deleteLibrarySong(librarySong),
      throwsA(isA<StateError>()),
    );
  });
}
