import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/auth_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSubsonicClient extends SubsonicClient {
  _FakeSubsonicClient(this.result);

  bool result;
  int pingCalls = 0;

  @override
  Future<bool> ping() async {
    pingCalls++;
    return result;
  }
}

class _ControlledSubsonicClient extends _FakeSubsonicClient {
  _ControlledSubsonicClient(this.results) : super(false);

  final List<Completer<bool>> results;
  final List<Completer<void>> calls = [];

  @override
  Future<bool> ping() {
    pingCalls++;
    final index = calls.length;
    final called = Completer<void>()..complete();
    calls.add(called);
    return results[index].future;
  }
}

Future<(ProviderContainer, SharedPreferences)> _container({
  required Map<String, Object> values,
  required _FakeSubsonicClient client,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      subsonicClientProvider.overrideWithValue(client),
    ],
  );
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configured server is authenticated after startup ping', () async {
    final client = _FakeSubsonicClient(true);
    final (container, _) = await _container(
      values: {
        'server_url': 'http://navidrome.local',
        'server_username': 'user',
      },
      client: client,
    );
    addTearDown(container.dispose);

    expect(await container.read(authProvider.future), AuthStatus.authenticated);
    expect(client.pingCalls, 1);
  });

  test('explicit sign out skips automatic login on next startup', () async {
    final client = _FakeSubsonicClient(true);
    final (container, _) = await _container(
      values: {
        'server_url': 'http://navidrome.local',
        'server_username': 'user',
        authSignedOutPreferenceKey: true,
      },
      client: client,
    );
    addTearDown(container.dispose);

    expect(
      await container.read(authProvider.future),
      AuthStatus.unauthenticated,
    );
    expect(client.pingCalls, 0);
  });

  test(
    'sign out preserves server configuration and marks session signed out',
    () async {
      final client = _FakeSubsonicClient(true);
      final (container, prefs) = await _container(
        values: {
          'server_url': 'http://navidrome.local',
          'server_username': 'user',
          'server_password': 'secret',
        },
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).value, AuthStatus.unauthenticated);
      expect(prefs.getBool(authSignedOutPreferenceKey), isTrue);
      expect(prefs.getString('server_url'), 'http://navidrome.local');
      expect(prefs.getString('server_username'), 'user');
      expect(prefs.getString('server_password'), 'secret');
    },
  );

  test(
    'successful sign in saves configuration and clears signed-out marker',
    () async {
      final client = _FakeSubsonicClient(true);
      final (container, prefs) = await _container(
        values: {authSignedOutPreferenceKey: true},
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final authenticated = await container
          .read(authProvider.notifier)
          .signIn(
            url: 'http://navidrome.local',
            username: 'user',
            password: 'secret',
          );

      expect(authenticated, isTrue);
      expect(container.read(authProvider).value, AuthStatus.authenticated);
      expect(prefs.getBool(authSignedOutPreferenceKey), isNull);
      expect(prefs.getString('server_url'), 'http://navidrome.local');
      expect(prefs.getString('server_username'), 'user');
    },
  );

  test(
    'authentication failure changes state without deleting configuration',
    () async {
      final client = _FakeSubsonicClient(true);
      final (container, prefs) = await _container(
        values: {
          'server_url': 'http://navidrome.local',
          'server_username': 'user',
        },
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      container.read(authProvider.notifier).authenticationFailed();

      expect(container.read(authProvider).value, AuthStatus.unauthenticated);
      expect(prefs.getString('server_url'), 'http://navidrome.local');
    },
  );
  test(
    'latest server activation wins when pings finish out of order',
    () async {
      final firstPing = Completer<bool>();
      final secondPing = Completer<bool>();
      final client = _ControlledSubsonicClient([firstPing, secondPing]);
      final (container, prefs) = await _container(
        values: {
          authSignedOutPreferenceKey: true,
          'servers_list': jsonEncode([
            {
              'id': 'a',
              'name': 'A',
              'url': 'http://a',
              'username': 'a',
              'isActive': true,
            },
            {
              'id': 'b',
              'name': 'B',
              'url': 'http://b',
              'username': 'b',
              'isActive': false,
            },
          ]),
        },
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final first = container.read(authProvider.notifier).activateServer('a');
      while (client.pingCalls < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      final second = container.read(authProvider.notifier).activateServer('b');
      while (client.pingCalls < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      secondPing.complete(true);
      expect(await second, isTrue);
      firstPing.complete(false);
      expect(await first, isFalse);

      expect(container.read(authProvider).value, AuthStatus.authenticated);
      expect(prefs.getString('active_server_id'), 'b');
    },
  );

  test('sign out cannot be undone by an in-flight server activation', () async {
    final ping = Completer<bool>();
    final client = _ControlledSubsonicClient([ping]);
    final (container, prefs) = await _container(
      values: {
        authSignedOutPreferenceKey: true,
        'servers_list': jsonEncode([
          {
            'id': 'a',
            'name': 'A',
            'url': 'http://a',
            'username': 'a',
            'isActive': true,
          },
        ]),
      },
      client: client,
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    final activation = container
        .read(authProvider.notifier)
        .activateServer('a');
    while (client.pingCalls < 1) {
      await Future<void>.delayed(Duration.zero);
    }
    await container.read(authProvider.notifier).signOut();
    ping.complete(true);

    expect(await activation, isFalse);
    expect(container.read(authProvider).value, AuthStatus.unauthenticated);
    expect(prefs.getBool(authSignedOutPreferenceKey), isTrue);
  });
}
