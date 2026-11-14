import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/online_playlist.dart';

void main() {
  test('playlist detail keeps playable song fields', () {
    final detail = OnlinePlaylistDetail.fromJson({
      'id': 4981163,
      'name': '我是歌手第一季-全集',
      'cover_url': 'https://cover.example/season.jpg',
      'track_count': 110,
      'truncated': false,
      'source': 'netease',
      'provider': 'gdstudio',
      'tracks': [
        {
          'id': '26191005',
          'title': '梦田 (Live)',
          'artist': '齐秦 / 齐豫',
          'album': '我是歌手第一季',
          'source': 'netease',
          'provider': 'gdstudio',
          'url_id': '26191005',
          'cover_id': 'https://cover.example/song.jpg',
          'lyric_id': '26191005',
          'duration': 240,
        },
      ],
    });

    expect(detail.name, '我是歌手第一季-全集');
    expect(detail.tracks, hasLength(1));
    final song = detail.tracks.first;
    expect(song.isOnline, isTrue);
    expect(song.title, '梦田 (Live)');
    expect(song.artist, '齐秦 / 齐豫');
    expect(song.onlineSource, 'netease');
    expect(song.onlineProvider, 'gdstudio');
    expect(song.coverArt, 'https://cover.example/song.jpg');
    expect(song.duration, 240);
  });
}
