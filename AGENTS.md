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

- 仅在发布或远程运维任务中读取 [远程运维目标](docs/remote-operations.md)。操作前同时确认 SSH alias、remote dir、服务归属及授权范围；文档不授予执行权限，不读取或记录秘密值。

## 注释语言

- 新增或修改注释（含文档注释）默认简体中文，保留必要技术术语、标识符、命令、协议字段与工具固定注释；仅按需调整相关代码的注释，不批量翻译。用户或外部规范另有要求时从其要求。

## Git 提交说明

- 提交使用 Conventional Commits：`<type>(<scope>): <中文描述>`；scope 用实际模块英文名，无明确模块时省略。type 限 `feat`、`fix`、`refactor`、`perf`、`docs`、`test`、`build`、`ci`、`chore`、`revert`。标题准确描述差异，保留必要技术术语，不用泛称或 emoji。
- 简单改动只写标题；复杂改动说明原因、主要变化及兼容性。破坏性变更用 `!` 和正文 `BREAKING CHANGE:` 说明影响与迁移方式。
- 仅约束后续提交，不改写历史；Git 自动生成的合并/撤销说明可保留。提交、推送仍需相应授权。
