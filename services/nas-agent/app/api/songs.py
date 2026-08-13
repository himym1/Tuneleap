from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import verify_agent_key
from app.models.schemas import DeleteRequest, DeleteResult, LibraryIdentitiesResponse
from app.services.library import DatabaseUnavailableError

router = APIRouter(
    prefix="/v1/songs",
    tags=["songs"],
    dependencies=[Depends(verify_agent_key)],
)


def _library(request: Request):
    service = getattr(request.app.state, "library", None)
    if service is None:
        raise HTTPException(503, "Library service not initialized")
    return service


@router.get(
    "/library-identities",
    response_model=LibraryIdentitiesResponse,
    summary="Active library weak identities for recommendation blocking",
)
async def library_identities(request: Request):
    library = _library(request)
    try:
        identities = await library.recommendation_weak_identities()
    except DatabaseUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    ordered = sorted(identities)
    return LibraryIdentitiesResponse(count=len(ordered), identities=ordered)


@router.post("/delete", response_model=DeleteResult, summary="Delete library songs")
async def delete_songs(request: Request, body: DeleteRequest):
    library = _library(request)
    try:
        return await library.delete_songs(body.song_ids)
    except DatabaseUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
