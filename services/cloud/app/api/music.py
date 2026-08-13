from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from app.core.auth import verify_api_key
from app.core.limiter import limiter
from app.core.sources import canonicalize_music_source
from app.models.schemas import (
    CoverResponse,
    LyricResponse,
    MusicCapabilitiesResponse,
    SearchResponse,
    UrlResponse,
)
from app.services.music_facade import MusicSearchSelectionError

router = APIRouter(
    prefix="/v1/music",
    tags=["music"],
    dependencies=[Depends(verify_api_key)],
)


def _facade(request: Request):
    facade = getattr(request.app.state, "music_facade", None)
    if facade is None:
        raise HTTPException(503, "Music facade not initialized")
    return facade


def _map_upstream(exc: Exception) -> HTTPException:
    if isinstance(exc, httpx.TimeoutException):
        return HTTPException(504, "upstream API timeout")
    if isinstance(exc, httpx.HTTPStatusError):
        return HTTPException(502, f"upstream API error: {exc.response.status_code}")
    if isinstance(exc, httpx.HTTPError):
        return HTTPException(502, f"upstream API error: {exc}")
    return HTTPException(502, f"music upstream failure: {exc}")


@router.get(
    "/capabilities",
    response_model=MusicCapabilitiesResponse,
    summary="Configured music adapters and supported platforms",
)
async def capabilities(request: Request):
    return _facade(request).capabilities()


@router.get("/search", response_model=SearchResponse, summary="First-success search")
@limiter.limit("60/minute")
async def search(
    request: Request,
    q: str = Query(..., min_length=1, max_length=200, description="Search query"),
    source: str | None = Query(
        None,
        description="Pinned platform when set; omit to walk MUSIC_SEARCH_SOURCES",
    ),
    provider: str | None = Query(
        None,
        description="Pinned adapter id; omit for configured adapter failover",
    ),
    count: int = Query(20, ge=1, le=50),
    page: int = Query(1, ge=1),
):
    """One user query -> one result list from the first successful upstream."""
    facade = _facade(request)
    try:
        return await facade.search_first_success(
            q,
            source=canonicalize_music_source(source),
            provider=provider.strip().lower() if provider else None,
            count=count,
            page=page,
        )
    except HTTPException:
        raise
    except MusicSearchSelectionError as exc:
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise _map_upstream(exc) from exc


@router.get("/url", response_model=UrlResponse)
@limiter.limit("60/minute")
async def get_url(
    request: Request,
    id: str = Query(...),
    source: str = Query(...),
    br: int = Query(999, ge=128),
    provider: str | None = Query(None),
):
    facade = _facade(request)
    try:
        return await facade.get_url(
            id,
            source=canonicalize_music_source(source) or source,
            br=br,
            provider=provider,
        )
    except Exception as exc:  # noqa: BLE001
        raise _map_upstream(exc) from exc


@router.get("/cover", response_model=CoverResponse)
@limiter.limit("60/minute")
async def get_cover(
    request: Request,
    id: str = Query(...),
    source: str = Query(...),
    size: int = Query(300, ge=100, le=1000),
    provider: str | None = Query(None),
):
    facade = _facade(request)
    try:
        return await facade.get_cover(
            id,
            source=canonicalize_music_source(source) or source,
            size=size,
            provider=provider,
        )
    except Exception as exc:  # noqa: BLE001
        raise _map_upstream(exc) from exc


@router.get("/lyric", response_model=LyricResponse)
@limiter.limit("60/minute")
async def get_lyric(
    request: Request,
    id: str = Query(...),
    source: str = Query(...),
    provider: str | None = Query(None),
):
    facade = _facade(request)
    try:
        return await facade.get_lyric(
            id,
            source=canonicalize_music_source(source) or source,
            provider=provider,
        )
    except Exception as exc:  # noqa: BLE001
        raise _map_upstream(exc) from exc
