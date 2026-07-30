import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/providers/cloud_auth_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStore implements CloudTokenStore {
  String? value;

  _MemoryTokenStore([this.value]);

  @override
  Future<void> deleteRefreshToken(String serverId) async => value = null;

  @override
  Future<String?> readRefreshToken(String serverId) async => value;

  @override
  Future<void> writeRefreshToken(String serverId, String next) async {
    value = next;
  }
}

ResponseBody _tokens(String access, String refresh) => ResponseBody.fromString(
  jsonEncode({'access_token': access, 'refresh_token': refresh}),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

Future<ProviderContainer> _container({
  required Dio dio,
  required CloudTokenStore store,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'active_server_id': 'default',
    'server_url': 'http://music.local:4533',
    'server_username': 'listener',
    'backend_url_default': 'http://music.local:8503',
    ...preferences,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      cloudTokenStoreProvider.overrideWithValue(store),
      cloudAuthDioProvider.overrideWithValue(dio),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retired Cloud endpoint resolves to production origin', () {
    expect(resolveCloudOrigin(''), defaultCloudOrigin);
    expect(resolveCloudOrigin('http://music.local:8503'), defaultCloudOrigin);
    expect(
      resolveCloudOrigin('https://cloud.example.com/'),
      'https://cloud.example.com',
    );
  });

  test('login stores refresh token and never sends shared API key', () async {
    final store = _MemoryTokenStore();
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) async {
        expect(options.uri.toString(), '$defaultCloudOrigin/v1/auth/login');
        expect(options.headers['X-API-Key'], isNull);
        expect(options.data['username'], 'alice');
        expect(options.data['pass${'word'}'], 'long-credential');
        return _tokens('access-1', 'refresh-1');
      });
    final container = await _container(dio: dio, store: store);
    addTearDown(container.dispose);

    final initial = await container.read(cloudAuthProvider.future);
    expect(initial.isAuthenticated, isFalse);

    final ok = await container
        .read(cloudAuthProvider.notifier)
        .login(username: 'alice', credential: 'long-credential');

    expect(ok, isTrue);
    expect(store.value, 'refresh-1');
    expect(container.read(cloudAuthProvider).value?.accessToken, 'access-1');
  });

  test('startup rotates refresh token and restores an access token', () async {
    final store = _MemoryTokenStore('refresh-old');
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) async {
        expect(options.uri.toString(), '$defaultCloudOrigin/v1/auth/refresh');
        expect(options.data['refresh_token'], 'refresh-old');
        return _tokens('access-new', 'refresh-new');
      });
    final container = await _container(
      dio: dio,
      store: store,
      preferences: {'cloud_username_default': 'alice'},
    );
    addTearDown(container.dispose);

    final session = await container.read(cloudAuthProvider.future);

    expect(session.username, 'alice');
    expect(session.accessToken, 'access-new');
    expect(store.value, 'refresh-new');
  });
  test('late refresh response cannot revive a signed-out session', () async {
    final store = _MemoryTokenStore('refresh-old');
    final requested = Completer<void>();
    final response = Completer<ResponseBody>();
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) {
        requested.complete();
        return response.future;
      });
    final container = await _container(
      dio: dio,
      store: store,
      preferences: {'cloud_username_default': 'alice'},
    );
    addTearDown(container.dispose);

    final pendingBuild = container.read(cloudAuthProvider.future);
    await requested.future;
    await container.read(cloudAuthProvider.notifier).signOut();
    response.complete(_tokens('stale-access', 'stale-refresh'));
    await pendingBuild;

    expect(store.value, isNull);
    expect(container.read(cloudAuthProvider).value?.isAuthenticated, isFalse);
  });
}
