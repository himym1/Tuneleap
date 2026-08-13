#!/usr/bin/env python3
"""Probe URL resolution rate for the first Meting search results."""

from __future__ import annotations

import argparse
import asyncio
import json

import httpx

from app.adapters.meting import MetingAdapter


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--token", default="")
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    queries = ("周杰伦", "晴天 周杰伦", "Taylor Swift", "海阔天空 Beyond")
    rows = []
    async with httpx.AsyncClient(timeout=20) as client:
        adapter = MetingAdapter(client, (args.base,), token=args.token, timeout=20)
        for query in queries:
            songs = await adapter.search(
                query, source="netease", count=args.limit, page=1
            )
            resolved = 0
            playable = 0
            for song in songs:
                try:
                    song_id = str(song["id"])
                    result = await adapter.get_url(song_id, source="netease", br=999)
                    resolved += bool(result.get("url"))
                    playable += await adapter.is_playable(
                        song_id, source="netease", br=999
                    )
                except httpx.HTTPError:
                    pass
                await asyncio.sleep(0.2)
            rows.append(
                {
                    "query": query,
                    "results": len(songs),
                    "resolvedUrls": resolved,
                    "resolvedRate": round(resolved / max(1, len(songs)), 3),
                    "playableUrls": playable,
                    "playableRate": round(playable / max(1, len(songs)), 3),
                }
            )
    print(json.dumps({"rows": rows}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
