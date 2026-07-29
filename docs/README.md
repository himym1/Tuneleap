# Navidrome Player 文档中心

欢迎来到 Navidrome Player 项目文档。本文档体系参考[音流 (Stream Music)](https://music.aqzscn.cn/) 项目的文档组织方式，分为六大板块。

## 文档导航

### [项目介绍](./intro.md)
项目概述、设计理念、支持的功能和平台。

### [功能特性](./features/)
四阶段功能规格文档，从基础播放到高级特性的完整规划。
- [Phase 1: 能听 — 基础播放](./features/phase1-playback.md)
- [Phase 2: 好用 — 完整功能](./features/phase2-usability.md)
- [Phase 3: 好看 — 视觉体验](./features/phase3-polish.md)
- [Phase 4: 完善 — 高级特性](./features/phase4-advanced.md)
- [PC 端功能文档](./navidrome-player-prd-pc.md)
- [移动端功能文档](./navidrome-player-prd-mobile.md)
- [产品完整功能文档（统一版）](./navidrome-player-prd.md)

### [服务适配](./services/)
Subsonic/Navidrome API 对接文档和服务端兼容性说明。
- [Subsonic API 参考](./services/subsonic-api.md)

### [开发指南](./guides/)
面向开发者的技术指南，涵盖 API 使用、状态管理、音频架构等。
- [Subsonic API 使用指南](./guides/subsonic-api.md)
- [状态管理 (Riverpod)](./guides/state-management.md)
- [音频播放架构](./guides/audio-playback.md)
- [平台适配](./guides/platform-adaptation.md)

### [架构决策 ADR](./adr/)
已接受的架构决策记录（不是开发排期）。
- [0001 多服务器会话隔离](./adr/0001-multi-server-session-isolation.md)
- [0002 在线推荐管线（已由 0003 取代）](./adr/0002-verified-online-recommendation-pipeline.md)
- [0003 确定性在线推荐算法](./adr/0003-deterministic-online-recommendation-algorithm.md)
- [0004 云端控制面 + NAS Agent](./adr/0004-cloud-control-plane-and-nas-agent.md)

### [开发笔记](./notes/)
技术决策记录、插件选型、架构演进等开发过程中的思考。
- [路由方案决策](./notes/routing-decision.md)

### [设计稿管理](./designs/pencil/README.md)
Pencil `.pen` 设计稿的目录规范、命名规则与导出流程。

### [版本记录](./versions/)
版本更新日志和发布说明。

## 快速开始

1. 阅读[项目介绍](./intro.md)了解项目背景
2. 查看[系统架构](./architecture.md)理解代码结构
3. 参考[开发指南](./development-guide.md)搭建开发环境
4. 浏览[功能特性](./features/)了解开发路线图
