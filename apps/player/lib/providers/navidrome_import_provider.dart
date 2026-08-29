import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/utils/library_style.dart';
import 'package:navidrome_player/api/backend_client.dart';

import 'audio_providers.dart';

enum NasImportStage { pending, resolving, uploading, completed, failed }

class NavidromeImportResult {
  final String filename;
  final String? message;

  const NavidromeImportResult({required this.filename, this.message});
}

final navidromeImportServiceProvider = Provider<NavidromeImportService>((ref) {
  return NavidromeImportService(
    backendClient: ref.watch(backendClientProvider),
  );
});

class NavidromeImportService {
  final BackendClient backendClient;

  NavidromeImportService({required this.backendClient});

  static const maxSlowUpstreamAttempts = 4;

  Future<NavidromeImportResult> importOnlineSong(
    Song song, {
    bool force = false,
    bool preferFreshUrl = false,
    void Function(NasImportStage stage)? onStage,
  }) async {
    if (!song.isOnline) {
      throw ArgumentError('Only online songs can be imported');
    }
    if (!backendClient.isConfigured) {
      throw StateError('Backend client is not configured');
    }
    if (!backendClient.canMutateNas) {
      throw StateError('Cloud is not configured');
    }

    debugPrint('[Import] started: source=${song.onlineSource ?? 'unknown'}');

    try {
      onStage?.call(NasImportStage.resolving);
      var playbackUrl = await backendClient.getPlaybackUrl(
        song,
        bypassCache: preferFreshUrl,
      );
      debugPrint('[Import] playback URL resolved');

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
        debugPrint(
          '[Import] 歌词: ${lrcText != null ? '${lrcText.length} chars' : 'none'}',
        );
      } catch (_) {}
      debugPrint(
        '[Import] metadata ready: lyrics=${lrcText != null}, cover=${picUrl.isNotEmpty}',
      );
      final genre = await _resolveImportGenre(song);

      onStage?.call(NasImportStage.uploading);
      String? message;
      for (var attempt = 0; attempt < maxSlowUpstreamAttempts; attempt++) {
        try {
          if (attempt > 0) {
            debugPrint(
              '[Import] slow upstream; resolving a fresh URL '
              '(${attempt + 1}/$maxSlowUpstreamAttempts)',
            );
            playbackUrl = await backendClient.getPlaybackUrl(
              song,
              bypassCache: true,
            );
          }
          message = await backendClient.queueNasDownload(
            url: playbackUrl,
            filename: filename,
            song: buildNasDownloadSong(song, genre: genre),
            picUrl: picUrl,
            lyric: lrcText,
            force: force,
          );
          break;
        } catch (error) {
          if (!isSlowNasUpstream(error) ||
              attempt >= maxSlowUpstreamAttempts - 1) {
            rethrow;
          }
        }
      }
      debugPrint('[Import] queued successfully');

      return NavidromeImportResult(filename: filename, message: message);
    } catch (e) {
      debugPrint('[Import] failed: ${e.runtimeType}');
      rethrow;
    }
  }

  static String safeSegment(String value) {
    final sanitized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return sanitized.isEmpty ? 'unknown' : sanitized;
  }

  static String buildFileName(Song song, {required String extension}) {
    final source = safeSegment(song.onlineSource ?? 'online');
    final provider = song.onlineProvider;
    final providerSuffix = provider == null || provider.isEmpty
        ? ''
        : '_via-${safeSegment(provider)}';
    final id = safeSegment(song.urlId ?? song.id);
    return 'solara_$source${providerSuffix}_$id.$extension';
  }

  Future<String?> _resolveImportGenre(Song song) async {
    final local = highConfidenceImportGenre(
      title: song.title,
      artist: song.artist,
      album: song.album,
      year: song.year,
    );
    if (local != null) return local;
    if (!backendClient.isConfigured) return null;
    try {
      final hits = await backendClient.lookupStyles([
        (
          title: song.title,
          artist: song.artist,
          album: song.album,
          year: song.year,
        ),
      ]);
      if (hits.isEmpty) return null;
      return closedStyleOf(hits.first.style);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> buildNasDownloadSong(Song song, {String? genre}) {
    final songId = song.urlId ?? song.id;
    final resolved =
        closedStyleOf(genre) ??
        highConfidenceImportGenre(
          title: song.title,
          artist: song.artist,
          album: song.album,
          year: song.year,
        );
    return {
      'id': songId,
      'url_id': songId,
      'lyric_id': song.lyricId ?? songId,
      'name': song.title,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'source': song.onlineSource ?? 'netease',
      'genre': ?resolved,
      if (song.onlineProvider?.isNotEmpty ?? false)
        'provider': song.onlineProvider,
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
