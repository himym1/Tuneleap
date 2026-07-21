import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/backend_client.dart';

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.onFetch);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  )
  onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

Map<String, dynamic> _pageJson({
  String sessionId = 'session-1',
  String mode = 'ai',
  bool hasMore = true,
  String? nextCursor = 'cursor-1',
}) {
  return {
    'contractVersion': 1,
    'sessionId': sessionId,
    'mode': mode,
    'items': [
      {
        'candidateId': 'candidate-1',
        'recommendationType': 'similar',
        'song': {
          'id': 'track-1',
          'title': 'Track',
          'album': 'Album',
          'albumId': 'album-1',
          'artist': 'Artist',
          'artistId': 'artist-1',
          'backend': 'solara',
          'onlineSource': 'netease',
          'urlId': 'url-1',
        },
      },
    ],
    'nextCursor': nextCursor,
    'hasMore': hasMore,
  };
}

Song _song({
  required String id,
  SongBackend backend = SongBackend.subsonic,
  String? onlineSource,
  String? urlId,
}) {
  return Song(
    id: id,
    title: 'Title $id',
    album: 'Album $id',
    albumId: 'album-$id',
    artist: 'Artist $id',
    artistId: 'artist-$id',
    backend: backend,
    onlineSource: onlineSource,
    urlId: urlId,
  );
}

void main() {
  group('BackendClient', () {
    test('inferBaseUrl reuses host and replaces port', () {
      expect(
        BackendClient.inferBaseUrl('http://192.168.1.10:4533'),
        'http://192.168.1.10:8503',
      );
      expect(
        BackendClient.inferBaseUrl('https://music.example.com'),
        'https://music.example.com:8503',
      );
      expect(BackendClient.inferBaseUrl('not-a-url'), '');
    });

    test('configure clears a previously set backend API key', () {
      final dio = Dio();
      final client = BackendClient(dio: dio);

      client.configure(baseUrl: 'http://backend', apiKey: 'secret');
      expect(dio.options.headers['X-API-Key'], 'secret');

      client.configure(baseUrl: 'http://backend');
      expect(dio.options.headers.containsKey('X-API-Key'), isFalse);
    });

    test(
      'searchSongs parses Solara search response into online songs',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            expect(options.path, 'http://nas:10086/proxy');
            expect(options.queryParameters['types'], 'search');
            expect(options.queryParameters['source'], 'netease');
            return _jsonBody([
              {
                'id': '5257138',
                'name': '屋顶',
                'artist': ['周杰伦', '温岚'],
                'album': '男女情歌对唱冠军全记录',
                'pic_id': '109951165671182684',
                'url_id': '5257138',
                'lyric_id': '5257138',
                'source': 'netease',
              },
            ]);
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://nas:10086');

        final songs = await client.searchSongs(
          '屋顶',
          source: 'netease',
          count: 1,
          page: 1,
        );

        expect(songs, hasLength(1));
        expect(songs.first.isOnline, isTrue);
        expect(songs.first.onlineSource, 'netease');
        expect(songs.first.storageKey, 'solara:netease:5257138');
      },
    );

    test('getPlaybackUrl maps bitrate to Solara quality parameter', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody({'url': 'https://cdn.example.com/song.mp3'});
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');
      const targetSong = Song(
        id: '228908',
        title: '晴天',
        album: '',
        albumId: '',
        artist: '周杰伦',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'kuwo',
      );

      final url = await client.getPlaybackUrl(targetSong, maxBitRate: 192);

      expect(url, 'https://cdn.example.com/song.mp3');
      expect(captured.queryParameters['types'], 'url');
      expect(captured.queryParameters['source'], 'kuwo');
      expect(captured.queryParameters['br'], '192');
    });

    test('buildCoverProxyUrl keeps Solara proxy on same host', () {
      final client = BackendClient()..configure(baseUrl: 'http://nas:10086');
      const song = Song(
        id: '1',
        title: 'Track',
        album: '',
        albumId: '',
        artist: 'Artist',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'netease',
        coverArt: '109951166681216835',
      );

      final url = client.buildCoverProxyUrl(song, size: 640);
      final uri = Uri.parse(url);

      expect(
        '${uri.scheme}://${uri.host}:${uri.port}${uri.path}',
        'http://nas:10086/proxy',
      );
      expect(uri.queryParameters['types'], 'pic');
      expect(uri.queryParameters['id'], '109951166681216835');
      expect(uri.queryParameters['source'], 'netease');
      expect(uri.queryParameters['size'], '640');
      expect(uri.queryParameters['s'], isNotEmpty);
    });

    test('queueNasDownload posts expected payload', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          expect(options.method, 'POST');
          return _jsonBody({'success': true, 'message': 'queued'});
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');

      final message = await client.queueNasDownload(
        url: 'https://cdn.example.com/song.flac',
        filename: 'solara_netease_1.flac',
        song: {'id': '1', 'name': 'Track'},
        picUrl: 'http://nas:10086/proxy?types=pic&id=1',
      );

      expect(message, 'queued');
      expect(captured.path, 'http://nas:10086/api/nas-download');
      expect(captured.data['url'], 'https://cdn.example.com/song.flac');
      expect(captured.data['filename'], 'solara_netease_1.flac');
      expect(captured.data['song'], {'id': '1', 'name': 'Track'});
      expect(captured.data['picUrl'], 'http://nas:10086/proxy?types=pic&id=1');
    });

    test('getRawLyrics sends fallback song context', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          expect(options.queryParameters['types'], 'lyric');
          expect(options.queryParameters['name'], '屋顶');
          expect(options.queryParameters['artist'], '周杰伦');
          return _jsonBody({'lyric': '[00:01]第一句'});
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');
      const song = Song(
        id: '5257138',
        title: '屋顶',
        album: '',
        albumId: '',
        artist: '周杰伦',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'joox',
      );

      expect(await client.getRawLyrics(song), '[00:01]第一句');
    });

    test('getLyrics parses lrc timestamps into LyricsList', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          expect(options.queryParameters['types'], 'lyric');
          expect(options.queryParameters['name'], '屋顶');
          expect(options.queryParameters['artist'], '周杰伦');
          return _jsonBody({'lyric': '[00:01.23]第一句\n[00:02.50]第二句\n纯文本结尾'});
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');
      const song = Song(
        id: '5257138',
        title: '屋顶',
        album: '',
        albumId: '',
        artist: '周杰伦',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'netease',
      );

      final lyrics = await client.getLyrics(song);

      expect(lyrics, isNotNull);
      expect(lyrics!.synced, isTrue);
      expect(lyrics.lines, hasLength(3));
      expect(lyrics.lines[0].text, '第一句');
      expect(lyrics.lines[0].startMs, 1230);
      expect(lyrics.lines[2].text, '纯文本结尾');
      expect(lyrics.lines[2].startMs, isNull);
    });
  });

  group('BackendClient recommendations', () {
    test(
      'create session posts body fields and truncates recent to 30',
      () async {
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            captured = options;
            return _jsonBody(_pageJson());
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://nas:10086', apiKey: 'secret-key');

        final recent = <Song>[
          for (var i = 0; i < 35; i++)
            _song(
              id: 'id-$i',
              backend: i.isEven ? SongBackend.subsonic : SongBackend.solara,
              onlineSource: i.isEven ? null : 'netease',
              urlId: i.isEven ? null : 'url-$i',
            ),
        ];

        final page = await client.createRecommendationSession(
          recent,
          refresh: true,
          pageSize: 7,
        );

        expect(page.sessionId, 'session-1');
        expect(page.mode, RecommendationMode.ai);
        expect(captured.method, 'POST');
        expect(captured.path, 'http://nas:10086/v1/recommendations/sessions');
        expect(captured.headers['X-API-Key'], 'secret-key');
        expect(captured.queryParameters, isEmpty);
        expect(captured.data['refresh'], isTrue);
        expect(captured.data['pageSize'], 7);
        final sentRecent = captured.data['recent'] as List<dynamic>;
        expect(sentRecent, hasLength(30));
        expect(sentRecent.first, {
          'title': 'Title id-0',
          'artist': 'Artist id-0',
          'album': 'Album id-0',
          'source': 'subsonic',
          'sourceId': 'id-0',
        });
        expect(sentRecent[1], {
          'title': 'Title id-1',
          'artist': 'Artist id-1',
          'album': 'Album id-1',
          'source': 'netease',
          'sourceId': 'url-1',
        });
        for (final item in sentRecent) {
          expect((item as Map).keys.toSet(), {
            'title',
            'artist',
            'album',
            'source',
            'sourceId',
          });
        }
      },
    );

    test('get items uses path session and optional cursor', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody(
            _pageJson(mode: 'fallback', hasMore: false, nextCursor: null),
          );
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');

      final page = await client.getRecommendationItems(
        'session-xyz',
        cursor: 'cursor-abc',
        limit: 3,
      );

      expect(page.mode, RecommendationMode.fallback);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
      expect(captured.method, 'GET');
      expect(
        captured.path,
        'http://nas:10086/v1/recommendations/sessions/session-xyz/items',
      );
      expect(captured.queryParameters['limit'], 3);
      expect(captured.queryParameters['cursor'], 'cursor-abc');
    });

    test('feedback posts all five events and parses response', () async {
      final events = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          expect(options.method, 'POST');
          expect(options.path, 'http://nas:10086/v1/recommendations/feedback');
          expect(options.data['sessionId'], 'session-1');
          expect(options.data['candidateId'], 'candidate-1');
          expect(options.data['idempotencyKey'], isA<String>());
          events.add(options.data['event'] as String);
          return _jsonBody({
            'contractVersion': 1,
            'accepted': events.length == 1,
            'duplicate': events.length > 1,
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');

      final first = await client.sendRecommendationFeedback(
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
        sessionId: 'session-1',
        candidateId: 'candidate-1',
        event: RecommendationFeedbackEvent.played,
      );
      expect(first.accepted, isTrue);
      expect(first.duplicate, isFalse);

      for (final event in RecommendationFeedbackEvent.values.skip(1)) {
        final response = await client.sendRecommendationFeedback(
          idempotencyKey: '22222222-2222-4222-8222-222222222222',
          sessionId: 'session-1',
          candidateId: 'candidate-1',
          event: event,
        );
        expect(response.accepted, isFalse);
        expect(response.duplicate, isTrue);
      }

      expect(events, [
        'played',
        'completed',
        'imported',
        'disliked',
        'unavailable',
      ]);
    });

    test(
      'reset profile deletes versioned endpoint and requires reset true',
      () async {
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            captured = options;
            return _jsonBody({'contractVersion': 1, 'reset': true});
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://nas:10086');

        await client.resetRecommendationProfile();

        expect(captured.method, 'DELETE');
        expect(captured.path, 'http://nas:10086/v1/recommendations/profile');

        final badDio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            return _jsonBody({'contractVersion': 1, 'reset': false});
          });
        final badClient = BackendClient(dio: badDio)
          ..configure(baseUrl: 'http://nas:10086');
        await expectLater(
          badClient.resetRecommendationProfile(),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('maps versioned recommendation errors', () async {
      Future<void> expectMapped({
        required int status,
        required String code,
        required bool retryable,
      }) async {
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            return _jsonBody({
              'contractVersion': 1,
              'code': code,
              'detail': 'server detail must stay out of toString',
              'retryable': retryable,
            }, statusCode: status);
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://nas:10086');

        await expectLater(
          client.createRecommendationSession(const []),
          throwsA(
            isA<RecommendationApiException>()
                .having((error) => error.code, 'code', code)
                .having((error) => error.retryable, 'retryable', retryable)
                .having((error) => error.statusCode, 'statusCode', status)
                .having(
                  (error) => error.toString(),
                  'toString',
                  isNot(contains('server detail must stay out of toString')),
                ),
          ),
        );
      }

      await expectMapped(
        status: 400,
        code: 'recommendation_invalid_request',
        retryable: false,
      );
      await expectMapped(
        status: 401,
        code: 'recommendation_unauthorized',
        retryable: false,
      );
      await expectMapped(
        status: 410,
        code: 'recommendation_session_expired',
        retryable: false,
      );
      await expectMapped(
        status: 429,
        code: 'recommendation_rate_limited',
        retryable: true,
      );
      await expectMapped(
        status: 503,
        code: 'recommendation_temporarily_unavailable',
        retryable: true,
      );
    });

    test('rejects unsupported success contract and preserves cancel', () async {
      final unsupportedDio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          return _jsonBody({
            'contractVersion': 2,
            'sessionId': 'x',
            'mode': 'ai',
            'items': <Object>[],
            'nextCursor': null,
            'hasMore': false,
          });
        });
      final unsupportedClient = BackendClient(dio: unsupportedDio)
        ..configure(baseUrl: 'http://nas:10086');
      await expectLater(
        unsupportedClient.createRecommendationSession(const []),
        throwsA(
          isA<RecommendationApiException>().having(
            (error) => error.code,
            'code',
            'recommendation_unsupported_contract',
          ),
        ),
      );

      final cancelToken = CancelToken();
      final cancelDio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, cancelFuture) async {
          cancelToken.cancel('stale');
          await cancelFuture;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'stale',
          );
        });
      final cancelClient = BackendClient(dio: cancelDio)
        ..configure(baseUrl: 'http://nas:10086');
      await expectLater(
        cancelClient.getRecommendationItems(
          'session-1',
          cancelToken: cancelToken,
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });

    test('encodes opaque session id in path', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody(
            _pageJson(mode: 'fallback', hasMore: false, nextCursor: null),
          );
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');

      await client.getRecommendationItems('sess/a?b#c', limit: 1);

      expect(
        captured.path,
        'http://nas:10086/v1/recommendations/sessions/sess%2Fa%3Fb%23c/items',
      );
    });

    test('rejects invalid page size and limit before network', () async {
      var called = false;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          called = true;
          return _jsonBody(_pageJson());
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');

      expect(
        () => client.createRecommendationSession(const [], pageSize: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => client.getRecommendationItems('session-1', limit: 21),
        throwsA(isA<ArgumentError>()),
      );
      expect(called, isFalse);
    });
  });
}
