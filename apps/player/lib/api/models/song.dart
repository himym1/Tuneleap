import 'package:navidrome_player/utils/duration_format.dart';

enum SongBackend { subsonic, solara }

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
  final String? path; // file path from Subsonic API
  final String? comment; // comment tag (may contain solara source info)
  final SongBackend backend;
  final String? onlineSource;
  final String? onlineProvider;
  final String? urlId;
  final String? lyricId;

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
    this.path,
    this.comment,
    this.backend = SongBackend.subsonic,
    this.onlineSource,
    this.onlineProvider,
    this.urlId,
    this.lyricId,
  });

  bool get isOnline => backend == SongBackend.solara;

  /// 音源显示标签
  String? get sourceLabel => switch (onlineSource) {
    'netease' => '网易云',
    'migu' => '咪咕',
    'joox' => 'JOOX',
    'kuwo' => '酷我',
    'kugou' => '酷狗',
    _ => onlineSource,
  };

  /// Formatted duration string (e.g. "3:05"), empty if null.
  String get formattedDuration => formatDurationOrEmpty(duration);

  String get storageKey => isOnline
      ? 'solara:${onlineSource ?? 'unknown'}:${urlId ?? id}'
      : 'subsonic:$id';

  static SongBackend _parseBackend(String? value) {
    return switch (value) {
      'solara' => SongBackend.solara,
      _ => SongBackend.subsonic,
    };
  }

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
      path: json['path'] as String?,
      comment: json['comment'] as String?,
      backend: _parseBackend(json['backend'] as String?),
      onlineSource: json['onlineSource'] as String?,
      onlineProvider: json['onlineProvider'] as String?,
      urlId: json['urlId'] as String?,
      lyricId: json['lyricId'] as String?,
    );
  }

  factory Song.fromSolaraJson(Map<String, dynamic> json) {
    final artist = switch (json['artist']) {
      final List<dynamic> artists => artists.join(' / '),
      final String value => value,
      _ => '',
    };
    final coverArt = json['pic_id']?.toString();
    final source = json['source']?.toString();
    final provider = json['provider']?.toString();
    final urlId = json['url_id']?.toString();
    final lyricId = json['lyric_id']?.toString();

    return Song(
      id: json['id'].toString(),
      title: json['name'] as String? ?? json['title'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumId: '',
      artist: artist,
      artistId: '',
      coverArt: coverArt == null || coverArt.isEmpty ? null : coverArt,
      backend: SongBackend.solara,
      onlineSource: source == null || source.isEmpty ? null : source,
      onlineProvider: provider == null || provider.isEmpty ? null : provider,
      urlId: urlId == null || urlId.isEmpty ? null : urlId,
      lyricId: lyricId == null || lyricId.isEmpty ? null : lyricId,
    );
  }

  /// Normalized song from navidrome-cloud `SongDTO`.
  factory Song.fromCloudJson(Map<String, dynamic> json) {
    final artist = switch (json['artist']) {
      final List<dynamic> artists => artists.join(' / '),
      final String value => value,
      _ => '',
    };
    final coverArt = (json['cover_id'] ?? json['coverId'] ?? json['pic_id'])
        ?.toString();
    final source = json['source']?.toString();
    final provider = json['provider']?.toString();
    final urlId = (json['url_id'] ?? json['urlId'] ?? json['id'])?.toString();
    final lyricId = (json['lyric_id'] ?? json['lyricId'] ?? json['id'])
        ?.toString();
    final durationRaw = json['duration'];
    final duration = switch (durationRaw) {
      final int value => value,
      final num value => value.round(),
      final String value => double.tryParse(value)?.round(),
      _ => null,
    };

    return Song(
      id: (json['id'] ?? urlId ?? '').toString(),
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumId: '',
      artist: artist,
      artistId: '',
      duration: duration,
      coverArt: coverArt == null || coverArt.isEmpty ? null : coverArt,
      backend: SongBackend.solara,
      onlineSource: source == null || source.isEmpty ? null : source,
      onlineProvider: provider == null || provider.isEmpty ? null : provider,
      urlId: urlId == null || urlId.isEmpty ? null : urlId,
      lyricId: lyricId == null || lyricId.isEmpty ? null : lyricId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'album': album,
    'albumId': albumId,
    'artist': artist,
    'artistId': artistId,
    if (track != null) 'track': track,
    if (year != null) 'year': year,
    if (duration != null) 'duration': duration,
    if (bitRate != null) 'bitRate': bitRate,
    if (coverArt != null) 'coverArt': coverArt,
    if (suffix != null) 'suffix': suffix,
    if (path != null) 'path': path,
    if (comment != null) 'comment': comment,
    if (backend != SongBackend.subsonic) 'backend': backend.name,
    if (onlineSource != null) 'onlineSource': onlineSource,
    if (onlineProvider != null) 'onlineProvider': onlineProvider,
    if (urlId != null) 'urlId': urlId,
    if (lyricId != null) 'lyricId': lyricId,
  };
}
