import 'package:navidrome_player/api/models/song.dart';

/// 网易云在线歌单摘要。曲目不在这里，打开详情后再取。
class OnlinePlaylistSummary {
  final String id;
  final String name;
  final String? coverUrl;
  final int? trackCount;
  final String source;
  final String section;

  const OnlinePlaylistSummary({
    required this.id,
    required this.name,
    this.coverUrl,
    this.trackCount,
    this.source = 'netease',
    this.section = '',
  });

  factory OnlinePlaylistSummary.fromJson(Map<String, dynamic> json) {
    return OnlinePlaylistSummary(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: _httpUrl(json['cover_url'] ?? json['coverUrl']),
      trackCount: _asInt(json['track_count'] ?? json['trackCount']),
      source: json['source'] as String? ?? 'netease',
      section: json['section'] as String? ?? '',
    );
  }
}

class OnlinePlaylistPage {
  final String section;
  final String query;
  final List<OnlinePlaylistSummary> items;

  const OnlinePlaylistPage({
    required this.section,
    this.query = '',
    this.items = const [],
  });

  factory OnlinePlaylistPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return OnlinePlaylistPage(
      section: json['section'] as String? ?? '',
      query: json['query'] as String? ?? '',
      items: [
        for (final item in rawItems is List ? rawItems : const [])
          if (item is Map)
            OnlinePlaylistSummary.fromJson(Map<String, dynamic>.from(item)),
      ].where((item) => item.id.isNotEmpty && item.name.isNotEmpty).toList(),
    );
  }
}

class OnlinePlaylistDetail {
  final String id;
  final String name;
  final String? coverUrl;
  final int? trackCount;
  final bool truncated;
  final String source;
  final String provider;
  final List<Song> tracks;

  const OnlinePlaylistDetail({
    required this.id,
    required this.name,
    this.coverUrl,
    this.trackCount,
    this.truncated = false,
    this.source = 'netease',
    this.provider = 'gdstudio',
    this.tracks = const [],
  });

  factory OnlinePlaylistDetail.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    return OnlinePlaylistDetail(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: _httpUrl(json['cover_url'] ?? json['coverUrl']),
      trackCount: _asInt(json['track_count'] ?? json['trackCount']),
      truncated: json['truncated'] == true,
      source: json['source'] as String? ?? 'netease',
      provider: json['provider'] as String? ?? 'gdstudio',
      tracks: [
        for (final item in rawTracks is List ? rawTracks : const [])
          if (item is Map) Song.fromCloudJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

String? _httpUrl(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return value;
}

int? _asInt(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.round(),
    final String text => int.tryParse(text),
    _ => null,
  };
}
