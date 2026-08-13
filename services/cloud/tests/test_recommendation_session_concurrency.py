import asyncio

import pytest

from app.models.recommendations import RecommendationPageV1
from app.services.recommendation_service import RecommendationService
from app.services.recommendation_store import Session, StaleSessionError


class _RacingStore:
    def __init__(self) -> None:
        self.active = Session("initial", 1, "fallback", 0, 1_000_000, "active")
        self.created = 0

    def _require_active(self, session_id: str) -> None:
        if self.active.session_id != session_id:
            raise StaleSessionError("session is stale or expired")

    async def get_active_session(self) -> Session:
        return self.active

    async def create_session(
        self,
        session_id: str | None = None,
        *,
        refresh: bool = False,
    ) -> Session:
        if refresh and session_id != self.active.session_id:
            raise StaleSessionError("session is stale or expired")
        self.created += 1
        self.active = Session(
            f"session-{self.created}", 1, "fallback", 0, 1_000_000, "active"
        )
        return self.active

    async def set_session_recent(
        self, session_id: str, recent: list[dict[str, object]]
    ) -> None:
        await asyncio.sleep(0.01)
        self._require_active(session_id)

    async def block_candidate_identities(
        self, session_id: str, weak_identities: set[str]
    ) -> None:
        self._require_active(session_id)

    async def candidate_count(self, session_id: str, cursor: str | None = None) -> int:
        self._require_active(session_id)
        return 20

    async def get_page(
        self, session_id: str, *, limit: int = 20, cursor: str | None = None
    ) -> RecommendationPageV1:
        self._require_active(session_id)
        return RecommendationPageV1(
            session_id=session_id,
            mode="fallback",
            items=[],
            next_cursor=None,
            has_more=False,
        )


@pytest.mark.asyncio
async def test_concurrent_refresh_requests_do_not_stale_each_other():
    store = _RacingStore()
    service = RecommendationService(
        store=store,  # type: ignore[arg-type]
        music_proxy=object(),  # type: ignore[arg-type]
        pool_target=20,
    )

    first, second = await asyncio.gather(
        service.create_or_resume(refresh=True),
        service.create_or_resume(refresh=True),
    )

    assert first.session_id == "session-1"
    assert second.session_id == "session-2"
    assert store.created == 2
