from __future__ import annotations

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings, get_settings
from app.main import create_app
from app.services.music_facade import MusicFacade
from app.services.recommendation_service import RecommendationService


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
            return httpx.Response(
                200, json={"url": "https://media.test/a.mp3", "br": 320}
            )
        if params.get("types") == "pic":
            return httpx.Response(200, json={"url": "https://media.test/a.jpg"})
        if params.get("types") == "lyric":
            return httpx.Response(200, json={"lyric": "[00:01]hi"})
        return httpx.Response(404)

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="https://bad.test/api.php,https://good.test/api.php",
            meting_api_base_urls="",
            chksz_api_key="",
            upstream_cooldown_seconds=60,
            upstream_strategy="ordered",
        )
        facade = MusicFacade(client, settings)
        result = await facade.search_first_success(
            "jay", source="netease", count=5, page=1
        )
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
        return httpx.Response(
            200, json=[_song(9, provider="meting"), _song(10, provider="meting")]
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="https://meting.test/",
            chksz_api_key="",
            music_adapter_order="gdstudio,meting",
            upstream_strategy="ordered",
        )
        facade = MusicFacade(client, settings)
        result = await facade.search_first_success("q", source=None, count=20, page=1)
        assert result.provider == "gdstudio"
        assert [item.id for item in result.items] == ["1", "2"]


@pytest.mark.asyncio
async def test_default_adapter_order_prefers_meting():
    async with httpx.AsyncClient() as client:
        settings = Settings(
            _env_file=None,
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="https://meting.test/api",
        )
        facade = MusicFacade(client, settings)

    assert [adapter.name for adapter in facade.adapters] == ["meting", "gdstudio"]


@pytest.mark.asyncio
async def test_explicit_source_does_not_fall_back_to_other_platforms():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        source = request.url.params.get("source") or ""
        calls.append(source)
        if source == "netease":
            return httpx.Response(503, json={"error": "temporary failure"})
        return httpx.Response(200, json=[_song(9, source="joox")])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="",
            music_search_sources="migu,joox",
            upstream_strategy="ordered",
        )
        with pytest.raises(httpx.HTTPError):
            await MusicFacade(client, settings).search_first_success(
                "q", source="netease", count=20, page=1
            )

    assert calls == ["netease"]


@pytest.mark.asyncio
async def test_omitted_source_walks_configured_search_sources():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        source = request.url.params.get("source") or ""
        calls.append(source)
        if source == "migu":
            return httpx.Response(200, json=[])
        return httpx.Response(200, json=[_song(9, source="joox")])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="",
            music_search_sources="migu,joox",
            upstream_strategy="ordered",
        )
        result = await MusicFacade(client, settings).search_first_success(
            "q", source=None, count=20, page=1
        )

    assert calls == ["migu", "joox"]
    assert result.source == "joox"
    assert [item.id for item in result.items] == ["9"]


@pytest.mark.asyncio
async def test_qq_alias_is_pinned_as_tencent():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(
            request.url.params.get("source")
            or request.url.params.get("server")
            or ""
        )
        return httpx.Response(200, json=[_song(3, source="tencent")])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="",
            meting_api_base_urls="https://meting.test/api",
            music_search_sources="netease,migu",
            upstream_strategy="ordered",
        )
        result = await MusicFacade(client, settings).search_first_success(
            "q", source="qq", count=20, page=1
        )

    assert calls == ["tencent"]
    assert result.source == "tencent"


@pytest.mark.asyncio
async def test_capabilities_and_provider_pin_follow_adapter_support():
    calls: list[tuple[str, str]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        source = request.url.params.get("source") or ""
        calls.append((request.url.host, source))
        return httpx.Response(200, json=[_song(4, source=source)])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_base_url="https://chksz.test",
                chksz_api_key="test-key",
                music_adapter_order="meting,gdstudio,chksz",
                upstream_strategy="ordered",
            ),
        )

        capabilities = facade.capabilities()
        result = await facade.search_first_success(
            "q",
            source="migu",
            provider="gdstudio",
            count=1,
            page=1,
        )

        assert capabilities["default_provider"] == "meting"
        assert [adapter["id"] for adapter in capabilities["adapters"]] == [
            "meting",
            "gdstudio",
            "chksz",
        ]
        assert capabilities["adapters"][0]["sources"] == [
            "baidu",
            "kugou",
            "kuwo",
            "netease",
            "tencent",
        ]
        assert capabilities["sources"]["netease"] == {
            "max_count": 50,
            "paginates": True,
        }
        assert capabilities["sources"]["tencent"] == {
            "max_count": 30,
            "paginates": False,
        }
        assert capabilities["sources"]["kugou"] == {
            "max_count": 30,
            "paginates": False,
        }
        assert capabilities["sources"]["kuwo"] == {
            "max_count": 50,
            "paginates": False,
        }
        assert result.provider == "gdstudio"
        assert calls == [("gds.test", "migu")]


@pytest.mark.asyncio
async def test_provider_pin_rejects_unsupported_source_without_fallback():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host)
        return httpx.Response(200, json=[_song(1)])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                music_adapter_order="meting,gdstudio",
            ),
        )
        with pytest.raises(ValueError, match="does not support source migu"):
            await facade.search_first_success(
                "q",
                source="migu",
                provider="meting",
                count=1,
                page=1,
            )

    assert calls == []

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
            assert body["has_more"] is False
            assert len(body["items"]) == 1
            assert body["items"][0]["title"] == "Song 7"
    finally:
        httpx.AsyncClient = original  # type: ignore[misc]
        get_settings.cache_clear()


@pytest.mark.asyncio
async def test_empty_search_page_is_a_successful_terminal_page():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.params.get("source") or "")
        return httpx.Response(200, json=[])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        settings = Settings(
            _env_file=None,
            api_key="k",
            gdstudio_api_base_urls="https://gds.test/api.php",
            meting_api_base_urls="",
            chksz_api_key="",
            music_search_sources="netease,migu,joox",
            upstream_strategy="ordered",
        )
        result = await MusicFacade(client, settings).search_first_success(
            "q", source=None, count=30, page=2
        )

    assert result.items == []
    assert result.strategy == "first-success-empty"
    assert result.has_more is False
    assert calls == ["netease"]


@pytest.mark.asyncio
async def test_netease_page_two_skips_meting_and_uses_gdstudio():
    hosts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        hosts.append(request.url.host)
        if request.url.host == "meting.test":
            return httpx.Response(
                200, json=[_song(index, provider="meting") for index in range(1, 6)]
            )
        pages = request.url.params.get("pages") or "1"
        start = 1 if pages == "1" else 11
        return httpx.Response(
            200,
            json=[
                _song(index, provider="gdstudio") for index in range(start, start + 5)
            ],
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_key="",
                music_adapter_order="meting,gdstudio",
                upstream_strategy="ordered",
            ),
        )
        first = await facade.search_first_success(
            "q", source="netease", count=5, page=1
        )
        hosts.clear()
        second = await facade.search_first_success(
            "q", source="netease", count=5, page=2
        )

    assert first.provider == "gdstudio"
    assert first.has_more is True
    assert first.page == 1
    assert second.provider == "gdstudio"
    assert second.page == 2
    assert [item.id for item in second.items] == ["11", "12", "13", "14", "15"]
    assert second.has_more is True
    assert hosts == ["gds.test"]


@pytest.mark.asyncio
async def test_meting_short_window_still_allows_later_pages():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "meting.test":
            return httpx.Response(
                200, json=[_song(index, provider="meting") for index in range(1, 31)]
            )
        return httpx.Response(200, json=[])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_key="",
                music_adapter_order="meting,gdstudio",
                upstream_strategy="ordered",
            ),
        )
        result = await facade.search_first_success(
            "q",
            source="netease",
            provider="meting",
            count=50,
            page=1,
        )

    assert result.provider == "meting"
    assert len(result.items) == 30
    assert result.has_more is True


@pytest.mark.asyncio
async def test_default_search_count_fills_netease_window():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "meting.test":
            return httpx.Response(
                200, json=[_song(index, provider="meting") for index in range(1, 31)]
            )
        count = int(request.url.params.get("count") or "0")
        return httpx.Response(
            200,
            json=[_song(index, provider="gdstudio") for index in range(1, count + 1)],
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_key="",
                music_adapter_order="meting,gdstudio",
                upstream_strategy="ordered",
            ),
        )
        result = await facade.search_first_success(
            "q", source="netease", count=30, page=1
        )

    assert result.provider == "gdstudio"
    assert len(result.items) == 50
    assert result.has_more is True


@pytest.mark.asyncio
async def test_artist_search_promotes_catalog_from_later_pages():
    def handler(request: httpx.Request) -> httpx.Response:
        pages = request.url.params.get("pages") or "1"
        if request.url.host == "meting.test":
            return httpx.Response(200, json=[])
        if pages == "1":
            return httpx.Response(
                200,
                json=[
                    {
                        **_song(1, provider="gdstudio"),
                        "name": "布拉格广场",
                        "artist": ["蔡依林", "周杰伦"],
                    },
                    {
                        **_song(2, provider="gdstudio"),
                        "name": "想你就写信 (Live)",
                        "artist": ["周杰伦", "李硕"],
                    },
                ],
            )
        return httpx.Response(
            200,
            json=[
                {
                    **_song(3, provider="gdstudio"),
                    "name": "晴天",
                    "artist": ["周杰伦"],
                }
            ],
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_key="",
                music_adapter_order="meting,gdstudio",
                upstream_strategy="ordered",
            ),
        )
        result = await facade.search_first_success(
            "周杰伦", source="netease", count=5, page=1
        )

    assert [item.title for item in result.items] == [
        "晴天",
        "想你就写信 (Live)",
        "布拉格广场",
    ]


@pytest.mark.asyncio
async def test_page_two_failsover_when_pinned_adapter_cannot_paginate():
    hosts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        hosts.append(request.url.host)
        return httpx.Response(
            200, json=[_song(index, provider="gdstudio") for index in range(21, 24)]
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="https://gds.test/api.php",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_key="",
                music_adapter_order="meting,gdstudio",
                upstream_strategy="ordered",
            ),
        )
        result = await facade.search_first_success(
            "q",
            source="netease",
            provider="meting",
            count=3,
            page=2,
        )

    assert result.provider == "gdstudio"
    assert [item.id for item in result.items] == ["21", "22", "23"]
    assert result.has_more is True
    assert hosts == ["gds.test"]


@pytest.mark.asyncio
async def test_tencent_full_page_cannot_paginate():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "code": 200,
                "msg": "success",
                "list": [
                    {
                        "name": f"Song {index}",
                        "singer": "Artist",
                        "album": "Album",
                        "mid": f"mid-{index}",
                    }
                    for index in range(3)
                ],
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="",
                meting_api_base_urls="",
                chksz_api_base_url="https://chksz.test",
                chksz_api_key="test-key",
                music_adapter_order="chksz",
                upstream_strategy="ordered",
            ),
        )
        result = await facade.search_first_success(
            "q", source="tencent", count=3, page=1
        )
        later = await facade.search_first_success(
            "q", source="tencent", count=3, page=2
        )

    assert result.provider == "chksz"
    assert len(result.items) == 3
    assert result.has_more is False
    assert later.items == []
    assert later.has_more is False


@pytest.mark.asyncio
async def test_page_two_without_paginating_adapter_does_not_call_upstream():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host)
        return httpx.Response(200, json=[_song(1, provider="meting")])

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                api_key="k",
                gdstudio_api_base_urls="",
                meting_api_base_urls="https://meting.test/api",
                chksz_api_key="",
                music_adapter_order="meting",
                upstream_strategy="ordered",
            ),
        )
        result = await facade.search_first_success(
            "q", source="netease", count=20, page=2
        )

    assert result.items == []
    assert result.has_more is False
    assert calls == []


def test_recommendation_item_keeps_winning_provider():
    item = RecommendationService._item(
        {
            "id": "1",
            "name": "Song",
            "artist": "Artist",
            "provider": "meting",
        },
        "migu",
        "similar",
    )

    assert item is not None
    assert item.song.online_provider == "meting"
    assert item.song.model_dump(by_alias=True)["onlineProvider"] == "meting"


class _PlayableAdapter:
    def __init__(self, name: str, result: bool | Exception, calls: list[str]) -> None:
        self.name = name
        self.result = result
        self.calls = calls

    async def is_playable(self, id: str, *, source: str, br: int) -> bool:
        self.calls.append(self.name)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


@pytest.mark.asyncio
async def test_is_playable_pins_false_to_winning_provider():
    calls: list[str] = []
    async with httpx.AsyncClient() as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="",
                meting_api_base_urls="",
            ),
        )
        facade._adapters = [  # type: ignore[assignment]
            _PlayableAdapter("meting", False, calls),
            _PlayableAdapter("gdstudio", True, calls),
        ]
        playable = await facade.is_playable("1", "netease", provider="meting")

    assert playable is False
    assert calls == ["meting"]


@pytest.mark.asyncio
async def test_is_playable_falls_back_after_preferred_provider_error():
    calls: list[str] = []
    async with httpx.AsyncClient() as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="",
                meting_api_base_urls="",
            ),
        )
        facade._adapters = [  # type: ignore[assignment]
            _PlayableAdapter("meting", httpx.HTTPError("down"), calls),
            _PlayableAdapter("gdstudio", True, calls),
        ]
        playable = await facade.is_playable("1", "netease", provider="meting")

    assert playable is True
    assert calls == ["meting", "gdstudio"]

class _MediaAdapter:
    def __init__(self, name: str, result: dict | Exception, calls: list[str]):
        self.name = name
        self.result = result
        self.calls = calls

    async def get_url(self, id: str, *, source: str, br: int) -> dict:
        self.calls.append(self.name)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


class _LyricAdapter:
    def __init__(
        self,
        name: str,
        result: dict | Exception,
        calls: list[str],
        sources: frozenset[str] | None = None,
    ):
        self.name = name
        self.result = result
        self.calls = calls
        self.supported_sources = sources or frozenset({"netease"})

    def supports(self, source: str | None) -> bool:
        return source is None or source in self.supported_sources

    async def get_lyric(self, id: str, *, source: str) -> dict:
        self.calls.append(self.name)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


@pytest.mark.asyncio
async def test_media_request_pins_explicit_provider_without_fallback():
    calls: list[str] = []
    async with httpx.AsyncClient() as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="",
                meting_api_base_urls="",
            ),
        )
    facade._adapters = [  # type: ignore[assignment]
        _MediaAdapter("chksz", httpx.HTTPError("down"), calls),
        _MediaAdapter(
            "meting",
            {
                "url": "https://cdn.example.com/wrong.mp3",
                "provider": "meting",
                "source": "netease",
            },
            calls,
        ),
    ]

    with pytest.raises(httpx.HTTPError, match="down"):
        await facade.get_url(
            "provider-specific-id",
            source="netease",
            br=320,
            provider="chksz",
        )

    assert calls == ["chksz"]


@pytest.mark.asyncio
async def test_get_lyric_falls_back_when_preferred_returns_empty():
    calls: list[str] = []
    async with httpx.AsyncClient() as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="",
                meting_api_base_urls="",
            ),
        )
        facade._adapters = [  # type: ignore[assignment]
            _LyricAdapter(
                "chksz",
                {"lyric": "", "provider": "chksz", "source": "netease"},
                calls,
            ),
            _LyricAdapter(
                "meting",
                {"lyric": "[00:01.00]蝴蝶", "provider": "meting", "source": "netease"},
                calls,
            ),
        ]
        lyric = await facade.get_lyric("93188", source="netease", provider="chksz")

    assert lyric.lyric == "[00:01.00]蝴蝶"
    assert lyric.provider == "meting"
    assert calls == ["chksz", "meting"]


@pytest.mark.asyncio
async def test_get_lyric_falls_back_when_preferred_errors():
    calls: list[str] = []
    async with httpx.AsyncClient() as client:
        facade = MusicFacade(
            client,
            Settings(
                _env_file=None,
                gdstudio_api_base_urls="",
                meting_api_base_urls="",
            ),
        )
        facade._adapters = [  # type: ignore[assignment]
            _LyricAdapter("chksz", httpx.HTTPError("down"), calls),
            _LyricAdapter(
                "gdstudio",
                {"lyric": "[00:01.00]蝴蝶", "provider": "gdstudio", "source": "netease"},
                calls,
            ),
        ]
        lyric = await facade.get_lyric("93188", source="netease", provider="chksz")

    assert lyric.lyric == "[00:01.00]蝴蝶"
    assert lyric.provider == "gdstudio"
    assert calls == ["chksz", "gdstudio"]


@pytest.mark.asyncio
async def test_recommendation_playability_forwards_winning_provider():
    class _Proxy:
        provider: str | None = None

        async def is_playable(
            self,
            id: str,
            source: str,
            br: int = 999,
            provider: str | None = None,
        ) -> bool:
            self.provider = provider
            return True

    item = RecommendationService._item(
        {
            "id": "1",
            "name": "Song",
            "artist": "Artist",
            "provider": "meting",
        },
        "netease",
        "similar",
    )
    assert item is not None
    proxy = _Proxy()
    service = RecommendationService(store=object(), music_proxy=proxy)  # type: ignore[arg-type]

    assert await service._is_playable(item)
    assert proxy.provider == "meting"
