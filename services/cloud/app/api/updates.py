"""Private update endpoints — serve RELEASE_DIR with path traversal guards."""

from __future__ import annotations

import re
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse

from app.core.auth import verify_api_key
from app.core.config import get_settings

router = APIRouter(tags=["updates"], dependencies=[Depends(verify_api_key)])

_RELEASE_NAME = re.compile(
    r"^navidrome_player-\d+\.\d+\.\d+\+\d+-(?:android\.apk|macos\.dmg|windows\.zip)$"
)


def _release_root() -> Path:
    return Path(get_settings().release_dir).resolve()


def _release_file(filename: str) -> Path:
    if filename != "SHA256SUMS" and not _RELEASE_NAME.fullmatch(filename):
        raise HTTPException(status_code=404, detail="Release file not found")
    root = _release_root()
    candidate = root / filename
    if candidate.is_symlink():
        raise HTTPException(status_code=404, detail="Release file not found")
    path = candidate.resolve()
    if path.parent != root or not path.is_file():
        raise HTTPException(status_code=404, detail="Release file not found")
    return path


@router.get("/version.json", include_in_schema=False)
async def version_metadata() -> FileResponse:
    root = _release_root()
    candidate = root / "version.json"
    if candidate.is_symlink():
        raise HTTPException(status_code=404, detail="Release metadata not found")
    path = candidate.resolve()
    if path.parent != root or not path.is_file():
        raise HTTPException(status_code=404, detail="Release metadata not found")
    return FileResponse(
        path,
        media_type="application/json",
        headers={"Cache-Control": "no-store"},
    )


@router.get("/releases/{filename}", include_in_schema=False)
async def release_file(filename: str) -> FileResponse:
    path = _release_file(filename)
    return FileResponse(
        path,
        filename=filename,
        headers={"Cache-Control": "private, max-age=3600"},
    )
