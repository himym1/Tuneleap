# Phase 2: 好用 — 完整功能

> 状态：🔲 未开始 | 模块数：11

## 概述

Phase 2 的目标是让应用具备完整的日常使用能力：导航、浏览、搜索、播放列表、设置。

## 功能模块

### 1. 后台播放

- 目标：应用切到后台时继续播放，通知栏/锁屏显示控制
- 关键文件：`lib/player/audio_handler.dart`
- 依赖：audio_service, just_audio
- 交互流程：播放歌曲 → NavidromeAudioHandler 接管 → 系统通知栏显示 → 锁屏控制

### 2. 主导航框架

- 目标：统一的应用导航结构，移动端底部导航，桌面端侧边导航
- 关键文件：新建 `lib/ui/screens/shell/app_shell.dart`
- 依赖：go_router (ShellRoute)
- 交互流程：
  - 移动端：BottomNavigationBar [首页, 音乐库, 搜索, 设置]
  - 桌面端：NavigationRail (72dp) [首页, 音乐库, 搜索, 播放列表, 设置]
  - MiniPlayer 作为全局 persistent widget

### 3. 艺术家浏览

- 目标：按字母索引浏览所有艺术家，点击进入艺术家详情
- 关键文件：新建 `lib/ui/screens/library/artists_screen.dart`
- API 接口：`getArtists` → 字母索引分组列表
- 交互流程：字母索引侧边栏 → 点击字母跳转 → 点击艺术家 → 艺术家详情（专辑列表）

### 4. 专辑浏览

- 目标：网格展示专辑，支持排序（最新/最常播放/随机/字母）
- 关键文件：新建 `lib/ui/screens/library/albums_screen.dart`
- API 接口：`getAlbumList2` (type, size, offset)
- 交互流程：排序选择 → 专辑网格（无限滚动） → 点击专辑 → 专辑详情页

### 5. 专辑详情页

- 目标：独立页面展示专辑信息和歌曲列表（替代当前 BottomSheet）
- 关键文件：新建 `lib/ui/screens/album_detail/album_detail_screen.dart`
- API 接口：`getAlbum` → 专辑信息 + 歌曲列表
- 交互流程：大封面 + 专辑名/艺术家 → 歌曲列表 → 点击播放 → 全部播放/随机播放

### 6. 搜索功能

- 目标：全文搜索艺术家、专辑、歌曲
- 关键文件：新建 `lib/ui/screens/search/search_screen.dart`
- API 接口：`search3` (query, artistCount, albumCount, songCount)
- 交互流程：搜索框输入 → 防抖 300ms → 结果分组展示（艺术家/专辑/歌曲）

### 7. 全屏播放页

- 目标：沉浸式播放体验，大封面、进度条、完整控制
- 关键文件：新建 `lib/ui/screens/player/player_screen.dart`
- 交互流程：
  - 点击 MiniPlayer 展开 → 全屏播放页（Hero 动画）
  - 移动端：大封面 + 歌曲信息 + 进度条 + 控制按钮 + 收藏/队列
  - 桌面端：左侧 40% 大封面，右侧 60% 信息 + 控制 + 队列

### 8. 播放队列 UI

- 目标：查看和管理当前播放队列
- 关键文件：新建 `lib/ui/widgets/queue_sheet.dart`
- 交互流程：播放页点击队列图标 → BottomSheet 展示队列 → 拖拽排序 → 滑动删除

### 9. 播放列表管理

- 目标：查看、创建、编辑播放列表
- 关键文件：新建 `lib/ui/screens/playlists/playlists_screen.dart`
- API 接口：`getPlaylists`, `getPlaylist`
- 交互流程：播放列表列表 → 点击进入详情 → 歌曲列表 → 播放/添加到队列

### 10. 收藏 UI

- 目标：收藏/取消收藏歌曲、专辑、艺术家，查看收藏列表
- API 接口：`star`, `unstar`
- 交互流程：长按或点击心形图标 → 调用 star/unstar API → UI 状态更新

### 11. 设置页

- 目标：应用配置管理（服务器、主题、缓存、关于）
- 关键文件：新建 `lib/ui/screens/settings/settings_screen.dart`
- 交互流程：
  - 服务器管理：查看/修改/断开连接
  - 主题选择：跟随系统/浅色/深色
  - 缓存管理：查看缓存大小，清除缓存
  - 关于：版本号、开源许可
