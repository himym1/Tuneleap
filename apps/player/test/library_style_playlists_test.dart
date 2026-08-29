import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/library_style.dart';
import 'package:navidrome_player/utils/library_style_playlists.dart';

Song _song(String id, {String genre = '', String title = '歌'}) {
  return Song(
    id: id,
    title: title,
    album: '专辑',
    albumId: 'a',
    artist: '歌手',
    artistId: 'b',
    genre: genre.isEmpty ? null : genre,
  );
}

void main() {
  test('closedStyleOf only accepts the 14 style names', () {
    expect(closedStyleOf('民谣'), '民谣');
    expect(closedStyleOf(' Pop '), isNull);
    expect(closedStyleOf(''), isNull);
  });

  test('draft files tagged songs and leaves unknown genre in review', () {
    final draft = buildStylePlaylistDraft(
      songs: [
        _song('1', genre: '民谣'),
        _song('2', genre: '民谣'),
        _song('3', genre: '华语流行'),
        _song('4', genre: 'Pop'),
        _song('5'),
      ],
      existingStyleSongIds: const {},
      existingPlaylistIds: const {},
      onlyMissingFromPlaylists: false,
    );
    expect(draft.scanned, 5);
    expect(draft.leftover.map((song) => song.id), ['4', '5']);
    expect(
      draft.buckets
          .singleWhere((bucket) => bucket.name == '民谣')
          .toAdd
          .map((song) => song.id),
      ['1', '2'],
    );
    expect(
      draft.buckets
          .singleWhere((bucket) => bucket.name == '华语流行')
          .toAdd
          .map((song) => song.id),
      ['3'],
    );
  });

  test('not-in-playlists skips songs already in any style list', () {
    final draft = buildStylePlaylistDraft(
      songs: [
        _song('1', genre: '民谣'),
        _song('2', genre: '摇滚'),
        _song('3'),
      ],
      existingStyleSongIds: {
        '华语流行': {'1'},
      },
      existingPlaylistIds: const {'华语流行': 'pl-1'},
      onlyMissingFromPlaylists: true,
    );
    expect(draft.leftover.map((song) => song.id), ['3']);
    expect(draft.buckets.single.name, '摇滚');
    expect(draft.buckets.single.toAdd.single.id, '2');
  });

  test('already-in-the-same-list songs are not added again', () {
    final draft = buildStylePlaylistDraft(
      songs: [
        _song('1', genre: '民谣'),
        _song('2', genre: '民谣'),
      ],
      existingStyleSongIds: {
        '民谣': {'1'},
      },
      existingPlaylistIds: const {'民谣': 'pl-folk'},
      onlyMissingFromPlaylists: false,
    );
    final folk = draft.buckets.single;
    expect(folk.existingPlaylistId, 'pl-folk');
    expect(folk.alreadyIn, 1);
    expect(folk.toAdd.single.id, '2');
    expect(folk.isNew, isFalse);
  });

  test('chunkSongIds keeps Subsonic writes bounded', () {
    expect(chunkSongIds(const []), isEmpty);
    expect(chunkSongIds(['a', 'b', 'c'], size: 2), [
      ['a', 'b'],
      ['c'],
    ]);
  });
}
