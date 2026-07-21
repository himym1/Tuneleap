import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart'
    show LyricsList, LyricsLine;

class BackendClient {
  final Dio _dio;
  String _baseUrl = '';
  String _apiKey = '';
  final Map<String, String> _coverArtCache = {};

  BackendClient({Dio? dio}) : _dio = dio ?? Dio();

  bool get isConfigured => _baseUrl.isNotEmpty;

  void configure({required String baseUrl, String apiKey = ''}) {
    _baseUrl = _normalizeBaseUrl(baseUrl);
    _apiKey = apiKey;
    debugPrint('[Backend] configured: apiKey=${_apiKey.isNotEmpty}');
    // 统一设置 API Key header
    if (_apiKey.isEmpty) {
      _dio.options.headers.remove('X-API-Key');
    } else {
      _dio.options.headers['X-API-Key'] = _apiKey;
    }
  }

  static String inferBaseUrl(String serverUrl, {int port = 8503}) {
    final uri = Uri.tryParse(serverUrl);
    if (uri == null || uri.host.isEmpty) return '';

    return Uri(
      scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
      host: uri.host,
      port: port,
    ).toString();
  }

  Future<List<Song>> searchSongs(
    String query, {
    required String source,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    debugPrint('[Backend] searchSongs: source=$source');
    try {
      final response = await _dio.get(
        '$_baseUrl/proxy',
        queryParameters: {
          'types': 'search',
          'source': source,
          'name': query,
          'count': count,
          'pages': page,
          's': _signature(),
        },
        cancelToken: cancelToken,
      );

      debugPrint(
        '[Backend] searchSongs response: ${response.statusCode}, data type: ${response.data.runtimeType}',
      );
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Backend search response must be a list');
      }

      return data
          .map((item) => Song.fromSolaraJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Backend] searchSongs ERROR: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<String> getPlaybackUrl(Song song, {int? maxBitRate}) async {
    final response = await _dio.get(
      '$_baseUrl/proxy',
      queryParameters: {
        'types': 'url',
        'id': song.urlId ?? song.id,
        'source': song.onlineSource ?? 'netease',
        'br': _qualityFromBitRate(maxBitRate),
        's': _signature(),
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Solara url response must be an object');
    }

    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const FormatException('Solara url response missing url');
    }

    return url;
  }

  String buildCoverProxyUrl(Song song, {int size = 300}) {
    final coverArtId = song.coverArt;
    if (coverArtId == null || coverArtId.isEmpty) return '';

    final query = Uri(
      queryParameters: {
        'types': 'pic',
        'id': coverArtId,
        'source': song.onlineSource ?? 'netease',
        'size': '$size',
        's': _signature(),
        if (_apiKey.isNotEmpty) 'api_key': _apiKey,
      },
    ).query;

    return '$_baseUrl/proxy?$query';
  }

  Future<String> resolveCoverArtUrl(Song song, {int size = 300}) async {
    final coverArtId = song.coverArt;
    if (coverArtId == null || coverArtId.isEmpty) return '';

    final cacheKey = '${song.onlineSource}:$coverArtId:$size';
    final cached = _coverArtCache[cacheKey];
    if (cached != null) return cached;

    final response = await _dio.get(
      '$_baseUrl/proxy',
      queryParameters: {
        'types': 'pic',
        'id': coverArtId,
        'source': song.onlineSource ?? 'netease',
        'size': size,
        's': _signature(),
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Solara pic response must be an object');
    }

    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) return '';

    _coverArtCache[cacheKey] = url;
    return url;
  }

  Future<String?> queueNasDownload({
    required String url,
    required String filename,
    required Map<String, dynamic> song,
    String? picUrl,
    String? lyric,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/nas-download',
      data: {
        'url': url,
        'filename': filename,
        'song': song,
        if (picUrl != null && picUrl.isNotEmpty) 'picUrl': picUrl,
        if (lyric != null && lyric.isNotEmpty) 'lyric': lyric,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException(
        'Solara nas-download response must be an object',
      );
    }

    if (data['success'] != true) {
      final error = data['error']?.toString().trim();
      throw StateError(
        error == null || error.isEmpty ? 'NAS download failed' : error,
      );
    }

    final message = data['message']?.toString().trim();
    if (message == null || message.isEmpty) {
      return null;
    }
    return message;
  }

  /// 获取歌词的原始 LRC 文本（用于导入/下载时保存）
  Future<String?> getRawLyrics(Song song) async {
    final lyricId = song.lyricId ?? song.id;
    final response = await _dio.get(
      '$_baseUrl/proxy',
      queryParameters: {
        'types': 'lyric',
        'id': lyricId,
        'source': song.onlineSource ?? 'netease',
        's': _signature(),
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return null;

    final lyric = data['lyric']?.toString() ?? '';
    return lyric.isEmpty ? null : lyric;
  }

  Future<LyricsList?> getLyrics(Song song) async {
    final lyricId = song.lyricId ?? song.id;
    debugPrint('[Backend] getLyrics: source=${song.onlineSource ?? 'unknown'}');
    final response = await _dio.get(
      '$_baseUrl/proxy',
      queryParameters: {
        'types': 'lyric',
        'id': lyricId,
        'source': song.onlineSource ?? 'netease',
        's': _signature(),
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      debugPrint(
        '[Backend] getLyrics ERROR: response is not a map: ${data.runtimeType}',
      );
      throw const FormatException('Solara lyric response must be an object');
    }

    final lyric = data['lyric']?.toString() ?? '';
    debugPrint(
      '[Backend] getLyrics: lyric length=${lyric.length}, empty=${lyric.isEmpty}',
    );
    if (lyric.isEmpty) return null;

    final lines = lyric
        .split('\n')
        .map((rawLine) => rawLine.trim())
        .where((line) => line.isNotEmpty)
        .expand(_parseLrcLine)
        .toList();

    if (lines.isEmpty) return null;

    return LyricsList(
      lines: lines,
      synced: lines.any((line) => line.startMs != null),
    );
  }

  /// 按 Navidrome song ID 删除本地歌曲文件
  Future<bool> deleteSongById(String navidromeId) async {
    debugPrint('[Backend] deleting song');
    try {
      final response = await _dio.post(
        '$_baseUrl/v1/songs/delete',
        data: [navidromeId],
        options: Options(contentType: 'application/json'),
      );
      debugPrint('[Backend]   status: ${response.statusCode}');
      final data = response.data;
      if (data is Map) {
        return (data['deleted'] as int? ?? 0) > 0;
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Backend] delete ERROR: ${e.runtimeType}');
      return false;
    }
  }

  Future<RecommendationPage> createRecommendationSession(
    List<Song> recent, {
    bool refresh = false,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    _validateRecommendationPageSize(pageSize);
    return _recommendationRequest(() async {
      final response = await _dio.post(
        '$_baseUrl/v1/recommendations/sessions',
        data: {
          'refresh': refresh,
          'pageSize': pageSize,
          'recent': recent
              .take(30)
              .map(
                (song) =>
                    RecentRecommendationSongSummary.fromSong(song).toJson(),
              )
              .toList(),
        },
        cancelToken: cancelToken,
      );
      return _parseRecommendationPage(response);
    });
  }

  Future<RecommendationPage> getRecommendationItems(
    String sessionId, {
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    _validateRecommendationPageSize(limit);
    return _recommendationRequest(() async {
      final encodedSessionId = Uri.encodeComponent(sessionId);
      final response = await _dio.get(
        '$_baseUrl/v1/recommendations/sessions/$encodedSessionId/items',
        queryParameters: {
          'limit': limit,
          ...?cursor == null ? null : {'cursor': cursor},
        },
        cancelToken: cancelToken,
      );
      return _parseRecommendationPage(response);
    });
  }

  Future<RecommendationFeedbackResponse> sendRecommendationFeedback({
    required String idempotencyKey,
    required String sessionId,
    required String candidateId,
    required RecommendationFeedbackEvent event,
    CancelToken? cancelToken,
  }) async {
    return _recommendationRequest(() async {
      final response = await _dio.post(
        '$_baseUrl/v1/recommendations/feedback',
        data: {
          'idempotencyKey': idempotencyKey,
          'sessionId': sessionId,
          'candidateId': candidateId,
          'event': event.name,
        },
        cancelToken: cancelToken,
      );
      return RecommendationFeedbackResponse.fromJson(
        _requireRecommendationEnvelope(response),
      );
    });
  }

  Future<void> resetRecommendationProfile({CancelToken? cancelToken}) async {
    await _recommendationRequest(() async {
      final response = await _dio.delete(
        '$_baseUrl/v1/recommendations/profile',
        cancelToken: cancelToken,
      );
      final data = _requireRecommendationEnvelope(response);
      if (data['reset'] != true) {
        throw const FormatException(
          'Recommendation profile reset was not confirmed',
        );
      }
    });
  }

  RecommendationPage _parseRecommendationPage(Response<dynamic> response) {
    final data = _requireRecommendationEnvelope(response);
    return RecommendationPage.fromJson(data);
  }

  Map<String, dynamic> _requireRecommendationEnvelope(
    Response<dynamic> response,
  ) {
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Recommendation response must be an object');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['contractVersion'] != 1) {
      throw RecommendationApiException(
        code: 'recommendation_unsupported_contract',
        detail: 'Unsupported recommendation contract',
        retryable: false,
        statusCode: response.statusCode,
      );
    }
    final code = map['code'];
    final detail = map['detail'];
    final retryable = map['retryable'];
    if (code != null || detail != null || retryable != null) {
      if (code is String && detail is String && retryable is bool) {
        throw RecommendationApiException(
          code: code,
          detail: detail,
          retryable: retryable,
          statusCode: response.statusCode,
        );
      }
      throw const FormatException('Invalid recommendation error response');
    }
    return map;
  }

  Future<T> _recommendationRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final response = error.response;
      final data = response?.data;
      if (response != null && data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['contractVersion'] == 1 &&
            map['code'] is String &&
            map['detail'] is String &&
            map['retryable'] is bool) {
          throw RecommendationApiException(
            code: map['code'] as String,
            detail: map['detail'] as String,
            retryable: map['retryable'] as bool,
            statusCode: response.statusCode,
          );
        }
      }
      rethrow;
    }
  }

  static void _validateRecommendationPageSize(int value) {
    if (value < 1 || value > 20) {
      throw ArgumentError.value(value, 'pageSize', 'must be between 1 and 20');
    }
  }

  static String _normalizeBaseUrl(String raw) {
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String _signature() {
    final random = Random.secure();
    final first = random.nextInt(1 << 32).toRadixString(36);
    final second = random.nextInt(1 << 32).toRadixString(36);
    return '$first$second';
  }

  static String _qualityFromBitRate(int? maxBitRate) {
    if (maxBitRate == null || maxBitRate <= 0) return '999';
    if (maxBitRate <= 128) return '128';
    if (maxBitRate <= 192) return '192';
    if (maxBitRate <= 320) return '320';
    return '999';
  }

  static Iterable<LyricsLine> _parseLrcLine(String line) sync* {
    final matches = RegExp(
      r'\[(\d{2}):(\d{2})(?:\.(\d{1,3}))?\]',
    ).allMatches(line);
    final text = line.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    if (matches.isEmpty) {
      if (text.isNotEmpty) {
        yield LyricsLine(text: text);
      }
      return;
    }

    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fractionRaw = match.group(3) ?? '0';
      final milliseconds = switch (fractionRaw.length) {
        1 => int.parse(fractionRaw) * 100,
        2 => int.parse(fractionRaw) * 10,
        _ => int.parse(fractionRaw.substring(0, 3)),
      };

      yield LyricsLine(
        text: text,
        startMs: (minutes * 60 * 1000) + (seconds * 1000) + milliseconds,
      );
    }
  }
}
