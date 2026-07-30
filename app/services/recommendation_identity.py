"""Shared recommendation identity normalization."""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Mapping

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
    text = "".join(char if not unicodedata.category(char).startswith("P") else " " for char in text)
    return _SPACE_RE.sub(" ", text).strip()


def _artist_tokens(value: object) -> tuple[str, ...]:
    artist = unicodedata.normalize("NFKC", str(value)).casefold()
    artist = _FEATURED_ARTIST_RE.split(artist, maxsplit=1)[0]
    splitter = _CJK_ARTIST_SEPARATOR_RE if _CJK_RE.search(artist) else _SPACED_ARTIST_SEPARATOR_RE
    artist = splitter.sub("|", artist)
    return tuple(sorted({token for part in artist.split("|") if (token := normalize_text(part))}))


def primary_artist(value: object) -> str:
    """Return an order-independent canonical artist-credit identity."""
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


def weak_identity(song_or_title: object, artist: object | None = None) -> str:
    """Return a title/artist identity that collapses common metadata variants."""
    if artist is None:
        song = song_or_title
        title = song.get("title", "") if isinstance(song, Mapping) else getattr(song, "title", "")
        artist = (
            song.get("artist", "") if isinstance(song, Mapping) else getattr(song, "artist", "")
        )
    else:
        title = song_or_title

    return f"{_song_title(title, artist)}\x1f{primary_artist(artist)}"
