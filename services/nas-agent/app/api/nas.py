import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse

from app.core.auth import verify_agent_key
from app.models.schemas import (
    ImportProgress,
    ImportRequest,
    ImportResult,
    LibraryAuditDeepRequest,
    LibraryAuditFindingsResponse,
    LibraryAuditSnapshot,
    LibraryAuditStartRequest,
    ScanResult,
)
from app.services.importer import (
    DownloadTooLargeError,
    DuplicateCheckUnavailableError,
    DuplicateTrackError,
    ImportBusyError,
    InsufficientStorageError,
    UpstreamContentError,
)
from app.services.library import (
    DatabaseUnavailableError,
    ScanNotConfiguredError,
    ScanRejectedError,
)
from app.services.library_audit import LibraryAuditRules
from app.services.library_audit_job import (
    LibraryAuditBusyError,
    LibraryAuditNotReadyError,
)

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


def _library_audit(request: Request):
    service = getattr(request.app.state, "library_audit", None)
    if service is None:
        raise HTTPException(503, "Library audit is not initialized")
    return service


@router.get("/import/progress", response_model=ImportProgress, summary="Current NAS import transfer")
async def nas_import_progress(request: Request):
    return _importer(request).current_progress()


@router.post("/import", response_model=ImportResult, summary="Download audio onto NAS")
async def nas_import(request: Request, body: ImportRequest):
    importer = _importer(request)
    try:
        if not body.wait:
            accepted = await importer.enqueue_import(
                url=body.url,
                filename=body.filename,
                song=body.song,
                pic_url=body.pic_url,
                lyric=body.lyric,
                force=body.force,
            )
            if isinstance(accepted, ImportResult):
                return accepted
            return JSONResponse(status_code=202, content=accepted.model_dump())
        return await importer.import_track(
            url=body.url,
            filename=body.filename,
            song=body.song,
            pic_url=body.pic_url,
            lyric=body.lyric,
            force=body.force,
        )
    except ImportBusyError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
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


@router.get("/library-audit", response_model=LibraryAuditSnapshot, summary="Library audit progress")
async def library_audit_status(request: Request):
    return _library_audit(request).snapshot()


@router.get(
    "/library-audit/findings",
    response_model=LibraryAuditFindingsResponse,
    summary="Library audit findings",
)
async def library_audit_findings(
    request: Request,
    offset: int = 0,
    limit: int = 50,
    code: str | None = None,
):
    if offset < 0 or limit < 1:
        raise HTTPException(status_code=400, detail="offset must be >= 0 and limit must be >= 1")
    return _library_audit(request).findings(offset=offset, limit=limit, code=code)


@router.post("/library-audit", response_model=LibraryAuditSnapshot, summary="Start library audit")
async def library_audit_start(
    request: Request,
    body: LibraryAuditStartRequest | None = None,
):
    payload = body or LibraryAuditStartRequest()
    service = _library_audit(request)
    try:
        snapshot = await service.start(
            LibraryAuditRules(
                low_bitrate_kbps=payload.low_bitrate_kbps,
                suspect_lossless_kbps=payload.suspect_lossless_kbps,
                duration_tolerance_seconds=payload.duration_tolerance_seconds,
            )
        )
    except LibraryAuditBusyError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except DatabaseUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return JSONResponse(status_code=202, content=snapshot.model_dump())


@router.post(
    "/library-audit/deep",
    response_model=LibraryAuditSnapshot,
    summary="Deep-scan flagged or lossless library files",
)
async def library_audit_deep(
    request: Request,
    body: LibraryAuditDeepRequest | None = None,
):
    payload = body or LibraryAuditDeepRequest()
    service = _library_audit(request)
    try:
        snapshot = await service.start_deep(
            scope=payload.scope,
            song_ids=payload.song_ids,
        )
    except LibraryAuditBusyError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except LibraryAuditNotReadyError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except DatabaseUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return JSONResponse(status_code=202, content=snapshot.model_dump())


@router.post(
    "/library-audit/cancel",
    response_model=LibraryAuditSnapshot,
    summary="Cancel in-flight library audit",
)
async def library_audit_cancel(request: Request):
    return await _library_audit(request).cancel()
