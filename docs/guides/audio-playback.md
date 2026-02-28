# 音频播放架构

本项目的音频播放由两个核心组件协作完成。

## 组件概览

| 组件 | 文件 | 职责 |
|------|------|------|
| AudioPlayerService | `lib/player/audio_player_service.dart` | 播放逻辑、队列管理 |
| NavidromeAudioHandler | `lib/player/audio_handler.dart` | 后台播放、系统集成 |

## AudioPlayerService

封装 just_audio，提供播放控制和队列管理。

### 核心能力

- 单曲播放：`playSong(Song)`
- 列表播放：`playAll(List<Song>, startIndex)`
- 播放控制：`play()`, `pause()`, `seekTo()`
- 队列导航：`next()`, `previous()`
- 队列管理：`addToQueue()`, `playNext()`, `removeFromQueue()`
- 播放模式：`toggleShuffle()`, `cycleRepeatMode()`

### 播放流程

```
playSong(song) / playAll(songs)
  → 更新队列 (_queue) 和索引 (_currentIndex)
  → _loadAndPlay()
    → client.streamUrl(song.id) 获取流 URL
    → _player.setUrl(url)
    → _player.play()
```

### 自动下一首

```dart
// init() 中注册监听
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
```

## NavidromeAudioHandler

继承 `BaseAudioHandler`，集成 audio_service 实现系统级播放控制。

### 核心能力

- 系统集成：通知栏控制、锁屏控制、媒体键响应
- 播放控制：`play()`, `pause()`, `stop()`, `seek()`
- 队列导航：`skipToNext()`, `skipToPrevious()`
- 状态广播：`_broadcastState()` 将 just_audio 状态映射到 audio_service

### 状态广播机制

```
just_audio PlaybackEvent
  → _broadcastState()
    → 映射 ProcessingState → AudioProcessingState
    → 构造 PlaybackState (controls, position, playing)
    → playbackState.add(...)
    → 系统通知栏/锁屏自动更新
```

### 两个组件的关系

当前 Phase 1 主要使用 AudioPlayerService。Phase 2 将统一切换到 NavidromeAudioHandler 作为主入口，AudioPlayerService 的逻辑逐步迁移到 Handler 中。
