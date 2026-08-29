/// Closed style names written as file genre tags. NAS does not own this list.
const libraryStyleNames = <String>[
  '华语流行',
  '粤语流行',
  '抒情情歌',
  '经典老歌',
  '民谣',
  '摇滚',
  'R&B',
  '电子舞曲',
  '嘻哈说唱',
  '轻音乐',
  '影视原声',
  '日本流行',
  '欧美流行',
  '欧美民谣',
];

final libraryStyleSet = Set<String>.unmodifiable(libraryStyleNames);

String? closedStyleOf(String? genre) {
  final value = genre?.trim() ?? '';
  return libraryStyleSet.contains(value) ? value : null;
}

enum LibraryStyleDecision { skip, suggest, review }

enum LibraryStyleConfidence { high, medium, low }

class LibraryStyleSuggestion {
  const LibraryStyleSuggestion({
    required this.decision,
    this.style,
    this.confidence = LibraryStyleConfidence.low,
    this.evidence = '',
  });

  final LibraryStyleDecision decision;
  final String? style;
  final LibraryStyleConfidence confidence;
  final String evidence;

  bool get shouldWrite =>
      decision == LibraryStyleDecision.suggest &&
      style != null &&
      libraryStyleSet.contains(style);
}

final _cjkRe = RegExp(r'[\u3400-\u9fff]');
final _kanaRe = RegExp(r'[\u3040-\u30ff]');
final _hangulRe = RegExp(r'[\uac00-\ud7af]');
final _cyrillicRe = RegExp(r'[\u0400-\u04ff]');
final _arabicRe = RegExp(r'[\u0600-\u06ff]');

const _ostNeedles = <String>[
  '原声',
  'ost',
  'soundtrack',
  '主题曲',
  '片头曲',
  '片尾曲',
  '插曲',
  'opening theme',
  'ending theme',
];

const _instrumentalNeedles = <String>[
  '轻音乐',
  '纯音乐',
  'instrumental',
  '钢琴曲',
  'piano solo',
  '无人声',
];

const _balladNeedles = <String>['情歌', '抒情', '慢歌', 'ballad'];

/// iTunes Mandopop / Pop buckets — language family, not final taste.
const coarseLookupStyles = <String>{'华语流行', '欧美流行'};

LibraryStyleSuggestion suggestLibraryStyle({
  required String title,
  required String artist,
  required String album,
  int? year,
  String? currentGenre,
  bool missingOnly = true,
}) {
  final existing = currentGenre?.trim() ?? '';
  if (existing.isNotEmpty) {
    if (missingOnly) {
      return const LibraryStyleSuggestion(
        decision: LibraryStyleDecision.skip,
        evidence: 'already tagged',
      );
    }
    if (libraryStyleSet.contains(existing)) {
      return LibraryStyleSuggestion(
        decision: LibraryStyleDecision.suggest,
        style: existing,
        confidence: LibraryStyleConfidence.high,
        evidence: 'keep existing genre',
      );
    }
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.review,
      evidence: 'genre outside closed set',
    );
  }

  final blob = '$title $artist $album'.toLowerCase();
  if (_hangulRe.hasMatch(blob) ||
      _cyrillicRe.hasMatch(blob) ||
      _arabicRe.hasMatch(blob)) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.review,
      evidence: 'script needs review',
    );
  }

  if (_containsAny(blob, _ostNeedles)) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '影视原声',
      confidence: LibraryStyleConfidence.high,
      evidence: 'ost marker',
    );
  }
  if (_containsAny(blob, _instrumentalNeedles)) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '轻音乐',
      confidence: LibraryStyleConfidence.high,
      evidence: 'instrumental marker',
    );
  }
  if (blob.contains('粤语') || blob.contains('cantonese')) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '粤语流行',
      confidence: LibraryStyleConfidence.high,
      evidence: 'cantonese marker',
    );
  }
  if (_kanaRe.hasMatch(title) || _kanaRe.hasMatch(album)) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '日本流行',
      confidence: LibraryStyleConfidence.high,
      evidence: 'kana in title or album',
    );
  }
  if (blob.contains('说唱') ||
      blob.contains('hip-hop') ||
      blob.contains('hip hop') ||
      _hasLatinWord(blob, 'rap')) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '嘻哈说唱',
      confidence: LibraryStyleConfidence.high,
      evidence: 'rap marker',
    );
  }
  if (blob.contains('摇滚') ||
      _hasLatinWord(blob, 'rock') ||
      _hasLatinWord(blob, 'punk')) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '摇滚',
      confidence: LibraryStyleConfidence.high,
      evidence: 'rock marker',
    );
  }
  if (blob.contains('r&b') || blob.contains('rnb') || blob.contains('节奏蓝调')) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: 'R&B',
      confidence: LibraryStyleConfidence.high,
      evidence: 'r&b marker',
    );
  }
  if (blob.contains('电音') ||
      blob.contains('舞曲') ||
      blob.contains('edm') ||
      _hasLatinWord(blob, 'techno') ||
      _hasLatinWord(blob, 'house')) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '电子舞曲',
      confidence: LibraryStyleConfidence.high,
      evidence: 'dance marker',
    );
  }
  if (blob.contains('民谣')) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '民谣',
      confidence: LibraryStyleConfidence.high,
      evidence: 'folk marker',
    );
  }
  if (_containsAny(blob, _balladNeedles)) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '抒情情歌',
      confidence: LibraryStyleConfidence.high,
      evidence: 'ballad marker',
    );
  }
  if (!_cjkRe.hasMatch(blob) &&
      (_hasLatinWord(blob, 'folk') || _hasLatinWord(blob, 'country'))) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '欧美民谣',
      confidence: LibraryStyleConfidence.high,
      evidence: 'western folk marker',
    );
  }

  final saneYear = _usableYear(year);
  if (saneYear != null &&
      saneYear < 1990 &&
      (_cjkRe.hasMatch(title) || _cjkRe.hasMatch(artist))) {
    return LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '经典老歌',
      confidence: LibraryStyleConfidence.medium,
      evidence: 'pre-1990 cjk',
    );
  }
  if (_cjkRe.hasMatch(title) || _cjkRe.hasMatch(artist)) {
    return const LibraryStyleSuggestion(
      decision: LibraryStyleDecision.suggest,
      style: '华语流行',
      confidence: LibraryStyleConfidence.medium,
      evidence: 'cjk default',
    );
  }
  return const LibraryStyleSuggestion(
    decision: LibraryStyleDecision.review,
    evidence: 'no high-confidence style',
  );
}

bool needsStyleLookup(LibraryStyleSuggestion suggestion) {
  if (suggestion.decision == LibraryStyleDecision.skip) {
    return false;
  }
  return !(suggestion.shouldWrite &&
      suggestion.confidence == LibraryStyleConfidence.high);
}

LibraryStyleSuggestion mergeLookupStyle({
  required LibraryStyleSuggestion local,
  String? remoteStyle,
  String? provider,
  String title = '',
  String artist = '',
  String album = '',
  int? year,
}) {
  final style = closedStyleOf(remoteStyle);
  if (style == null) return local;
  if (coarseLookupStyles.contains(style)) {
    final refined = refineCoarseLookupStyle(
      coarse: style,
      title: title,
      artist: artist,
      album: album,
      year: year,
    );
    if (refined != null) {
      return LibraryStyleSuggestion(
        decision: LibraryStyleDecision.suggest,
        style: refined,
        confidence: LibraryStyleConfidence.high,
        evidence: 'lookup:${provider ?? 'cloud'}+refine',
      );
    }
  }
  return LibraryStyleSuggestion(
    decision: LibraryStyleDecision.suggest,
    style: style,
    confidence: LibraryStyleConfidence.high,
    evidence: 'lookup:${provider ?? 'cloud'}',
  );
}

/// Specific markers only — never the CJK/Pop language default.
String? refineCoarseLookupStyle({
  required String coarse,
  required String title,
  required String artist,
  required String album,
  int? year,
}) {
  if (!coarseLookupStyles.contains(coarse)) return null;
  final suggestion = suggestLibraryStyle(
    title: title,
    artist: artist,
    album: album,
    year: year,
    missingOnly: true,
  );
  if (suggestion.shouldWrite &&
      suggestion.style != null &&
      !coarseLookupStyles.contains(suggestion.style)) {
    return suggestion.style;
  }
  return null;
}

String? highConfidenceImportGenre({
  required String title,
  required String artist,
  required String album,
  int? year,
}) {
  final suggestion = suggestLibraryStyle(
    title: title,
    artist: artist,
    album: album,
    year: year,
    missingOnly: true,
  );
  if (suggestion.shouldWrite &&
      suggestion.confidence == LibraryStyleConfidence.high) {
    return suggestion.style;
  }
  return null;
}

bool _containsAny(String haystack, List<String> needles) {
  for (final needle in needles) {
    if (haystack.contains(needle)) return true;
  }
  return false;
}

bool _hasLatinWord(String haystack, String word) {
  return RegExp(
    '\\b${RegExp.escape(word)}\\b',
    caseSensitive: false,
  ).hasMatch(haystack);
}

int? _usableYear(int? year) {
  if (year == null || year < 1900 || year >= 2090) return null;
  return year;
}
