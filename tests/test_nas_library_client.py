from __future__ import annotations

import httpx
import pytest

from app.core.config import Settings
from app.services.nas_library_client import NasLibraryClient


@pytest.mark.asyncio
async def test_nas_library_client_parses_identities():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/songs/library-identities")
        assert request.headers.get("X-API-Key") == "nas-key"
        return httpx.Response(
            200,
            json={"count": 2, "identities": ["a\x1fb", "c\x1fd"]},
        )

    settings = Settings(
        api_key="cloud",
        nas_agent_url="https://nas-agent.test",
        nas_agent_key="nas-key",
        recommendation_sources="netease",
        _env_file=None,
    )
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        lib = NasLibraryClient(client, settings)
        assert lib.enabled
        identities = await lib.recommendation_weak_identities()
        assert identities == {"a\x1fb", "c\x1fd"}


@pytest.mark.asyncio
async def test_nas_library_client_disabled_without_url():
    settings = Settings(
        api_key="cloud",
        nas_agent_url="",
        nas_agent_key="",
        recommendation_sources="netease",
        _env_file=None,
    )
    async with httpx.AsyncClient() as client:
        lib = NasLibraryClient(client, settings)
        assert not lib.enabled
        assert await lib.recommendation_weak_identities() == set()
