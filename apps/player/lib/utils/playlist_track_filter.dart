import 'package:navidrome_player/api/models/models.dart';

/// 在已加载的歌单曲目里按歌名、歌手、专辑过滤，返回原列表下标。
List<int> playlistTrackMatchIndexes(List<Song> songs, String query) {
  final tokens = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) {
    return [for (var index = 0; index < songs.length; index++) index];
  }
  final matches = <int>[];
  for (var index = 0; index < songs.length; index++) {
    final song = songs[index];
    final haystack = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
    if (tokens.every(haystack.contains)) matches.add(index);
  }
  return matches;
}
