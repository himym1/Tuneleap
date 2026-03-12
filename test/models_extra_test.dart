import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';

void main() {
  group('Genre', () {
    test('fromJson parses full data', () {
      final genre = Genre.fromJson({
        'value': 'Rock',
        'songCount': 150,
        'albumCount': 20,
      });

      expect(genre.name, 'Rock');
      expect(genre.songCount, 150);
      expect(genre.albumCount, 20);
    });

    test('fromJson handles missing fields', () {
      final genre = Genre.fromJson({});

      expect(genre.name, '');
      expect(genre.songCount, 0);
      expect(genre.albumCount, 0);
    });

    test('fromJson handles null value', () {
      final genre = Genre.fromJson({'value': null, 'songCount': 5});

      expect(genre.name, '');
      expect(genre.songCount, 5);
    });
  });

  group('RadioStation', () {
    test('fromJson parses full data', () {
      final station = RadioStation.fromJson({
        'id': 'rs-1',
        'name': 'Jazz FM',
        'streamUrl': 'http://stream.jazzfm.com/live',
        'homePageUrl': 'http://jazzfm.com',
      });

      expect(station.id, 'rs-1');
      expect(station.name, 'Jazz FM');
      expect(station.streamUrl, 'http://stream.jazzfm.com/live');
      expect(station.homePageUrl, 'http://jazzfm.com');
    });

    test('fromJson handles missing optional homePageUrl', () {
      final station = RadioStation.fromJson({
        'id': 'rs-2',
        'name': 'Radio',
        'streamUrl': 'http://stream.example.com',
      });

      expect(station.homePageUrl, isNull);
    });

    test('fromJson handles empty data', () {
      final station = RadioStation.fromJson({});

      expect(station.id, '');
      expect(station.name, '');
      expect(station.streamUrl, '');
      expect(station.homePageUrl, isNull);
    });
  });

  group('Song.formattedDuration', () {
    test('formats duration correctly', () {
      const song = Song(
        id: '1',
        title: 'T',
        album: '',
        albumId: '',
        artist: '',
        artistId: '',
        duration: 185,
      );
      expect(song.formattedDuration, '3:05');
    });

    test('returns empty string for null duration', () {
      const song = Song(
        id: '2',
        title: 'T',
        album: '',
        albumId: '',
        artist: '',
        artistId: '',
      );
      expect(song.formattedDuration, '');
    });
  });
}
