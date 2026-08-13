"""Postgres connection pool and transactional SQL migrations."""

from __future__ import annotations

from pathlib import Path

from psycopg.rows import tuple_row
from psycopg_pool import AsyncConnectionPool

_SCHEMA_MIGRATION_LOCK_ID = 7_321_962_857_420_001


class Database:
    def __init__(
        self,
        database_url: str,
        *,
        min_size: int = 1,
        max_size: int = 10,
        timeout: float = 10.0,
    ) -> None:
        if not database_url.strip():
            raise RuntimeError("DATABASE_URL is required")
        self.pool = AsyncConnectionPool(
            conninfo=database_url,
            min_size=min_size,
            max_size=max_size,
            timeout=timeout,
            open=False,
            kwargs={"autocommit": True, "row_factory": tuple_row},
        )

    async def open(self) -> None:
        await self.pool.open(wait=True)
        try:
            await self.apply_migrations()
        except Exception:
            await self.pool.close()
            raise

    async def close(self) -> None:
        await self.pool.close()

    async def apply_migrations(self) -> None:
        migration_dir = Path(__file__).with_name("migrations")
        files = sorted(migration_dir.glob("*.sql"))
        async with self.pool.connection() as connection:
            async with connection.transaction():
                # Serialize first-start migrations across application replicas.
                await connection.execute(
                    "SELECT pg_advisory_xact_lock(%s)",
                    (_SCHEMA_MIGRATION_LOCK_ID,),
                )
                await connection.execute(
                    """
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        version TEXT PRIMARY KEY,
                        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                    """
                )
                rows = await (
                    await connection.execute("SELECT version FROM schema_migrations")
                ).fetchall()
                applied = {str(row[0]) for row in rows}
                for path in files:
                    version = path.stem
                    if version in applied:
                        continue
                    sql = path.read_text(encoding="utf-8")
                    await connection.execute(sql, prepare=False)
                    await connection.execute(
                        "INSERT INTO schema_migrations(version) VALUES (%s)",
                        (version,),
                    )
