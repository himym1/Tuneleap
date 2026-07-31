import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/song_media_resolver.dart';
import 'package:navidrome_player/api/subsonic_client.dart';

class _NoLyricsSubsonicClient extends SubsonicClient {
  @override
  Future<LyricsList?> getLyricsBySongId(String id) async => null;
}

class _CapturingBackendClient extends BackendClient {
  Song? requestedSong;

  _CapturingBackendClient() {
    configure(baseUrl: 'https://cloud.test');
  }

  @override
  Future<LyricsList?> getLyrics(Song song) async {
    requestedSong = song;
    return null;
  }
}

Song _importedSong(String path) => Song(
  id: 'local-id',
  title: 'Imported song',
  album: '',
  albumId: '',
  artist: 'Artist',
  artistId: '',
  path: path,
);

void main() {
  test('imported filename restores source and winning provider', () async {
    final backend = _CapturingBackendClient();
    final resolver = SongMediaResolver(
      subsonicClient: _NoLyricsSubsonicClient(),
      backendClient: backend,
    );

    await resolver.lyrics(
      _importedSong('/music/solara_netease_via-meting_123.part.mp3'),
    );

    expect(backend.requestedSong?.onlineSource, 'netease');
    expect(backend.requestedSong?.onlineProvider, 'meting');
    expect(backend.requestedSong?.lyricId, '123.part');
  });

  test('legacy imported filename remains supported', () async {
    final backend = _CapturingBackendClient();
    final resolver = SongMediaResolver(
      subsonicClient: _NoLyricsSubsonicClient(),
      backendClient: backend,
    );

    await resolver.lyrics(_importedSong('/music/solara_joox_456.mp3'));

    expect(backend.requestedSong?.onlineSource, 'joox');
    expect(backend.requestedSong?.onlineProvider, isNull);
    expect(backend.requestedSong?.lyricId, '456');
  });
}
