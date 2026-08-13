#!/usr/bin/env python3
"""One-shot, idempotent SQLite -> Postgres data migration.

Dry-run is the default. Pass --apply to write. The target must be empty except
for the default profile row created by schema migration 001_initial.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from psycopg.types.json import Jsonb

from app.db.database import Database

MIGRATION_NAME = "sqlite_to_postgres_v1"
_MIGRATION_LOCK_ID = 7_321_962_857_420_002


class MigrationDataError(ValueError):
    pass


def _open_sqlite(path: Path) -> sqlite3.Connection | None:
    if not path.is_file():
        return None
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    return connection


def _rows(connection: sqlite3.Connection | None, table: str) -> list[dict[str, Any]]:
    if connection is None:
        return []
    exists = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    if exists is None:
        return []
    return [dict(row) for row in connection.execute(f'SELECT * FROM "{table}"')]


def _json_value(value: Any, expected_type: type, *, location: str) -> Any:
    parsed = value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError as exc:
            raise MigrationDataError(f"invalid JSON at {location}: {exc.msg}") from exc
    if not isinstance(parsed, expected_type):
        raise MigrationDataError(
            f"invalid JSON type at {location}: expected {expected_type.__name__}"
        )
    return parsed


def read_sources(
    auth_db: Path, recommendation_db: Path
) -> dict[str, list[dict[str, Any]]]:
    auth = _open_sqlite(auth_db)
    recommendations = _open_sqlite(recommendation_db)
    if auth is None and recommendations is None:
        raise FileNotFoundError("no SQLite source database exists")
    try:
        return {
            "users": _rows(auth, "users"),
            "refresh_tokens": _rows(auth, "refresh_tokens"),
            "profile": _rows(recommendations, "profile"),
            "sessions": _rows(recommendations, "sessions"),
            "candidates": _rows(recommendations, "candidates"),
            "feedback": _rows(recommendations, "feedback"),
        }
    finally:
        if auth is not None:
            auth.close()
        if recommendations is not None:
            recommendations.close()


def validate_sources(sources: dict[str, list[dict[str, Any]]]) -> None:
    user_ids = {int(row["id"]) for row in sources["users"]}
    if len(user_ids) != len(sources["users"]):
        raise MigrationDataError("users contain duplicate IDs")
    for row in sources["refresh_tokens"]:
        jti = str(row["jti"])
        if int(row["user_id"]) not in user_ids:
            raise MigrationDataError(f"refresh_tokens.{jti} references a missing user")

    profiles = sources["profile"]
    recommendation_rows = (
        sources["sessions"],
        sources["candidates"],
        sources["feedback"],
    )
    if len(profiles) > 1:
        raise MigrationDataError("profile contains more than one singleton row")
    if not profiles:
        if any(recommendation_rows):
            raise MigrationDataError(
                "recommendation rows exist without a profile singleton"
            )
        return

    profile = profiles[0]
    if int(profile.get("singleton", 0)) != 1:
        raise MigrationDataError("profile singleton must equal 1")
    generation = int(profile["generation"])
    _json_value(
        profile.get("summary_json"),
        dict,
        location="profile.singleton=1.summary_json",
    )

    sessions: dict[str, int] = {}
    for row in sources["sessions"]:
        session_id = str(row["session_id"])
        session_generation = int(row["generation"])
        if session_generation != generation:
            raise MigrationDataError(
                f"sessions.{session_id}.generation does not match profile"
            )
        sessions[session_id] = session_generation
        _json_value(
            row.get("recent_json"),
            list,
            location=f"sessions.{session_id}.recent_json",
        )

    for row in sources["candidates"]:
        session_id = str(row["session_id"])
        candidate_id = str(row["candidate_id"])
        candidate_generation = int(row["generation"])
        if session_id not in sessions:
            raise MigrationDataError(
                f"candidates.{session_id}/{candidate_id} has no source session"
            )
        if candidate_generation != sessions[session_id]:
            raise MigrationDataError(
                f"candidates.{session_id}/{candidate_id}.generation "
                "does not match its session"
            )
        _json_value(
            row["song_json"],
            dict,
            location=f"candidates.{session_id}/{candidate_id}.song_json",
        )

    for row in sources["feedback"]:
        feedback_id = int(row["id"])
        if int(row["generation"]) != generation:
            raise MigrationDataError(
                f"feedback.{feedback_id}.generation does not match profile"
            )
        _json_value(
            row["song_json"],
            dict,
            location=f"feedback.{feedback_id}.song_json",
        )


async def _target_counts(connection) -> dict[str, int]:
    counts: dict[str, int] = {}
    for table in ("users", "refresh_tokens", "sessions", "candidates", "feedback"):
        row = await (
            await connection.execute(f"SELECT COUNT(*) FROM {table}")
        ).fetchone()
        counts[table] = int(row[0])
    return counts


async def _marker(connection):
    return await (
        await connection.execute(
            "SELECT details FROM data_migrations WHERE name = %s",
            (MIGRATION_NAME,),
        )
    ).fetchone()


async def _migration_report(
    connection,
    *,
    apply: bool,
    source_counts: dict[str, int],
) -> dict[str, Any]:
    marker = await _marker(connection)
    return {
        "migration": MIGRATION_NAME,
        "apply": apply,
        "source": source_counts,
        "target_before": await _target_counts(connection),
        "already_applied": marker is not None,
    }


async def _apply_sources(
    connection,
    sources: dict[str, list[dict[str, Any]]],
    source_counts: dict[str, int],
) -> dict[str, Any]:
    await connection.execute("SELECT pg_advisory_xact_lock(%s)", (_MIGRATION_LOCK_ID,))
    report = await _migration_report(
        connection, apply=True, source_counts=source_counts
    )
    if report["already_applied"]:
        return report

    profile_row = await (
        await connection.execute(
            "SELECT generation, summary_json FROM profile WHERE singleton = 1"
        )
    ).fetchone()
    profile_is_default = (
        profile_row is not None and int(profile_row[0]) == 0 and profile_row[1] == {}
    )
    if any(report["target_before"].values()) or not profile_is_default:
        raise RuntimeError("target Postgres database is not empty")

    for row in sources["users"]:
        await connection.execute(
            """
            INSERT INTO users(id, username, email, password_hash, created_at)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                int(row["id"]),
                row["username"],
                row.get("email"),
                row["password_hash"],
                float(row["created_at"]),
            ),
        )

    for row in sources["refresh_tokens"]:
        await connection.execute(
            """
            INSERT INTO refresh_tokens(jti, user_id, token_hash, expires_at, revoked)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                row["jti"],
                int(row["user_id"]),
                row["token_hash"],
                float(row["expires_at"]),
                bool(row["revoked"]),
            ),
        )

    if sources["profile"]:
        row = sources["profile"][0]
        await connection.execute(
            """
            UPDATE profile
            SET generation = %s, summary_json = %s, updated_at = %s
            WHERE singleton = 1
            """,
            (
                int(row["generation"]),
                Jsonb(
                    _json_value(
                        row.get("summary_json"),
                        dict,
                        location="profile.singleton=1.summary_json",
                    )
                ),
                int(row.get("updated_at", 0)),
            ),
        )

    for row in sources["sessions"]:
        session_id = str(row["session_id"])
        await connection.execute(
            """
            INSERT INTO sessions(
                session_id, generation, mode, created_at, expires_at,
                status, refill_owner, refill_lease_until, recent_json
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                session_id,
                int(row["generation"]),
                "fallback",
                int(row["created_at"]),
                int(row["expires_at"]),
                row.get("status", "active"),
                row.get("refill_owner"),
                row.get("refill_lease_until"),
                Jsonb(
                    _json_value(
                        row.get("recent_json"),
                        list,
                        location=f"sessions.{session_id}.recent_json",
                    )
                ),
            ),
        )

    for row in sources["candidates"]:
        session_id = str(row["session_id"])
        candidate_id = str(row["candidate_id"])
        await connection.execute(
            """
            INSERT INTO candidates(
                candidate_id, session_id, generation, rank,
                recommendation_type, song_json, strong_identity,
                weak_identity, blocked, served
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                candidate_id,
                session_id,
                int(row["generation"]),
                int(row["rank"]),
                row["recommendation_type"],
                Jsonb(
                    _json_value(
                        row["song_json"],
                        dict,
                        location=f"candidates.{session_id}/{candidate_id}.song_json",
                    )
                ),
                row["strong_identity"],
                row["weak_identity"],
                bool(row.get("blocked", 0)),
                bool(row.get("served", 0)),
            ),
        )

    for row in sources["feedback"]:
        feedback_id = int(row["id"])
        await connection.execute(
            """
            INSERT INTO feedback(
                id, idempotency_key, generation, session_id,
                candidate_id, event, song_json, strong_identity,
                weak_identity, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                feedback_id,
                row["idempotency_key"],
                int(row["generation"]),
                row["session_id"],
                row["candidate_id"],
                row["event"],
                Jsonb(
                    _json_value(
                        row["song_json"],
                        dict,
                        location=f"feedback.{feedback_id}.song_json",
                    )
                ),
                row["strong_identity"],
                row["weak_identity"],
                int(row["created_at"]),
            ),
        )

    for table in ("users", "feedback"):
        await connection.execute(
            f"""
            SELECT setval(
                pg_get_serial_sequence('{table}', 'id'),
                COALESCE((SELECT MAX(id) FROM {table}), 1),
                EXISTS(SELECT 1 FROM {table})
            )
            """
        )

    await connection.execute(
        "INSERT INTO data_migrations(name, details) VALUES (%s, %s)",
        (MIGRATION_NAME, Jsonb({"source": source_counts})),
    )
    target_after = await _target_counts(connection)
    expected = {key: source_counts[key] for key in target_after}
    if target_after != expected:
        raise RuntimeError(
            f"post-migration row count mismatch: {target_after} != {expected}"
        )
    report["target_after"] = target_after
    report["applied"] = True
    return report


async def migrate_sqlite_to_postgres(
    *,
    database_url: str,
    auth_db: Path,
    recommendation_db: Path,
    apply: bool,
) -> dict[str, Any]:
    sources = read_sources(auth_db, recommendation_db)
    validate_sources(sources)
    source_counts = {name: len(rows) for name, rows in sources.items()}
    database = Database(database_url, min_size=1, max_size=2)
    await database.open()
    try:
        async with database.pool.connection() as connection:
            if not apply:
                return await _migration_report(
                    connection, apply=False, source_counts=source_counts
                )
            async with connection.transaction():
                return await _apply_sources(connection, sources, source_counts)
    finally:
        await database.close()


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-url", required=True)
    parser.add_argument("--auth-db", type=Path, default=Path("./data/auth.db"))
    parser.add_argument(
        "--recommendation-db",
        type=Path,
        default=Path("./data/recommendations.db"),
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write data; without this flag the command is dry-run only",
    )
    return parser.parse_args()


def main() -> None:
    args = _arguments()
    report = asyncio.run(
        migrate_sqlite_to_postgres(
            database_url=args.database_url,
            auth_db=args.auth_db,
            recommendation_db=args.recommendation_db,
            apply=args.apply,
        )
    )
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
