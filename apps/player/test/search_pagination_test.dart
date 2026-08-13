import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/online_source_preferences.dart';
import 'package:navidrome_player/providers/search_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PagedBackendClient extends BackendClient {
  final pages = <int>[];
  final sources = <String?>[];

  @override
  Future<List<Song>> searchSongs(
    String query, {
    String? source,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    pages.add(page);
    sources.add(source);
    if (page == 1) {
      return [_song('0', source: 'migu'), _song('1', source: 'migu')];
    }
    if (page == 2) {
      return [_song('1', source: 'migu'), _song('2', source: 'migu')];
    }
    return [];
  }
}

class _RepeatingBackendClient extends BackendClient {
  final pages = <int>[];

  @override
  Future<List<Song>> searchSongs(
    String query, {
    String? source,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    pages.add(page);
    return [_song('same')];
  }
}

class _DelayedBackendClient extends BackendClient {
  final secondPage = Completer<List<Song>>();

  @override
  Future<List<Song>> searchSongs(
    String query, {
    String? source,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (query == 'new') return [_song('new')];
    if (page == 1) {
      return [for (var index = 0; index < 30; index++) _song('$index')];
    }
    return secondPage.future;
  }
}

Song _song(String id, {String? source}) => Song(
  id: id,
  title: 'Song $id',
  album: 'Album',
  albumId: 'album',
  artist: 'Artist',
  artistId: 'artist',
  backend: source == null ? SongBackend.subsonic : SongBackend.solara,
  onlineSource: source,
  urlId: source == null ? null : id,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('short pages keep loading until an empty page', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
    });
    final prefs = await SharedPreferences.getInstance();
    final backend = _PagedBackendClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendClientProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(searchProvider('migu'), (_, _) {});
    addTearDown(subscription.close);

    final notifier = container.read(searchProvider('migu').notifier);
    await notifier.search('query');
    expect(container.read(searchProvider('migu')).songs, hasLength(2));
    expect(container.read(searchProvider('migu')).hasMore, isTrue);

    await notifier.loadMore();

    var state = container.read(searchProvider('migu'));
    expect(backend.pages, [1, 2]);
    expect(backend.sources, ['migu', 'migu']);
    expect(state.songs.map((song) => song.id), ['0', '1', '2']);
    expect(state.hasMore, isTrue);

    await notifier.loadMore();

    state = container.read(searchProvider('migu'));
    expect(backend.pages, [1, 2, 3]);
    expect(backend.sources, ['migu', 'migu', 'migu']);
    expect(state.songs, hasLength(3));
    expect(state.hasMore, isFalse);
    expect(state.loadingMore, isFalse);
  });

  test('a page with no new songs stops pagination', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
    });
    final prefs = await SharedPreferences.getInstance();
    final backend = _RepeatingBackendClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendClientProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(searchProvider('netease'), (_, _) {});
    addTearDown(subscription.close);

    final notifier = container.read(searchProvider('netease').notifier);
    await notifier.search('query');
    await notifier.loadMore();

    final state = container.read(searchProvider('netease'));
    expect(backend.pages, [1, 2]);
    expect(state.songs.map((song) => song.id), ['same']);
    expect(state.hasMore, isFalse);
    expect(state.loadingMore, isFalse);
  });

  test('late loadMore response cannot replace a newer search', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
    });
    final prefs = await SharedPreferences.getInstance();
    final backend = _DelayedBackendClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendClientProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(searchProvider('netease'), (_, _) {});
    addTearDown(subscription.close);

    final notifier = container.read(searchProvider('netease').notifier);
    await notifier.search('old');
    final pending = notifier.loadMore();
    await Future<void>.delayed(Duration.zero);
    await notifier.search('new');
    backend.secondPage.complete([_song('old-next')]);
    await pending;

    final state = container.read(searchProvider('netease'));
    expect(state.songs.map((song) => song.id), ['new']);
    expect(state.loadingMore, isFalse);
  });

  test('searchEnabledSources pins each configured platform', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
      onlineSourcesPreferenceKey('server-a'): ['netease', 'tencent'],
    });
    final prefs = await SharedPreferences.getInstance();
    final backend = _PagedBackendClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendClientProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    container.listen(searchProvider('netease'), (_, _) {});
    container.listen(searchProvider('tencent'), (_, _) {});

    final sources = container.read(onlineSourcePreferencesProvider);
    for (final source in sources) {
      await container.read(searchProvider(source).notifier).search('query');
    }

    expect(backend.sources, ['netease', 'tencent']);
    expect(sources, ['netease', 'tencent']);
  });
}
