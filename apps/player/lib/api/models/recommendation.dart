import 'package:navidrome_player/api/models/song.dart';

enum RecommendationMode { ai, fallback }

enum RecommendationType { similar, explore }

enum RecommendationFeedbackEvent {
  played,
  completed,
  imported,
  disliked,
  unavailable,
}

class RecommendationFeedbackResponse {
  const RecommendationFeedbackResponse({
    required this.accepted,
    required this.duplicate,
  });

  final bool accepted;
  final bool duplicate;

  factory RecommendationFeedbackResponse.fromJson(Map<String, dynamic> json) {
    _requireContract(json);
    if (json['accepted'] is! bool || json['duplicate'] is! bool) {
      throw const FormatException('Invalid recommendation feedback response');
    }
    return RecommendationFeedbackResponse(
      accepted: json['accepted'] as bool,
      duplicate: json['duplicate'] as bool,
    );
  }
}

void _requireContract(Map<String, dynamic> json) {
  if (json['contractVersion'] != 1) {
    throw const RecommendationApiException(
      code: 'recommendation_unsupported_contract',
      detail: 'Unsupported recommendation contract',
      retryable: false,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String label) {
  if (raw is! String) {
    throw FormatException('Invalid recommendation $label');
  }
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Invalid recommendation $label');
}

class RecommendationApiException implements Exception {
  const RecommendationApiException({
    required this.code,
    required this.detail,
    required this.retryable,
    this.statusCode,
  });

  final String code;
  final String detail;
  final bool retryable;
  final int? statusCode;

  @override
  String toString() =>
      'RecommendationApiException(code: $code, retryable: $retryable, '
      'statusCode: $statusCode)';
}

class RecentRecommendationSongSummary {
  const RecentRecommendationSongSummary({
    required this.title,
    required this.artist,
    required this.album,
    required this.source,
    required this.sourceId,
  });

  final String title;
  final String artist;
  final String album;
  final String source;
  final String sourceId;

  factory RecentRecommendationSongSummary.fromSong(Song song) {
    final source = song.isOnline ? song.onlineSource : 'subsonic';
    final sourceId = song.isOnline ? (song.urlId ?? song.id) : song.id;
    if (source == null || source.isEmpty || sourceId.isEmpty) {
      throw const FormatException(
        'Recent recommendation song is missing source',
      );
    }
    return RecentRecommendationSongSummary(
      title: song.title,
      artist: song.artist,
      album: song.album,
      source: source,
      sourceId: sourceId,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'album': album,
    'source': source,
    'sourceId': sourceId,
  };
}

class RecommendationItem {
  const RecommendationItem({
    required this.candidateId,
    required this.type,
    required this.song,
  });

  final String candidateId;
  final RecommendationType type;
  final Song song;

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    if (json['candidateId'] is! String ||
        (json['candidateId'] as String).isEmpty ||
        json['song'] is! Map) {
      throw const FormatException('Invalid recommendation item');
    }
    final song = Song.fromJson(Map<String, dynamic>.from(json['song'] as Map));
    if (!song.isOnline ||
        song.onlineSource?.isEmpty != false ||
        song.urlId?.isEmpty != false) {
      throw const FormatException('Recommendation song must be online');
    }
    return RecommendationItem(
      candidateId: json['candidateId'] as String,
      type: _enumByName(
        RecommendationType.values,
        json['recommendationType'],
        'type',
      ),
      song: song,
    );
  }
}

class RecommendationPage {
  const RecommendationPage({
    required this.sessionId,
    required this.mode,
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final String sessionId;
  final RecommendationMode mode;
  final List<RecommendationItem> items;
  final String? nextCursor;
  final bool hasMore;

  factory RecommendationPage.fromJson(Map<String, dynamic> json) {
    _requireContract(json);
    if (json['sessionId'] is! String ||
        (json['sessionId'] as String).isEmpty ||
        json['items'] is! List ||
        json['hasMore'] is! bool ||
        (json['nextCursor'] != null && json['nextCursor'] is! String)) {
      throw const FormatException('Invalid recommendation page');
    }
    final hasMore = json['hasMore'] as bool;
    final nextCursor = json['nextCursor'] as String?;
    if (hasMore) {
      if (nextCursor == null || nextCursor.isEmpty) {
        throw const FormatException('Invalid recommendation page cursor');
      }
    } else if (nextCursor != null) {
      throw const FormatException('Invalid recommendation page cursor');
    }
    final items = <RecommendationItem>[];
    for (final item in json['items'] as List) {
      if (item is! Map) {
        throw const FormatException('Invalid recommendation item');
      }
      items.add(RecommendationItem.fromJson(Map<String, dynamic>.from(item)));
    }
    return RecommendationPage(
      sessionId: json['sessionId'] as String,
      mode: _enumByName(RecommendationMode.values, json['mode'], 'mode'),
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}
