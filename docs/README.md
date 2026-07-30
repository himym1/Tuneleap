# Navidrome Player 文档中心

这里维护当前产品、架构、开发和发布文档。已完成任务的临时计划、证据草稿和旧 `navidrome-backend` 操作手册不再保留在主文档树中。

## 首选入口

- [项目介绍](./intro.md)
- [系统架构](./architecture.md)
- [开发环境与验证](./development-guide.md)
- [私有更新发布](./release.md)
- [产品完整功能文档](./navidrome-player-prd.md)

## 架构决策

- [ADR-0001 多服务器会话隔离](./adr/0001-multi-server-session-isolation.md)
- [ADR-0002 在线推荐管线（已由 0003 取代）](./adr/0002-verified-online-recommendation-pipeline.md)
- [ADR-0003 确定性在线推荐算法](./adr/0003-deterministic-online-recommendation-algorithm.md)
- [ADR-0004 Cloud 控制面 + NAS Agent](./adr/0004-cloud-control-plane-and-nas-agent.md)

ADR 记录决策演进。已被取代的 ADR 只作为历史依据，不代表当前实现。

## 专题指南

- [Subsonic API](./guides/subsonic-api.md)
- [Riverpod 状态管理](./guides/state-management.md)
- [音频播放架构](./guides/audio-playback.md)
- [平台适配](./guides/platform-adaptation.md)
- [Pencil 设计稿管理](./designs/pencil/README.md)

## 产品资料

- [统一 PRD](./navidrome-player-prd.md)
- [PC PRD](./navidrome-player-prd-pc.md)
- [移动端 PRD](./navidrome-player-prd-mobile.md)
- [功能规格](./features/README.md)
