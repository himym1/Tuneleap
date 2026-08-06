import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/screens/playlists/playlists_screen.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

const _librarySong = Song(
  id: 's1',
  title: 'Spring',
  album: 'Album',
  albumId: 'a1',
  artist: 'Artist',
  artistId: 'ar1',
);

class _RecordingPlaylistClient extends SubsonicClient {
  _RecordingPlaylistClient() {
    configure(serverUrl: 'http://server', username: 'user', password: 'pass');
  }

  final playlists = <Playlist>[
    const Playlist(id: 'p1', name: 'Morning', songCount: 0),
    const Playlist(id: 'p2', name: 'Road Trip', songCount: 0),
  ];
  final librarySongs = <Song>[_librarySong];
  String? createdName;
  String? renamedId;
  String? renamedName;
  String? deletedId;
  List<String>? addedSongIds;
  String? addedToPlaylistId;

  @override
  Future<List<Playlist>> getPlaylists() async => List.of(playlists);

  @override
  Future<Playlist> getPlaylist(String id) async =>
      playlists.firstWhere((playlist) => playlist.id == id);

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
    final q = query.trim().toLowerCase();
    final songs = librarySongs
        .where(
          (song) =>
              q.isEmpty ||
              song.title.toLowerCase().contains(q) ||
              song.artist.toLowerCase().contains(q),
        )
        .skip(songOffset)
        .take(songCount)
        .toList();
    return SearchResult(songs: songs);
  }

  @override
  Future<void> createPlaylist(String name, {List<String>? songIds}) async {
    createdName = name;
    playlists.add(
      Playlist(id: 'created', name: name, songCount: songIds?.length ?? 0),
    );
  }

  @override
  Future<void> updatePlaylist(
    String id, {
    String? name,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    final index = playlists.indexWhere((playlist) => playlist.id == id);
    final current = playlists[index];
    var songs = List<Song>.from(current.songs);

    if (songIndexesToRemove != null && songIndexesToRemove.isNotEmpty) {
      final remove = songIndexesToRemove.toSet();
      songs = [
        for (var i = 0; i < songs.length; i++)
          if (!remove.contains(i)) songs[i],
      ];
    }
    if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) {
      addedToPlaylistId = id;
      addedSongIds = List.of(songIdsToAdd);
      for (final songId in songIdsToAdd) {
        final match = librarySongs.where((song) => song.id == songId);
        if (match.isNotEmpty) {
          songs.add(match.first);
        } else {
          songs.add(
            Song(
              id: songId,
              title: songId,
              album: '',
              albumId: '',
              artist: '',
              artistId: '',
            ),
          );
        }
      }
    }
    if (name != null) {
      renamedId = id;
      renamedName = name;
    }
    playlists[index] = Playlist(
      id: current.id,
      name: name ?? current.name,
      songCount: songs.length,
      duration: current.duration,
      coverArt: current.coverArt,
      owner: current.owner,
      songs: songs,
    );
  }

  @override
  Future<void> deletePlaylist(String id) async {
    deletedId = id;
    playlists.removeWhere((playlist) => playlist.id == id);
  }
}

Future<_RecordingPlaylistClient> _pumpPlaylists(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final client = _RecordingPlaylistClient();
  final router = GoRouter(
    initialLocation: '/library/playlists',
    routes: [
      GoRoute(
        path: '/library/playlists',
        builder: (_, _) => const PlaylistsScreen(),
      ),
      for (final path in [
        '/library/songs',
        '/library/albums',
        '/library/artists',
        '/library/genres',
        '/library/album-artists',
        '/library/radio',
      ])
        GoRoute(path: path, builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [subsonicClientProvider.overrideWithValue(client)],
      child: MaterialApp.router(
        locale: const Locale('en'),
        theme: AppTheme.light(),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  testWidgets('mobile playlist header stays above library tabs', (
    tester,
  ) async {
    await _pumpPlaylists(tester);

    final header = find.byKey(const Key('playlist-header-title'));
    final tabs = find.byKey(const Key('playlist-section-tabs'));
    expect(header, findsOneWidget);
    expect(find.byKey(const Key('playlist-create-button')), findsOneWidget);
    expect(
      tester.getBottomLeft(header).dy,
      lessThan(tester.getTopLeft(tabs).dy),
    );
    expect(find.text('2 playlists'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playlist create rename and delete actions are reachable', (
    tester,
  ) async {
    final client = await _pumpPlaylists(tester);

    await tester.tap(find.byKey(const Key('playlist-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Focus');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(client.createdName, 'Focus');
    expect(find.text('3 playlists'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('playlist-menu-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Morning Focus');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(client.renamedId, 'p1');
    expect(client.renamedName, 'Morning Focus');
    expect(find.text('Morning Focus'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('playlist-menu-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(client.deletedId, 'p1');
    expect(find.text('2 playlists'), findsOneWidget);
  });

  testWidgets('empty playlist can add local library songs', (tester) async {
    final client = await _pumpPlaylists(tester);

    await tester.tap(find.text('Morning'));
    // Avoid pumpAndSettle: CoverArt shimmer keeps animating.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const Key('playlist-empty-add-songs-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('playlist-empty-add-songs-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Add Songs to Playlist'), findsOneWidget);
    expect(find.text('Spring'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('picker-song-s1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('playlist-song-picker-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(client.addedToPlaylistId, 'p1');
    expect(client.addedSongIds, ['s1']);
    expect(find.text('Spring'), findsWidgets);
    expect(find.text('Added 1 songs'), findsOneWidget);
  });
}
