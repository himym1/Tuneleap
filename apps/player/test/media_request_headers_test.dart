import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/media_request_headers.dart';

void main() {
  group('mediaRequestHeaders', () {
    test('uses browser-like headers for http images', () {
      final headers = mediaRequestHeaders(
        'https://p2.music.126.net/example/cover.jpg?param=300y300',
      );

      expect(headers['User-Agent'], contains('Mozilla/5.0'));
      expect(headers['Accept'], contains('image/'));
      expect(headers['Referer'], 'https://music.163.com/');
    });

    test('does not add audio headers for normal self-hosted streams', () {
      final headers = mediaRequestHeaders(
        'https://cdn.example.com/example/song.mp3',
        kind: MediaRequestKind.audio,
      );

      expect(headers, isEmpty);
    });

    test('uses browser-like headers for netease audio requests', () {
      final headers = mediaRequestHeaders(
        'https://m701.music.126.net/example/song.mp3',
        kind: MediaRequestKind.audio,
      );

      expect(headers['User-Agent'], contains('Mozilla/5.0'));
      expect(headers['Accept'], contains('audio/'));
      expect(headers['Referer'], 'https://music.163.com/');
    });

    test('does not add headers for non-http urls', () {
      expect(mediaRequestHeaders(''), isEmpty);
      expect(mediaRequestHeaders('file:///tmp/cover.jpg'), isEmpty);
    });
  });
}
