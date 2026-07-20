import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/search_provider.dart';

void main() {
  test('clearing search results also clears the loading state', () {
    const song = Song(
      id: '1',
      title: 'Song',
      album: 'Album',
      albumId: 'album',
      artist: 'Artist',
      artistId: 'artist',
    );
    const state = SearchState(songs: [song], searching: true);

    final cleared = state.copyWith(clearResult: true);

    expect(cleared.songs, isEmpty);
    expect(cleared.searching, isFalse);
  });
}
