# navidrome-cloud — Development guide

Public **control plane**. Do not grow this service into a NAS file manager.

Authority: `navidrome_player/docs/adr/0004-cloud-control-plane-and-nas-agent.md`.

## Boundaries

1. Flutter online features (search / url / cover / lyric / updates / auth / recommendations) live here.
2. Third-party music APIs are accessed only through adapters.
3. Search is first-success: one query → one non-empty result list.
4. Cloud never mounts music volumes or opens `navidrome.db`.
5. Postgres is the sole runtime source of truth.

## Layout

```text
app/
  db/                  # Postgres pool + transactional SQL migrations
  api/                 # HTTP routes
  adapters/            # Music upstream clients
  services/            # Music facade, auth, recommendations
docs/
releases/              # Private update artifacts
data/                  # Legacy SQLite migration inputs only
scripts/
  migrate_sqlite_to_postgres.py
tests/
```

## Local run

```bash
cp .env.example .env
# edit API_KEY, JWT_SECRET, POSTGRES_PASSWORD, DATABASE_URL
docker compose up -d --build
pytest -q
```

For host-side Uvicorn, make `DATABASE_URL` use `127.0.0.1` rather than Compose hostname `postgres`.

## Postgres behavior

- `app/db/migrations/*.sql` run in order at startup.
- Applied versions are recorded in `schema_migrations`.
- A migration failure aborts startup.
- Auth and recommendations share one async connection pool.
- Refresh token rotation and recommendation writes are transactional.
- Refill lease updates remain safe across workers.

## SQLite cutover

SQLite is no longer opened by runtime code. Use `scripts/migrate_sqlite_to_postgres.py`; see [POSTGRES_MIGRATION.md](POSTGRES_MIGRATION.md).

## Search semantics

```text
adapters = [gdstudio, meting?]
for each adapter (ordered) or race(N):
  search(query)
  first non-empty result wins
all empty/fail → 502/504
```

Do not merge NetEase + Kuwo + JOOX lists.

## Recommendation library blocking

Set `NAS_AGENT_URL` and `NAS_AGENT_KEY`. Cloud calls `GET /v1/songs/library-identities` and blocks those weak identities. Cloud still never touches NAS paths or `navidrome.db`.

## Verification

```bash
pytest -q
```

Coverage includes:

- music adapter failover and first-success contract
- private update allow-list
- Postgres register/login/refresh rotation
- recommendation sessions, leases, paging, feedback idempotency and reset
- SQLite migration dry-run/apply/repeat marker
- NAS library identity client
