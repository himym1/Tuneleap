# Implementation Plan

**Session**: WFS-20260227-083208
**Project**: navidrome_player - Flutter Navidrome 音乐播放器客户端
**Created**: 2026-02-27
**Status**: Planning Complete

---

## 1. Overview

### 1.1 Goal

完善 navidrome_player 项目文档体系，参考《音流》(Stream Music) 项目的文档和功能设计，建立完整文档以指导应用开发。同时修复阻塞 Phase 2 开发的编译错误。

### 1.2 Scope

- 建立 docs/ 目录结构（参考音流 Docusaurus 六大板块）
- 重写 README.md，创建项目介绍和架构文档
- 创建 Subsonic API 参考文档和开发指南
- 同步 PROJECT_PLAN.md 与实际实现状态
- 编写四阶段功能规格文档（Phase 1-4）
- 编写开发者技术指南（API/状态管理/音频/平台适配）
- 修复 audio_handler.dart 编译错误
- 创建 CHANGELOG.md

### 1.3 Current State

| Metric | Value |
|--------|-------|
| Dart 文件数 | 19 |
| 代码总行数 | 1370 |
| Phase 1 完成度 | ~25-30% |
| 文档文件数 | 1 (PROJECT_PLAN.md) |
| 编译状态 | audio_handler.dart 有错误 |

### 1.4 Constraints (from Planning Notes)

1. 现有 navidrome_player 项目，需要系统化文档支撑完整应用开发
2. Phase 1 已完成 (~25-30%)，PROJECT_PLAN.md 与实际实现有偏差需同步
3. audio_handler.dart 有编译错误，需修复后才能进入 Phase 2
4. 参考音流项目文档结构：intro/features/services/guides/notes/versions
5. 文档应同时服务于开发指导和用户使用两个目标
6. 优先建立文档体系，再以文档为蓝图推进 Phase 2-4 开发

---

## 2. Task Summary

| ID | Title | Type | Priority | Dependencies | Status |
|----|-------|------|----------|--------------|--------|
| IMPL-1 | Documentation Foundation - docs/ 目录结构搭建 | docs | P0 | none | pending |
| IMPL-2 | Core Documentation - 项目概述与架构文档 | docs | P0 | IMPL-1 | pending |
| IMPL-3 | Core Documentation - 技术规格与项目同步 | docs | P0 | IMPL-1 | pending |
| IMPL-4 | Feature Documentation - 四阶段功能规格文档 | docs | P1 | IMPL-2 | pending |
| IMPL-5 | Development Guides - 开发指南文档 | docs | P1 | IMPL-2 | pending |
| IMPL-6 | Bug Fix Prerequisites - audio_handler 修复与路由同步 | bugfix | P0 | none | pending |

**Total**: 6 tasks, 预计产出 ~20 个文件

---

## 3. Dependency Graph

```
IMPL-6 (bugfix, independent)
  └── No dependencies, can run in parallel with docs tasks

IMPL-1 (docs foundation)
  ├── IMPL-2 (README + intro + architecture) ─── depends on IMPL-1
  │   ├── IMPL-4 (feature docs) ─── depends on IMPL-2
  │   └── IMPL-5 (dev guides) ─── depends on IMPL-2
  └── IMPL-3 (API docs + plan sync + changelog) ── depends on IMPL-1
```

### Execution Order

**Phase A** (parallel): IMPL-1 + IMPL-6
**Phase B** (parallel, after IMPL-1): IMPL-2 + IMPL-3
**Phase C** (parallel, after IMPL-2): IMPL-4 + IMPL-5

---

## 4. Task Details

### IMPL-1: Documentation Foundation - docs/ 目录结构搭建

**Type**: docs | **Priority**: P0 | **Complexity**: Simple

**Deliverables**:
- 1 documentation root directory: `docs/`
- 6 subdirectories: features/, guides/, services/, notes/, versions/, assets/
- 1 index file: `docs/README.md`
- 1 sidebar navigation: `docs/_sidebar.md`

**Reference**: 音流项目 Docusaurus 六大板块 (intro/features/services/guides/notes/versions)

**Acceptance**:
- 6 subdirectories存在: `ls -d docs/*/ | wc -l = 6`
- Index 文件包含所有板块链接: `grep -c '\[' docs/README.md >= 6`

---

### IMPL-2: Core Documentation - 项目概述与架构文档

**Type**: docs | **Priority**: P0 | **Complexity**: Medium | **Depends on**: IMPL-1

**Deliverables**:
- README.md 重写 (从 17 行模板扩展到 ~120-150 行)
- docs/intro.md 创建 (~80-100 行)
- docs/architecture.md 创建 (~150-200 行)

**Key Content**:
- README.md 7 个章节: 项目描述, 截图占位, 功能特性, 技术栈, 快速开始, 项目结构, 开发状态
- architecture.md 4 层架构: UI Layer, State Layer (Riverpod), Service Layer, Data Layer
- architecture.md 需覆盖全部 19 个 Dart 文件的职责说明

**Acceptance**:
- README.md >= 100 行: `wc -l README.md >= 100`
- architecture.md 包含 4 层说明: `grep -c 'Layer' docs/architecture.md >= 4`

---

### IMPL-3: Core Documentation - 技术规格与项目同步

**Type**: docs | **Priority**: P0 | **Complexity**: Medium | **Depends on**: IMPL-1

**Deliverables**:
- docs/services/subsonic-api.md 创建 (~150-180 行)
- docs/development-guide.md 创建 (~100-120 行)
- PROJECT_PLAN.md 更新 (~15 处修正)
- CHANGELOG.md 创建 (~40-60 行)

**Key Content**:
- subsonic-api.md 覆盖 6 类 15 个 API 端点
- PROJECT_PLAN.md 同步 5 处关键偏差:
  1. go_router 声明但未使用
  2. audio_handler.dart 仅 32 行，不完整
  3. drift/sqlite 未在 pubspec.yaml 中
  4. palette_generator 未在 pubspec.yaml 中
  5. riverpod_generator/build_runner 未在 pubspec.yaml 中

**Acceptance**:
- API 文档覆盖 15 端点: `grep -c '###\|endpoint' docs/services/subsonic-api.md >= 15`
- PROJECT_PLAN.md 包含偏差说明: `grep -c 'incomplete\|unused\|diverge' PROJECT_PLAN.md >= 1`

---

### IMPL-4: Feature Documentation - 四阶段功能规格文档

**Type**: docs | **Priority**: P1 | **Complexity**: High | **Depends on**: IMPL-2

**Deliverables**:
- docs/features/README.md (功能总览, ~60-80 行)
- docs/features/phase1-playback.md (8 个已完成功能, ~80-100 行)
- docs/features/phase2-usability.md (11 个功能模块, ~200-250 行)
- docs/features/phase3-polish.md (6 个功能, ~100-120 行)
- docs/features/phase4-advanced.md (7 个功能, ~100-120 行)

**Feature Counts**:
- Phase 1 能听: 8 features (项目搭建, API客户端, 数据模型, 歌曲展示, 音频播放, 播放控制, 基础UI, 平台权限)
- Phase 2 好用: 11 modules (后台播放, 主导航, 艺术家浏览, 专辑浏览, 专辑详情, 搜索, 全屏播放, 播放队列, 播放列表, 收藏, 设置)
- Phase 3 好看: 6 features (完整播放页, 深色/浅色主题, 封面取色, 歌词, 动画, 响应式布局)
- Phase 4 完善: 7 features (离线缓存, 收藏, scrobble, 音质选择, 均衡器, 快捷键, 多服务器)

**数据来源**: PROJECT_PLAN.md section 9 (lines 248-432) 提供 Phase 2 详细规格

**Acceptance**:
- 5 个文件创建: `ls docs/features/*.md | wc -l = 5`
- Phase 2 覆盖 11 模块: `grep -c '^### ' docs/features/phase2-usability.md >= 11`

---

### IMPL-5: Development Guides - 开发指南文档

**Type**: docs | **Priority**: P1 | **Complexity**: Medium | **Depends on**: IMPL-2

**Deliverables**:
- docs/guides/subsonic-api.md (API 使用指南, ~120-150 行)
- docs/guides/state-management.md (Riverpod 模式, ~100-130 行)
- docs/guides/audio-playback.md (音频架构, ~100-130 行)
- docs/guides/platform-adaptation.md (平台适配, ~80-100 行)

**Key Content**:
- subsonic-api.md: token 认证流程, salt 生成, MD5 计算, 请求构造
- state-management.md: 4 个已有 Provider (sharedPreferences, serverConfig, subsonicClient, audioPlayerService)
- audio-playback.md: AudioPlayerService (168 行, 完整) vs NavidromeAudioHandler (32 行, 不完整)
- platform-adaptation.md: Android (网络/前台Service) + macOS (窗口/entitlements)

**Acceptance**:
- 4 个文件创建: `ls docs/guides/*.md | wc -l = 4`
- Provider 文档化: `grep -c 'Provider' docs/guides/state-management.md >= 4`

---

### IMPL-6: Bug Fix Prerequisites - audio_handler 修复与路由同步

**Type**: bugfix | **Priority**: P0 | **Complexity**: Medium

**Deliverables**:
- audio_handler.dart 修复 (从 32 行扩展到 ~100-120 行)
- docs/notes/routing-decision.md 创建 (~30-40 行)
- flutter analyze 通过 (0 errors)

**Missing Implementations** (audio_handler.dart):
- 6 个播放方法: play(), pause(), stop(), skipToNext(), skipToPrevious(), seek()
- 1 个状态广播: _broadcastState()
- 1 个队列管理: setQueue()
- 1 个转换工具: _songToMediaItem()

**Reference**: AudioPlayerService (lib/player/audio_player_service.dart, 168 行) 提供队列管理模式参考

**Acceptance**:
- 编译通过: `flutter analyze lib/player/audio_handler.dart` (0 errors)
- 方法实现: `grep -c 'Future.*play\|Future.*pause\|Future.*stop' lib/player/audio_handler.dart >= 3`
- 项目编译: `flutter analyze` (0 errors)

---

## 5. File Inventory

### New Files (18 files)

| File | Task | Lines (est.) |
|------|------|-------------|
| docs/README.md | IMPL-1 | ~40 |
| docs/_sidebar.md | IMPL-1 | ~30 |
| docs/intro.md | IMPL-2 | ~80-100 |
| docs/architecture.md | IMPL-2 | ~150-200 |
| docs/services/subsonic-api.md | IMPL-3 | ~150-180 |
| docs/development-guide.md | IMPL-3 | ~100-120 |
| CHANGELOG.md | IMPL-3 | ~40-60 |
| docs/features/README.md | IMPL-4 | ~60-80 |
| docs/features/phase1-playback.md | IMPL-4 | ~80-100 |
| docs/features/phase2-usability.md | IMPL-4 | ~200-250 |
| docs/features/phase3-polish.md | IMPL-4 | ~100-120 |
| docs/features/phase4-advanced.md | IMPL-4 | ~100-120 |
| docs/guides/subsonic-api.md | IMPL-5 | ~120-150 |
| docs/guides/state-management.md | IMPL-5 | ~100-130 |
| docs/guides/audio-playback.md | IMPL-5 | ~100-130 |
| docs/guides/platform-adaptation.md | IMPL-5 | ~80-100 |
| docs/notes/routing-decision.md | IMPL-6 | ~30-40 |

### Modified Files (2 files)

| File | Task | Changes |
|------|------|---------|
| README.md | IMPL-2 | Rewrite (17 -> ~120-150 lines) |
| PROJECT_PLAN.md | IMPL-3 | Update ~15 items to sync with actual state |
| lib/player/audio_handler.dart | IMPL-6 | Fix (32 -> ~100-120 lines) |

**Total estimated output**: ~1,600-2,100 lines of documentation + ~80 lines of Dart code

---

## 6. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| audio_service API 变更 | audio_handler 修复可能需适配新版 API | 检查 audio_service ^0.18.18 的 BaseAudioHandler 接口 |
| 文档与实际代码后续脱节 | 文档过时失去指导价值 | CHANGELOG.md 跟踪变更，Phase 2 开发同步更新文档 |
| Phase 2 规格过于详细 | 开发时可能偏离文档 | 文档标注为 "规划参考"，允许实现时灵活调整 |

---

## 7. Quality Gates

- [ ] **QG1**: docs/ 目录结构完整 (IMPL-1 complete)
- [ ] **QG2**: README.md 和架构文档可读 (IMPL-2 complete)
- [ ] **QG3**: PROJECT_PLAN.md 与代码同步 (IMPL-3 complete)
- [ ] **QG4**: 四阶段功能规格覆盖所有计划功能 (IMPL-4 complete)
- [ ] **QG5**: 开发指南可指导新贡献者 (IMPL-5 complete)
- [ ] **QG6**: flutter analyze 0 errors (IMPL-6 complete)

---

## 8. CCW Workflow Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Session Discovery | Complete | WFS-20260227-083208 |
| Phase 2: Context Gathering | Complete | 19 Dart files, 1370 lines analyzed |
| Phase 3: Conflict Resolution | Skipped | conflict_risk = low |
| Phase 4: Task Generation | Complete | 6 tasks generated |
| Phase 5: Execution | Pending | Ready for execution |
