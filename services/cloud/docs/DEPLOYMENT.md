# navidrome-cloud — Deployment notes

## Target topology

```text
Internet → HTTPS / Cloudflare Tunnel → 127.0.0.1:8600 → navidrome-cloud → Postgres
                                                   ↘ restricted FRP/Tailscale → navidrome-nas-agent
```

## Required

- Deploy behind TLS.
- Set long random `API_KEY`, `JWT_SECRET`, and `POSTGRES_PASSWORD` values.
- Make `DATABASE_URL` match the Postgres credentials and network hostname.
- Persist the Compose `cloud-pg` volume and `RELEASE_DIR`.
- Back up Postgres independently from application containers.

## Do not

- Bind-mount `/volume*/music` or `navidrome.db` into this container.
- Use SQLite as a live fallback after Postgres cutover.
- Expose unauthenticated release downloads.
- Point Flutter `nasAgentUrl` at this service.

## Docker

```bash
cp .env.example .env
docker compose up -d --build
curl -fsS http://127.0.0.1:8600/health
```

Compose binds both Cloud `8600` and Postgres `5432` to loopback by default. Publish Cloud through Nginx or Cloudflare Tunnel; do not change the Compose mapping to `0.0.0.0`.

Postgres schema migrations run transactionally during application startup. Startup fails when Postgres is unavailable or a migration fails.

## Music upstream order

The current bounded benchmark recommends Meting first and GDStudio second:

```env
METING_API_BASE_URLS=https://meting.mikus.ink/api
MUSIC_ADAPTER_ORDER=meting,gdstudio,chksz
CHKSZ_API_BASE_URL=https://api.chksz.com
CHKSZ_API_KEY=
```

Leave `CHKSZ_API_KEY` empty until a key is available. Do not put ChKSz first.

The public Meting endpoint is third-party infrastructure. A self-hosted `ghcr.io/metowolf/meting-api` instance should replace it only after configuring a NetEase cookie and passing `scripts/probe_meting_playability.py`. See `reports/music-upstream-benchmark.md` for evidence.

## Existing SQLite data

Follow [POSTGRES_MIGRATION.md](POSTGRES_MIGRATION.md). Stop old writers, back up both SQLite files, dry-run, apply once, then verify before retiring SQLite.

## Recommendation library blocking

Cloud never reads `navidrome.db`. Configure `NAS_AGENT_URL` and `NAS_AGENT_KEY`; cloud calls the NAS agent’s read-only identity endpoint. Use Tailscale or a restricted tunnel rather than exposing the NAS agent publicly.
