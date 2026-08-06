import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';

void main() {
  group('Song', () {
    test('fromJson parses full JSON correctly', () {
      final json = {
        'id': 's1',
        'title': 'Test Song',
        'album': 'Test Album',
        'albumId': 'a1',
        'artist': 'Test Artist',
        'artistId': 'ar1',
        'track': 3,
        'year': 2024,
        'duration': 240,
        'bitRate': 320,
        'coverArt': 'cover1',
        'suffix': 'flac',
      };

      final song = Song.fromJson(json);

      expect(song.id, 's1');
      expect(song.title, 'Test Song');
      expect(song.album, 'Test Album');
      expect(song.albumId, 'a1');
      expect(song.artist, 'Test Artist');
      expect(song.artistId, 'ar1');
      expect(song.track, 3);
      expect(song.year, 2024);
      expect(song.duration, 240);
      expect(song.bitRate, 320);
      expect(song.coverArt, 'cover1');
      expect(song.suffix, 'flac');
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 's2'};

      final song = Song.fromJson(json);

      expect(song.id, 's2');
      expect(song.title, '');
      expect(song.album, '');
      expect(song.artist, '');
      expect(song.track, isNull);
      expect(song.duration, isNull);
      expect(song.coverArt, isNull);
    });

    test('toJson produces correct output', () {
      const song = Song(
        id: 's1',
        title: 'Test',
        album: 'Album',
        albumId: 'a1',
        artist: 'Artist',
        artistId: 'ar1',
        track: 1,
        duration: 180,
      );

      final json = song.toJson();

      expect(json['id'], 's1');
      expect(json['title'], 'Test');
      expect(json['track'], 1);
      expect(json['duration'], 180);
      expect(json.containsKey('bitRate'), isFalse);
      expect(json.containsKey('coverArt'), isFalse);
    });

    test('toJson round-trips with fromJson', () {
      const original = Song(
        id: 'rt1',
        title: 'Round Trip',
        album: 'RTA',
        albumId: 'rta1',
        artist: 'RTA Artist',
        artistId: 'rtAr1',
        track: 5,
        year: 2025,
        duration: 300,
        bitRate: 128,
        coverArt: 'rtCover',
        suffix: 'mp3',
        backend: SongBackend.solara,
        onlineSource: 'netease',
        onlineProvider: 'gdstudio',
      );

      final roundTripped = Song.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.title, original.title);
      expect(roundTripped.track, original.track);
      expect(roundTripped.suffix, original.suffix);
      expect(roundTripped.onlineProvider, original.onlineProvider);
    });

    test('fromSolaraJson maps online song fields correctly', () {
      final song = Song.fromSolaraJson({
        'id': '5257138',
        'name': '屋顶',
        'artist': ['周杰伦', '温岚'],
        'album': '男女情歌对唱冠军全记录',
        'pic_id': '109951165671182684',
        'url_id': '5257138',
        'lyric_id': '5257138',
        'source': 'netease',
        'provider': 'gdstudio',
      });

      expect(song.id, '5257138');
      expect(song.title, '屋顶');
      expect(song.artist, '周杰伦 / 温岚');
      expect(song.album, '男女情歌对唱冠军全记录');
      expect(song.coverArt, '109951165671182684');
      expect(song.backend, SongBackend.solara);
      expect(song.onlineSource, 'netease');
      expect(song.onlineProvider, 'gdstudio');
      expect(song.urlId, '5257138');
      expect(song.lyricId, '5257138');
      expect(song.isOnline, isTrue);
      expect(song.storageKey, 'solara:netease:5257138');
    });

    test('storageKey distinguishes subsonic and online songs', () {
      const localSong = Song(
        id: 'same-id',
        title: 'Local',
        album: '',
        albumId: '',
        artist: '',
        artistId: '',
      );
      const onlineSong = Song(
        id: 'same-id',
        title: 'Online',
        album: '',
        albumId: '',
        artist: '',
        artistId: '',
        backend: SongBackend.solara,
        onlineSource: 'kuwo',
      );

      expect(localSong.storageKey, 'subsonic:same-id');
      expect(onlineSong.storageKey, 'solara:kuwo:same-id');
    });
  });

  group('Album', () {
    test('fromJson parses album without songs', () {
      final json = {
        'id': 'a1',
        'name': 'Test Album',
        'artist': 'Test Artist',
        'artistId': 'ar1',
        'coverArt': 'cover1',
        'songCount': 10,
        'duration': 2400,
        'year': 2024,
      };

      final album = Album.fromJson(json);

      expect(album.id, 'a1');
      expect(album.name, 'Test Album');
      expect(album.artist, 'Test Artist');
      expect(album.songCount, 10);
      expect(album.songs, isEmpty);
    });

    test('fromJson parses album with nested songs', () {
      final json = {
        'id': 'a2',
        'name': 'With Songs',
        'song': [
          {'id': 's1', 'title': 'Song 1'},
          {'id': 's2', 'title': 'Song 2'},
        ],
      };

      final album = Album.fromJson(json);

      expect(album.songs.length, 2);
      expect(album.songs[0].title, 'Song 1');
      expect(album.songs[1].title, 'Song 2');
    });

    test('fromJson uses title as fallback for name', () {
      final json = {'id': 'a3', 'title': 'Fallback Name'};

      final album = Album.fromJson(json);

      expect(album.name, 'Fallback Name');
    });

    test('fromJson handles no name and no title', () {
      final json = {'id': 'a4'};

      final album = Album.fromJson(json);

      expect(album.name, '');
    });
  });

  group('Artist', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'ar1',
        'name': 'Test Artist',
        'coverArt': 'arCover1',
        'albumCount': 5,
      };

      final artist = Artist.fromJson(json);

      expect(artist.id, 'ar1');
      expect(artist.name, 'Test Artist');
      expect(artist.coverArt, 'arCover1');
      expect(artist.albumCount, 5);
    });

    test('fromJson uses artistImageUrl as coverArt fallback', () {
      final json = {
        'id': 'ar2',
        'name': 'Image Artist',
        'artistImageUrl': 'http://example.com/image.jpg',
      };

      final artist = Artist.fromJson(json);

      expect(artist.coverArt, 'http://example.com/image.jpg');
    });

    test('fromJson handles minimal data', () {
      final json = {'id': 'ar3'};

      final artist = Artist.fromJson(json);

      expect(artist.id, 'ar3');
      expect(artist.name, '');
      expect(artist.coverArt, isNull);
      expect(artist.albumCount, isNull);
    });
  });

  group('ArtistDetail', () {
    test('constructs with artist and albums', () {
      const artist = Artist(id: 'ar1', name: 'A');
      const albums = [Album(id: 'a1', name: 'Album 1')];
      const detail = ArtistDetail(artist: artist, albums: albums);

      expect(detail.artist.name, 'A');
      expect(detail.albums.length, 1);
    });
  });

  group('Playlist', () {
    test('fromJson parses playlist without entries', () {
      final json = {
        'id': 'p1',
        'name': 'My Playlist',
        'songCount': 5,
        'duration': 1200,
        'owner': 'admin',
      };

      final playlist = Playlist.fromJson(json);

      expect(playlist.id, 'p1');
      expect(playlist.name, 'My Playlist');
      expect(playlist.songCount, 5);
      expect(playlist.owner, 'admin');
      expect(playlist.songs, isEmpty);
    });

    test('fromJson parses playlist with entries', () {
      final json = {
        'id': 'p2',
        'name': 'With Songs',
        'entry': [
          {'id': 's1', 'title': 'Song 1'},
          {'id': 's2', 'title': 'Song 2'},
        ],
      };

      final playlist = Playlist.fromJson(json);

      expect(playlist.songs.length, 2);
      expect(playlist.songs[0].id, 's1');
    });
  });
}
