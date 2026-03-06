# 功能特性总览

Navidrome Player 的开发分为四个阶段，从基础播放到高级特性逐步推进。

## 平台功能文档

- [PC 端功能文档](../navidrome-player-prd-pc.md)
- [移动端功能文档](../navidrome-player-prd-mobile.md)
- [统一版 PRD](../navidrome-player-prd.md)

## 阶段概览

| 阶段 | 名称 | 功能数 | 状态 |
|------|------|--------|------|
| Phase 1 | 能听 | 8 | ✅ 完成 |
| Phase 2 | 好用 | 11 | 🟡 进行中 |
| Phase 3 | 好看 | 6 | 🟡 进行中 |
| Phase 4 | 完善 | 7 | 🟡 进行中 |

## Phase 1: 能听

基础播放能力，让应用可以连接 Navidrome 并播放音乐。

- 项目搭建与依赖配置
- Subsonic API 客户端（15 个端点）
- 数据模型定义（Song, Album, Artist, Playlist）
- 歌曲列表获取与展示
- just_audio 音频播放
- 基本播放控制（播放/暂停/上下曲/随机/循环）
- 基础 UI（登录页 + 首页 + 迷你播放条）
- 平台权限配置（Android + macOS）

详见 [Phase 1 文档](./phase1-playback.md)

## Phase 2: 好用

完整的应用功能，让日常使用体验流畅。当前已有主导航、音乐库、搜索、播放器、播放列表、收藏、设置等基础实现。

- 后台播放（通知栏/锁屏控制）
- 主导航框架（BottomNav / NavigationRail）
- 艺术家浏览、专辑浏览、专辑详情页
- 搜索功能
- 全屏播放页
- 播放队列 UI
- 播放列表管理
- 收藏 UI
- 设置页

详见 [Phase 2 文档](./phase2-usability.md)

## Phase 3: 好看

视觉体验提升，让应用赏心悦目。当前已具备播放器歌词、封面取色、部分动效与响应式布局基础。

- 完整播放页（大封面 + 进度条 + 控制）
- 深色/浅色主题完善
- 封面取色动态主题
- 歌词显示
- 过渡动画
- 响应式布局

详见 [Phase 3 文档](./phase3-polish.md)

## Phase 4: 完善

高级特性，提升专业度和完整度。当前已落地基础下载、Scrobble、音质选择、快捷键与多服务器支持，仍有完善空间。

- 离线缓存
- 收藏同步
- Scrobble 统计
- 音质选择
- 均衡器
- 键盘快捷键
- 多服务器支持

详见 [Phase 4 文档](./phase4-advanced.md)
