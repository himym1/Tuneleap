"""Postgres-backed recommendation state and cross-worker refill leases."""

from __future__ import annotations

import asyncio
import base64
import binascii
import functools
import json
import secrets
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, TypeVar

from psycopg.errors import UniqueViolation
from psycopg.types.json import Jsonb
from psycopg_pool import AsyncConnectionPool

from app.models.recommendations import (
    RecommendationFeedbackEvent,
    RecommendationItem,
    RecommendationPageV1,
    RecommendationSong,
)
from app.services.recommendation_identity import weak_identity as song_weak_identity


class RecommendationStoreError(Exception):
    pass


class StaleSessionError(RecommendationStoreError):
    pass


class LeaseLostError(RecommendationStoreError):
    pass


class InvalidCursorError(RecommendationStoreError):
    pass


@dataclass(frozen=True)
class Session:
    session_id: str
    generation: int
    mode: str
    created_at: int
    expires_at: int
    status: str


@dataclass(frozen=True)
class FeedbackResult:
    accepted: bool
    duplicate: bool
    feedback_id: int | None = None
    event: str | None = None


_T = TypeVar("_T")


def _serialized(method: Callable[..., Awaitable[_T]]) -> Callable[..., Awaitable[_T]]:
    @functools.wraps(method)
    async def wrapper(self: RecommendationStore, *args: Any, **kwargs: Any) -> _T:
        async with self._lock:
            return await method(self, *args, **kwargs)

    return wrapper


def _json_value(value: Any, default: Any) -> Any:
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return default
    return default


class RecommendationStore:
    CURSOR_VERSION = 1

    def __init__(
        self,
        pool: AsyncConnectionPool,
        *,
        session_ttl_ms: int = 24 * 60 * 60 * 1000,
        clock_ms: Callable[[], int] | None = None,
    ) -> None:
        self.pool = pool
        self.session_ttl_ms = session_ttl_ms
        self.clock_ms = clock_ms or _now
        self._lock = asyncio.Lock()
        self._initialized = False

    def _now(self) -> int:
        return int(self.clock_ms())

    @_serialized
    async def initialize(self) -> None:
        if self._initialized:
            return
        async with self.pool.connection() as connection:
            async with connection.transaction():
                for table, keys in (
                    ("candidates", ("session_id", "candidate_id")),
                    ("feedback", ("id",)),
                ):
                    columns = ", ".join((*keys, "song_json", "weak_identity"))
                    rows = await (
                        await connection.execute(f"SELECT {columns} FROM {table}")
                    ).fetchall()
                    for row in rows:
                        key_values = row[: len(keys)]
                        song = _json_value(row[len(keys)], {})
                        stored_identity = str(row[len(keys) + 1])
                        normalized_identity = song_weak_identity(song)
                        if normalized_identity == stored_identity:
                            continue
                        where = " AND ".join(f"{key} = %s" for key in keys)
                        await connection.execute(
                            f"UPDATE {table} SET weak_identity = %s WHERE {where}",
                            (normalized_identity, *key_values),
                        )
        self._initialized = True

    @_serialized
    async def close(self) -> None:
        self._initialized = False

    async def _generation(self, connection, *, lock: bool = False) -> int:
        suffix = " FOR UPDATE" if lock else ""
        row = await (
            await connection.execute(
                f"SELECT generation FROM profile WHERE singleton = 1{suffix}"
            )
        ).fetchone()
        if row is None:
            raise RuntimeError("recommendation profile is not initialized")
        return int(row[0])

    async def _resume_with_connection(self, connection, session_id: str) -> Session:
        row = await (
            await connection.execute(
                """
                SELECT s.session_id, s.generation, s.mode, s.created_at,
                       s.expires_at, s.status
                FROM sessions s
                JOIN profile p ON p.singleton = 1 AND p.generation = s.generation
                WHERE s.session_id = %s
                  AND s.status = 'active'
                  AND s.expires_at > %s
                """,
                (session_id, self._now()),
            )
        ).fetchone()
        if row is None:
            raise StaleSessionError("session is stale or expired")
        return Session(
            str(row[0]), int(row[1]), str(row[2]), int(row[3]), int(row[4]), str(row[5])
        )

    @_serialized
    async def current_generation(self) -> int:
        async with self.pool.connection() as connection:
            return await self._generation(connection)

    @_serialized
    async def create_session(
        self,
        session_id: str | None = None,
        *,
        mode: str = "fallback",
        refresh: bool = False,
        ttl_ms: int | None = None,
    ) -> Session:
        if mode != "fallback":
            raise ValueError("invalid recommendation mode")
        sid = session_id or secrets.token_urlsafe(16)
        now = self._now()
        expires = now + (self.session_ttl_ms if ttl_ms is None else ttl_ms)
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                old = await (
                    await connection.execute(
                        "SELECT generation, status FROM sessions WHERE session_id = %s",
                        (sid,),
                    )
                ).fetchone()
                if old is not None and int(old[0]) != generation:
                    raise StaleSessionError("session belongs to an old generation")
                if refresh and session_id is not None and old is None:
                    raise StaleSessionError("session does not exist")
                if old is not None and not refresh:
                    row = await (
                        await connection.execute(
                            """
                            SELECT session_id, generation, mode, created_at,
                                   expires_at, status
                            FROM sessions WHERE session_id = %s
                            """,
                            (sid,),
                        )
                    ).fetchone()
                    assert row is not None
                    if str(row[5]) != "active" or int(row[4]) <= now:
                        raise StaleSessionError("session is not active")
                    return Session(
                        str(row[0]),
                        int(row[1]),
                        str(row[2]),
                        int(row[3]),
                        int(row[4]),
                        str(row[5]),
                    )
                if old is not None:
                    if str(old[1]) != "active":
                        raise StaleSessionError("session is not active")
                    cursor = await connection.execute(
                        """
                        UPDATE sessions
                        SET status = 'ended', refill_owner = NULL,
                            refill_lease_until = NULL
                        WHERE session_id = %s AND generation = %s
                          AND status = 'active' AND expires_at > %s
                        """,
                        (sid, generation, now),
                    )
                    if cursor.rowcount != 1:
                        raise StaleSessionError("session is stale or no longer active")
                    sid = secrets.token_urlsafe(16)
                await connection.execute(
                    """
                    INSERT INTO sessions(
                        session_id, generation, mode, created_at, expires_at,
                        status, refill_owner, refill_lease_until
                    ) VALUES (%s, %s, %s, %s, %s, 'active', NULL, NULL)
                    """,
                    (sid, generation, mode, now, expires),
                )
        return Session(sid, generation, mode, now, expires, "active")

    @_serialized
    async def resume_session(self, session_id: str) -> Session:
        async with self.pool.connection() as connection:
            return await self._resume_with_connection(connection, session_id)

    @_serialized
    async def get_active_session(self) -> Session | None:
        async with self.pool.connection() as connection:
            row = await (
                await connection.execute(
                    """
                    SELECT s.session_id, s.generation, s.mode, s.created_at,
                           s.expires_at, s.status
                    FROM sessions s
                    JOIN profile p ON p.singleton = 1 AND p.generation = s.generation
                    WHERE s.status = 'active' AND s.expires_at > %s
                    ORDER BY s.created_at DESC LIMIT 1
                    """,
                    (self._now(),),
                )
            ).fetchone()
        if row is None:
            return None
        return Session(
            str(row[0]), int(row[1]), str(row[2]), int(row[3]), int(row[4]), str(row[5])
        )

    @_serialized
    async def set_session_mode(self, session_id: str, mode: str) -> None:
        if mode != "fallback":
            raise ValueError("invalid recommendation mode")
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                cursor = await connection.execute(
                    """
                    UPDATE sessions SET mode = %s
                    WHERE session_id = %s AND generation = %s
                      AND status = 'active' AND expires_at > %s
                    """,
                    (mode, session_id, generation, self._now()),
                )
                if cursor.rowcount != 1:
                    raise StaleSessionError("session is stale or expired")

    @_serialized
    async def set_session_recent(
        self, session_id: str, recent: list[dict[str, object]]
    ) -> None:
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                cursor = await connection.execute(
                    """
                    UPDATE sessions SET recent_json = %s
                    WHERE session_id = %s AND generation = %s
                      AND status = 'active' AND expires_at > %s
                    """,
                    (Jsonb(recent[:30]), session_id, generation, self._now()),
                )
                if cursor.rowcount != 1:
                    raise StaleSessionError("session is stale or expired")

    @_serialized
    async def get_session_recent(self, session_id: str) -> list[dict[str, object]]:
        async with self.pool.connection() as connection:
            session = await self._resume_with_connection(connection, session_id)
            row = await (
                await connection.execute(
                    """
                    SELECT recent_json FROM sessions
                    WHERE session_id = %s AND generation = %s
                    """,
                    (session_id, session.generation),
                )
            ).fetchone()
        values = _json_value(row[0], []) if row else []
        if not isinstance(values, list):
            return []
        return [value for value in values if isinstance(value, dict)][:30]

    @_serialized
    async def expire_session(self, session_id: str) -> None:
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                await connection.execute(
                    """
                    UPDATE sessions SET status = 'expired', expires_at = %s
                    WHERE session_id = %s AND generation = %s AND status = 'active'
                    """,
                    (self._now() - 1, session_id, generation),
                )

    @_serialized
    async def claim_refill_lease(
        self, session_id: str, owner: str, lease_ms: int = 10000
    ) -> bool:
        now = self._now()
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                cursor = await connection.execute(
                    """
                    UPDATE sessions
                    SET refill_owner = %s, refill_lease_until = %s
                    WHERE session_id = %s AND generation = %s
                      AND status = 'active' AND expires_at > %s
                      AND (refill_owner IS NULL OR refill_lease_until <= %s
                           OR refill_owner = %s)
                    """,
                    (owner, now + lease_ms, session_id, generation, now, now, owner),
                )
                return cursor.rowcount == 1

    @_serialized
    async def renew_refill_lease(
        self, session_id: str, owner: str, lease_ms: int = 10000
    ) -> None:
        now = self._now()
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                cursor = await connection.execute(
                    """
                    UPDATE sessions SET refill_lease_until = %s
                    WHERE session_id = %s AND generation = %s
                      AND status = 'active' AND expires_at > %s
                      AND refill_owner = %s AND refill_lease_until > %s
                    """,
                    (now + lease_ms, session_id, generation, now, owner, now),
                )
                if cursor.rowcount != 1:
                    raise LeaseLostError("refill lease lost")

    @_serialized
    async def release_refill_lease(self, session_id: str, owner: str) -> None:
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                cursor = await connection.execute(
                    """
                    UPDATE sessions
                    SET refill_owner = NULL, refill_lease_until = NULL
                    WHERE session_id = %s AND generation = %s
                      AND status = 'active' AND refill_owner = %s
                    """,
                    (session_id, generation, owner),
                )
                if cursor.rowcount != 1:
                    raise LeaseLostError("refill lease lost")

    @_serialized
    async def candidate_count(self, session_id: str, cursor: str | None = None) -> int:
        async with self.pool.connection() as connection:
            session = await self._resume_with_connection(connection, session_id)
            rank = (
                0
                if cursor is None
                else self._decode_cursor(cursor, session_id, session.generation)
            )
            row = await (
                await connection.execute(
                    """
                    SELECT COUNT(*)
                    FROM candidates c
                    JOIN sessions s ON s.session_id = c.session_id
                                   AND s.generation = c.generation
                    JOIN profile p ON p.singleton = 1
                                  AND p.generation = c.generation
                    WHERE c.session_id = %s AND c.generation = p.generation
                      AND s.status = 'active' AND s.expires_at > %s
                      AND c.blocked = FALSE AND c.rank >= %s
                    """,
                    (session_id, self._now(), rank),
                )
            ).fetchone()
        return int(row[0]) if row else 0

    @_serialized
    async def candidate_identities(self, session_id: str) -> set[str]:
        async with self.pool.connection() as connection:
            rows = await (
                await connection.execute(
                    """
                    SELECT strong_identity, weak_identity
                    FROM candidates WHERE session_id = %s
                    """,
                    (session_id,),
                )
            ).fetchall()
        return {str(identity) for row in rows for identity in row if identity}

    @_serialized
    async def block_candidate_identities(
        self, session_id: str, weak_identities: set[str]
    ) -> None:
        if not weak_identities:
            return
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                await connection.execute(
                    """
                    UPDATE candidates SET blocked = TRUE
                    WHERE session_id = %s AND generation = %s
                      AND weak_identity = ANY(%s)
                    """,
                    (session_id, generation, list(weak_identities)),
                )

    @_serialized
    async def append_candidates(
        self,
        session_id: str,
        owner: str,
        candidates: list[RecommendationItem],
        *,
        start_rank: int | None = None,
    ) -> None:
        now = self._now()
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                row = await (
                    await connection.execute(
                        """
                        SELECT refill_owner, refill_lease_until
                        FROM sessions
                        WHERE session_id = %s AND generation = %s
                          AND status = 'active' AND expires_at > %s
                        FOR UPDATE
                        """,
                        (session_id, generation, now),
                    )
                ).fetchone()
                if row is None:
                    raise StaleSessionError("session is stale or expired")
                if str(row[0]) != owner or row[1] is None or int(row[1]) <= now:
                    raise LeaseLostError("refill lease lost")
                if start_rank is None:
                    rank_row = await (
                        await connection.execute(
                            """
                            SELECT COALESCE(MAX(rank) + 1, 0)
                            FROM candidates
                            WHERE session_id = %s AND generation = %s
                            """,
                            (session_id, generation),
                        )
                    ).fetchone()
                    start_rank = int(rank_row[0])
                for offset, item in enumerate(candidates):
                    song = item.song.model_dump(mode="json")
                    await connection.execute(
                        """
                        INSERT INTO candidates(
                            candidate_id, session_id, generation, rank,
                            recommendation_type, song_json, strong_identity,
                            weak_identity
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            item.candidate_id,
                            session_id,
                            generation,
                            start_rank + offset,
                            item.recommendation_type,
                            Jsonb(song),
                            f"{song['online_source']}:{song['url_id']}",
                            song_weak_identity(item.song),
                        ),
                    )

    def _cursor(self, sid: str, generation: int, rank: int) -> str:
        raw = json.dumps(
            {"v": 1, "s": sid, "g": generation, "r": rank},
            separators=(",", ":"),
            sort_keys=True,
        ).encode()
        value = base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
        if len(value) > 512:
            raise InvalidCursorError("cursor too large")
        return value

    def _decode_cursor(self, cursor: str, sid: str, generation: int) -> int:
        if len(cursor) > 512:
            raise InvalidCursorError("cursor too large")
        try:
            payload = json.loads(
                base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)).decode()
            )
        except (ValueError, UnicodeDecodeError, binascii.Error) as exc:
            raise InvalidCursorError("malformed cursor") from exc
        if not isinstance(payload, dict) or payload.get("v") != 1:
            raise InvalidCursorError("unsupported cursor")
        if payload.get("s") != sid or payload.get("g") != generation:
            raise StaleSessionError("stale cursor")
        rank = payload.get("r")
        if (
            isinstance(rank, bool)
            or not isinstance(rank, int)
            or not 0 <= rank <= 2**63 - 1
        ):
            raise InvalidCursorError("invalid cursor")
        return rank

    @_serialized
    async def get_page(
        self, session_id: str, *, limit: int = 20, cursor: str | None = None
    ) -> RecommendationPageV1:
        if not 1 <= limit <= 20:
            raise ValueError("limit must be between 1 and 20")
        async with self.pool.connection() as connection:
            session = await self._resume_with_connection(connection, session_id)
            rank = (
                0
                if cursor is None
                else self._decode_cursor(cursor, session_id, session.generation)
            )
            rows = await (
                await connection.execute(
                    """
                    SELECT candidate_id, recommendation_type, song_json, rank
                    FROM candidates
                    WHERE session_id = %s AND generation = %s
                      AND blocked = FALSE AND rank >= %s
                    ORDER BY rank LIMIT %s
                    """,
                    (session_id, session.generation, rank, limit + 1),
                )
            ).fetchall()
        items = [
            RecommendationItem(
                candidate_id=str(row[0]),
                recommendation_type=str(row[1]),
                song=RecommendationSong.model_validate(_json_value(row[2], {})),
            )
            for row in rows[:limit]
        ]
        next_rank = (
            int(rows[limit][3])
            if len(rows) > limit
            else (int(rows[-1][3]) + 1 if len(rows) == limit else None)
        )
        return RecommendationPageV1(
            session_id=session_id,
            mode=session.mode,
            items=items,
            next_cursor=(
                self._cursor(session_id, session.generation, next_rank)
                if next_rank is not None
                else None
            ),
            has_more=next_rank is not None,
        )

    @_serialized
    async def insert_feedback(
        self,
        session_id: str,
        candidate_id: str,
        event: RecommendationFeedbackEvent | str,
        idempotency_key: str,
    ) -> FeedbackResult:
        event_value = (
            event.value if isinstance(event, RecommendationFeedbackEvent) else event
        )
        generation = 0
        try:
            async with self.pool.connection() as connection:
                async with connection.transaction():
                    generation = await self._generation(connection, lock=True)
                    duplicate = await (
                        await connection.execute(
                            """
                            SELECT 1 FROM feedback
                            WHERE generation = %s
                              AND (idempotency_key = %s OR
                                   (session_id = %s AND candidate_id = %s AND event = %s))
                            LIMIT 1
                            """,
                            (
                                generation,
                                idempotency_key,
                                session_id,
                                candidate_id,
                                event_value,
                            ),
                        )
                    ).fetchone()
                    if duplicate is not None:
                        return FeedbackResult(False, True)
                    row = await (
                        await connection.execute(
                            """
                            SELECT c.song_json, c.strong_identity, c.weak_identity
                            FROM candidates c
                            JOIN sessions s ON s.session_id = c.session_id
                                           AND s.generation = c.generation
                            JOIN profile p ON p.singleton = 1
                                          AND p.generation = s.generation
                            WHERE c.session_id = %s AND c.candidate_id = %s
                              AND c.generation = %s AND s.status = 'active'
                              AND s.expires_at > %s
                            """,
                            (session_id, candidate_id, generation, self._now()),
                        )
                    ).fetchone()
                    if row is None:
                        raise StaleSessionError("candidate is stale")
                    inserted = await (
                        await connection.execute(
                            """
                            INSERT INTO feedback(
                                idempotency_key, generation, session_id,
                                candidate_id, event, song_json, strong_identity,
                                weak_identity, created_at
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                            RETURNING id
                            """,
                            (
                                idempotency_key,
                                generation,
                                session_id,
                                candidate_id,
                                event_value,
                                Jsonb(_json_value(row[0], {})),
                                row[1],
                                row[2],
                                self._now(),
                            ),
                        )
                    ).fetchone()
                    assert inserted is not None
                    return FeedbackResult(True, False, int(inserted[0]), event_value)
        except UniqueViolation:
            async with self.pool.connection() as connection:
                duplicate = await (
                    await connection.execute(
                        """
                        SELECT 1 FROM feedback
                        WHERE generation = %s
                          AND (idempotency_key = %s OR
                               (session_id = %s AND candidate_id = %s AND event = %s))
                        LIMIT 1
                        """,
                        (
                            generation,
                            idempotency_key,
                            session_id,
                            candidate_id,
                            event_value,
                        ),
                    )
                ).fetchone()
            if duplicate is not None:
                return FeedbackResult(False, True)
            raise

    @_serialized
    async def get_profile(self) -> dict[str, Any]:
        async with self.pool.connection() as connection:
            row = await (
                await connection.execute(
                    "SELECT summary_json FROM profile WHERE singleton = 1"
                )
            ).fetchone()
        return dict(_json_value(row[0], {})) if row else {}

    @_serialized
    async def update_profile(
        self, summary: dict[str, Any], *, generation: int | None = None
    ) -> None:
        async with self.pool.connection() as connection:
            async with connection.transaction():
                current = await self._generation(connection, lock=True)
                if generation is not None and generation != current:
                    raise StaleSessionError("profile generation is stale")
                await connection.execute(
                    """
                    UPDATE profile SET summary_json = %s, updated_at = %s
                    WHERE singleton = 1 AND generation = %s
                    """,
                    (Jsonb(summary), self._now(), current),
                )

    @_serialized
    async def get_profile_summary(self) -> dict[str, Any]:
        async with self.pool.connection() as connection:
            profile_row = await (
                await connection.execute(
                    "SELECT generation, summary_json FROM profile WHERE singleton = 1"
                )
            ).fetchone()
            assert profile_row is not None
            generation = int(profile_row[0])
            summary = dict(_json_value(profile_row[1], {}))
            rows = await (
                await connection.execute(
                    """
                    SELECT event, song_json FROM feedback
                    WHERE generation = %s AND event IN ('completed', 'imported')
                    ORDER BY id DESC LIMIT 50
                    """,
                    (generation,),
                )
            ).fetchall()
        positive_seeds: list[dict[str, str]] = []
        artist_weights: dict[str, int] = {}
        for event, song_json in rows:
            song = _json_value(song_json, {})
            title = str(song.get("title", "")).strip()
            artist = str(song.get("artist", "")).strip()
            if title and artist:
                positive_seeds.append(
                    {"title": title, "artist": artist, "event": str(event)}
                )
                artist_weights[artist] = artist_weights.get(artist, 0) + (
                    6 if event == "imported" else 4
                )
        if positive_seeds:
            summary["positiveSeeds"] = positive_seeds
            summary["artistWeights"] = dict(
                sorted(artist_weights.items(), key=lambda item: (-item[1], item[0]))[
                    :20
                ]
            )
        return summary

    @_serialized
    async def get_exclusions(self) -> set[str]:
        async with self.pool.connection() as connection:
            generation = await self._generation(connection)
            rows = await (
                await connection.execute(
                    """
                    SELECT strong_identity, weak_identity FROM feedback
                    WHERE generation = %s
                      AND event IN ('imported', 'disliked', 'unavailable')
                    """,
                    (generation,),
                )
            ).fetchall()
        return {str(identity) for row in rows for identity in row if identity}

    @_serialized
    async def cleanup_expired(self) -> None:
        async with self.pool.connection() as connection:
            async with connection.transaction():
                generation = await self._generation(connection, lock=True)
                await connection.execute(
                    "DELETE FROM sessions WHERE generation = %s AND expires_at <= %s",
                    (generation, self._now()),
                )

    @_serialized
    async def reset(self) -> int:
        async with self.pool.connection() as connection:
            async with connection.transaction():
                row = await (
                    await connection.execute(
                        """
                        UPDATE profile
                        SET generation = generation + 1,
                            summary_json = '{}'::jsonb,
                            updated_at = %s
                        WHERE singleton = 1
                        RETURNING generation
                        """,
                        (self._now(),),
                    )
                ).fetchone()
                await connection.execute("DELETE FROM feedback")
                await connection.execute("DELETE FROM sessions")
        assert row is not None
        return int(row[0])


def _now() -> int:
    return time.time_ns() // 1_000_000
