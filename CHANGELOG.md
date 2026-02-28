# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式。

## [Unreleased] - Phase 2: 好用

### 计划中
- 主导航框架（BottomNavigationBar / NavigationRail）
- 艺术家浏览页
- 专辑浏览页
- 专辑详情页（独立页面替代 BottomSheet）
- 搜索页
- 全屏播放页
- 播放队列 UI
- 播放列表管理
- 收藏 UI
- 设置页

## [0.1.0] - 2026-02-27 - Phase 1: 能听

### Added
- Subsonic API 客户端：token 认证、15 个 API 端点（浏览/搜索/媒体/播放列表/标记）
- 数据模型：Song, Album, Artist, ArtistDetail, Playlist, SearchResult
- 音频播放服务：just_audio 封装，播放/暂停/上下曲/随机/循环/单曲循环
- 后台播放 Handler：audio_service 集成，通知栏/锁屏控制
- 登录页：服务器地址 + 用户名密码配置，连接测试
- 首页：最近添加专辑网格，专辑详情弹窗，歌曲播放
- 迷你播放条：封面图 + 歌曲信息 + 播放/暂停/下一首
- 通用组件：CoverArt（缓存封面）、SongTile（歌曲列表项）
- 主题系统：Material 3 深色/浅色主题，跟随系统
- 状态管理：Riverpod Provider（ServerConfig, SubsonicClient, AudioPlayerService）
- macOS 窗口管理：最小尺寸 400x600，默认 1000x700
- Android 权限：INTERNET, FOREGROUND_SERVICE, WAKE_LOCK
- 工具函数：时长格式化、平台判断

### Known Issues
- ~~audio_handler.dart 编译错误（缺少 _broadcastState 方法）~~ 已修复
- go_router 已声明依赖但未使用（Phase 2 启用）
- 密码以明文存储在 SharedPreferences 中
- HomeScreen 中 _AlbumCard 直接使用 Image.network 而非 CoverArt 组件
