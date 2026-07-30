import httpx
from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import verify_agent_key
from app.models.schemas import ImportRequest, ImportResult, ScanResult
from app.services.importer import (
    DownloadTooLargeError,
    DuplicateCheckUnavailableError,
    DuplicateTrackError,
    InsufficientStorageError,
    UpstreamContentError,
)
from app.services.library import ScanNotConfiguredError, ScanRejectedError

router = APIRouter(
    prefix="/v1/nas",
    tags=["nas"],
    dependencies=[Depends(verify_agent_key)],
)


def _importer(request: Request):
    service = getattr(request.app.state, "importer", None)
    if service is None:
        raise HTTPException(503, "Importer not initialized")
    return service


def _library(request: Request):
    service = getattr(request.app.state, "library", None)
    if service is None:
        raise HTTPException(503, "Library service not initialized")
    return service


@router.post("/import", response_model=ImportResult, summary="Download audio onto NAS")
async def nas_import(request: Request, body: ImportRequest):
    importer = _importer(request)
    try:
        return await importer.import_track(
            url=body.url,
            filename=body.filename,
            song=body.song,
            pic_url=body.pic_url,
            lyric=body.lyric,
            force=body.force,
        )
    except DuplicateTrackError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except DuplicateCheckUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except DownloadTooLargeError as exc:
        raise HTTPException(status_code=413, detail=str(exc)) from exc
    except InsufficientStorageError as exc:
        raise HTTPException(status_code=507, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="media download timed out") from exc
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"media upstream returned {exc.response.status_code}",
        ) from exc
    except (httpx.TooManyRedirects, UpstreamContentError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except OSError as exc:
        raise HTTPException(status_code=500, detail="media file write failed") from exc


@router.post("/scan", response_model=ScanResult, summary="Trigger Navidrome rescan")
async def nas_scan(request: Request):
    library = _library(request)
    try:
        status = await library.trigger_scan()
    except ScanNotConfiguredError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ScanRejectedError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="Navidrome scan timed out") from exc
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Navidrome returned {exc.response.status_code}",
        ) from exc

    scanning = status.get("scanning")
    count = status.get("count")
    return ScanResult(ok=True, message=f"scan started: scanning={scanning}, count={count}")
