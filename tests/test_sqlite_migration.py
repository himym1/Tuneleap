from __future__ import annotations

import asyncio
import json
import os
import sqlite3
from pathlib import Path

import psycopg
import pytest

from app.db.database import Database
from scripts.migrate_sqlite_to_postgres import (
    MIGRATION_NAME,
    MigrationDataError,
    migrate_sqlite_to_postgres,
)

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql://navidrome:navidrome_test@127.0.0.1:55432/navidrome_cloud_test",
)


def _auth_db(path: Path) -> None:
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE COLLATE NOCASE,
            email TEXT,
            password_hash TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE TABLE refresh_tokens (
            jti TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            token_hash TEXT NOT NULL,
            expires_at REAL NOT NULL,
            revoked INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    connection.execute(
        "INSERT INTO users VALUES (7, 'Alice', 'a@example.com', 'hash', 12.5)"
    )
    connection.execute(
        "INSERT INTO refresh_tokens VALUES ('jti-1', 7, 'token-hash', 99.0, 1)"
    )
    connection.commit()
    connection.close()


def _recommendation_db(path: Path) -> None:
    song = {
        "id": "song-1",
        "title": "Song",
        "album": "Album",
        "album_id": "album",
        "artist": "Artist",
        "artist_id": "artist",
        "backend": "solara",
        "online_source": "netease",
        "url_id": "url-1",
    }
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        CREATE TABLE profile (
            singleton INTEGER PRIMARY KEY,
            generation INTEGER NOT NULL,
            summary_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
        );
        CREATE TABLE sessions (
            session_id TEXT PRIMARY KEY,
            generation INTEGER NOT NULL,
            mode TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            refill_owner TEXT,
            refill_lease_until INTEGER,
            recent_json TEXT NOT NULL
        );
        CREATE TABLE candidates (
            candidate_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            generation INTEGER NOT NULL,
            rank INTEGER NOT NULL,
            recommendation_type TEXT NOT NULL,
            song_json TEXT NOT NULL,
            strong_identity TEXT NOT NULL,
            weak_identity TEXT NOT NULL,
            blocked INTEGER NOT NULL,
            served INTEGER NOT NULL
        );
        CREATE TABLE feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            idempotency_key TEXT NOT NULL,
            generation INTEGER NOT NULL,
            session_id TEXT NOT NULL,
            candidate_id TEXT NOT NULL,
            event TEXT NOT NULL,
            song_json TEXT NOT NULL,
            strong_identity TEXT NOT NULL,
            weak_identity TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );
        """
    )
    connection.execute(
        "INSERT INTO profile VALUES (1, 3, ?, 10)", ('{"mood":"focus"}',)
    )
    connection.execute(
        "INSERT INTO sessions VALUES (?, 3, 'ai', 10, 999999, 'active', NULL, NULL, ?)",
        ("session-1", '[{"title":"Recent"}]'),
    )
    payload = json.dumps(song, separators=(",", ":"), sort_keys=True)
    connection.execute(
        "INSERT INTO candidates VALUES (?, ?, 3, 0, 'similar', ?, ?, ?, 0, 0)",
        ("candidate-1", "session-1", payload, "netease:url-1", "song\x1fartist"),
    )
    connection.execute(
        "INSERT INTO feedback VALUES (11, ?, 3, ?, ?, 'played', ?, ?, ?, 12)",
        (
            "idem-1",
            "session-1",
            "candidate-1",
            payload,
            "netease:url-1",
            "song\x1fartist",
        ),
    )
    connection.commit()
    connection.close()


@pytest.mark.asyncio
async def test_sqlite_migration_dry_run_apply_and_repeat(tmp_path: Path):
    auth = tmp_path / "auth.db"
    recommendations = tmp_path / "recommendations.db"
    _auth_db(auth)
    _recommendation_db(recommendations)

    dry = await migrate_sqlite_to_postgres(
        database_url=TEST_DATABASE_URL,
        auth_db=auth,
        recommendation_db=recommendations,
        apply=False,
    )
    assert dry["apply"] is False
    assert dry["source"]["users"] == 1
    assert dry["target_before"]["users"] == 0

    applied = await migrate_sqlite_to_postgres(
        database_url=TEST_DATABASE_URL,
        auth_db=auth,
        recommendation_db=recommendations,
        apply=True,
    )
    assert applied["target_after"] == {
        "users": 1,
        "refresh_tokens": 1,
        "sessions": 1,
        "candidates": 1,
        "feedback": 1,
    }

    repeated = await migrate_sqlite_to_postgres(
        database_url=TEST_DATABASE_URL,
        auth_db=auth,
        recommendation_db=recommendations,
        apply=True,
    )
    assert repeated["already_applied"] is True

    with psycopg.connect(TEST_DATABASE_URL) as connection:
        user = connection.execute(
            "SELECT id, username FROM users WHERE id = 7"
        ).fetchone()
        profile = connection.execute(
            "SELECT generation, summary_json FROM profile WHERE singleton = 1"
        ).fetchone()
        session = connection.execute(
            "SELECT mode, recent_json FROM sessions WHERE session_id = 'session-1'"
        ).fetchone()
    assert user == (7, "Alice")
    assert profile == (3, {"mood": "focus"})
    assert session == ("fallback", [{"title": "Recent"}])


@pytest.mark.asyncio
async def test_sqlite_migration_concurrent_apply_is_idempotent(tmp_path: Path):
    auth = tmp_path / "auth.db"
    recommendations = tmp_path / "recommendations.db"
    _auth_db(auth)
    _recommendation_db(recommendations)

    results = await asyncio.gather(
        *(
            migrate_sqlite_to_postgres(
                database_url=TEST_DATABASE_URL,
                auth_db=auth,
                recommendation_db=recommendations,
                apply=True,
            )
            for _ in range(2)
        )
    )
    assert sum(bool(result.get("applied")) for result in results) == 1
    assert sum(result["already_applied"] for result in results) == 1


@pytest.mark.asyncio
async def test_invalid_json_rolls_back_without_marker(tmp_path: Path):
    auth = tmp_path / "auth.db"
    recommendations = tmp_path / "recommendations.db"
    _auth_db(auth)
    _recommendation_db(recommendations)
    with sqlite3.connect(recommendations) as connection:
        connection.execute(
            "UPDATE candidates SET song_json = '{' WHERE candidate_id = 'candidate-1'"
        )

    for apply in (False, True):
        with pytest.raises(
            MigrationDataError, match="candidates.session-1/candidate-1"
        ):
            await migrate_sqlite_to_postgres(
                database_url=TEST_DATABASE_URL,
                auth_db=auth,
                recommendation_db=recommendations,
                apply=apply,
            )

    with psycopg.connect(TEST_DATABASE_URL) as connection:
        counts = [
            connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            for table in ("users", "sessions", "candidates", "feedback")
        ]
        marker = connection.execute(
            "SELECT 1 FROM data_migrations WHERE name = %s", (MIGRATION_NAME,)
        ).fetchone()
    assert counts == [0, 0, 0, 0]
    assert marker is None


@pytest.mark.asyncio
async def test_schema_migration_is_serialized_across_replicas():
    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as connection:
        connection.execute(
            "DELETE FROM schema_migrations WHERE version = '001_initial'"
        )

    databases = [Database(TEST_DATABASE_URL, min_size=1, max_size=2) for _ in range(2)]
    try:
        await asyncio.gather(*(database.open() for database in databases))
    finally:
        await asyncio.gather(*(database.close() for database in databases))

    with psycopg.connect(TEST_DATABASE_URL) as connection:
        count = connection.execute(
            "SELECT COUNT(*) FROM schema_migrations WHERE version = '001_initial'"
        ).fetchone()[0]
    assert count == 1


@pytest.mark.asyncio
async def test_generation_mismatch_is_rejected_before_cutover(tmp_path: Path):
    auth = tmp_path / "auth.db"
    recommendations = tmp_path / "recommendations.db"
    _auth_db(auth)
    _recommendation_db(recommendations)
    with sqlite3.connect(recommendations) as connection:
        connection.execute(
            "UPDATE candidates SET generation = 2 WHERE candidate_id = 'candidate-1'"
        )

    for apply in (False, True):
        with pytest.raises(MigrationDataError, match="does not match its session"):
            await migrate_sqlite_to_postgres(
                database_url=TEST_DATABASE_URL,
                auth_db=auth,
                recommendation_db=recommendations,
                apply=apply,
            )

    with psycopg.connect(TEST_DATABASE_URL) as connection:
        count = connection.execute("SELECT COUNT(*) FROM candidates").fetchone()[0]
        marker = connection.execute(
            "SELECT 1 FROM data_migrations WHERE name = %s", (MIGRATION_NAME,)
        ).fetchone()
    assert count == 0
    assert marker is None
