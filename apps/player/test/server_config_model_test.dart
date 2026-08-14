import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';

void main() {
  test('ServerEntry strips retired Cloud shared keys from client storage', () {
    const entry = ServerEntry(
      id: 'server-a',
      name: 'A',
      url: 'https://music.example.com',
      username: 'user',
      password: 'nav-password',
      backendUrl: 'https://cloud.example.com',
      backendApiKey: 'cloud-key',
      nasAgentUrl: 'http://nas.example.com:8503',
      nasAgentKey: 'nas-key',
      isActive: true,
    );

    final json = entry.toJson();
    final restored = ServerEntry.fromJson({
      ...json,
      'password': 'nav-password',
      'backendApiKey': 'cloud-key',
      'nasAgentKey': 'nas-key',
    });

    expect(json.containsKey('password'), isFalse);
    expect(json.containsKey('backendApiKey'), isFalse);
    expect(json.containsKey('nasAgentKey'), isFalse);
    expect(restored.backendUrl, 'https://cloud.example.com');
    expect(restored.backendApiKey, isEmpty);
    expect(restored.nasAgentUrl, 'http://nas.example.com:8503');
    expect(restored.nasAgentKey, 'nas-key');
    expect(restored.password, 'nav-password');
  });
}
