import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/app.dart';
import 'package:navidrome_player/providers/providers.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const NavidromePlayerApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Navidrome Player'), findsOneWidget);
  });
}
