import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
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

  const NasImportTask({
    required this.id,
    required this.song,
    this.force = false,
    this.stage = NasImportStage.pending,
    this.message,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isActive =>
      stage == NasImportStage.pending ||
      stage == NasImportStage.resolving ||
      stage == NasImportStage.uploading;

  NasImportTask copyWith({
    NasImportStage? stage,
    String? message,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NasImportTask(
      id: id,
      song: song,
      force: force,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
    );
  }
}

final nasImportQueueProvider =
    NotifierProvider<NasImportQueueNotifier, List<NasImportTask>>(
      NasImportQueueNotifier.new,
    );

class NasImportQueueNotifier extends Notifier<List<NasImportTask>> {
  static const _maxFinished = 40;
  bool _pumping = false;
  Timer? _scanDebounce;
  int _seq = 0;

  @override
  List<NasImportTask> build() {
    ref.onDispose(() {
      _scanDebounce?.cancel();
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
          item.copyWith(stage: NasImportStage.pending, clearError: true)
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
      while (true) {
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
    _update(task.id, stage: NasImportStage.resolving, clearError: true);
    final importService = ref.read(navidromeImportServiceProvider);
    try {
      final result = await importService.importOnlineSong(
        task.song,
        force: task.force,
        onStage: (stage) {
          if (stage == NasImportStage.resolving ||
              stage == NasImportStage.uploading) {
            _update(task.id, stage: stage);
          }
        },
      );
      _update(
        task.id,
        stage: NasImportStage.completed,
        message: result.message,
        clearError: true,
      );
      _scheduleScan();
      if (task.song.isOnline) {
        // Optional UI hook consumers can watch completed tasks.
      }
    } on NasDuplicateException catch (error) {
      _update(
        task.id,
        stage: NasImportStage.failed,
        errorMessage: error.message,
      );
    } catch (error) {
      debugPrint('[NasImportQueue] failed: ${error.runtimeType}');
      _update(
        task.id,
        stage: NasImportStage.failed,
        errorMessage: _formatError(error),
      );
    }
    _trimFinished();
  }

  void _update(
    String id, {
    NasImportStage? stage,
    String? message,
    String? errorMessage,
    bool clearError = false,
  }) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            stage: stage,
            message: message,
            errorMessage: errorMessage,
            clearError: clearError,
          )
        else
          task,
    ];
  }

  void _trimFinished() {
    final active = state.where((task) => task.isActive).toList();
    final finished = state.where((task) => !task.isActive).toList();
    if (finished.length <= _maxFinished) return;
    state = [...active, ...finished.take(_maxFinished)];
  }

  void _scheduleScan() {
    _scanDebounce?.cancel();
    _scanDebounce = Timer(const Duration(seconds: 2), () async {
      try {
        await ref.read(subsonicClientProvider).startScan();
      } catch (error) {
        debugPrint('[NasImportQueue] scan failed: ${error.runtimeType}');
      }
    });
  }

  static String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) return 'unknown error';
    return message.length <= 160 ? message : '${message.substring(0, 157)}...';
  }
}
