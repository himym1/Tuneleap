import 'package:just_audio/just_audio.dart';
import '../api/models/models.dart';
import '../api/solara_client.dart';
import '../api/subsonic_client.dart';
import 'audio_handler.dart';

enum RepeatMode { off, all, one }

/// 音频播放服务 — UI 层使用的轻量封装，内部委托 NavidromeAudioHandler
///
/// NavidromeAudioHandler 负责真正的 just_audio 播放 + audio_service 系统集成。
/// 本类在其之上提供 shuffle / repeat / queue 编辑等高层逻辑。
class AudioPlayerService {
  final NavidromeAudioHandler _handler;

  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;

  AudioPlayerService(this._handler);

  // === Getters ===

  AudioPlayer get player => _handler.player;
  List<Song> get queue => _handler.songQueue;
  List<Song> get playHistory => _handler.playHistory;
  int get currentIndex => _handler.currentIndex;
  Song? get currentSong => _handler.currentSong;
  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;

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

  // === 播放控制 ===

  /// 播放单首歌曲
  Future<void> playSong(Song song) async {
    _shuffle = false;
    await _handler.setQueue([song], startIndex: 0);
  }

  /// 播放歌曲列表
  Future<void> playAll(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    await _handler.setQueue(songs, startIndex: startIndex);
  }

  /// 添加到队列末尾
  void addToQueue(Song song) {
    _handler.addToQueue(song);
  }

  /// 播放下一首后插入
  void playNext(Song song) {
    _handler.insertNext(song);
  }

  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();

  Future<void> seekTo(Duration position) => _handler.seek(position);

  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) {
      _handler.shuffleQueue();
    }
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
    }
    _handler.setRepeat(_repeatMode);
  }

  /// 从队列中移除
  void removeFromQueue(int index) {
    _handler.removeFromQueue(index);
  }

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
  void updateClients(SubsonicClient newClient, SolaraClient newSolaraClient) {
    _handler.updateClients(newClient, newSolaraClient);
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
  }
}
