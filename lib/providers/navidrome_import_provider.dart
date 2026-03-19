import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/backend_client.dart';

import 'audio_providers.dart';

class NavidromeImportResult {
  final String filename;
  final String? message;

  const NavidromeImportResult({required this.filename, this.message});
}

final navidromeImportServiceProvider = Provider<NavidromeImportService>((ref) {
  return NavidromeImportService(backendClient: ref.watch(backendClientProvider));
});

class NavidromeImportService {
  final BackendClient backendClient;

  NavidromeImportService({required this.backendClient});

  Future<NavidromeImportResult> importOnlineSong(Song song) async {
    if (!song.isOnline) {
      throw ArgumentError('Only online songs can be imported');
    }
    if (!backendClient.isConfigured) {
      throw StateError('Backend client is not configured');
    }

    debugPrint('[Import] 开始导入: ${song.title} - ${song.artist}');
    debugPrint('[Import] source=${song.onlineSource}, urlId=${song.urlId}');

    try {
      final playbackUrl = await backendClient.getPlaybackUrl(song);
      debugPrint('[Import] 获取播放URL: ${playbackUrl.substring(0, playbackUrl.length.clamp(0, 80))}...');

      final extension = inferFileExtension(playbackUrl, song);
      final filename = buildFileName(song, extension: extension);
      // Resolve actual cover URL from source (not proxy URL)
      String picUrl = '';
      try {
        picUrl = await backendClient.resolveCoverArtUrl(song);
      } catch (_) {}
      // 获取歌词原文
      String? lrcText;
      try {
        lrcText = await backendClient.getRawLyrics(song);
        debugPrint('[Import] 歌词: ${lrcText != null ? '${lrcText.length} chars' : 'none'}');
      } catch (_) {}
      debugPrint('[Import] filename=$filename, picUrl=${picUrl.isNotEmpty}');

      final message = await backendClient.queueNasDownload(
        url: playbackUrl,
        filename: filename,
        song: buildNasDownloadSong(song),
        picUrl: picUrl,
        lyric: lrcText,
      );
      debugPrint('[Import] 导入成功: $message');

      return NavidromeImportResult(filename: filename, message: message);
    } catch (e, stack) {
      debugPrint('[Import] 导入失败: $e');
      debugPrint('[Import] Stack: $stack');
      rethrow;
    }
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
