from __future__ import annotations

import asyncio
import httpx
import pytest

from app.adapters.chksz import ChkszAdapter
from app.core.config import Settings
from app.services.music_facade import MusicFacade


def _netease_search_payload() -> dict:
    return {
        "code": 200,
        "msg": "success",
        "data": {
            "songs": [
                {
                    "id": 186001,
                    "name": "晴天",
                    "artists": "周杰伦",
                    "album": "叶惠美",
                    "picUrl": "https://p1.music.126.net/cover.jpg",
                    "duration": 269000,
                }
            ],
            "total": 1,
        },
    }


@pytest.mark.asyncio
async def test_chksz_search_reads_netease_songs_object():
    def handler(request: httpx.Request) -> httpx.Response:
        assert "apikey" in request.url.params
        assert request.url.path == "/api/163_search"
        assert request.url.params.get("offset") == "0"
        return httpx.Response(200, json=_netease_search_payload())

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(client, "https://api.chksz.test", "chksz_test")
        songs = await adapter.search("晴天", source="netease", count=5, page=1)

    assert len(songs) == 1
    assert songs[0]["id"] == "186001"
    assert songs[0]["title"] == "晴天"
    assert songs[0]["artist"] == "周杰伦"
    assert songs[0]["source"] == "netease"
    assert songs[0]["provider"] == "chksz"
    assert songs[0]["cover_id"] == "https://p1.music.126.net/cover.jpg"
    assert songs[0]["duration"] == 269.0


@pytest.mark.asyncio
async def test_chksz_search_qq_uses_mid_and_skips_later_pages():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.path)
        return httpx.Response(
            200,
            json={
                "code": 200,
                "msg": "success",
                "count": 1,
                "list": [
                    {
                        "n": 1,
                        "name": "晴天",
                        "singer": "周杰伦",
                        "album": "叶惠美",
                        "mid": "0039MnYb0qxYhV",
                    }
                ],
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(client, "https://api.chksz.test", "chksz_test")
        page1 = await adapter.search("晴天", source="qq", count=5, page=1)
        page2 = await adapter.search("晴天", source="tencent", count=5, page=2)

    assert [song["id"] for song in page1] == ["0039MnYb0qxYhV"]
    assert page1[0]["source"] == "tencent"
    assert page2 == []
    assert calls == ["/api/qq_music"]


@pytest.mark.asyncio
async def test_chksz_ignores_unsupported_sources():
    async with httpx.AsyncClient() as client:
        adapter = ChkszAdapter(client, "https://api.chksz.test", "chksz_test")
        assert await adapter.search("q", source="migu", count=10, page=1) == []
        assert await adapter.search("q", source="joox", count=10, page=1) == []


@pytest.mark.asyncio
async def test_chksz_url_and_http_cover():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/api/163_music":
            assert request.url.params.get("level") == "exhigh"
            return httpx.Response(
                200,
                json={
                    "code": 200,
                    "data": {
                        "url": "https://m701.music.126.net/a.mp3",
                        "br": 320000,
                    },
                },
            )
        raise AssertionError(request.url.path)

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(client, "https://api.chksz.test", "chksz_test")
        url = await adapter.get_url("186001", source="netease", br=320)
        cover = await adapter.get_cover(
            "https://p1.music.126.net/cover.jpg", source="netease", size=300
        )

    assert url["url"].endswith("a.mp3")
    assert cover["url"].endswith("cover.jpg")


@pytest.mark.asyncio
async def test_chksz_quota_errors_fail_over():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "api.chksz.test":
            return httpx.Response(402, json={"code": 402, "msg": "quota"})
        return httpx.Response(200, json=[{"id": "1", "name": "Song", "source": "netease"}])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="",
            chksz_api_base_url="https://api.chksz.test",
            chksz_api_key="chksz_test",
            music_adapter_order="chksz,gdstudio",
            upstream_strategy="ordered",
        )
        result = await MusicFacade(client, settings).search_first_success(
            "q", source="netease", count=20, page=1
        )

    assert result.provider == "gdstudio"
    assert [item.id for item in result.items] == ["1"]


@pytest.mark.asyncio
async def test_facade_skips_chksz_without_key():
    async with httpx.AsyncClient() as client:
        settings = Settings(
            _env_file=None,
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="https://meting.test/api",
            chksz_api_base_url="https://api.chksz.test",
            chksz_api_key="",
        )
        facade = MusicFacade(client, settings)

    assert [adapter.name for adapter in facade.adapters] == ["meting", "gdstudio"]

@pytest.mark.asyncio
async def test_chksz_serializes_concurrent_requests():
    active = 0
    max_active = 0

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal active, max_active
        active += 1
        max_active = max(max_active, active)
        await asyncio.sleep(0.01)
        active -= 1
        return httpx.Response(200, json=_netease_search_payload())

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
            retry_delays=(),
        )
        await asyncio.gather(
            adapter.search("one", source="netease", count=1, page=1),
            adapter.search("two", source="netease", count=1, page=1),
            adapter.search("three", source="netease", count=1, page=1),
        )

    assert max_active == 1


@pytest.mark.asyncio
async def test_chksz_retries_rate_limit_then_recovers():
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(429, headers={"Retry-After": "0"})
        return httpx.Response(200, json=_netease_search_payload())

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
            retry_delays=(0,),
        )
        songs = await adapter.search("晴天", source="netease", count=1, page=1)

    assert calls == 2
    assert [song["title"] for song in songs] == ["晴天"]
