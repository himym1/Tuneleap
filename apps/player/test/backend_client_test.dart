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
        'http://192.168.1.10:8504',
      );
      expect(BackendClient.inferBaseUrl('https://music.example.com'), '');
      expect(BackendClient.inferBaseUrl('not-a-url'), '');
    });

    test('configure accepts legacy baseUrl alias for cloud', () {
      final client = BackendClient(dio: Dio())
        ..configure(baseUrl: 'http://cloud', apiKey: 'secret');
      expect(client.cloudBaseUrl, 'http://cloud');
      expect(client.isConfigured, isTrue);
    });

    test(
      'searchSongs parses Solara search response into online songs',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            expect(options.path, 'http://nas:10086/v1/music/search');
            expect(options.queryParameters['q'], '屋顶');
            expect(options.queryParameters['source'], 'netease');
            expect(options.queryParameters['provider'], 'chksz');
            expect(options.headers['X-API-Key'], isNull);
            return _jsonBody({
              'query': '屋顶',
              'provider': 'gdstudio',
              'source': 'netease',
              'strategy': 'first-success',
              'has_more': false,
              'items': [
                {
                  'id': '5257138',
                  'title': '屋顶',
                  'artist': '周杰伦 / 温岚',
                  'album': '男女情歌对唱冠军全记录',
                  'source': 'netease',
                  'provider': 'gdstudio',
                  'url_id': '5257138',
                  'cover_id': '109951165671182684',
                  'lyric_id': '5257138',
                },
              ],
            });
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://nas:10086');

        final page = await client.searchSongs(
          '屋顶',
          source: 'netease',
          provider: 'chksz',
          count: 1,
          page: 1,
        );

        expect(page.songs, hasLength(1));
        expect(page.hasMore, isFalse);
        expect(page.songs.first.isOnline, isTrue);
        expect(page.songs.first.onlineSource, 'netease');
        expect(page.songs.first.onlineProvider, 'gdstudio');
        expect(page.songs.first.storageKey, 'solara:netease:5257138');
      },
    );

    test('getMusicCapabilities parses configured adapters', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          expect(options.path, 'http://cloud/v1/music/capabilities');
          return _jsonBody({
            'default_provider': 'meting',
            'sources': {
              'netease': {'max_count': 50, 'paginates': true},
              'tencent': {'max_count': 30, 'paginates': false},
            },
            'adapters': [
              {
                'id': 'meting',
                'sources': ['netease', 'tencent', 'kugou'],
              },
              {
                'id': 'gdstudio',
                'sources': ['netease', 'kugou', 'migu', 'joox'],
              },
            ],
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://cloud');

      final capabilities = await client.getMusicCapabilities();

      expect(capabilities.defaultProvider, 'meting');
      expect(capabilities.adapters.map((adapter) => adapter.id), [
        'meting',
        'gdstudio',
      ]);
      expect(capabilities.sourcesFor('gdstudio'), [
        'netease',
        'kugou',
        'migu',
        'joox',
      ]);
      expect(capabilities.pageSizeFor('netease'), 50);
      expect(capabilities.paginates('netease'), isTrue);
      expect(capabilities.pageSizeFor('tencent'), 30);
      expect(capabilities.paginates('tencent'), isFalse);
      expect(capabilities.pageSizeFor('kugou'), 30);
    });

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
        onlineProvider: 'meting',
      );

      final url = await client.getPlaybackUrl(targetSong, maxBitRate: 192);

      expect(url, 'https://cdn.example.com/song.mp3');
      expect(captured.path, 'http://nas:10086/v1/music/url');
      expect(captured.queryParameters['source'], 'kuwo');
      expect(captured.queryParameters['provider'], 'meting');
      expect(captured.queryParameters['br'], '192');
    });

    test('getPlaybackInfo keeps bitrate type and size from Cloud', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          return _jsonBody({
            'url': 'https://cdn.example.com/song.flac',
            'br': 999,
            'type': 'flac',
            'size': 25840123,
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(cloudBaseUrl: 'http://cloud:8600');
      const song = Song(
        id: '1',
        title: 'Track',
        album: '',
        albumId: '',
        artist: '',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'netease',
        onlineProvider: 'chksz',
      );

      final info = await client.getPlaybackInfo(song);

      expect(info.url, endsWith('.flac'));
      expect(info.br, 999);
      expect(info.type, 'flac');
      expect(info.size, 25840123);
    });

    test(
      'getPlaybackUrl bypassCache skips local cache and asks Cloud again',
      () async {
        var calls = 0;
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            calls += 1;
            captured = options;
            return _jsonBody({
              'url': 'https://cdn.example.com/song-$calls.mp3',
            });
          });
        final client = BackendClient(dio: dio)
          ..configure(cloudBaseUrl: 'http://cloud:8600');
        const song = Song(
          id: '1',
          title: 'Track',
          album: '',
          albumId: '',
          artist: '',
          artistId: '',
          backend: SongBackend.solara,
          onlineSource: 'netease',
          onlineProvider: 'chksz',
        );

        final first = await client.getPlaybackUrl(song);
        final cached = await client.getPlaybackUrl(song);
        final fresh = await client.getPlaybackUrl(song, bypassCache: true);

        expect(first, cached);
        expect(fresh, isNot(first));
        expect(calls, 2);
        expect(captured.queryParameters['fresh'], 'true');
      },
    );

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
        onlineProvider: 'meting',
        coverArt: '109951166681216835',
      );

      final url = client.buildCoverProxyUrl(song, size: 640);
      final uri = Uri.parse(url);

      expect(
        '${uri.scheme}://${uri.host}:${uri.port}${uri.path}',
        'http://nas:10086/v1/music/cover',
      );
      expect(uri.queryParameters['id'], '109951166681216835');
      expect(uri.queryParameters['source'], 'netease');
      expect(uri.queryParameters['provider'], 'meting');
      expect(uri.queryParameters['size'], '640');
    });

    test('resolveCoverArtUrl pins the winning provider', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody({'url': 'https://cdn.example.com/cover.jpg'});
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://nas:10086');
      const song = Song(
        id: '1',
        title: 'Track',
        album: '',
        albumId: '',
        artist: 'Artist',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'netease',
        onlineProvider: 'meting',
        coverArt: 'cover-1',
      );

      final url = await client.resolveCoverArtUrl(song);

      expect(url, 'https://cdn.example.com/cover.jpg');
      expect(captured.queryParameters['source'], 'netease');
      expect(captured.queryParameters['provider'], 'meting');
    });

    test(
      'playback response caches URL cover and lyrics for the same song',
      () async {
        var requestCount = 0;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            requestCount++;
            expect(options.path, 'http://cloud/v1/music/url');
            return _jsonBody({
              'url': 'https://cdn.example.com/song.mp3',
              'cover_url': 'https://cdn.example.com/cover.jpg',
              'lyric': '[00:01.00]First line',
            });
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://cloud');
        const song = Song(
          id: 'qq-1',
          title: 'Song',
          album: '',
          albumId: '',
          artist: 'Artist',
          artistId: '',
          backend: SongBackend.solara,
          onlineSource: 'tencent',
          onlineProvider: 'chksz',
          urlId: 'qq-1',
          lyricId: 'qq-1',
        );

        final first = await client.getPlaybackUrl(song, maxBitRate: 320);
        final second = await client.getPlaybackUrl(song, maxBitRate: 320);
        final cover = await client.resolveCoverArtUrl(song);
        final lyrics = await client.getLyrics(song);

        expect(first, second);
        expect(cover, 'https://cdn.example.com/cover.jpg');
        expect(lyrics?.lines.single.text, 'First line');
        expect(requestCount, 1);
      },
    );

    test(
      'song without cover metadata does not request the cover endpoint',
      () async {
        var requested = false;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            requested = true;
            return _jsonBody({'url': 'https://cdn.example.com/cover.jpg'});
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://cloud');
        const song = Song(
          id: 'kugou-1',
          title: 'Song',
          album: '',
          albumId: '',
          artist: 'Artist',
          artistId: '',
          backend: SongBackend.solara,
          onlineSource: 'kugou',
          onlineProvider: 'chksz',
          urlId: 'kugou-1',
        );

        expect(await client.resolveCoverArtUrl(song), isEmpty);
        expect(requested, isFalse);
      },
    );

    test('missing cover response is negatively cached', () async {
      var requestCount = 0;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          requestCount++;
          return _jsonBody({
            'detail': 'upstream API error: chksz cover empty',
          }, statusCode: 502);
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://cloud');
      const song = Song(
        id: 'legacy-kugou',
        title: 'Song',
        album: '',
        albumId: '',
        artist: 'Artist',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'kugou',
        onlineProvider: 'chksz',
        urlId: 'legacy-kugou',
        coverArt: 'legacy-kugou',
      );

      final results = await Future.wait([
        client.resolveCoverArtUrl(song),
        client.resolveCoverArtUrl(song),
      ]);
      expect(results, ['', '']);
      expect(await client.resolveCoverArtUrl(song), isEmpty);
      expect(requestCount, 1);
    });

    test(
      'resolveCoverArtUrl returns direct online cover without proxy',
      () async {
        var requested = false;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
            requested = true;
            return _jsonBody({'url': 'unexpected'});
          });
        final client = BackendClient(dio: dio)
          ..configure(baseUrl: 'http://cloud');
        const song = Song(
          id: 'netease-1',
          title: 'Song',
          album: '',
          albumId: '',
          artist: 'Artist',
          artistId: '',
          backend: SongBackend.solara,
          onlineSource: 'netease',
          onlineProvider: 'chksz',
          coverArt: 'https://images.example.com/cover.jpg',
        );

        expect(
          await client.resolveCoverArtUrl(song),
          'https://images.example.com/cover.jpg',
        );
        expect(requested, isFalse);
      },
    );

    test('queueNasDownload posts expected payload', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          expect(options.method, 'POST');
          return _jsonBody({'success': true, 'message': 'queued'});
        });
      final client = BackendClient(dio: dio)
        ..configure(
          cloudBaseUrl: 'http://cloud:8600',
          nasAgentUrl: 'http://nas:10086',
          nasAgentKey: 'nas-key',
        );

      final message = await client.queueNasDownload(
        url: 'https://cdn.example.com/song.flac',
        filename: 'solara_netease_1.flac',
        song: {'id': '1', 'name': 'Track'},
        picUrl: 'http://cover/1',
        force: true,
      );

      expect(message, 'queued');
      expect(captured.path, 'http://cloud:8600/v1/library/import');
      expect(captured.headers['X-API-Key'], isNull);
      expect(captured.data['url'], 'https://cdn.example.com/song.flac');
      expect(captured.data['filename'], 'solara_netease_1.flac');
      expect(captured.data['song'], {'id': '1', 'name': 'Track'});
      expect(captured.data['picUrl'], 'http://cover/1');
      expect(captured.data['force'], isTrue);
      expect(captured.data['wait'], isFalse);
    });

    test('queueNasDownload polls until async import completes', () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          calls += 1;
          if (options.method == 'POST') {
            expect(options.data['wait'], isFalse);
            return _jsonBody({
              'active': true,
              'filename': 'solara_netease_1.flac',
              'stage': 'downloading',
              'bytes_received': 4096,
            }, statusCode: 202);
          }
          expect(options.method, 'GET');
          return _jsonBody({
            'active': false,
            'filename': 'solara_netease_1.flac',
            'stage': 'completed',
            'message': 'imported',
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(cloudBaseUrl: 'http://cloud:8600');

      final message = await client.queueNasDownload(
        url: 'https://cdn.example.com/song.flac',
        filename: 'solara_netease_1.flac',
        song: {'id': '1', 'name': 'Track'},
      );

      expect(message, 'imported');
      expect(calls, 2);
    });

    test('formatNasImportError hides DioException boilerplate', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/library/import'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/v1/library/import'),
          statusCode: 504,
          data: {'detail': 'NAS agent timeout'},
        ),
      );
      expect(formatNasImportError(error), 'NAS agent timeout');
      expect(
        formatNasImportError(
          DioException(
            requestOptions: RequestOptions(path: '/v1/library/import'),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: '/v1/library/import'),
              statusCode: 502,
            ),
          ),
        ),
        'NAS agent unavailable',
      );
    });

    test('getNasImportProgress reads Cloud snapshot', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody({
            'active': true,
            'filename': 'a.flac',
            'bytes_received': 4096,
            'bytes_total': 8192,
            'speed_bps': 1024.5,
            'stage': 'downloading',
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(cloudBaseUrl: 'http://cloud:8600');

      final progress = await client.getNasImportProgress();

      expect(captured.path, 'http://cloud:8600/v1/library/import/progress');
      expect(progress.active, isTrue);
      expect(progress.filename, 'a.flac');
      expect(progress.bytesReceived, 4096);
      expect(progress.bytesTotal, 8192);
      expect(progress.speedBps, 1024.5);
      expect(progress.fraction, 0.5);
    });

    test('getNasImportProgress uses LAN agent when Cloud is absent', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody({
            'active': false,
            'filename': null,
            'bytes_received': 0,
            'stage': 'idle',
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(
          nasAgentUrl: 'http://192.168.1.10:8504',
          nasAgentKey: 'nas-key',
        );

      final progress = await client.getNasImportProgress();

      expect(captured.path, 'http://192.168.1.10:8504/v1/nas/import/progress');
      expect(captured.headers['X-API-Key'], 'nas-key');
      expect(progress.active, isFalse);
    });

    test('queueNasDownload uses LAN agent when Cloud is absent', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody({'success': true, 'message': 'queued'});
        });
      final client = BackendClient(dio: dio)
        ..configure(
          nasAgentUrl: 'http://192.168.1.10:8504',
          nasAgentKey: 'nas-key',
        );

      await client.queueNasDownload(
        url: 'https://cdn.example.com/song.mp3',
        filename: 'song.mp3',
        song: {'title': 'Song'},
      );

      expect(captured.path, 'http://192.168.1.10:8504/v1/nas/import');
      expect(captured.headers['X-API-Key'], 'nas-key');
    });

    test('queueNasDownload surfaces NAS duplicate conflict', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          return _jsonBody({
            'detail': 'song already exists in the Navidrome library',
          }, statusCode: 409);
        });
      final client = BackendClient(dio: dio)
        ..configure(
          cloudBaseUrl: 'http://cloud:8600',
          nasAgentUrl: 'http://nas:8504',
          nasAgentKey: 'nas-key',
        );

      expect(
        () => client.queueNasDownload(
          url: 'https://cdn.example.com/song.mp3',
          filename: 'song.mp3',
          song: {'title': 'Song'},
        ),
        throwsA(isA<NasDuplicateException>()),
      );
    });

    test('NAS mutations require Cloud or a secure LAN agent', () async {
      final client = BackendClient(dio: Dio())
        ..configure(cloudBaseUrl: 'https://cloud.example.com');

      expect(client.canMutateNas, isTrue);

      client.configure();
      expect(client.canMutateNas, isFalse);
      expect(
        () => client.queueNasDownload(
          url: 'https://cdn.example.com/song.mp3',
          filename: 'song.mp3',
          song: {'title': 'Song'},
        ),
        throwsStateError,
      );

      client.configure(
        nasAgentUrl: 'https://nas-agent.example.com',
        nasAgentKey: 'nas-key',
      );
      expect(client.canMutateNas, isTrue);

      client.configure(
        nasAgentUrl: 'http://192.168.1.10:8504',
        nasAgentKey: 'nas-key',
      );
      expect(client.canMutateNas, isTrue);

      client.configure(
        nasAgentUrl: 'http://navidrome.example:8504',
        nasAgentKey: 'nas-key',
      );
      expect(client.canMutateNas, isFalse);

      client.configure(
        nasAgentUrl: 'https://nas-agent.example.com',
        nasAgentKey: '',
      );
      expect(client.canMutateNas, isFalse);
    });

    test('deleteLibrarySongs posts song ids to NAS agent', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          captured = options;
          return _jsonBody({
            'deleted': 1,
            'skipped': 0,
            'errors': 0,
            'msg': 'deleted 1, skipped 0, errors 0',
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(
          cloudBaseUrl: 'http://cloud:8600',
          nasAgentUrl: 'http://192.168.1.10:8504',
          nasAgentKey: 'nas-key',
        );

      final result = await client.deleteLibrarySongs(['song-1']);

      expect(result.ok, isTrue);
      expect(result.deleted, 1);
      expect(captured.path, 'http://cloud:8600/v1/library/delete');
      expect(captured.headers['X-API-Key'], isNull);
      expect(captured.data['song_ids'], ['song-1']);
    });

    test('deleteLibrarySongs treats skipped ids as not found', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          return _jsonBody({
            'deleted': 0,
            'skipped': 1,
            'errors': 0,
            'msg': 'deleted 0, skipped 1, errors 0',
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(
          nasAgentUrl: 'http://192.168.1.10:8504',
          nasAgentKey: 'nas-key',
        );

      expect(
        () => client.deleteLibrarySongs(['missing']),
        throwsA(
          isA<NasDeleteException>().having(
            (error) => error.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('getRawLyrics sends fallback song context', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          expect(options.path, 'http://nas:10086/v1/music/lyric');
          expect(options.queryParameters['id'], '5257138');
          expect(options.queryParameters['source'], 'joox');
          expect(options.queryParameters['provider'], 'meting');
          return _jsonBody({
            'lyric': '[00:01]第一句',
            'provider': 'gdstudio',
            'source': 'joox',
          });
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
        onlineProvider: 'meting',
      );

      expect(await client.getRawLyrics(song), '[00:01]第一句');
    });

    test('getLyrics parses lrc timestamps into LyricsList', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          expect(options.path, 'http://nas:10086/v1/music/lyric');
          expect(options.queryParameters['source'], 'netease');
          expect(options.queryParameters['provider'], 'gdstudio');
          return _jsonBody({
            'lyric': '[00:01.23]第一句\n[00:02.50]第二句\n纯文本结尾',
            'provider': 'gdstudio',
            'source': 'netease',
          });
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
        onlineProvider: 'gdstudio',
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

    test('empty lyrics response is negatively cached', () async {
      var requestCount = 0;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          requestCount++;
          return _jsonBody({
            'lyric': '',
            'provider': 'chksz',
            'source': 'kugou',
          });
        });
      final client = BackendClient(dio: dio)
        ..configure(baseUrl: 'http://cloud');
      const song = Song(
        id: 'kugou-1',
        title: 'Song',
        album: '',
        albumId: '',
        artist: 'Artist',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'kugou',
        onlineProvider: 'chksz',
        lyricId: 'kugou-1',
      );

      expect(await client.getLyrics(song), isNull);
      expect(await client.getLyrics(song), isNull);
      expect(requestCount, 1);
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
        final client = BackendClient(
          dio: dio,
          cloudTokenProvider: ({bool forceRefresh = false}) async =>
              'access-token',
        )..configure(baseUrl: 'http://nas:10086');

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
        expect(captured.headers['Authorization'], 'Bearer access-token');
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
    test('refreshes Bearer token once after a Cloud 401', () async {
      var requests = 0;
      final refreshFlags = <bool>[];
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
          requests += 1;
          if (requests == 1) {
            expect(options.headers['Authorization'], 'Bearer access-old');
            return ResponseBody.fromString('{}', 401);
          }
          expect(options.headers['Authorization'], 'Bearer access-new');
          return _jsonBody(_pageJson());
        });
      final client = BackendClient(
        dio: dio,
        cloudTokenProvider: ({bool forceRefresh = false}) async {
          refreshFlags.add(forceRefresh);
          return forceRefresh ? 'access-new' : 'access-old';
        },
      )..configure(baseUrl: 'http://cloud:8600');

      final page = await client.createRecommendationSession(
        const [],
        pageSize: 1,
      );

      expect(page.sessionId, 'session-1');
      expect(refreshFlags, [false, true]);
      expect(requests, 2);
    });
  });
}
