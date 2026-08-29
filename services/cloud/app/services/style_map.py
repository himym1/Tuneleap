"""Map upstream / MusicBrainz genre tags onto the closed 音跃 style set."""

from __future__ import annotations

import re
from typing import Any

CLOSED_STYLES = frozenset(
    {
        "华语流行",
        "粤语流行",
        "抒情情歌",
        "经典老歌",
        "民谣",
        "摇滚",
        "R&B",
        "电子舞曲",
        "嘻哈说唱",
        "轻音乐",
        "影视原声",
        "日本流行",
        "欧美流行",
        "欧美民谣",
    }
)

# iTunes often returns only Mandopop / Pop; these are language buckets, not final taste.
COARSE_STYLES = frozenset({"华语流行", "欧美流行"})

_CJK_RE = re.compile(r"[\u3400-\u9fff]")
_KANA_RE = re.compile(r"[\u3040-\u30ff]")

_EXACT_MAP = {
    "华语流行": "华语流行",
    "粤语流行": "粤语流行",
    "抒情情歌": "抒情情歌",
    "经典老歌": "经典老歌",
    "民谣": "民谣",
    "摇滚": "摇滚",
    "r&b": "R&B",
    "电子舞曲": "电子舞曲",
    "嘻哈说唱": "嘻哈说唱",
    "轻音乐": "轻音乐",
    "影视原声": "影视原声",
    "日本流行": "日本流行",
    "欧美流行": "欧美流行",
    "欧美民谣": "欧美民谣",
    "国语流行": "华语流行",
    "國語流行": "华语流行",
    "國語流行樂": "华语流行",
    "国语流行乐": "华语流行",
    "mandopop": "华语流行",
    "mando-pop": "华语流行",
    "マンドポップ": "华语流行",
    "粵語流行": "粤语流行",
    "粵語流行樂": "粤语流行",
    "粤语流行乐": "粤语流行",
    "cantopop": "粤语流行",
    "j-pop": "日本流行",
    "jpop": "日本流行",
}

_UNMAPPED = (
    "k-pop",
    "kpop",
    "korean pop",
    "jazz",
    "reggae",
    "latin",
    "blues",
)

_HINT_MAP: list[tuple[tuple[str, ...], str]] = [
    (("粤语", "cantopop", "cantonese", "廣東歌", "广东歌", "香港流行"), "粤语流行"),
    (
        ("主题曲", "片头", "片尾", "原声", "soundtrack", "ost", "film score", "anime"),
        "影视原声",
    ),
    (
        ("轻音乐", "instrumental", "new age", "piano", "classical", "easy listening"),
        "轻音乐",
    ),
    (("说唱", "嘻哈", "hip hop", "hip-hop", "rap"), "嘻哈说唱"),
    (("摇滚", "rock", "punk", "metal"), "摇滚"),
    (("r&b", "rnb", "rhythm and blues", "soul"), "R&B"),
    (("电音", "舞曲", "edm", "electronic", "house", "techno", "dance"), "电子舞曲"),
    (("情歌", "ballad"), "抒情情歌"),
    (("时代曲", "老歌"), "经典老歌"),
    (("j-pop", "jpop", "city pop", "日本"), "日本流行"),
    (("country", "americana", "singer/songwriter"), "欧美民谣"),
    (("mandopop", "c-pop", "cpop", "华语", "国语流行", "國語流行"), "华语流行"),
    (("民谣", "folk"), "民谣"),
    (("流行", "pop"), "流行"),
]


def extract_genre_text(raw: Any) -> str | None:
    if raw is None:
        return None
    if isinstance(raw, str):
        text = raw.strip()
        return text or None
    if isinstance(raw, list):
        for item in raw:
            found = extract_genre_text(item)
            if found:
                return found
        return None
    if not isinstance(raw, dict):
        return None
    for key in ("genre", "genres", "style", "styles", "tag", "tags", "曲风", "tcon"):
        if key not in raw:
            continue
        found = extract_genre_text(raw[key])
        if found:
            return found
        value = raw[key]
        if isinstance(value, dict):
            found = extract_genre_text(value.get("name") or value.get("title"))
            if found:
                return found
        if isinstance(value, list):
            names = []
            for item in value:
                if isinstance(item, str) and item.strip():
                    names.append(item.strip())
                elif isinstance(item, dict):
                    name = item.get("name") or item.get("title")
                    if isinstance(name, str) and name.strip():
                        names.append(name.strip())
            if names:
                return names[0]
    return None


def map_closed_style(
    raw_genre: str | None,
    *,
    title: str = "",
    artist: str = "",
) -> str | None:
    if raw_genre is None:
        return None
    cleaned = raw_genre.strip()
    if not cleaned:
        return None
    if cleaned in CLOSED_STYLES:
        return cleaned
    lowered = cleaned.casefold()
    exact = _EXACT_MAP.get(lowered)
    if exact:
        return exact
    blob = f"{lowered} {title} {artist}".casefold()
    if any(needle in blob for needle in _UNMAPPED):
        return None
    for needles, style in _HINT_MAP:
        if any(needle in blob for needle in needles):
            if style == "流行":
                return _pop_by_language(title, artist)
            if style == "民谣":
                return "民谣" if _CJK_RE.search(f"{title}{artist}") else "欧美民谣"
            return style
    return None


def _pop_by_language(title: str, artist: str) -> str:
    text = f"{title}{artist}"
    if _KANA_RE.search(text):
        return "日本流行"
    if _CJK_RE.search(text):
        return "华语流行"
    return "欧美流行"


def refine_coarse_style(
    style: str | None,
    *,
    title: str = "",
    artist: str = "",
    album: str = "",
    year: int | None = None,
) -> str | None:
    """Split Mandopop/Pop buckets using title/album/year markers.

    Returns a more specific closed style, or None to keep ``style``.
    """
    if style not in COARSE_STYLES:
        return None
    marker_blob = f"{title} {album}".strip()
    if marker_blob:
        specific = map_closed_style(marker_blob, title=title, artist=artist)
        if (
            specific
            and specific != style
            and specific in CLOSED_STYLES
            and specific not in COARSE_STYLES
        ):
            return specific
    if (
        style == "华语流行"
        and isinstance(year, int)
        and 1900 <= year < 1990
        and _CJK_RE.search(f"{title}{artist}")
    ):
        return "经典老歌"
    return None


def script_storefronts(title: str, artist: str) -> tuple[str, ...]:
    """iTunes storefronts most likely to keep the original title script."""
    text = f"{title}{artist}"
    if _KANA_RE.search(text):
        return ("jp", "us")
    if _CJK_RE.search(text):
        return ("cn", "hk")
    return ("us", "gb")
