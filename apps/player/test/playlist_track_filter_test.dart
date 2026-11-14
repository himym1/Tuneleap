import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/playlist_track_filter.dart';

Song _song({
  required String id,
  required String title,
  String artist = '',
  String album = '',
}) {
  return Song(
    id: id,
    title: title,
    album: album,
    albumId: '',
    artist: artist,
    artistId: '',
  );
}

void main() {
  test('blank query keeps every track in order', () {
    final tracks = [
      _song(id: '1', title: 'Red Necks', artist: 'Blur'),
      _song(id: '2', title: 'Daydreamer', artist: 'Menswear'),
    ];
    expect(playlistTrackMatchIndexes(tracks, '  '), [0, 1]);
  });

  test('matches title artist or album and keeps source indexes', () {
    final tracks = [
      _song(
        id: '1',
        title: 'Red Necks',
        artist: 'Blur',
        album: 'End of a Century',
      ),
      _song(
        id: '2',
        title: 'Daydreamer',
        artist: 'Menswear',
        album: 'Nuisance',
      ),
      _song(
        id: '3',
        title: 'Scrawny',
        artist: 'Wallows',
        album: 'Nothing Happens',
      ),
    ];
    expect(playlistTrackMatchIndexes(tracks, 'blur'), [0]);
    expect(playlistTrackMatchIndexes(tracks, 'NUISANCE'), [1]);
    expect(playlistTrackMatchIndexes(tracks, 'wallows scrawny'), [2]);
    expect(playlistTrackMatchIndexes(tracks, '不存在'), isEmpty);
  });
}
