import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/screens/audio_quality/audio_quality_screen.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/app_brand_logo.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/loading_skeleton.dart';
import 'package:navidrome_player/ui/widgets/song_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  testWidgets('AppBrandLogo renders cleanly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: AppBrandLogo(size: 48))),
      ),
    );

    await tester.pump();
    expect(find.byType(AppBrandLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmptyState renders safely without AppTheme extension', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.music_off_rounded, message: 'No tracks'),
        ),
      ),
    );

    expect(find.text('No tracks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SongTile renders track and active state cleanly', (
    tester,
  ) async {
    const song = Song(
      id: 's1',
      title: 'Night Drive',
      album: 'Neon',
      albumId: 'a1',
      artist: 'Synth',
      artistId: 'ar1',
      track: 3,
      duration: 195,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(amoled: true),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: SongTile(
            song: song,
            cardStyle: true,
            isActive: true,
            isPlaying: true,
            showHoverPlay: true,
          ),
        ),
      ),
    );

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Synth · Neon'), findsOneWidget);
    expect(find.text('3:15'), findsOneWidget);
    expect(find.byType(AudioVisualizerBars), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SongListSkeleton renders shimmer placeholders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: SongListSkeleton(itemCount: 4)),
      ),
    );

    await tester.pump();
    expect(find.byType(SongListSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AudioQualityScreen stacks cleanly on narrow mobile viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.dark(),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const AudioQualityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original'), findsWidgets);
    expect(find.text('MP3 128k'), findsOneWidget);
    expect(find.text('MP3 320k'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('MP3 128k')).dy,
      lessThan(tester.getTopLeft(find.text('MP3 320k')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
