# Navidrome Player — 项目规划文档

> 跨平台音乐播放器，对接 Navidrome 服务端（Subsonic API），支持 Android + macOS

## 1. 项目概述

### 1.1 背景

- 个人音乐播放需求，Navidrome 作为自建音乐服务端
- 现有音流播放器更新缓慢，希望自建可控的播放器
- 目标平台：Android（手机）+ macOS（电脑）

### 1.2 核心目标

| 优先级 | 目标 | 说明 |
|--------|------|------|
| P0 | 基本播放 | 连接 Navidrome，浏览/搜索/播放音乐 |
| P0 | 后台播放 | 锁屏控制、通知栏控制、音频焦点 |
| P1 | 播放队列 | 队列管理、随机/循环/单曲模式 |
| P1 | 离线缓存 | 下载歌曲供离线播放 |
| P2 | 歌词显示 | 内嵌歌词 + 在线歌词 |
| P2 | 主题适配 | 深色/浅色主题、封面取色 |
| P3 | 均衡器 | 音频均衡器调节 |

### 1.3 技术选型

| 类别 | 选型 | 理由 |
|------|------|------|
| 框架 | **Flutter 3.38** | 一套代码覆盖 Android + macOS，音流已验证可行 |
| 语言 | **Dart 3.10** | Flutter 原生语言 |
| 音频引擎 | **just_audio** + **audio_service** | 成熟稳定，支持后台播放/锁屏/通知栏 |
| HTTP | **dio** | 拦截器、取消、进度回调 |
| 状态管理 | **riverpod** | 类型安全、可测试、社区活跃 |
| 本地存储 | **drift** (SQLite) | 类型安全的数据库访问，适合结构化缓存 |
| 配置存储 | **shared_preferences** | 简单 KV 存储（服务器地址、Token 等） |
| 图片缓存 | **cached_network_image** | 封面图缓存 |
| 桌面窗口 | **window_manager** | macOS 窗口尺寸/标题栏控制 |

---

## 2. 系统架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────┐
│                    UI Layer                  │
│  ┌─────────┐ ┌─────────┐ ┌───────────────┐  │
│  │ Screens │ │ Widgets │ │ Platform Adapt │  │
│  └────┬────┘ └────┬────┘ └───────┬───────┘  │
│       └───────────┼───────────────┘          │
├───────────────────┼─────────────────────────┤
│              State Layer (Riverpod)          │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │
│  │ Player   │ │ Library  │ │ Settings    │  │
│  │ Provider │ │ Provider │ │ Provider    │  │
│  └────┬─────┘ └────┬─────┘ └──────┬──────┘  │
├───────┼─────────────┼──────────────┼────────┤
│            Service Layer                     │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │
│  │ Audio    │ │ Subsonic │ │ Cache       │  │
│  │ Service  │ │ Client   │ │ Service     │  │
│  └────┬─────┘ └────┬─────┘ └──────┬──────┘  │
├───────┼─────────────┼──────────────┼────────┤
│            Data Layer                        │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │
│  │just_audio│ │  dio     │ │  drift/SQL  │  │
│  │audio_svc │ │  HTTP    │ │  Storage    │  │
│  └──────────┘ └──────────┘ └─────────────┘  │
└─────────────────────────────────────────────┘
```

### 2.2 目录结构

```
lib/
├── main.dart                       # 入口
├── app.dart                        # MaterialApp 配置
│
├── api/                            # Subsonic API 层
│   ├── subsonic_client.dart        # HTTP 客户端 + 认证逻辑
│   ├── models/                     # 数据模型
│   │   ├── artist.dart
│   │   ├── album.dart
│   │   ├── song.dart
│   │   ├── playlist.dart
│   │   └── server_info.dart
│   └── endpoints/                  # API 接口封装
│       ├── media_retrieval.dart    # stream, getCoverArt, getLyrics
│       ├── browsing.dart           # getArtists, getAlbum, getSong
│       ├── search.dart             # search3
│       └── playlists.dart          # getPlaylists, createPlaylist
│
├── player/                         # 播放核心
│   ├── audio_player_service.dart   # just_audio 封装
│   ├── audio_handler.dart          # audio_service handler (后台播放)
│   └── queue_manager.dart          # 播放队列管理
│
├── providers/                      # Riverpod providers
│   ├── player_provider.dart        # 播放状态
│   ├── library_provider.dart       # 音乐库状态
│   ├── search_provider.dart        # 搜索状态
│   └── settings_provider.dart      # 设置状态
│
├── ui/                             # 界面
│   ├── screens/
│   │   ├── login/                  # 服务器连接/登录
│   │   │   └── login_screen.dart
│   │   ├── home/                   # 首页（最近播放、推荐）
│   │   │   └── home_screen.dart
│   │   ├── library/                # 音乐库（艺术家/专辑/歌曲）
│   │   │   ├── artists_screen.dart
│   │   │   ├── albums_screen.dart
│   │   │   └── songs_screen.dart
│   │   ├── album_detail/           # 专辑详情
│   │   │   └── album_detail_screen.dart
│   │   ├── player/                 # 播放页面
│   │   │   └── player_screen.dart
│   │   ├── search/                 # 搜索
│   │   │   └── search_screen.dart
│   │   ├── playlists/              # 播放列表
│   │   │   └── playlists_screen.dart
│   │   └── settings/               # 设置
│   │       └── settings_screen.dart
│   │
│   ├── widgets/                    # 通用组件
│   │   ├── mini_player.dart        # 底部迷你播放条
│   │   ├── song_tile.dart          # 歌曲列表项
│   │   ├── album_card.dart         # 专辑卡片
│   │   ├── artist_card.dart        # 艺术家卡片
│   │   └── cover_art.dart          # 封面图组件
│   │
│   └── theme/                      # 主题
│       ├── app_theme.dart          # 主题定义
│       └── colors.dart             # 颜色常量
│
├── data/                           # 本地数据
│   ├── database.dart               # drift 数据库定义
│   ├── tables/                     # 数据表
│   │   ├── cached_songs.dart
│   │   └── play_history.dart
│   └── preferences.dart            # SharedPreferences 封装
│
└── utils/                          # 工具
    ├── duration_format.dart        # 时长格式化
    └── platform_utils.dart         # 平台判断工具
```

---

## 3. Subsonic API 对接

### 3.1 认证机制

Subsonic API 使用 token 认证：

```
所有请求参数:
  u = 用户名
  t = md5(password + salt)
  s = salt (随机字符串)
  v = API 版本 (1.16.1)
  c = 客户端名称 (navidrome_player)
  f = json
```

### 3.2 核心接口清单

| 分类 | 接口 | 用途 |
|------|------|------|
| **系统** | `ping` | 连接测试 |
| **浏览** | `getArtists` | 获取所有艺术家 |
| | `getArtist` | 获取艺术家详情+专辑列表 |
| | `getAlbum` | 获取专辑详情+歌曲列表 |
| | `getAlbumList2` | 按条件获取专辑列表(最新/最热/随机) |
| **搜索** | `search3` | 全局搜索(艺术家/专辑/歌曲) |
| **媒体** | `stream` | 获取音频流 (核心播放接口) |
| | `getCoverArt` | 获取封面图 |
| | `getLyrics` | 获取歌词 |
| **播放列表** | `getPlaylists` | 获取播放列表 |
| | `getPlaylist` | 获取播放列表详情 |
| | `createPlaylist` | 创建播放列表 |
| | `updatePlaylist` | 更新播放列表 |
| **标记** | `star` / `unstar` | 收藏/取消收藏 |
| | `scrobble` | 上报播放记录 |

### 3.3 Navidrome 特有扩展

Navidrome 在 Subsonic API 基础上提供额外接口：
- `/api/song/{id}/lyrics` — 结构化歌词（支持同步歌词）
- 支持 `transcoding` 参数控制音质

---

## 4. 平台适配

### 4.1 Android

| 功能 | 实现方式 |
|------|----------|
| 后台播放 | `audio_service` → 前台 Service + 通知栏 |
| 锁屏控制 | `audio_service` 自动处理 |
| 音频焦点 | `audio_session` 自动管理 |
| 网络权限 | `AndroidManifest.xml` 配置 |
| 最低版本 | API 21 (Android 5.0) |

### 4.2 macOS

| 功能 | 实现方式 |
|------|----------|
| 窗口管理 | `window_manager` — 最小尺寸、标题栏 |
| 媒体键 | `audio_service` 支持系统媒体键 |
| 网络权限 | `entitlements` 配置 |
| 沙盒 | 需启用 `com.apple.security.network.client` |
| 最低版本 | macOS 10.15 |

---

## 5. 开发路线

### Phase 1 — 能听 (1~2 周) ✅

- [x] 项目搭建 + 依赖配置
- [x] Subsonic API 客户端（认证 + ping + 浏览 + 搜索 + 收藏）
- [x] 数据模型定义（Artist, Album, Song, Playlist）
- [x] 歌曲列表获取 + 展示（首页专辑网格）
- [x] `just_audio` 播放 stream 接口音频
- [x] 基本播放控制（播放/暂停/上下曲/随机/循环）
- [x] 简单的列表 UI（登录页 + 首页 + 迷你播放条）
- [x] 平台权限配置（Android 网络/前台服务，macOS entitlements）

### Phase 2 — 好用 (2~4 周)

- [ ] 后台播放 + 锁屏/通知栏控制 (`audio_service`)
- [ ] 主导航框架（移动端 BottomNav / 桌面端 NavigationRail）
- [ ] 专辑/艺术家浏览页面
- [ ] 搜索功能 (search3)
- [ ] 全屏播放页面（大封面 + 进度条 + 控制按钮）
- [ ] 播放队列管理（随机/循环/单曲 + 队列查看/编辑）
- [ ] 播放列表支持（浏览 + 播放 + 创建）
- [ ] 迷你播放条完善（点击展开全屏播放页）
- [ ] macOS 窗口适配（NavigationRail + 宽屏布局）
- [ ] 收藏功能 (star/unstar)
- [ ] 设置页面（服务器管理 + 主题切换）

---

## 9. Phase 2 功能详细规格

### 9.1 后台播放 (AudioHandler)

**目标**：应用切到后台或锁屏后继续播放，通知栏/锁屏显示控制

**实现方案**：
```
audio_service 的 BaseAudioHandler 子类:
├── play() / pause() / stop()
├── skipToNext() / skipToPrevious()
├── seek(position)
├── setRepeatMode() / setShuffleMode()
├── mediaItem stream → 当前歌曲信息（标题、艺术家、封面URL）
└── playbackState stream → 播放状态（playing、position、controls）
```

**关键文件**：`lib/player/audio_handler.dart`

**Android 通知栏显示**：
- 歌曲标题 + 艺术家
- 封面缩略图
- 上一首 / 播放暂停 / 下一首 按钮

**macOS 系统集成**：
- 媒体键（播放/暂停/上下曲）
- Now Playing 信息（系统控制中心显示）

### 9.2 主导航框架

**目标**：统一的导航结构，移动端和桌面端自适应

**移动端** — BottomNavigationBar：
```
Tab: 首页(Home) | 音乐库(Library) | 搜索(Search) | 设置(Settings)
图标: home | library_music | search | settings
```

**桌面端** — NavigationRail + 侧边栏：
```
NavigationRail (72dp):
  首页 | 音乐库 | 搜索 | 播放列表 | 设置
右侧: 内容区域
底部: MiniPlayer (全宽)
```

**关键文件**：`lib/ui/screens/shell/app_shell.dart`
**路由**：使用 `go_router` 的 `ShellRoute` 嵌套导航

### 9.3 音乐库浏览

**目标**：按艺术家/专辑/全部歌曲三个维度浏览音乐库

**艺术家列表** (`artists_screen.dart`)：
- API: `getArtists` → 按字母索引分组
- 布局: 列表，每项显示 [头像] [名称] [专辑数]
- 点击: 进入艺术家详情（专辑列表）

**专辑列表** (`albums_screen.dart`)：
- API: `getAlbumList2` (type=alphabeticalByName, 分页加载)
- 布局: 网格 (2列移动端 / 4-6列桌面端)
- 排序: 最新 / 字母 / 最近播放 / 随机
- 点击: 进入专辑详情

**专辑详情** (`album_detail_screen.dart`)：
- API: `getAlbum(id)` → 歌曲列表
- 布局: 顶部大封面 + 专辑信息 + 歌曲列表
- 操作: 播放全部 / 随机播放 / 收藏

### 9.4 搜索功能

**目标**：全局搜索艺术家、专辑、歌曲

**交互流程**：
```
1. 点击搜索 Tab → 显示搜索框 + 空状态提示
2. 输入关键词 → 300ms 防抖 → 调用 search3
3. 显示结果分组:
   ├── 艺术家 (横向滚动圆形头像卡片，最多 5 个)
   ├── 专辑 (横向滚动方形封面卡片，最多 5 个)
   └── 歌曲 (纵向列表，最多 20 首)
4. 点击歌曲 → 直接播放
5. 点击专辑/艺术家 → 进入详情页
```

**关键文件**：`lib/ui/screens/search/search_screen.dart`
**API**：`search3(query, artistCount=5, albumCount=5, songCount=20)`

### 9.5 全屏播放页

**目标**：沉浸式播放体验，大封面 + 完整控制

**移动端布局**：
```
SafeArea 内:
  顶部: 收起按钮 (下箭头) + 专辑名
  中部: 封面图 (280x280, 圆角 16dp, 阴影)
  歌曲信息: 歌名 (20sp, bold) + 艺术家 (14sp, secondary)
  进度条: Slider (accent 色) + 当前时间/总时长
  主控制: 随机 | 上一首 | 播放/暂停(56dp圆形) | 下一首 | 循环
  底部操作: 收藏 | 播放队列 | 更多菜单
```

**桌面端布局**：
```
Row:
  左侧 (40%): 大封面图 (居中, 最大 400x400)
  右侧 (60%): Column:
    歌曲信息 + 进度条 + 控制按钮
    Divider
    当前播放队列列表 (可拖拽排序)
```

**关键文件**：`lib/ui/screens/player/player_screen.dart`
**转场动画**：从 MiniPlayer 向上滑出 (Hero 动画封面图)

### 9.6 播放队列管理

**目标**：查看、编辑当前播放队列

**功能**：
- 查看队列中所有歌曲，高亮当前播放
- 拖拽排序（ReorderableListView）
- 左滑删除单首
- 清空队列
- 从任意位置点击跳转播放
- 队列底部显示 "接下来播放" 分隔

**入口**：
- 全屏播放页底部 "队列" 按钮
- 桌面端播放页右侧直接显示

**关键文件**：`lib/ui/screens/player/queue_sheet.dart`

### 9.7 播放列表

**目标**：浏览、播放、创建服务端播放列表

**浏览** (`playlists_screen.dart`)：
- API: `getPlaylists` → 列表展示
- 每项: [封面] [名称] [歌曲数] [时长]
- 点击: 进入播放列表详情

**详情** (`playlist_detail_screen.dart`)：
- API: `getPlaylist(id)` → 歌曲列表
- 操作: 播放全部 / 随机播放
- 长按歌曲: 从列表移除

**创建**：
- 入口: 播放列表页右上角 "+" 按钮
- 弹窗输入名称 → `createPlaylist`
- 歌曲长按菜单 "添加到播放列表" → 选择目标列表

### 9.8 收藏功能

**目标**：收藏/取消收藏歌曲、专辑、艺术家

**交互**：
- 心形图标 (♡ / ♥)，点击切换
- 出现位置: 歌曲列表项、专辑详情、全屏播放页
- API: `star(id)` / `unstar(id)`

### 9.9 设置页面

**目标**：服务器管理 + 应用设置

**设置项**：
```
服务器:
  - 当前服务器地址 + 用户名
  - 测试连接按钮
  - 退出登录

播放:
  - 音质选择 (原始 / 320kbps / 192kbps / 128kbps)
  - Gapless 播放开关

外观:
  - 主题模式 (跟随系统 / 深色 / 浅色)

关于:
  - 版本号
  - 服务器版本 (来自 ping 响应)
```

**关键文件**：`lib/ui/screens/settings/settings_screen.dart`

### Phase 3 — 好看 (2~4 周)

- [ ] 完整播放页面（大封面、进度条、控制按钮）
- [ ] 深色/浅色主题
- [ ] 封面取色动态主题
- [ ] 歌词显示
- [ ] 流畅的页面转场动画
- [ ] 响应式布局（手机竖屏 / 桌面宽屏）

### Phase 4 — 完善 (按需)

- [ ] 离线缓存下载
- [ ] 收藏功能 (star/unstar)
- [ ] 播放记录上报 (scrobble)
- [ ] 音质选择 / 转码设置
- [ ] 均衡器
- [ ] 快捷键支持 (macOS)
- [ ] 多服务器支持

---

## 6. 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 音频
  just_audio: ^0.9.40
  audio_service: ^0.18.15
  audio_session: ^0.1.21

  # 网络
  dio: ^5.7.0
  crypto: ^3.0.5              # MD5 for Subsonic auth

  # 状态管理
  flutter_riverpod: ^2.6.0
  riverpod_annotation: ^2.6.0

  # 本地存储
  drift: ^2.22.0
  sqlite3_flutter_libs: ^0.5.0
  shared_preferences: ^2.3.0

  # UI
  cached_network_image: ^3.4.0
  palette_generator: ^0.3.3   # 封面取色
  go_router: ^14.6.0          # 路由

  # 桌面
  window_manager: ^0.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.6.0
  drift_dev: ^2.22.0
```

---

## 7. 约束与规范

- **代码风格**：遵循 Flutter 官方 lint 规则
- **文件命名**：snake_case
- **状态管理**：统一使用 Riverpod，禁止 setState 管理业务状态
- **API 调用**：统一通过 SubsonicClient，不直接使用 dio
- **错误处理**：API 层统一捕获，UI 层展示用户友好提示
- **平台判断**：通过 `Platform.isMacOS` / `Platform.isAndroid` 做平台适配

---

## 8. UI 设计系统

### 8.1 设计风格

**风格定位**：深色沉浸式音乐播放器，Vibrant & Block-based

- 以深色为主基调，营造沉浸式听歌氛围
- 大色块布局，几何形状，高对比度
- 避免纯平面设计（无层次感）和文字密集页面

### 8.2 色彩体系

```
┌─────────────────────────────────────────┐
│  Color Token        │  Hex      │ 用途  │
├─────────────────────┼───────────┼───────┤
│  primary            │ #1E1B4B   │ 主色  │
│  secondary          │ #4338CA   │ 强调  │
│  accent / CTA       │ #22C55E   │ 播放  │
│  background         │ #0F0F23   │ 背景  │
│  surface            │ #1A1A2E   │ 卡片  │
│  surfaceContainer   │ #252540   │ 容器  │
│  onBackground       │ #F8FAFC   │ 主文字│
│  onSurface          │ #E2E8F0   │ 副文字│
│  onSurfaceVariant   │ #94A3B8   │ 辅助  │
│  error              │ #EF4444   │ 错误  │
└─────────────────────┴───────────┴───────┘
```

### 8.3 字体

| 用途 | 字体 | 字重 | 场景 |
|------|------|------|------|
| 标题/品牌 | Righteous | 400 | App 标题、播放页歌名 |
| 正文 | Poppins | 300-700 | 列表、按钮、描述文字 |
| 数字/时间 | Poppins Mono | 500 | 播放时间、码率 |

### 8.4 间距与圆角

- 页面内边距：16dp (移动端) / 24dp (桌面端)
- 卡片圆角：12dp
- 按钮圆角：8dp（普通）/ 全圆（播放按钮）
- 列表项高度：64dp
- 网格间距：12dp

### 8.5 关键组件规格

#### MiniPlayer（底部迷你播放条）
```
高度: 64dp
布局: [封面 48x48] [歌名+艺术家] [播放/暂停] [下一首]
背景: surfaceContainer + 顶部 0.5dp 分割线
点击: 展开为全屏播放页
```

#### PlayerScreen（全屏播放页）
```
布局 (移动端):
  ┌──────────────────┐
  │    ← 收起按钮     │
  │                  │
  │   ┌──────────┐   │
  │   │          │   │
  │   │  封面图   │   │
  │   │ 280x280  │   │
  │   └──────────┘   │
  │                  │
  │   歌名 (20sp)    │
  │   艺术家 (14sp)  │
  │                  │
  │   ━━━━●━━━━━━━   │  进度条 (accent)
  │   1:23    3:45   │
  │                  │
  │  🔀  ⏮  ▶  ⏭  🔁 │  控制按钮
  │                  │
  │  ♡    📋    ⋮    │  收藏/队列/更多
  └──────────────────┘

布局 (桌面端):
  左侧 40%: 大封面图
  右侧 60%: 歌曲信息 + 控制 + 队列列表
```

#### SearchScreen（搜索页）
```
顶部: 搜索框 (TextField + 清除按钮)
结果分组:
  - 艺术家 (横向滚动卡片)
  - 专辑 (横向滚动卡片)
  - 歌曲 (纵向列表)
空状态: 搜索图标 + "搜索歌曲、专辑或艺术家"
```

#### 主导航
```
移动端: BottomNavigationBar
  [首页] [音乐库] [搜索] [设置]

桌面端: 左侧 NavigationRail (宽度 72dp)
  [首页] [音乐库] [搜索] [播放列表] [设置]
```

---

## 10. 实现状态说明 (2026-02-27 更新)

> 本节记录规划文档与实际实现之间的偏差，便于后续开发参考。

### 10.1 Phase 1 完成状态

| 规划项 | 实际状态 | 说明 |
|--------|---------|------|
| 项目搭建 + 依赖配置 | ✅ 完成 | |
| Subsonic API 客户端 | ✅ 完成 | 15 个端点全部在 subsonic_client.dart 中实现 |
| 数据模型 | ✅ 完成 | Song, Album, Artist, ArtistDetail, Playlist |
| just_audio 播放 | ✅ 完成 | AudioPlayerService 168 行 |
| audio_service 后台播放 | ✅ 完成 | NavidromeAudioHandler 已补全 |
| 登录页 | ✅ 完成 | 服务器配置 + 连接测试 |
| 首页 | ✅ 完成 | 最近添加专辑网格 + 专辑详情弹窗 |
| 迷你播放条 | ✅ 完成 | 封面 + 歌曲信息 + 播放控制 |

### 10.2 目录结构偏差

以下规划中的文件/目录 **尚未创建**：

| 规划路径 | 状态 | 说明 |
|----------|------|------|
| `api/endpoints/` | 未创建 | API 端点全部集中在 subsonic_client.dart |
| `api/models/server_info.dart` | 未创建 | |
| `player/queue_manager.dart` | 未创建 | 队列逻辑内嵌在 AudioPlayerService |
| `providers/player_provider.dart` | 未创建 | 全部 Provider 集中在 providers.dart |
| `providers/library_provider.dart` | 未创建 | Phase 2 实现 |
| `providers/search_provider.dart` | 未创建 | Phase 2 实现 |
| `providers/settings_provider.dart` | 未创建 | Phase 2 实现 |
| `ui/screens/library/` | 未创建 | Phase 2 实现 |
| `ui/screens/album_detail/` | 未创建 | 当前用 BottomSheet 替代 |
| `ui/screens/player/` | 未创建 | Phase 2 实现 |
| `ui/screens/search/` | 未创建 | Phase 2 实现 |
| `ui/screens/playlists/` | 未创建 | Phase 2 实现 |
| `ui/screens/settings/` | 未创建 | Phase 2 实现 |
| `ui/widgets/album_card.dart` | 未创建 | 当前为 HomeScreen 内部私有类 |
| `ui/widgets/artist_card.dart` | 未创建 | Phase 2 实现 |
| `ui/theme/colors.dart` | 未创建 | 颜色定义内嵌在 app_theme.dart |
| `data/` | 未创建 | drift/SQLite 未引入 |

### 10.3 依赖偏差

| 规划依赖 | pubspec.yaml 状态 | 说明 |
|----------|-------------------|------|
| drift | 未添加 | Phase 2 引入 |
| sqlite3_flutter_libs | 未添加 | 随 drift 引入 |
| palette_generator | 未添加 | Phase 3 引入 |
| build_runner | 未添加 | Phase 2 引入 |
| riverpod_generator | 未添加 | Phase 2 引入 |
| go_router | ✅ 已添加 | 但未使用，Phase 2 启用 |

### 10.4 已知问题

- 密码以明文存储在 SharedPreferences 中
- HomeScreen 中 `_AlbumCard` 直接使用 `Image.network` 而非 `CoverArt` 组件
- MiniPlayer 也直接使用 `Image.network` 而非 `CoverArt` 组件
- Android applicationId 仍为 `com.example.navidrome_player`
- 无 CI/CD 配置
- 无 release 签名配置
