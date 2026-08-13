import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/media_request_headers.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/api/song_media_resolver.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/utils/request_generation.dart';
import 'package:navidrome_player/providers/server_scope.dart';
import 'audio_player_service.dart';
import 'playback_origin.dart';

/// audio_service 的 Handler，处理后台播放、通知栏、锁屏控制
///
/// 这是唯一持有 AudioPlayer 实例的类。
/// AudioPlayerService 通过委托调用本类的方法。
class NavidromeAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  SubsonicClient _subsonicClient;
  BackendClient _backendClient;
  int _maxBitRate = 0;
  final SharedPreferences? _prefs;
  String _serverId;
  String get _historyKey => scopedPreferenceKey('play_history', _serverId);
  String? Function(Song song)? _localPathLookup;
  final RequestGeneration _loadRequests = RequestGeneration();
  Future<void> _playerOperations = Future.value();
  String? _loadedSongKey;
  int? _loadedRequest;

  final List<Song> _queue = [];
  final List<PlaybackOrigin?> _origins = [];
  final List<Song> _playHistory = [];
  final StreamController<PlaybackOrigin?> _currentOriginController =
      StreamController<PlaybackOrigin?>.broadcast();
  final StreamController<PlaybackFailure> _playbackFailureController =
      StreamController<PlaybackFailure>.broadcast();
  int _currentIndex = -1;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  bool _shuffle = false;

  // Scrobble 跟踪
  String? _scrobbledSongId;
  String? _scrobbleInFlightSongId;

  NavidromeAudioHandler(
    this._subsonicClient,
    this._backendClient, {
    SharedPreferences? prefs,
    String serverId = defaultServerId,
    AudioPlayer? player,
  }) : _player =
           player ?? AudioPlayer(useProxyForRequestHeaders: !Platform.isMacOS),
       _prefs = prefs,
       _serverId = normalizeServerId(serverId) {
    // 加载持久化的播放历史
    _loadHistory();

    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      final completedSongKey = _loadedSongKey;
      final completedRequest = _loadedRequest;
      if (state == ProcessingState.completed &&
          completedSongKey != null &&
          completedRequest != null) {
        unawaited(_onCompleted(completedSongKey, completedRequest));
      }
    });
    // 自动 scrobble：播放超过 50% 或 4 分钟
    _player.positionStream.listen(_checkScrobble);
  }

  Future<void> _enqueuePlayerOperation(Future<void> Function() operation) {
    final result = _playerOperations.then((_) => operation());
    _playerOperations = result.catchError((Object _) {});
    return result;
  }

  /// 从 SharedPreferences 加载播放历史
  void _loadHistory() {
    _playHistory.clear();
    final json = _prefs?.getString(_historyKey);
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List;
      _playHistory.addAll(
        list.map((e) => Song.fromJson(e as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('Failed to load play history: $e');
    }
  }

  /// 持久化播放历史到 SharedPreferences
  void _persistHistory() {
    if (_prefs == null) return;
    final json = jsonEncode(_playHistory.map((s) => s.toJson()).toList());
    _prefs.setString(_historyKey, json);
  }

  void _checkScrobble(Duration position) {
    final song = currentSong;
    if (song == null) return;
    final songKey = scopedSongKey(_serverId, song.storageKey);
    if (_loadedSongKey != songKey ||
        _scrobbledSongId == songKey ||
        _scrobbleInFlightSongId == songKey) {
      return;
    }

    final duration = _player.duration;
    if (duration == null || duration.inSeconds < 10) return;

    final playedRatio = position.inSeconds / duration.inSeconds;
    final playedMinutes = position.inMinutes;
    if (playedRatio >= 0.5 || playedMinutes >= 4) {
      _scrobbleInFlightSongId = songKey;
      unawaited(_scrobble(song, songKey));
    }
  }

  Future<void> _scrobble(Song song, String songKey) async {
    try {
      await _resolver.scrobble(song);
      if (_loadedSongKey == songKey) {
        _scrobbledSongId = songKey;
      }
    } catch (_) {
      // Leave the song unmarked so a later position event can retry.
    } finally {
      if (_scrobbleInFlightSongId == songKey) {
        _scrobbleInFlightSongId = null;
      }
    }
  }

  // === Client / Quality ===

  /// 切换服务器时更新 client 实例
  void updateClients(
    SubsonicClient newSubsonicClient,
    BackendClient newBackend, {
    required String serverId,
  }) {
    final nextServerId = normalizeServerId(serverId);
    final changedSession =
        nextServerId != _serverId ||
        !identical(newSubsonicClient, _subsonicClient) ||
        !identical(newBackend, _backendClient);
    _subsonicClient = newSubsonicClient;
    _backendClient = newBackend;
    if (!changedSession) return;

    _serverId = nextServerId;
    _loadRequests.invalidate();
    _loadedSongKey = null;
    _loadedRequest = null;
    _scrobbledSongId = null;
    _scrobbleInFlightSongId = null;
    unawaited(
      _enqueuePlayerOperation(() async {
        await _player.stop();
        await _player.setLoopMode(LoopMode.off);
      }),
    );
    _queue.clear();
    _clearOrigins();
    _currentIndex = -1;
    queue.add(const []);
    mediaItem.add(null);
    _shuffle = false;
    _repeatMode = PlaybackRepeatMode.off;
    _loadHistory();
  }

  /// 设置最大码率（0 = 原始音质，不限制）
  void setMaxBitRate(int value) {
    _maxBitRate = value;
  }

  /// 设置离线文件查找回调
  void setLocalPathLookup(String? Function(Song song)? lookup) {
    _localPathLookup = lookup;
  }

  SongMediaResolver get _resolver => SongMediaResolver(
    subsonicClient: _subsonicClient,
    backendClient: _backendClient,
  );

  /// 设置音量 (0.0 ~ 1.0)
  void setVolume(double value) {
    unawaited(
      _enqueuePlayerOperation(() => _player.setVolume(value.clamp(0.0, 1.0))),
    );
  }

  /// 设置播放速度 (0.25 ~ 3.0)
  @override
  Future<void> setSpeed(double value) =>
      _enqueuePlayerOperation(() => _player.setSpeed(value.clamp(0.25, 3.0)));

  // === Getters ===

  AudioPlayer get player => _player;
  List<Song> get songQueue => List.unmodifiable(_queue);
  List<Song> get playHistory => List.unmodifiable(_playHistory);
  int get currentIndex => _currentIndex;
  bool get shuffle => _shuffle;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  PlaybackOrigin? get currentPlaybackOrigin =>
      _currentIndex >= 0 && _currentIndex < _origins.length
      ? _origins[_currentIndex]
      : null;
  Stream<PlaybackOrigin?> get currentPlaybackOriginStream =>
      _currentOriginController.stream;
  Stream<PlaybackFailure> get playbackFailureStream =>
      _playbackFailureController.stream;
  bool get hasLoadedCurrentSong =>
      currentSong != null &&
      _loadedSongKey == scopedSongKey(_serverId, currentSong!.storageKey);

  void _publishCurrentOrigin() {
    if (!_currentOriginController.isClosed) {
      _currentOriginController.add(currentPlaybackOrigin);
    }
  }

  void _clearOrigins() {
    _origins.clear();
    _publishCurrentOrigin();
  }

  void _replaceOrigins(List<Song> songs, List<PlaybackOrigin?>? origins) {
    if (origins != null && origins.length != songs.length) {
      throw ArgumentError.value(
        origins.length,
        'origins',
        'must match songs length (${songs.length})',
      );
    }
    _origins
      ..clear()
      ..addAll(origins ?? List<PlaybackOrigin?>.filled(songs.length, null));
    _publishCurrentOrigin();
  }

  // === 队列管理 ===

  /// 设置播放队列
  Future<void> setQueue(
    List<Song> songs, {
    int startIndex = 0,
    List<PlaybackOrigin?>? origins,
  }) async {
    _queue
      ..clear()
      ..addAll(songs);
    _replaceOrigins(songs, origins);
    queue.add(songs.map(_songToMediaItem).toList());
    if (songs.isEmpty) {
      _loadRequests.invalidate();
      _loadedSongKey = null;
      _loadedRequest = null;
      _currentIndex = -1;
      mediaItem.add(null);
      await _enqueuePlayerOperation(_player.stop);
      return;
    }
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _publishCurrentOrigin();
    await _loadAndPlay();
  }

  /// 添加到队列末尾
  void addToQueue(Song song, {PlaybackOrigin? origin}) {
    _queue.add(song);
    _origins.add(origin);
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 在当前歌曲后面插入
  void insertNext(Song song, {PlaybackOrigin? origin}) {
    if (_currentIndex < _queue.length - 1) {
      _queue.insert(_currentIndex + 1, song);
      _origins.insert(_currentIndex + 1, origin);
    } else {
      _queue.add(song);
      _origins.add(origin);
    }
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 从队列中移除
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final removingCurrent = index == _currentIndex;
    final wasPlaying = _player.playing;
    final autoplayNext = wasPlaying || _loadedSongKey == null;
    _queue.removeAt(index);
    if (index < _origins.length) {
      _origins.removeAt(index);
    }

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (removingCurrent) {
      _currentIndex = _queue.isEmpty ? -1 : index.clamp(0, _queue.length - 1);
    }
    queue.add(_queue.map(_songToMediaItem).toList());
    _publishCurrentOrigin();

    if (!removingCurrent) return;
    _loadRequests.invalidate();
    _loadedSongKey = null;
    _loadedRequest = null;
    _scrobbledSongId = null;
    _scrobbleInFlightSongId = null;
    if (_queue.isEmpty) {
      mediaItem.add(null);
      _publishCurrentOrigin();
      await _enqueuePlayerOperation(_player.stop);
    } else {
      await _loadCurrent(autoplay: autoplayNext);
    }
  }

  /// 拖拽排序；[newIndex] 使用 Flutter `onReorderItem` 的已调整索引。
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    final origin = oldIndex < _origins.length
        ? _origins.removeAt(oldIndex)
        : null;
    _queue.insert(newIndex, song);
    _origins.insert(newIndex, origin);

    // 同步 currentIndex
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else {
      if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
        _currentIndex--;
      } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
        _currentIndex++;
      }
    }
    queue.add(_queue.map(_songToMediaItem).toList());
    _publishCurrentOrigin();
  }

  void setShuffle(bool enabled) {
    _shuffle = enabled;
    if (enabled) shuffleQueue();
  }

  /// 随机打乱队列（保持当前歌曲在首位）
  void shuffleQueue() {
    final current = currentSong;
    final currentOrigin = currentPlaybackOrigin;
    final paired = [
      for (var i = 0; i < _queue.length; i++)
        (song: _queue[i], origin: i < _origins.length ? _origins[i] : null),
    ]..shuffle();
    _queue
      ..clear()
      ..addAll(paired.map((e) => e.song));
    _origins
      ..clear()
      ..addAll(paired.map((e) => e.origin));
    if (current != null) {
      final idx = _queue.indexWhere(
        (s) => identical(s, current) || s.storageKey == current.storageKey,
      );
      if (idx >= 0) {
        final song = _queue.removeAt(idx);
        final origin = idx < _origins.length
            ? _origins.removeAt(idx)
            : currentOrigin;
        _queue.insert(0, song);
        _origins.insert(0, origin);
      } else {
        _queue.insert(0, current);
        _origins.insert(0, currentOrigin);
      }
      _currentIndex = 0;
    }
    queue.add(_queue.map(_songToMediaItem).toList());
    _publishCurrentOrigin();
  }

  /// 设置循环模式
  void setRepeat(PlaybackRepeatMode mode) {
    _repeatMode = mode;
    unawaited(
      _enqueuePlayerOperation(
        () => _player.setLoopMode(
          mode == PlaybackRepeatMode.one ? LoopMode.one : LoopMode.off,
        ),
      ),
    );
  }

  // === 播放控制 ===

  @override
  Future<void> play() async {
    final song = currentSong;
    if (song == null) return;
    final songKey = scopedSongKey(_serverId, song.storageKey);
    if (_loadedSongKey != songKey) {
      await _loadAndPlay();
      return;
    }
    final request = _loadRequests.current;
    final origin = currentPlaybackOrigin;
    await _enqueuePlayerOperation(() async {
      if (!_loadRequests.isCurrent(request) ||
          currentSong?.storageKey != song.storageKey ||
          _loadedSongKey != songKey) {
        return;
      }
      _loadedRequest = request;
      _startPlayback(song, request, origin);
    });
  }

  @override
  Future<void> pause() async {
    _loadRequests.invalidate();
    await _enqueuePlayerOperation(_player.pause);
  }

  Future<void> disposePlaybackStreams() async {
    if (!_currentOriginController.isClosed) {
      await _currentOriginController.close();
    }
    if (!_playbackFailureController.isClosed) {
      await _playbackFailureController.close();
    }
  }

  @override
  Future<void> stop() async {
    _loadRequests.invalidate();
    _loadedSongKey = null;
    _loadedRequest = null;
    _scrobbleInFlightSongId = null;
    _publishCurrentOrigin();
    await _enqueuePlayerOperation(_player.stop);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = _repeatMode.nextIndex(_currentIndex, _queue.length);
    if (nextIndex == null) return;
    _currentIndex = nextIndex;
    _publishCurrentOrigin();
    await _loadAndPlay();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _enqueuePlayerOperation(() => _player.seek(Duration.zero));
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_repeatMode == PlaybackRepeatMode.all) {
      _currentIndex = _queue.length - 1;
    } else {
      return;
    }
    _publishCurrentOrigin();
    await _loadAndPlay();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _publishCurrentOrigin();
    await _loadAndPlay();
  }

  @override
  Future<void> seek(Duration position) =>
      _enqueuePlayerOperation(() => _player.seek(position));

  // === 内部方法 ===

  /// 处理仍属于当前已加载 source 的完成事件。
  Future<void> _onCompleted(String completedSongKey, int request) async {
    if (!_loadRequests.isCurrent(request) ||
        _loadedSongKey != completedSongKey) {
      return;
    }
    if (_repeatMode == PlaybackRepeatMode.one) return;

    if (_repeatMode.nextIndex(_currentIndex, _queue.length) == null) {
      await _enqueuePlayerOperation(() async {
        if (!_loadRequests.isCurrent(request) ||
            _loadedSongKey != completedSongKey) {
          return;
        }
        await _player.pause();
        await _player.seek(Duration.zero);
      });
      return;
    }
    if (_loadRequests.isCurrent(request) &&
        _loadedSongKey == completedSongKey) {
      await skipToNext();
    }
  }

  /// 加载当前歌曲并播放
  Future<void> _loadAndPlay() => _loadCurrent(autoplay: true);

  Future<Duration?> _setPlaybackUrl(String url) {
    final headers = mediaRequestHeaders(url, kind: MediaRequestKind.audio);
    return _player.setUrl(url, headers: headers.isEmpty ? null : headers);
  }

  Future<void> _loadCurrent({required bool autoplay}) {
    final request = _loadRequests.begin();
    final song = currentSong;
    if (song == null) return Future.value();
    final songKey = scopedSongKey(_serverId, song.storageKey);
    final localPath = _localPathLookup?.call(song);

    return _enqueuePlayerOperation(() async {
      if (!_loadRequests.isCurrent(request)) return;
      await _player.pause();
      if (!_loadRequests.isCurrent(request)) return;
      _loadedSongKey = null;
      _loadedRequest = null;
      mediaItem.add(_songToMediaItem(song));

      final origin = currentPlaybackOrigin;
      try {
        if (localPath != null && File(localPath).existsSync()) {
          await _player.setFilePath(localPath);
        } else {
          final url = await _resolver.playbackUrl(
            song,
            maxBitRate: _maxBitRate,
          );
          if (!_loadRequests.isCurrent(request)) return;
          try {
            await _setPlaybackUrl(url);
          } catch (_) {
            if (!song.isOnline || !_loadRequests.isCurrent(request)) rethrow;
            final retryUrl = await _resolver.playbackUrl(
              song,
              maxBitRate: _maxBitRate,
            );
            if (!_loadRequests.isCurrent(request)) return;
            await _setPlaybackUrl(retryUrl);
          }
        }
        if (!_loadRequests.isCurrent(request)) return;

        _loadedSongKey = songKey;
        _loadedRequest = request;
        _scrobbledSongId = null;
        _scrobbleInFlightSongId = null;
        // 媒体源加载成功后再记录历史，避免失败播放污染历史。
        _playHistory.removeWhere((s) => s.storageKey == song.storageKey);
        _playHistory.insert(0, song);
        if (_playHistory.length > 50) _playHistory.removeLast();
        _persistHistory();
        _publishCurrentOrigin();

        if (autoplay) _startPlayback(song, request, origin);
      } catch (error) {
        _handlePlaybackError(error, song, request, origin);
      }
    });
  }

  void _startPlayback(Song song, int request, PlaybackOrigin? origin) {
    unawaited(
      _player.play().catchError((Object error) {
        _handlePlaybackError(error, song, request, origin);
      }),
    );
  }

  void _handlePlaybackError(
    Object error,
    Song song,
    int request,
    PlaybackOrigin? origin,
  ) {
    if (!_loadRequests.isCurrent(request)) return;
    _loadedSongKey = null;
    _loadedRequest = null;
    debugPrint('Failed to play ${song.storageKey}: ${error.runtimeType}');
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    final failure = _classifyPlaybackFailure(
      error: error,
      song: song,
      request: request,
      origin: origin,
    );
    if (_loadRequests.isCurrent(request) &&
        currentSong?.storageKey == song.storageKey &&
        !_playbackFailureController.isClosed) {
      _playbackFailureController.add(failure);
    }
  }

  /// 广播播放状态到系统通知栏/锁屏
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ),
    );
  }

  PlaybackFailure _classifyPlaybackFailure({
    required Object error,
    required Song song,
    required int request,
    required PlaybackOrigin? origin,
  }) {
    final typeName = error.runtimeType.toString().toLowerCase();
    final message = error.toString().toLowerCase();
    final PlaybackFailureKind kind;
    if (typeName.contains('timeout') || message.contains('timeout')) {
      kind = PlaybackFailureKind.timeout;
    } else if (typeName.contains('socket') ||
        typeName.contains('handshake') ||
        typeName.contains('connection') ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection')) {
      kind = PlaybackFailureKind.network;
    } else if (typeName.contains('http') ||
        typeName.contains('format') ||
        typeName.contains('stateerror') ||
        message.contains('404') ||
        message.contains('403') ||
        message.contains('source') ||
        message.contains('url')) {
      kind = PlaybackFailureKind.sourceUnavailable;
    } else {
      kind = PlaybackFailureKind.unknown;
    }
    final retryable =
        kind == PlaybackFailureKind.network ||
        kind == PlaybackFailureKind.timeout;
    return PlaybackFailure(
      serverId: _serverId,
      songStorageKey: song.storageKey,
      requestGeneration: request,
      kind: kind,
      retryable: retryable,
      origin: origin,
    );
  }

  /// Song 模型转换为 MediaItem
  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.storageKey,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration != null
          ? Duration(seconds: song.duration!)
          : null,
      artUri: !song.isOnline && song.coverArt != null
          ? Uri.parse(_subsonicClient.coverArtUrl(song.coverArt!))
          : null,
    );
  }
}
