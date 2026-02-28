# Phase 1: 能听 — 基础播放

> 状态：✅ 完成 | 文件数：19 | 代码行数：1370

## 概述

Phase 1 的目标是实现最基本的播放能力：连接 Navidrome 服务端，浏览音乐库，播放歌曲。

## 已实现功能

### 1. 项目搭建与依赖配置

- Flutter 3.38 + Dart 3.10 项目初始化
- Android + macOS 双平台配置
- 核心依赖引入（just_audio, dio, riverpod 等）
- 关键文件：`pubspec.yaml`, `main.dart`

### 2. Subsonic API 客户端

- Token 认证（MD5 + salt）
- 15 个 API 端点实现
- 统一错误处理（SubsonicApiException）
- 关键文件：`lib/api/subsonic_client.dart` (231 行)

### 3. 数据模型定义

- Song：歌曲（id, title, album, artist, duration, coverArt 等）
- Album：专辑（id, name, artist, songCount, coverArt 等）
- Artist / ArtistDetail：艺术家及详情
- Playlist：播放列表
- 关键文件：`lib/api/models/`

### 4. 歌曲列表获取与展示

- 最近添加专辑网格（getAlbumList2 type=newest）
- 专辑详情弹窗（getAlbum 获取歌曲列表）
- 关键文件：`lib/ui/screens/home/home_screen.dart` (187 行)

### 5. just_audio 音频播放

- 通过 stream URL 播放歌曲
- 支持多种音频格式（MP3, FLAC, OGG 等）
- 关键文件：`lib/player/audio_player_service.dart` (168 行)

### 6. 基本播放控制

- 播放 / 暂停
- 上一首 / 下一首（队列管理）
- 随机播放（shuffle）
- 循环模式（关闭 / 列表循环 / 单曲循环）
- 播放完成自动下一首
- 关键文件：`lib/player/audio_player_service.dart`

### 7. 基础 UI

- 登录页：服务器地址 + 用户名密码，连接测试，错误提示
- 首页：专辑网格 + 专辑详情弹窗 + 歌曲播放
- 迷你播放条：封面图 + 歌曲信息 + 播放/暂停/下一首
- Material 3 深色/浅色主题（跟随系统）
- 关键文件：`lib/ui/`

### 8. 平台权限配置

- Android：INTERNET, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK, WAKE_LOCK
- macOS：app-sandbox, network.client, audio-input, JIT (debug)
- macOS 窗口：最小 400x600，默认 1000x700
- 关键文件：`AndroidManifest.xml`, `*.entitlements`, `lib/app.dart`
