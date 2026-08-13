import 'album.dart';

class Artist {
  final String id;
  final String name;
  final String? coverArt;
  final int? albumCount;

  const Artist({
    required this.id,
    required this.name,
    this.coverArt,
    this.albumCount,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      coverArt: json['coverArt'] as String? ?? json['artistImageUrl'] as String?,
      albumCount: json['albumCount'] as int?,
    );
  }
}

class ArtistDetail {
  final Artist artist;
  final List<Album> albums;

  const ArtistDetail({required this.artist, required this.albums});
}
