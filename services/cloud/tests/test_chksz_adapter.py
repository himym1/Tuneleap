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
        assert adapter.supports_pagination("netease")
        assert not adapter.supports_pagination("tencent")
        assert not adapter.supports_pagination("kugou")
        assert adapter.search_window("netease").max_count == 50
        assert adapter.search_window("tencent").max_count == 30
        assert adapter.search_window("kugou").max_count == 20


@pytest.mark.asyncio
async def test_chksz_kugou_search_sends_num():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/kugou_music"
        assert request.url.params.get("num") == "20"
        return httpx.Response(
            200,
            json={
                "code": 200,
                "msg": "success",
                "list": [
                    {
                        "name": "晴天",
                        "singer": "周杰伦",
                        "id": "hash-1",
                    }
                ],
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(client, "https://api.chksz.test", "chksz_test")
        songs = await adapter.search("晴天", source="kugou", count=50, page=1)

    assert [song["id"] for song in songs] == ["hash-1"]


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
async def test_chksz_invalidate_url_cache_asks_upstream_again():
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        if request.url.path == "/api/163_music":
            calls += 1
            return httpx.Response(
                200,
                json={
                    "code": 200,
                    "data": {
                        "url": f"https://m80{calls}.music.126.net/a.mp3",
                        "br": 320000,
                    },
                },
            )
        raise AssertionError(request.url.path)

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
        )
        first = await adapter.get_url("186001", source="netease", br=320)
        cached = await adapter.get_url("186001", source="netease", br=320)
        adapter.invalidate_url_cache("186001", source="netease", br=320)
        fresh = await adapter.get_url("186001", source="netease", br=320)

    assert calls == 2
    assert first["url"] == cached["url"]
    assert fresh["url"] != first["url"]


@pytest.mark.asyncio
async def test_chksz_quota_errors_fail_over():
    chksz_calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal chksz_calls
        if request.url.host == "api.chksz.test":
            chksz_calls += 1
            return httpx.Response(402, json={"code": 402, "msg": "quota"})
        return httpx.Response(
            200, json=[{"id": "1", "name": "Song", "source": "netease"}]
        )

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
        facade = MusicFacade(client, settings)
        result = await facade.search_first_success(
            "q", source="netease", count=20, page=1
        )

        capabilities = facade.capabilities()
        with pytest.raises(ValueError, match="music adapter unavailable: chksz"):
            await facade.search_first_success(
                "q",
                source="netease",
                provider="chksz",
                count=20,
                page=1,
            )

    assert result.provider == "gdstudio"
    assert [item.id for item in result.items] == ["1"]
    assert chksz_calls == 1
    assert [adapter["id"] for adapter in capabilities["adapters"]] == [
        "gdstudio"
    ]
    assert capabilities["default_provider"] == "gdstudio"


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
async def test_chksz_quota_stops_already_queued_requests():
    calls = 0

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        await asyncio.sleep(0.01)
        return httpx.Response(402, json={"code": 402, "msg": "quota"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
            retry_delays=(),
        )
        results = await asyncio.gather(
            adapter.search("one", source="netease", count=1, page=1),
            adapter.search("two", source="tencent", count=1, page=1),
            adapter.search("three", source="kugou", count=1, page=1),
            return_exceptions=True,
        )

    assert calls == 1
    assert all(isinstance(result, httpx.HTTPError) for result in results)
    assert adapter.available is False


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

@pytest.mark.asyncio
async def test_chksz_search_treats_not_found_as_empty():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            404,
            json={"code": 404, "msg": "未找到匹配的歌曲"},
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
            retry_delays=(),
        )
        songs = await adapter.search(
            "no matching song",
            source="kugou",
            count=10,
            page=1,
        )

    assert songs == []


@pytest.mark.asyncio
async def test_chksz_url_keeps_not_found_as_error():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404, json={"code": 404, "msg": "not found"})

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
            retry_delays=(),
        )
        with pytest.raises(httpx.HTTPStatusError):
            await adapter.get_url("missing", source="kugou", br=320)

@pytest.mark.asyncio
async def test_chksz_search_without_real_cover_does_not_invent_cover_id():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "code": 200,
                "list": [
                    {
                        "name": "Bad Boy",
                        "singer": "Artist",
                        "mid": "qq-1",
                    }
                ],
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
        )
        songs = await adapter.search(
            "Bad Boy", source="tencent", count=1, page=1
        )

    assert songs[0]["cover_id"] is None


@pytest.mark.asyncio
async def test_chksz_reuses_detail_for_url_cover_and_lyric():
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        return httpx.Response(
            200,
            json={
                "code": 200,
                "url": "https://cdn.example.com/song.mp3",
                "cover": "https://cdn.example.com/cover.jpg",
                "lrc": "[00:01.00]First line",
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
        )
        playback = await adapter.get_url("qq-1", source="tencent", br=320)
        cover = await adapter.get_cover("qq-1", source="tencent", size=300)
        lyric = await adapter.get_lyric("qq-1", source="tencent")
        repeated = await adapter.get_url("qq-1", source="tencent", br=320)

    assert calls == 1
    assert playback["cover_url"].endswith("cover.jpg")
    assert playback["lyric"] == "[00:01.00]First line"
    assert cover["url"].endswith("cover.jpg")
    assert lyric["lyric"] == "[00:01.00]First line"
    assert repeated["url"].endswith("song.mp3")


@pytest.mark.asyncio
async def test_chksz_netease_lyric_does_not_reuse_empty_playback_cache():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.path)
        if request.url.path == "/api/163_music":
            return httpx.Response(
                200,
                json={
                    "code": 200,
                    "data": {
                        "url": "https://m701.music.126.net/a.flac",
                        "br": 999000,
                    },
                },
            )
        if request.url.path == "/api/163_lyric":
            return httpx.Response(
                200,
                json={
                    "code": 200,
                    "data": {
                        "lyric": "",
                        "lrc": {"lyric": "[00:01.00]蝴蝶"},
                    },
                },
            )
        raise AssertionError(request.url.path)

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        adapter = ChkszAdapter(
            client,
            "https://api.chksz.test",
            "chksz_test",
            request_interval=0,
        )
        playback = await adapter.get_url("93188", source="netease", br=999)
        lyric = await adapter.get_lyric("93188", source="netease")

    assert playback["url"].endswith("a.flac")
    assert "lyric" not in playback
    assert calls == ["/api/163_music", "/api/163_lyric"]
    assert lyric["lyric"] == "[00:01.00]蝴蝶"
