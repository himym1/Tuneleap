import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/solara_client.dart';
import 'package:navidrome_player/providers/navidrome_import_provider.dart';

class _FakeSolaraClient extends SolaraClient {
  _FakeSolaraClient({required this.playbackUrl, required this.queueMessage});

  final String playbackUrl;
  final String? queueMessage;
  late String queuedUrl;
  late String queuedFilename;
  late Map<String, dynamic> queuedSong;
  String? queuedPicUrl;

  @override
  bool get isConfigured => true;

  @override
  Future<String> getPlaybackUrl(Song song, {int? maxBitRate}) async {
    return playbackUrl;
  }

  @override
  String buildCoverProxyUrl(Song song, {int size = 300}) {
    return 'http://solara.local/proxy?types=pic&id=${song.coverArt}&size=$size';
  }

  @override
  Future<String?> queueNasDownload({
    required String url,
    required String filename,
    required Map<String, dynamic> song,
    String? picUrl,
  }) async {
    queuedUrl = url;
    queuedFilename = filename;
    queuedSong = song;
    queuedPicUrl = picUrl;
    return queueMessage;
  }
}

void main() {
  group('NavidromeImportService helpers', () {
    test('buildFileName uses stable ascii-safe source and id', () {
      const song = Song(
        id: 'abc',
        title: '屋顶',
        album: '',
        albumId: '',
        artist: '周杰伦',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'netease',
        urlId: 'id+/=123',
      );

      final filename = NavidromeImportService.buildFileName(
        song,
        extension: 'mp3',
      );

      expect(filename, 'solara_netease_id_123.mp3');
    });

    test('inferFileExtension prefers playback url extension', () {
      const song = Song(
        id: 'abc',
        title: 'Track',
        album: '',
        albumId: '',
        artist: '',
        artistId: '',
        backend: SongBackend.solara,
      );

      expect(
        NavidromeImportService.inferFileExtension(
          'https://cdn.example.com/path/song.flac?token=1',
          song,
        ),
        'flac',
      );
      expect(
        NavidromeImportService.inferFileExtension(
          'https://cdn.example.com/path/stream',
          song,
        ),
        'mp3',
      );
    });

    test('buildNasDownloadSong matches Solara web payload shape', () {
      const song = Song(
        id: 'abc',
        title: 'Track',
        album: 'Album',
        albumId: '',
        artist: 'Artist',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'kuwo',
        urlId: 'url-123',
        lyricId: 'lyric-456',
        coverArt: 'pic-789',
      );

      final payload = NavidromeImportService.buildNasDownloadSong(song);

      expect(payload['id'], 'url-123');
      expect(payload['url_id'], 'url-123');
      expect(payload['lyric_id'], 'lyric-456');
      expect(payload['name'], 'Track');
      expect(payload['title'], 'Track');
      expect(payload['artist'], 'Artist');
      expect(payload['album'], 'Album');
      expect(payload['source'], 'kuwo');
      expect(payload['pic_id'], 'pic-789');
    });
  });

  group('NavidromeImportService', () {
    test('queues Solara NAS download instead of using ssh/scp', () async {
      const song = Song(
        id: '1899989255',
        title: '天地龙鳞',
        album: 'Album',
        albumId: '',
        artist: '王力宏',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'netease',
        urlId: '1899989255',
        lyricId: '1899989255',
        coverArt: '109951166681216835',
      );
      final solaraClient = _FakeSolaraClient(
        playbackUrl: 'https://cdn.example.com/song.flac?token=1',
        queueMessage: 'queued',
      );
      final service = NavidromeImportService(solaraClient: solaraClient);

      final result = await service.importOnlineSong(song);

      expect(result.filename, 'solara_netease_1899989255.flac');
      expect(result.message, 'queued');
      expect(
        solaraClient.queuedUrl,
        'https://cdn.example.com/song.flac?token=1',
      );
      expect(solaraClient.queuedFilename, 'solara_netease_1899989255.flac');
      expect(solaraClient.queuedSong['name'], '天地龙鳞');
      expect(solaraClient.queuedSong['source'], 'netease');
      expect(
        solaraClient.queuedPicUrl,
        'http://solara.local/proxy?types=pic&id=109951166681216835&size=300',
      );
    });
  });
}
