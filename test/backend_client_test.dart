import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/backend_client.dart';

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.onFetch);

  final ResponseBody Function(RequestOptions options) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data) {
  return ResponseBody.fromString(
    jsonEncode(data),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
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
          ..httpClientAdapter = _CaptureAdapter((options) {
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
        ..httpClientAdapter = _CaptureAdapter((options) {
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
        ..httpClientAdapter = _CaptureAdapter((options) {
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

    test('getLyrics parses lrc timestamps into LyricsList', () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options) {
          expect(options.queryParameters['types'], 'lyric');
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
}
