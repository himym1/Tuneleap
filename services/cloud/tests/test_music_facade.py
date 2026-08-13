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

        assert capabilities == {
            "default_provider": "meting",
            "adapters": [
                {
                    "id": "meting",
                    "sources": ["baidu", "kugou", "kuwo", "netease", "tencent"],
                },
                {
                    "id": "gdstudio",
                    "sources": ["joox", "kugou", "kuwo", "migu", "netease"],
                },
                {
                    "id": "chksz",
                    "sources": ["kugou", "netease", "tencent"],
                },
            ],
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
    assert calls == ["netease"]


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
