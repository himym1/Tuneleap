import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/player/audio_player_service.dart';

void main() {
  group('PlaybackRepeatMode.nextIndex', () {
    test('advances while the queue has another song', () {
      expect(PlaybackRepeatMode.off.nextIndex(0, 2), 1);
      expect(PlaybackRepeatMode.all.nextIndex(0, 2), 1);
    });

    test('stops at the queue end when repeat is off', () {
      expect(PlaybackRepeatMode.off.nextIndex(1, 2), isNull);
    });

    test('wraps at the queue end only when repeating all', () {
      expect(PlaybackRepeatMode.all.nextIndex(1, 2), 0);
      expect(PlaybackRepeatMode.one.nextIndex(1, 2), isNull);
    });
  });
}
