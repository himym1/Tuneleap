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

Song _localSong(String id, {String? artistId}) => Song(
  id: id,
  title: 'Song $id',
  album: 'Album $id',
  albumId: 'album-$id',
  artist: 'Artist ${artistId ?? id}',
  artistId: artistId ?? 'artist-$id',
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
      newestSongsProvider.overrideWith((ref) async {
        onNewestLoad?.call();
        return [
          _localSong('newest-1'),
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

  test(
    'personalized mix excludes recent songs and limits artist repetition',
    () {
      final history = List.generate(
        12,
        (index) => _localSong('history-$index'),
      );
      final mix = composePersonalizedLocalMix(
        playHistory: history,
        similarSongs: [
          history.first,
          _localSong('similar-1', artistId: 'favorite-artist'),
          _localSong('similar-2', artistId: 'favorite-artist'),
          _localSong('similar-3', artistId: 'favorite-artist'),
        ],
        starredSongs: [_localSong('starred')],
        randomSongs: List.generate(8, (index) => _localSong('random-$index')),
        limit: 10,
      );

      final ids = mix.map((song) => song.id).toList();
      expect(ids, isNot(contains('history-0')));
      expect(ids.take(2), ['similar-1', 'similar-2']);
      expect(ids, contains('history-8'));
      expect(ids, contains('starred'));
      expect(ids.length, 10);
      expect(mix.where((song) => song.artistId == 'favorite-artist').length, 2);
    },
  );

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
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Shuffle Library'), findsNothing);
    expect(find.text('Recently Played Song 1'), findsOneWidget);
    expect(find.text('Recently Played Song 2'), findsNothing);
    expect(find.text('Recommended Song 1'), findsOneWidget);
    expect(
      find.text('Recommended Artist 1 · Recommended Album 1'),
      findsOneWidget,
    );
    expect(find.text('4:01'), findsOneWidget);
    expect(find.text('Latest Songs'), findsOneWidget);
    expect(find.text('Song newest-1'), findsOneWidget);

    final yourMusicY = tester.getTopLeft(find.text('Your Music')).dy;
    final discoveryY = tester.getTopLeft(find.text('Discover New Music')).dy;
    final latestSongsY = tester.getTopLeft(find.text('Latest Songs')).dy;
    expect(yourMusicY, lessThan(discoveryY));
    expect(discoveryY, lessThan(latestSongsY));
  });

  testWidgets('mobile local listening actions fit without overflow', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      size: const Size(360, 800),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Shuffle Library'), findsNothing);
    expect(
      find.byKey(const Key('home-personalized-mix-button')),
      findsOneWidget,
    );
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
    expect(find.text('Latest Songs'), findsOneWidget);
    expect(find.text('Song newest-1'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Latest Songs')).dy,
      lessThanOrEqualTo(size.height),
    );
  });
}
