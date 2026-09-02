import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/song_identity.dart';

const importDuplicateDurationToleranceSeconds = 3;

enum ImportRecordingMatch { same, different, unknown }

enum ImportDuplicateAction { cancel, download, replace }

class ImportDuplicateDecision {
  const ImportDuplicateDecision.cancel()
    : action = ImportDuplicateAction.cancel,
      replaceSongId = null;

  const ImportDuplicateDecision.download()
    : action = ImportDuplicateAction.download,
      replaceSongId = null;

  const ImportDuplicateDecision.replace(this.replaceSongId)
    : action = ImportDuplicateAction.replace;

  final ImportDuplicateAction action;
  final String? replaceSongId;

  bool get shouldImport => action != ImportDuplicateAction.cancel;

  List<String> get replaceSongIds {
    final id = replaceSongId;
    if (action != ImportDuplicateAction.replace || id == null || id.isEmpty) {
      return const [];
    }
    return [id];
  }
}

class ImportDuplicateCandidate {
  const ImportDuplicateCandidate({required this.song, required this.match});

  final Song song;
  final ImportRecordingMatch match;
}

ImportRecordingMatch classifyRecordingMatch({
  required String incomingAlbum,
  required int? incomingDuration,
  required String localAlbum,
  required int? localDuration,
  int durationToleranceSeconds = importDuplicateDurationToleranceSeconds,
}) {
  final incomingAlbumNorm = normalizeSongIdentityText(incomingAlbum);
  final localAlbumNorm = normalizeSongIdentityText(localAlbum);
  final incomingAlbumKnown = incomingAlbumNorm.isNotEmpty;
  final localAlbumKnown = localAlbumNorm.isNotEmpty;
  final albumsBothKnown = incomingAlbumKnown && localAlbumKnown;
  final albumsBothEmpty = !incomingAlbumKnown && !localAlbumKnown;
  final albumsEqual = albumsBothKnown && incomingAlbumNorm == localAlbumNorm;
  final albumsDiffer = albumsBothKnown && incomingAlbumNorm != localAlbumNorm;

  final bothDurations = incomingDuration != null && localDuration != null;
  final durationDelta = bothDurations
      ? (incomingDuration - localDuration).abs()
      : null;
  final durationMatch =
      durationDelta != null && durationDelta <= durationToleranceSeconds;
  final durationDiffer =
      durationDelta != null && durationDelta > durationToleranceSeconds;

  if (durationDiffer || albumsDiffer) return ImportRecordingMatch.different;
  if ((albumsEqual || albumsBothEmpty) && durationMatch) {
    return ImportRecordingMatch.same;
  }
  return ImportRecordingMatch.unknown;
}

/// Subsonic `search3` queries for the import duplicate pre-check.
///
/// Online titles often keep version labels (`(live)`, `现场版`) that the local
/// library stores without. Search the raw title and the weak-identity title so
/// studio copies still surface in the duplicate picker.
List<String> importDuplicateSearchQueries(Song incoming) {
  final queries = <String>[];
  void add(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    final exists = queries.any(
      (existing) => existing.toLowerCase() == query.toLowerCase(),
    );
    if (!exists) queries.add(query);
  }

  add(incoming.title);
  add(canonicalSongTitle(incoming.title, incoming.artist));
  return queries;
}

List<ImportDuplicateCandidate> importDuplicateCandidates({
  required Song incoming,
  required Iterable<Song> locals,
}) {
  final identity = songWeakIdentity(incoming);
  return [
    for (final local in locals)
      if (songWeakIdentity(local) == identity)
        ImportDuplicateCandidate(
          song: local,
          match: classifyRecordingMatch(
            incomingAlbum: incoming.album,
            incomingDuration: incoming.duration,
            localAlbum: local.album,
            localDuration: local.duration,
          ),
        ),
  ];
}

List<ImportDuplicateCandidate> withPreferredDuplicate({
  required List<ImportDuplicateCandidate> candidates,
  Song? preferred,
}) {
  if (preferred == null || preferred.id.isEmpty) return candidates;
  final index = candidates.indexWhere(
    (candidate) => candidate.song.id == preferred.id,
  );
  if (index >= 0) return candidates;
  return [
    ImportDuplicateCandidate(
      song: preferred,
      match: ImportRecordingMatch.unknown,
    ),
    ...candidates,
  ];
}

int defaultImportDuplicateSelection(
  List<ImportDuplicateCandidate> candidates, {
  String? preferredSongId,
}) {
  if (candidates.isEmpty) return 0;
  if (preferredSongId != null && preferredSongId.isNotEmpty) {
    final preferredIndex = candidates.indexWhere(
      (candidate) => candidate.song.id == preferredSongId,
    );
    if (preferredIndex >= 0) return preferredIndex;
  }
  final sameIndex = candidates.indexWhere(
    (candidate) => candidate.match == ImportRecordingMatch.same,
  );
  return sameIndex >= 0 ? sameIndex : 0;
}

const importQualitySimilarToleranceKbps = 64;
const importQualityLosslessBitRateFloor = 700;
const importQualitySentinelBitRate = 999;

const _knownAudioFormats = {
  'FLAC',
  'MP3',
  'M4A',
  'AAC',
  'OGG',
  'WAV',
  'APE',
  'DSF',
  'DFF',
  'ALAC',
  'AIFF',
  'AIF',
  'TAK',
  'WV',
};

const _losslessFormats = {
  'FLAC',
  'WAV',
  'ALAC',
  'APE',
  'DSF',
  'DFF',
  'AIFF',
  'AIF',
  'TAK',
  'WV',
};

enum ImportQualityCompare {
  higher,
  lower,
  similar,
  unknown,
  localAlreadyLossless,
  originalUsuallyHigher,
  bothLosslessUnknown,
}

class ImportQualityInfo {
  const ImportQualityInfo({
    this.format = '',
    this.bitRate,
    this.isOriginal = false,
    this.estimated = false,
  });

  final String format;
  final int? bitRate;
  final bool isOriginal;
  final bool estimated;

  bool get looksLossless {
    if (_losslessFormats.contains(format.trim().toUpperCase())) return true;
    final rate = bitRate;
    return rate != null &&
        rate >= importQualityLosslessBitRateFloor &&
        rate != importQualitySentinelBitRate;
  }

  bool get isKnown {
    return isOriginal ||
        format.trim().isNotEmpty ||
        (bitRate != null && bitRate! > 0);
  }
}

ImportQualityInfo incomingImportQuality({required int maxBitRate}) {
  if (maxBitRate <= 0) return const ImportQualityInfo(isOriginal: true);
  return ImportQualityInfo(format: 'MP3', bitRate: maxBitRate);
}

String? normalizeAudioFormat(String? raw) {
  final value = (raw ?? '').trim().toUpperCase().replaceFirst(
    RegExp(r'^\.'),
    '',
  );
  if (value.isEmpty) return null;
  if (value.contains('FLAC')) return 'FLAC';
  if (value.contains('MPEG') || value == 'MP3') return 'MP3';
  if (_knownAudioFormats.contains(value)) return value;
  return null;
}

String? audioFormatFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final filename = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last
      : url.split('?').first.split('/').last;
  final dot = filename.lastIndexOf('.');
  if (dot <= 0 || dot >= filename.length - 1) return null;
  return normalizeAudioFormat(filename.substring(dot + 1));
}

int? estimateBitRateKbps({required int bytes, required int durationSeconds}) {
  if (bytes <= 0 || durationSeconds <= 0) return null;
  final kbps = ((bytes * 8) / durationSeconds / 1000).round();
  return kbps > 0 ? kbps : null;
}

int? usableReportedBitRate(int? bitRate) {
  if (bitRate == null || bitRate <= 0) return null;
  if (bitRate == importQualitySentinelBitRate) return null;
  return bitRate;
}

ImportQualityInfo incomingQualityFromPlayback({
  required int maxBitRate,
  String? url,
  int? cloudBr,
  String? cloudType,
  int? cloudSize,
  int? durationSeconds,
}) {
  final setting = incomingImportQuality(maxBitRate: maxBitRate);
  final format =
      normalizeAudioFormat(cloudType) ??
      (url == null ? null : audioFormatFromUrl(url)) ??
      (setting.format.isEmpty ? null : setting.format);
  final estimated = estimateBitRateKbps(
    bytes: cloudSize ?? 0,
    durationSeconds: durationSeconds ?? 0,
  );
  final reported = usableReportedBitRate(cloudBr);
  final bitRate = estimated ?? reported ?? setting.bitRate;
  final hasProbe = format != null || bitRate != null;
  if (!hasProbe) return setting;
  return ImportQualityInfo(
    format: format ?? '',
    bitRate: bitRate,
    estimated: estimated != null,
  );
}

ImportQualityInfo localImportQuality(Song song) {
  return ImportQualityInfo(
    format: (song.suffix ?? '').trim().toUpperCase(),
    bitRate: song.bitRate,
  );
}

String formatImportQualityLabel(
  ImportQualityInfo info, {
  required String originalLabel,
  String Function(int kbps)? estimatedLabel,
}) {
  if (info.isOriginal) return originalLabel;
  final format = info.format.trim();
  final bitRate = info.bitRate;
  final rateLabel = bitRate != null && bitRate > 0
      ? (info.estimated && estimatedLabel != null
            ? estimatedLabel(bitRate)
            : '$bitRate kbps')
      : null;
  if (format.isNotEmpty && rateLabel != null) return '$format · $rateLabel';
  if (format.isNotEmpty) return format;
  return rateLabel ?? '';
}

String incomingImportQualityLabel({
  required int maxBitRate,
  required String originalLabel,
}) {
  return formatImportQualityLabel(
    incomingImportQuality(maxBitRate: maxBitRate),
    originalLabel: originalLabel,
  );
}

String localImportQualityLabel(Song song) {
  return formatImportQualityLabel(localImportQuality(song), originalLabel: '');
}

int? importQualityDeltaKbps({
  required ImportQualityInfo incoming,
  required ImportQualityInfo local,
}) {
  final incomingRate = incoming.bitRate;
  final localRate = local.bitRate;
  if (incomingRate == null ||
      incomingRate <= 0 ||
      localRate == null ||
      localRate <= 0) {
    return null;
  }
  return incomingRate - localRate;
}

ImportQualityCompare compareImportQuality({
  required ImportQualityInfo incoming,
  required ImportQualityInfo local,
}) {
  if (!local.isKnown) return ImportQualityCompare.unknown;

  final delta = importQualityDeltaKbps(incoming: incoming, local: local);
  if (delta != null) {
    if (delta >= importQualitySimilarToleranceKbps) {
      return ImportQualityCompare.higher;
    }
    if (delta <= -importQualitySimilarToleranceKbps) {
      return ImportQualityCompare.lower;
    }
    return ImportQualityCompare.similar;
  }

  if (incoming.isOriginal) {
    return local.looksLossless
        ? ImportQualityCompare.localAlreadyLossless
        : ImportQualityCompare.originalUsuallyHigher;
  }
  if (incoming.looksLossless && local.looksLossless) {
    return ImportQualityCompare.bothLosslessUnknown;
  }
  if (incoming.looksLossless && !local.looksLossless) {
    return ImportQualityCompare.higher;
  }
  if (!incoming.looksLossless &&
      incoming.format.isNotEmpty &&
      local.looksLossless) {
    return ImportQualityCompare.lower;
  }
  return ImportQualityCompare.unknown;
}
