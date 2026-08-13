# SQLite → Postgres migration

`navidrome-cloud` 0.2 uses Postgres as the only runtime source of truth. Existing `data/auth.db` and `data/recommendations.db` are migration inputs only.

## 1. Stop writers

Stop the old cloud process before the final migration. Do not let SQLite and Postgres accept writes at the same time.

## 2. Back up SQLite

```bash
cp data/auth.db /safe/location/auth.db
cp data/recommendations.db /safe/location/recommendations.db
```

## 3. Start Postgres

Set `POSTGRES_PASSWORD` and make `DATABASE_URL` use the same credentials, then:

```bash
docker compose up -d postgres
```

For a host-side migration, use a host-reachable URL, for example:

```bash
export DATABASE_URL='postgresql://navidrome:<password>@127.0.0.1:5432/navidrome_cloud'
```

## 4. Dry-run

Dry-run is the default and does not write:

```bash
python scripts/migrate_sqlite_to_postgres.py \
  --database-url "$DATABASE_URL" \
  --auth-db data/auth.db \
  --recommendation-db data/recommendations.db
```

Review `source`, `target_before`, and `already_applied` in the JSON output.

## 5. Apply once

The target must be empty except for the default profile row created by schema migration `001_initial`.

```bash
python scripts/migrate_sqlite_to_postgres.py \
  --database-url "$DATABASE_URL" \
  --auth-db data/auth.db \
  --recommendation-db data/recommendations.db \
  --apply
```

The operation is transactional, preserves user/feedback IDs, resets Postgres sequences, verifies row counts, and writes marker `sqlite_to_postgres_v1`. Re-running after success returns `already_applied: true` without duplicating rows.

## 6. Start cloud and verify

```bash
docker compose up -d --build navidrome-cloud
curl -fsS http://127.0.0.1:8600/health
pytest -q
```

Verify register/login/refresh and recommendation session/feedback before deleting any SQLite source files.

## Rollback

1. Stop the Postgres-backed cloud process.
2. Restore the backed-up SQLite files and the previous application image/commit.
3. Do not copy newer Postgres writes back automatically; that requires a separate reconciliation procedure.
