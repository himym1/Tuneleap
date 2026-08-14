import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/utils/reorder.dart';

void main() {
  test('dragging down subtracts one from the destination', () {
    expect(adjustedReorderIndex(1, 4), 3);
  });

  test('dragging up keeps the destination index', () {
    expect(adjustedReorderIndex(4, 1), 1);
  });

  test('dropping on the same slot is a no-op index', () {
    expect(adjustedReorderIndex(2, 2), 2);
  });
}
