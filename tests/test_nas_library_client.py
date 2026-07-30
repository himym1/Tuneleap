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


@pytest.mark.asyncio
async def test_nas_library_client_retries_transport_error_once():
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise httpx.RemoteProtocolError("disconnected", request=request)
        return httpx.Response(200, json={"identities": ["a\x1fb"]})

    settings = Settings(
        api_key="cloud",
        nas_agent_url="https://nas-agent.test",
        nas_agent_key="nas-key",
        recommendation_sources="netease",
        _env_file=None,
    )
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        identities = await NasLibraryClient(
            client, settings
        ).recommendation_weak_identities()

    assert identities == {"a\x1fb"}
    assert calls == 2


@pytest.mark.asyncio
async def test_nas_library_client_uses_recent_cache_after_retry_failure():
    calls = 0
    now = 10.0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(200, json={"identities": ["a\x1fb"]})
        raise httpx.RemoteProtocolError("disconnected", request=request)

    settings = Settings(
        api_key="cloud",
        nas_agent_url="https://nas-agent.test",
        nas_agent_key="nas-key",
        recommendation_sources="netease",
        _env_file=None,
    )
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        library = NasLibraryClient(client, settings, clock=lambda: now)
        assert await library.recommendation_weak_identities() == {"a\x1fb"}
        assert await library.recommendation_weak_identities() == {"a\x1fb"}

    assert calls == 3
