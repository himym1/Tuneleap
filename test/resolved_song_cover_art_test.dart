import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/song_media_resolver.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';

class _FakeResolver extends SongMediaResolver {
  _FakeResolver()
    : super(subsonicClient: SubsonicClient(), backendClient: BackendClient());

  @override
  Future<String> coverArtUrl(Song song, {int size = 300}) async {
    return 'https://images.test/$size.jpg';
  }
}

void main() {
  testWidgets('resolved cover uses the media resolver result', (tester) async {
    const song = Song(
      id: 'online',
      title: 'Song',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
      backend: SongBackend.solara,
      onlineSource: 'netease',
      urlId: 'source-id',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songMediaResolverProvider.overrideWithValue(_FakeResolver()),
        ],
        child: const MaterialApp(
          home: ResolvedSongCoverArt(song: song, size: 52),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<CoverArt>(find.byType(CoverArt)).url,
      'https://images.test/100.jpg',
    );
  });
}
