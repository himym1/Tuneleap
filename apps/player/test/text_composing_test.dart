import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/utils/text_composing.dart';

void main() {
  test('Windows idle composing range 0..0 does not count as composing', () {
    const value = TextEditingValue(
      text: 'jazz',
      composing: TextRange(start: 0, end: 0),
    );

    expect(value.composing, isNot(TextRange.empty));
    expect(isActivelyComposing(value), isFalse);
  });

  test('empty composing range does not count as composing', () {
    const value = TextEditingValue(text: 'jazz');

    expect(value.composing, TextRange.empty);
    expect(isActivelyComposing(value), isFalse);
  });

  test('in-progress IME range still counts as composing', () {
    const value = TextEditingValue(
      text: 'nihao',
      composing: TextRange(start: 0, end: 5),
    );

    expect(isActivelyComposing(value), isTrue);
  });
}
