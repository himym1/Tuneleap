import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart'
    show LyricsList, LyricsLine;

typedef CloudTokenProvider = Future<String?> Function({bool forceRefresh});

class NasDuplicateException implements Exception {
  const NasDuplicateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NasDeleteException implements Exception {
  const NasDeleteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaybackInfo {
  const PlaybackInfo({required this.url, this.br, this.type, this.size});

  final String url;
  final int? br;
  final String? type;
  final int? size;

  PlaybackInfo copyWith({int? br, String? type, int? size}) {
    return PlaybackInfo(
      url: url,
      br: br ?? this.br,
      type: type ?? this.type,
      size: size ?? this.size,
    );
  }
}

class NasDeleteResult {
  const NasDeleteResult({
    required this.deleted,
    this.skipped = 0,
    this.errors = 0,
    this.message = '',
  });

  final int deleted;
  final int skipped;
  final int errors;
  final String message;

  bool get ok => deleted > 0 && errors == 0;
}

bool isSlowNasUpstream(Object error) {
  final text = formatNasImportError(error).toLowerCase();
  return text.contains('too slow');
}

String formatNasImportError(Object error) {
  if (error is NasDuplicateException) return error.message;
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final detail = data is Map
        ? (data['detail'] ?? data['error'] ?? data['message'])
              ?.toString()
              .trim()
        : null;
    if (detail != null &&
        detail.isNotEmpty &&
        !detail.startsWith('DioException') &&
        !detail.contains('This exception was thrown because the response')) {
      return _truncateImportError(detail);
    }
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'NAS import timed out';
    }
    return switch (status) {
      504 => 'NAS agent timeout',
      502 => 'NAS agent unavailable',
      503 => 'Library import is not configured',
      413 => 'File is too large',
      429 => 'Too many import requests',
      507 => 'Not enough disk space',
      null => 'Import failed',
      _ => 'Import failed ($status)',
    };
  }
  var text = error.toString().trim();
  if (text.startsWith('Exception: ')) text = text.substring(11);
  if (text.startsWith('StateError: ')) text = text.substring(12);
  if (text.startsWith('Bad state: ')) text = text.substring(11);
  if (text.startsWith('DioException') ||
      text.contains('This exception was thrown because the response')) {
    return 'Import failed';
  }
  return _truncateImportError(text);
}

String _truncateImportError(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'Import failed';
  return trimmed.length <= 160 ? trimmed : '${trimmed.substring(0, 157)}...';
}

class NasImportProgress {
  const NasImportProgress({
    this.active = false,
    this.filename,
    this.bytesReceived = 0,
    this.bytesTotal,
    this.speedBps = 0,
    this.stage = 'idle',
    this.error,
    this.message,
  });

  final bool active;
  final String? filename;
  final int bytesReceived;
  final int? bytesTotal;
  final double speedBps;
  final String stage;
  final String? error;
  final String? message;

  double? get fraction {
    final total = bytesTotal;
    if (total == null || total <= 0) return null;
    return (bytesReceived / total).clamp(0.0, 1.0);
  }

  factory NasImportProgress.fromJson(Map<dynamic, dynamic> data) {
    return NasImportProgress(
      active: data['active'] == true,
      filename: data['filename']?.toString(),
      bytesReceived: _asInt(data['bytes_received']) ?? 0,
      bytesTotal: _asInt(data['bytes_total']),
      speedBps: _asDouble(data['speed_bps']) ?? 0,
      stage: data['stage']?.toString() ?? 'idle',
      error: data['error']?.toString(),
      message: data['message']?.toString(),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

/// Dual-endpoint companion client (ADR-0004):
/// - cloud: Bearer-authenticated search, media, recommendations, and updates
/// - nas agent: API-key-authenticated import/delete/library-audit only
class BackendClient {
  static const _playbackUrlCacheTtl = Duration(seconds: 60);
  static const _missingMediaCacheTtl = Duration(minutes: 5);
  static const _cloudRetryKey = 'cloud-auth-retried';

  late final Dio _dio;
  final CloudTokenProvider? _cloudTokenProvider;
  String _cloudBaseUrl = '';
  String _nasBaseUrl = '';
  String _nasAgentKey = '';
  final Map<String, String> _coverArtCache = {};
  final Map<String, (PlaybackInfo, DateTime)> _playbackUrlCache = {};
  static final Dio _mediaProbeDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      followRedirects: true,
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  final Map<String, String> _lyricsCache = {};
  final Map<String, DateTime> _missingCoverCache = {};
  final Map<String, DateTime> _missingLyricsCache = {};
  final Map<String, Future<String>> _coverRequests = {};

  BackendClient({Dio? dio, CloudTokenProvider? cloudTokenProvider})
    : _cloudTokenProvider = cloudTokenProvider {
    _dio = dio ?? Dio();
    _dio.options.connectTimeout ??= const Duration(seconds: 10);
    if (cloudTokenProvider != null) _installCloudAuth();
  }

  bool get isConfigured => _cloudBaseUrl.isNotEmpty;
  bool get isNasConfigured => _nasBaseUrl.isNotEmpty;
  bool get canMutateNas => isConfigured || _hasDirectNasAgent;
  bool get canAuditLibrary => _hasDirectNasAgent;

  bool get _hasDirectNasAgent {
    final uri = Uri.tryParse(_nasBaseUrl);
    return _nasAgentKey.isNotEmpty &&
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' && _isLanHost(uri.host)));
  }

  String get cloudBaseUrl => _cloudBaseUrl;
  String get nasBaseUrl => _nasBaseUrl;

  void configure({
    String cloudBaseUrl = '',
    String cloudApiKey = '',
    String nasAgentUrl = '',
    String nasAgentKey = '',
    // Backward-compatible URL aliases for older call sites/tests.
    String? baseUrl,
    String apiKey = '',
  }) {
    final resolvedCloud = cloudBaseUrl.isNotEmpty
        ? cloudBaseUrl
        : (baseUrl ?? '');
    final normalizedCloud = _normalizeBaseUrl(resolvedCloud);
    if (_cloudBaseUrl != normalizedCloud) {
      _coverArtCache.clear();
      _playbackUrlCache.clear();
      _lyricsCache.clear();
      _missingCoverCache.clear();
      _missingLyricsCache.clear();
      _coverRequests.clear();
    }
    _cloudBaseUrl = normalizedCloud;
    _nasBaseUrl = _normalizeBaseUrl(nasAgentUrl);
    _nasAgentKey = nasAgentKey;
    debugPrint(
      '[Backend] configured cloud=${_cloudBaseUrl.isNotEmpty} nas=${_nasBaseUrl.isNotEmpty}',
    );
  }

  /// Infer the production LAN NAS agent endpoint on port 8504.
  static String inferBaseUrl(String serverUrl, {int port = 8504}) {
    final uri = Uri.tryParse(serverUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme.isNotEmpty &&
            uri.scheme != 'http' &&
            uri.scheme != 'https') ||
        !_isLanHost(uri.host)) {
      return '';
    }

    return Uri(
      scheme: uri.scheme.isEmpty ? 'http' : uri.scheme,
      host: uri.host,
      port: port,
    ).toString();
  }

  static bool _isLanHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized.endsWith('.local') ||
        (!normalized.contains('.') && !normalized.contains(':'))) {
      return true;
    }
    final octets = normalized.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((part) => part == null)) return false;
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  void _installCloudAuth() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_isCloudRequest(options)) {
            handler.next(options);
            return;
          }
          if (options.headers['Authorization'] != null) {
            handler.next(options);
            return;
          }
          try {
            final token = await _cloudTokenProvider!(forceRefresh: false);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } on Exception {
            // Let the request surface its normal 401/network error.
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              !_isCloudRequest(request) ||
              request.extra[_cloudRetryKey] == true) {
            handler.next(error);
            return;
          }
          try {
            final token = await _cloudTokenProvider!(forceRefresh: true);
            if (token == null || token.isEmpty) {
              handler.next(error);
              return;
            }
            request.extra[_cloudRetryKey] = true;
            request.headers['Authorization'] = 'Bearer $token';
            handler.resolve(await _dio.fetch<dynamic>(request));
          } on Exception {
            handler.next(error);
          }
        },
      ),
    );
  }

  bool _isCloudRequest(RequestOptions options) {
    final cloud = Uri.tryParse(_cloudBaseUrl);
    final request = options.uri;
    return cloud != null &&
        cloud.host.isNotEmpty &&
        request.scheme == cloud.scheme &&
        request.host == cloud.host &&
        request.port == cloud.port;
  }

  Options _cloudOptions() => Options();

  Options _nasOptions({String? contentType}) {
    final headers = <String, dynamic>{};
    if (_nasAgentKey.isNotEmpty) {
      headers['X-API-Key'] = _nasAgentKey;
    }
    return Options(headers: headers, contentType: contentType);
  }

  Future<MusicCapabilities> getMusicCapabilities() async {
    final response = await _dio.get(
      '$_cloudBaseUrl/v1/music/capabilities',
      options: _cloudOptions(),
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException(
        'Cloud music capabilities response must be an object',
      );
    }
    return MusicCapabilities.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CloudSearchPage> searchSongs(
    String query, {
    String? source,
    String? provider,
    int count = 20,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    debugPrint('[Backend] searchSongs cloud first-success source=$source');
    try {
      final response = await _dio.get(
        '$_cloudBaseUrl/v1/music/search',
        queryParameters: {
          'q': query,
          if (source != null && source.isNotEmpty) 'source': source,
          if (provider != null && provider.isNotEmpty) 'provider': provider,
          'count': count,
          'page': page,
        },
        options: _cloudOptions(),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map) {
        final items = data['items'];
        if (items is! List) {
          throw const FormatException(
            'Cloud search response items must be a list',
          );
        }
        final songs = items
            .whereType<Map>()
            .map((item) => Song.fromCloudJson(Map<String, dynamic>.from(item)))
            .toList();
        return CloudSearchPage(
          songs: songs,
          hasMore: _parseSearchHasMore(data, songs.length, count),
        );
      }
      if (data is List) {
        // Legacy monorepo /proxy shape fallback.
        final songs = data
            .map((item) => Song.fromSolaraJson(item as Map<String, dynamic>))
            .toList();
        return CloudSearchPage(songs: songs, hasMore: songs.length >= count);
      }
      throw const FormatException('Cloud search response must be an object');
    } catch (e) {
      debugPrint('[Backend] searchSongs ERROR: ${e.runtimeType}');
      rethrow;
    }
  }

  static bool _parseSearchHasMore(Map data, int itemCount, int count) {
    final raw = data['has_more'] ?? data['hasMore'];
    if (raw is bool) return raw;
    return itemCount >= count;
  }

  Future<String> getPlaybackUrl(
    Song song, {
    int? maxBitRate,
    bool bypassCache = false,
  }) async {
    final info = await getPlaybackInfo(
      song,
      maxBitRate: maxBitRate,
      bypassCache: bypassCache,
    );
    return info.url;
  }

  Future<PlaybackInfo> getPlaybackInfo(
    Song song, {
    int? maxBitRate,
    bool bypassCache = false,
  }) async {
    final id = song.urlId ?? song.id;
    final source = song.onlineSource ?? 'netease';
    final provider = song.onlineProvider ?? '';
    final bitRate = _qualityFromBitRate(maxBitRate);
    final cacheKey = '$provider:$source:$id:$bitRate';
    if (!bypassCache) {
      final cached = _playbackUrlCache[cacheKey];
      if (cached != null && cached.$2.isAfter(DateTime.now())) {
        return cached.$1;
      }
    }
    _playbackUrlCache.remove(cacheKey);

    final response = await _dio.get(
      '$_cloudBaseUrl/v1/music/url',
      queryParameters: {
        'id': id,
        'source': source,
        if (provider.isNotEmpty) 'provider': provider,
        'br': bitRate,
        if (bypassCache) 'fresh': 'true',
      },
      options: _cloudOptions(),
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Cloud url response must be an object');
    }
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const FormatException('Cloud url response missing url');
    }
    final info = PlaybackInfo(
      url: url,
      br: _asPositiveInt(data['br']),
      type: data['type']?.toString(),
      size: _asPositiveInt(data['size']),
    );
    _playbackUrlCache[cacheKey] = (
      info,
      DateTime.now().add(_playbackUrlCacheTtl),
    );

    final coverUrl = data['cover_url']?.toString() ?? '';
    if (coverUrl.isNotEmpty) {
      _coverArtCache[_coverCacheKey(song, id)] = coverUrl;
    }
    final lyric = data['lyric']?.toString() ?? '';
    if (lyric.isNotEmpty) {
      _lyricsCache[_mediaCacheKey(song, id)] = lyric;
    }
    return info;
  }

  Future<PlaybackInfo> probePlaybackInfo(Song song, {int? maxBitRate}) async {
    final info = await getPlaybackInfo(song, maxBitRate: maxBitRate);
    if (info.size != null && info.size! > 0) return info;
    final size = await _probeContentLength(info.url);
    if (size == null) return info;
    final filled = info.copyWith(size: size);
    final id = song.urlId ?? song.id;
    final cacheKey =
        '${song.onlineProvider ?? ''}:${song.onlineSource ?? 'netease'}:$id:${_qualityFromBitRate(maxBitRate)}';
    final cached = _playbackUrlCache[cacheKey];
    if (cached != null) {
      _playbackUrlCache[cacheKey] = (filled, cached.$2);
    }
    return filled;
  }

  String _mediaCacheKey(Song song, String id) =>
      '${song.onlineProvider}:${song.onlineSource}:$id';

  String _coverCacheKey(Song song, String id) =>
      '${_mediaCacheKey(song, id)}:300';

  String buildCoverProxyUrl(Song song, {int size = 300}) {
    final coverArtId = song.coverArt;
    if (coverArtId == null || coverArtId.isEmpty) return '';

    final query = Uri(
      queryParameters: {
        'id': coverArtId,
        'source': song.onlineSource ?? 'netease',
        if (song.onlineProvider?.isNotEmpty ?? false)
          'provider': song.onlineProvider,
        'size': '$size',
      },
    ).query;

    // Direct cloud cover endpoint (resolved URL preferred via resolveCoverArtUrl).
    return '$_cloudBaseUrl/v1/music/cover?$query';
  }

  Future<String> resolveCoverArtUrl(Song song, {int size = 300}) async {
    final detailCacheKey = _coverCacheKey(song, song.urlId ?? song.id);
    final detailCached = _coverArtCache[detailCacheKey];
    if (detailCached != null) return detailCached;
    final missingUntil = _missingCoverCache[detailCacheKey];
    if (missingUntil != null && missingUntil.isAfter(DateTime.now())) return '';
    _missingCoverCache.remove(detailCacheKey);

    final coverArtId = song.coverArt;
    if (coverArtId == null || coverArtId.isEmpty) return '';
    final direct = Uri.tryParse(coverArtId);
    if (direct != null &&
        (direct.scheme == 'http' || direct.scheme == 'https') &&
        direct.host.isNotEmpty) {
      return direct.toString();
    }
    final cacheKey =
        '${song.onlineProvider}:${song.onlineSource}:$coverArtId:$size';
    final cached = _coverArtCache[cacheKey];
    if (cached != null) return cached;

    final pending = _coverRequests[cacheKey];
    if (pending != null) return pending;
    final request = _fetchCoverArtUrl(
      song,
      coverArtId: coverArtId,
      size: size,
      cacheKey: cacheKey,
      detailCacheKey: detailCacheKey,
    );
    _coverRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_coverRequests[cacheKey], request)) {
        _coverRequests.remove(cacheKey);
      }
    }
  }

  Future<String> _fetchCoverArtUrl(
    Song song, {
    required String coverArtId,
    required int size,
    required String cacheKey,
    required String detailCacheKey,
  }) async {
    try {
      final response = await _dio.get(
        '$_cloudBaseUrl/v1/music/cover',
        queryParameters: {
          'id': coverArtId,
          'source': song.onlineSource ?? 'netease',
          if (song.onlineProvider?.isNotEmpty ?? false)
            'provider': song.onlineProvider,
          'size': size,
        },
        options: _cloudOptions(),
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Cloud cover response must be an object');
      }
      final url = data['url']?.toString() ?? '';
      if (url.isEmpty) {
        _cacheMissingCover(detailCacheKey);
        return '';
      }
      _coverArtCache[cacheKey] = url;
      return url;
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? (error.response?.data as Map)['detail']?.toString() ?? ''
          : '';
      if (detail.contains('cover empty') ||
          detail.contains('music adapter unavailable')) {
        _cacheMissingCover(detailCacheKey);
        return '';
      }
      rethrow;
    }
  }

  void _cacheMissingCover(String key) {
    _missingCoverCache[key] = DateTime.now().add(_missingMediaCacheTtl);
  }

  Future<String?> queueNasDownload({
    required String url,
    required String filename,
    required Map<String, dynamic> song,
    String? picUrl,
    String? lyric,
    bool force = false,
  }) async {
    if (!canMutateNas) {
      throw StateError('Cloud is not configured');
    }

    final payload = {
      'url': url,
      'filename': filename,
      'song': song,
      if (picUrl != null && picUrl.isNotEmpty) 'picUrl': picUrl,
      if (lyric != null && lyric.isNotEmpty) 'lyric': lyric,
      'force': force,
      'wait': false,
    };

    // Accept returns quickly. Old servers ignore wait and still block;
    // keep a long POST timeout so those clients do not fail at 20s.
    const importTimeout = Duration(minutes: 5);
    if (isConfigured) {
      return _postImport(
        '$_cloudBaseUrl/v1/library/import',
        payload,
        _cloudOptions().copyWith(
          contentType: 'application/json',
          sendTimeout: importTimeout,
          receiveTimeout: importTimeout,
        ),
        filename: filename,
      );
    }

    return _postImport(
      '$_nasBaseUrl/v1/nas/import',
      payload,
      _nasOptions(
        contentType: 'application/json',
      ).copyWith(sendTimeout: importTimeout, receiveTimeout: importTimeout),
      filename: filename,
      legacyPath: '$_nasBaseUrl/api/nas-download',
    );
  }

  Future<NasImportProgress> getNasImportProgress() async {
    if (!canMutateNas) {
      return const NasImportProgress();
    }
    try {
      if (isConfigured) {
        final response = await _dio.get(
          '$_cloudBaseUrl/v1/library/import/progress',
          options: _cloudOptions().copyWith(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        return _parseImportProgress(response.data);
      }
      final response = await _dio.get(
        '$_nasBaseUrl/v1/nas/import/progress',
        options: _nasOptions().copyWith(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return _parseImportProgress(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const NasImportProgress();
      }
      rethrow;
    }
  }

  static NasImportProgress _parseImportProgress(dynamic data) {
    if (data is! Map) {
      throw const FormatException('NAS import progress must be an object');
    }
    return NasImportProgress.fromJson(data);
  }

  Future<String?> _postImport(
    String path,
    Map<String, dynamic> payload,
    Options options, {
    required String filename,
    String? legacyPath,
  }) async {
    try {
      final response = await _dio.post(path, data: payload, options: options);
      return await _resultFromImportResponse(response, filename);
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        final data = error.response?.data;
        final detail = data is Map ? data['detail']?.toString() : null;
        final message = detail == null || detail.isEmpty
            ? 'Song already exists in the Navidrome library'
            : detail;
        if (message.toLowerCase().contains('already running')) {
          throw StateError(message);
        }
        throw NasDuplicateException(message);
      }
      if (legacyPath != null && error.response?.statusCode == 404) {
        final response = await _dio.post(
          legacyPath,
          data: payload,
          options: options,
        );
        return await _resultFromImportResponse(response, filename);
      }
      throw StateError(formatNasImportError(error));
    }
  }

  Future<String?> _resultFromImportResponse(
    Response<dynamic> response,
    String filename,
  ) async {
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('NAS import response must be an object');
    }
    if (data['ok'] == true || data['success'] == true) {
      final message = data['message']?.toString().trim();
      if (message == null || message.isEmpty) return null;
      return message;
    }
    final stage = data['stage']?.toString();
    if (stage == 'completed') {
      final message = data['message']?.toString().trim();
      return message == null || message.isEmpty ? null : message;
    }
    if (stage == 'failed') {
      final error = data['error']?.toString().trim();
      throw StateError(
        error == null || error.isEmpty ? 'NAS download failed' : error,
      );
    }
    if (response.statusCode == 202 ||
        stage == 'queued' ||
        stage == 'downloading' ||
        stage == 'finishing') {
      return _awaitNasImport(filename);
    }
    final error =
        data['error']?.toString().trim() ?? data['detail']?.toString().trim();
    throw StateError(
      error == null || error.isEmpty ? 'NAS download failed' : error,
    );
  }

  Future<String?> _awaitNasImport(String filename) async {
    final deadline = DateTime.now().add(const Duration(hours: 2));
    var sawJob = false;
    var idleStreak = 0;
    while (DateTime.now().isBefore(deadline)) {
      final progress = await getNasImportProgress();
      final sameFile =
          progress.filename == null || progress.filename == filename;
      if (sameFile && progress.stage == 'completed') {
        final message = progress.message?.trim();
        return message == null || message.isEmpty ? null : message;
      }
      if (sameFile && progress.stage == 'failed') {
        final error = progress.error?.trim();
        throw StateError(
          error == null || error.isEmpty ? 'NAS download failed' : error,
        );
      }
      if (progress.active ||
          progress.stage == 'downloading' ||
          progress.stage == 'finishing' ||
          progress.stage == 'queued') {
        sawJob = true;
        idleStreak = 0;
      } else if (progress.stage == 'idle') {
        idleStreak += 1;
        if (sawJob && idleStreak >= 3) {
          throw StateError('NAS import ended without a result');
        }
        if (!sawJob && idleStreak >= 8) {
          throw StateError('NAS import progress unavailable');
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('NAS import timed out');
  }

  /// 获取歌词的原始 LRC 文本（用于导入/下载时保存）
  Future<String?> getRawLyrics(Song song) async {
    final lyricId = song.lyricId ?? song.id;
    final response = await _dio.get(
      '$_cloudBaseUrl/v1/music/lyric',
      queryParameters: {
        'id': lyricId,
        'source': song.onlineSource ?? 'netease',
        if (song.onlineProvider?.isNotEmpty ?? false)
          'provider': song.onlineProvider,
      },
      options: _cloudOptions(),
    );

    final data = response.data;
    if (data is! Map) return null;

    final lyric = data['lyric']?.toString() ?? '';
    return lyric.isEmpty ? null : lyric;
  }

  Future<LyricsList?> getLyrics(Song song) async {
    final lyricId = song.lyricId ?? song.id;
    final cached = _lyricsCache[_mediaCacheKey(song, lyricId)];
    if (cached != null) return _parseLyrics(cached);
    final missingUntil = _missingLyricsCache[_mediaCacheKey(song, lyricId)];
    if (missingUntil != null && missingUntil.isAfter(DateTime.now())) {
      return null;
    }
    _missingLyricsCache.remove(_mediaCacheKey(song, lyricId));
    debugPrint('[Backend] getLyrics: source=${song.onlineSource ?? 'unknown'}');
    final response = await _dio.get(
      '$_cloudBaseUrl/v1/music/lyric',
      queryParameters: {
        'id': lyricId,
        'source': song.onlineSource ?? 'netease',
        if (song.onlineProvider?.isNotEmpty ?? false)
          'provider': song.onlineProvider,
      },
      options: _cloudOptions(),
    );

    final data = response.data;
    if (data is! Map) {
      debugPrint(
        '[Backend] getLyrics ERROR: response is not a map: ${data.runtimeType}',
      );
      throw const FormatException('Cloud lyric response must be an object');
    }

    final lyric = data['lyric']?.toString() ?? '';
    debugPrint(
      '[Backend] getLyrics: lyric length=${lyric.length}, empty=${lyric.isEmpty}',
    );
    if (lyric.isEmpty) {
      _missingLyricsCache[_mediaCacheKey(song, lyricId)] = DateTime.now().add(
        _missingMediaCacheTtl,
      );
      return null;
    }

    return _parseLyrics(lyric);
  }

  LyricsList? _parseLyrics(String lyric) {
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

  /// Delete local library songs by Navidrome media_file id.
  Future<NasDeleteResult> deleteLibrarySongs(List<String> navidromeIds) async {
    debugPrint('[Backend] deleting songs count=${navidromeIds.length}');
    if (!canMutateNas) {
      throw StateError('Cloud is not configured');
    }
    final path = isConfigured
        ? '$_cloudBaseUrl/v1/library/delete'
        : '$_nasBaseUrl/v1/songs/delete';
    final response = await _dio.post(
      path,
      data: {'song_ids': navidromeIds},
      options: isConfigured
          ? _cloudOptions().copyWith(contentType: 'application/json')
          : _nasOptions(contentType: 'application/json'),
    );
    return _parseDeleteResponse(response.data);
  }

  void _ensureDirectNasAgent() {
    if (!canAuditLibrary) {
      throw StateError('NAS agent is not configured');
    }
  }

  Map<String, dynamic> _requireObject(dynamic data, String name) {
    if (data is! Map) {
      throw FormatException('$name must be an object');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<LibraryAuditSnapshot> getLibraryAudit() async {
    _ensureDirectNasAgent();
    final response = await _dio.get(
      '$_nasBaseUrl/v1/nas/library-audit',
      options: _nasOptions().copyWith(
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    return LibraryAuditSnapshot.fromJson(
      _requireObject(response.data, 'Library audit'),
    );
  }

  Future<LibraryAuditSnapshot> startLibraryAudit({
    LibraryAuditRules rules = const LibraryAuditRules(),
  }) async {
    _ensureDirectNasAgent();
    try {
      final response = await _dio.post(
        '$_nasBaseUrl/v1/nas/library-audit',
        data: rules.toJson(),
        options: _nasOptions(contentType: 'application/json').copyWith(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return LibraryAuditSnapshot.fromJson(
        _requireObject(response.data, 'Library audit'),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        return getLibraryAudit();
      }
      throw StateError(formatNasImportError(error));
    }
  }

  Future<LibraryAuditSnapshot> startLibraryAuditDeep({
    String scope = 'findings',
    List<String> songIds = const [],
  }) async {
    _ensureDirectNasAgent();
    try {
      final response = await _dio.post(
        '$_nasBaseUrl/v1/nas/library-audit/deep',
        data: {'scope': scope, if (songIds.isNotEmpty) 'song_ids': songIds},
        options: _nasOptions(contentType: 'application/json').copyWith(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return LibraryAuditSnapshot.fromJson(
        _requireObject(response.data, 'Library audit'),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        return getLibraryAudit();
      }
      throw StateError(formatNasImportError(error));
    }
  }

  Future<LibraryAuditSnapshot> cancelLibraryAudit() async {
    _ensureDirectNasAgent();
    final response = await _dio.post(
      '$_nasBaseUrl/v1/nas/library-audit/cancel',
      options: _nasOptions(contentType: 'application/json').copyWith(
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    return LibraryAuditSnapshot.fromJson(
      _requireObject(response.data, 'Library audit'),
    );
  }

  Future<List<LibraryAuditFinding>> getLibraryAuditFindings({
    String? code,
  }) async {
    _ensureDirectNasAgent();
    final items = <LibraryAuditFinding>[];
    var offset = 0;
    const limit = 200;
    while (true) {
      final response = await _dio.get(
        '$_nasBaseUrl/v1/nas/library-audit/findings',
        queryParameters: {
          'offset': offset,
          'limit': limit,
          if (code != null && code.isNotEmpty) 'code': code,
        },
        options: _nasOptions().copyWith(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final page = LibraryAuditFindingsPage.fromJson(
        _requireObject(response.data, 'Library audit findings'),
      );
      items.addAll(page.items);
      if (items.length >= page.total || page.items.isEmpty) {
        return items;
      }
      offset += page.items.length;
    }
  }

  NasDeleteResult _parseDeleteResponse(dynamic data) {
    if (data is! Map) {
      throw const FormatException('NAS delete response must be an object');
    }
    final result = NasDeleteResult(
      deleted: _asInt(data['deleted']),
      skipped: _asInt(data['skipped']),
      errors: _asInt(data['errors']),
      message: data['msg']?.toString() ?? '',
    );
    if (result.errors > 0) {
      throw NasDeleteException(
        result.message.isEmpty ? 'NAS delete failed' : result.message,
      );
    }
    if (result.deleted == 0 && result.skipped > 0) {
      throw const NasDeleteException('song not found in the Navidrome library');
    }
    if (!result.ok) {
      throw NasDeleteException(
        result.message.isEmpty ? 'NAS delete failed' : result.message,
      );
    }
    return result;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
        '$_cloudBaseUrl/v1/recommendations/sessions',
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
        options: _cloudOptions(),
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
        '$_cloudBaseUrl/v1/recommendations/sessions/$encodedSessionId/items',
        queryParameters: {
          'limit': limit,
          ...?cursor == null ? null : {'cursor': cursor},
        },
        options: _cloudOptions(),
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
        '$_cloudBaseUrl/v1/recommendations/feedback',
        data: {
          'idempotencyKey': idempotencyKey,
          'sessionId': sessionId,
          'candidateId': candidateId,
          'event': event.name,
        },
        options: _cloudOptions(),
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
        '$_cloudBaseUrl/v1/recommendations/profile',
        options: _cloudOptions(),
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
    if (raw.isEmpty) return '';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static int? _asPositiveInt(Object? value) {
    final parsed = switch (value) {
      final int number => number,
      final num number => number.toInt(),
      _ => int.tryParse(value?.toString() ?? ''),
    };
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static Future<int?> _probeContentLength(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await _mediaProbeDio.head(url);
      final length = _asPositiveInt(response.headers.value('content-length'));
      if (length != null) return length;
    } catch (_) {}
    return null;
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
