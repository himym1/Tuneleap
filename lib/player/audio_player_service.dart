import 'package:just_audio/just_audio.dart';
import '../api/subsonic_client.dart';
import '../api/models/models.dart';

enum RepeatMode { off, all, one }

/// 音频播放服务 — 封装 just_audio
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final SubsonicClient _client;

  final List<Song> _queue = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;

  AudioPlayerService(this._client);

  // === Getters ===

  AudioPlayer get player => _player;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;

  // === Streams ===

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // === 播放控制 ===

  /// 播放单首歌曲
  Future<void> playSong(Song song) async {
    _queue
      ..clear()
      ..add(song);
    _currentIndex = 0;
    await _loadAndPlay();
  }

  /// 播放歌曲列表
  Future<void> playAll(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue
      ..clear()
      ..addAll(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    await _loadAndPlay();
  }

  /// 添加到队列末尾
  void addToQueue(Song song) {
    _queue.add(song);
  }

  /// 播放下一首后插入
  void playNext(Song song) {
    if (_currentIndex < _queue.length - 1) {
      _queue.insert(_currentIndex + 1, song);
    } else {
      _queue.add(song);
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> seekTo(Duration position) => _player.seek(position);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
    } else {
      return;
    }
    await _loadAndPlay();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // 播放超过 3 秒则回到开头
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

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) {
      final current = currentSong;
      _queue.shuffle();
      if (current != null) {
        _queue.remove(current);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
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
    _player.setLoopMode(
      _repeatMode == RepeatMode.one ? LoopMode.one : LoopMode.off,
    );
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
  }

  /// 加载并播放当前歌曲
  Future<void> _loadAndPlay() async {
    final song = currentSong;
    if (song == null) return;
    final url = _client.streamUrl(song.id);
    await _player.setUrl(url);
    await _player.play();
  }

  /// 初始化播放完成监听
  void init() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_repeatMode == RepeatMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          next();
        }
      }
    });
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
