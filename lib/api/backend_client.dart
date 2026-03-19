import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart' show LyricsList, LyricsLine;

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
    debugPrint('[Backend] configured: $_baseUrl, apiKey=${_apiKey.isNotEmpty}');
    // 统一设置 API Key header
    if (_apiKey.isNotEmpty) {
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
    debugPrint('[Backend] searchSongs: query=$query, source=$source, baseUrl=$_baseUrl');
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

      debugPrint('[Backend] searchSongs response: ${response.statusCode}, data type: ${response.data.runtimeType}');
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Backend search response must be a list');
      }

      return data
          .map((item) => Song.fromSolaraJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Backend] searchSongs ERROR: $e');
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
    debugPrint('[Backend] getLyrics: id=$lyricId, source=${song.onlineSource}, lyricId=${song.lyricId}');
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
      debugPrint('[Backend] getLyrics ERROR: response is not a map: ${data.runtimeType}');
      throw const FormatException('Solara lyric response must be an object');
    }

    final lyric = data['lyric']?.toString() ?? '';
    debugPrint('[Backend] getLyrics: lyric length=${lyric.length}, empty=${lyric.isEmpty}');
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
    debugPrint('[Backend] DELETE by ID: $navidromeId');
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
      debugPrint('[Backend]   ERROR: $e');
      return false;
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
