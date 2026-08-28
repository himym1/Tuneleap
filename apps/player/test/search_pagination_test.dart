import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/music_capabilities.dart';
import 'package:navidrome_player/api/models/search_page.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/online_source_preferences.dart';
import 'package:navidrome_player/providers/search_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PagedBackendClient extends BackendClient {
  final pages = <int>[];
  final sources = <String?>[];
  final providers = <String?>[];
  final counts = <int>[];

  @override
  Future<CloudSearchPage> searchSongs(
    String query, {
    String? source,
    String? provider,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    pages.add(page);
    sources.add(source);
    providers.add(provider);
    counts.add(count);
    if (page == 1) {
      return CloudSearchPage(
        songs: [
          _song('0', source: 'migu'),
          _song('1', source: 'migu'),
        ],
        hasMore: true,
      );
    }
    if (page == 2) {
      return CloudSearchPage(
        songs: [
          _song('1', source: 'migu'),
          _song('2', source: 'migu'),
        ],
        hasMore: true,
      );
    }
    return const CloudSearchPage(songs: [], hasMore: false);
  }
}

class _RepeatingBackendClient extends BackendClient {
  final pages = <int>[];

  @override
  Future<CloudSearchPage> searchSongs(
    String query, {
    String? source,
    String? provider,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    pages.add(page);
    return CloudSearchPage(songs: [_song('same')], hasMore: true);
  }
}

class _DelayedBackendClient extends BackendClient {
  final secondPage = Completer<List<Song>>();

  @override
  Future<CloudSearchPage> searchSongs(
    String query, {
    String? source,
    String? provider,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    if (query == 'new') {
      return CloudSearchPage(songs: [_song('new')], hasMore: false);
    }
    if (page == 1) {
      return CloudSearchPage(
        songs: [for (var index = 0; index < 30; index++) _song('$index')],
        hasMore: true,
      );
    }
    return CloudSearchPage(songs: await secondPage.future, hasMore: true);
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
      onlineAdapterPreferenceKey('server-a'): 'gdstudio',
    });
    final prefs = await SharedPreferences.getInstance();
    final backend = _PagedBackendClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendClientProvider.overrideWithValue(backend),
        musicCapabilitiesProvider.overrideWith(
          (ref) async => const MusicCapabilities(
            adapters: [
              MusicAdapterCapability(
                id: 'gdstudio',
                sources: ['netease', 'tencent', 'kugou'],
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(searchProvider('migu'), (_, _) {});
    addTearDown(subscription.close);
    await container.read(musicCapabilitiesProvider.future);

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
    expect(backend.providers, ['gdstudio', 'gdstudio', 'gdstudio']);
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

  test('server hasMore false stops after the first page', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'server-a',
      'server_url': 'http://music.local',
    });
    final prefs = await SharedPreferences.getInstance();
    final backend = _TerminalFirstPageClient();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendClientProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(searchProvider('tencent'), (_, _) {});
    addTearDown(subscription.close);

    final notifier = container.read(searchProvider('tencent').notifier);
    await notifier.search('query');
    await notifier.loadMore();

    final state = container.read(searchProvider('tencent'));
    expect(backend.pages, [1]);
    expect(state.songs, hasLength(2));
    expect(state.hasMore, isFalse);
  });

  test('searchIfAbsent skips a query that already has results', () async {
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
    final subscription = container.listen(searchProvider('kugou'), (_, _) {});
    addTearDown(subscription.close);

    final notifier = container.read(searchProvider('kugou').notifier);
    await notifier.searchIfAbsent('周杰伦');
    await notifier.searchIfAbsent('周杰伦');
    await notifier.searchIfAbsent('林俊杰');

    expect(backend.sources, ['kugou', 'kugou']);
    expect(container.read(searchProvider('kugou')).songs, hasLength(2));
  });

  test('search asks for the capability page size', () async {
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
        musicCapabilitiesProvider.overrideWith(
          (ref) async => const MusicCapabilities(
            adapters: [
              MusicAdapterCapability(id: 'gdstudio', sources: ['netease']),
            ],
            sources: {
              'netease': SourceSearchWindow(maxCount: 50, paginates: true),
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(searchProvider('netease'), (_, _) {});
    addTearDown(subscription.close);
    await container.read(musicCapabilitiesProvider.future);

    await container.read(searchProvider('netease').notifier).search('query');

    expect(backend.counts, [50]);
    expect(backend.pages, [1]);
  });
}

class _TerminalFirstPageClient extends BackendClient {
  final pages = <int>[];

  @override
  Future<CloudSearchPage> searchSongs(
    String query, {
    String? source,
    String? provider,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    pages.add(page);
    return CloudSearchPage(
      songs: [
        _song('0', source: 'tencent'),
        _song('1', source: 'tencent'),
      ],
      hasMore: false,
    );
  }
}
