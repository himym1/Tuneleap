from __future__ import annotations

from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api import auth_routes, health, library, music, recommendations, updates
from app.core.config import get_settings
from app.core.limiter import limiter
from app.core.recommendation_http import (
    RecommendationBodyLimitMiddleware,
    recommendation_exception_handler,
    recommendation_http_handler,
    recommendation_rate_limit_handler,
    recommendation_runtime_error_handler,
    recommendation_validation_handler,
    recommendation_value_error_handler,
)
from app.db.database import Database
from app.services.auth_service import AuthService
from app.services.music_facade import MusicFacade
from app.services.nas_library_client import NasLibraryClient
from app.services.recommendation_service import RecommendationService
from app.services.recommendation_store import RecommendationStore


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    client = httpx.AsyncClient(timeout=settings.http_timeout_seconds)
    database = Database(
        settings.database_url,
        min_size=settings.database_pool_min_size,
        max_size=settings.database_pool_max_size,
        timeout=settings.database_pool_timeout_seconds,
    )
    facade = MusicFacade(client, settings)
    library = NasLibraryClient(client, settings)
    store: RecommendationStore | None = None
    service: RecommendationService | None = None
    try:
        await database.open()
        store = RecommendationStore(
            database.pool,
            session_ttl_ms=settings.recommendation_session_ttl_hours * 3600_000,
        )
        await store.initialize()
        service = RecommendationService(
            store=store,
            music_proxy=facade,
            library=library if library.enabled else None,
            sources=settings.recommendation_source_list,
            discovery_seeds=settings.recommendation_discovery_seed_list,
            upstream_concurrency=settings.recommendation_upstream_concurrency,
            pool_target=settings.recommendation_pool_target,
            low_watermark=settings.recommendation_pool_low_watermark,
            page_max=settings.recommendation_page_max,
        )
        app.state.database = database
        app.state.auth_service = AuthService(database.pool, settings)
        app.state.http_client = client
        app.state.music_facade = facade
        app.state.nas_library = library
        app.state.recommendation_store = store
        app.state.recommendation_service = service
        yield
    finally:
        cleanup_error: BaseException | None = None
        if service is not None:
            try:
                await service.shutdown(
                    timeout=min(float(settings.http_timeout_seconds), 5.0)
                )
            except BaseException as exc:  # noqa: BLE001
                cleanup_error = exc
        if store is not None:
            try:
                await store.close()
            except BaseException as exc:  # noqa: BLE001
                if cleanup_error is None:
                    cleanup_error = exc
        try:
            await database.close()
        except BaseException as exc:  # noqa: BLE001
            if cleanup_error is None:
                cleanup_error = exc
        try:
            await client.aclose()
        except BaseException as exc:  # noqa: BLE001
            if cleanup_error is None:
                cleanup_error = exc
        if cleanup_error is not None:
            raise cleanup_error


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        lifespan=lifespan,
        description=(
            "Public control plane for navidrome_player. "
            "No NAS disk mounts. See docs/DEVELOPMENT.md and ADR-0004."
        ),
    )
    app.state.limiter = limiter
    app.add_exception_handler(RequestValidationError, recommendation_validation_handler)
    app.add_exception_handler(HTTPException, recommendation_http_handler)
    app.add_exception_handler(RateLimitExceeded, recommendation_rate_limit_handler)
    app.add_exception_handler(ValueError, recommendation_value_error_handler)
    app.add_exception_handler(RuntimeError, recommendation_runtime_error_handler)
    app.add_exception_handler(Exception, recommendation_exception_handler)
    app.add_middleware(RecommendationBodyLimitMiddleware)
    app.add_middleware(SlowAPIMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(health.router)
    app.include_router(library.router)
    app.include_router(music.router)
    app.include_router(updates.router)
    app.include_router(auth_routes.router)
    app.include_router(recommendations.router)
    return app


app = create_app()
