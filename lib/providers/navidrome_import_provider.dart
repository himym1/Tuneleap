import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/solara_client.dart';

import 'audio_providers.dart';

class NavidromeImportResult {
  final String filename;
  final String? message;

  const NavidromeImportResult({required this.filename, this.message});
}

final navidromeImportServiceProvider = Provider<NavidromeImportService>((ref) {
  return NavidromeImportService(solaraClient: ref.watch(solaraClientProvider));
});

class NavidromeImportService {
  final SolaraClient solaraClient;

  NavidromeImportService({required this.solaraClient});

  Future<NavidromeImportResult> importOnlineSong(Song song) async {
    if (!song.isOnline) {
      throw ArgumentError('Only online songs can be imported');
    }
    if (!solaraClient.isConfigured) {
      throw StateError('Solara client is not configured');
    }

    final playbackUrl = await solaraClient.getPlaybackUrl(song);
    final extension = inferFileExtension(playbackUrl, song);
    final filename = buildFileName(song, extension: extension);
    final picUrl = solaraClient.buildCoverProxyUrl(song);
    final message = await solaraClient.queueNasDownload(
      url: playbackUrl,
      filename: filename,
      song: buildNasDownloadSong(song),
      picUrl: picUrl,
    );

    return NavidromeImportResult(filename: filename, message: message);
  }

  static String safeSegment(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }

  static String buildFileName(Song song, {required String extension}) {
    final source = safeSegment(song.onlineSource ?? 'online');
    final id = safeSegment(song.urlId ?? song.id);
    return 'solara_${source}_$id.$extension';
  }

  static Map<String, dynamic> buildNasDownloadSong(Song song) {
    final songId = song.urlId ?? song.id;
    return {
      'id': songId,
      'url_id': songId,
      'lyric_id': song.lyricId ?? songId,
      'name': song.title,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'source': song.onlineSource ?? 'netease',
      if (song.coverArt != null && song.coverArt!.isNotEmpty)
        'pic_id': song.coverArt,
    };
  }

  static String inferFileExtension(String playbackUrl, Song song) {
    final uri = Uri.tryParse(playbackUrl);
    final filename = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < filename.length - 1) {
      final extension = filename.substring(dotIndex + 1).toLowerCase();
      if (extension.length <= 5) return safeSegment(extension);
    }
    return song.suffix ?? 'mp3';
  }
}
