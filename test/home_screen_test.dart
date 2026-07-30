import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/screens/home/home_screen.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _recommendedSong(int index) => Song(
  id: 'recommended-$index',
  title: 'Recommended Song $index',
  album: 'Recommended Album $index',
  albumId: 'recommended-album-$index',
  artist: 'Recommended Artist $index',
  artistId: 'recommended-artist-$index',
  duration: 240 + index,
  backend: SongBackend.solara,
  onlineSource: 'netease',
  urlId: 'recommended-url-$index',
);

const _recentSongs = [
  Song(
    id: 'recent-1',
    title: 'Recently Played Song 1',
    album: 'Recent Album 1',
    albumId: 'recent-album-1',
    artist: 'Recent Artist 1',
    artistId: 'recent-artist-1',
    duration: 181,
  ),
  Song(
    id: 'recent-2',
    title: 'Recently Played Song 2',
    album: 'Recent Album 2',
    albumId: 'recent-album-2',
    artist: 'Recent Artist 2',
    artistId: 'recent-artist-2',
    duration: 202,
  ),
];

int _recommendationRefreshCalls = 0;

class _StaticRecommendationNotifier extends RecommendationNotifier {
  @override
  RecommendationState build() => RecommendationState(
    items: List.generate(
      6,
      (index) => RecommendationItem(
        candidateId: 'candidate-${index + 1}',
        type: RecommendationType.similar,
        song: _recommendedSong(index + 1),
      ),
    ),
    sessionId: 'session-1',
    hasMore: false,
  );

  @override
  Future<void> refresh() async {
    _recommendationRefreshCalls++;
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onNewestLoad,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _recommendationRefreshCalls = 0;

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      newestAlbumsProvider.overrideWith((ref) async {
        onNewestLoad?.call();
        return const [
          Album(id: 'album-1', name: 'Newest Album', artist: 'Album Artist'),
        ];
      }),
      weatherProvider.overrideWith((ref) async => null),
      recommendationProvider.overrideWith(_StaticRecommendationNotifier.new),
      recommendationRecentSongsProvider.overrideWithValue(_recentSongs),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.light(),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: textScaler),
          child: const HomeScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  test('local mix favors older local songs and removes duplicates', () {
    final history = List.generate(
      7,
      (index) => Song(
        id: 'history-$index',
        title: 'History $index',
        album: 'Album',
        albumId: 'album',
        artist: 'Artist',
        artistId: 'artist',
      ),
    );
    final random = [
      history[6],
      const Song(
        id: 'random',
        title: 'Random',
        album: 'Album',
        albumId: 'album',
        artist: 'Artist',
        artistId: 'artist',
      ),
    ];

    final mix = composeLocalMix(history, random, limit: 4);

    expect(mix.map((song) => song.id), [
      'history-6',
      'history-5',
      'history-4',
      'random',
    ]);
  });

  testWidgets('home separates local listening from online discovery', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: const Size(1200, 1400),
      textScaler: const TextScaler.linear(1.8),
    );

    expect(find.text('Your Music'), findsOneWidget);
    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Local Mix'), findsOneWidget);
    expect(find.text('Shuffle Library'), findsOneWidget);
    expect(find.text('Recently Played Song 1'), findsOneWidget);
    expect(find.text('Recently Played Song 2'), findsNothing);
    expect(find.text('Recommended Song 1'), findsOneWidget);
    expect(
      find.text('Recommended Artist 1 · Recommended Album 1'),
      findsOneWidget,
    );
    expect(find.text('4:01'), findsOneWidget);
    expect(find.text('Newest Album'), findsOneWidget);

    final yourMusicY = tester.getTopLeft(find.text('Your Music')).dy;
    final discoveryY = tester.getTopLeft(find.text('Discover New Music')).dy;
    final latestAlbumsY = tester.getTopLeft(find.text('Latest Albums')).dy;
    expect(yourMusicY, lessThan(discoveryY));
    expect(discoveryY, lessThan(latestAlbumsY));
  });

  testWidgets('mobile local listening actions fit without overflow', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: const Size(360, 800),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('Local Mix'), findsOneWidget);
    expect(find.text('Shuffle Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull and button refresh reload home data', (tester) async {
    var newestLoads = 0;
    await _pumpHome(
      tester,
      size: const Size(1200, 1400),
      onNewestLoad: () => newestLoads++,
    );

    expect(newestLoads, 1);
    expect(_recommendationRefreshCalls, 0);

    await tester.drag(
      find.byKey(const Key('home-scroll-view')),
      const Offset(0, 400),
      touchSlopY: 0,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(newestLoads, 2);
    expect(_recommendationRefreshCalls, 1);
    expect(find.text('Home refreshed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-refresh-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(newestLoads, 3);
    expect(_recommendationRefreshCalls, 2);
  });

  testWidgets('desktop home summary fits in a 1200x820 viewport', (
    tester,
  ) async {
    const size = Size(1200, 820);
    await _pumpHome(tester, size: size);

    expect(find.text('Recommended Song 6'), findsOneWidget);
    expect(find.text('Recently Played Song 1'), findsOneWidget);
    expect(find.text('Newest Album'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Newest Album')).dy,
      lessThanOrEqualTo(size.height),
    );
  });
}
