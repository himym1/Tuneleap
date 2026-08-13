# 音跃 Agent Rules

## Product

- User-facing name: 音跃. English: Yinyue. Repo: `yinyue`.
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

- Player: `make player-analyze` and `make player-test` from the repo root, or the same commands inside `apps/player`.
- Cloud tests need disposable Postgres (`TEST_DATABASE_URL`). Do not point smoke scripts at production.
- NAS Agent tests must use disposable directories, never the production music volume.

## Security

- Never commit `.env`, API keys, JWT secrets, NAS Agent keys, Navidrome passwords, or `navidrome.db`.
- Do not log tokens, passwords, or full media URLs with credentials.
