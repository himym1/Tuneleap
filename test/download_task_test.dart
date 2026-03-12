import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/download_provider.dart';

void main() {
  const testSong = Song(
    id: 'song-1',
    title: 'Test Song',
    artist: 'Test Artist',
    artistId: 'ar-1',
    album: 'Test Album',
    albumId: 'al-1',
    duration: 240,
    track: 3,
    coverArt: 'cover-1',
    suffix: 'flac',
  );

  group('DownloadTask', () {
    test('toJson produces expected keys', () {
      const task = DownloadTask(
        id: 'subsonic:song-1',
        song: testSong,
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: '/downloads/song.flac',
        fileSizeBytes: 12345678,
      );

      final json = task.toJson();

      expect(json['id'], 'subsonic:song-1');
      expect(json['songId'], 'song-1');
      expect(json['songTitle'], 'Test Song');
      expect(json['songArtist'], 'Test Artist');
      expect(json['songAlbum'], 'Test Album');
      expect(json['songDuration'], 240);
      expect(json['songTrack'], 3);
      expect(json['songCoverArt'], 'cover-1');
      expect(json['songSuffix'], 'flac');
      expect(json['songBackend'], 'subsonic');
      expect(json['localPath'], '/downloads/song.flac');
      expect(json['fileSizeBytes'], 12345678);
    });

    test('fromJson restores completed task correctly', () {
      final json = {
        'id': 'subsonic:song-1',
        'songId': 'song-1',
        'songTitle': 'Test Song',
        'songArtist': 'Test Artist',
        'songArtistId': 'ar-1',
        'songAlbum': 'Test Album',
        'songAlbumId': 'al-1',
        'songDuration': 240,
        'songTrack': 3,
        'songCoverArt': 'cover-1',
        'songSuffix': 'flac',
        'songBackend': 'subsonic',
        'localPath': '/downloads/song.flac',
        'fileSizeBytes': 12345678,
      };

      final task = DownloadTask.fromJson(json);

      expect(task.id, 'subsonic:song-1');
      expect(task.status, DownloadStatus.completed);
      expect(task.progress, 1.0);
      expect(task.localPath, '/downloads/song.flac');
      expect(task.fileSizeBytes, 12345678);
      expect(task.song.id, 'song-1');
      expect(task.song.title, 'Test Song');
      expect(task.song.artist, 'Test Artist');
      expect(task.song.duration, 240);
      expect(task.song.suffix, 'flac');
      expect(task.song.backend, SongBackend.subsonic);
    });

    test('toJson/fromJson round-trip preserves data', () {
      const original = DownloadTask(
        id: 'subsonic:song-1',
        song: testSong,
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: '/downloads/song.flac',
        fileSizeBytes: 9876543,
      );

      final restored = DownloadTask.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.song.id, original.song.id);
      expect(restored.song.title, original.song.title);
      expect(restored.song.artist, original.song.artist);
      expect(restored.song.album, original.song.album);
      expect(restored.song.duration, original.song.duration);
      expect(restored.song.track, original.song.track);
      expect(restored.song.coverArt, original.song.coverArt);
      expect(restored.song.suffix, original.song.suffix);
      expect(restored.localPath, original.localPath);
      expect(restored.fileSizeBytes, original.fileSizeBytes);
    });

    test('fromJson handles solara backend', () {
      final json = {
        'id': 'solara:netease:12345',
        'songId': '12345',
        'songTitle': 'Online Song',
        'songArtist': 'Artist',
        'songArtistId': '',
        'songAlbum': 'Album',
        'songAlbumId': '',
        'songBackend': 'solara',
        'songOnlineSource': 'netease',
        'songUrlId': '12345',
        'songLyricId': '12345',
        'localPath': '/downloads/online.mp3',
      };

      final task = DownloadTask.fromJson(json);

      expect(task.song.backend, SongBackend.solara);
      expect(task.song.onlineSource, 'netease');
      expect(task.song.urlId, '12345');
      expect(task.song.lyricId, '12345');
      expect(task.song.isOnline, isTrue);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {'id': 'minimal-task'};

      final task = DownloadTask.fromJson(json);

      expect(task.id, 'minimal-task');
      expect(task.song.id, 'minimal-task');
      expect(task.song.title, '');
      expect(task.song.backend, SongBackend.subsonic);
      expect(task.localPath, isNull);
      expect(task.fileSizeBytes, isNull);
    });

    test('copyWith updates specified fields only', () {
      const task = DownloadTask(
        id: 'test',
        song: testSong,
        status: DownloadStatus.pending,
      );

      final updated = task.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.5,
      );

      expect(updated.status, DownloadStatus.downloading);
      expect(updated.progress, 0.5);
      expect(updated.id, 'test');
      expect(updated.song.title, 'Test Song');
      expect(updated.localPath, isNull);
    });

    test('copyWith to completed with localPath', () {
      const task = DownloadTask(
        id: 'test',
        song: testSong,
        status: DownloadStatus.downloading,
        progress: 0.8,
      );

      final completed = task.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: '/path/to/file.flac',
        fileSizeBytes: 5000000,
      );

      expect(completed.status, DownloadStatus.completed);
      expect(completed.progress, 1.0);
      expect(completed.localPath, '/path/to/file.flac');
      expect(completed.fileSizeBytes, 5000000);
    });
  });
}
