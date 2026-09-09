import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/audio_handler.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/screens/playlist_detail/playlist_detail_screen.dart';
import 'package:navidrome_player/ui/screens/playlists/playlists_screen.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<_RecordingPlaylistClient> _pumpPlaylists(
  WidgetTester tester, {
  bool withPlayer = false,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final client = _RecordingPlaylistClient();
  final player = withPlayer ? _FakeAudioPlayer() : null;
  final handler = withPlayer
      ? NavidromeAudioHandler(
          client,
          BackendClient(),
          prefs: prefs,
          player: player,
        )
      : null;
  if (handler != null && player != null) {
    addTearDown(player.disposeStreams);
  }

  final router = GoRouter(
    initialLocation: '/library/playlists',
    routes: [
      GoRoute(
        path: '/library/playlists',
        builder: (_, _) => const PlaylistsScreen(),
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (_, state) => PlaylistDetailScreen(
          playlistId: Uri.decodeComponent(state.pathParameters['id']!),
        ),
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
      overrides: [
        subsonicClientProvider.overrideWithValue(client),
        if (handler != null) ...[
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioHandlerProvider.overrideWithValue(handler),
        ],
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        theme: AppTheme.light(),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (withPlayer) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } else {
    await tester.pumpAndSettle();
  }
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  testWidgets('mobile playlist header stays above the list', (tester) async {
    await _pumpPlaylists(tester);

    final header = find.byKey(const Key('playlist-header-title'));
    expect(header, findsOneWidget);
    expect(find.byKey(const Key('playlist-create-button')), findsOneWidget);
    expect(find.byKey(const Key('playlist-section-tabs')), findsNothing);
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
    await tester.tap(find.text('Save'));
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

  testWidgets('empty playlist opens detail and can add local library songs', (
    tester,
  ) async {
    final client = await _pumpPlaylists(tester, withPlayer: true);

    await tester.tap(find.text('Morning'));
    // Avoid pumpAndSettle: CoverArt shimmer keeps animating.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlaylistDetailScreen), findsOneWidget);
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
    expect(find.text('Added 1 songs'), findsWidgets);
  });

  testWidgets('playlist songs mark the currently playing item', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const current = Song(
      id: 's2',
      title: 'Summer',
      album: 'Album',
      albumId: 'a1',
      artist: 'Artist',
      artistId: 'ar1',
    );
    const other = Song(
      id: 's1',
      title: 'Spring',
      album: 'Album',
      albumId: 'a1',
      artist: 'Artist',
      artistId: 'ar1',
    );
    final client = _RecordingPlaylistClient()
      ..playlists[0] = Playlist(
        id: 'p1',
        name: 'Morning',
        songCount: 2,
        songs: const [other, current],
      );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final player = _FakeAudioPlayer();
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      prefs: prefs,
      player: player,
    );
    addTearDown(player.disposeStreams);
    await handler.setQueue(const [other, current], startIndex: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          subsonicClientProvider.overrideWithValue(client),
          audioHandlerProvider.overrideWithValue(handler),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const PlaylistDetailScreen(playlistId: 'p1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Summer'), findsOneWidget);
    expect(find.text('Spring'), findsOneWidget);
    expect(find.byType(AudioVisualizerBars), findsOneWidget);
  });
}

class _FakeAudioPlayer extends AudioPlayer {
  final positionController = StreamController<Duration>.broadcast();
  final processingController = StreamController<ProcessingState>.broadcast();
  final playingController = StreamController<bool>.broadcast();
  int playCalls = 0;
  bool isPlaying = false;

  @override
  bool get playing => isPlaying;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      processingController.stream;

  @override
  Stream<bool> get playingStream => playingController.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();

  Future<void> disposeStreams() async {
    await positionController.close();
    await processingController.close();
    await playingController.close();
  }

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    return const Duration(seconds: 100);
  }

  @override
  Future<void> play() async {
    playCalls++;
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {}
}
