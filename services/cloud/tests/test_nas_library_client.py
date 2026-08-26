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


@pytest.mark.asyncio
async def test_nas_library_client_imports_song():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/nas/import")
        assert request.headers.get("X-API-Key") == "nas-key"
        assert request.method == "POST"
        return httpx.Response(200, json={"ok": True, "message": "imported"})

    settings = Settings(
        api_key="cloud",
        nas_agent_url="https://nas-agent.test",
        nas_agent_key="nas-key",
        recommendation_sources="netease",
        _env_file=None,
    )
    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        result = await NasLibraryClient(client, settings).import_song(
            {"url": "https://cdn.example/a.mp3", "filename": "a.mp3", "song": {}}
        )
    assert result == {"ok": True, "message": "imported"}


@pytest.mark.asyncio
async def test_nas_library_client_import_does_not_retry_transport_error():
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        raise httpx.ConnectError("disconnected", request=request)

    settings = Settings(
        api_key="cloud",
        nas_agent_url="https://nas-agent.test",
        nas_agent_key="nas-key",
        recommendation_sources="netease",
        _env_file=None,
    )
    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(httpx.ConnectError):
            await NasLibraryClient(client, settings).import_song(
                {"url": "https://cdn.example/a.mp3", "filename": "a.mp3", "wait": False}
            )
    assert calls == 1


@pytest.mark.asyncio
async def test_nas_library_client_maps_duplicate_conflict():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            409,
            json={"detail": "Song already exists in the Navidrome library"},
        )

    settings = Settings(
        api_key="cloud",
        nas_agent_url="https://nas-agent.test",
        nas_agent_key="nas-key",
        recommendation_sources="netease",
        _env_file=None,
    )
    from app.services.nas_library_client import NasAgentError

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        with pytest.raises(NasAgentError) as exc:
            await NasLibraryClient(client, settings).import_song(
                {"url": "https://cdn.example/a.mp3", "filename": "a.mp3", "song": {}}
            )
    assert exc.value.status_code == 409
    assert "already exists" in exc.value.detail


@pytest.mark.asyncio
async def test_nas_library_client_reads_import_progress():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/nas/import/progress")
        assert request.method == "GET"
        return httpx.Response(
            200,
            json={
                "active": True,
                "filename": "a.mp3",
                "bytes_received": 2048,
                "bytes_total": 4096,
                "speed_bps": 512.0,
                "stage": "downloading",
            },
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
        result = await NasLibraryClient(client, settings).import_progress()
    assert result["bytes_received"] == 2048
    assert result["filename"] == "a.mp3"


@pytest.mark.asyncio
async def test_nas_library_client_deletes_songs():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/songs/delete")
        return httpx.Response(
            200,
            json={"deleted": 1, "skipped": 0, "errors": 0, "msg": "ok"},
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
        result = await NasLibraryClient(client, settings).delete_songs(["id1"])
    assert result["deleted"] == 1
