# 系统架构

## 架构概览

Navidrome Player 采用四层架构，自上而下为 UI Layer、State Layer、Service Layer、Data Layer。

```
┌─────────────────────────────────────────────┐
│                 UI Layer                     │
│  screens/ widgets/ theme/                    │
├─────────────────────────────────────────────┤
│              State Layer (Riverpod)          │
│  providers/                                  │
├─────────────────────────────────────────────┤
│              Service Layer                   │
│  player/ (AudioPlayerService, AudioHandler)  │
├─────────────────────────────────────────────┤
│               Data Layer                     │
│  api/ (SubsonicClient, Models)               │
└─────────────────────────────────────────────┘
```

## 各层职责

### UI Layer — 用户界面

负责页面渲染和用户交互，不包含业务逻辑。

| 文件 | 职责 |
|------|------|
| `ui/screens/login/login_screen.dart` | 登录页：服务器地址、用户名密码输入，连接测试 |
| `ui/screens/home/home_screen.dart` | 首页：最近添加专辑网格，专辑详情弹窗 |
| `ui/widgets/cover_art.dart` | 封面图组件：CachedNetworkImage 封装 |
| `ui/widgets/mini_player.dart` | 迷你播放条：当前歌曲信息 + 播放控制 |
| `ui/widgets/song_tile.dart` | 歌曲列表项：track/标题/艺术家/专辑/时长 |
| `ui/theme/app_theme.dart` | 主题定义：Material 3 深色/浅色主题 |

### State Layer — 状态管理 (Riverpod)

通过 Riverpod Provider 管理全局状态，连接 UI 和 Service 层。

| 文件 | 职责 |
|------|------|
| `providers/providers.dart` | 全局 Provider 定义：ServerConfig、SubsonicClient、AudioPlayerService |

当前已定义的 Provider：

```dart
sharedPreferencesProvider  → SharedPreferences 实例
serverConfigProvider       → 服务器连接配置 (url/username/password)
subsonicClientProvider     → Subsonic API 客户端实例
audioPlayerServiceProvider → 音频播放服务实例
```

Phase 2 将新增：PlayerProvider、LibraryProvider、SearchProvider、SettingsProvider。

### Service Layer — 业务服务

封装核心业务逻辑，不依赖 UI 框架。

| 文件 | 职责 |
|------|------|
| `player/audio_player_service.dart` | 音频播放服务：just_audio 封装，队列管理，播放控制 |
| `player/audio_handler.dart` | 后台播放 Handler：audio_service 集成，通知栏/锁屏控制 |

### Data Layer — 数据访问

负责与外部数据源通信，提供数据模型。

| 文件 | 职责 |
|------|------|
| `api/subsonic_client.dart` | Subsonic API 客户端：token 认证，15 个 API 端点 |
| `api/models/song.dart` | Song 数据模型 |
| `api/models/album.dart` | Album 数据模型 |
| `api/models/artist.dart` | Artist / ArtistDetail 数据模型 |
| `api/models/playlist.dart` | Playlist 数据模型 |
| `api/models/models.dart` | 模型导出桶文件 |

### 基础设施

| 文件 | 职责 |
|------|------|
| `main.dart` | 应用入口，初始化 WidgetsBinding 和 SharedPreferences |
| `app.dart` | MaterialApp 配置，主题，页面切换逻辑 |
| `utils/duration_format.dart` | 时长格式化工具 |
| `utils/platform_utils.dart` | 平台判断工具 |

## 关键数据流

### 登录流程

```
LoginScreen → ServerConfig (SharedPreferences)
           → SubsonicClient.configure()
           → SubsonicClient.ping() → 成功 → HomeScreen
```

### 浏览与播放流程

```
HomeScreen → SubsonicClient.getAlbumList2()
          → 展示专辑网格
          → 点击专辑 → SubsonicClient.getAlbum()
          → 展示歌曲列表
          → 点击歌曲 → AudioPlayerService.playAll()
                     → SubsonicClient.streamUrl()
                     → just_audio 播放
                     → MiniPlayer 更新状态
```

### Provider 依赖图

```
sharedPreferencesProvider
    └── serverConfigProvider
            └── subsonicClientProvider
                    └── audioPlayerServiceProvider
```

## 架构缺口 (Phase 2+ 待补充)

| 缺口 | 计划方案 | 阶段 |
|------|---------|------|
| 路由系统 | go_router ShellRoute | Phase 2 |
| 本地数据库 | drift (SQLite) | Phase 2 |
| 离线缓存 | 文件系统 + drift 索引 | Phase 4 |
| 错误处理抽象 | Result 类型 + 统一异常 | Phase 2 |
| 依赖注入 | Riverpod codegen | Phase 2 |
