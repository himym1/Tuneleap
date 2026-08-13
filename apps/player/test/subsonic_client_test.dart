import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/subsonic_client.dart';

/// A fake Dio adapter that returns predefined responses for testing.
class _MockDioAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(String path) responseFactory;

  _MockDioAdapter(this.responseFactory);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Extract endpoint from path (e.g., /rest/ping -> ping)
    final path = options.path;
    final endpoint = path.split('/rest/').last.split('?').first;
    final body = responseFactory(endpoint);

    return ResponseBody.fromString(
      _jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  String _jsonEncode(Map<String, dynamic> data) {
    // Simple JSON encoder
    return _encodeValue(data);
  }

  String _encodeValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return '[${value.map(_encodeValue).join(',')}]';
    }
    if (value is Map) {
      final entries = value.entries
          .map((e) => '"${e.key}":${_encodeValue(e.value)}')
          .join(',');
      return '{$entries}';
    }
    return '"$value"';
  }
}

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

class _CancellationAdapter implements HttpClientAdapter {
  final started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await cancelFuture;
    throw DioException(requestOptions: options, type: DioExceptionType.cancel);
  }

  @override
  void close({bool force = false}) {}
}

SubsonicClient _createClient(
  Map<String, dynamic> Function(String endpoint) responseFactory,
) {
  final dio = Dio();
  dio.httpClientAdapter = _MockDioAdapter(responseFactory);
  final client = SubsonicClient(dio: dio);
  client.configure(
    serverUrl: 'http://localhost:4533',
    username: 'test',
    password: 'test123',
  );
  return client;
}

void main() {
  test('downloadFile forwards cancellation to Dio', () async {
    final adapter = _CancellationAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = SubsonicClient(dio: dio);
    final token = CancelToken();
    final path = '${Directory.systemTemp.path}/navidrome-cancel-test';

    final download = client.downloadFile(
      'http://localhost/file',
      path,
      cancelToken: token,
    );
    await adapter.started.future;
    token.cancel('server switched');

    await expectLater(
      download,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });

  group('SubsonicClient', () {
    group('configure', () {
      test('strips trailing slash from server URL', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://localhost:4533/',
          username: 'user',
          password: 'pass',
        );
        // Verify by checking streamUrl output (contains base URL)
        final url = client.streamUrl('test-id');
        expect(url.startsWith('http://localhost:4533/rest/stream'), isTrue);
        expect(url.contains('//rest'), isFalse);
      });

      test('handles URL without trailing slash', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://localhost:4533',
          username: 'user',
          password: 'pass',
        );
        final url = client.streamUrl('test-id');
        expect(url.startsWith('http://localhost:4533/rest/stream'), isTrue);
      });
    });

    group('streamUrl', () {
      test('generates URL with auth params', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://host:4533',
          username: 'admin',
          password: 'password',
        );

        final url = client.streamUrl('song-123');

        expect(url, contains('/rest/stream'));
        expect(url, contains('id=song-123'));
        expect(url, contains('u=admin'));
        expect(url, contains('v=1.16.1'));
        expect(url, contains('c=NavidromePlayer'));
        expect(url, contains('f=json'));
        expect(url, contains('t='));
        expect(url, contains('s='));
      });

      test('includes maxBitRate when provided', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://host:4533',
          username: 'admin',
          password: 'password',
        );

        final url = client.streamUrl('song-123', maxBitRate: 320);

        expect(url, contains('maxBitRate=320'));
      });

      test('excludes maxBitRate when 0', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://host:4533',
          username: 'admin',
          password: 'password',
        );

        final url = client.streamUrl('song-123', maxBitRate: 0);

        expect(url, isNot(contains('maxBitRate')));
      });
    });

    group('coverArtUrl', () {
      test('returns empty string for null coverArtId', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://host:4533',
          username: 'admin',
          password: 'password',
        );

        expect(client.coverArtUrl(null), '');
      });

      test('generates URL with default size', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://host:4533',
          username: 'admin',
          password: 'password',
        );

        final url = client.coverArtUrl('cover-1');

        expect(url, contains('/rest/getCoverArt'));
        expect(url, contains('id=cover-1'));
        expect(url, contains('size=300'));
      });

      test('generates URL with custom size', () {
        final client = SubsonicClient();
        client.configure(
          serverUrl: 'http://host:4533',
          username: 'admin',
          password: 'password',
        );

        final url = client.coverArtUrl('cover-1', size: 600);

        expect(url, contains('size=600'));
      });
    });

    group('ping', () {
      test('returns true on success', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {'status': 'ok', 'version': '1.16.1'},
          },
        );

        expect(await client.ping(), isTrue);
      });

      test('returns false on error', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'failed',
              'error': {'code': 40, 'message': 'Wrong credentials'},
            },
          },
        );

        expect(await client.ping(), isFalse);
      });
    });

    test('getSimilarSongs2 sends seed id and parses songs', () async {
      late RequestOptions captured;
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options) {
          captured = options;
          return ResponseBody.fromString(
            '{"subsonic-response":{"status":"ok","similarSongs2":{"song":[{"id":"similar-1","title":"Similar","album":"Album","albumId":"album-1","artist":"Artist","artistId":"artist-1"}]}}}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json; charset=utf-8'],
            },
          );
        });
      final client = SubsonicClient(dio: dio)
        ..configure(
          serverUrl: 'http://localhost:4533',
          username: 'test',
          password: 'test123',
        );

      final songs = await client.getSimilarSongs2('seed-1', count: 15);

      expect(captured.path, 'http://localhost:4533/rest/getSimilarSongs2');
      expect(captured.queryParameters['id'], 'seed-1');
      expect(captured.queryParameters['count'], 15);
      expect(songs.single.id, 'similar-1');
    });

    group('startScan', () {
      test('calls startScan endpoint without fullScan by default', () async {
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options) {
            captured = options;
            return ResponseBody.fromString(
              '{"subsonic-response":{"status":"ok"}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          });
        final client = SubsonicClient(dio: dio)
          ..configure(
            serverUrl: 'http://localhost:4533',
            username: 'test',
            password: 'test123',
          );

        await client.startScan();

        expect(captured.path, 'http://localhost:4533/rest/startScan');
        expect(captured.queryParameters.containsKey('fullScan'), isFalse);
      });

      test('passes fullScan when requested', () async {
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options) {
            captured = options;
            return ResponseBody.fromString(
              '{"subsonic-response":{"status":"ok"}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          });
        final client = SubsonicClient(dio: dio)
          ..configure(
            serverUrl: 'http://localhost:4533',
            username: 'test',
            password: 'test123',
          );

        await client.startScan(fullScan: true);

        expect(captured.queryParameters['fullScan'], true);
      });
    });

    group('star and unstar', () {
      test('star includes only provided song id', () async {
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options) {
            captured = options;
            return ResponseBody.fromString(
              '{"subsonic-response":{"status":"ok"}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          });
        final client = SubsonicClient(dio: dio)
          ..configure(
            serverUrl: 'http://localhost:4533',
            username: 'test',
            password: 'test123',
          );

        await client.star(id: 'song-1');

        expect(captured.path, 'http://localhost:4533/rest/star');
        expect(captured.queryParameters['id'], 'song-1');
        expect(captured.queryParameters.containsKey('albumId'), isFalse);
        expect(captured.queryParameters.containsKey('artistId'), isFalse);
      });

      test('unstar includes provided album and artist ids', () async {
        late RequestOptions captured;
        final dio = Dio()
          ..httpClientAdapter = _CaptureAdapter((options) {
            captured = options;
            return ResponseBody.fromString(
              '{"subsonic-response":{"status":"ok"}}',
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json; charset=utf-8'],
              },
            );
          });
        final client = SubsonicClient(dio: dio)
          ..configure(
            serverUrl: 'http://localhost:4533',
            username: 'test',
            password: 'test123',
          );

        await client.unstar(albumId: 'album-1', artistId: 'artist-1');

        expect(captured.path, 'http://localhost:4533/rest/unstar');
        expect(captured.queryParameters.containsKey('id'), isFalse);
        expect(captured.queryParameters['albumId'], 'album-1');
        expect(captured.queryParameters['artistId'], 'artist-1');
      });

      test('star throws when no target id is provided', () {
        final client = SubsonicClient()
          ..configure(
            serverUrl: 'http://localhost:4533',
            username: 'test',
            password: 'test123',
          );

        expect(() => client.star(), throwsArgumentError);
      });

      test('unstar throws when no target id is provided', () {
        final client = SubsonicClient()
          ..configure(
            serverUrl: 'http://localhost:4533',
            username: 'test',
            password: 'test123',
          );

        expect(() => client.unstar(), throwsArgumentError);
      });
    });

    group('getArtists', () {
      test('parses indexed artist list', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'ok',
              'artists': {
                'index': [
                  {
                    'name': 'A',
                    'artist': [
                      {'id': 'ar1', 'name': 'ABBA', 'albumCount': 10},
                      {'id': 'ar2', 'name': 'AC/DC', 'albumCount': 8},
                    ],
                  },
                  {
                    'name': 'B',
                    'artist': [
                      {'id': 'ar3', 'name': 'Beatles', 'albumCount': 12},
                    ],
                  },
                ],
              },
            },
          },
        );

        final artists = await client.getArtists();

        expect(artists.length, 3);
        expect(artists[0].name, 'ABBA');
        expect(artists[1].name, 'AC/DC');
        expect(artists[2].name, 'Beatles');
      });

      test('handles empty artist list', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'ok',
              'artists': {'index': []},
            },
          },
        );

        final artists = await client.getArtists();

        expect(artists, isEmpty);
      });
    });

    group('getAlbumList2', () {
      test('parses album list', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'ok',
              'albumList2': {
                'album': [
                  {'id': 'a1', 'name': 'Album 1', 'year': 2024},
                  {'id': 'a2', 'name': 'Album 2', 'year': 2023},
                ],
              },
            },
          },
        );

        final albums = await client.getAlbumList2();

        expect(albums.length, 2);
        expect(albums[0].name, 'Album 1');
        expect(albums[0].year, 2024);
      });

      test('handles empty album list', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {'status': 'ok', 'albumList2': {}},
          },
        );

        final albums = await client.getAlbumList2();

        expect(albums, isEmpty);
      });
    });

    group('search3', () {
      test('parses search results', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'ok',
              'searchResult3': {
                'artist': [
                  {'id': 'ar1', 'name': 'Found Artist'},
                ],
                'album': [
                  {'id': 'a1', 'name': 'Found Album'},
                ],
                'song': [
                  {'id': 's1', 'title': 'Found Song'},
                ],
              },
            },
          },
        );

        final result = await client.search3('test');

        expect(result.artists.length, 1);
        expect(result.artists[0].name, 'Found Artist');
        expect(result.albums.length, 1);
        expect(result.songs.length, 1);
        expect(result.songs[0].title, 'Found Song');
      });

      test('handles empty search results', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {'status': 'ok', 'searchResult3': {}},
          },
        );

        final result = await client.search3('nothing');

        expect(result.artists, isEmpty);
        expect(result.albums, isEmpty);
        expect(result.songs, isEmpty);
      });
    });

    group('getPlaylists', () {
      test('parses playlist list', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'ok',
              'playlists': {
                'playlist': [
                  {
                    'id': 'p1',
                    'name': 'Favorites',
                    'songCount': 20,
                    'owner': 'admin',
                  },
                ],
              },
            },
          },
        );

        final playlists = await client.getPlaylists();

        expect(playlists.length, 1);
        expect(playlists[0].name, 'Favorites');
        expect(playlists[0].owner, 'admin');
      });
    });

    group('error handling', () {
      test('throws SubsonicApiException on API error', () async {
        final client = _createClient(
          (endpoint) => {
            'subsonic-response': {
              'status': 'failed',
              'error': {'code': 70, 'message': 'Not found'},
            },
          },
        );

        expect(() => client.getArtists(), throwsA(isA<SubsonicApiException>()));
      });
    });
  });

  group('SubsonicApiException', () {
    test('toString formats correctly', () {
      const ex = SubsonicApiException(code: 40, message: 'Wrong credentials');
      expect(ex.toString(), 'SubsonicApiException(40): Wrong credentials');
    });
  });

  group('LyricsLine', () {
    test('constructs with text and optional startMs', () {
      const line = LyricsLine(text: 'Hello World', startMs: 5000);
      expect(line.text, 'Hello World');
      expect(line.startMs, 5000);
    });

    test('constructs without startMs', () {
      const line = LyricsLine(text: 'No timing');
      expect(line.startMs, isNull);
    });
  });

  group('LyricsList', () {
    test('constructs correctly', () {
      const lyrics = LyricsList(
        lines: [LyricsLine(text: 'Line 1', startMs: 0)],
        synced: true,
      );
      expect(lyrics.lines.length, 1);
      expect(lyrics.synced, isTrue);
    });
  });
}
