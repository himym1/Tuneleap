import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/api/models/models.dart';

/// audio_service 的 Handler，处理后台播放、通知栏、锁屏控制
class NavidromeAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final SubsonicClient _client;

  final List<Song> _queue = [];
  int _currentIndex = -1;

  NavidromeAudioHandler(this._client) {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  // === Getters ===

  AudioPlayer get player => _player;
  List<Song> get songQueue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
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
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
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
    } else {
      _currentIndex = _queue.length - 1;
    }
    await _loadAndPlay();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // === 内部方法 ===

  /// 加载当前歌曲并播放
  Future<void> _loadAndPlay() async {
    final song = currentSong;
    if (song == null) return;
    mediaItem.add(_songToMediaItem(song));
    final url = _client.streamUrl(song.id);
    await _player.setUrl(url);
    await _player.play();
  }

  /// 广播播放状态到系统通知栏/锁屏
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
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
    ));
  }

  /// Song 模型转换为 MediaItem
  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration != null
          ? Duration(seconds: song.duration!)
          : null,
      artUri: song.coverArt != null
          ? Uri.parse(_client.coverArtUrl(song.coverArt!))
          : null,
    );
  }
}
