# ADR-0004: Cloud control plane + NAS import agent

- Status: Accepted
- Date: 2026-07-29
- Supersedes in part: local monorepo assumption that companion backend is same-host `:8503` only (see ADR-0001 migration note)

## Context

`navidrome_player` is a Flutter client for personal Navidrome libraries, with online search/import via a companion backend.

Today that companion is a single FastAPI process (`navidrome-backend` on NAS `himym:8503`) that:

1. Proxies a third-party music HTTP API shaped like Solara / gdstudio (`MUSIC_API_BASE_URL=https://music-api.gdstudio.xyz/api.php`).
2. Imports audio onto the NAS music volume and mutates `navidrome.db`.
3. Serves private app updates and recommendation state from the same process.

Problems:

- **Product coupling**: search/auth/update belong on the public internet; import/delete must touch local disks.
- **Upstream coupling**: the service is effectively a thin wrapper around one open upstream, not an owned control plane.
- **Search UX**: the Flutter client serial-searches multiple sources and merges lists; the desired product is “one query → one result set as soon as any upstream succeeds” (first-success), not multi-source dump.
- **OpenMusic** ([qq01-hub/openmusic](https://github.com/qq01-hub/openmusic)) was evaluated as a multi-room listen product. Its **Meting / custom music HTTP APIs** are useful as adapters only; its room/Socket/Redis stack is out of scope.

User direction (2026-07-29): stop wrapping an open project as the product; rebuild two servers; keep the Flutter app as the third project.

## Decision

### Three projects

| Project | Role | Runtime | Data |
|---|---|---|---|
| `navidrome_player` | Flutter client | existing | local prefs / secure storage |
| `navidrome-cloud` | Public control plane | FastAPI + Uvicorn | **Postgres** |
| `navidrome-nas-agent` | Local import/delete agent | FastAPI + Uvicorn | local volume + `navidrome.db`; optional tiny **SQLite** for agent-only state |

Do **not** introduce OpenMusic’s Express + Redis + Socket.IO stack for this player.

### Upstream music adapters (not product cores)

Cloud owns a music facade with pluggable adapters. Day-1 targets:

1. **Gdstudio / Solara-shaped API** (current upstream): `types=search|url|pic|lyric` style requests against configurable base URL(s). Historical default: `https://music-api.gdstudio.xyz/api.php`.
2. **Meting / OpenMusic-shaped API**: Meting-compatible query form and/or OpenMusic-style custom music endpoint templates (`server` + `type` + `id` / keyword), used only as HTTP clients.

Rules:

- No embedding or redistributing those projects as our service identity.
- Multi-upstream means **failover / first-success across adapters or mirrors**, not merging NetEase + Kuwo + JOOX result lists into one UI dump.
- Response may still carry `source` / `provider` metadata for playback URL resolution.

### Search semantics

`GET /v1/music/search`:

- Input: one user query (optional preferred source hint).
- Behavior: ordered failover or short race across upstreams.
- Output: **one** normalized song list from the first non-empty success.
- Empty everywhere → structured error (502/503), not a partial multi-source mashup.

Flutter must stop serial multi-source `addAll` search once cloud search is live.

### API sketch — cloud (`navidrome-cloud`)

Public HTTPS. Auth: app session / API key (evolve to register/login).

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | No NAS dependency |
| GET | `/v1/music/search` | First-success |
| GET | `/v1/music/url` | Playback URL via same adapter chain |
| GET | `/v1/music/cover` | |
| GET | `/v1/music/lyric` | |
| GET | `/version.json` | Private update metadata |
| GET | `/releases/{filename}` | Authenticated artifact download |
| POST | `/v1/auth/register` | New product capability |
| POST | `/v1/auth/login` | |
| POST | `/v1/auth/refresh` | |
| * | `/v1/recommendations/*` | Migrate later; keep contract versioned |

Cloud **does not** mount NAS music disks and **does not** open `navidrome.db`.

### API sketch — NAS agent (`navidrome-nas-agent`)

LAN / Tailscale / restricted tunnel only. Auth: **separate** `nas_agent_key` (not Navidrome password, not cloud user password).

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Local only |
| POST | `/v1/nas/import` | Download + tag write to music volume (evolves today’s `/v1/nas/download`) |
| POST | `/v1/songs/delete` | Delete files + Navidrome DB rows |
| POST | `/v1/nas/scan` | Optional trigger for Navidrome rescan |

NAS agent **does not** expose public search, login, or update APIs.

### Credentials (three secrets, not one)

| Secret | Used for |
|---|---|
| Navidrome username/password | Subsonic only |
| Cloud credential (`cloud_token` / API key → later user session) | Search, updates, recommendations, auth |
| `nas_agent_key` | Import / delete on NAS |

ADR-0001 already separated `backendUrl` / `backendApiKey` from Navidrome password; this ADR further splits **cloud** vs **nas-agent** endpoints so same-host `:8503` inference is no longer the long-term topology.

### Client configuration

App must configure independently:

- `navidromeUrl` (Subsonic)
- `cloudApiUrl`
- `nasAgentUrl` (may default for LAN, but must be overridable)

Import path preference:

1. App resolves metadata/URL from **cloud**.
2. App calls **nas-agent** to import (LAN best).
3. Optional later: cloud-mediated import for remote-only setups (bandwidth cost).

### Deployment

| Component | Where |
|---|---|
| `navidrome-cloud` | VPS + HTTPS |
| Private updates | Same VPS and/or Cloudflare in front (existing `player.himym.us.ci` pattern may move origin to VPS) |
| `navidrome-nas-agent` | himym NAS Docker; no public search port |
| Navidrome | Stays on NAS with music volume |

### Language / database

- **FastAPI** for both new servers (team already owns FastAPI companion code; Go/Rust deferred).
- **Postgres** on cloud for accounts, sessions, recommendations, audit.
- **SQLite** only for tiny agent-local state if needed; Navidrome’s DB remains Navidrome’s.
- Redis optional later (rate limit / short search cache), not Day-1 required.

## Alternatives rejected

| Option | Why rejected |
|---|---|
| Keep single `navidrome-backend` on NAS for all APIs | Couples public search/auth to home disk and home egress |
| Fork/embed OpenMusic server | Wrong product (rooms/chat); heavy Redis/Socket stack |
| Move import to VPS | VPS cannot own the music volume / `navidrome.db` without fragile mounts |
| Client multi-source merge search | Noisy UX; desired “有结果即可” is first-success |
| Rust/Go rewrite as default | Higher cost than FastAPI for this CRUD + HTTP proxy shape |

## Consequences

- Two new server repos (or clearly separated deployables) plus the Flutter app = **three active projects**.
- Existing `navidrome-backend` becomes a migration source / temporary bridge, not the long-term product name.
- Flutter search, backend URL inference, import, and update check need a staged cutover.
- Upstream ToS/stability risk remains; adapters isolate failure and allow dropping a provider without rewriting the app.
- Private update publishing pipeline must point at cloud origin after cutover.
- Recommendation store migrates from NAS SQLite to cloud Postgres (or remains temporarily on old backend until Phase recommendations).

## Migration phases (non-binding schedule)

0. This ADR + OpenAPI sketches frozen.
1. Cloud music facade with multi-upstream first-success (can still be tested against current clients via temporary URL).
2. Extract NAS agent (import/delete only).
3. Flutter: cloud + nas-agent wiring; remove multi-source merge search.
4. Auth + updates fully on cloud.
5. Retire monolithic `:8503` companion.

## References

- Current companion: `~/MyProject/navidrome-backend`
- Player dual media boundary: wiki `navidrome-player-dual-media-backend`
- OpenMusic upstream (adapter reference only): https://github.com/qq01-hub/openmusic
- Gdstudio-shaped upstream historically configured as `MUSIC_API_BASE_URL`
- Related ADRs: `0001-multi-server-session-isolation.md`, `0003-deterministic-online-recommendation-algorithm.md`

## Scaffold locations (2026-07-29)

- Cloud scaffold: `~/MyProject/navidrome-cloud` (docs under `docs/`, default port `8600`)
- NAS agent scaffold: `~/MyProject/navidrome-nas-agent` (docs under `docs/`, default port `8503`)
- Both are empty-implementation shells (`501` until filled); develop against each repo's `docs/DEVELOPMENT.md`.
