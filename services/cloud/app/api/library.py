from __future__ import annotations

from typing import Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.core.auth import verify_api_key
from app.core.limiter import limiter
from app.services.nas_library_client import NasAgentError, NasLibraryClient

router = APIRouter(
    prefix="/v1/library",
    tags=["library"],
    dependencies=[Depends(verify_api_key)],
)


class LibraryImportRequest(BaseModel):
    url: str = Field(min_length=1)
    filename: str = Field(min_length=1)
    song: dict[str, Any]
    picUrl: str | None = None
    lyric: str | None = None
    force: bool = False
    wait: bool = True


class LibraryDeleteRequest(BaseModel):
    song_ids: list[str] = Field(min_length=1, max_length=50)


def _library(request: Request) -> NasLibraryClient:
    library = getattr(request.app.state, "nas_library", None)
    if library is None:
        raise HTTPException(503, "Library client not initialized")
    return library


def _map_nas_error(exc: Exception) -> HTTPException:
    if isinstance(exc, NasAgentError):
        return HTTPException(exc.status_code, exc.detail)
    if isinstance(exc, httpx.TimeoutException):
        return HTTPException(504, "NAS agent timeout")
    if isinstance(exc, httpx.HTTPError):
        return HTTPException(502, "NAS agent unavailable")
    return HTTPException(502, "Library request failed")


@router.post("/import")
@limiter.limit("30/minute")
async def import_song(request: Request, body: LibraryImportRequest):
    library = _library(request)
    if not library.enabled:
        raise HTTPException(503, "Library import is not configured")
    payload = body.model_dump(exclude_none=True)
    try:
        result = await library.import_song(payload)
    except Exception as exc:  # noqa: BLE001
        raise _map_nas_error(exc) from exc
    if body.wait is False:
        return JSONResponse(result, status_code=202)
    return result


@router.get("/import/progress")
@limiter.limit("120/minute")
async def import_progress(request: Request):
    library = _library(request)
    if not library.enabled:
        raise HTTPException(503, "Library import is not configured")
    try:
        return await library.import_progress()
    except Exception as exc:  # noqa: BLE001
        raise _map_nas_error(exc) from exc


@router.post("/delete")
@limiter.limit("30/minute")
async def delete_songs(request: Request, body: LibraryDeleteRequest):
    library = _library(request)
    if not library.enabled:
        raise HTTPException(503, "Library delete is not configured")
    try:
        return await library.delete_songs(body.song_ids)
    except Exception as exc:  # noqa: BLE001
        raise _map_nas_error(exc) from exc
