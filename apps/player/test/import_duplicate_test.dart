import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/import_duplicate.dart';

Song _song({
  required String id,
  String title = '晴天',
  String artist = '周杰伦',
  String album = '叶惠美',
  int? duration,
  int? year,
  int? bitRate,
  String? suffix,
  SongBackend backend = SongBackend.subsonic,
}) {
  return Song(
    id: id,
    title: title,
    album: album,
    albumId: '',
    artist: artist,
    artistId: '',
    duration: duration,
    year: year,
    bitRate: bitRate,
    suffix: suffix,
    backend: backend,
    onlineSource: backend == SongBackend.solara ? 'netease' : null,
    urlId: backend == SongBackend.solara ? id : null,
  );
}

void main() {
  group('classifyRecordingMatch', () {
    test('same album and duration within 3 seconds is the same version', () {
      expect(
        classifyRecordingMatch(
          incomingAlbum: '叶惠美',
          incomingDuration: 269,
          localAlbum: '叶惠美',
          localDuration: 271,
        ),
        ImportRecordingMatch.same,
      );
    });

    test('empty albums with matching duration is the same version', () {
      expect(
        classifyRecordingMatch(
          incomingAlbum: '',
          incomingDuration: 200,
          localAlbum: '   ',
          localDuration: 200,
        ),
        ImportRecordingMatch.same,
      );
    });

    test('duration gap over 3 seconds is a different version', () {
      expect(
        classifyRecordingMatch(
          incomingAlbum: '叶惠美',
          incomingDuration: 269,
          localAlbum: '叶惠美',
          localDuration: 280,
        ),
        ImportRecordingMatch.different,
      );
    });

    test('different albums are a different version', () {
      expect(
        classifyRecordingMatch(
          incomingAlbum: '叶惠美',
          incomingDuration: 269,
          localAlbum: '现场',
          localDuration: 269,
        ),
        ImportRecordingMatch.different,
      );
    });

    test('missing duration is unknown even with the same album', () {
      expect(
        classifyRecordingMatch(
          incomingAlbum: '叶惠美',
          incomingDuration: 269,
          localAlbum: '叶惠美',
          localDuration: null,
        ),
        ImportRecordingMatch.unknown,
      );
    });

    test('one empty album is unknown when durations match', () {
      expect(
        classifyRecordingMatch(
          incomingAlbum: '叶惠美',
          incomingDuration: 269,
          localAlbum: '',
          localDuration: 269,
        ),
        ImportRecordingMatch.unknown,
      );
    });
  });

  group('importDuplicateSearchQueries', () {
    test('adds the canonical title so live labels still find studio copies', () {
      final incoming = _song(
        id: 'online',
        title: '凡人诀 (live)',
        artist: '陈楚生',
        backend: SongBackend.solara,
      );
      expect(importDuplicateSearchQueries(incoming), [
        '凡人诀 (live)',
        '凡人诀',
      ]);
    });

    test('does not duplicate when the title is already canonical', () {
      final incoming = _song(
        id: 'online',
        title: '大梦',
        artist: '陈楚生',
        backend: SongBackend.solara,
      );
      expect(importDuplicateSearchQueries(incoming), ['大梦']);
    });
  });

  group('importDuplicateCandidates', () {
    test('keeps weak-identity hits and classifies each row', () {
      final incoming = _song(
        id: 'online',
        duration: 269,
        backend: SongBackend.solara,
      );
      final same = _song(id: 'local-1', duration: 268, suffix: 'flac');
      final live = _song(
        id: 'local-2',
        album: '演唱会',
        duration: 312,
        suffix: 'mp3',
      );
      final other = _song(id: 'local-3', title: '七里香', duration: 269);

      final candidates = importDuplicateCandidates(
        incoming: incoming,
        locals: [same, live, other],
      );

      expect(candidates.map((c) => c.song.id), ['local-1', 'local-2']);
      expect(candidates.first.match, ImportRecordingMatch.same);
      expect(candidates.last.match, ImportRecordingMatch.different);
      expect(defaultImportDuplicateSelection(candidates), 0);
    });

    test('defaults to the first row when nothing is the same version', () {
      final incoming = _song(
        id: 'online',
        album: '',
        duration: null,
        backend: SongBackend.solara,
      );
      final candidates = importDuplicateCandidates(
        incoming: incoming,
        locals: [_song(id: 'a', album: 'A', duration: 100)],
      );
      expect(candidates.single.match, ImportRecordingMatch.unknown);
      expect(defaultImportDuplicateSelection(candidates), 0);
    });

    test('prefers the audit song id even when it is a different version', () {
      final incoming = _song(
        id: 'online',
        duration: 269,
        backend: SongBackend.solara,
      );
      final same = _song(id: 'local-1', duration: 268, suffix: 'flac');
      final audit = _song(
        id: 'audit-9',
        album: '现场',
        duration: 312,
        suffix: 'mp3',
      );
      final candidates = importDuplicateCandidates(
        incoming: incoming,
        locals: [same, audit],
      );
      expect(
        defaultImportDuplicateSelection(candidates, preferredSongId: 'audit-9'),
        1,
      );
    });

    test('inserts a missing preferred local song at the front', () {
      final incoming = _song(
        id: 'online',
        duration: 269,
        backend: SongBackend.solara,
      );
      final same = _song(id: 'local-1', duration: 268, suffix: 'flac');
      final preferred = _song(id: 'audit-9', album: '现场', duration: 312);
      final candidates = withPreferredDuplicate(
        candidates: importDuplicateCandidates(
          incoming: incoming,
          locals: [same],
        ),
        preferred: preferred,
      );
      expect(candidates.map((c) => c.song.id), ['audit-9', 'local-1']);
      expect(
        defaultImportDuplicateSelection(candidates, preferredSongId: 'audit-9'),
        0,
      );
    });
  });

  group('quality labels', () {
    test('incoming quality uses the same tokens as local files', () {
      expect(
        incomingImportQualityLabel(maxBitRate: 0, originalLabel: '原始 · 未转码'),
        '原始 · 未转码',
      );
      expect(
        incomingImportQualityLabel(maxBitRate: 320, originalLabel: '原始 · 未转码'),
        'MP3 · 320 kbps',
      );
    });

    test('local quality lists format and bitrate', () {
      expect(
        localImportQualityLabel(_song(id: '1', suffix: 'flac', bitRate: 1411)),
        'FLAC · 1411 kbps',
      );
      expect(localImportQualityLabel(_song(id: '2')), '');
    });
  });

  group('compareImportQuality', () {
    test('original vs local flac is already lossless', () {
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 0),
          local: localImportQuality(
            _song(id: '1', suffix: 'flac', bitRate: 947),
          ),
        ),
        ImportQualityCompare.localAlreadyLossless,
      );
    });

    test('original vs local mp3 is usually higher', () {
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 0),
          local: localImportQuality(
            _song(id: '1', suffix: 'mp3', bitRate: 320),
          ),
        ),
        ImportQualityCompare.originalUsuallyHigher,
      );
    });

    test('probed flac bitrates compare even when both are lossless', () {
      expect(
        compareImportQuality(
          incoming: const ImportQualityInfo(
            format: 'FLAC',
            bitRate: 1400,
            estimated: true,
          ),
          local: localImportQuality(
            _song(id: '1', suffix: 'flac', bitRate: 819),
          ),
        ),
        ImportQualityCompare.higher,
      );
      expect(
        compareImportQuality(
          incoming: const ImportQualityInfo(format: 'FLAC', bitRate: 800),
          local: localImportQuality(
            _song(id: '1', suffix: 'flac', bitRate: 819),
          ),
        ),
        ImportQualityCompare.similar,
      );
      expect(
        importQualityDeltaKbps(
          incoming: const ImportQualityInfo(format: 'FLAC', bitRate: 1400),
          local: localImportQuality(
            _song(id: '1', suffix: 'flac', bitRate: 819),
          ),
        ),
        581,
      );
    });

    test('flac without a bitrate stays unknown against local lossless', () {
      expect(
        compareImportQuality(
          incoming: const ImportQualityInfo(format: 'FLAC'),
          local: localImportQuality(
            _song(id: '1', suffix: 'flac', bitRate: 819),
          ),
        ),
        ImportQualityCompare.bothLosslessUnknown,
      );
    });

    test('transcoded mp3 is lower than local lossless', () {
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 320),
          local: localImportQuality(_song(id: '1', suffix: 'flac')),
        ),
        ImportQualityCompare.lower,
      );
    });

    test('playback size estimates bitrate and ignores 999', () {
      final quality = incomingQualityFromPlayback(
        maxBitRate: 0,
        url: 'https://cdn.example.com/a.flac',
        cloudBr: 999,
        cloudType: 'flac',
        cloudSize: 25840123,
        durationSeconds: 246,
      );
      expect(quality.format, 'FLAC');
      expect(quality.estimated, isTrue);
      expect(quality.bitRate, 840);
      expect(quality.isOriginal, isFalse);
      expect(usableReportedBitRate(999), isNull);
      expect(
        audioFormatFromUrl('https://cdn.example.com/a.mp3?token=1'),
        'MP3',
      );
    });

    test('compares known lossy bitrates', () {
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 320),
          local: localImportQuality(
            _song(id: '1', suffix: 'mp3', bitRate: 128),
          ),
        ),
        ImportQualityCompare.higher,
      );
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 128),
          local: localImportQuality(
            _song(id: '1', suffix: 'mp3', bitRate: 320),
          ),
        ),
        ImportQualityCompare.lower,
      );
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 320),
          local: localImportQuality(
            _song(id: '1', suffix: 'mp3', bitRate: 320),
          ),
        ),
        ImportQualityCompare.similar,
      );
    });

    test('missing local quality is unknown', () {
      expect(
        compareImportQuality(
          incoming: incomingImportQuality(maxBitRate: 320),
          local: localImportQuality(_song(id: '1')),
        ),
        ImportQualityCompare.unknown,
      );
    });
  });

  test('replace decision carries the selected local id', () {
    const decision = ImportDuplicateDecision.replace('local-1');
    expect(decision.shouldImport, isTrue);
    expect(decision.replaceSongIds, ['local-1']);
    expect(const ImportDuplicateDecision.download().replaceSongIds, isEmpty);
    expect(const ImportDuplicateDecision.cancel().shouldImport, isFalse);
  });
}
