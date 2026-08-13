from __future__ import annotations

import asyncio
import os
from pathlib import Path

import psycopg
import pytest

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql://navidrome:navidrome_test@127.0.0.1:55432/navidrome_cloud_test",
)


@pytest.fixture(scope="session", autouse=True)
def _prepare_postgres():
    os.environ["DATABASE_URL"] = TEST_DATABASE_URL

    async def prepare() -> None:
        from app.db.database import Database

        database = Database(TEST_DATABASE_URL, min_size=1, max_size=2)
        await database.open()
        await database.close()

    asyncio.run(prepare())
    yield


@pytest.fixture(autouse=True)
def _isolate_settings(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("DATABASE_URL", TEST_DATABASE_URL)
    monkeypatch.setenv("API_KEY", "test-cloud-key")
    monkeypatch.setenv("JWT_SECRET", "test-jwt-secret-at-least-32-characters-long")
    monkeypatch.setenv("AUTH_DB_PATH", str(tmp_path / "auth.db"))
    monkeypatch.setenv("RECOMMENDATION_DB_PATH", str(tmp_path / "recommendations.db"))
    monkeypatch.setenv("RELEASE_DIR", str(tmp_path / "releases"))
    monkeypatch.setenv("GDSTUDIO_API_BASE_URLS", "https://gdstudio.test/api.php")
    monkeypatch.setenv("METING_API_BASE_URLS", "")
    monkeypatch.setenv("UPSTREAM_STRATEGY", "ordered")
    (tmp_path / "releases").mkdir(parents=True, exist_ok=True)

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as connection:
        connection.execute(
            """
            TRUNCATE refresh_tokens, users, feedback, candidates, sessions
            RESTART IDENTITY CASCADE
            """
        )
        connection.execute(
            """
            UPDATE profile
            SET generation = 0, summary_json = '{}'::jsonb, updated_at = 0
            WHERE singleton = 1
            """
        )
        connection.execute("DELETE FROM data_migrations")

    from app.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
