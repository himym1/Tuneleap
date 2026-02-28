# Planning Notes

**Session**: WFS-20260227-083208
**Created**: 2026-02-27T08:32:08Z

## User Intent (Phase 1)

- **GOAL**: 完善 navidrome_player 项目文档体系，参考《音流》(Stream Music) 项目，建立完整文档以指导应用开发
- **SCOPE**: 项目文档结构、功能规格说明、技术架构文档、开发指南；参考音流项目的功能特性和文档组织
- **KEY_CONSTRAINTS**: 现有 navidrome_player 项目，需要系统化文档支撑完整应用开发

---

## Context Findings (Phase 2)

- **CRITICAL_FILES**: PROJECT_PLAN.md, lib/api/subsonic_client.dart, lib/player/audio_player_service.dart, lib/player/audio_handler.dart, lib/app.dart
- **ARCHITECTURE**: Feature-based structure, Provider pattern, Service layer
- **CONFLICT_RISK**: low (greenfield documentation work)
- **PROJECT_STATE**: Phase 1 完成 (~25-30%)，Phase 2-4 未开始，19 个 Dart 文件共 1370 行
- **CONSTRAINTS**: audio_handler.dart 有编译错误；go_router 未使用；无 CI/CD；README 为模板
- **REFERENCE**: 音流项目使用 Docusaurus 文档框架，分 intro/features/services/guides/notes/versions 六大板块
- **DOCUMENTATION_GAPS**: 无 README、无 API 文档、无架构文档、无贡献指南、无 CHANGELOG、无 docs/ 目录
- **DEVELOPMENT_GAPS**: Phase 2 (导航框架/浏览页/播放页/搜索/播放列表/设置), Phase 3 (主题/歌词/动画), Phase 4 (离线/scrobble)

## Conflict Decisions (Phase 3)
(To be filled if conflicts detected)

## Consolidated Constraints (Phase 4 Input)
1. 现有 navidrome_player 项目，需要系统化文档支撑完整应用开发
2. [Context] Phase 1 已完成 (~25-30%)，PROJECT_PLAN.md 与实际实现有偏差需同步
3. [Context] audio_handler.dart 有编译错误，需修复后才能进入 Phase 2
4. [Context] 参考音流项目文档结构：intro/features/services/guides/notes/versions
5. [Context] 文档应同时服务于开发指导和用户使用两个目标
6. [Context] 优先建立文档体系，再以文档为蓝图推进 Phase 2-4 开发

---

## Task Generation (Phase 4)

**Completed**: 2026-02-27
**Tasks Generated**: 6 (IMPL-1 through IMPL-6)
**Execution Phases**: 3 phases (A: foundation+bugfix, B: core docs, C: feature+guide docs)
**Estimated Output**: ~18 new files, 3 modified files, ~1,780-2,240 lines

### Task Breakdown
- IMPL-1: docs/ 目录结构搭建 (P0, no deps)
- IMPL-2: README + intro + architecture (P0, depends IMPL-1)
- IMPL-3: API docs + plan sync + changelog (P0, depends IMPL-1)
- IMPL-4: 四阶段功能规格文档 (P1, depends IMPL-2)
- IMPL-5: 开发指南文档 (P1, depends IMPL-2)
- IMPL-6: audio_handler 修复 + routing note (P0, no deps)

---

## N+1 Context
### Decisions
| Decision | Rationale | Revisit? |
|----------|-----------|----------|
| Markdown docs over Docusaurus | 项目早期阶段，简单 Markdown 足够，降低维护成本 | Yes - Phase 3 时可考虑迁移到 Docusaurus |
| audio_handler 与文档并行修复 | 阻塞 Phase 2 开发，需尽早修复 | No |
| 文档结构参考音流六大板块 | 成熟的文档组织方式，适合音乐播放器项目 | No |
| go_router 保留但暂不迁移 | Phase 2 主导航框架时一并集成 ShellRoute | Yes - Phase 2 启动时 |
| 功能规格文档标注为规划参考 | 允许实现时灵活调整，避免文档成为束缚 | No |

### Deferred
- [ ] Docusaurus 搭建 - 当前使用纯 Markdown，Phase 3 时可考虑 (N+1)
- [ ] 多语言文档 (i18n) - 当前仅中文，未来可考虑英文 (N+2)
- [ ] CI/CD 文档自动部署 - 需先建立 CI/CD 流程 (N+2)
- [ ] API 文档自动生成 (dart doc) - Phase 2 代码稳定后考虑 (N+1)
- [ ] 贡献者指南 (CONTRIBUTING.md) - 当前为个人项目，开源时再添加 (N+2)
