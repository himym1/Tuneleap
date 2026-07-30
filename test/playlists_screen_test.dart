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

class _RecordingPlaylistClient extends SubsonicClient {
  _RecordingPlaylistClient() {
    configure(serverUrl: 'http://server', username: 'user', password: 'pass');
  }

  final playlists = <Playlist>[
    const Playlist(id: 'p1', name: 'Morning', songCount: 0),
    const Playlist(id: 'p2', name: 'Road Trip', songCount: 0),
  ];
  String? createdName;
  String? renamedId;
  String? renamedName;
  String? deletedId;

  @override
  Future<List<Playlist>> getPlaylists() async => List.of(playlists);

  @override
  Future<Playlist> getPlaylist(String id) async =>
      playlists.firstWhere((playlist) => playlist.id == id);

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
    if (name == null) return;
    renamedId = id;
    renamedName = name;
    final index = playlists.indexWhere((playlist) => playlist.id == id);
    final current = playlists[index];
    playlists[index] = Playlist(
      id: current.id,
      name: name,
      songCount: current.songCount,
      duration: current.duration,
      coverArt: current.coverArt,
      owner: current.owner,
      songs: current.songs,
    );
  }

  @override
  Future<void> deletePlaylist(String id) async {
    deletedId = id;
    playlists.removeWhere((playlist) => playlist.id == id);
  }
}

Future<_RecordingPlaylistClient> _pumpPlaylists(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
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
}
