import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/models.dart';

/// Subsonic API 客户端，对接 Navidrome 服务端
class SubsonicClient {
  final Dio _dio;
  late String _baseUrl;
  late String _username;
  late String _password;
  // 每次 configure() 时生成一次，后续复用，保证 URL 稳定可被缓存
  String? _cachedSalt;

  static const String _apiVersion = '1.16.1';
  static const String _clientName = 'NavidromePlayer';

  SubsonicClient({Dio? dio}) : _dio = dio ?? Dio();

  /// 配置服务器连接信息
  void configure({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _baseUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    _username = username;
    _password = password;
    _cachedSalt = _generateSalt(); // 生成一次，复用
  }

  /// 生成认证参数（使用固定 salt，保证封面/流媒体 URL 稳定可缓存）
  Map<String, String> _authParams() {
    final salt = _cachedSalt ?? _generateSalt();
    final token = md5.convert(utf8.encode('$_password$salt')).toString();
    return {
      'u': _username,
      't': token,
      's': salt,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };
  }

  String _generateSalt() {
    final random = Random.secure();
    return List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
  }

  /// 发起 API 请求
  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final queryParams = <String, dynamic>{..._authParams()};
    if (params != null) queryParams.addAll(params);

    final response = await _dio.get(
      '$_baseUrl/rest/$endpoint',
      queryParameters: queryParams,
    );

    final data = response.data as Map<String, dynamic>;
    final subsonicResponse = data['subsonic-response'] as Map<String, dynamic>;

    if (subsonicResponse['status'] != 'ok') {
      final error = subsonicResponse['error'] as Map<String, dynamic>?;
      throw SubsonicApiException(
        code: error?['code'] as int? ?? -1,
        message: error?['message'] as String? ?? 'Unknown error',
      );
    }

    return subsonicResponse;
  }

  // === 系统 ===

  /// 测试服务器连接
  Future<bool> ping() async {
    try {
      await _request('ping');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 触发媒体库扫描
  Future<void> startScan({bool fullScan = false}) async {
    await _request('startScan', params: {if (fullScan) 'fullScan': true});
  }

  // === 浏览 ===

  /// 获取所有艺术家
  Future<List<Artist>> getArtists() async {
    final response = await _request('getArtists');
    final artists = response['artists'] as Map<String, dynamic>;
    final indexes = artists['index'] as List<dynamic>? ?? [];
    return indexes
        .expand((index) => (index['artist'] as List<dynamic>? ?? []))
        .map((a) => Artist.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// 获取艺术家详情（含专辑列表）
  Future<ArtistDetail> getArtist(String id) async {
    final response = await _request('getArtist', params: {'id': id});
    final data = response['artist'] as Map<String, dynamic>;
    final artist = Artist.fromJson(data);
    final albumList = data['album'] as List<dynamic>? ?? [];
    final albums = albumList
        .map((a) => Album.fromJson(a as Map<String, dynamic>))
        .toList();
    return ArtistDetail(artist: artist, albums: albums);
  }

  /// 获取专辑详情（含歌曲列表）
  Future<Album> getAlbum(String id) async {
    final response = await _request('getAlbum', params: {'id': id});
    return Album.fromJson(response['album'] as Map<String, dynamic>);
  }

  /// 获取专辑列表
  Future<List<Album>> getAlbumList2({
    String type = 'newest', // newest, frequent, recent, random, starred
    int size = 20,
    int offset = 0,
  }) async {
    final response = await _request(
      'getAlbumList2',
      params: {'type': type, 'size': size, 'offset': offset},
    );
    final albumList = response['albumList2']?['album'] as List<dynamic>? ?? [];
    return albumList
        .map((a) => Album.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // === 搜索 ===

  /// 全局搜索
  Future<SearchResult> search3(
    String query, {
    int artistCount = 10,
    int albumCount = 10,
    int songCount = 20,
    int artistOffset = 0,
    int albumOffset = 0,
    int songOffset = 0,
  }) async {
    final response = await _request(
      'search3',
      params: {
        'query': query,
        'artistCount': artistCount,
        'albumCount': albumCount,
        'songCount': songCount,
        'artistOffset': artistOffset,
        'albumOffset': albumOffset,
        'songOffset': songOffset,
      },
    );
    final result = response['searchResult3'] as Map<String, dynamic>? ?? {};
    return SearchResult(
      artists: (result['artist'] as List<dynamic>? ?? [])
          .map((a) => Artist.fromJson(a as Map<String, dynamic>))
          .toList(),
      albums: (result['album'] as List<dynamic>? ?? [])
          .map((a) => Album.fromJson(a as Map<String, dynamic>))
          .toList(),
      songs: (result['song'] as List<dynamic>? ?? [])
          .map((s) => Song.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  // === 媒体 ===

  /// 获取音频流 URL
  String streamUrl(String id, {int? maxBitRate}) {
    final params = _authParams();
    params['id'] = id;
    if (maxBitRate != null && maxBitRate > 0) {
      params['maxBitRate'] = maxBitRate.toString();
    }
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_baseUrl/rest/stream?$query';
  }

  /// 获取封面图 URL
  String coverArtUrl(String? coverArtId, {int size = 300}) {
    if (coverArtId == null) return '';
    final params = _authParams();
    params['id'] = coverArtId;
    params['size'] = size.toString();
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_baseUrl/rest/getCoverArt?$query';
  }

  // === 播放列表 ===

  /// 获取所有播放列表
  Future<List<Playlist>> getPlaylists() async {
    final response = await _request('getPlaylists');
    final playlists =
        response['playlists']?['playlist'] as List<dynamic>? ?? [];
    return playlists
        .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// 获取播放列表详情
  Future<Playlist> getPlaylist(String id) async {
    final response = await _request('getPlaylist', params: {'id': id});
    return Playlist.fromJson(response['playlist'] as Map<String, dynamic>);
  }

  /// 创建播放列表
  Future<void> createPlaylist(String name, {List<String>? songIds}) async {
    final params = <String, dynamic>{'name': name};
    if (songIds != null && songIds.isNotEmpty) {
      params['songId'] = songIds;
    }
    await _request('createPlaylist', params: params);
  }

  /// 更新播放列表（重命名、添加歌曲、移除歌曲）
  Future<void> updatePlaylist(
    String id, {
    String? name,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    final params = <String, dynamic>{'playlistId': id};
    if (name != null) params['name'] = name;
    if (songIdsToAdd != null) params['songIdToAdd'] = songIdsToAdd;
    if (songIndexesToRemove != null) {
      params['songIndexToRemove'] = songIndexesToRemove;
    }
    await _request('updatePlaylist', params: params);
  }

  /// 删除播放列表
  Future<void> deletePlaylist(String id) async {
    await _request('deletePlaylist', params: {'id': id});
  }

  // === 标记 ===

  /// 收藏
  Future<void> star({String? id, String? albumId, String? artistId}) async {
    final params = <String, dynamic>{
      ...?switch (id) {
        final value? => {'id': value},
        null => null,
      },
      ...?switch (albumId) {
        final value? => {'albumId': value},
        null => null,
      },
      ...?switch (artistId) {
        final value? => {'artistId': value},
        null => null,
      },
    };
    if (params.isEmpty) {
      throw ArgumentError('At least one target id must be provided');
    }
    await _request('star', params: params);
  }

  /// 取消收藏
  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    final params = <String, dynamic>{
      ...?switch (id) {
        final value? => {'id': value},
        null => null,
      },
      ...?switch (albumId) {
        final value? => {'albumId': value},
        null => null,
      },
      ...?switch (artistId) {
        final value? => {'artistId': value},
        null => null,
      },
    };
    if (params.isEmpty) {
      throw ArgumentError('At least one target id must be provided');
    }
    await _request('unstar', params: params);
  }

  /// 获取收藏内容
  Future<StarredResult> getStarred2() async {
    final data = await _request('getStarred2');
    final starred = data['starred2'] ?? {};
    return StarredResult(
      songs:
          (starred['song'] as List?)?.map((e) => Song.fromJson(e)).toList() ??
          [],
      albums:
          (starred['album'] as List?)?.map((e) => Album.fromJson(e)).toList() ??
          [],
      artists:
          (starred['artist'] as List?)
              ?.map((e) => Artist.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// 获取随机歌曲
  Future<List<Song>> getRandomSongs({int size = 50}) async {
    final response = await _request('getRandomSongs', params: {'size': size});
    final songs = response['randomSongs']?['song'] as List<dynamic>? ?? [];
    return songs.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// 获取与指定本地歌曲相似的歌曲
  Future<List<Song>> getSimilarSongs2(String id, {int count = 50}) async {
    final response = await _request(
      'getSimilarSongs2',
      params: {'id': id, 'count': count},
    );
    final songs = response['similarSongs2']?['song'] as List<dynamic>? ?? [];
    return songs
        .map((song) => Song.fromJson(song as Map<String, dynamic>))
        .toList();
  }

  /// 获取所有流派
  Future<List<Genre>> getGenres() async {
    final response = await _request('getGenres');
    final genres = response['genres']?['genre'] as List<dynamic>? ?? [];
    return genres
        .map((g) => Genre.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  /// 按流派获取歌曲
  Future<List<Song>> getSongsByGenre(
    String genre, {
    int size = 50,
    int offset = 0,
  }) async {
    final response = await _request(
      'getSongsByGenre',
      params: {'genre': genre, 'count': size, 'offset': offset},
    );
    final songs = response['songsByGenre']?['song'] as List<dynamic>? ?? [];
    return songs.map((s) => Song.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// 获取网络电台列表
  Future<List<RadioStation>> getInternetRadioStations() async {
    final response = await _request('getInternetRadioStations');
    final stations =
        response['internetRadioStations']?['internetRadioStation']
            as List<dynamic>? ??
        [];
    return stations
        .map((s) => RadioStation.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// 上报播放记录
  Future<void> scrobble(String id) async {
    await _request('scrobble', params: {'id': id});
  }

  // === 管理 ===

  /// 删除歌曲 — Navidrome 不支持通过 API 删除歌曲文件，
  /// 需要在服务器文件系统上手动删除后触发扫描。
  /// 此方法仅触发媒体库扫描。
  Future<void> deleteSong(String id) async {
    throw UnsupportedError(
      'Navidrome does not support deleting songs via API. '
      'Please delete the file on the server and rescan.',
    );
  }

  /// 获取歌词（getLyricsBySongId，Subsonic API 1.14+）
  Future<LyricsList?> getLyricsBySongId(String id) async {
    try {
      final response = await _request('getLyricsBySongId', params: {'id': id});
      final lyricsList = response['lyricsList'] as Map<String, dynamic>?;
      if (lyricsList == null) return null;
      final structured = lyricsList['structuredLyrics'] as List<dynamic>?;
      if (structured == null || structured.isEmpty) return null;
      // 优先选同步歌词（含时间戳），否则用第一个
      final entry =
          (structured.firstWhere(
                (e) => (e as Map<String, dynamic>)['synced'] == true,
                orElse: () => structured[0],
              ))
              as Map<String, dynamic>;
      final synced = entry['synced'] as bool? ?? false;
      final lines = (entry['line'] as List<dynamic>? ?? []).map((l) {
        final m = l as Map<String, dynamic>;
        return LyricsLine(
          text: m['value'] as String? ?? '',
          startMs: m['start'] as int?,
        );
      }).toList();
      return LyricsList(lines: lines, synced: synced);
    } catch (_) {
      return null;
    }
  }

  /// 下载文件到指定路径，带进度回调
  Future<void> downloadFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

/// 收藏结果
class StarredResult {
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;

  const StarredResult({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
  });
}

/// 搜索结果
class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  const SearchResult({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });
}

/// Subsonic API 异常
class SubsonicApiException implements Exception {
  final int code;
  final String message;

  const SubsonicApiException({required this.code, required this.message});

  @override
  String toString() => 'SubsonicApiException($code): $message';
}

/// 单行歌词
class LyricsLine {
  final String text;
  final int? startMs;
  const LyricsLine({required this.text, this.startMs});
}

/// 歌词列表
class LyricsList {
  final List<LyricsLine> lines;
  final bool synced;
  const LyricsList({required this.lines, required this.synced});
}
