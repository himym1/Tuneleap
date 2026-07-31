import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart' show LyricsList;
import 'audio_providers.dart';
import 'server_config_provider.dart';
import 'package:navidrome_player/providers/server_scope.dart';
import 'package:navidrome_player/utils/request_generation.dart';

// ============================================================
// 下载管理
// ============================================================

enum DownloadStatus { pending, downloading, completed, failed }

String downloadStorageSegment(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

class DownloadTask {
  final String id; // song.storageKey
  final Song song;
  final DownloadStatus status;
  final double progress; // 0.0 ~ 1.0
  final String? localPath;
  final String? errorMessage;
  final int? fileSizeBytes; // 真实文件大小

  const DownloadTask({
    required this.id,
    required this.song,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.localPath,
    this.errorMessage,
    this.fileSizeBytes,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? errorMessage,
    int? fileSizeBytes,
  }) {
    return DownloadTask(
      id: id,
      song: song,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  /// 序列化为 JSON（仅用于持久化已完成的任务）
  Map<String, dynamic> toJson() => {
    'id': id,
    'songId': song.id,
    'songTitle': song.title,
    'songArtist': song.artist,
    'songArtistId': song.artistId,
    'songAlbum': song.album,
    'songAlbumId': song.albumId,
    'songDuration': song.duration,
    'songTrack': song.track,
    'songCoverArt': song.coverArt,
    'songSuffix': song.suffix,
    'songBackend': song.backend.name,
    'songOnlineSource': song.onlineSource,
    'songOnlineProvider': song.onlineProvider,
    'songUrlId': song.urlId,
    'songLyricId': song.lyricId,
    'localPath': localPath,
    'fileSizeBytes': fileSizeBytes,
  };

  /// 从 JSON 恢复已完成的任务
  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'] as String,
    song: Song(
      id: json['songId'] as String? ?? json['id'] as String,
      title: json['songTitle'] as String? ?? '',
      artist: json['songArtist'] as String? ?? '',
      artistId: json['songArtistId'] as String? ?? '',
      album: json['songAlbum'] as String? ?? '',
      albumId: json['songAlbumId'] as String? ?? '',
      duration: json['songDuration'] as int?,
      track: json['songTrack'] as int?,
      coverArt: json['songCoverArt'] as String?,
      suffix: json['songSuffix'] as String?,
      backend: SongBackend.values.byName(
        json['songBackend'] as String? ?? SongBackend.subsonic.name,
      ),
      onlineSource: json['songOnlineSource'] as String?,
      onlineProvider: json['songOnlineProvider'] as String?,
      urlId: json['songUrlId'] as String?,
      lyricId: json['songLyricId'] as String?,
    ),
    status: DownloadStatus.completed,
    progress: 1.0,
    localPath: json['localPath'] as String?,
    fileSizeBytes: json['fileSizeBytes'] as int?,
  );
}

final downloadManagerProvider =
    NotifierProvider<DownloadManagerNotifier, List<DownloadTask>>(
      DownloadManagerNotifier.new,
    );

class DownloadManagerNotifier extends Notifier<List<DownloadTask>> {
  static const _allowedExtensions = {
    'aac',
    'flac',
    'm4a',
    'mp3',
    'ogg',
    'opus',
    'wav',
  };
  final RequestGeneration _requests = RequestGeneration();
  final Set<CancelToken> _cancelTokens = {};
  int _nextTransferId = 0;
  late String _persistKey;
  late String _serverId;

  @override
  List<DownloadTask> build() {
    _cancelActiveDownloads();
    _serverId = ref.watch(
      serverConfigProvider.select((config) => config.serverId),
    );
    _persistKey = scopedPreferenceKey('download_tasks', _serverId);
    _requests.begin();
    ref.onDispose(() {
      _cancelActiveDownloads();
      _requests.invalidate();
    });

    final prefs = ref.read(sharedPreferencesProvider);
    final json = prefs.getString(_persistKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final tasks = list
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();
      return tasks.where((task) {
        final path = task.localPath;
        return path != null && File(path).existsSync();
      }).toList();
    } catch (e) {
      debugPrint('Failed to load download tasks: $e');
      return [];
    }
  }

  void _cancelActiveDownloads() {
    for (final token in _cancelTokens) {
      if (!token.isCancelled) token.cancel('Server session changed');
    }
    _cancelTokens.clear();
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final completed = state
        .where((task) => task.status == DownloadStatus.completed)
        .map((task) => task.toJson())
        .toList();
    await prefs.setString(_persistKey, jsonEncode(completed));
  }

  bool isDownloaded(String songId) => state.any(
    (task) => task.id == songId && task.status == DownloadStatus.completed,
  );

  bool isDownloading(String songId) => state.any(
    (task) => task.id == songId && task.status == DownloadStatus.downloading,
  );

  Future<void> download(Song song) async {
    final request = _requests.current;
    final songId = song.storageKey;
    if (state.any(
      (task) =>
          task.id == songId &&
          (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.downloading),
    )) {
      return;
    }
    state = state.where((task) => task.id != songId).toList();
    state = [
      ...state,
      DownloadTask(id: songId, song: song, status: DownloadStatus.downloading),
    ];

    CancelToken? cancelToken;
    String? tempPath;
    String? tempLrcPath;
    try {
      final resolver = ref.read(songMediaResolverProvider);
      final quality = ref.read(audioQualityProvider);
      final url = await resolver.playbackUrl(song, maxBitRate: quality);
      if (!_requests.isCurrent(request)) return;

      final dir = await getApplicationDocumentsDirectory();
      final safeServerId = downloadStorageSegment(_serverId);
      final downloadsDir = Directory(
        '${dir.path}/navidrome_downloads/$safeServerId',
      );
      await downloadsDir.create(recursive: true);
      if (!_requests.isCurrent(request)) return;

      final extension = _safeExtension(song.suffix);
      final safeName = downloadStorageSegment(songId);
      final savePath = '${downloadsDir.path}/$safeName.$extension';
      final transferId = _nextTransferId++;
      tempPath = '$savePath.part-$request-$transferId';
      tempLrcPath = '$tempPath.lrc';
      cancelToken = CancelToken();
      _cancelTokens.add(cancelToken);

      final client = ref.read(subsonicClientProvider);
      await client.downloadFile(
        url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (_requests.isCurrent(request) && total > 0) {
            _updateTask(songId, progress: received / total);
          }
        },
      );
      if (!_requests.isCurrent(request)) return;

      final fileSize = File(tempPath).lengthSync();
      try {
        final lyrics = await resolver.lyrics(song);
        if (_requests.isCurrent(request) &&
            lyrics != null &&
            lyrics.lines.isNotEmpty) {
          File(tempLrcPath).writeAsStringSync(_buildLrcContent(lyrics));
        }
      } catch (e) {
        debugPrint('[Download] Lyrics download failed (non-fatal): $e');
      }
      if (!_requests.isCurrent(request)) return;

      // No await between the ownership check and promotion: a server switch
      // cannot interleave and let an obsolete transfer touch a newer file.
      final finalFile = File(savePath);
      if (finalFile.existsSync()) finalFile.deleteSync();
      File(tempPath).renameSync(savePath);
      tempPath = null;

      final finalLrcPath =
          '${savePath.replaceAll(RegExp(r'\.[^.]+$'), '')}.lrc';
      final tempLyrics = File(tempLrcPath);
      if (tempLyrics.existsSync()) {
        final finalLyrics = File(finalLrcPath);
        if (finalLyrics.existsSync()) finalLyrics.deleteSync();
        tempLyrics.renameSync(finalLrcPath);
      }
      tempLrcPath = null;

      _updateTask(
        songId,
        status: DownloadStatus.completed,
        localPath: savePath,
        progress: 1.0,
        fileSizeBytes: fileSize,
      );
      await _persist();
    } catch (e) {
      if (_requests.isCurrent(request)) {
        _updateTask(
          songId,
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
      }
    } finally {
      if (cancelToken != null) _cancelTokens.remove(cancelToken);
      if (tempPath != null) {
        final file = File(tempPath);
        if (file.existsSync()) file.deleteSync();
      }
      if (tempLrcPath != null) {
        final file = File(tempLrcPath);
        if (file.existsSync()) file.deleteSync();
      }
    }
  }

  void _updateTask(
    String id, {
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? errorMessage,
    int? fileSizeBytes,
  }) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            status: status,
            progress: progress,
            localPath: localPath,
            errorMessage: errorMessage,
            fileSizeBytes: fileSizeBytes,
          )
        else
          task,
    ];
  }

  Future<void> removeTask(String id) async {
    final matches = state.where((task) => task.id == id);
    final task = matches.isEmpty ? null : matches.first;
    final localPath = task?.localPath;
    // Update and persist the originating server before any filesystem await can
    // allow a provider rebuild to replace state with another server's tasks.
    state = state.where((task) => task.id != id).toList();
    await _persist();
    if (localPath != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final root = Directory('${appDir.path}/navidrome_downloads');
      if (await root.exists()) {
        final rootPath = await root.resolveSymbolicLinks();
        final file = File(localPath);
        if (await file.exists()) {
          final filePath = await file.resolveSymbolicLinks();
          final prefix = '$rootPath${Platform.pathSeparator}';
          if (filePath.startsWith(prefix)) {
            await file.delete();
            final lrcPath =
                '${localPath.replaceAll(RegExp(r'\.[^.]+$'), '')}.lrc';
            final lrcFile = File(lrcPath);
            if (await lrcFile.exists()) await lrcFile.delete();
          }
        }
      }
    }
  }

  int get completedCount =>
      state.where((task) => task.status == DownloadStatus.completed).length;

  double get totalSizeMb {
    final totalBytes = state
        .where((task) => task.status == DownloadStatus.completed)
        .fold<int>(0, (sum, task) => sum + (task.fileSizeBytes ?? 0));
    return totalBytes / (1024 * 1024);
  }

  static String _safeExtension(String? suffix) {
    final extension = suffix?.toLowerCase().trim() ?? '';
    return _allowedExtensions.contains(extension) ? extension : 'mp3';
  }

  static String _buildLrcContent(LyricsList lyrics) {
    final buffer = StringBuffer();
    for (final line in lyrics.lines) {
      if (line.startMs != null) {
        final ms = line.startMs!;
        final min = (ms ~/ 60000).toString().padLeft(2, '0');
        final sec = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
        final frac = (ms % 1000).toString().padLeft(3, '0').substring(0, 2);
        buffer.writeln('[$min:$sec.$frac]${line.text}');
      } else {
        buffer.writeln(line.text);
      }
    }
    return buffer.toString();
  }
}
