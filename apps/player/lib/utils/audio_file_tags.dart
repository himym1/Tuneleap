import 'dart:convert';
import 'dart:typed_data';

/// 把歌名、歌手、专辑、歌词和封面写进已下载的音频。
///
/// B 站音轨是 fMP4：moov 在媒体数据前面，分片偏移相对 moof，
/// 所以只扩大 moov 里的 ilst，后面的音轨不用重写。
Uint8List embedAudioFileTags(
  Uint8List bytes, {
  String title = '',
  String artist = '',
  String album = '',
  String lyrics = '',
  Uint8List? cover,
}) {
  final hasText =
      title.isNotEmpty ||
      artist.isNotEmpty ||
      album.isNotEmpty ||
      lyrics.isNotEmpty;
  final image = _coverBytes(cover);
  if (!hasText && image == null) return bytes;
  if (_isMp4(bytes)) {
    return _embedMp4(
          bytes,
          title: title,
          artist: artist,
          album: album,
          lyrics: lyrics,
          cover: image,
        ) ??
        bytes;
  }
  if (_isMp3(bytes) && !_startsWithId3(bytes)) {
    return _prependId3(
      bytes,
      title: title,
      artist: artist,
      album: album,
      lyrics: lyrics,
      cover: image,
    );
  }
  return bytes;
}

/// 用文件头判断扩展名。在线歌曲经常没有 suffix，不能一律存成 mp3。
String? sniffedAudioExtension(List<int> header) {
  if (header.length >= 8 &&
      latin1.decode(header.sublist(4, 8), allowInvalid: true) == 'ftyp') {
    return 'm4a';
  }
  if (header.length >= 3 &&
      header[0] == 0x49 &&
      header[1] == 0x44 &&
      header[2] == 0x33) {
    return 'mp3';
  }
  if (header.length >= 2 && header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
    return 'mp3';
  }
  if (header.length >= 4 &&
      latin1.decode(header.sublist(0, 4), allowInvalid: true) == 'fLaC') {
    return 'flac';
  }
  return null;
}

Uint8List? _coverBytes(Uint8List? cover) {
  if (cover == null || cover.length < 4) return null;
  if (cover[0] == 0xFF && cover[1] == 0xD8 && cover[2] == 0xFF) return cover;
  if (cover[0] == 0x89 &&
      cover[1] == 0x50 &&
      cover[2] == 0x4E &&
      cover[3] == 0x47) {
    return cover;
  }
  return null;
}

bool _isMp4(Uint8List bytes) {
  return bytes.length >= 12 &&
      latin1.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp';
}

bool _isMp3(Uint8List bytes) {
  if (bytes.length < 2) return false;
  if (_startsWithId3(bytes)) return true;
  return bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
}

bool _startsWithId3(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0x49 &&
      bytes[1] == 0x44 &&
      bytes[2] == 0x33;
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

String _boxType(Uint8List bytes, int offset) {
  return latin1.decode(
    bytes.sublist(offset + 4, offset + 8),
    allowInvalid: true,
  );
}

/// 返回 null 表示这个 MP4 不能安全改大小。
Uint8List? _embedMp4(
  Uint8List bytes, {
  required String title,
  required String artist,
  required String album,
  required String lyrics,
  required Uint8List? cover,
}) {
  final moov = _findTopLevel(bytes, 'moov');
  if (moov == null) return null;
  final ilst = _findIlst(bytes, moov);
  final items = <Uint8List>[
    if (title.isNotEmpty) _textItem('nam', title),
    if (artist.isNotEmpty) _textItem('ART', artist),
    if (album.isNotEmpty) _textItem('alb', album),
    if (lyrics.isNotEmpty) _textItem('lyr', lyrics),
    if (cover != null) _coverItem(cover),
  ];
  if (items.isEmpty) return bytes;

  final Uint8List next;
  final int delta;
  final int shiftedFrom;
  if (ilst != null) {
    final rebuilt = _rebuildIlst(bytes, ilst, items);
    delta = rebuilt.length - ilst.size;
    if (delta == 0 &&
        _sameBytes(rebuilt, bytes.sublist(ilst.start, ilst.end))) {
      return bytes;
    }
    next = _splice(bytes, ilst.start, ilst.end, rebuilt);
    for (final header in _ancestorHeaders(bytes, ilst.start)) {
      _writeU32(next, header, _u32(next, header) + delta);
    }
    shiftedFrom = moov.end;
  } else {
    final udta = _freshUdta(items);
    delta = udta.length;
    shiftedFrom = moov.end;
    next = _splice(bytes, moov.end, moov.end, udta);
    _writeU32(next, moov.start, moov.size + delta);
  }
  if (delta != 0) {
    _bumpAbsoluteOffsets(next, shiftedFrom, delta);
  }
  return next;
}

class _Box {
  const _Box(this.start, this.size);
  final int start;
  final int size;
  int get end => start + size;
}

_Box? _findTopLevel(Uint8List bytes, String type) {
  var offset = 0;
  while (offset + 8 <= bytes.length) {
    final size = _u32(bytes, offset);
    if (size < 8 || offset + size > bytes.length) return null;
    if (_boxType(bytes, offset) == type) return _Box(offset, size);
    offset += size;
  }
  return null;
}

_Box? _findIlst(Uint8List bytes, _Box moov) {
  final udta = _child(bytes, moov.start + 8, moov.end, 'udta');
  if (udta == null) return null;
  final meta = _child(bytes, udta.start + 8, udta.end, 'meta');
  if (meta == null) return null;
  // meta 是 FullBox，子盒从 version/flags 之后开始。
  return _child(bytes, meta.start + 12, meta.end, 'ilst');
}

_Box? _child(Uint8List bytes, int start, int end, String type) {
  var offset = start;
  while (offset + 8 <= end) {
    final size = _u32(bytes, offset);
    if (size < 8 || offset + size > end) return null;
    if (_boxType(bytes, offset) == type) return _Box(offset, size);
    offset += size;
  }
  return null;
}

Uint8List _rebuildIlst(
  Uint8List bytes,
  _Box ilst,
  List<Uint8List> replacements,
) {
  final replaced = replacements.map(_itemType).toSet();
  final kept = <Uint8List>[];
  var offset = ilst.start + 8;
  while (offset + 8 <= ilst.end) {
    final size = _u32(bytes, offset);
    if (size < 8 || offset + size > ilst.end) break;
    final type = _boxType(bytes, offset);
    if (!replaced.contains(type)) {
      kept.add(Uint8List.fromList(bytes.sublist(offset, offset + size)));
    }
    offset += size;
  }
  return _box(
    'ilst',
    [...kept, ...replacements].expand((part) => part).toList(),
  );
}

String _itemType(Uint8List item) => latin1.decode(item.sublist(4, 8));

Uint8List _freshUdta(List<Uint8List> items) {
  final ilst = _box('ilst', items.expand((part) => part).toList());
  final hdlr = Uint8List(33);
  _writeU32(hdlr, 0, 33);
  hdlr.setRange(4, 8, latin1.encode('hdlr'));
  hdlr.setRange(16, 20, latin1.encode('mdir'));
  final metaBody = Uint8List(4 + hdlr.length + ilst.length);
  metaBody.setRange(4, 4 + hdlr.length, hdlr);
  metaBody.setRange(4 + hdlr.length, metaBody.length, ilst);
  return _box('udta', _box('meta', metaBody));
}

Uint8List _textItem(String name, String value) {
  return _ilstItem(_copyrightType(name), _dataAtom(1, utf8.encode(value)));
}

Uint8List _coverItem(Uint8List cover) {
  final png =
      cover.length >= 4 &&
      cover[0] == 0x89 &&
      cover[1] == 0x50 &&
      cover[2] == 0x4E &&
      cover[3] == 0x47;
  return _ilstItem(latin1.encode('covr'), _dataAtom(png ? 14 : 13, cover));
}

Uint8List _copyrightType(String name) {
  return Uint8List.fromList([0xA9, ...latin1.encode(name)]);
}

Uint8List _ilstItem(List<int> type, Uint8List dataAtom) {
  final body = Uint8List(type.length + dataAtom.length);
  body.setRange(0, type.length, type);
  body.setRange(type.length, body.length, dataAtom);
  return _boxBytes(body);
}

Uint8List _dataAtom(int typeIndicator, List<int> payload) {
  final body = Uint8List(8 + payload.length);
  _writeU32(body, 0, typeIndicator);
  body.setRange(8, body.length, payload);
  final boxed = Uint8List(8 + body.length);
  _writeU32(boxed, 0, boxed.length);
  boxed.setRange(4, 8, latin1.encode('data'));
  boxed.setRange(8, boxed.length, body);
  return boxed;
}

Uint8List _box(String type, List<int> body) {
  final boxed = Uint8List(8 + body.length);
  _writeU32(boxed, 0, boxed.length);
  boxed.setRange(4, 8, latin1.encode(type));
  boxed.setRange(8, boxed.length, body);
  return boxed;
}

Uint8List _boxBytes(Uint8List body) {
  // body 已经带上 4 字节类型，这里只补盒子长度。
  final boxed = Uint8List(4 + body.length);
  _writeU32(boxed, 0, boxed.length);
  boxed.setRange(4, boxed.length, body);
  return boxed;
}

Uint8List _splice(Uint8List bytes, int start, int end, Uint8List replacement) {
  final next = Uint8List(bytes.length - (end - start) + replacement.length);
  next.setRange(0, start, bytes);
  next.setRange(start, start + replacement.length, replacement);
  next.setRange(start + replacement.length, next.length, bytes.sublist(end));
  return next;
}

List<int> _ancestorHeaders(Uint8List bytes, int point) {
  final headers = <int>[];
  void walk(int start, int end) {
    var offset = start;
    while (offset + 8 <= end) {
      final size = _u32(bytes, offset);
      if (size < 8 || offset + size > end) return;
      if (offset < point && point < offset + size) {
        headers.add(offset);
        var child = offset + 8;
        if (_boxType(bytes, offset) == 'meta') child += 4;
        if (child < point) walk(child, offset + size);
        return;
      }
      offset += size;
    }
  }

  walk(0, bytes.length);
  return headers;
}

void _bumpAbsoluteOffsets(Uint8List bytes, int shiftedFrom, int delta) {
  void walk(int start, int end) {
    var offset = start;
    while (offset + 8 <= end) {
      final size = _u32(bytes, offset);
      if (size < 8 || offset + size > end) return;
      final type = _boxType(bytes, offset);
      if (type == 'stco') {
        _bumpStco(bytes, offset, size, shiftedFrom, delta);
      } else if (type == 'co64') {
        _bumpCo64(bytes, offset, size, shiftedFrom, delta);
      } else if (type == 'tfhd') {
        _bumpTfhd(bytes, offset, size, shiftedFrom, delta);
      } else if (_containerTypes.contains(type)) {
        var child = offset + 8;
        if (type == 'meta') child += 4;
        walk(child, offset + size);
      }
      offset += size;
    }
  }

  walk(0, bytes.length);
}

const _containerTypes = {
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'udta',
  'edts',
  'moof',
  'traf',
  'dinf',
  'meta',
};

void _bumpStco(
  Uint8List bytes,
  int offset,
  int size,
  int shiftedFrom,
  int delta,
) {
  if (offset + 16 > bytes.length || size < 16) return;
  final count = _u32(bytes, offset + 12);
  for (var i = 0; i < count; i++) {
    final at = offset + 16 + i * 4;
    if (at + 4 > offset + size) return;
    final value = _u32(bytes, at);
    if (value >= shiftedFrom) _writeU32(bytes, at, value + delta);
  }
}

void _bumpCo64(
  Uint8List bytes,
  int offset,
  int size,
  int shiftedFrom,
  int delta,
) {
  if (offset + 16 > bytes.length || size < 16) return;
  final count = _u32(bytes, offset + 12);
  for (var i = 0; i < count; i++) {
    final at = offset + 16 + i * 8;
    if (at + 8 > offset + size) return;
    final value = (_u32(bytes, at) << 32) | _u32(bytes, at + 4);
    if (value >= shiftedFrom) {
      final updated = value + delta;
      _writeU32(bytes, at, updated >> 32);
      _writeU32(bytes, at + 4, updated & 0xFFFFFFFF);
    }
  }
}

void _bumpTfhd(
  Uint8List bytes,
  int offset,
  int size,
  int shiftedFrom,
  int delta,
) {
  if (offset + 20 > bytes.length || size < 20) return;
  final flags = _u32(bytes, offset + 8) & 0xFFFFFF;
  if ((flags & 0x1) == 0) return;
  final value = (_u32(bytes, offset + 12) << 32) | _u32(bytes, offset + 16);
  if (value >= shiftedFrom) {
    final updated = value + delta;
    _writeU32(bytes, offset + 12, updated >> 32);
    _writeU32(bytes, offset + 16, updated & 0xFFFFFFFF);
  }
}

bool _sameBytes(Uint8List left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

Uint8List _prependId3(
  Uint8List bytes, {
  required String title,
  required String artist,
  required String album,
  required String lyrics,
  required Uint8List? cover,
}) {
  final frames = <Uint8List>[
    if (title.isNotEmpty) _textFrame('TIT2', title),
    if (artist.isNotEmpty) _textFrame('TPE1', artist),
    if (album.isNotEmpty) _textFrame('TALB', album),
    if (lyrics.isNotEmpty) _lyricsFrame(lyrics),
    if (cover != null) _apicFrame(cover),
  ];
  if (frames.isEmpty) return bytes;
  final body = frames.expand((frame) => frame).toList();
  final header = Uint8List(10);
  header.setRange(0, 3, latin1.encode('ID3'));
  header[3] = 4;
  header.setRange(6, 10, _synchsafe(body.length));
  return Uint8List.fromList([...header, ...body, ...bytes]);
}

Uint8List _textFrame(String id, String value) {
  final text = utf8.encode(value);
  final body = Uint8List(1 + text.length)..[0] = 3;
  body.setRange(1, body.length, text);
  return _frame(id, body);
}

Uint8List _lyricsFrame(String value) {
  final text = utf8.encode(value);
  final body = Uint8List(1 + 3 + 1 + text.length);
  body[0] = 3;
  body.setRange(1, 4, latin1.encode('zho'));
  body.setRange(5, body.length, text);
  return _frame('USLT', body);
}

Uint8List _apicFrame(Uint8List cover) {
  final png =
      cover.length >= 4 &&
      cover[0] == 0x89 &&
      cover[1] == 0x50 &&
      cover[2] == 0x4E &&
      cover[3] == 0x47;
  final mime = latin1.encode(png ? 'image/png' : 'image/jpeg');
  final body = Uint8List(1 + mime.length + 1 + 1 + 1 + cover.length);
  body[0] = 3;
  body.setRange(1, 1 + mime.length, mime);
  body[1 + mime.length + 1] = 3;
  body.setRange(body.length - cover.length, body.length, cover);
  return _frame('APIC', body);
}

Uint8List _frame(String id, Uint8List body) {
  final frame = Uint8List(10 + body.length);
  frame.setRange(0, 4, latin1.encode(id));
  frame.setRange(4, 8, _synchsafe(body.length));
  frame.setRange(10, frame.length, body);
  return frame;
}

Uint8List _synchsafe(int size) {
  return Uint8List.fromList([
    (size >> 21) & 0x7F,
    (size >> 14) & 0x7F,
    (size >> 7) & 0x7F,
    size & 0x7F,
  ]);
}
