# ADR-0005: 音跃产品仓

- Status: Accepted
- Date: 2026-08-13
- Complements: [ADR-0004](../../apps/player/docs/adr/0004-cloud-control-plane-and-nas-agent.md)

## Context

音跃是一个产品，原先拆成三个 Git 仓：`navidrome_player`、`navidrome-cloud`、`navidrome-nas-agent`。ADR-0004 把公网控制面和 NAS 写盘拆成两个进程，这个运行时边界仍然有效。

分仓的代价是跨端契约（尤其是推荐弱身份）和 AI 读代码都要切三个仓库。media-hub 用一个仓放一个控制面和两套客户端；音跃要对齐的是「一个产品一个仓」，不是「再合成一个 backend」。

## Decision

1. 使用一个 Git 仓 `himym1/Tuneleap`，目录为 `apps/player`、`services/cloud`、`services/nas-agent`。
2. 继续打三个产物、使用三套密钥、两份 Dockerfile。
3. 用户可见名保持「音跃」；英文名用 Tuneleap。仓库不再以 Navidrome 命名。
4. 生产部署路径、镜像名、`com.himym.player` 先不动。

## Consequences

- 一次检出就能读完整条搜 → 播 → 推荐 → 导入链路。
- Cloud 镜像构建上下文必须限制在 `services/cloud/`，避免把 NAS 写盘代码打进公网镜像。
- 旧的三个 GitHub 仓变成只读来源，直到明确归档。
- 身份算法仍可能漂移；用 `contracts/identity/` 做共享用例，而不是靠合仓自动一致。
