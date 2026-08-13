# Cloud control plane

Public **control plane** for [音跃 player](../../apps/player): online music search, playback URL/lyric/cover resolution, private app updates, product auth, and recommendations.

Source path in this repo: `services/cloud`. Production directory is still `cloud-host:/opt/navidrome-cloud`.

## Architecture (ADR-0004)

| This service owns | This service must NOT |
|---|---|
| Multi-upstream music facade (first-success) | Mount NAS music disks |
| Private updates | Open `navidrome.db` |
| Register/login/refresh + recommendations | Import/delete library files |

Runtime state is stored in **Postgres**. SQLite files under `data/` are accepted only as one-time migration inputs.

Sibling service: [`nas-agent`](../nas-agent) for import/delete and read-only library identities.

Runtime split: [ADR-0004](../../apps/player/docs/adr/0004-cloud-control-plane-and-nas-agent.md). Product repo: [ADR-0005](../../docs/adr/0005-product-monorepo.md).

## Docs

| File | Purpose |
|---|---|
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Local development and module map |
| [docs/API.md](docs/API.md) | HTTP contract for Flutter / agents |
| [docs/UPSTREAMS.md](docs/UPSTREAMS.md) | gdstudio + Meting adapter notes |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | VPS / HTTPS / secrets |
| [docs/POSTGRES_MIGRATION.md](docs/POSTGRES_MIGRATION.md) | SQLite → Postgres runbook |

## Quick start

```bash
cd services/cloud
cp .env.example .env
# edit API_KEY, JWT_SECRET, POSTGRES_PASSWORD, DATABASE_URL
docker compose up -d --build
curl -fsS http://127.0.0.1:8600/health
```

- OpenAPI: `http://127.0.0.1:8600/docs`
- Search:

```bash
curl -H 'X-API-Key: <API_KEY>' \
  'http://127.0.0.1:8600/v1/music/search?q=hello&source=netease'
```

## Tests

Tests require a disposable Postgres database:

```bash
export TEST_DATABASE_URL='postgresql://navidrome:navidrome_test@127.0.0.1:55432/navidrome_cloud_test'
pytest -q
```

## Implemented

- Music MVP: gdstudio adapter, first-success facade, url/cover/lyric
- Optional Meting adapter and private updates
- Postgres product auth with JWT access/rotating refresh tokens
- Postgres recommendation sessions, leases, candidates, feedback, profile
- Optional NAS library blocking through `NAS_AGENT_URL`
- SlowAPI rate limits
