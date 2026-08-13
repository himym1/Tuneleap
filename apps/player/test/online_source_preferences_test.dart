import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/music_capabilities.dart';
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
  test('adapter capabilities filter enabled platform tabs', () {
    expect(
      catalogSourcesSupportedBy(
        const MusicCapabilities(
          adapters: [
            MusicAdapterCapability(
              id: 'gdstudio',
              sources: ['netease', 'kugou', 'migu', 'joox', 'kuwo'],
            ),
          ],
        ),
        'gdstudio',
      ),
      ['netease', 'kugou', 'migu', 'joox'],
    );
    expect(
      filterEnabledOnlineSources(
        ['netease', 'tencent', 'migu'],
        ['netease', 'kugou', 'migu', 'joox'],
      ),
      ['netease', 'migu'],
    );
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

  test('adapter preference is isolated by server id', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://a.local',
      onlineAdapterPreferenceKey('server-a'): 'gdstudio',
      onlineAdapterPreferenceKey('server-b'): 'chksz',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onlineSearchAdapterProvider), 'gdstudio');
    await container
        .read(onlineSearchAdapterProvider.notifier)
        .setProvider('chksz');
    expect(prefs.getString(onlineAdapterPreferenceKey('server-a')), 'chksz');
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
