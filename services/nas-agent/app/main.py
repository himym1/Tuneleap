from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import health, nas, songs
from app.core.config import Settings, get_settings
from app.services.importer import ImporterService
from app.services.library import LibraryService


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings: Settings = app.state.settings or get_settings()
    app.state.settings = settings
    client = httpx.AsyncClient(
        timeout=httpx.Timeout(settings.http_timeout_seconds),
        follow_redirects=False,
    )
    app.state.http_client = client
    app.state.importer = ImporterService(client, settings)
    app.state.library = LibraryService(client, settings)
    try:
        yield
    finally:
        await client.aclose()


def create_app(settings: Settings | None = None) -> FastAPI:
    app = FastAPI(
        title=settings.app_name if settings else "navidrome-nas-agent",
        version=settings.app_version if settings else "0.1.0",
        lifespan=lifespan,
        description=(
            "NAS import/delete agent for navidrome_player. "
            "No public search. See docs/DEVELOPMENT.md and ADR-0004."
        ),
    )
    app.state.settings = settings

    origins = settings.cors_origin_list if settings else []
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials="*" not in origins,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["X-API-Key", "Content-Type"],
        )

    app.include_router(health.router)
    app.include_router(nas.router)
    app.include_router(songs.router)
    return app


app = create_app()
