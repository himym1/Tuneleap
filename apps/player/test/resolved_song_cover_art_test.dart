import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/song_media_resolver.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';

class _FakeResolver extends SongMediaResolver {
  _FakeResolver()
    : super(subsonicClient: SubsonicClient(), backendClient: BackendClient());

  @override
  Future<String> coverArtUrl(Song song, {int size = 300}) async {
    return 'https://images.test/$size.jpg';
  }
}

class _EmptyResolver extends SongMediaResolver {
  _EmptyResolver()
    : super(subsonicClient: SubsonicClient(), backendClient: BackendClient());

  final completer = Completer<String>();

  @override
  Future<String> coverArtUrl(Song song, {int size = 300}) => completer.future;
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

  testWidgets('empty resolved cover stops shimmering and shows a music icon', (
    tester,
  ) async {
    const song = Song(
      id: 'online-empty',
      title: 'Song',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
      backend: SongBackend.solara,
      onlineSource: 'kugou',
      urlId: 'source-id',
    );
    final resolver = _EmptyResolver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [songMediaResolverProvider.overrideWithValue(resolver)],
        child: const MaterialApp(
          home: ResolvedSongCoverArt(song: song, size: 52),
        ),
      ),
    );

    expect(find.byType(Shimmer), findsOneWidget);
    resolver.completer.complete('');
    await tester.pump();

    expect(find.byType(Shimmer), findsNothing);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });
}
