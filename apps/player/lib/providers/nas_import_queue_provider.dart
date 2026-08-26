import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/navidrome_import_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:navidrome_player/utils/song_identity.dart';

export 'navidrome_import_provider.dart' show NasImportStage;

class NasImportTask {
  final String id;
  final Song song;
  final bool force;
  final NasImportStage stage;
  final String? message;
  final String? errorMessage;
  final DateTime createdAt;
  final int bytesReceived;
  final int? bytesTotal;
  final double speedBps;

  const NasImportTask({
    required this.id,
    required this.song,
    this.force = false,
    this.stage = NasImportStage.pending,
    this.message,
    this.errorMessage,
    required this.createdAt,
    this.bytesReceived = 0,
    this.bytesTotal,
    this.speedBps = 0,
  });

  bool get isActive =>
      stage == NasImportStage.pending ||
      stage == NasImportStage.resolving ||
      stage == NasImportStage.uploading;

  double? get fraction {
    final total = bytesTotal;
    if (total == null || total <= 0) return null;
    return (bytesReceived / total).clamp(0.0, 1.0);
  }

  NasImportTask copyWith({
    NasImportStage? stage,
    String? message,
    String? errorMessage,
    bool clearError = false,
    int? bytesReceived,
    int? bytesTotal,
    double? speedBps,
    bool clearProgress = false,
  }) {
    return NasImportTask(
      id: id,
      song: song,
      force: force,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
      bytesReceived: clearProgress ? 0 : (bytesReceived ?? this.bytesReceived),
      bytesTotal: clearProgress ? null : (bytesTotal ?? this.bytesTotal),
      speedBps: clearProgress ? 0 : (speedBps ?? this.speedBps),
    );
  }
}

String formatNasImportBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    return '${kb >= 10 ? kb.round() : kb.toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatNasImportSpeed(double bytesPerSecond) {
  return '${formatNasImportBytes(bytesPerSecond.round())}/s';
}

String localizeNasImportError(S l10n, String? raw) {
  if (raw == null || raw.trim().isEmpty) return l10n.nasImportErrorFailed;
  final text = raw.trim();
  final lower = text.toLowerCase();
  if (text.startsWith('DioException') ||
      text.contains('This exception was thrown because the response')) {
    return l10n.nasImportErrorFailed;
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return l10n.nasImportErrorTimeout;
  }
  if (lower.contains('unavailable')) {
    return l10n.nasImportErrorUnavailable;
  }
  if (lower.contains('too slow')) {
    return l10n.nasImportErrorSlowUpstream;
  }
  return text;
}

String formatNasImportTransfer(NasImportTask task) {
  final received = formatNasImportBytes(task.bytesReceived);
  final speed = formatNasImportSpeed(task.speedBps);
  final total = task.bytesTotal;
  if (total != null && total > 0) {
    return '$received / ${formatNasImportBytes(total)} · $speed';
  }
  if (task.bytesReceived <= 0 && task.speedBps <= 0) return '';
  return '$received · $speed';
}

final nasImportQueueProvider =
    NotifierProvider<NasImportQueueNotifier, List<NasImportTask>>(
      NasImportQueueNotifier.new,
    );

class NasImportQueueNotifier extends Notifier<List<NasImportTask>> {
  static const _maxFinished = 40;
  static const _progressPollInterval = Duration(seconds: 1);
  bool _pumping = false;
  Timer? _scanDebounce;
  Timer? _progressPoll;
  int _seq = 0;

  @override
  List<NasImportTask> build() {
    ref.onDispose(() {
      _scanDebounce?.cancel();
      _progressPoll?.cancel();
    });
    // Drop in-flight work when the active server changes.
    ref.watch(serverConfigProvider.select((c) => c.serverId));
    return const [];
  }

  bool isQueuedOrActive(Song song) {
    final identity = songWeakIdentity(song);
    return state.any(
      (task) => task.isActive && songWeakIdentity(task.song) == identity,
    );
  }

  /// Enqueue an online song for serial NAS import. Returns false if already queued.
  bool enqueue(Song song, {bool force = false}) {
    if (!song.isOnline) {
      throw ArgumentError('Only online songs can be imported');
    }
    final identity = songWeakIdentity(song);
    if (state.any(
      (task) => task.isActive && songWeakIdentity(task.song) == identity,
    )) {
      return false;
    }

    final id = 'nas-import-${++_seq}-${song.storageKey}';
    state = [
      NasImportTask(
        id: id,
        song: song,
        force: force,
        createdAt: DateTime.now(),
      ),
      ...state,
    ];
    unawaited(_pump());
    return true;
  }

  Future<void> retry(String id) async {
    final matches = state.where((task) => task.id == id);
    if (matches.isEmpty) return;
    final task = matches.first;
    if (task.stage != NasImportStage.failed) return;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            stage: NasImportStage.pending,
            clearError: true,
            clearProgress: true,
          )
        else
          item,
    ];
    await _pump();
  }

  void remove(String id) {
    final matches = state.where((task) => task.id == id);
    if (matches.isEmpty) return;
    final task = matches.first;
    if (task.stage == NasImportStage.resolving ||
        task.stage == NasImportStage.uploading) {
      return;
    }
    state = state.where((task) => task.id != id).toList();
  }

  void clearFinished() {
    state = state.where((task) => task.isActive).toList();
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (ref.mounted) {
        final pending = state
            .where((task) => task.stage == NasImportStage.pending)
            .toList();
        if (pending.isEmpty) break;
        // FIFO: oldest pending first (state is newest-first).
        final task = pending.last;
        await _run(task);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(NasImportTask task) async {
    if (!ref.mounted) return;
    _update(
      task.id,
      stage: NasImportStage.resolving,
      clearError: true,
      clearProgress: true,
    );
    final importService = ref.read(navidromeImportServiceProvider);
    try {
      final result = await importService.importOnlineSong(
        task.song,
        force: task.force,
        onStage: (stage) {
          if (!ref.mounted) return;
          if (stage == NasImportStage.resolving ||
              stage == NasImportStage.uploading) {
            _update(task.id, stage: stage);
            if (stage == NasImportStage.uploading) {
              _ensureProgressPoll();
            }
          }
        },
      );
      if (!ref.mounted) return;
      _update(
        task.id,
        stage: NasImportStage.completed,
        message: result.message,
        clearError: true,
        clearProgress: true,
      );
      _scheduleScan();
    } on NasDuplicateException catch (error) {
      if (!ref.mounted) return;
      _update(
        task.id,
        stage: NasImportStage.failed,
        errorMessage: error.message,
        clearProgress: true,
      );
    } catch (error) {
      if (!ref.mounted) return;
      debugPrint('[NasImportQueue] failed: ${error.runtimeType}');
      _update(
        task.id,
        stage: NasImportStage.failed,
        errorMessage: _formatError(error),
        clearProgress: true,
      );
    }
    _stopProgressPollIfIdle();
    if (!ref.mounted) return;
    _trimFinished();
  }

  void _update(
    String id, {
    NasImportStage? stage,
    String? message,
    String? errorMessage,
    bool clearError = false,
    int? bytesReceived,
    int? bytesTotal,
    double? speedBps,
    bool clearProgress = false,
  }) {
    if (!ref.mounted) return;
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            stage: stage,
            message: message,
            errorMessage: errorMessage,
            clearError: clearError,
            bytesReceived: bytesReceived,
            bytesTotal: bytesTotal,
            speedBps: speedBps,
            clearProgress: clearProgress,
          )
        else
          task,
    ];
  }

  void _ensureProgressPoll() {
    if (_progressPoll != null) return;
    _progressPoll = Timer.periodic(_progressPollInterval, (_) {
      unawaited(_refreshProgress());
    });
    unawaited(_refreshProgress());
  }

  void _stopProgressPollIfIdle() {
    if (state.any((task) => task.stage == NasImportStage.uploading)) return;
    _progressPoll?.cancel();
    _progressPoll = null;
  }

  Future<void> _refreshProgress() async {
    if (!ref.mounted) return;
    final uploading = state.where(
      (task) => task.stage == NasImportStage.uploading,
    );
    if (uploading.isEmpty) {
      _stopProgressPollIfIdle();
      return;
    }
    try {
      final progress = await ref
          .read(backendClientProvider)
          .getNasImportProgress();
      if (!ref.mounted) return;
      final task = uploading.first;
      if (!progress.active && progress.bytesReceived <= 0) return;
      _update(
        task.id,
        bytesReceived: progress.bytesReceived,
        bytesTotal: progress.bytesTotal,
        speedBps: progress.speedBps,
      );
    } catch (error) {
      debugPrint('[NasImportQueue] progress: ${error.runtimeType}');
    }
  }

  void _trimFinished() {
    if (!ref.mounted) return;
    final active = state.where((task) => task.isActive).toList();
    final finished = state.where((task) => !task.isActive).toList();
    if (finished.length <= _maxFinished) return;
    state = [...active, ...finished.take(_maxFinished)];
  }

  void _scheduleScan() {
    if (!ref.mounted) return;
    _scanDebounce?.cancel();
    _scanDebounce = Timer(const Duration(seconds: 2), () async {
      if (!ref.mounted) return;
      try {
        await ref.read(subsonicClientProvider).startScan();
      } catch (error) {
        debugPrint('[NasImportQueue] scan failed: ${error.runtimeType}');
      }
    });
  }

  static String _formatError(Object error) => formatNasImportError(error);
}
