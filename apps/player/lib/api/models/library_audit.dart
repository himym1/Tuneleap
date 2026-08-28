import 'package:navidrome_player/api/models/song.dart';

const libraryAuditCodeMissing = 'missing';
const libraryAuditCodeLowBitrate = 'low_bitrate';
const libraryAuditCodeSuspectTranscode = 'suspect_transcode';
const libraryAuditCodeDuplicateVersion = 'duplicate_version';
const libraryAuditCodeLossyTranscode = 'lossy_transcode';
const libraryAuditCodeFakeHires = 'fake_hires';
const libraryAuditCodeDeepFailed = 'deep_failed';

/// Codes that mean the file itself looks defective or unverifiable.
const libraryAuditQualityCodes = {
  libraryAuditCodeMissing,
  libraryAuditCodeLowBitrate,
  libraryAuditCodeSuspectTranscode,
  libraryAuditCodeLossyTranscode,
  libraryAuditCodeFakeHires,
  libraryAuditCodeDeepFailed,
};

class LibraryAuditRules {
  static const defaultLowBitrateKbps = 320;
  static const defaultSuspectLosslessKbps = 500;
  static const defaultDurationToleranceSeconds = 3;
  static const minLowBitrateKbps = 64;
  static const maxLowBitrateKbps = 320;
  static const minSuspectLosslessKbps = 200;
  static const maxSuspectLosslessKbps = 800;
  static const minDurationToleranceSeconds = 1;
  static const maxDurationToleranceSeconds = 15;

  const LibraryAuditRules({
    this.lowBitrateKbps = defaultLowBitrateKbps,
    this.suspectLosslessKbps = defaultSuspectLosslessKbps,
    this.durationToleranceSeconds = defaultDurationToleranceSeconds,
  });

  final int lowBitrateKbps;
  final int suspectLosslessKbps;
  final int durationToleranceSeconds;

  factory LibraryAuditRules.clamped({
    required int lowBitrateKbps,
    required int suspectLosslessKbps,
    required int durationToleranceSeconds,
  }) {
    return LibraryAuditRules(
      lowBitrateKbps: lowBitrateKbps.clamp(
        minLowBitrateKbps,
        maxLowBitrateKbps,
      ),
      suspectLosslessKbps: suspectLosslessKbps.clamp(
        minSuspectLosslessKbps,
        maxSuspectLosslessKbps,
      ),
      durationToleranceSeconds: durationToleranceSeconds.clamp(
        minDurationToleranceSeconds,
        maxDurationToleranceSeconds,
      ),
    );
  }

  Map<String, int> toJson() {
    return {
      'low_bitrate_kbps': lowBitrateKbps,
      'suspect_lossless_kbps': suspectLosslessKbps,
      'duration_tolerance_seconds': durationToleranceSeconds,
    };
  }
}

class LibraryAuditSummary {
  const LibraryAuditSummary({
    this.scanned = 0,
    this.passed = 0,
    this.issues = 0,
    this.missing = 0,
    this.lowBitrate = 0,
    this.suspectTranscode = 0,
    this.duplicateVersion = 0,
    this.lossyTranscode = 0,
    this.fakeHires = 0,
    this.deepFailed = 0,
  });

  final int scanned;
  final int passed;
  final int issues;
  final int missing;
  final int lowBitrate;
  final int suspectTranscode;
  final int duplicateVersion;
  final int lossyTranscode;
  final int fakeHires;
  final int deepFailed;

  factory LibraryAuditSummary.fromJson(Map<dynamic, dynamic> data) {
    return LibraryAuditSummary(
      scanned: _asInt(data['scanned']) ?? 0,
      passed: _asInt(data['passed']) ?? 0,
      issues: _asInt(data['issues']) ?? 0,
      missing: _asInt(data['missing']) ?? 0,
      lowBitrate: _asInt(data['low_bitrate']) ?? 0,
      suspectTranscode: _asInt(data['suspect_transcode']) ?? 0,
      duplicateVersion: _asInt(data['duplicate_version']) ?? 0,
      lossyTranscode: _asInt(data['lossy_transcode']) ?? 0,
      fakeHires: _asInt(data['fake_hires']) ?? 0,
      deepFailed: _asInt(data['deep_failed']) ?? 0,
    );
  }
}

class LibraryAuditSnapshot {
  const LibraryAuditSnapshot({
    this.active = false,
    this.stage = 'idle',
    this.scanned = 0,
    this.total = 0,
    this.error,
    this.message,
    this.summary = const LibraryAuditSummary(),
  });

  final bool active;
  final String stage;
  final int scanned;
  final int total;
  final String? error;
  final String? message;
  final LibraryAuditSummary summary;

  bool get isScanning =>
      stage == 'scanning' || stage == 'deep_scanning' || active;
  bool get isDeepScanning => stage == 'deep_scanning';
  bool get isIdle => stage == 'idle';
  bool get hasResult =>
      stage == 'completed' ||
      stage == 'cancelled' ||
      stage == 'failed' ||
      stage == 'deep_scanning';

  double? get fraction {
    if (total <= 0) return isScanning ? 0 : null;
    return (scanned / total).clamp(0.0, 1.0);
  }

  factory LibraryAuditSnapshot.fromJson(Map<dynamic, dynamic> data) {
    final rawSummary = data['summary'];
    return LibraryAuditSnapshot(
      active: data['active'] == true,
      stage: data['stage']?.toString() ?? 'idle',
      scanned: _asInt(data['scanned']) ?? 0,
      total: _asInt(data['total']) ?? 0,
      error: data['error']?.toString(),
      message: data['message']?.toString(),
      summary: rawSummary is Map
          ? LibraryAuditSummary.fromJson(rawSummary)
          : const LibraryAuditSummary(),
    );
  }
}

class LibraryAuditFinding {
  const LibraryAuditFinding({
    required this.songId,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.albumId = '',
    this.suffix = '',
    this.bitRate,
    this.duration,
    this.sampleRate,
    this.codes = const [],
    this.severity = 'info',
    this.cutoffHz,
    this.hfExtensionDb,
    this.deepError,
  });

  final String songId;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final String suffix;
  final int? bitRate;
  final int? duration;
  final int? sampleRate;
  final List<String> codes;
  final String severity;
  final double? cutoffHz;
  final double? hfExtensionDb;
  final String? deepError;

  bool get isMissing => codes.contains(libraryAuditCodeMissing);

  /// File looks defective / unverifiable (missing, low bitrate, fake lossless…).
  bool get hasQualityIssue => codes.any(libraryAuditQualityCodes.contains);

  /// Same-title duration mismatch only; audio itself is not flagged bad.
  bool get isVersionOnly =>
      codes.contains(libraryAuditCodeDuplicateVersion) && !hasQualityIssue;

  Song toSong() {
    return Song(
      id: songId,
      title: title,
      album: album,
      albumId: albumId,
      artist: artist,
      artistId: '',
      duration: duration,
      bitRate: bitRate,
      suffix: suffix.isEmpty ? null : suffix,
    );
  }

  String searchQuery() {
    return [title, artist].where((part) => part.trim().isNotEmpty).join(' ');
  }

  factory LibraryAuditFinding.fromJson(Map<dynamic, dynamic> data) {
    final rawCodes = data['codes'];
    return LibraryAuditFinding(
      songId: data['song_id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      artist: data['artist']?.toString() ?? '',
      album: data['album']?.toString() ?? '',
      albumId: data['album_id']?.toString() ?? '',
      suffix: data['suffix']?.toString() ?? '',
      bitRate: _asInt(data['bit_rate']),
      duration: _asInt(data['duration']),
      sampleRate: _asInt(data['sample_rate']),
      codes: rawCodes is List
          ? [
              for (final code in rawCodes)
                if (code.toString().trim().isNotEmpty) code.toString(),
            ]
          : const [],
      severity: data['severity']?.toString() ?? 'info',
      cutoffHz: _asDouble(data['cutoff_hz']),
      hfExtensionDb: _asDouble(data['hf_extension_db']),
      deepError: data['deep_error']?.toString(),
    );
  }
}

class LibraryAuditFindingsPage {
  const LibraryAuditFindingsPage({
    this.items = const [],
    this.offset = 0,
    this.limit = 50,
    this.total = 0,
  });

  final List<LibraryAuditFinding> items;
  final int offset;
  final int limit;
  final int total;

  factory LibraryAuditFindingsPage.fromJson(Map<dynamic, dynamic> data) {
    final rawItems = data['items'];
    return LibraryAuditFindingsPage(
      items: rawItems is List
          ? [
              for (final item in rawItems)
                if (item is Map) LibraryAuditFinding.fromJson(item),
            ]
          : const [],
      offset: _asInt(data['offset']) ?? 0,
      limit: _asInt(data['limit']) ?? 50,
      total: _asInt(data['total']) ?? 0,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
