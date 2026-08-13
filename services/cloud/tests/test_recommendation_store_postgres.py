from __future__ import annotations

import asyncio
import os
from uuid import uuid4

import pytest

from app.db.database import Database
from app.models.recommendations import RecommendationItem, RecommendationSong
from app.services.recommendation_identity import weak_identity
from app.services.recommendation_store import (
    InvalidCursorError,
    LeaseLostError,
    RecommendationStore,
    StaleSessionError,
)

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql://navidrome:navidrome_test@127.0.0.1:55432/navidrome_cloud_test",
)


def item(index: int) -> RecommendationItem:
    return RecommendationItem(
        candidate_id=f"c{index}",
        recommendation_type="similar",
        song=RecommendationSong(
            id=f"s{index}",
            title=f"Song {index}",
            album="Album",
            album_id="album",
            artist="Artist",
            artist_id="artist",
            online_source="netease",
            url_id=f"u{index}",
        ),
    )


async def open_store(now: list[int]) -> tuple[Database, RecommendationStore]:
    database = Database(TEST_DATABASE_URL, min_size=1, max_size=4)
    await database.open()
    store = RecommendationStore(
        database.pool,
        session_ttl_ms=100,
        clock_ms=lambda: now[0],
    )
    await store.initialize()
    return database, store


@pytest.mark.asyncio
async def test_store_lifecycle_paging_feedback_and_reset():
    now = [1_000_000]
    database, store = await open_store(now)
    try:
        session = await store.create_session("session-1")
        assert await store.claim_refill_lease("session-1", "owner-a", lease_ms=50)
        await store.append_candidates(
            "session-1", "owner-a", [item(1), item(2), item(3)]
        )

        first = await store.get_page("session-1", limit=2)
        assert [entry.candidate_id for entry in first.items] == ["c1", "c2"]
        assert first.has_more and first.next_cursor
        second = await store.get_page("session-1", limit=2, cursor=first.next_cursor)
        assert [entry.candidate_id for entry in second.items] == ["c3"]

        await store.block_candidate_identities(
            "session-1", {weak_identity("Song 2", "Artist")}
        )
        assert [
            entry.candidate_id for entry in (await store.get_page("session-1")).items
        ] == ["c1", "c3"]

        key = str(uuid4())
        accepted = await store.insert_feedback("session-1", "c1", "imported", key)
        duplicate = await store.insert_feedback(
            "session-1", "c1", "imported", str(uuid4())
        )
        assert accepted.accepted and not accepted.duplicate
        assert duplicate.duplicate and not duplicate.accepted
        assert await store.get_exclusions() == {
            "netease:u1",
            weak_identity("Song 1", "Artist"),
        }
        summary = await store.get_profile_summary()
        assert summary["positiveSeeds"][0]["title"] == "Song 1"

        generation = await store.reset()
        assert generation == session.generation + 1
        with pytest.raises(StaleSessionError):
            await store.resume_session("session-1")
    finally:
        await store.close()
        await database.close()


@pytest.mark.asyncio
async def test_cross_store_lease_expiry_and_recovery():
    now = [2_000_000]
    database, store_a = await open_store(now)
    store_b = RecommendationStore(
        database.pool, session_ttl_ms=100, clock_ms=lambda: now[0]
    )
    await store_b.initialize()
    try:
        await store_a.create_session("session-1")
        assert await store_a.claim_refill_lease("session-1", "owner-a", lease_ms=20)
        assert not await store_b.claim_refill_lease("session-1", "owner-b", lease_ms=20)
        now[0] += 21
        assert await store_b.claim_refill_lease("session-1", "owner-b", lease_ms=100)
        with pytest.raises(LeaseLostError):
            await store_a.append_candidates("session-1", "owner-a", [item(1)])
        await store_b.append_candidates("session-1", "owner-b", [item(1)])
    finally:
        await store_a.close()
        await store_b.close()
        await database.close()


@pytest.mark.asyncio
async def test_feedback_idempotency_across_store_instances():
    now = [3_000_000]
    database, store_a = await open_store(now)
    store_b = RecommendationStore(database.pool, clock_ms=lambda: now[0])
    await store_b.initialize()
    try:
        await store_a.create_session("session-1")
        assert await store_a.claim_refill_lease("session-1", "owner", lease_ms=100)
        await store_a.append_candidates("session-1", "owner", [item(1)])
        key = str(uuid4())
        results = await asyncio.gather(
            store_a.insert_feedback("session-1", "c1", "played", key),
            store_b.insert_feedback("session-1", "c1", "played", key),
        )
        assert sum(result.accepted for result in results) == 1
        assert sum(result.duplicate for result in results) == 1
    finally:
        await store_a.close()
        await store_b.close()
        await database.close()


@pytest.mark.asyncio
async def test_recent_context_refresh_and_cursor_validation():
    now = [4_000_000]
    database, store = await open_store(now)
    try:
        session = await store.create_session("session-1")
        recent = [
            {
                "title": "Recent",
                "artist": "Artist",
                "source": "navidrome",
                "sourceId": "song-1",
            }
        ]
        await store.set_session_recent(session.session_id, recent)
        assert await store.get_session_recent(session.session_id) == recent
        with pytest.raises(InvalidCursorError):
            await store.get_page(session.session_id, cursor="!")

        refreshed = await store.create_session(session.session_id, refresh=True)
        assert refreshed.session_id != session.session_id
        with pytest.raises(StaleSessionError):
            await store.resume_session(session.session_id)
        assert (await store.get_page(refreshed.session_id)).items == []
    finally:
        await store.close()
        await database.close()


@pytest.mark.asyncio
async def test_profile_generation_guard_and_expiry_cleanup():
    now = [5_000_000]
    database, store = await open_store(now)
    try:
        generation = await store.current_generation()
        await store.update_profile({"mood": "focus"}, generation=generation)
        assert await store.get_profile() == {"mood": "focus"}
        await store.create_session("short", ttl_ms=1)
        now[0] += 2
        await store.cleanup_expired()
        with pytest.raises(StaleSessionError):
            await store.resume_session("short")
        await store.reset()
        with pytest.raises(StaleSessionError):
            await store.update_profile({"stale": True}, generation=generation)
    finally:
        await store.close()
        await database.close()
