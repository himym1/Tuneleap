from __future__ import annotations

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings, get_settings
from app.main import create_app
from app.services.music_facade import MusicFacade


def _song(i: int, *, provider: str = "gdstudio", source: str = "netease") -> dict:
    return {
        "id": str(i),
        "name": f"Song {i}",
        "artist": ["Artist"],
        "album": "Album",
        "pic_id": f"pic-{i}",
        "url_id": str(i),
        "lyric_id": str(i),
        "source": source,
    }


@pytest.mark.asyncio
async def test_gdstudio_adapter_search_and_url_failover():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        host = request.url.host
        params = request.url.params
        if host == "bad.test":
            return httpx.Response(500, json={"error": "down"})
        if params.get("types") == "search":
            return httpx.Response(200, json=[_song(1)])
        if params.get("types") == "url":
            return httpx.Response(200, json={"url": "https://media.test/a.mp3", "br": 320})
        if params.get("types") == "pic":
            return httpx.Response(200, json={"url": "https://media.test/a.jpg"})
        if params.get("types") == "lyric":
            return httpx.Response(200, json={"lyric": "[00:01]hi"})
        return httpx.Response(404)

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            api_key="k",
            gdstudio_api_base_urls="https://bad.test/api.php,https://good.test/api.php",
            meting_api_base_urls="",
            upstream_cooldown_seconds=60,
            upstream_strategy="ordered",
        )
        facade = MusicFacade(client, settings)
        result = await facade.search_first_success("jay", source="netease", count=5, page=1)
        assert result.provider == "gdstudio"
        assert len(result.items) == 1
        assert result.items[0].title == "Song 1"
        assert result.items[0].artist == "Artist"
        url = await facade.get_url("1", source="netease", br=999, provider="gdstudio")
        assert url.url.endswith("a.mp3")
        cover = await facade.get_cover("1", source="netease", size=300)
        assert cover.url.endswith("a.jpg")
        lyric = await facade.get_lyric("1", source="netease")
        assert "hi" in lyric.lyric
    assert any("bad.test" in c for c in calls)
    assert any("good.test" in c for c in calls)


@pytest.mark.asyncio
async def test_first_success_does_not_concatenate_providers():
    def handler(request: httpx.Request) -> httpx.Response:
        host = request.url.host
        params = request.url.params
        if params.get("types") != "search" and params.get("type") != "search":
            return httpx.Response(200, json={"url": "https://x"})
        if host == "gds.test":
            return httpx.Response(200, json=[_song(1), _song(2)])
        return httpx.Response(200, json=[_song(9, provider="meting"), _song(10, provider="meting")])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            api_key="k",
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="https://meting.test/",
            upstream_strategy="ordered",
        )
        facade = MusicFacade(client, settings)
        result = await facade.search_first_success("q", source=None, count=20, page=1)
        assert result.provider == "gdstudio"
        assert [item.id for item in result.items] == ["1", "2"]


def test_search_api_happy_path():
    def handler(request: httpx.Request) -> httpx.Response:
        params = request.url.params
        if params.get("types") == "search":
            return httpx.Response(200, json=[_song(7)])
        return httpx.Response(200, json={"url": "https://media.test/x"})

    transport = httpx.MockTransport(handler)

    class _PatchedClient(httpx.AsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    import app.main as main_mod

    original = httpx.AsyncClient
    httpx.AsyncClient = _PatchedClient  # type: ignore[misc,assignment]
    try:
        get_settings.cache_clear()
        with TestClient(create_app()) as client:
            resp = client.get(
                "/v1/music/search",
                params={"q": "hello", "source": "netease"},
                headers={"X-API-Key": "test-cloud-key"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            assert body["provider"] == "gdstudio"
            assert body["strategy"] == "first-success"
            assert len(body["items"]) == 1
            assert body["items"][0]["title"] == "Song 7"
    finally:
        httpx.AsyncClient = original  # type: ignore[misc]
        get_settings.cache_clear()
