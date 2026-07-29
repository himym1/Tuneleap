from __future__ import annotations

from fastapi import APIRouter, Depends, Path, Query, Request
from slowapi.errors import RateLimitExceeded

from app.core.recommendation_errors import RecommendationSessionExpired, RecommendationTemporarilyUnavailable
from app.core.auth import verify_api_key
from app.core.limiter import limiter
from app.core.recommendation_http import error_response
from app.models.recommendations import (
    RecommendationFeedbackRequest,
    RecommendationFeedbackResponse,
    RecommendationPageV1,
    RecommendationSessionCreateRequest,
)
from app.services.recommendation_service import RecommendationService
from app.services.recommendation_store import InvalidCursorError, LeaseLostError, StaleSessionError

router = APIRouter(prefix="/v1/recommendations", tags=["recommendations"], dependencies=[Depends(verify_api_key)])


def get_recommendation_service(request: Request) -> RecommendationService:
    return request.app.state.recommendation_service


def _page_or_unavailable(page: RecommendationPageV1) -> RecommendationPageV1:
    if not page.items and not page.has_more:
        raise RecommendationTemporarilyUnavailable()
    return page


@router.post("/sessions", response_model=RecommendationPageV1)
@limiter.limit("5/minute")
async def create_session(request: Request, payload: RecommendationSessionCreateRequest, service: RecommendationService = Depends(get_recommendation_service)) -> RecommendationPageV1:
    try:
        return _page_or_unavailable(await service.create_or_resume(payload.recent, page_size=payload.page_size, refresh=payload.refresh))
    except ValueError as exc:
        raise ValueError("invalid recommendation request") from exc


@router.get("/sessions/{session_id}/items", response_model=RecommendationPageV1)
@limiter.limit("60/minute")
async def get_session_page(request: Request, session_id: str = Path(..., max_length=128), limit: int = Query(20, ge=1, le=20), cursor: str | None = Query(None, max_length=512), service: RecommendationService = Depends(get_recommendation_service)) -> RecommendationPageV1:
    try:
        return await service.get_page(session_id, limit=limit, cursor=cursor)
    except (InvalidCursorError, ValueError) as exc:
        raise ValueError("invalid recommendation request") from exc
    except (StaleSessionError, LeaseLostError) as exc:
        raise RecommendationSessionExpired() from exc


@router.post("/feedback", response_model=RecommendationFeedbackResponse)
@limiter.limit("120/minute")
async def feedback(request: Request, payload: RecommendationFeedbackRequest, service: RecommendationService = Depends(get_recommendation_service)) -> RecommendationFeedbackResponse:
    try:
        result = await service.feedback(payload.session_id, payload.candidate_id, payload.event, str(payload.idempotency_key))
    except (StaleSessionError, LeaseLostError) as exc:
        raise RecommendationSessionExpired() from exc
    return RecommendationFeedbackResponse(accepted=bool(result.accepted), duplicate=bool(result.duplicate))


@router.delete("/profile")
@limiter.limit("2/minute")
async def reset(request: Request, service: RecommendationService = Depends(get_recommendation_service)) -> dict[str, object]:
    await service.reset()
    return {"contractVersion": 1, "reset": True}
