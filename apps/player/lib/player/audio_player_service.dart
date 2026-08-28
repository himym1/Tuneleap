import 'package:just_audio/just_audio.dart';
import '../api/models/models.dart';
import '../api/backend_client.dart';
import '../api/subsonic_client.dart';
import 'audio_handler.dart';
import 'playback_origin.dart';

enum PlaybackRepeatMode {
  off,
  all,
  one;

  int? nextIndex(int currentIndex, int queueLength) {
    if (queueLength <= 0 || currentIndex < 0 || currentIndex >= queueLength) {
      return null;
    }
    if (currentIndex < queueLength - 1) return currentIndex + 1;
    return this == all ? 0 : null;
  }
}

/// 音频播放服务 — UI 层使用的轻量封装，内部委托 NavidromeAudioHandler
///
/// NavidromeAudioHandler 负责真正的 just_audio 播放 + audio_service 系统集成。
/// 本类在其之上提供 shuffle / repeat / queue 编辑等高层逻辑。
class AudioPlayerService {
  final NavidromeAudioHandler _handler;

  AudioPlayerService(this._handler);

  // === Getters ===

  AudioPlayer get player => _handler.player;
  List<Song> get queue => _handler.songQueue;
  List<Song> get playHistory => _handler.playHistory;
  int get currentIndex => _handler.currentIndex;
  Song? get currentSong => _handler.currentSong;
  bool get shuffle => _handler.shuffle;
  PlaybackRepeatMode get repeatMode => _handler.repeatMode;
  PlaybackOrigin? get currentPlaybackOrigin => _handler.currentPlaybackOrigin;

  // === Streams (从 handler 的 AudioPlayer 透传) ===

  Stream<Duration> get positionStream => _handler.player.positionStream;
  Stream<Duration?> get durationStream => _handler.player.durationStream;
  Stream<bool> get playingStream => _handler.player.playingStream;
  Stream<PlayerState> get playerStateStream =>
      _handler.player.playerStateStream;

  /// 当前歌曲变化流 — mediaItem 变化时发射当前 Song
  Stream<Song?> get currentSongStream => _handler.mediaItem
      .map((_) => _handler.currentSong)
      .distinct((a, b) => a?.storageKey == b?.storageKey);

  Stream<PlaybackOrigin?> get currentPlaybackOriginStream =>
      _handler.currentPlaybackOriginStream;

  Stream<PlaybackFailure> get playbackFailureStream =>
      _handler.playbackFailureStream;
  Stream<(bool, PlaybackRepeatMode)> get playbackModeStream =>
      _handler.playbackModeStream;

  // === 播放控制 ===

  /// 播放单首歌曲
  Future<void> playSong(Song song, {PlaybackOrigin? origin}) async {
    await _handler.setQueue([song], startIndex: 0, origins: [origin]);
    _reshuffleQueueIfEnabled();
  }

  /// 播放单首歌曲，并确认媒体源已成功加载。
  Future<bool> playSongAndConfirm(Song song, {PlaybackOrigin? origin}) async {
    await playSong(song, origin: origin);
    return _handler.hasLoadedCurrentSong;
  }

  /// 播放歌曲列表
  Future<void> playAll(
    List<Song> songs, {
    int startIndex = 0,
    List<PlaybackOrigin?>? origins,
  }) async {
    if (songs.isEmpty) return;
    await _handler.setQueue(songs, startIndex: startIndex, origins: origins);
    _reshuffleQueueIfEnabled();
  }

  /// 播放列表并确认当前曲目已成功加载。
  Future<bool> playAllAndConfirm(
    List<Song> songs, {
    int startIndex = 0,
    List<PlaybackOrigin?>? origins,
  }) async {
    await playAll(songs, startIndex: startIndex, origins: origins);
    return _handler.hasLoadedCurrentSong;
  }

  void _reshuffleQueueIfEnabled() {
    if (_handler.shuffle) _handler.shuffleQueue();
  }

  /// 添加到队列末尾
  void addToQueue(Song song, {PlaybackOrigin? origin}) {
    _handler.addToQueue(song, origin: origin);
  }

  /// 播放下一首后插入
  void playNext(Song song, {PlaybackOrigin? origin}) {
    _handler.insertNext(song, origin: origin);
  }

  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();

  Future<void> seekTo(Duration position) => _handler.seek(position);

  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();

  void toggleShuffle() {
    _handler.setShuffle(!_handler.shuffle);
  }

  void cycleRepeatMode() {
    final nextMode = switch (_handler.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    _handler.setRepeat(nextMode);
  }

  /// 从队列中移除
  Future<void> removeFromQueue(int index) => _handler.removeFromQueue(index);

  /// 清空播放队列并停止
  Future<void> clearQueue() => _handler.setQueue(const []);

  /// 移动队列中的歌曲（拖拽排序）
  void reorderQueue(int oldIndex, int newIndex) {
    _handler.reorderQueue(oldIndex, newIndex);
  }

  /// 跳转到队列中的指定位置播放
  Future<void> skipToIndex(int index) async {
    await _handler.skipToQueueItem(index);
  }

  /// 设置最大码率
  void setMaxBitRate(int value) {
    _handler.setMaxBitRate(value);
  }

  /// 更新底层 SubsonicClient（服务器切换时调用）
  void updateClients(
    SubsonicClient newClient,
    BackendClient newBackendClient, {
    required String serverId,
  }) {
    _handler.updateClients(newClient, newBackendClient, serverId: serverId);
  }

  /// 设置音量
  void setVolume(double value) {
    _handler.setVolume(value);
  }

  /// 设置播放速度
  Future<void> setSpeed(double value) async {
    await _handler.setSpeed(value);
  }

  /// 设置离线文件查找回调
  void setLocalPathLookup(String? Function(Song song)? lookup) {
    _handler.setLocalPathLookup(lookup);
  }

  /// 初始化（空实现，handler 自身已在构造函数中初始化）
  void init() {
    // handler 内部已处理播放完成监听
  }

  Future<void> dispose() async {
    await _handler.stop();
    await _handler.disposePlaybackStreams();
  }
}
