import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/navidrome_import_provider.dart';
import 'package:navidrome_player/utils/library_style.dart';

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.onFetch);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  )
  onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

void main() {
  test('closed styles stay a fixed set of 14 names', () {
    expect(libraryStyleNames, hasLength(14));
    expect(libraryStyleSet, containsAll(libraryStyleNames));
  });

  test('parses genre from Subsonic song json', () {
    final song = Song.fromJson({
      'id': '1',
      'title': '歌',
      'artist': '歌手',
      'album': '专辑',
      'albumId': 'a',
      'artistId': 'b',
      'genre': ' 民谣 ',
    });
    expect(song.genre, '民谣');
    expect(song.copyWith(genre: '摇滚').genre, '摇滚');
  });

  test('skips already tagged songs when analyzing missing only', () {
    final suggestion = suggestLibraryStyle(
      title: '晴天',
      artist: '周杰伦',
      album: '叶惠美',
      currentGenre: '华语流行',
    );
    expect(suggestion.decision, LibraryStyleDecision.skip);
  });

  test('keeps existing closed genre when analyzing all', () {
    final suggestion = suggestLibraryStyle(
      title: '晴天',
      artist: '周杰伦',
      album: '叶惠美',
      currentGenre: '华语流行',
      missingOnly: false,
    );
    expect(suggestion.shouldWrite, isTrue);
    expect(suggestion.style, '华语流行');
  });

  test('ost markers beat language defaults', () {
    final suggestion = suggestLibraryStyle(
      title: '名探偵コナン 主题曲',
      artist: '仓木麻衣',
      album: 'Detective Conan',
    );
    expect(suggestion.style, '影视原声');
    expect(suggestion.confidence, LibraryStyleConfidence.high);
  });

  test('kana titles become 日本流行 when they are not ost', () {
    final suggestion = suggestLibraryStyle(
      title: '北国の春',
      artist: '邓丽君',
      album: 'シングル',
    );
    expect(suggestion.style, '日本流行');
  });

  test('cjk songs default to 华语流行 for preview', () {
    final suggestion = suggestLibraryStyle(
      title: '红玫瑰',
      artist: '陈奕迅',
      album: '认了吧',
    );
    expect(suggestion.style, '华语流行');
    expect(suggestion.confidence, LibraryStyleConfidence.medium);
  });

  test('latin songs without markers stay in review', () {
    final suggestion = suggestLibraryStyle(
      title: 'Blank Space',
      artist: 'Taylor Swift',
      album: '1989',
    );
    expect(suggestion.decision, LibraryStyleDecision.review);
    expect(
      highConfidenceImportGenre(
        title: 'Blank Space',
        artist: 'Taylor Swift',
        album: '1989',
      ),
      isNull,
    );
  });

  test('cjk default is not written on silent import', () {
    expect(
      highConfidenceImportGenre(title: '红玫瑰', artist: '陈奕迅', album: '认了吧'),
      isNull,
    );
    expect(
      highConfidenceImportGenre(title: '主题曲', artist: '仓木麻衣', album: 'OST'),
      '影视原声',
    );
  });

  test('import payload includes only high-confidence genre', () {
    const ost = Song(
      id: '1',
      title: '主题曲',
      album: '影视原声带',
      albumId: '',
      artist: '歌手',
      artistId: '',
      backend: SongBackend.solara,
      onlineSource: 'netease',
      urlId: 'url-1',
    );
    const pop = Song(
      id: '2',
      title: '红玫瑰',
      album: '认了吧',
      albumId: '',
      artist: '陈奕迅',
      artistId: '',
      backend: SongBackend.solara,
      onlineSource: 'netease',
      urlId: 'url-2',
    );
    expect(NavidromeImportService.buildNasDownloadSong(ost)['genre'], '影视原声');
    expect(
      NavidromeImportService.buildNasDownloadSong(pop).containsKey('genre'),
      isFalse,
    );
    expect(
      NavidromeImportService.buildNasDownloadSong(pop, genre: '华语流行')['genre'],
      '华语流行',
    );
  });

  test('media-tags posts genre to the NAS agent', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
        captured = options;
        return _jsonBody({
          'ok': true,
          'song_id': 'song1',
          'updated': ['genre'],
          'message': '',
        });
      });
    final client = BackendClient(dio: dio)
      ..configure(
        cloudBaseUrl: 'http://cloud:8600',
        nasAgentUrl: 'http://192.168.1.10:8504',
        nasAgentKey: 'nas-key',
      );

    final result = await client.updateMediaTags(songId: 'song1', genre: '民谣');
    expect(captured.path, 'http://192.168.1.10:8504/v1/nas/media-tags');
    expect(captured.method, 'POST');
    expect(captured.data, {
      'song_id': 'song1',
      'song': {'genre': '民谣'},
    });
    expect(result.ok, isTrue);
    expect(result.updated, ['genre']);
  });

  test('lookup overrides review and medium local guesses', () {
    final review = suggestLibraryStyle(
      title: 'Blank Space',
      artist: 'Taylor Swift',
      album: '1989',
    );
    expect(needsStyleLookup(review), isTrue);
    final merged = mergeLookupStyle(
      local: review,
      remoteStyle: '欧美流行',
      provider: 'itunes',
      title: 'Blank Space',
      artist: 'Taylor Swift',
      album: '1989',
    );
    expect(merged.style, '欧美流行');
    expect(merged.confidence, LibraryStyleConfidence.high);
    expect(merged.evidence, 'lookup:itunes');
  });

  test('coarse mandopop lookup refines title markers', () {
    final local = suggestLibraryStyle(
      title: '恋爱情歌',
      artist: '歌手',
      album: '精选',
    );
    final merged = mergeLookupStyle(
      local: local,
      remoteStyle: '华语流行',
      provider: 'itunes',
      title: '恋爱情歌',
      artist: '歌手',
      album: '精选',
    );
    expect(merged.style, '抒情情歌');
    expect(merged.evidence, 'lookup:itunes+refine');
  });

  test('high-confidence local markers skip cloud lookup', () {
    final ost = suggestLibraryStyle(title: '主题曲', artist: '仓木麻衣', album: 'OST');
    expect(needsStyleLookup(ost), isFalse);
    expect(
      mergeLookupStyle(local: ost, remoteStyle: null, provider: 'itunes').style,
      '影视原声',
    );
  });

  test('cloud json keeps genre from SongDTO', () {
    final song = Song.fromCloudJson({
      'id': '1',
      'title': '晴天',
      'artist': '周杰伦',
      'album': '叶惠美',
      'source': 'netease',
      'provider': 'gdstudio',
      'genre': '华语流行',
    });
    expect(song.genre, '华语流行');
  });

  test('style lookup posts a batch to cloud', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
        captured = options;
        return _jsonBody({
          'items': [
            {
              'title': '晴天',
              'artist': '周杰伦',
              'style': '华语流行',
              'raw_genre': '国语流行',
              'provider': 'itunes',
            },
          ],
        });
      });
    final client = BackendClient(dio: dio)
      ..configure(cloudBaseUrl: 'http://cloud:8600');

    final hits = await client.lookupStyles([
      (title: '晴天', artist: '周杰伦', album: '叶惠美', year: 2003),
    ]);
    expect(captured.path, 'http://cloud:8600/v1/music/style-lookup');
    expect(captured.method, 'POST');
    expect(captured.data, {
      'tracks': [
        {'title': '晴天', 'artist': '周杰伦', 'album': '叶惠美', 'year': 2003},
      ],
    });
    expect(hits.single.style, '华语流行');
    expect(hits.single.provider, 'itunes');
  });

  test('media-tags requires a direct NAS agent', () {
    final client = BackendClient(dio: Dio())
      ..configure(cloudBaseUrl: 'https://cloud.example.com');
    expect(
      () => client.updateMediaTags(songId: 'song1', genre: '民谣'),
      throwsStateError,
    );
  });
}
