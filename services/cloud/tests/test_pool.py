from __future__ import annotations

import httpx
import pytest

from app.adapters.pool import BasePool


@pytest.mark.asyncio
async def test_request_does_not_cool_down_base_for_resource_404():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host or "")
        if request.url.host == "missing.test":
            return httpx.Response(404)
        return httpx.Response(200, json={"ok": True})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        pool = BasePool(
            client,
            ("https://missing.test", "https://healthy.test"),
            cooldown_seconds=60,
        )
        await pool.request_json(params={})
        await pool.request_json(params={})

    assert calls == [
        "missing.test",
        "healthy.test",
        "missing.test",
        "healthy.test",
    ]


@pytest.mark.asyncio
async def test_request_cools_down_base_for_500():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host or "")
        if request.url.host == "broken.test":
            return httpx.Response(500)
        return httpx.Response(200, json={"ok": True})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        pool = BasePool(
            client,
            ("https://broken.test", "https://healthy.test"),
            cooldown_seconds=60,
        )
        await pool.request_json(params={})
        await pool.request_json(params={})

    assert calls == ["broken.test", "healthy.test", "healthy.test"]


@pytest.mark.asyncio
async def test_request_fails_over_unexpected_redirect_but_accepts_302():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host or "")
        if request.url.host == "moved.test":
            return httpx.Response(307, headers={"Location": "https://elsewhere.test"})
        return httpx.Response(302, headers={"Location": "https://media.test/song.mp3"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        pool = BasePool(
            client,
            ("https://moved.test", "https://resource.test"),
            cooldown_seconds=60,
        )
        response = await pool.request(
            params={}, allowed_redirect_statuses=frozenset({302})
        )

    assert calls == ["moved.test", "resource.test"]
    assert response.status_code == 302
    assert response.headers["location"] == "https://media.test/song.mp3"


@pytest.mark.asyncio
async def test_all_cooled_bases_probe_only_earliest_base():
    calls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.host or "")
        return httpx.Response(500)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        pool = BasePool(
            client,
            ("https://first.test", "https://second.test"),
            cooldown_seconds=60,
        )
        with pytest.raises(httpx.HTTPStatusError):
            await pool.request_json(params={})
        first_attempt_count = len(calls)
        with pytest.raises(httpx.HTTPStatusError):
            await pool.request_json(params={})

    assert first_attempt_count == 2
    assert len(calls) == 3
