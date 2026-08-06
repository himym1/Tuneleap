import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/utils/song_identity.dart';

void main() {
  test('duet identity ignores separator order and language suffix', () {
    final expected = songWeakIdentityOf('花好月圆夜', '任贤齐 / 杨千嬅');

    expect(songWeakIdentityOf('花好月圆夜', '杨千嬅 & 任贤齐'), expected);
    expect(songWeakIdentityOf('花好月圆夜(国)', '任贤齐 • 杨千嬅'), expected);
    expect(songWeakIdentityOf('任贤齐 _ 杨千嬅 - 花好月圆夜', '杨千嬅/任贤齐'), expected);
  });

  test('latin artist punctuation is normalized', () {
    expect(
      songWeakIdentityOf('Enemy', 'Imagine Dragons / J.I.D'),
      songWeakIdentityOf('Enemy', 'J.I.D & Imagine Dragons'),
    );
  });

  test('featured artist keeps primary artist weak identity', () {
    expect(
      songWeakIdentityOf('Song', 'Artist feat. Guest'),
      songWeakIdentityOf('Song', 'Artist'),
    );
  });

  test('version labels preserve unrelated Chinese brackets', () {
    expect(
      songWeakIdentityOf('Song - Live', 'Artist'),
      songWeakIdentityOf('Song', 'Artist'),
    );
    expect(
      songWeakIdentityOf('Song (中国风)', 'Artist'),
      isNot(songWeakIdentityOf('Song', 'Artist')),
    );
  });
}
