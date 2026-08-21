import 'dart:async';

import 'package:dio/dio.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/navidrome_import_provider.dart';
import 'package:navidrome_player/providers/recommendation_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(String id, {String source = 'netease'}) {
  return Song(
    id: id,
    title: 'Title $id',
    album: 'Album',
    albumId: 'album',
    artist: 'Artist',
    artistId: 'artist',
    backend: SongBackend.solara,
    onlineSource: source,
    urlId: 'url-$id',
  );
}

RecommendationItem _item(
  String candidateId, {
  String songId = 's1',
  RecommendationType type = RecommendationType.similar,
}) {
  return RecommendationItem(
    candidateId: candidateId,
    type: type,
    song: _song(songId),
  );
}

RecommendationPage _page({
  required String sessionId,
  required List<RecommendationItem> items,
  String? cursor,
  bool hasMore = true,
  RecommendationMode mode = RecommendationMode.ai,
}) {
  return RecommendationPage(
    sessionId: sessionId,
    mode: mode,
    items: items,
    nextCursor: cursor,
    hasMore: hasMore,
  );
}

class FakeBackendClient extends BackendClient {
  FakeBackendClient() : super(dio: null);

  final List<String> calls = [];
  final List<Map<String, dynamic>> feedbackCalls = [];
  int createCount = 0;
  int itemsCount = 0;
  bool configured = true;
  Object? createError;
  Object? itemsError;
  Object? feedbackError;
  Object? resetError;
  Completer<void>? createGate;
  Completer<void>? itemsGate;
  Completer<void>? feedbackGate;
  List<RecommendationPage> createPages = [];
  List<RecommendationPage> itemPages = [];
  RecommendationFeedbackResponse feedbackResponse =
      const RecommendationFeedbackResponse(accepted: true, duplicate: false);

  @override
  bool get isConfigured => configured;

  @override
  Future<RecommendationPage> createRecommendationSession(
    List<Song> recent, {
    bool refresh = false,
    int pageSize = 20,
    cancelToken,
  }) async {
    calls.add('create:${refresh ? 'refresh' : 'resume'}:${recent.length}');
    createCount++;
    final gate = createGate;
    if (gate != null) await gate.future;
    final error = createError;
    if (error != null) throw error;
    if (createPages.isEmpty) {
      return _page(
        sessionId: 'session-$createCount',
        items: [_item('c-$createCount', songId: 'song-$createCount')],
        cursor: 'cursor-$createCount',
      );
    }
    return createPages.removeAt(0);
  }

  @override
  Future<RecommendationPage> getRecommendationItems(
    String sessionId, {
    String? cursor,
    int limit = 20,
    cancelToken,
  }) async {
    calls.add('items:$sessionId:${cursor ?? ''}');
    itemsCount++;
    final gate = itemsGate;
    if (gate != null) await gate.future;
    final error = itemsError;
    if (error != null) throw error;
    if (itemPages.isEmpty) {
      return _page(
        sessionId: sessionId,
        items: [_item('more-$itemsCount', songId: 'more-$itemsCount')],
        cursor: null,
        hasMore: false,
      );
    }
    return itemPages.removeAt(0);
  }

  @override
  Future<RecommendationFeedbackResponse> sendRecommendationFeedback({
    required String idempotencyKey,
    required String sessionId,
    required String candidateId,
    required RecommendationFeedbackEvent event,
    cancelToken,
  }) async {
    feedbackCalls.add({
      'idempotencyKey': idempotencyKey,
      'sessionId': sessionId,
      'candidateId': candidateId,
      'event': event.name,
    });
    final gate = feedbackGate;
    if (gate != null) await gate.future;
    final error = feedbackError;
    if (error != null) throw error;
    return feedbackResponse;
  }

  @override
  Future<void> resetRecommendationProfile({cancelToken}) async {
    calls.add('reset');
    final error = resetError;
    if (error != null) throw error;
  }
}

class FakeImportService extends NavidromeImportService {
  FakeImportService() : super(backendClient: FakeBackendClient());

  Object? error;
  int calls = 0;

  @override
  Future<NavidromeImportResult> importOnlineSong(
    Song song, {
    bool force = false,
    void Function(NasImportStage stage)? onStage,
  }) async {
    calls++;
    final err = error;
    if (err != null) throw err;
    return const NavidromeImportResult(filename: 'ok.mp3');
  }
}

Future<ProviderContainer> buildContainer({
  required FakeBackendClient client,
  List<Song> recent = const [],
  FakeImportService? importService,
  Map<String, Object> prefs = const {},
  String backendUrl = 'http://backend.local',
  String backendApiKey = 'key',
  String serverId = 'server-a',
}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'http://navidrome.local',
    'server_username': 'user',
    'active_server_id': serverId,
    backendUrlPreferenceKey(serverId): backendUrl,
    ...prefs,
  });
  final preferences = await SharedPreferences.getInstance();
  final importer = importService ?? FakeImportService();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      cachedBackendApiKeyProvider.overrideWith(
        () => _FixedApiKeyNotifier(backendApiKey),
      ),
      backendClientProvider.overrideWithValue(client),
      recommendationRecentSongsProvider.overrideWithValue(recent),
      navidromeImportServiceProvider.overrideWithValue(importer),
    ],
  );
}

class _FixedApiKeyNotifier extends CachedBackendApiKeyNotifier {
  _FixedApiKeyNotifier(this.value);
  final String value;
  @override
  String build() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('state keeps immutable collections and visible filtering', () {
    final item = _item('c1');
    final state = RecommendationState(
      items: [item],
      hiddenCandidateIds: {'c1'},
      pendingCandidateIds: {'c1'},
      importingCandidateIds: {'c2'},
    );
    expect(state.items, isA<List<RecommendationItem>>());
    expect(() => state.items.add(item), throwsUnsupportedError);
    expect(() => state.hiddenCandidateIds.add('x'), throwsUnsupportedError);
    expect(state.visibleItems, isEmpty);
  });

  test('ensureLoaded sends recent history and stores page', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [
            _item('c1', songId: 'a'),
            _item('c2', songId: 'b'),
          ],
          cursor: 'next',
          mode: RecommendationMode.fallback,
        ),
      ];
    final recent = List<Song>.generate(35, (i) => _song('r$i'));
    final container = await buildContainer(client: client, recent: recent);
    addTearDown(container.dispose);

    await container.read(recommendationProvider.notifier).ensureLoaded();
    final state = container.read(recommendationProvider);

    expect(client.calls.single, 'create:resume:30');
    expect(state.sessionId, 's1');
    expect(state.items, hasLength(2));
    expect(state.cursor, 'next');
    expect(state.initialLoading, isFalse);
    expect(state.mode, RecommendationMode.fallback);
  });

  test('refresh replaces session with refresh=true', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 'old',
          items: [_item('c1', songId: 'a')],
          cursor: 'c-old',
        ),
        _page(
          sessionId: 'new',
          items: [_item('c9', songId: 'z')],
          cursor: 'c-new',
        ),
      ];
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);

    await notifier.ensureLoaded();
    await notifier.refresh();
    final state = container.read(recommendationProvider);

    expect(client.calls, ['create:resume:0', 'create:refresh:0']);
    expect(state.sessionId, 'new');
    expect(state.items.single.candidateId, 'c9');
    expect(state.cursor, 'c-new');
    expect(state.mode, RecommendationMode.ai);
  });

  test('loadMore is single-flight and appends unique songs', () async {
    final gate = Completer<void>();
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: 'cur-1',
        ),
      ]
      ..itemPages = [
        _page(
          sessionId: 's1',
          items: [
            _item('c1-dup', songId: 'a'),
            _item('c2', songId: 'b'),
          ],
          cursor: 'cur-2',
        ),
      ]
      ..itemsGate = gate;
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();

    final first = notifier.loadMore();
    final second = notifier.loadMore();
    expect(identical(first, second), isTrue);
    gate.complete();
    await first;

    final state = container.read(recommendationProvider);
    expect(client.itemsCount, 1);
    expect(state.items.map((e) => e.song.storageKey).toList(), [
      'solara:netease:url-a',
      'solara:netease:url-b',
    ]);
    expect(state.cursor, 'cur-2');
  });

  test('stale create response is ignored after newer request starts', () async {
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    final client = FakeBackendClient()
      ..createGate = firstGate
      ..createPages = [
        _page(
          sessionId: 'stale',
          items: [_item('old', songId: 'old')],
          cursor: 'old',
        ),
        _page(
          sessionId: 'fresh',
          items: [_item('new', songId: 'new')],
          cursor: 'new',
        ),
      ];
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);

    final first = notifier.ensureLoaded();
    // Start a refresh while first create is gated; this bumps generation.
    client.createGate = secondGate;
    final second = notifier.refresh();
    firstGate.complete();
    await Future<void>.delayed(Duration.zero);
    secondGate.complete();
    await Future.wait([first, second]);

    final state = container.read(recommendationProvider);
    expect(state.sessionId, 'fresh');
    expect(state.items.single.candidateId, 'new');
  });

  test('410 on loadMore recovers once without loop', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: 'cur',
        ),
        _page(
          sessionId: 's2',
          items: [_item('c2', songId: 'b')],
          cursor: 'cur2',
        ),
      ]
      ..itemsError = const RecommendationApiException(
        code: 'recommendation_session_expired',
        detail: 'expired',
        retryable: false,
        statusCode: 410,
      );
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.loadMore();

    final state = container.read(recommendationProvider);
    expect(client.createCount, 2);
    expect(client.itemsCount, 1);
    expect(state.sessionId, 's2');
    expect(state.items.map((e) => e.candidateId), containsAll(['c1', 'c2']));
    expect(state.loadMoreError, isNull);
  });

  test('retryable feedback keeps UUID and outbox until success', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: null,
          hasMore: false,
        ),
      ]
      ..feedbackError = const RecommendationApiException(
        code: 'recommendation_rate_limited',
        detail: 'slow down',
        retryable: true,
        statusCode: 429,
      );
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.dislike(container.read(recommendationProvider).items.single);

    expect(client.feedbackCalls, hasLength(1));
    final firstKey = client.feedbackCalls.single['idempotencyKey'];
    final prefs = container.read(sharedPreferencesProvider);
    final outboxRaw = prefs.getString(
      'recommendation_outbox::http://backend.local',
    );
    expect(outboxRaw, isNotNull);
    expect(jsonDecode(outboxRaw!), hasLength(1));
    expect(container.read(recommendationProvider).hiddenCandidateIds, {'c1'});
    expect(container.read(recommendationProvider).pendingCandidateIds, {'c1'});

    client.feedbackError = null;
    await notifier.recordFeedback(
      container.read(recommendationProvider).items.single,
      RecommendationFeedbackEvent.disliked,
    );
    expect(client.feedbackCalls, hasLength(2));
    expect(client.feedbackCalls.last['idempotencyKey'], firstKey);
    expect(
      prefs.getString('recommendation_outbox::http://backend.local'),
      isNull,
    );
    expect(container.read(recommendationProvider).pendingCandidateIds, isEmpty);
    expect(container.read(recommendationProvider).hiddenCandidateIds, {'c1'});
  });

  test('definitive dislike rejection restores visibility', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: null,
          hasMore: false,
        ),
      ]
      ..feedbackError = const RecommendationApiException(
        code: 'recommendation_invalid_request',
        detail: 'bad',
        retryable: false,
        statusCode: 400,
      );
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.dislike(container.read(recommendationProvider).items.single);

    final state = container.read(recommendationProvider);
    expect(state.hiddenCandidateIds, isEmpty);
    expect(state.pendingCandidateIds, isEmpty);
    expect(state.error, isA<RecommendationApiException>());
  });

  test('import success emits imported; failure emits nothing', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: null,
          hasMore: false,
        ),
      ];
    final importer = FakeImportService();
    final container = await buildContainer(
      client: client,
      importService: importer,
    );
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    final item = container.read(recommendationProvider).items.single;

    await notifier.importItem(item);
    expect(importer.calls, 1);
    expect(client.feedbackCalls.single['event'], 'imported');

    importer.error = StateError('import failed');
    client.feedbackCalls.clear();
    await expectLater(notifier.importItem(item), throwsStateError);
    expect(client.feedbackCalls, isEmpty);
    expect(
      container.read(recommendationProvider).importingCandidateIds,
      isEmpty,
    );
  });

  test('reset clears provider state and only current backend outbox', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: 'c',
        ),
      ];
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final prefs = container.read(sharedPreferencesProvider);
    await prefs.setString(
      'recommendation_outbox::http://backend.local',
      jsonEncode([
        {
          'idempotencyKey': '11111111-1111-4111-8111-111111111111',
          'sessionId': 's1',
          'candidateId': 'c1',
          'event': 'disliked',
        },
      ]),
    );
    await prefs.setString(
      'recommendation_outbox::http://other.local',
      jsonEncode([
        {
          'idempotencyKey': '22222222-2222-4222-8222-222222222222',
          'sessionId': 's9',
          'candidateId': 'c9',
          'event': 'played',
        },
      ]),
    );
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    // Allow build-time outbox retry to finish before reset/dispose.
    await Future<void>.delayed(Duration.zero);
    await notifier.reset();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(recommendationProvider);
    expect(client.calls, contains('reset'));
    expect(state.sessionId, isNull);
    expect(state.items, isEmpty);
    expect(
      prefs.getString('recommendation_outbox::http://backend.local'),
      isNull,
    );
    expect(
      prefs.getString('recommendation_outbox::http://other.local'),
      isNotNull,
    );
  });

  test('network DioException keeps outbox and UUID for retry', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: null,
          hasMore: false,
        ),
      ]
      ..feedbackError = DioException(
        requestOptions: RequestOptions(path: '/v1/recommendations/feedback'),
        type: DioExceptionType.connectionTimeout,
      );
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.dislike(container.read(recommendationProvider).items.single);

    final prefs = container.read(sharedPreferencesProvider);
    final outbox =
        jsonDecode(
              prefs.getString('recommendation_outbox::http://backend.local')!,
            )
            as List<dynamic>;
    expect(outbox, hasLength(1));
    expect(container.read(recommendationProvider).hiddenCandidateIds, {'c1'});
    expect(container.read(recommendationProvider).pendingCandidateIds, {'c1'});

    final firstKey = client.feedbackCalls.single['idempotencyKey'];
    client.feedbackError = null;
    await notifier.recordFeedback(
      container.read(recommendationProvider).items.single,
      RecommendationFeedbackEvent.disliked,
    );
    expect(client.feedbackCalls.last['idempotencyKey'], firstKey);
    expect(
      prefs.getString('recommendation_outbox::http://backend.local'),
      isNull,
    );
  });

  test('outbox delivery does not cross backend scope after switch', () async {
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [_item('c1', songId: 'a')],
          cursor: null,
          hasMore: false,
        ),
      ]
      ..feedbackError = const RecommendationApiException(
        code: 'recommendation_rate_limited',
        detail: 'slow',
        retryable: true,
        statusCode: 429,
      );
    final container = await buildContainer(
      client: client,
      backendUrl: 'http://backend-a.local',
    );
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.dislike(container.read(recommendationProvider).items.single);
    expect(client.feedbackCalls, hasLength(1));

    // Switch active backend URL in prefs + invalidate config/notifier scope.
    final prefs = container.read(sharedPreferencesProvider);
    await prefs.setString(
      backendUrlPreferenceKey('server-a'),
      'http://backend-b.local',
    );
    container.invalidate(serverConfigProvider);
    container.invalidate(recommendationProvider);
    await Future<void>.delayed(Duration.zero);

    // New scope should not flush old outbox against the new backend client.
    final before = client.feedbackCalls.length;
    await container.read(recommendationProvider.notifier).ensureLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(client.feedbackCalls.length, before);
    expect(
      prefs.getString('recommendation_outbox::http://backend-a.local'),
      isNotNull,
    );
  });

  test('concurrent feedback preserves both outbox records', () async {
    final gate = Completer<void>();
    final client = FakeBackendClient()
      ..createPages = [
        _page(
          sessionId: 's1',
          items: [
            _item('c1', songId: 'a'),
            _item('c2', songId: 'b'),
          ],
          cursor: null,
          hasMore: false,
        ),
      ]
      ..feedbackGate = gate
      ..feedbackError = const RecommendationApiException(
        code: 'recommendation_rate_limited',
        detail: 'slow',
        retryable: true,
        statusCode: 429,
      );
    final container = await buildContainer(client: client);
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    await notifier.ensureLoaded();
    final items = container.read(recommendationProvider).items;

    final first = notifier.dislike(items[0]);
    final second = notifier.dislike(items[1]);
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([first, second]);

    final prefs = container.read(sharedPreferencesProvider);
    final outbox =
        jsonDecode(
              prefs.getString('recommendation_outbox::http://backend.local')!,
            )
            as List<dynamic>;
    expect(outbox, hasLength(2));
    expect(outbox.map((e) => (e as Map)['candidateId']).toSet(), {'c1', 'c2'});
  });

  test('api key rotation rejects stale create response', () async {
    final gate = Completer<void>();
    final client = FakeBackendClient()
      ..createGate = gate
      ..createPages = [
        _page(
          sessionId: 'stale-key',
          items: [_item('old', songId: 'old')],
          cursor: 'old',
        ),
        _page(
          sessionId: 'fresh-key',
          items: [_item('new', songId: 'new')],
          cursor: 'new',
        ),
      ];
    final container = await buildContainer(
      client: client,
      backendApiKey: 'key-old',
    );
    addTearDown(container.dispose);
    final notifier = container.read(recommendationProvider.notifier);
    final pending = notifier.ensureLoaded();

    container.read(cachedBackendApiKeyProvider.notifier).set('key-new');
    container.invalidate(serverConfigProvider);
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);

    // Either rebuilt empty or later fresh load; never keep stale-key session.
    final state = container.read(recommendationProvider);
    expect(state.sessionId, isNot('stale-key'));
  });
}
