import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:navidrome_player/providers/server_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent server additions are serialized without losing entries',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(serversListProvider.notifier);

      await Future.wait([
        notifier.addServer(
          name: 'A',
          url: 'http://a',
          username: 'a',
          password: 'a',
          backendUrl: '',
          backendApiKey: '',
        ),
        notifier.addServer(
          name: 'B',
          url: 'http://b',
          username: 'b',
          password: 'b',
          backendUrl: '',
          backendApiKey: '',
        ),
      ]);

      final servers = container.read(serversListProvider);
      expect(servers.map((server) => server.name).toSet(), {'A', 'B'});
      expect(servers.map((server) => server.id).toSet(), hasLength(2));
    },
  );

  test('queued removal cannot delete the server being activated', () async {
    SharedPreferences.setMockInitialValues({
      'servers_list': jsonEncode([
        {
          'id': 'a',
          'name': 'A',
          'url': 'http://a',
          'username': 'a',
          'password': 'a',
          'isActive': true,
        },
        {
          'id': 'b',
          'name': 'B',
          'url': 'http://b',
          'username': 'b',
          'password': 'b',
          'isActive': false,
        },
      ]),
      activeServerIdPreferenceKey: 'a',
      'server_url': 'http://a',
      'server_username': 'a',
      'server_password': 'a',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(serversListProvider.notifier);

    final activate = notifier.setActive('b');
    final remove = notifier.removeServer('b');
    await Future.wait([activate, remove]);

    final servers = container.read(serversListProvider);
    expect(
      servers.any((server) => server.id == 'b' && server.isActive),
      isTrue,
    );
    expect(prefs.getString(activeServerIdPreferenceKey), 'b');
  });

  test(
    'clear forgets the active server credentials but keeps the entry',
    () async {
      SharedPreferences.setMockInitialValues({
        'servers_list': jsonEncode([
          {
            'id': 'a',
            'name': 'A',
            'url': 'http://a',
            'username': 'a',
            'password': 'secret',
            'backendUrl': 'http://cloud',
            'backendApiKey': 'cloud-secret',
            'nasAgentUrl': 'http://nas:8503',
            'nasAgentKey': 'nas-secret',
            'isActive': true,
          },
        ]),
        activeServerIdPreferenceKey: 'a',
        'server_url': 'http://a',
        'server_username': 'a',
        'server_password': 'secret',
        backendApiKeyPreferenceKey('a'): 'cloud-secret',
        nasAgentUrlPreferenceKey('a'): 'http://nas:8503',
        nasAgentKeyPreferenceKey('a'): 'nas-secret',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(serverConfigProvider.notifier).clear();

      final server = container.read(serversListProvider).single;
      expect(server.id, 'a');
      expect(server.password, isEmpty);
      expect(server.backendApiKey, isEmpty);
      expect(server.nasAgentKey, isEmpty);
      expect(prefs.getString('server_password'), isNull);
      expect(prefs.getString(backendApiKeyPreferenceKey('a')), isNull);
      expect(prefs.getString(nasAgentKeyPreferenceKey('a')), isNull);
    },
  );
  test('legacy Cloud key is removed and NAS defaults to port 8504', () async {
    SharedPreferences.setMockInitialValues({
      'servers_list': jsonEncode([
        {
          'id': 'a',
          'name': 'A',
          'url': 'http://music.local:4533',
          'username': 'alice',
          'backendApiKey': 'legacy-shared-key',
          'isActive': true,
        },
      ]),
      activeServerIdPreferenceKey: 'a',
      'server_url': 'http://music.local:4533',
      backendApiKeyPreferenceKey('a'): 'legacy-shared-key',
    });
    final prefs = await SharedPreferences.getInstance();

    await migratePasswordsToSecureStorage(prefs);
    await migrateActiveBackendConfiguration(
      prefs,
      serverId: 'a',
      serverUrl: 'http://music.local:4533',
      serverPassword: 'must-not-be-copied',
    );

    final servers = jsonDecode(prefs.getString('servers_list')!) as List;
    expect((servers.single as Map).containsKey('backendApiKey'), isFalse);
    expect(prefs.getString(backendApiKeyPreferenceKey('a')), isNull);
    expect(
      prefs.getString(nasAgentUrlPreferenceKey('a')),
      'http://music.local:8504',
    );
  });
}
