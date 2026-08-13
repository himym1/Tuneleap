import httpx
import pytest

from app.services.recommendation_service import RecommendationService


class _UnavailableLibrary:
    async def recommendation_weak_identities(self) -> set[str]:
        raise httpx.RemoteProtocolError("disconnected")


class _RecordingStore:
    blocked: set[str] | None = None

    async def block_candidate_identities(
        self, session_id: str, weak_identities: set[str]
    ) -> None:
        self.blocked = weak_identities


@pytest.mark.asyncio
async def test_library_transport_failure_does_not_fail_recommendation_request():
    store = _RecordingStore()
    service = RecommendationService(
        store=store,  # type: ignore[arg-type]
        music_proxy=object(),  # type: ignore[arg-type]
        library=_UnavailableLibrary(),
    )

    await service._block_library_candidates("session-1")

    assert store.blocked == set()
