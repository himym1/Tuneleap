import 'song.dart';

class CloudSearchPage {
  const CloudSearchPage({required this.songs, required this.hasMore});

  final List<Song> songs;
  final bool hasMore;
}
