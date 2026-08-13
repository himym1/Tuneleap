#!/usr/bin/env python3
"""Read-only ChKSz probe. Uses a few calls so the daily quota is not burned.

The API key is read from CHKSZ_API_KEY or services/cloud/.env. It is never printed.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import time
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import httpx

BASE_URL = "https://api.chksz.com"
ENV_KEY = "CHKSZ_API_KEY"
DEFAULT_ENV_PATH = Path(__file__).resolve().parents[1] / ".env"


def _load_env_file(path: Path) -> None:
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        name = name.strip()
        if name != ENV_KEY or name in os.environ:
            continue
        os.environ[name] = value.strip().strip("'").strip('"')


def _redact_url(url: str) -> str:
    parsed = urlsplit(url)
    query = [
        (key, "[redacted]" if key.lower() in {"apikey", "key", "token"} else value)
        for key, value in parse_qsl(parsed.query, keep_blank_values=True)
    ]
    return urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urlencode(query), parsed.fragment)
    )


def _summarize_url(url: str) -> str:
    parsed = urlsplit(url)
    if not parsed.scheme or not parsed.hostname:
        return "[invalid]"
    suffix = Path(parsed.path).suffix.lower()
    return f"{parsed.scheme}://{parsed.hostname}/…{suffix or ''}"


async def _request(
    client: httpx.AsyncClient,
    path: str,
    params: dict[str, Any],
    api_key: str,
) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        response = await client.get(
            f"{BASE_URL}{path}",
            params={**params, "apikey": api_key},
        )
        elapsed = round((time.perf_counter() - started) * 1000, 1)
        payload: Any
        try:
            payload = response.json()
        except ValueError:
            payload = {"raw": response.text[:120]}
        return {
            "ok": response.is_success,
            "status": response.status_code,
            "latencyMs": elapsed,
            "quotaFree": response.headers.get("x-quota-free-remaining"),
            "quotaPaid": response.headers.get("x-quota-paid-remaining"),
            "rateLimit": response.headers.get("x-ratelimit-limit"),
            "payload": payload,
        }
    except httpx.HTTPError as exc:
        return {
            "ok": False,
            "status": 0,
            "latencyMs": round((time.perf_counter() - started) * 1000, 1),
            "error": type(exc).__name__,
            "url": _redact_url(str(exc.request.url)) if exc.request else path,
        }


def _search_items(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, dict):
        return []
    data = payload.get("data")
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        for key in ("songs", "list", "records"):
            items = data.get(key)
            if isinstance(items, list):
                return [item for item in items if isinstance(item, dict)]
    items = payload.get("list")
    if isinstance(items, list):
        return [item for item in items if isinstance(item, dict)]
    return []


def _relevant(item: dict[str, Any], expected: tuple[str, ...]) -> bool:
    haystack = " ".join(
        str(item.get(key) or "")
        for key in ("name", "title", "artists", "artist", "singer")
    ).casefold()
    return all(token.casefold() in haystack for token in expected)


async def _playable(client: httpx.AsyncClient, url: str) -> dict[str, Any]:
    if not url:
        return {"ok": False, "error": "empty-url"}
    started = time.perf_counter()
    try:
        async with client.stream(
            "GET",
            url,
            headers={"Range": "bytes=0-0", "User-Agent": "Mozilla/5.0"},
            follow_redirects=True,
        ) as response:
            chunk = b""
            async for part in response.aiter_bytes():
                chunk = part
                break
            return {
                "ok": response.is_success or response.status_code == 206,
                "status": response.status_code,
                "latencyMs": round((time.perf_counter() - started) * 1000, 1),
                "hasBody": bool(chunk),
                "contentType": response.headers.get("content-type", ""),
                "url": _summarize_url(str(response.url)),
            }
    except httpx.HTTPError as exc:
        return {
            "ok": False,
            "error": type(exc).__name__,
            "latencyMs": round((time.perf_counter() - started) * 1000, 1),
        }


async def probe(api_key: str, timeout: float) -> dict[str, Any]:
    timeout_cfg = httpx.Timeout(timeout)
    calls = 0
    async with httpx.AsyncClient(timeout=timeout_cfg) as client:
        netease_search = await _request(
            client,
            "/api/163_search",
            {"keyword": "晴天 周杰伦", "limit": 5, "offset": 0},
            api_key,
        )
        calls += 1
        items = _search_items(netease_search.get("payload"))
        first = items[0] if items else {}
        song_id = str(first.get("id") or "")

        netease_empty = await _request(
            client,
            "/api/163_search",
            {"keyword": "pi-diagnostic-no-such-song-9f3c", "limit": 5},
            api_key,
        )
        calls += 1

        music = (
            await _request(
                client,
                "/api/163_music",
                {"id": song_id, "level": "exhigh", "type": "json"},
                api_key,
            )
            if song_id
            else {"ok": False, "error": "no-search-id"}
        )
        if song_id:
            calls += 1
        music_data = (
            music.get("payload", {}).get("data")
            if isinstance(music.get("payload"), dict)
            else {}
        )
        if not isinstance(music_data, dict):
            music_data = {}
        play_url = str(music_data.get("url") or "")

        lyric = (
            await _request(client, "/api/163_lyric", {"id": song_id}, api_key)
            if song_id
            else {"ok": False, "error": "no-search-id"}
        )
        if song_id:
            calls += 1
        lyric_data = (
            lyric.get("payload", {}).get("data")
            if isinstance(lyric.get("payload"), dict)
            else {}
        )
        if not isinstance(lyric_data, dict):
            lyric_data = {}

        playable = await _playable(client, play_url)

        qq_search = await _request(
            client, "/api/qq_music", {"msg": "晴天", "num": 3, "type": "json"}, api_key
        )
        calls += 1
        qq_items = _search_items(qq_search.get("payload"))
        qq_mid = str((qq_items[0].get("mid") if qq_items else "") or "")
        qq_detail = (
            await _request(
                client,
                "/api/qq_music",
                {"mid": qq_mid, "size": "320k", "type": "json"},
                api_key,
            )
            if qq_mid
            else {"ok": False, "error": "no-qq-mid"}
        )
        if qq_mid:
            calls += 1
        qq_url = ""
        if isinstance(qq_detail.get("payload"), dict):
            qq_url = str(qq_detail["payload"].get("url") or "")
        qq_playable = await _playable(client, qq_url)

        kugou_search = await _request(
            client, "/api/kugou_music", {"msg": "晴天", "type": "json"}, api_key
        )
        calls += 1
        kugou_items = _search_items(kugou_search.get("payload"))
        kugou_id = str((kugou_items[0].get("id") if kugou_items else "") or "")
        kugou_detail = (
            await _request(
                client,
                "/api/kugou_music",
                {"id": kugou_id, "size": "320k", "type": "json"},
                api_key,
            )
            if kugou_id
            else {"ok": False, "error": "no-kugou-id"}
        )
        if kugou_id:
            calls += 1
        kugou_url = ""
        if isinstance(kugou_detail.get("payload"), dict):
            kugou_url = str(kugou_detail["payload"].get("url") or "")
        kugou_playable = await _playable(client, kugou_url)

    return {
        "calls": calls,
        "netease": {
            "searchOk": bool(netease_search.get("ok")),
            "searchStatus": netease_search.get("status"),
            "searchLatencyMs": netease_search.get("latencyMs"),
            "resultCount": len(items),
            "relevantTop5": sum(_relevant(item, ("晴天", "周杰伦")) for item in items),
            "emptyQueryCount": len(_search_items(netease_empty.get("payload"))),
            "emptyQueryStatus": netease_empty.get("status"),
            "parseOk": bool(music.get("ok") and play_url),
            "parseStatus": music.get("status"),
            "br": music_data.get("br"),
            "level": music_data.get("level"),
            "hasCover": bool(music_data.get("picUrl") or first.get("picUrl")),
            "lyricOk": bool(lyric.get("ok") and lyric_data.get("lrc")),
            "playable": playable,
            "quotaFreeRemaining": music.get("quotaFree") or netease_search.get("quotaFree"),
        },
        "qq": {
            "searchOk": bool(qq_search.get("ok")),
            "searchStatus": qq_search.get("status"),
            "resultCount": len(qq_items),
            "parseOk": bool(qq_detail.get("ok") and qq_url),
            "playable": qq_playable,
        },
        "kugou": {
            "searchOk": bool(kugou_search.get("ok")),
            "searchStatus": kugou_search.get("status"),
            "resultCount": len(kugou_items),
            "parseOk": bool(kugou_detail.get("ok") and kugou_url),
            "playable": kugou_playable,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_PATH)
    parser.add_argument("--timeout", type=float, default=20.0)
    args = parser.parse_args()
    _load_env_file(args.env_file)
    api_key = os.environ.get(ENV_KEY, "").strip()
    if not api_key:
        raise SystemExit(
            f"missing {ENV_KEY}; put it in {args.env_file} or the environment"
        )
    report = asyncio.run(probe(api_key, args.timeout))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
