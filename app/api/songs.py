from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import verify_agent_key
from app.models.schemas import DeleteRequest, DeleteResult
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


@router.post("/delete", response_model=DeleteResult, summary="Delete library songs")
async def delete_songs(request: Request, body: DeleteRequest):
    library = _library(request)
    try:
        return await library.delete_songs(body.song_ids)
    except DatabaseUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
