# 项目介绍

## 项目背景

Navidrome Player 是一个面向 [Navidrome](https://www.navidrome.org/) 自建音乐服务的跨平台播放器客户端。

Navidrome 是一个开源的音乐流媒体服务器，兼容 Subsonic API 协议。虽然已有多款第三方客户端（如音流 Stream Music、Symfonium、Subtracks 等），但大多数要么闭源、要么功能过于复杂。本项目旨在提供一个**轻量、开源、专注 Navidrome** 的播放器方案。

## 设计理念

参考 [音流 (Stream Music)](https://music.aqzscn.cn/) 的产品设计，但在以下方面有所不同：

| 维度 | 音流 | Navidrome Player |
|------|------|------------------|
| 开源 | 闭源 | 开源 |
| 服务端 | Subsonic/Navidrome/Jellyfin/Emby/Plex/AudioStation | 仅 Navidrome (Subsonic API) |
| 平台 | Android/iOS/macOS/Windows/TV/CarPlay | Android + macOS |
| 音频引擎 | media_kit (MPV) | just_audio |
| 商业模式 | 免费 + 付费会员 | 完全免费开源 |
| 复杂度 | 功能丰富，支持多服务端 | 轻量简洁，专注核心体验 |

## 核心目标

按优先级排列：

- **P0 能听**: 连接 Navidrome，浏览音乐库，播放歌曲 ✅
- **P1 好用**: 完整导航、搜索、播放列表、后台播放
- **P2 好看**: 精致 UI、歌词、动画、响应式布局
- **P3 完善**: 离线缓存、scrobble、音质选择、快捷键
