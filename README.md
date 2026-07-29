# navidrome-cloud

Public **control plane** for [navidrome_player](../navidrome_player): online music search, playback URL/lyric/cover resolution, private app updates, product auth, and recommendations.

## Architecture (ADR-0004)

| This service owns | This service must NOT |
|---|---|
| Multi-upstream music facade (first-success) | Mount NAS music disks |
| Private updates | Open `navidrome.db` |
| Register/login/refresh + recommendations | Import/delete library files |

Sibling service: [`navidrome-nas-agent`](../navidrome-nas-agent) for import/delete only.

Player ADR (source of truth):

`../navidrome_player/docs/adr/0004-cloud-control-plane-and-nas-agent.md`

## Docs in this repo

| File | Purpose |
|---|---|
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | How to run, module map, phases |
| [docs/API.md](docs/API.md) | HTTP contract for Flutter / agents |
| [docs/UPSTREAMS.md](docs/UPSTREAMS.md) | gdstudio + Meting adapter notes |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | VPS / HTTPS / secrets |

## Quick start

```bash
cd navidrome-cloud
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit API_KEY + JWT_SECRET
uvicorn app.main:app --reload --host 0.0.0.0 --port 8600
```

- Health: `GET http://127.0.0.1:8600/health`
- OpenAPI: `http://127.0.0.1:8600/docs`
- Search:

```bash
curl -H 'X-API-Key: change-me-cloud' \
  'http://127.0.0.1:8600/v1/music/search?q=hello&source=netease'
```

```bash
pytest -q
```

## Status

Implemented:

- P0 music MVP (gdstudio adapter, first-success facade, url/cover/lyric)
- P1 optional Meting adapter + private updates (`version.json` / releases)
- P2 SQLite auth (register/login/refresh JWT) + recommendations (ported, no NAS library)
- P3 slowapi rate limits on music/auth/recommendations

## Related projects

- App: `../navidrome_player`
- Legacy monorepo bridge: `../navidrome-backend` (reference only while migrating)
- NAS agent: `../navidrome-nas-agent`
