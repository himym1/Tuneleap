import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/screens/settings/settings_screen.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences)> _container(
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return (
    ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ),
    prefs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  test('theme mode and preset default to system and classic', () async {
    final (container, _) = await _container({});
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(container.read(themePresetProvider), ThemePreset.classic);
  });

  test('theme preset loads and persists by enum name', () async {
    final (container, prefs) = await _container({
      'theme_preset': 'dynamic',
      'theme_mode': 'light',
    });
    addTearDown(container.dispose);

    expect(container.read(themePresetProvider), ThemePreset.dynamic);

    await container
        .read(themePresetProvider.notifier)
        .setPreset(ThemePreset.amoled);

    expect(container.read(themePresetProvider), ThemePreset.amoled);
    expect(prefs.getString('theme_preset'), 'amoled');
    expect(prefs.getString('theme_mode'), 'light');
  });

  test('unknown stored preset falls back to classic', () async {
    final (container, _) = await _container({'theme_preset': 'unknown'});
    addTearDown(container.dispose);

    expect(container.read(themePresetProvider), ThemePreset.classic);
  });

  test('amoled dark theme uses true black base surfaces', () {
    final theme = AppTheme.dark(amoled: true);

    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.colorScheme.surface, Colors.black);
    expect(theme.colorScheme.surfaceContainerLowest, Colors.black);
    expect(theme.colorScheme.surfaceContainerHigh, const Color(0xFF111111));
  });

  test('light theme sliders follow the seed color', () {
    const seed = Color(0xFFFF8A00);
    final theme = AppTheme.light(seedColor: seed);

    expect(theme.sliderTheme.activeTrackColor, theme.colorScheme.primary);
    expect(theme.sliderTheme.thumbColor, theme.colorScheme.primary);
  });

  test('dynamic theme derives material and semantic colors from artwork', () {
    const artworkColor = Color(0xFFB3261E);
    final theme = AppTheme.dark(seedColor: artworkColor);
    final semantic = theme.extension<AppSemanticColors>()!;

    expect(theme.colorScheme.primary, isNot(AppColors.primary));
    expect(semantic.primary, theme.colorScheme.primary);
    expect(semantic.accent, theme.colorScheme.tertiary);
    expect(
      semantic.onEmphasisMuted,
      theme.colorScheme.onPrimary.withValues(alpha: 0.70),
    );
  });

  testWidgets('theme style selector fits a narrow English viewport', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appVersionProvider.overrideWithValue('1.0.0'),
        appBuildProvider.overrideWithValue(1),
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
            data: MediaQueryData(size: Size(320, 720)),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Settings cards already wrap ListTiles in DecoratedBox, which Flutter
    // reports as an ink-splash warning; ignore that pre-existing noise here.
    final exceptions = <Object?>[];
    while (true) {
      final exception = tester.takeException();
      if (exception == null) break;
      exceptions.add(exception);
    }
    expect(
      exceptions.whereType<FlutterError>().any(
        (error) => error.message.contains('A RenderFlex overflowed'),
      ),
      isFalse,
    );
    expect(find.byType(DropdownButton<ThemePreset>), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.byType(ResponsivePageScaffold), findsOneWidget);
  });
}
