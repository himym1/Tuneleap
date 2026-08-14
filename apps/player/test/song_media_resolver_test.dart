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

  test('direct radio stream url is used as-is', () async {
    final resolver = SongMediaResolver(
      subsonicClient: _NoLyricsSubsonicClient(),
      backendClient: _CapturingBackendClient(),
    );
    const radio = Song(
      id: 'radio:1',
      title: 'Station',
      album: '',
      albumId: '',
      artist: '',
      artistId: '',
      streamUrl: 'https://radio.test/stream',
    );

    expect(radio.isRadio, isTrue);
    expect(resolver.supportsLibraryMutations(radio), isFalse);
    expect(await resolver.playbackUrl(radio), 'https://radio.test/stream');
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
