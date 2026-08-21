import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/navidrome_delete_provider.dart';

class _FakeBackendClient extends BackendClient {
  _FakeBackendClient({this.canMutate = true});

  final bool canMutate;
  List<String>? deletedIds;

  @override
  bool get canMutateNas => canMutate;

  @override
  Future<NasDeleteResult> deleteLibrarySongs(List<String> navidromeIds) async {
    deletedIds = navidromeIds;
    return NasDeleteResult(deleted: navidromeIds.length);
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
    expect(backend.deletedIds, ['local-1']);
  });

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
