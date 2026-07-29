# navidrome-cloud — Deployment notes

## Target topology

```text
Internet → HTTPS (Caddy/Nginx or Cloudflare) → navidrome-cloud :8600 on VPS
                                              ↘ optional object storage for large APK/DMG
NAS himym → navidrome-nas-agent only (not this service)
```

## Do

- Deploy on VPS with TLS
- Keep `API_KEY` and a long `JWT_SECRET` (≥32 chars) in env or secret manager
- Persist `./data` (auth.db + recommendations.db) and `RELEASE_DIR` across deploys
- Put release artifacts under `RELEASE_DIR` (or object storage + signed URLs later)

## Do not

- Bind-mount `/volume*/music` or `navidrome.db` into this container
- Expose unauthenticated release downloads
- Point Flutter `nasAgentUrl` at this service

## Docker

```bash
cp .env.example .env
docker compose up -d --build
curl -s http://127.0.0.1:8600/health
```

Auth and recommendations use local SQLite under `./data` by default. Postgres remains optional for a later migration (`DATABASE_URL`).

## Cutover from old `navidrome-backend:8503`

1. Point a test Flutter build `cloudApiUrl` to this host for music + updates.
2. Keep NAS import on nas-agent / old backend until agent is ready.
3. Move private update origin (`player.himym.us.ci` pattern) to this origin.
4. Retire monolithic 8503 music+update+recommendation routes last.
