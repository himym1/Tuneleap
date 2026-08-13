import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/online_source_preferences.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sanitizeOnlineSources maps qq and keeps catalog order defaults', () {
    expect(sanitizeOnlineSources(['qq', 'KUGOU', 'unknown']), [
      'tencent',
      'kugou',
    ]);
    expect(sanitizeOnlineSources(const []), kDefaultOnlineSources);
  });

  test('disabling the last source is rejected', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(onlineSourcePreferencesProvider.notifier);
    await notifier.setEnabled('tencent', enabled: false);
    await notifier.setEnabled('kugou', enabled: false);
    final kept = await notifier.setEnabled('netease', enabled: false);

    expect(kept, isFalse);
    expect(container.read(onlineSourcePreferencesProvider), ['netease']);
  });

  test('preferences are isolated by server id', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://a.local',
      onlineSourcesPreferenceKey('server-a'): ['netease'],
      onlineSourcesPreferenceKey('server-b'): ['kugou', 'migu'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onlineSourcePreferencesProvider), ['netease']);
  });
}
