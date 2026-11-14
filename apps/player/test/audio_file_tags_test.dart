import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/utils/audio_file_tags.dart';

void main() {
  test('mp4 tags grow moov and leave the following audio in place', () {
    final mdatPayload = latin1.encode('AUDIO');
    final original = _mp4(mdatOffset: null, payload: mdatPayload);
    final moovEnd = _topLevelEnd(original, 'moov');

    final tagged = embedAudioFileTags(
      original,
      title: '爱错',
      artist: '王力宏 / 单依纯',
      album: '最好的地方',
      lyrics: '[00:01.00]北风毫不留情',
      cover: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
    );

    final newMoovEnd = _topLevelEnd(tagged, 'moov');
    expect(newMoovEnd, greaterThan(moovEnd));
    expect(tagged.sublist(newMoovEnd), original.sublist(moovEnd));
    final text = utf8.decode(tagged, allowMalformed: true);
    expect(text, contains('爱错'));
    expect(text, contains('王力宏 / 单依纯'));
    expect(text, contains('最好的地方'));
    expect(text, contains('北风毫不留情'));
    expect(_hasBoxType(tagged, 'covr'), isTrue);
  });

  test('mp4 chunk offsets move with the audio when moov grows', () {
    final payload = latin1.encode('AUDIO');
    final original = _mp4(mdatOffset: 0, payload: payload);
    final sampleAt = _topLevelEnd(original, 'moov') + 8;
    _writeU32(original, _stcoValueOffset(original), sampleAt);

    final tagged = embedAudioFileTags(original, title: '爱错');

    final delta = tagged.length - original.length;
    expect(_u32(tagged, _stcoValueOffset(tagged)), sampleAt + delta);
    expect(
      latin1.decode(tagged.sublist(tagged.length - payload.length)),
      'AUDIO',
    );
  });

  test('mp3 tag is prepended and an existing tag is left untouched', () {
    final frame = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00, 1, 2, 3]);
    final tagged = embedAudioFileTags(frame, title: '爱错', artist: '王力宏');

    expect(latin1.decode(tagged.sublist(0, 3)), 'ID3');
    expect(tagged.sublist(tagged.length - frame.length), frame);
    expect(utf8.decode(tagged, allowMalformed: true), contains('爱错'));

    final again = embedAudioFileTags(tagged, title: '另一首');
    expect(again, tagged);
  });

  test('sniffs m4a instead of treating every online file as mp3', () {
    final header = Uint8List(12);
    header.setRange(4, 8, latin1.encode('ftyp'));
    expect(sniffedAudioExtension(header), 'm4a');
    expect(sniffedAudioExtension([0xFF, 0xFB]), 'mp3');
  });
}

Uint8List _mp4({required int? mdatOffset, required List<int> payload}) {
    final ilst = _box('ilst', _textItem('too', 'Lavf'));
  final hdlr = Uint8List(33);
  _writeU32(hdlr, 0, 33);
  hdlr.setRange(4, 8, latin1.encode('hdlr'));
  hdlr.setRange(16, 20, latin1.encode('mdir'));
  final metaBody = Uint8List(4 + hdlr.length + ilst.length);
  metaBody.setRange(4, 4 + hdlr.length, hdlr);
  metaBody.setRange(4 + hdlr.length, metaBody.length, ilst);
  final children = <int>[
    ..._box('mvhd', Uint8List(100)),
    if (mdatOffset != null) ..._stco(mdatOffset),
    ..._box('udta', _box('meta', metaBody)),
  ];
  return Uint8List.fromList([
    ..._box('ftyp', latin1.encode('isom')),
    ..._box('moov', children),
    ..._box('mdat', payload),
  ]);
}

Uint8List _stco(int value) {
  final body = Uint8List(12);
  _writeU32(body, 4, 1);
  _writeU32(body, 8, value);
  return _box('stco', body);
}

Uint8List _textItem(String name, String value) {
  final text = utf8.encode(value);
  final data = Uint8List(8 + 8 + text.length);
  _writeU32(data, 0, data.length);
  data.setRange(4, 8, latin1.encode('data'));
  _writeU32(data, 8, 1);
  data.setRange(16, data.length, text);
  final body = Uint8List(4 + data.length);
  body[0] = 0xA9;
  body.setRange(1, 4, latin1.encode(name));
  body.setRange(4, body.length, data);
  return _boxBytes(body);
}

Uint8List _box(String type, List<int> body) {
  final boxed = Uint8List(8 + body.length);
  _writeU32(boxed, 0, boxed.length);
  boxed.setRange(4, 8, latin1.encode(type));
  boxed.setRange(8, boxed.length, body);
  return boxed;
}

Uint8List _boxBytes(Uint8List body) {
  final boxed = Uint8List(4 + body.length);
  _writeU32(boxed, 0, boxed.length);
  boxed.setRange(4, boxed.length, body);
  return boxed;
}

int _topLevelEnd(Uint8List bytes, String type) {
  var offset = 0;
  while (offset + 8 <= bytes.length) {
    final size = _u32(bytes, offset);
    final kind = latin1.decode(bytes.sublist(offset + 4, offset + 8));
    if (kind == type) return offset + size;
    offset += size;
  }
  fail('missing $type');
}

bool _hasBoxType(Uint8List bytes, String type) {
  final needle = latin1.encode(type);
  for (var i = 0; i + 4 <= bytes.length; i++) {
    if (bytes[i] == needle[0] &&
        bytes[i + 1] == needle[1] &&
        bytes[i + 2] == needle[2] &&
        bytes[i + 3] == needle[3]) {
      return true;
    }
  }
  return false;
}

int _stcoValueOffset(Uint8List bytes) {
  final needle = latin1.encode('stco');
  for (var i = 0; i + 20 <= bytes.length; i++) {
    if (bytes[i] == needle[0] &&
        bytes[i + 1] == needle[1] &&
        bytes[i + 2] == needle[2] &&
        bytes[i + 3] == needle[3]) {
      return i + 12;
    }
  }
  fail('missing stco');
}

int _u32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

void _writeU32(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xFF;
  bytes[offset + 1] = (value >> 16) & 0xFF;
  bytes[offset + 2] = (value >> 8) & 0xFF;
  bytes[offset + 3] = value & 0xFF;
}
