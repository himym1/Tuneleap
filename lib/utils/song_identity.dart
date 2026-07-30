import 'package:navidrome_player/api/models/song.dart';

final _cjk = RegExp(r'[\u3400-\u9fff]');
final _version = RegExp(
  r'\b(acoustic|demo|edit|explicit|instrumental|karaoke|live|mix|mono|radio|remastered?|remix|rework|stereo|version)\b|^(国语|粤语|伴奏|现场|重制|混音|纯音乐|国|粤)(版)?$',
  caseSensitive: false,
);
final _bracket = RegExp(r'(\([^()]*\)|（[^（）]*）|\[[^\[\]]*\]|【[^【】]*】)');
final _titlePrefix = RegExp(r'^(.+?)\s[-–—]\s(.+)$');
final _versionSuffix = RegExp(r'\s[-–—:]\s(.+)$');
final _featured = RegExp(r'\s+(feat(?:uring)?|ft)\.?\s+', caseSensitive: false);
final _identityPunctuation = RegExp(
  r'''[\s.\-–—_:：'"`~!@#$%^*()（）\[\]【】{}<>《》?？;；]+''',
);

String normalizeSongIdentityText(String value) => value
    .toLowerCase()
    .replaceAll(_identityPunctuation, ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

List<String> canonicalArtistTokens(String value) {
  var artist = value.toLowerCase().split(_featured).first;
  final separators = _cjk.hasMatch(artist)
      ? RegExp(r'[/&＆+•·、,，_]')
      : RegExp(r'\s+[/&＆+•·、,，_]\s+');
  artist = artist.replaceAll(separators, '|');
  final tokens =
      artist
          .split('|')
          .map(normalizeSongIdentityText)
          .where((token) => token.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return tokens;
}

bool _isVersionLabel(String value) =>
    _version.hasMatch(normalizeSongIdentityText(value));

String canonicalSongTitle(String title, String artist) {
  var value = title.toLowerCase();
  final prefix = _titlePrefix.firstMatch(value);
  if (prefix != null) {
    final prefixArtists = canonicalArtistTokens(prefix.group(1) ?? '').toSet();
    final songArtists = canonicalArtistTokens(artist).toSet();
    if (prefixArtists.isNotEmpty && songArtists.containsAll(prefixArtists)) {
      value = prefix.group(2) ?? value;
    }
  }
  value = value.replaceAllMapped(_bracket, (match) {
    final text = match.group(0) ?? '';
    return _isVersionLabel(text) ? '' : text;
  });
  final suffix = _versionSuffix.firstMatch(value);
  if (suffix != null && _isVersionLabel(suffix.group(1) ?? '')) {
    value = value.substring(0, suffix.start);
  }
  return normalizeSongIdentityText(value);
}

String songWeakIdentity(Song song) =>
    songWeakIdentityOf(song.title, song.artist);

String songWeakIdentityOf(String title, String artist) =>
    '${canonicalSongTitle(title, artist)}\u001f${canonicalArtistTokens(artist).join('\u001e')}';
