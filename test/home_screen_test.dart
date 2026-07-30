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

const _recommendedSong = Song(
  id: 'recommended',
  title: 'Recommended Song',
  album: 'Recommended Album',
  albumId: 'recommended-album',
  artist: 'Recommended Artist',
  artistId: 'recommended-artist',
  duration: 245,
  backend: SongBackend.solara,
  onlineSource: 'netease',
  urlId: 'recommended-url',
);

const _recentSong = Song(
  id: 'recent',
  title: 'Recently Played Song',
  album: 'Recent Album',
  albumId: 'recent-album',
  artist: 'Recent Artist',
  artistId: 'recent-artist',
  duration: 181,
);

class _StaticRecommendationNotifier extends RecommendationNotifier {
  @override
  RecommendationState build() => RecommendationState(
    items: const [
      RecommendationItem(
        candidateId: 'candidate-1',
        type: RecommendationType.similar,
        song: _recommendedSong,
      ),
    ],
    sessionId: 'session-1',
    hasMore: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  testWidgets('home prioritizes concrete songs over the album rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        newestAlbumsProvider.overrideWith(
          (ref) async => const [
            Album(id: 'album-1', name: 'Newest Album', artist: 'Album Artist'),
          ],
        ),
        weatherProvider.overrideWith((ref) async => null),
        recommendationProvider.overrideWith(_StaticRecommendationNotifier.new),
        recommendationRecentSongsProvider.overrideWithValue(const [
          _recentSong,
        ]),
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
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(1200, 1400),
              textScaler: TextScaler.linear(1.8),
            ),
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Recommended Song'), findsOneWidget);
    expect(find.text('Recommended Artist · Recommended Album'), findsOneWidget);
    expect(find.text('4:05'), findsOneWidget);
    expect(find.text('Recently Played Song'), findsOneWidget);
    expect(find.text('Recent Artist · Recent Album'), findsOneWidget);
    expect(find.text('3:01'), findsOneWidget);
    expect(find.text('Newest Album'), findsOneWidget);

    final forYouY = tester.getTopLeft(find.text('For You')).dy;
    final recentlyPlayedY = tester.getTopLeft(find.text('Recently Played')).dy;
    final latestAlbumsY = tester.getTopLeft(find.text('Latest Albums')).dy;
    expect(forYouY, lessThan(recentlyPlayedY));
    expect(recentlyPlayedY, lessThan(latestAlbumsY));
  });
}
