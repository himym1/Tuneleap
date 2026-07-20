import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';

void main() {
  test(
    'ServerEntry keeps backend configuration separate from Navidrome credentials',
    () {
      const entry = ServerEntry(
        id: 'server-a',
        name: 'A',
        url: 'https://music.example.com',
        username: 'user',
        password: 'nav-password',
        backendUrl: 'https://backend.example.com',
        backendApiKey: 'backend-key',
        isActive: true,
      );

      final json = entry.toJson();
      final restored = ServerEntry.fromJson({
        ...json,
        'password': 'nav-password',
        'backendApiKey': 'backend-key',
      });

      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('backendApiKey'), isFalse);
      expect(restored.backendUrl, 'https://backend.example.com');
      expect(restored.password, 'nav-password');
      expect(restored.backendApiKey, 'backend-key');
    },
  );
}
