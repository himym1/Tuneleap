import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/ui/widgets/library_section_tabs.dart';

Widget _page() => const Scaffold(
  body: Padding(padding: EdgeInsets.all(16), child: LibrarySectionTabs()),
);

void main() {
  testWidgets(
    'library sections expose four primary views and secondary browse',
    (tester) async {
      tester.view.physicalSize = const Size(320, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/library/songs',
        routes: [
          for (final path in [
            '/library/playlists',
            '/library/songs',
            '/library/albums',
            '/library/artists',
            '/library/genres',
            '/library/album-artists',
            '/library/radio',
          ])
            GoRoute(path: path, builder: (_, _) => _page()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/library/playlists');

      await tester.tap(find.byTooltip('Browse library'));
      await tester.pumpAndSettle();
      expect(find.text('Genres'), findsOneWidget);
      expect(find.text('Album Artists'), findsOneWidget);
      expect(find.text('Radio'), findsOneWidget);

      await tester.tap(find.text('Genres'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/library/genres');
    },
  );
}
