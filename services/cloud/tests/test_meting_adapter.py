from __future__ import annotations

import hashlib
import hmac

import httpx
import pytest

from app.adapters.meting import MetingAdapter


@pytest.mark.asyncio
async def test_standard_meting_search_and_resources():
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        kind = request.url.params["type"]
        if kind == "search":
            return httpx.Response(
                200,
                json=[
                    {
                        "title": "晴天",
                        "author": "周杰伦",
                        "url": "https://meting.test/api?server=netease&type=url&id=186016&auth=signed",
                        "pic": "https://meting.test/api?server=netease&type=pic&id=186016&auth=signed",
                        "lrc": "https://meting.test/api?server=netease&type=lrc&id=186016&auth=signed",
                    }
                ],
            )
        if kind == "url":
            return httpx.Response(302, headers={"Location": "https://media.test/a.mp3"})
        if kind == "pic":
            return httpx.Response(302, headers={"Location": "https://media.test/a.jpg"})
        if kind == "lrc":
            return httpx.Response(200, text="[00:01]晴天")
        return httpx.Response(404)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        adapter = MetingAdapter(client, ("https://meting.test/api",), token="secret")
        songs = await adapter.search("晴天", source="netease", count=20, page=1)
        url = await adapter.get_url("186016", source="netease", br=999)
        cover = await adapter.get_cover("186016", source="netease", size=300)
        lyric = await adapter.get_lyric("186016", source="netease")

    assert len(songs) == 1
    assert songs[0]["id"] == "186016"
    assert songs[0]["title"] == "晴天"
    assert songs[0]["artist"] == "周杰伦"
    assert songs[0]["provider"] == "meting"
    assert url["url"] == "https://media.test/a.mp3"
    assert cover["url"] == "https://media.test/a.jpg"
    assert lyric["lyric"] == "[00:01]晴天"

    resource_calls = [
        request for request in calls if request.url.params["type"] != "search"
    ]
    for request in resource_calls:
        kind = request.url.params["type"]
        expected = hmac.new(
            b"secret", f"netease{kind}186016".encode(), hashlib.sha1
        ).hexdigest()
        assert request.url.params["auth"] == expected


@pytest.mark.asyncio
async def test_meting_returns_terminal_page_without_repeating_search():
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        return httpx.Response(200, json=[])

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        adapter = MetingAdapter(client, ("https://meting.test/api",))
        assert await adapter.search("q", source="netease", count=20, page=2) == []
        assert await adapter.search("q", source="migu", count=20, page=1) == []

    assert calls == 0


@pytest.mark.asyncio
async def test_meting_search_fails_over_api_redirect():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host or "")
        if request.url.host == "moved.test":
            return httpx.Response(
                307, headers={"Location": "https://elsewhere.test/api"}
            )
        return httpx.Response(
            200,
            json=[
                {
                    "title": "晴天",
                    "author": "周杰伦",
                    "url": "https://healthy.test/api?type=url&id=186016",
                }
            ],
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        adapter = MetingAdapter(
            client, ("https://moved.test/api", "https://healthy.test/api")
        )
        songs = await adapter.search("晴天", source="netease", count=20, page=1)

    assert calls == ["moved.test", "healthy.test"]
    assert [song["id"] for song in songs] == ["186016"]
