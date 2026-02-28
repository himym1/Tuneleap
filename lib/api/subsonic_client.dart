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

  static const String _apiVersion = '1.16.1';
  static const String _clientName = 'NavidromePlayer';

  SubsonicClient({Dio? dio}) : _dio = dio ?? Dio();

  /// 配置服务器连接信息
  void configure({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _baseUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    _username = username;
    _password = password;
  }

  /// 生成认证参数
  Map<String, String> _authParams() {
    final salt = _generateSalt();
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
    return List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join();
  }

  /// 发起 API 请求
  Future<Map<String, dynamic>> _request(String endpoint, {Map<String, dynamic>? params}) async {
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
    final albums = albumList.map((a) => Album.fromJson(a as Map<String, dynamic>)).toList();
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
    final response = await _request('getAlbumList2', params: {
      'type': type,
      'size': size,
      'offset': offset,
    });
    final albumList = response['albumList2']?['album'] as List<dynamic>? ?? [];
    return albumList.map((a) => Album.fromJson(a as Map<String, dynamic>)).toList();
  }

  // === 搜索 ===

  /// 全局搜索
  Future<SearchResult> search3(String query, {int artistCount = 10, int albumCount = 10, int songCount = 20}) async {
    final response = await _request('search3', params: {
      'query': query,
      'artistCount': artistCount,
      'albumCount': albumCount,
      'songCount': songCount,
    });
    final result = response['searchResult3'] as Map<String, dynamic>? ?? {};
    return SearchResult(
      artists: (result['artist'] as List<dynamic>? ?? []).map((a) => Artist.fromJson(a as Map<String, dynamic>)).toList(),
      albums: (result['album'] as List<dynamic>? ?? []).map((a) => Album.fromJson(a as Map<String, dynamic>)).toList(),
      songs: (result['song'] as List<dynamic>? ?? []).map((s) => Song.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  // === 媒体 ===

  /// 获取音频流 URL
  String streamUrl(String id) {
    final params = _authParams();
    params['id'] = id;
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_baseUrl/rest/stream?$query';
  }

  /// 获取封面图 URL
  String coverArtUrl(String? coverArtId, {int size = 300}) {
    if (coverArtId == null) return '';
    final params = _authParams();
    params['id'] = coverArtId;
    params['size'] = size.toString();
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_baseUrl/rest/getCoverArt?$query';
  }

  // === 播放列表 ===

  /// 获取所有播放列表
  Future<List<Playlist>> getPlaylists() async {
    final response = await _request('getPlaylists');
    final playlists = response['playlists']?['playlist'] as List<dynamic>? ?? [];
    return playlists.map((p) => Playlist.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// 获取播放列表详情
  Future<Playlist> getPlaylist(String id) async {
    final response = await _request('getPlaylist', params: {'id': id});
    return Playlist.fromJson(response['playlist'] as Map<String, dynamic>);
  }

  // === 标记 ===

  /// 收藏
  Future<void> star({String? id, String? albumId, String? artistId}) async {
    await _request('star', params: {
      if (id != null) 'id': id,
      if (albumId != null) 'albumId': albumId,
      if (artistId != null) 'artistId': artistId,
    });
  }

  /// 取消收藏
  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    await _request('unstar', params: {
      if (id != null) 'id': id,
      if (albumId != null) 'albumId': albumId,
      if (artistId != null) 'artistId': artistId,
    });
  }

  /// 上报播放记录
  Future<void> scrobble(String id) async {
    await _request('scrobble', params: {'id': id});
  }
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
