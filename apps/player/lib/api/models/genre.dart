class Genre {
  final String name;
  final int songCount;
  final int albumCount;

  const Genre({required this.name, this.songCount = 0, this.albumCount = 0});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      name: json['value'] as String? ?? '',
      songCount: json['songCount'] as int? ?? 0,
      albumCount: json['albumCount'] as int? ?? 0,
    );
  }
}
