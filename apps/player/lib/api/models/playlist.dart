import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final int? songCount;
  final int? duration;
  final String? coverArt;
  final String? owner;
  final List<Song> songs;

  const Playlist({
    required this.id,
    required this.name,
    this.songCount,
    this.duration,
    this.coverArt,
    this.owner,
    this.songs = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final entries = json['entry'] as List<dynamic>?;
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      songCount: json['songCount'] as int?,
      duration: json['duration'] as int?,
      coverArt: json['coverArt'] as String?,
      owner: json['owner'] as String?,
      songs: entries?.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
