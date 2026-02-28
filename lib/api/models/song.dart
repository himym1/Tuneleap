class Song {
  final String id;
  final String title;
  final String album;
  final String albumId;
  final String artist;
  final String artistId;
  final int? track;
  final int? year;
  final int? duration; // seconds
  final int? bitRate;
  final String? coverArt;
  final String? suffix; // mp3, flac, etc.

  const Song({
    required this.id,
    required this.title,
    required this.album,
    required this.albumId,
    required this.artist,
    required this.artistId,
    this.track,
    this.year,
    this.duration,
    this.bitRate,
    this.coverArt,
    this.suffix,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumId: json['albumId'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      artistId: json['artistId'] as String? ?? '',
      track: json['track'] as int?,
      year: json['year'] as int?,
      duration: json['duration'] as int?,
      bitRate: json['bitRate'] as int?,
      coverArt: json['coverArt'] as String?,
      suffix: json['suffix'] as String?,
    );
  }
}
