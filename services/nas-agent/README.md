# NAS agent

Local **NAS agent** for [音跃 player](../../apps/player). It imports online audio onto the music volume, writes tags/cover/lyrics, deletes tracks from disk plus `navidrome.db`, and can trigger a Navidrome scan.

Source path in this repo: `services/nas-agent`. Production directory is still `himym:/volume1/docker/navidrome-nas-agent`.

## Implemented MVP

- Streamed, size-limited audio download with redirect and SSRF checks
- Atomic placement under `DOWNLOAD_DIR`; MP3/FLAC/M4A/MP4 tags and JPEG/PNG cover art
- Optional `.lrc` sidecar; Flutter-compatible `picUrl` and `name` request aliases
- Idempotent import and reserved free-space enforcement
- Reversible file staging before SQLite row deletion
- Optional Subsonic `startScan` using token authentication
- Header-only `X-API-Key` auth and structured JSON audit events

## Architecture (ADR-0004)

| This service owns | This service must NOT |
|---|---|
| Download/import to `MUSIC_DIR` | Public multi-upstream search |
| Delete files + Navidrome DB rows | App register/login |
| Optional Navidrome scan trigger | Private update CDN / `version.json` API |

Sibling service: [`cloud`](../cloud) owns search/auth/updates.

Runtime split: [ADR-0004](../../apps/player/docs/adr/0004-cloud-control-plane-and-nas-agent.md). Product repo: [ADR-0005](../../docs/adr/0005-product-monorepo.md).

## Quick start

```bash
cd services/nas-agent
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Paste the generated value into `NAS_AGENT_KEY`, point the three storage paths at disposable local data, then run:

```bash
mkdir -p data/music/download
uvicorn app.main:app --reload --host 127.0.0.1 --port 8503
```

- Health: `GET http://127.0.0.1:8503/health`
- OpenAPI: `http://127.0.0.1:8503/docs`

## Verification

```bash
ruff check .
ruff format --check .
pytest -q
docker compose config --quiet
```

## Auth

Send `X-API-Key: <NAS_AGENT_KEY>`. The key must contain at least 32 non-space characters and must be independent from Navidrome and cloud credentials.

## Documentation

- [docs/API.md](docs/API.md)
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- [docs/SECURITY.md](docs/SECURITY.md)
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Related trees

- App: [`../../apps/player`](../../apps/player)
- Cloud: [`../cloud`](../cloud)
