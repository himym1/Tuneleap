# navidrome-cloud — Development guide

Public **control plane**. Do not grow this service into a NAS file manager.

Authority: `navidrome_player/docs/adr/0004-cloud-control-plane-and-nas-agent.md`.

## Goals

1. Own HTTP API for Flutter online features (search / url / cover / lyric / updates / auth / recommendations).
2. Call third-party music HTTP APIs only through **adapters** (ports).
3. Search is **first-success**: one query → one non-empty list from the first working upstream.
4. Never mount music volumes or open Navidrome SQLite here.

## Non-goals

- OpenMusic rooms, chat, Socket.IO, Redis room state
- Wrapping an entire open-source music server as our product identity
- Multi-source UI merge (`netease + kuwo + joox` concatenated lists)
- NAS import/delete (belongs to `navidrome-nas-agent`)

## Implement status

| Phase | Work | Status |
|---|---|---|
| P0 | Gdstudio adapter `search/url/pic/lyric` + multi-base failover | Done — `app/adapters/gdstudio.py` |
| P0 | `MusicFacade.search_first_success` + normalize `SongDTO` | Done — `app/services/music_facade.py` |
| P0 | Wire url/cover/lyric routes | Done — `app/api/music.py` |
| P1 | Optional Meting adapter when bases configured | Done — `app/adapters/meting.py` |
| P1 | Private updates (`version.json` + releases) | Done — `app/api/updates.py` |
| P2 | Auth register/login/refresh | Done — SQLite + JWT (`app/services/auth_service.py`) |
| P2 | Recommendations migration | Done — ported service/store; library=None |
| P3 | Rate limit | Done — slowapi on music/auth/recommendations |

## Layout

```text
app/
  main.py              # FastAPI app + lifespan httpx + recommendation service
  api/                 # HTTP routes (thin)
  adapters/            # Upstream clients + pool/normalize
  services/            # Facades / auth / recommendations
  models/              # Pydantic DTOs
  core/                # settings, auth, limiter, recommendation HTTP helpers
docs/
releases/              # Private update artifacts (local/VPS)
data/                  # Local SQLite (auth + recommendations) — gitignored
tests/
```

## Local run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# set API_KEY and a long JWT_SECRET
uvicorn app.main:app --reload --port 8600
pytest -q
```

Auth:

- Early shared key: header `X-API-Key` matching `API_KEY`
- Or `Authorization: Bearer <access_token>` from `/v1/auth/*`

## First-success search algorithm

```text
adapters = [gdstudio, meting?]  # enabled if bases non-empty
for each adapter (ordered) or race(N):
  try search(query)
  if items non-empty:
    return { provider, items normalized }
  on failure: mark base cooldown, try next
if all empty/fail: 502/503 with stable error body
```

Do **not** merge multiple providers’ hit lists for one request.

Optional: accept `source=` as a **hint** (prefer netease inside an adapter).

## Compatibility with Flutter

Target near-term compatibility with `navidrome_player/lib/api/backend_client.dart`:

- Online song fields: ids, title/artist/album, source/provider, url/cover/lyric ids
- Private updates: `/version.json` + `/releases/{filename}` allow-list (same as old backend)
- Recommendations: `/v1/recommendations/*` contractVersion 1 (ported)
- App should use `cloudApiUrl` (not `navidromeHost:8503`) for this service

## Reference code (migration aid)

- Old proxy: `navidrome-backend/app/services/music_proxy.py`
- Old music routes: `navidrome-backend/app/routers/music.py`
- Old updates: `navidrome-backend/app/routers/updates.py`
- Old recommendations: `navidrome-backend/app/services/recommendation_*.py`

## Testing expectations

- Unit-test adapters with `httpx.MockTransport`
- Contract test: first-success returns a single `provider` and does not concatenate two lists
- Auth: missing key → 401; register/login/refresh round-trip
- Updates: allow-list + no symlink escape

## Definition of done (music MVP)

- [x] `GET /v1/music/search` returns real items with valid API key
- [x] url/cover/lyric work for a search hit
- [x] At least two gdstudio bases can failover (if configured)
- [x] No NAS paths in config or code
- [x] pytest green for health + auth + adapter happy path
