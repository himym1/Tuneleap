"""Shared recommendation identity normalization."""
from __future__ import annotations

import re
import unicodedata
from collections.abc import Mapping

_SPACE_RE = re.compile(r"\s+")
_BRACKET_RE = re.compile(r"(\([^()]*\)|\[[^\[\]]*\])")
_VERSION_RE = re.compile(
    r"\b(?:acoustic|demo|edit|explicit|instrumental|karaoke|live|mix|mono|"
    r"radio|remaster(?:ed)?|remix|rework|stereo|version)\b"
)
_VERSION_SUFFIX_RE = re.compile(r"\s[-–—:]\s(?P<suffix>.+)$")
_FEATURED_ARTIST_RE = re.compile(
    r"\s+/\s+|\s+(?:feat(?:uring)?|ft)\.?\s+", re.IGNORECASE
)


def normalize_text(value: object) -> str:
    text = unicodedata.normalize("NFKC", str(value)).casefold()
    text = "".join(
        char if not unicodedata.category(char).startswith("P") else " "
        for char in text
    )
    return _SPACE_RE.sub(" ", text).strip()

def primary_artist(value: object) -> str:
    artist = unicodedata.normalize("NFKC", str(value)).casefold()
    return normalize_text(_FEATURED_ARTIST_RE.split(artist, maxsplit=1)[0])


def canonical_title(value: object) -> str:
    text = unicodedata.normalize("NFKC", str(value)).casefold()
    text = _BRACKET_RE.sub(
        lambda match: "" if _VERSION_RE.search(match.group()) else match.group(),
        text,
    )
    suffix = _VERSION_SUFFIX_RE.search(text)
    if suffix is not None and _VERSION_RE.search(suffix.group("suffix")):
        text = text[: suffix.start()]
    return normalize_text(text)


def weak_identity(song_or_title: object, artist: object | None = None) -> str:
    """Return a title/artist identity that collapses recording-version suffixes."""
    if artist is None:
        song = song_or_title
        title = song.get("title", "") if isinstance(song, Mapping) else getattr(song, "title", "")
        artist = song.get("artist", "") if isinstance(song, Mapping) else getattr(song, "artist", "")
    else:
        title = song_or_title

    return f"{canonical_title(title)}\x1f{primary_artist(artist)}"
