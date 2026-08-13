import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      onlineSourcesPreferenceKey('server-a'): ['netease', 'tencent'],
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
    expect(find.text('QQ'), findsOneWidget);
    expect(find.text('酷狗'), findsNothing);
  });
}
