import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/subsonic_client.dart';

class SongMediaResolver {
  final SubsonicClient subsonicClient;
  final BackendClient backendClient;

  const SongMediaResolver({
    required this.subsonicClient,
    required this.backendClient,
  });

  Future<String> coverArtUrl(Song song, {int size = 300}) async {
    if (song.isOnline) {
      return backendClient.resolveCoverArtUrl(song, size: size);
    }
    return subsonicClient.coverArtUrl(song.coverArt, size: size);
  }

  Future<String> playbackUrl(Song song, {int? maxBitRate}) async {
    if (song.isOnline) {
      return backendClient.getPlaybackUrl(song, maxBitRate: maxBitRate);
    }
    return subsonicClient.streamUrl(song.id, maxBitRate: maxBitRate);
  }

  Future<LyricsList?> lyrics(Song song, {String? localAudioPath}) async {
    debugPrint(
      '[Resolver] lyrics: backend=${song.backend.name}, local=${localAudioPath != null}',
    );
    // 1. 优先读取本地 .lrc 歌词文件（下载歌曲附带）
    final localLyrics = await _loadLocalLrc(localAudioPath);
    if (localLyrics != null) {
      debugPrint(
        '[Resolver] lyrics: got local .lrc, ${localLyrics.lines.length} lines',
      );
      return localLyrics;
    }

    // 2. 在线歌曲 → Backend API
    if (song.isOnline) {
      debugPrint('[Resolver] lyrics: online → backend API');
      return backendClient.getLyrics(song);
    }

    // 3. 本地歌曲 → Subsonic API，失败则尝试从文件路径解析在线源回退
    final result = await subsonicClient.getLyricsBySongId(song.id);
    debugPrint(
      '[Resolver] lyrics: subsonic result=${result?.lines.length ?? 0} lines',
    );
    if (result != null && result.lines.isNotEmpty) return result;

    // Subsonic 无歌词 → 检查是否为导入的在线歌曲，回退到 Backend API
    if (!backendClient.isConfigured) return result;
    final solaraInfo = _parseSolaraInfo(song);
    if (solaraInfo == null) return result;

    debugPrint('[Resolver] Subsonic lyrics empty; trying backend fallback');
    try {
      return await backendClient.getLyrics(
        Song(
          id: solaraInfo.lyricId,
          title: song.title,
          artist: song.artist,
          artistId: song.artistId,
          album: song.album,
          albumId: song.albumId,
          backend: SongBackend.solara,
          onlineSource: solaraInfo.source,
          onlineProvider: solaraInfo.provider,
          lyricId: solaraInfo.lyricId,
        ),
      );
    } catch (e) {
      debugPrint('[Resolver] Backend lyrics fallback failed: ${e.runtimeType}');
      return result;
    }
  }

  Future<void> scrobble(Song song) async {
    if (song.isOnline) return;
    await subsonicClient.scrobble(song.id);
  }

  bool supportsLibraryMutations(Song song) => !song.isOnline;

  /// 读取音频文件同目录的 .lrc 歌词文件
  static Future<LyricsList?> _loadLocalLrc(String? audioPath) async {
    if (audioPath == null || audioPath.isEmpty) return null;
    final lrcPath = '${audioPath.replaceAll(RegExp(r'\.[^.]+$'), '')}.lrc';
    final file = File(lrcPath);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return parseLrc(content);
    } catch (e) {
      debugPrint(
        '[Resolver] Failed to read local lrc: ${e.runtimeType}',
      );
      return null;
    }
  }

  /// 解析 LRC 歌词文本为 LyricsList
  static LyricsList parseLrc(String lrcText) {
    final lines = lrcText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .expand(_parseLrcLine)
        .toList();
    // 按时间排序
    lines.sort((a, b) => (a.startMs ?? 0).compareTo(b.startMs ?? 0));
    return LyricsList(
      lines: lines,
      synced: lines.any((l) => l.startMs != null),
    );
  }

  /// 解析单行 LRC（支持多时间戳如 [00:01.23][00:05.67]text）
  static List<LyricsLine> _parseLrcLine(String raw) {
    final timeRe = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final matches = timeRe.allMatches(raw).toList();
    if (matches.isEmpty) {
      // 无时间戳行（可能是元数据标签如 [ti:xxx]，跳过）
      if (RegExp(r'^\[.+\]$').hasMatch(raw)) return [];
      final text = raw.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      return text.isEmpty ? [] : [LyricsLine(text: text)];
    }

    final text = raw.substring(matches.last.end).trim();
    if (text.isEmpty) return [];

    return matches.map((m) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final fracStr = m.group(3) ?? '0';
      final frac = int.parse(fracStr.padRight(3, '0'));
      return LyricsLine(text: text, startMs: min * 60000 + sec * 1000 + frac);
    }).toList();
  }

  /// 从本地歌曲的文件路径中解析 solara 来源信息。
  /// 新格式: solara_{source}_via-{provider}_{id}.{ext}；兼容旧格式。
  static _SolaraInfo? _parseSolaraInfo(Song song) {
    final path = song.path;
    if (path == null || path.isEmpty) return null;
    final basename = path.split('/').last;
    final extensionIndex = basename.lastIndexOf('.');
    final filename = extensionIndex > 0
        ? basename.substring(0, extensionIndex)
        : basename;
    final providerMatch = RegExp(
      r'^solara_(\w+?)_via-([A-Za-z0-9.-]+)_(.+)$',
    ).firstMatch(filename);
    if (providerMatch != null) {
      return _SolaraInfo(
        source: providerMatch.group(1)!,
        provider: providerMatch.group(2)!,
        lyricId: providerMatch.group(3)!,
      );
    }
    final legacyMatch = RegExp(r'^solara_(\w+?)_(.+)$').firstMatch(filename);
    if (legacyMatch == null) return null;
    return _SolaraInfo(
      source: legacyMatch.group(1)!,
      lyricId: legacyMatch.group(2)!,
    );
  }
}

class _SolaraInfo {
  final String source;
  final String? provider;
  final String lyricId;
  const _SolaraInfo({
    required this.source,
    this.provider,
    required this.lyricId,
  });
}
