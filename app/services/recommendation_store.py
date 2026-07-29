"""Durable recommendation state and cross-worker refill leases."""
from __future__ import annotations

import asyncio
import base64
import binascii
import functools
import json
import secrets
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Awaitable, Callable, TypeVar

import aiosqlite

from app.models.recommendations import (
    RecommendationFeedbackEvent,
    RecommendationItem,
    RecommendationPageV1,
    RecommendationSong,
)
from app.services.recommendation_identity import weak_identity



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
    async def wrapper(self: "RecommendationStore", *args: Any, **kwargs: Any) -> _T:
        async with self._lock:
            return await method(self, *args, **kwargs)

    return wrapper


class RecommendationStore:
    CURSOR_VERSION = 1

    def __init__(self, path: str | Path, *, session_ttl_ms: int = 24 * 60 * 60 * 1000, clock_ms: Callable[[], int] | None = None):
        self.path = Path(path)
        self.session_ttl_ms = session_ttl_ms
        self.clock_ms = clock_ms or _now
        self._db: aiosqlite.Connection | None = None
        self._lock = asyncio.Lock()

    @property
    def db(self) -> aiosqlite.Connection:
        if self._db is None:
            raise RuntimeError("store is not initialized")
        return self._db

    def _now(self) -> int:
        return int(self.clock_ms())

    @_serialized
    async def initialize(self) -> None:
        if self._db is not None:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        connection = await aiosqlite.connect(self.path)
        self._db = connection
        try:
            await connection.execute("PRAGMA foreign_keys=ON")
            await connection.execute("PRAGMA journal_mode=WAL")
            await connection.execute("PRAGMA busy_timeout=5000")
            await connection.execute("BEGIN IMMEDIATE")
            await connection.execute(
                "CREATE TABLE IF NOT EXISTS profile ("
                "singleton INTEGER PRIMARY KEY CHECK(singleton=1), "
                "generation INTEGER NOT NULL, "
                "summary_json TEXT NOT NULL DEFAULT '{}', "
                "updated_at INTEGER NOT NULL DEFAULT 0)"
            )
            await connection.execute("CREATE TABLE IF NOT EXISTS sessions (session_id TEXT PRIMARY KEY, generation INTEGER NOT NULL, mode TEXT NOT NULL, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','ended','expired')), refill_owner TEXT, refill_lease_until INTEGER, recent_json TEXT NOT NULL DEFAULT '[]')")
            session_columns = {
                row[1]
                for row in await (
                    await connection.execute("PRAGMA table_info(sessions)")
                ).fetchall()
            }
            if "recent_json" not in session_columns:
                await connection.execute(
                    "ALTER TABLE sessions ADD COLUMN recent_json TEXT NOT NULL DEFAULT '[]'"
                )
            await connection.execute("UPDATE sessions SET mode='fallback' WHERE mode='ai'")
            await connection.execute("CREATE TABLE IF NOT EXISTS candidates (candidate_id TEXT NOT NULL, session_id TEXT NOT NULL, generation INTEGER NOT NULL, rank INTEGER NOT NULL, recommendation_type TEXT NOT NULL, song_json TEXT NOT NULL, strong_identity TEXT NOT NULL, weak_identity TEXT NOT NULL, blocked INTEGER NOT NULL DEFAULT 0, served INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(session_id,candidate_id), UNIQUE(session_id,generation,rank), FOREIGN KEY(session_id) REFERENCES sessions(session_id) ON DELETE CASCADE)")
            await connection.execute("CREATE TABLE IF NOT EXISTS feedback (id INTEGER PRIMARY KEY AUTOINCREMENT, idempotency_key TEXT NOT NULL UNIQUE, generation INTEGER NOT NULL, session_id TEXT NOT NULL, candidate_id TEXT NOT NULL, event TEXT NOT NULL, song_json TEXT NOT NULL, strong_identity TEXT NOT NULL, weak_identity TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE(generation,session_id,candidate_id,event))")
            await connection.execute("CREATE INDEX IF NOT EXISTS idx_feedback_generation_event_identity ON feedback(generation,event,strong_identity)")
            await connection.execute("CREATE INDEX IF NOT EXISTS idx_candidates_session_generation_blocked_rank ON candidates(session_id,generation,blocked,rank)")
            await connection.execute("CREATE INDEX IF NOT EXISTS idx_sessions_generation_expires_at ON sessions(generation,expires_at)")
            await connection.execute("INSERT OR IGNORE INTO profile(singleton,generation,summary_json,updated_at) VALUES(1,0,'{}',?)", (self._now(),))
            for table in ("candidates", "feedback"):
                rows = await (await connection.execute(
                    f"SELECT rowid,song_json,weak_identity FROM {table}"
                )).fetchall()
                updates = []
                for row_id, song_json, stored_identity in rows:
                    normalized_identity = weak_identity(json.loads(song_json))
                    if normalized_identity != stored_identity:
                        updates.append((normalized_identity, row_id))
                if updates:
                    await connection.executemany(
                        f"UPDATE {table} SET weak_identity=? WHERE rowid=?", updates
                    )
            await connection.commit()
        except Exception:
            await connection.rollback()
            await connection.close()
            self._db = None
            raise

    @_serialized
    async def close(self) -> None:
        if self._db is not None:
            await self._db.close()
            self._db = None

    @_serialized
    async def current_generation(self) -> int:
        row = await (await self.db.execute("SELECT generation FROM profile WHERE singleton=1")).fetchone()
        return int(row[0])

    async def _begin(self) -> int:
        begun = False
        try:
            await self.db.execute("BEGIN IMMEDIATE")
            begun = True
            row = await (await self.db.execute("SELECT generation FROM profile WHERE singleton=1")).fetchone()
            return int(row[0])
        except Exception:
            if begun:
                await self.db.rollback()
            raise

    @_serialized
    async def create_session(self, session_id: str | None = None, *, mode: str = "fallback", refresh: bool = False, ttl_ms: int | None = None) -> Session:
        sid = session_id or secrets.token_urlsafe(16)
        generation = await self._begin()
        now = self._now(); expires = now + (self.session_ttl_ms if ttl_ms is None else ttl_ms)
        try:
            old = await (await self.db.execute("SELECT generation,status FROM sessions WHERE session_id=?", (sid,))).fetchone()
            if old and old[0] != generation: raise StaleSessionError("session belongs to an old generation")
            if refresh and session_id is not None and old is None: raise StaleSessionError("session does not exist")
            if old and not refresh:
                row = await (await self.db.execute("SELECT session_id,generation,mode,created_at,expires_at,status FROM sessions WHERE session_id=?", (sid,))).fetchone()
                await self.db.commit()
                if row[5] != 'active' or row[4] <= now: raise StaleSessionError("session is not active")
                return Session(*row)
            if old:
                if old[1] != 'active': raise StaleSessionError("session is not active")
                cur = await self.db.execute("UPDATE sessions SET status='ended',refill_owner=NULL,refill_lease_until=NULL WHERE session_id=? AND generation=? AND status='active' AND expires_at>?", (sid, generation, now))
                if cur.rowcount != 1: raise StaleSessionError("session is stale or no longer active")
                sid = secrets.token_urlsafe(16)
            await self.db.execute("INSERT INTO sessions(session_id,generation,mode,created_at,expires_at,status,refill_owner,refill_lease_until) VALUES(?,?,?,?,?,'active',NULL,NULL)", (sid,generation,mode,now,expires))
            await self.db.commit()
            return Session(sid,generation,mode,now,expires,'active')
        except Exception:
            await self.db.rollback(); raise

    async def _resume_session_unlocked(self, session_id: str) -> Session:
        row = await (await self.db.execute("SELECT s.session_id,s.generation,s.mode,s.created_at,s.expires_at,s.status FROM sessions s JOIN profile p ON p.singleton=1 AND p.generation=s.generation WHERE s.session_id=? AND s.status='active' AND s.expires_at>?", (session_id,self._now()))).fetchone()
        if not row: raise StaleSessionError("session is stale or expired")
        return Session(*row)

    @_serialized
    async def resume_session(self, session_id: str) -> Session:
        return await self._resume_session_unlocked(session_id)

    @_serialized
    async def get_active_session(self) -> Session | None:
        row = await (await self.db.execute(
            "SELECT s.session_id,s.generation,s.mode,s.created_at,s.expires_at,s.status "
            "FROM sessions s JOIN profile p ON p.singleton=1 AND p.generation=s.generation "
            "WHERE s.status='active' AND s.expires_at>? ORDER BY s.created_at DESC LIMIT 1",
            (self._now(),),
        )).fetchone()
        return Session(*row) if row else None

    @_serialized
    async def set_session_mode(self, session_id: str, mode: str) -> None:
        if mode != "fallback":
            raise ValueError("invalid recommendation mode")
        generation = await self._begin()
        try:
            cur = await self.db.execute(
                "UPDATE sessions SET mode=? WHERE session_id=? AND generation=? AND status='active' AND expires_at>?",
                (mode, session_id, generation, self._now()),
            )
            if cur.rowcount != 1:
                raise StaleSessionError('session is stale or expired')
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

    @_serialized
    async def set_session_recent(
        self, session_id: str, recent: list[dict[str, object]]
    ) -> None:
        generation = await self._begin()
        try:
            cursor = await self.db.execute(
                "UPDATE sessions SET recent_json=? WHERE session_id=? AND generation=? "
                "AND status='active' AND expires_at>?",
                (
                    json.dumps(recent[:30], separators=(",", ":"), sort_keys=True),
                    session_id,
                    generation,
                    self._now(),
                ),
            )
            if cursor.rowcount != 1:
                raise StaleSessionError("session is stale or expired")
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

    @_serialized
    async def get_session_recent(
        self, session_id: str
    ) -> list[dict[str, object]]:
        session = await self._resume_session_unlocked(session_id)
        row = await (
            await self.db.execute(
                "SELECT recent_json FROM sessions WHERE session_id=? AND generation=?",
                (session_id, session.generation),
            )
        ).fetchone()
        values = json.loads(row[0]) if row else []
        if not isinstance(values, list):
            return []
        return [value for value in values if isinstance(value, dict)][:30]

    @_serialized
    async def expire_session(self, session_id: str) -> None:
        generation = await self._begin()
        try:
            await self.db.execute("UPDATE sessions SET status='expired',expires_at=? WHERE session_id=? AND generation=? AND status='active'", (self._now()-1,session_id,generation)); await self.db.commit()
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def claim_refill_lease(self, session_id: str, owner: str, lease_ms: int = 10000) -> bool:
        now = self._now(); generation = await self._begin()
        try:
            cur = await self.db.execute("UPDATE sessions SET refill_owner=?,refill_lease_until=? WHERE session_id=? AND generation=? AND status='active' AND expires_at>? AND (refill_owner IS NULL OR refill_lease_until<=? OR refill_owner=?)", (owner,now+lease_ms,session_id,generation,now,now,owner)); await self.db.commit(); return cur.rowcount == 1
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def renew_refill_lease(self, session_id: str, owner: str, lease_ms: int = 10000) -> None:
        now=self._now(); generation=await self._begin()
        try:
            cur=await self.db.execute("UPDATE sessions SET refill_lease_until=? WHERE session_id=? AND generation=? AND status='active' AND expires_at>? AND refill_owner=? AND refill_lease_until>?",(now+lease_ms,session_id,generation,now,owner,now)); await self.db.commit()
            if cur.rowcount != 1: raise LeaseLostError("refill lease lost")
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def release_refill_lease(self, session_id: str, owner: str) -> None:
        generation=await self._begin()
        try:
            cur=await self.db.execute("UPDATE sessions SET refill_owner=NULL,refill_lease_until=NULL WHERE session_id=? AND generation=? AND status='active' AND refill_owner=?",(session_id,generation,owner)); await self.db.commit()
            if cur.rowcount != 1: raise LeaseLostError("refill lease lost")
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def candidate_count(self, session_id: str, cursor: str | None = None) -> int:
        session = await self._resume_session_unlocked(session_id)
        rank = 0 if cursor is None else self._decode_cursor(cursor, session_id, session.generation)
        row = await (await self.db.execute(
            "SELECT COUNT(*) FROM candidates c JOIN sessions s ON s.session_id=c.session_id "
            "AND s.generation=c.generation JOIN profile p ON p.singleton=1 "
            "AND p.generation=c.generation WHERE c.session_id=? AND c.generation=p.generation "
            "AND s.status='active' AND s.expires_at>? AND c.blocked=0 AND c.rank>=?",
            (session_id, self._now(), rank),
        )).fetchone()
        return int(row[0]) if row else 0

    @_serialized
    async def candidate_identities(self, session_id: str) -> set[str]:
        rows = await (await self.db.execute("SELECT strong_identity, weak_identity FROM candidates WHERE session_id=?", (session_id,))).fetchall()
        return {identity for row in rows for identity in row if identity}

    @_serialized
    async def block_candidate_identities(
        self, session_id: str, weak_identities: set[str]
    ) -> None:
        if not weak_identities:
            return
        generation = await self._begin()
        try:
            identities = tuple(weak_identities)
            for offset in range(0, len(identities), 500):
                chunk = identities[offset : offset + 500]
                placeholders = ",".join("?" for _ in chunk)
                await self.db.execute(
                    "UPDATE candidates SET blocked=1 "
                    "WHERE session_id=? AND generation=? "
                    f"AND weak_identity IN ({placeholders})",
                    (session_id, generation, *chunk),
                )
            await self.db.commit()
        except Exception:
            await self.db.rollback()
            raise

    @_serialized
    async def append_candidates(self, session_id: str, owner: str, candidates: list[RecommendationItem], *, start_rank: int | None = None) -> None:
        now=self._now(); generation=await self._begin()
        try:
            row=await (await self.db.execute("SELECT refill_owner,refill_lease_until FROM sessions WHERE session_id=? AND generation=? AND status='active' AND expires_at>?",(session_id,generation,now))).fetchone()
            if not row: raise StaleSessionError("session is stale or expired")
            if row[0] != owner or row[1] is None or row[1] <= now: raise LeaseLostError("refill lease lost")
            if start_rank is None: start_rank=int((await (await self.db.execute("SELECT COALESCE(MAX(rank)+1,0) FROM candidates WHERE session_id=? AND generation=?",(session_id,generation))).fetchone())[0])
            for off,item in enumerate(candidates):
                song=item.song.model_dump(mode="json")
                await self.db.execute("INSERT INTO candidates(candidate_id,session_id,generation,rank,recommendation_type,song_json,strong_identity,weak_identity) VALUES(?,?,?,?,?,?,?,?)",(item.candidate_id,session_id,generation,start_rank+off,item.recommendation_type,json.dumps(song,separators=(",",":"),sort_keys=True),f"{song['online_source']}:{song['url_id']}",weak_identity(item.song)))
            await self.db.commit()
        except Exception: await self.db.rollback(); raise

    def _cursor(self,sid:str,generation:int,rank:int)->str:
        raw=json.dumps({"v":1,"s":sid,"g":generation,"r":rank},separators=(",",":"),sort_keys=True).encode(); value=base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
        if len(value)>512: raise InvalidCursorError("cursor too large")
        return value

    def _decode_cursor(self,cursor:str,sid:str,generation:int)->int:
        if len(cursor)>512: raise InvalidCursorError("cursor too large")
        try: payload=json.loads(base64.urlsafe_b64decode(cursor+"="*(-len(cursor)%4)).decode())
        except (ValueError,UnicodeDecodeError,binascii.Error) as exc: raise InvalidCursorError("malformed cursor") from exc
        if not isinstance(payload,dict) or payload.get("v")!=1: raise InvalidCursorError("unsupported cursor")
        if payload.get("s")!=sid or payload.get("g")!=generation: raise StaleSessionError("stale cursor")
        rank=payload.get("r")
        if isinstance(rank,bool) or not isinstance(rank,int) or not 0 <= rank <= 2**63 - 1: raise InvalidCursorError("invalid cursor")
        return rank

    @_serialized
    async def get_page(self, session_id:str, *, limit:int=20, cursor:str|None=None)->RecommendationPageV1:
        if not 1<=limit<=20: raise ValueError("limit must be between 1 and 20")
        session=await self._resume_session_unlocked(session_id); rank=0 if cursor is None else self._decode_cursor(cursor,session_id,session.generation)
        rows=await (await self.db.execute("SELECT candidate_id,recommendation_type,song_json,rank FROM candidates WHERE session_id=? AND generation=? AND blocked=0 AND rank>=? ORDER BY rank LIMIT ?",(session_id,session.generation,rank,limit+1))).fetchall()
        items=[RecommendationItem(candidate_id=r[0],recommendation_type=r[1],song=RecommendationSong.model_validate(json.loads(r[2]))) for r in rows[:limit]]
        next_rank = rows[limit][3] if len(rows)>limit else (rows[-1][3] + 1 if len(rows) == limit else None)
        return RecommendationPageV1(session_id=session_id,mode=session.mode,items=items,next_cursor=self._cursor(session_id,session.generation,next_rank) if next_rank is not None else None,has_more=next_rank is not None)

    @_serialized
    async def insert_feedback(self, session_id:str,candidate_id:str,event:RecommendationFeedbackEvent|str,idempotency_key:str)->FeedbackResult:
        generation=await self._begin(); now=self._now(); event_value=event.value if isinstance(event,RecommendationFeedbackEvent) else event
        try:
            duplicate = await (await self.db.execute("SELECT 1 FROM feedback WHERE generation=? AND (idempotency_key=? OR (session_id=? AND candidate_id=? AND event=?)) LIMIT 1",(generation,idempotency_key,session_id,candidate_id,event_value))).fetchone()
            if duplicate:
                await self.db.rollback()
                return FeedbackResult(False,True)
            row=await (await self.db.execute("SELECT c.song_json,c.strong_identity,c.weak_identity FROM candidates c JOIN sessions s ON s.session_id=c.session_id AND s.generation=c.generation JOIN profile p ON p.singleton=1 AND p.generation=s.generation WHERE c.session_id=? AND c.candidate_id=? AND c.generation=? AND s.status='active' AND s.expires_at>?",(session_id,candidate_id,generation,now))).fetchone()
            if not row: raise StaleSessionError("candidate is stale")
            cursor = await self.db.execute("INSERT INTO feedback(idempotency_key,generation,session_id,candidate_id,event,song_json,strong_identity,weak_identity,created_at) VALUES(?,?,?,?,?,?,?,?,?)",(idempotency_key,generation,session_id,candidate_id,event_value,row[0],row[1],row[2],now))
            await self.db.commit()
            return FeedbackResult(True,False,int(cursor.lastrowid),event_value)
        except aiosqlite.IntegrityError as exc:
            await self.db.rollback()
            duplicate = await (await self.db.execute("SELECT 1 FROM feedback WHERE generation=? AND (idempotency_key=? OR (session_id=? AND candidate_id=? AND event=?)) LIMIT 1",(generation,idempotency_key,session_id,candidate_id,event_value))).fetchone()
            if duplicate: return FeedbackResult(False,True)
            raise exc
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def get_profile(self)->dict[str,Any]:
        row=await (await self.db.execute("SELECT summary_json FROM profile WHERE singleton=1")).fetchone(); return json.loads(row[0])

    @_serialized
    async def update_profile(self, summary: dict[str,Any], *, generation: int|None=None) -> None:
        current=await self._begin()
        try:
            if generation is not None and generation != current: raise StaleSessionError("profile generation is stale")
            await self.db.execute("UPDATE profile SET summary_json=?,updated_at=? WHERE singleton=1 AND generation=?",(json.dumps(summary,separators=(",",":"),sort_keys=True),self._now(),current)); await self.db.commit()
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def get_profile_summary(self)->dict[str,Any]:
        profile_row = await (await self.db.execute(
            "SELECT generation,summary_json FROM profile WHERE singleton=1"
        )).fetchone()
        generation = int(profile_row[0])
        summary = json.loads(profile_row[1])
        rows = await (await self.db.execute(
            "SELECT event,song_json FROM feedback "
            "WHERE generation=? AND event IN ('completed','imported') "
            "ORDER BY id DESC LIMIT 50",
            (generation,),
        )).fetchall()
        positive_seeds: list[dict[str, str]] = []
        artist_weights: dict[str, int] = {}
        for event, song_json in rows:
            song = json.loads(song_json)
            title = str(song.get("title", "")).strip()
            artist = str(song.get("artist", "")).strip()
            if title and artist:
                positive_seeds.append({"title": title, "artist": artist, "event": event})
                artist_weights[artist] = artist_weights.get(artist, 0) + (6 if event == "imported" else 4)
        if positive_seeds:
            summary["positiveSeeds"] = positive_seeds
            summary["artistWeights"] = dict(
                sorted(artist_weights.items(), key=lambda item: (-item[1], item[0]))[:20]
            )
        return summary


    @_serialized
    async def get_exclusions(self)->set[str]:
        row=await (await self.db.execute("SELECT generation FROM profile WHERE singleton=1")).fetchone(); generation=int(row[0])
        rows=await (await self.db.execute("SELECT strong_identity,weak_identity FROM feedback WHERE generation=? AND event IN ('imported','disliked','unavailable')",(generation,))).fetchall(); return {identity for row in rows for identity in row if identity}

    @_serialized
    async def cleanup_expired(self)->None:
        generation=await self._begin()
        try: await self.db.execute("DELETE FROM sessions WHERE generation=? AND expires_at<=?",(generation,self._now())); await self.db.commit()
        except Exception: await self.db.rollback(); raise

    @_serialized
    async def reset(self)->int:
        await self.db.execute("BEGIN IMMEDIATE")
        try:
            await self.db.execute(
                "UPDATE profile SET generation=generation+1,summary_json='{}',"
                "updated_at=? WHERE singleton=1",
                (self._now(),),
            )
            await self.db.execute("DELETE FROM feedback")
            await self.db.execute("DELETE FROM sessions")
            await self.db.commit()
        except Exception: await self.db.rollback(); raise
        row = await (await self.db.execute("SELECT generation FROM profile WHERE singleton=1")).fetchone()
        return int(row[0])


def _now()->int: return time.time_ns()//1_000_000
