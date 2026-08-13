#!/usr/bin/env python3
"""Compare GDStudio and Meting search quality, latency, paging, and resources."""

from __future__ import annotations

import argparse
import asyncio
import json
import statistics
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit, urlunsplit

import httpx

from app.adapters.gdstudio import GdstudioAdapter
from app.adapters.meting import MetingAdapter

QUERIES = (
    ("artist-zh", "周杰伦", ("周杰伦",)),
    ("artist-en", "Taylor Swift", ("taylor swift",)),
    ("song-zh", "晴天 周杰伦", ("晴天", "周杰伦")),
    ("song-en", "Love Story Taylor Swift", ("love story", "taylor swift")),
    ("band-zh", "海阔天空 Beyond", ("海阔天空", "beyond")),
    ("cold-zh", "漠河舞厅 柳爽", ("漠河舞厅", "柳爽")),
    ("artist-cantonese", "陈奕迅", ("陈奕迅",)),
    ("song-en-2", "Adele Hello", ("adele", "hello")),
    ("classic-en", "Hotel California Eagles", ("hotel california", "eagles")),
    ("no-result", "pi-diagnostic-no-such-song-9f3c", ()),
)


def safe_endpoint(value: str) -> str:
    parsed = urlsplit(value)
    if not parsed.scheme or not parsed.hostname:
        return "[invalid]"
    host = f"[{parsed.hostname}]" if ":" in parsed.hostname else parsed.hostname
    if parsed.port is not None:
        host = f"{host}:{parsed.port}"
    return urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def relevant_ratio(items: list[dict[str, Any]], expected: tuple[str, ...]) -> float:
    if not expected:
        return 1.0 if not items else 0.0
    relevant = 0
    sample = items[:10]
    for item in sample:
        haystack = f"{item.get('title', '')} {item.get('artist', '')}".casefold()
        if all(token.casefold() in haystack for token in expected):
            relevant += 1
    return relevant / len(sample) if sample else 0.0


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return round(ordered[index], 1)


async def benchmark(args: argparse.Namespace) -> dict[str, Any]:
    timeout = httpx.Timeout(args.timeout)
    async with httpx.AsyncClient(timeout=timeout) as client:
        adapters = {
            "gdstudio": GdstudioAdapter(
                client, (args.gdstudio,), cooldown_seconds=0, timeout=args.timeout
            ),
            "meting": MetingAdapter(
                client,
                (args.meting,),
                token=args.meting_token,
                cooldown_seconds=0,
                timeout=args.timeout,
            ),
        }
        attempts: list[dict[str, Any]] = []
        first_results: dict[str, dict[str, Any]] = {}
        for round_number in range(1, args.rounds + 1):
            for category, query, expected in QUERIES:
                for name, adapter in adapters.items():
                    started = time.perf_counter()
                    try:
                        items = await adapter.search(
                            query, source="netease", count=30, page=1
                        )
                        elapsed = (time.perf_counter() - started) * 1000
                        attempts.append(
                            {
                                "provider": name,
                                "round": round_number,
                                "category": category,
                                "query": query,
                                "ok": True,
                                "latencyMs": round(elapsed, 1),
                                "count": len(items),
                                "relevantTop10Ratio": round(
                                    relevant_ratio(items, expected), 3
                                ),
                                "top3": [
                                    {
                                        "id": item.get("id"),
                                        "title": item.get("title"),
                                        "artist": item.get("artist"),
                                    }
                                    for item in items[:3]
                                ],
                            }
                        )
                        if items and category != "no-result":
                            first_results.setdefault(name, items[0])
                    except Exception as exc:  # noqa: BLE001 - benchmark evidence
                        elapsed = (time.perf_counter() - started) * 1000
                        attempts.append(
                            {
                                "provider": name,
                                "round": round_number,
                                "category": category,
                                "query": query,
                                "ok": False,
                                "latencyMs": round(elapsed, 1),
                                "error": type(exc).__name__,
                            }
                        )
                    await asyncio.sleep(args.sleep)

        pagination: list[dict[str, Any]] = []
        for name, adapter in adapters.items():
            previous: set[str] = set()
            for page in (1, 2, 3):
                started = time.perf_counter()
                try:
                    items = await adapter.search(
                        "周杰伦", source="netease", count=30, page=page
                    )
                    ids = {str(item.get("id")) for item in items}
                    pagination.append(
                        {
                            "provider": name,
                            "page": page,
                            "ok": True,
                            "latencyMs": round(
                                (time.perf_counter() - started) * 1000, 1
                            ),
                            "count": len(items),
                            "overlapPrevious": len(ids & previous),
                        }
                    )
                    previous = ids
                except Exception as exc:  # noqa: BLE001 - benchmark evidence
                    pagination.append(
                        {
                            "provider": name,
                            "page": page,
                            "ok": False,
                            "latencyMs": round(
                                (time.perf_counter() - started) * 1000, 1
                            ),
                            "error": type(exc).__name__,
                        }
                    )
                await asyncio.sleep(args.sleep)

        resources: list[dict[str, Any]] = []
        for name, adapter in adapters.items():
            item = first_results.get(name)
            if not item:
                resources.append(
                    {"provider": name, "tested": False, "reason": "no search result"}
                )
                continue
            song_id = str(item["id"])
            checks: dict[str, Any] = {"provider": name, "tested": True}
            for kind in ("url", "cover", "lyric"):
                started = time.perf_counter()
                try:
                    if kind == "url":
                        value = await adapter.get_url(song_id, source="netease", br=999)
                    elif kind == "cover":
                        value = await adapter.get_cover(
                            song_id, source="netease", size=300
                        )
                    else:
                        value = await adapter.get_lyric(song_id, source="netease")
                    checks[kind] = {
                        "ok": bool(value.get("url") or value.get("lyric")),
                        "latencyMs": round((time.perf_counter() - started) * 1000, 1),
                    }
                except Exception as exc:  # noqa: BLE001 - benchmark evidence
                    checks[kind] = {
                        "ok": False,
                        "latencyMs": round((time.perf_counter() - started) * 1000, 1),
                        "error": type(exc).__name__,
                    }
                await asyncio.sleep(args.sleep)
            resources.append(checks)

    summaries: dict[str, Any] = {}
    for provider in ("gdstudio", "meting"):
        rows = [row for row in attempts if row["provider"] == provider]
        successful = [row for row in rows if row["ok"]]
        expected_rows = [row for row in successful if row["category"] != "no-result"]
        no_result_rows = [row for row in successful if row["category"] == "no-result"]
        summaries[provider] = {
            "attempts": len(rows),
            "requestSuccessRate": round(len(successful) / len(rows), 3),
            "nonEmptyRate": round(
                sum(row.get("count", 0) > 0 for row in expected_rows)
                / max(1, len(expected_rows)),
                3,
            ),
            "noResultEmptyRate": round(
                sum(row.get("count", 0) == 0 for row in no_result_rows)
                / max(1, len(no_result_rows)),
                3,
            ),
            "meanRelevantTop10Ratio": round(
                statistics.fmean(
                    row.get("relevantTop10Ratio", 0) for row in expected_rows
                ),
                3,
            ),
            "latencyP50Ms": percentile([row["latencyMs"] for row in successful], 0.5),
            "latencyP95Ms": percentile([row["latencyMs"] for row in successful], 0.95),
        }

    return {
        "generatedAtEpochMs": round(time.time() * 1000),
        "environment": args.environment,
        "endpoints": {
            "gdstudio": safe_endpoint(args.gdstudio),
            "meting": safe_endpoint(args.meting),
        },
        "rounds": args.rounds,
        "queries": [query for _, query, _ in QUERIES],
        "summary": summaries,
        "attempts": attempts,
        "pagination": pagination,
        "resources": resources,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gdstudio", default="https://music-api.gdstudio.xyz/api.php")
    parser.add_argument("--meting", default="https://meting.mikus.ink/api")
    parser.add_argument("--meting-token", default="")
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--sleep", type=float, default=0.4)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--environment", default="local")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = asyncio.run(benchmark(args))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
