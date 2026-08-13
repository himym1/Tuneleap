"""Canonical music platform ids shared by Cloud search and adapters."""

from __future__ import annotations

_SOURCE_ALIASES = {
    "qq": "tencent",
    "qqmusic": "tencent",
    "qq_music": "tencent",
}


def canonicalize_music_source(value: str | None) -> str | None:
    if value is None:
        return None
    text = value.strip().lower()
    if not text:
        return None
    return _SOURCE_ALIASES.get(text, text)
