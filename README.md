# Navidrome Player

一个基于 Flutter 的 Navidrome 音乐播放器客户端，支持 Android 和 macOS 平台。

> 项目灵感来源于 [音流 (Stream Music)](https://music.aqzscn.cn/)，专注于 Navidrome/Subsonic 协议的轻量级开源实现。

## 截图

<!-- TODO: 添加应用截图 -->
| 登录页 | 首页 | 播放器 |
|--------|------|--------|
| 待添加 | 待添加 | 待添加 |

## 功能特性

### 已实现 (Phase 1: 能听)

- Subsonic API 客户端（认证、浏览、搜索、收藏、scrobble）
- 音频播放（just_audio 引擎，播放/暂停/上下曲/随机/循环）
- 后台播放支持（audio_service 通知栏/锁屏控制）
- 登录页（服务器配置 + 连接测试）
- 首页（最近添加专辑网格 + 专辑详情弹窗）
- 迷你播放条（封面 + 歌曲信息 + 播放控制）
- 深色/浅色主题（Material 3，跟随系统）

### 规划中

- **Phase 2 好用**: 主导航框架、艺术家/专辑浏览、搜索、全屏播放页、播放列表、设置
- **Phase 3 好看**: 完整播放页、封面取色主题、歌词显示、动画、响应式布局
- **Phase 4 完善**: 离线缓存、scrobble 统计、音质选择、均衡器、键盘快捷键

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.38 / Dart 3.10 |
| 状态管理 | Riverpod 3.x |
| 音频引擎 | just_audio + audio_service |
| 网络请求 | dio 5.x |
| 图片缓存 | cached_network_image |
| 路由 | go_router（Phase 2 启用） |
| 窗口管理 | window_manager (macOS) |
| 本地存储 | shared_preferences |
| 设计系统 | Material 3 |

## 快速开始

### 环境要求

- Flutter 3.38+
- Dart 3.10+
- Android SDK（Android 开发）
- Xcode 15+（macOS 开发）
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
```

### 配置服务器

启动应用后在登录页输入：
- 服务器地址（如 `http://192.168.1.100:4533`）
- 用户名和密码

应用会自动通过 Subsonic API ping 接口验证连接。

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── app.dart                     # MaterialApp 配置 + 路由
├── api/
│   ├── subsonic_client.dart     # Subsonic API 客户端 (15 个端点)
│   └── models/                  # 数据模型 (Song, Album, Artist, Playlist)
├── player/
│   ├── audio_player_service.dart # 音频播放服务 (just_audio 封装)
│   └── audio_handler.dart       # 后台播放 Handler (audio_service)
├── providers/
│   └── providers.dart           # Riverpod 全局 Provider
├── ui/
│   ├── screens/
│   │   ├── home/                # 首页
│   │   └── login/               # 登录页
│   ├── widgets/                 # 通用组件 (CoverArt, MiniPlayer, SongTile)
│   └── theme/                   # 主题定义
└── utils/                       # 工具函数
```

## 开发状态

| 阶段 | 名称 | 状态 | 说明 |
|------|------|------|------|
| Phase 1 | 能听 | ✅ 完成 | 基础播放功能，19 个文件，1370 行 |
| Phase 2 | 好用 | 🔲 未开始 | 完整导航、浏览、搜索、播放列表 |
| Phase 3 | 好看 | 🔲 未开始 | 视觉体验、歌词、动画 |
| Phase 4 | 完善 | 🔲 未开始 | 离线、高级特性 |

## 文档

完整文档请查看 [docs/](./docs/README.md)。

## 许可证

<!-- TODO: 选择并添加许可证 -->
