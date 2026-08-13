import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/utils/duration_format.dart';

void main() {
  group('formatDuration', () {
    test('formats seconds only', () {
      expect(formatDuration(45), '0:45');
    });

    test('formats minutes and seconds', () {
      expect(formatDuration(185), '3:05');
    });

    test('formats zero', () {
      expect(formatDuration(0), '0:00');
    });

    test('pads seconds with leading zero', () {
      expect(formatDuration(61), '1:01');
    });

    test('formats hours when >= 3600', () {
      expect(formatDuration(3661), '1:01:01');
    });

    test('formats exact hour', () {
      expect(formatDuration(3600), '1:00:00');
    });

    test('formats long duration', () {
      expect(formatDuration(7384), '2:03:04');
    });
  });

  group('formatPositionDuration', () {
    test('formats Duration object', () {
      expect(
        formatPositionDuration(const Duration(minutes: 3, seconds: 25)),
        '3:25',
      );
    });

    test('formats zero duration', () {
      expect(formatPositionDuration(Duration.zero), '0:00');
    });

    test('formats duration with hours', () {
      expect(
        formatPositionDuration(
          const Duration(hours: 1, minutes: 5, seconds: 30),
        ),
        '1:05:30',
      );
    });
  });
}
