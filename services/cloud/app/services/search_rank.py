"""Rank keyword hits so artist queries surface the artist's own catalog first."""

from __future__ import annotations

import re
import unicodedata

from app.models.schemas import SongDTO

_LIVE_RE = re.compile(r"\blive\b|现场|演唱会", re.IGNORECASE)
_DJ_RE = re.compile(r"\bdj\b|remix|混音", re.IGNORECASE)
_BEAT_RE = re.compile(r"\bbeat\b|type beat|伴奏|纯音乐", re.IGNORECASE)
_COVER_RE = re.compile(
    r"翻唱|女声|男声|钢琴版|古筝|吉他版|原唱|cover|铃声",
    re.IGNORECASE,
)


def _fold(value: str) -> str:
    return unicodedata.normalize("NFKC", value).casefold().strip()


def _artists(artist: str) -> list[str]:
    text = artist.replace("、", "/").replace(",", "/").replace("&", "/").replace("＆", "/")
    return [part.strip() for part in text.split("/") if part.strip()]


def looks_like_artist_query(query: str, items: list[SongDTO]) -> bool:
    needle = _fold(query)
    if len(needle) < 2 or not items:
        return False
    sample = items[:20]
    hits = 0
    for item in sample:
        names = [_fold(name) for name in _artists(item.artist)]
        if any(needle == name or needle in name or name in needle for name in names):
            hits += 1
    return hits >= min(3, max(1, len(sample) // 3))


def search_hit_score(query: str, item: SongDTO) -> int:
    needle = _fold(query)
    title = item.title or ""
    title_fold = _fold(title)
    artists = [_fold(name) for name in _artists(item.artist)]
    primary = artists[0] if artists else ""
    score = 0
    if needle and primary == needle:
        score += 100
        if len(artists) == 1:
            score += 30
    elif needle and needle in artists:
        score += 50
    elif needle and any(needle in name or name in needle for name in artists):
        score += 20
    if needle and title_fold == needle:
        score += 40
    elif needle and needle in title_fold:
        score += 10
    if _BEAT_RE.search(title) or _BEAT_RE.search(title_fold):
        score -= 90
    if _DJ_RE.search(title_fold):
        score -= 60
    if _COVER_RE.search(title):
        score -= 50
    if _LIVE_RE.search(title) or _LIVE_RE.search(title_fold):
        score -= 25
    return score


def rank_search_hits(query: str, items: list[SongDTO]) -> list[SongDTO]:
    return [
        item
        for _, _, item in sorted(
            (
                -search_hit_score(query, item),
                index,
                item,
            )
            for index, item in enumerate(items)
        )
    ]
