import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/api/song_media_resolver.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'audio_player_service.dart';

/// audio_service 的 Handler，处理后台播放、通知栏、锁屏控制
///
/// 这是唯一持有 AudioPlayer 实例的类。
/// AudioPlayerService 通过委托调用本类的方法。
class NavidromeAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  SubsonicClient _subsonicClient;
  BackendClient _backendClient;
  int _maxBitRate = 0;
  final SharedPreferences? _prefs;
  static const _historyKey = 'play_history';
  String? Function(Song song)? _localPathLookup;

  final List<Song> _queue = [];
  final List<Song> _playHistory = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.off;

  // Scrobble 跟踪
  String? _scrobbledSongId;

  NavidromeAudioHandler(
    this._subsonicClient,
    this._backendClient, {
    SharedPreferences? prefs,
  }) : _prefs = prefs {
    // 加载持久化的播放历史
    _loadHistory();

    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onCompleted();
      }
    });
    // 自动 scrobble：播放超过 50% 或 4 分钟
    _player.positionStream.listen(_checkScrobble);
  }

  /// 从 SharedPreferences 加载播放历史
  void _loadHistory() {
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
    if (_scrobbledSongId == song.storageKey) return; // 已上报

    final duration = _player.duration;
    if (duration == null || duration.inSeconds < 10) return;

    final playedRatio = position.inSeconds / duration.inSeconds;
    final playedMinutes = position.inMinutes;

    if (playedRatio >= 0.5 || playedMinutes >= 4) {
      _scrobbledSongId = song.storageKey;
      _resolver.scrobble(song).catchError((_) {});
    }
  }

  // === Client / Quality ===

  /// 切换服务器时更新 client 实例
  void updateClients(SubsonicClient newSubsonicClient, BackendClient newBackend) {
    _subsonicClient = newSubsonicClient;
    _backendClient = newBackend;
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
    _player.setVolume(value.clamp(0.0, 1.0));
  }

  /// 设置播放速度 (0.25 ~ 3.0)
  @override
  Future<void> setSpeed(double value) async {
    await _player.setSpeed(value.clamp(0.25, 3.0));
  }

  // === Getters ===

  AudioPlayer get player => _player;
  List<Song> get songQueue => List.unmodifiable(_queue);
  List<Song> get playHistory => List.unmodifiable(_playHistory);
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  // === 队列管理 ===

  /// 设置播放队列
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    _queue
      ..clear()
      ..addAll(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    queue.add(songs.map(_songToMediaItem).toList());
    await _loadAndPlay();
  }

  /// 添加到队列末尾
  void addToQueue(Song song) {
    _queue.add(song);
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 在当前歌曲后面插入
  void insertNext(Song song) {
    if (_currentIndex < _queue.length - 1) {
      _queue.insert(_currentIndex + 1, song);
    } else {
      _queue.add(song);
    }
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 从队列中移除
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    }
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 拖拽排序
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _queue.insert(adjustedNew, song);

    // 同步 currentIndex
    if (oldIndex == _currentIndex) {
      _currentIndex = adjustedNew;
    } else {
      if (oldIndex < _currentIndex && adjustedNew >= _currentIndex) {
        _currentIndex--;
      } else if (oldIndex > _currentIndex && adjustedNew <= _currentIndex) {
        _currentIndex++;
      }
    }
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 随机打乱队列（保持当前歌曲在首位）
  void shuffleQueue() {
    final current = currentSong;
    _queue.shuffle();
    if (current != null) {
      _queue.remove(current);
      _queue.insert(0, current);
      _currentIndex = 0;
    }
    queue.add(_queue.map(_songToMediaItem).toList());
  }

  /// 设置循环模式
  void setRepeat(RepeatMode mode) {
    _repeatMode = mode;
    _player.setLoopMode(mode == RepeatMode.one ? LoopMode.one : LoopMode.off);
  }

  // === 播放控制 ===

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
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
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      // 队列播完：循环模式回到开头，否则也回到开头继续播
      _currentIndex = 0;
    }
    await _loadAndPlay();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = _queue.length - 1;
    } else {
      return;
    }
    await _loadAndPlay();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _loadAndPlay();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // === 内部方法 ===

  /// 播放完成时的处理
  ///
  /// 注意：当 _repeatMode == RepeatMode.one 时，just_audio 的 LoopMode.one
  /// 会自动循环，此处不再手动 seek+play 以避免双重触发。
  void _onCompleted() {
    if (_repeatMode == RepeatMode.one) {
      // LoopMode.one 已由 just_audio 自动处理
      return;
    }
    skipToNext();
  }

  /// 加载当前歌曲并播放
  Future<void> _loadAndPlay() async {
    final song = currentSong;
    if (song == null) return;
    _scrobbledSongId = null; // 重置 scrobble 跟踪

    // 记录播放历史（去重后前插，最多保留 50 首）
    _playHistory.removeWhere((s) => s.storageKey == song.storageKey);
    _playHistory.insert(0, song);
    if (_playHistory.length > 50) _playHistory.removeLast();
    _persistHistory(); // 持久化

    mediaItem.add(_songToMediaItem(song));

    // 优先使用已下载的本地文件
    final localPath = _localPathLookup?.call(song);
    try {
      if (localPath != null && File(localPath).existsSync()) {
        await _player.setFilePath(localPath);
      } else {
        final url = await _resolver.playbackUrl(song, maxBitRate: _maxBitRate);
        await _player.setUrl(url);
      }
      await _player.play();
    } catch (e) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
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
