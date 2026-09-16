# 音跃 Agent Rules

## Product

- User-facing name: 音跃. English: Tuneleap. Repo: `himym1/Tuneleap`.
- This is one product and three deployables. Do not collapse Cloud and NAS Agent into one process.
- Navidrome/Subsonic is an external library server. Do not treat this repository as a Navidrome fork.
- Android applicationId `com.himym.player` and production host paths stay unchanged unless the user explicitly asks to migrate deploy.

## Layout

```text
apps/player/              Flutter client
services/cloud/           Public control plane
services/nas-agent/       LAN import/delete/library agent
contracts/                Shared API notes and identity fixtures
docs/architecture.md      Canonical topology
```

## Runtime boundaries

- `services/cloud` must not mount music volumes and must not open `navidrome.db`.
- `services/cloud` Dockerfile may copy only `services/cloud/**`. Never copy `services/nas-agent` into the Cloud image.
- `services/nas-agent` must not implement public search, product auth, recommendations state, or private updates.
- `apps/player` talks to three endpoints with three credential planes: Subsonic password, Cloud Bearer tokens, NAS Agent Key.
- Cloud server `API_KEY` stays in the Cloud environment. Never put it in Flutter, fixtures, logs, or command output.

## Contracts

- Cloud and NAS Agent keep separate HTTP APIs. See `services/cloud/docs/API.md` and `services/nas-agent/docs/API.md`.
- Recommendation library blocking depends on identical weak identities. When changing title/artist normalization, update:
  - `apps/player/lib/utils/song_identity.dart`
  - `services/cloud/app/services/recommendation_identity.py`
  - `services/nas-agent/app/services/recommendation_identity.py`
  - `contracts/identity/cases.v1.json`
- Prefer adding a failing identity case to `contracts/` before changing algorithms.

## Verification

- Coding tasks authorize maintaining necessary tests and running focused, low-risk local unit tests, analysis, and necessary local builds after checking script side effects. Documentation, prompt, and comment-only changes normally need only readback and diff review.
- Database/container tests or setup, remote smoke requests, real accounts/data, device installation, release scripts, and full or substantially costly checks require explicit authorization. Use synthetic data and disposable local paths for ordinary checks; report results without automatically checking every component.
- Player: run `make player-analyze` and `make player-test` from the repository root; these targets are defined in the root `Makefile`.
- Cloud tests need disposable Postgres (`TEST_DATABASE_URL`). Do not point smoke scripts at production.
- NAS Agent tests must use disposable directories, never the production music volume.

## Security

- Never commit `.env`, API keys, JWT secrets, NAS Agent keys, Navidrome passwords, or `navidrome.db`.
- Do not log tokens, passwords, or full media URLs with credentials.

## 远程 SSH 目标

- `dmit`：Tuneleap Cloud VPS 和私有更新发布主机；`apps/player/scripts/deploy-private-update.sh` 默认发布到 `dmit:/opt/navidrome-cloud/releases`。
- `himym`：家庭 NAS，运行 `services/nas-agent` 和 Navidrome；Cloud 通过受限私有通路访问 NAS Agent。
- 涉及发布或远程运维时必须同时确认 SSH alias 和 remote dir；不要把凭据、私钥、令牌或其他 secret value 写入项目文档。

## 注释语言

- 新增或修改代码注释默认使用简体中文，包括文档注释。
- 保留必要的英文技术术语、标识符、命令、协议字段及工具要求的固定注释。
- 不为统一语言批量翻译已有注释；修改相关代码时按需调整。
- 用户明确要求英文，或文件必须遵循外部规范时，以该要求为准。
## Git 提交说明

- 使用 Conventional Commits：`<type>(<scope>): <中文描述>`；无明确模块时省略 `(scope)`。
- `type` 使用 `feat`、`fix`、`refactor`、`perf`、`docs`、`test`、`build`、`ci`、`chore`、`revert`。
- `scope` 使用实际模块的英文名称；标题使用简体中文，保留必要的英文技术术语，不使用 emoji。
- 提交说明必须准确描述实际差异；避免使用“更新代码”“修复问题”“优化”等无法说明具体变化的标题。
- 简单改动只写标题；复杂改动在正文说明原因、主要变化和必要的兼容性影响。
- 破坏性变更使用 `!` 标记，并在正文用 `BREAKING CHANGE:` 说明影响及迁移方式。
- 只约束后续提交，不为统一格式改写历史；Git 自动生成的合并或撤销说明可保留。
