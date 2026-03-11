import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'audio_providers.dart';
import 'server_config_provider.dart';

// ============================================================
// 下载管理
// ============================================================

enum DownloadStatus { pending, downloading, completed, failed }

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
  static const _persistKey = 'download_tasks';
  final _dio = Dio();

  @override
  List<DownloadTask> build() {
    // 从 SharedPreferences 加载已完成的下载任务
    final prefs = ref.read(sharedPreferencesProvider);
    final json = prefs.getString(_persistKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        final tasks = list
            .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
            .toList();
        // 验证本地文件是否还存在
        return tasks.where((t) {
          if (t.localPath == null) return false;
          return File(t.localPath!).existsSync();
        }).toList();
      } catch (_) {}
    }
    return [];
  }

  /// 持久化已完成的任务到 SharedPreferences
  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final completed = state
        .where((t) => t.status == DownloadStatus.completed)
        .map((t) => t.toJson())
        .toList();
    await prefs.setString(_persistKey, jsonEncode(completed));
  }

  bool isDownloaded(String songId) =>
      state.any((t) => t.id == songId && t.status == DownloadStatus.completed);

  bool isDownloading(String songId) => state.any(
    (t) => t.id == songId && t.status == DownloadStatus.downloading,
  );

  Future<void> download(Song song) async {
    // Skip if already downloading or completed
    if (state.any(
      (t) =>
          t.id == song.storageKey &&
          (t.status == DownloadStatus.completed ||
              t.status == DownloadStatus.downloading),
    )) {
      return;
    }
    // Remove failed task with same id
    state = state.where((t) => t.id != song.storageKey).toList();

    final task = DownloadTask(
      id: song.storageKey,
      song: song,
      status: DownloadStatus.downloading,
    );
    state = [...state, task];

    try {
      final resolver = ref.read(songMediaResolverProvider);
      final quality = ref.read(audioQualityProvider);
      final url = await resolver.playbackUrl(song, maxBitRate: quality);

      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/navidrome_downloads');
      await downloadsDir.create(recursive: true);

      final ext = song.suffix ?? 'mp3';
      final safeName = song.storageKey.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-]'),
        '_',
      );
      final savePath = '${downloadsDir.path}/$safeName.$ext';

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _updateTask(song.storageKey, progress: received / total);
          }
        },
      );

      // 获取真实文件大小
      final file = File(savePath);
      final fileSize = await file.length();

      _updateTask(
        song.storageKey,
        status: DownloadStatus.completed,
        localPath: savePath,
        progress: 1.0,
        fileSizeBytes: fileSize,
      );

      // 持久化已完成的任务
      await _persist();
    } catch (e) {
      _updateTask(
        song.storageKey,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
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
      for (final t in state)
        if (t.id == id)
          t.copyWith(
            status: status,
            progress: progress,
            localPath: localPath,
            errorMessage: errorMessage,
            fileSizeBytes: fileSizeBytes,
          )
        else
          t,
    ];
  }

  void removeTask(String id) {
    // 同时删除本地文件
    final task = state.firstWhere(
      (t) => t.id == id,
      orElse: () => DownloadTask(
        id: id,
        song: Song(
          id: id,
          title: '',
          artist: '',
          artistId: '',
          album: '',
          albumId: '',
        ),
      ),
    );
    if (task.localPath != null) {
      final file = File(task.localPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    state = state.where((t) => t.id != id).toList();
    _persist(); // 更新持久化
  }

  int get completedCount =>
      state.where((t) => t.status == DownloadStatus.completed).length;

  /// 已下载文件的真实总大小（MB）
  double get totalSizeMb {
    final totalBytes = state
        .where((t) => t.status == DownloadStatus.completed)
        .fold<int>(0, (sum, t) => sum + (t.fileSizeBytes ?? 0));
    return totalBytes / (1024 * 1024);
  }
}
