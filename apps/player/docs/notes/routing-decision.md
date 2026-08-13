# 路由方案决策

## 当前状态

项目 `pubspec.yaml` 中声明了 `go_router ^17.1.0` 依赖，但实际代码中 **未使用**。

当前路由方式：`app.dart` 中通过 `_loggedIn` 状态变量直接切换 `LoginScreen` 和 `HomeScreen`，使用 `MaterialApp.home` 属性。

## 决策原因

Phase 1（能听）阶段仅有两个页面（登录 + 首页），声明式路由的引入会增加不必要的复杂度。go_router 的价值在多页面导航场景下才能体现。

## Phase 2 迁移计划

进入 Phase 2（好用）阶段后，将引入 go_router 实现以下导航结构：

```
/login          → LoginScreen
/               → AppShell (BottomNav / NavigationRail)
  /home         → HomeScreen
  /library      → LibraryScreen (artists/albums/songs tabs)
  /search       → SearchScreen
  /playlists    → PlaylistsScreen
  /settings     → SettingsScreen
/album/:id      → AlbumDetailScreen
/player         → FullPlayerScreen (overlay)
```

关键设计：使用 `ShellRoute` 包裹主导航框架，`MiniPlayer` 作为全局 persistent widget。

## 参考

- PROJECT_PLAN.md 第 9.2 节：主导航框架规格
- go_router 文档：ShellRoute pattern
