#!/usr/bin/env python3
"""One-shot ops helper: enrich audit findings via Cloud, apply via NAS media-tags.

Runs in three modes on the appropriate host. Never prints API keys.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

_SPACE_RE = re.compile(r"\s+")
_BRACKET_RE = re.compile(r"(\([^()]*\)|（[^（）]*）|\[[^\[\]]*\]|【[^【】]*】)")
_VERSION_RE = re.compile(
    r"(?:\b(?:acoustic|demo|edit|explicit|instrumental|karaoke|live|mix|mono|"
    r"radio|remaster(?:ed)?|remix|rework|stereo|version)\b|"
    r"^(?:国语|粤语|伴奏|现场|重制|混音|纯音乐|国|粤)(?:版)?$)",
    re.IGNORECASE,
)
_VERSION_SUFFIX_RE = re.compile(r"\s[-–—:]\s(?P<suffix>.+)$")
_FEATURED_ARTIST_RE = re.compile(r"\s+(?:feat(?:uring)?|ft)\.?\s+", re.IGNORECASE)
_SPACED_ARTIST_SEPARATOR_RE = re.compile(r"\s+[/&＆+•·、,，_]\s+")
_CJK_ARTIST_SEPARATOR_RE = re.compile(r"[/&＆+•·、,，_]")
_CJK_RE = re.compile(r"[\u3400-\u9fff]")
_TITLE_PREFIX_RE = re.compile(r"^(?P<prefix>.+?)\s[-–—]\s(?P<title>.+)$")


def normalize_text(value: object) -> str:
    text = unicodedata.normalize("NFKC", str(value)).casefold()
    text = "".join(
        char if not unicodedata.category(char).startswith("P") else " " for char in text
    )
    return _SPACE_RE.sub(" ", text).strip()


def _artist_tokens(value: object) -> tuple[str, ...]:
    artist = unicodedata.normalize("NFKC", str(value)).casefold()
    artist = _FEATURED_ARTIST_RE.split(artist, maxsplit=1)[0]
    splitter = (
        _CJK_ARTIST_SEPARATOR_RE if _CJK_RE.search(artist) else _SPACED_ARTIST_SEPARATOR_RE
    )
    artist = splitter.sub("|", artist)
    return tuple(sorted({token for part in artist.split("|") if (token := normalize_text(part))}))


def primary_artist(value: object) -> str:
    return "\x1e".join(_artist_tokens(value))


def _is_version_label(value: object) -> bool:
    return _VERSION_RE.search(normalize_text(value)) is not None


def canonical_title(value: object) -> str:
    text = unicodedata.normalize("NFKC", str(value)).casefold()
    text = _BRACKET_RE.sub(
        lambda match: "" if _is_version_label(match.group()) else match.group(),
        text,
    )
    suffix = _VERSION_SUFFIX_RE.search(text)
    if suffix is not None and _is_version_label(suffix.group("suffix")):
        text = text[: suffix.start()]
    return normalize_text(text)


def _song_title(value: object, artist: object) -> str:
    text = unicodedata.normalize("NFKC", str(value))
    prefixed = _TITLE_PREFIX_RE.match(text)
    if prefixed is not None:
        prefix = set(_artist_tokens(prefixed.group("prefix")))
        credits = set(_artist_tokens(artist))
        if prefix and prefix.issubset(credits):
            text = prefixed.group("title")
    return canonical_title(text)


def weak_identity(title: object, artist: object) -> str:
    return f"{_song_title(title, artist)}\x1f{primary_artist(artist)}"


def artist_text(value: object) -> str:
    if isinstance(value, list):
        return " / ".join(str(part) for part in value if str(part).strip())
    return str(value or "")


def dump_findings() -> None:
    from app.core.config import get_settings

    settings = get_settings()
    path = Path(settings.navidrome_db_path).parent / "library-audit.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    wanted = {"missing_cover", "tag_mismatch"}
    items = []
    for item in data.get("findings") or []:
        codes = set(item.get("codes") or [])
        hit = codes & wanted
        if not hit:
            continue
        items.append(
            {
                "song_id": item.get("song_id"),
                "title": item.get("title") or "",
                "artist": item.get("artist") or "",
                "album": item.get("album") or "",
                "codes": sorted(hit),
            }
        )
    json.dump({"items": items}, sys.stdout, ensure_ascii=False)


def _cloud_get(path: str, params: dict[str, str], key: str) -> dict:
    query = urllib.parse.urlencode(params)
    req = urllib.request.Request(
        f"http://127.0.0.1:8600{path}?{query}",
        headers={"X-API-Key": key},
    )
    with urllib.request.urlopen(req, timeout=25) as resp:
        payload = json.loads(resp.read().decode())
    if not isinstance(payload, dict):
        raise ValueError("cloud response must be an object")
    return payload


def enrich(findings_path: Path) -> None:
    key = os.environ.get("API_KEY", "")
    if not key:
        raise SystemExit("API_KEY missing")
    findings = json.loads(findings_path.read_text(encoding="utf-8"))["items"]
    plan: list[dict] = []
    skipped: list[dict] = []
    for item in findings:
        query = " ".join(part for part in (item["title"], item["artist"]) if part.strip())
        if not query.strip():
            skipped.append({"song_id": item["song_id"], "reason": "empty_query"})
            continue
        try:
            data = _cloud_get("/v1/music/search", {"q": query, "count": "5"}, key)
        except Exception as exc:
            skipped.append(
                {"song_id": item["song_id"], "reason": f"search_{type(exc).__name__}"}
            )
            time.sleep(0.35)
            continue
        target_id = weak_identity(item["title"], item["artist"])
        match = None
        for cand in data.get("items") or []:
            if not isinstance(cand, dict):
                continue
            cand_artist = artist_text(cand.get("artist"))
            if weak_identity(cand.get("title") or "", cand_artist) == target_id:
                match = cand
                break
        if match is None:
            skipped.append(
                {
                    "song_id": item["song_id"],
                    "reason": "no_high_conf_match",
                    "query": query,
                }
            )
            time.sleep(0.25)
            continue
        cover_url = None
        if "missing_cover" in item["codes"] and match.get("cover_id") and match.get("source"):
            try:
                cover = _cloud_get(
                    "/v1/music/cover",
                    {
                        "id": str(match.get("cover_id") or ""),
                        "source": str(match.get("source") or ""),
                        "provider": str(match.get("provider") or ""),
                    },
                    key,
                )
                cover_url = cover.get("url")
            except Exception:
                cover_url = None
        entry: dict = {
            "song_id": item["song_id"],
            "codes": item["codes"],
            "song": None,
            "pic_url": cover_url if "missing_cover" in item["codes"] else None,
        }
        if "tag_mismatch" in item["codes"]:
            entry["song"] = {
                "title": match.get("title") or item["title"],
                "artist": artist_text(match.get("artist")) or item["artist"],
                "album": match.get("album") or item["album"],
                "source": match.get("source"),
            }
        if entry["song"] is None and not entry["pic_url"]:
            skipped.append({"song_id": item["song_id"], "reason": "nothing_to_write"})
        else:
            plan.append(entry)
        time.sleep(0.25)
    json.dump({"plan": plan, "skipped": skipped}, sys.stdout, ensure_ascii=False)


def _nas_post(path: str, body: dict, key: str) -> dict:
    data = json.dumps(body).encode()
    last_error: Exception | None = None
    # Prefer NAS_AGENT_URL; otherwise try common local publish ports.
    env_base = (os.environ.get("NAS_AGENT_URL") or "").rstrip("/")
    bases = tuple(
        b
        for b in (
            env_base,
            "http://127.0.0.1:8504",
            "http://127.0.0.1:8503",
        )
        if b
    )
    for base in bases:
        req = urllib.request.Request(
            f"{base}{path}",
            data=data,
            headers={"X-API-Key": key, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                payload = json.loads(resp.read().decode())
            if isinstance(payload, dict):
                return payload
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:200]
            last_error = RuntimeError(f"HTTP{exc.code}:{detail}")
            continue
        except Exception as exc:  # noqa: BLE001 - ops script tries alternate hosts
            last_error = exc
            continue
    raise RuntimeError(str(last_error) if last_error else "nas_unreachable")


def apply_plan(plan_path: Path) -> None:
    key = os.environ.get("NAS_AGENT_KEY", "")
    if not key:
        raise SystemExit("NAS_AGENT_KEY missing")
    payload = json.loads(plan_path.read_text(encoding="utf-8"))
    updated = 0
    failed: list[dict] = []
    for entry in payload.get("plan") or []:
        body: dict = {"song_id": entry["song_id"]}
        if entry.get("song"):
            body["song"] = entry["song"]
        if entry.get("pic_url"):
            body["pic_url"] = entry["pic_url"]
        if "song" not in body and "pic_url" not in body:
            failed.append({"song_id": entry["song_id"], "reason": "empty_update"})
            continue
        try:
            result = _nas_post("/v1/nas/media-tags", body, key)
            if result.get("ok"):
                updated += 1
            else:
                failed.append(
                    {
                        "song_id": entry["song_id"],
                        "reason": str(result.get("message") or "not_ok"),
                    }
                )
        except Exception as exc:  # noqa: BLE001
            code = getattr(exc, "code", "")
            failed.append(
                {"song_id": entry["song_id"], "reason": f"{type(exc).__name__}:{code}"}
            )
        time.sleep(0.05)
    scan_ok = False
    try:
        scan = _nas_post("/v1/nas/scan", {}, key)
        scan_ok = bool(scan.get("ok"))
    except Exception:
        scan_ok = False
    json.dump(
        {"updated": updated, "failed": failed, "scan_ok": scan_ok},
        sys.stdout,
        ensure_ascii=False,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("dump", "enrich", "apply"))
    parser.add_argument("--input", type=Path)
    args = parser.parse_args()
    if args.mode == "dump":
        dump_findings()
    elif args.mode == "enrich":
        if args.input is None:
            raise SystemExit("--input required for enrich")
        enrich(args.input)
    else:
        if args.input is None:
            raise SystemExit("--input required for apply")
        apply_plan(args.input)


if __name__ == "__main__":
    main()
