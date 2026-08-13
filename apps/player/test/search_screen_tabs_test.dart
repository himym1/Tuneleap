import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/music_capabilities.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/online_source_preferences.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:navidrome_player/ui/screens/search/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search screen shows only enabled platform tabs', (tester) async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
      onlineSourcesPreferenceKey('server-a'): [
        'netease',
        'tencent',
        'kugou',
        'migu',
        'joox',
      ],
      onlineAdapterPreferenceKey('server-a'): 'gdstudio',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          musicCapabilitiesProvider.overrideWith(
            (ref) async => const MusicCapabilities(
              defaultProvider: 'meting',
              adapters: [
                MusicAdapterCapability(
                  id: 'meting',
                  sources: ['netease', 'tencent', 'kugou'],
                ),
                MusicAdapterCapability(
                  id: 'gdstudio',
                  sources: ['netease', 'kugou', 'migu', 'joox'],
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网易云'), findsOneWidget);
    expect(find.text('QQ'), findsNothing);
    expect(find.text('酷狗'), findsOneWidget);
    expect(find.text('咪咕'), findsOneWidget);
    expect(find.text('JOOX'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-source-kugou')));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('search-source-kugou')))
          .properties
          .selected,
      isTrue,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SearchScreen)),
    );
    await container
        .read(onlineSearchAdapterProvider.notifier)
        .setProvider('meting');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('search-source-netease')),
          )
          .properties
          .selected,
      isTrue,
    );
  });
}
