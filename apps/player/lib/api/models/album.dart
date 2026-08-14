import 'song.dart';

class Album {
  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int? songCount;
  final int? duration;
  final int? year;
  final List<Song> songs;

  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArt,
    this.songCount,
    this.duration,
    this.year,
    this.songs = const [],
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final songList = json['song'] as List<dynamic>?;
    return Album(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      artistId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      songCount: json['songCount'] as int?,
      duration: json['duration'] as int?,
      year: json['year'] as int?,
      songs:
          songList
              ?.map((s) => Song.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
