import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/audio_handler.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/mini_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('desktop mini player stays visible when queue is empty', (
    WidgetTester tester,
  ) async {
    await initializeAppColors();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final client = SubsonicClient();
    final backendClient = BackendClient();
    final handler = NavidromeAudioHandler(client, backendClient, prefs: prefs);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.dark(),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(1280, 800)),
            child: Scaffold(
              bottomNavigationBar: MiniPlayer(alwaysVisible: true),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Nothing playing'), findsOneWidget);
    expect(
      find.text('Start playback from Home, Library, or Playlists'),
      findsOneWidget,
    );
  });
}
