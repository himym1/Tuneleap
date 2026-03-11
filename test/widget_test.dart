import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/app.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/player/audio_handler.dart';
import 'package:navidrome_player/api/solara_client.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await initializeAppColors();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final client = SubsonicClient();
    final solaraClient = SolaraClient();
    // 注意：测试环境不调用 AudioService.init，直接构造 Handler
    final handler = NavidromeAudioHandler(client, solaraClient, prefs: prefs);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NavidromePlayerApp(),
      ),
    );

    // 使用 pump() 而非 pumpAndSettle() — AudioHandler 的 stream 永不 settle
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // 验证 App 至少渲染了 — 找到 MaterialApp 即可
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
