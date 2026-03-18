# 音跃 (Navidrome Player)

一个基于 Flutter 的 Navidrome 音乐播放器客户端，面向 Navidrome/Subsonic 协议，支持 Android、macOS 与 Windows。

> 项目灵感来源于 [音流 (Stream Music)](https://music.aqzscn.cn/)，专注于 Navidrome/Subsonic 协议的轻量级开源实现。

## 功能特性

- **Subsonic API 客户端** — 已接入认证、浏览、搜索、封面、歌词、scrobble、播放列表等基础接口
- **音频播放** — `just_audio` 引擎，支持播放/暂停/上下曲/随机/循环/音量/倍速
- **后台播放** — 已接入 `audio_service`，提供基础通知栏/锁屏控制能力
- **主导航框架** — 移动端 BottomNavigationBar / 桌面端 NavigationRail
- **音乐库浏览** — 已有艺术家/专辑/歌曲多维度浏览页面
- **专辑/艺术家详情** — 独立详情页已接入基础数据与播放入口
- **搜索** — 全局搜索艺术家、专辑、歌曲
- **全屏播放页** — 大封面、进度条、歌词、播放队列、倍速、音量，封面动态取色渐变背景
- **均衡器 (EQ)** — 7 频段均衡器，内置 6 种预设，设置自动持久化
- **播放历史与统计** — Scrobble 记录、播放统计卡片、最近播放列表
- **播放列表管理** — 已支持浏览、创建、删除；更多编辑能力待完善
- **收藏体系** — 已有歌曲/专辑/艺术家收藏页面与交互，稳定性仍需补强
- **下载管理** — 基础下载与离线回退能力，进度追踪与任务管理
- **多服务器支持** — 已支持多 Navidrome 实例的增删改切换
- **设置** — 主题切换、音质选择、均衡器、缓存管理、服务器信息等
- **应用更新检查** — 自动检测新版本并提示更新
- **安全存储** — 密码通过 `flutter_secure_storage` 加密存储
- **深色/浅色主题** — Material 3，跟随系统 / 手动切换

## 技术栈

| 类别 | 技术 |
| ---- | ---- |
| 框架 | Flutter 3.38 / Dart 3.10 |
| 状态管理 | Riverpod 3.x |
| 音频引擎 | just_audio + audio_service |
| 网络请求 | dio 5.x |
| 图片缓存 | cached_network_image |
| 封面取色 | palette_generator |
| 路由 | go_router |
| 窗口管理 | window_manager (macOS) |
| 本地存储 | shared_preferences + flutter_secure_storage |
| 外部链接 | url_launcher |
| 设计系统 | Material 3 |

## 快速开始

### 环境要求

- Flutter 3.38+
- Dart 3.10+
- Android SDK（Android 开发）
- Xcode 15+（macOS 开发）
- Visual Studio 2022+（Windows 开发）
- 一个运行中的 [Navidrome](https://www.navidrome.org/) 服务端

### 安装运行

```bash
# 克隆项目
git clone <repo-url>
cd navidrome_player

# 安装依赖
flutter pub get

# 运行 (Android)
flutter run -d android

# 运行 (macOS)
flutter run -d macos

# 运行 (Windows)
flutter run -d windows
```

### 配置服务器

启动应用后在登录页输入：

- 服务器地址（如 `http://192.168.1.100:4533`）
- 用户名和密码

应用会自动通过 Subsonic API ping 接口验证连接。

## 项目结构

```text
lib/
├── main.dart                        # 应用入口
├── app.dart                         # MaterialApp 配置 + go_router 路由
├── api/
│   ├── subsonic_client.dart         # Subsonic API 客户端
│   └── models/                      # 数据模型 (Song, Album, Artist, Playlist 等)
├── player/
│   ├── audio_player_service.dart    # 音频播放服务 (just_audio 封装)
│   └── audio_handler.dart           # 后台播放 Handler (audio_service)
├── services/
│   └── update_checker.dart          # 应用更新检查服务
├── providers/
│   ├── providers.dart               # 核心 Provider
│   ├── audio_providers.dart         # 音频相关 Provider
│   ├── server_config_provider.dart  # 服务器配置 Provider
│   ├── download_provider.dart       # 下载管理 Provider
│   ├── theme_provider.dart          # 主题 Provider
│   ├── starred_provider.dart        # 收藏 Provider
│   └── cover_color_provider.dart    # 封面取色 Provider
├── ui/
│   ├── screens/
│   │   ├── shell/                   # 主导航框架 (AppShell)
│   │   ├── home/                    # 首页
│   │   ├── login/                   # 登录页
│   │   ├── library/                 # 音乐库
│   │   ├── search/                  # 搜索
│   │   ├── player/                  # 全屏播放页
│   │   ├── album_detail/            # 专辑详情
│   │   ├── artist_detail/           # 艺术家详情
│   │   ├── playlists/               # 播放列表
│   │   ├── favorites/               # 收藏
│   │   ├── downloads/               # 下载管理
│   │   ├── settings/                # 设置
│   │   ├── multi_server/            # 多服务器管理
│   │   ├── audio_quality/           # 音质设置
│   │   └── scrobble/                # 播放记录
│   ├── widgets/                     # 通用组件 (CoverArt, MiniPlayer, SongTile, SongContextMenu)
│   └── theme/                       # 主题定义
├── data/
│   └── tables/                      # 本地数据表
└── utils/                           # 工具函数
```

## 文档

- 文档中心：[docs/README.md](./docs/README.md)
- 统一版 PRD：[docs/navidrome-player-prd.md](./docs/navidrome-player-prd.md)
- PC 端功能文档：[docs/navidrome-player-prd-pc.md](./docs/navidrome-player-prd-pc.md)
- 移动端功能文档：[docs/navidrome-player-prd-mobile.md](./docs/navidrome-player-prd-mobile.md)
- 设计稿：[docs/designs/pencil/README.md](./docs/designs/pencil/README.md)

## 许可证

本项目基于 [MIT License](./LICENSE) 开源。
