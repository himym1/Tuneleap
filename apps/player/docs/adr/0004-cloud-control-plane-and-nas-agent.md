# ADR-0004: Cloud control plane + NAS import agent

- Status: Accepted and implemented
- Date: 2026-07-29
- Implemented: 2026-07-30
- Supersedes: single companion backend on NAS `:8503`

## Context

The original `navidrome-backend` combined public music proxying, recommendations, private app updates, NAS file writes, and direct `navidrome.db` access. That topology coupled internet-facing work to home storage and made one API Key protect unrelated trust boundaries.

The product requires:

- Public search, recommendation, authentication, and update delivery.
- Local import/delete operations that can safely access NAS storage.
- A Flutter client that does not merge multiple online source result sets.
- Recommendation filtering that excludes songs already present in the NAS library without mounting NAS data on the public server.

## Decision

### Three projects

| Project | Role | Runtime data |
|---|---|---|
| `navidrome_player` | Flutter client | local preferences and secure storage |
| `navidrome-cloud` | Public control plane | Postgres |
| `navidrome-nas-agent` | Local import/delete/library agent | NAS music volume and `navidrome.db` |

### Cloud boundary

`navidrome-cloud` owns:

- First-success online music search.
- Playback URL, cover, and lyric resolution.
- Recommendation sessions, candidates, profile, feedback, and library exclusion.
- Account and Refresh Token APIs.
- Private update metadata and artifact downloads.

Cloud does not mount NAS music storage and does not open `navidrome.db`.

### NAS boundary

`navidrome-nas-agent` owns:

- `/v1/nas/import`
- `/v1/songs/delete`
- library identity reads used by Cloud recommendation filtering
- local Navidrome scan/file/database integration

The NAS Agent does not expose public search, authentication, recommendation state, or update artifacts.

### Search semantics

Cloud adapters use ordered failover / first-success. One query returns one normalized result set from the first non-empty successful source. Flutter does not concatenate source lists.

### Credentials

| Secret | Scope |
|---|---|
| Navidrome username/password | Subsonic only |
| Cloud user Access/Refresh Token | App search, recommendations, auth, updates |
| Cloud server API Key | Operations and server-side release verification only |
| NAS Agent Key | NAS import/delete |

The Cloud server API Key stays in the Cloud environment and is never provisioned to Flutter. The App obtains Bearer tokens through Cloud register/login/refresh. NAS Agent uses an independent LAN credential.

### Client configuration

The App stores these endpoints independently:

- Navidrome URL
- Cloud URL (`backendUrl` compatibility field)
- NAS Agent URL

When NAS Agent URL is omitted, the App infers the Navidrome host on LAN port `8504`. Retired or empty Cloud URLs resolve to the production HTTPS Origin. Refresh Tokens are stored in platform secure storage; Access Tokens remain in memory.

### Private updates

Release files are published to `/opt/navidrome-cloud/releases` on the Cloud host (`REMOTE_HOST`) and mounted read-only at `/app/releases`. The App uses its Cloud Bearer token to check `https://player.himym.us.ci/version.json`, downloads from the same Origin under `/releases/`, and verifies SHA-256 before opening the installer.

## Production deployment

| Component | Production location |
|---|---|
| Cloud | VPS `/opt/navidrome-cloud`, loopback `8600`, Cloudflare Tunnel HTTPS |
| Postgres | Same-host Docker network / loopback only |
| NAS Agent | Home NAS container, LAN `http://<nas-lan-ip>:8504` |
| Navidrome | Home NAS |

Cloud reaches the NAS Agent only through the restricted private mapping. Public access to `5432`, `8504`, and `8600` is blocked.

## Migration result

- Cloud runtime state migrated from recommendation SQLite to Postgres.
- Cloud obtains NAS library identities from the NAS Agent.
- Flutter routes Cloud requests through user Bearer tokens and NAS operations through a separate LAN key.
- The monolithic `navidrome-backend:8503`, its deployment directory, local source checkout, images, and migration backup were retired and deleted.
- Private update publishing moved from NAS to Cloud.

## Consequences

- Public control-plane availability no longer depends on mounting the NAS database or music volume.
- Import/delete remain available only where NAS storage is reachable.
- Endpoint configuration is explicit and testable.
- New music providers remain adapters behind a stable Cloud API.
- Release publishing must complete artifact checksum validation before replacing `version.json`.

## References

- [System architecture](../architecture.md)
- [Private update release](../release.md)
- [ADR-0001 multi-server session isolation](./0001-multi-server-session-isolation.md)
- [ADR-0003 deterministic online recommendation](./0003-deterministic-online-recommendation-algorithm.md)
