"""Normalize upstream song payloads into SongDTO-compatible dicts."""

from __future__ import annotations

from typing import Any


def _as_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    if isinstance(value, list):
        return " / ".join(str(part) for part in value if part not in (None, ""))
    text = str(value).strip()
    return text or default


def _as_optional_str(value: Any) -> str | None:
    text = _as_str(value)
    return text or None


def _as_optional_float(value: Any) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def normalize_song(raw: dict[str, Any], *, provider: str, default_source: str | None = None) -> dict[str, Any] | None:
    song_id = _as_optional_str(
        raw.get("id")
        or raw.get("songid")
        or raw.get("song_id")
        or raw.get("url_id")
        or raw.get("urlId")
    )
    title = _as_str(raw.get("title") or raw.get("name") or raw.get("song"))
    if not song_id or not title:
        return None

    source = _as_str(
        raw.get("source") or raw.get("online_source") or raw.get("server") or default_source or "netease"
    )
    url_id = _as_optional_str(raw.get("url_id") or raw.get("urlId") or song_id)
    cover_id = _as_optional_str(
        raw.get("cover_id")
        or raw.get("pic_id")
        or raw.get("picId")
        or raw.get("album_id")
        or raw.get("albumId")
        or song_id
    )
    lyric_id = _as_optional_str(raw.get("lyric_id") or raw.get("lyricId") or song_id)
    duration = _as_optional_float(raw.get("duration") or raw.get("dt") or raw.get("time"))
    if duration is not None and duration > 1000:
        # some sources return milliseconds
        duration = duration / 1000.0

    return {
        "id": song_id,
        "title": title,
        "artist": _as_str(raw.get("artist") or raw.get("singer") or raw.get("author")),
        "album": _as_str(raw.get("album")),
        "source": source,
        "provider": provider,
        "url_id": url_id,
        "cover_id": cover_id,
        "lyric_id": lyric_id,
        "duration": duration,
        "raw": raw,
    }


def normalize_songs(
    items: Any, *, provider: str, default_source: str | None = None
) -> list[dict[str, Any]]:
    if not isinstance(items, list):
        return []
    songs: list[dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        song = normalize_song(item, provider=provider, default_source=default_source)
        if song is not None:
            songs.append(song)
    return songs


def extract_url_payload(payload: Any) -> str | None:
    if isinstance(payload, str) and payload.strip():
        return payload.strip()
    if not isinstance(payload, dict):
        return None
    for key in ("url", "brurl", "src", "data"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
        if isinstance(value, dict):
            nested = extract_url_payload(value)
            if nested:
                return nested
    return None


def extract_lyric_payload(payload: Any) -> str:
    if isinstance(payload, str):
        return payload if payload.strip() else ""
    if not isinstance(payload, dict):
        return ""
    for key in ("lyric", "lrc", "lyrics", "data"):
        value = payload.get(key)
        if isinstance(value, str):
            if value.strip():
                return value
            continue
        if isinstance(value, dict):
            nested = extract_lyric_payload(value)
            if nested:
                return nested
    return ""
