from pathlib import Path

from fastapi import APIRouter, Request

from app.models.schemas import HealthResponse

router = APIRouter(tags=["system"])


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    settings = request.app.state.settings
    return HealthResponse(
        version=settings.app_version,
        music_dir_configured=Path(settings.music_dir).is_dir(),
        download_dir_configured=Path(settings.download_dir).is_dir(),
        database_configured=Path(settings.navidrome_db_path).is_file(),
    )
