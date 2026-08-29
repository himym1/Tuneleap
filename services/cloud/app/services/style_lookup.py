"""Look up a closed style from iTunes, then MusicBrainz.

Cloud music search is not used: adapters do not return genre and would
burn playback-upstream quota. NAS Agent only writes tags.
"""

from __future__ import annotations

import asyncio
import time
from collections import defaultdict
from typing import Any

import httpx

from app.services.recommendation_identity import primary_artist, weak_identity
from app.services.style_map import (
    COARSE_STYLES,
    extract_genre_text,
    map_closed_style,
    refine_coarse_style,
    script_storefronts,
)

_ITUNES_URL = "https://itunes.apple.com/search"
_MB_SEARCH_URL = "https://musicbrainz.org/ws/2/recording"
_MB_LOOKUP_URL = "https://musicbrainz.org/ws/2/recording/{mbid}"
_USER_AGENT = "Tuneleap-cloud/1.0 (https://github.com/himym1/Tuneleap)"


class StyleLookupHit:
    __slots__ = ("title", "artist", "style", "raw_genre", "provider")

    def __init__(
        self,
        *,
        title: str,
        artist: str,
        style: str | None,
        raw_genre: str | None,
        provider: str | None,
    ) -> None:
        self.title = title
        self.artist = artist
        self.style = style
        self.raw_genre = raw_genre
        self.provider = provider

    def as_dict(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "artist": self.artist,
            "style": self.style,
            "raw_genre": self.raw_genre,
            "provider": self.provider,
        }


class StyleLookupService:
    def __init__(
        self,
        client: httpx.AsyncClient,
        *,
        itunes_min_interval: float = 1.2,
        mb_min_interval: float = 1.1,
    ) -> None:
        self._client = client
        self._itunes_interval = itunes_min_interval
        self._mb_interval = mb_min_interval
        self._itunes_lock = asyncio.Lock()
        self._mb_lock = asyncio.Lock()
        self._itunes_next = 0.0
        self._mb_next = 0.0
        self._cache: dict[str, StyleLookupHit] = {}

    async def lookup_many(self, tracks: list[dict[str, Any]]) -> list[StyleLookupHit]:
        hits: list[StyleLookupHit | None] = [None] * len(tracks)
        pending: list[int] = []
        for index, track in enumerate(tracks):
            title = (track.get("title") or "").strip()
            artist = (track.get("artist") or "").strip()
            cached = self._cache.get(weak_identity(title, artist)) if title else None
            if cached is not None:
                hits[index] = StyleLookupHit(
                    title=title,
                    artist=artist,
                    style=cached.style,
                    raw_genre=cached.raw_genre,
                    provider=cached.provider,
                )
                continue
            pending.append(index)

        groups: dict[tuple[str, str], list[int]] = defaultdict(list)
        singles: list[int] = []
        for index in pending:
            track = tracks[index]
            album = (track.get("album") or "").strip()
            artist = (track.get("artist") or "").strip()
            if album and artist:
                groups[(primary_artist(artist), album.casefold())].append(index)
            else:
                singles.append(index)

        for indexes in groups.values():
            if len(indexes) >= 2:
                album_hit = await self._from_itunes_album(tracks[indexes[0]])
                if album_hit is not None and album_hit.style:
                    for index in indexes:
                        hits[index] = self._remember(tracks[index], album_hit)
                    continue
            singles.extend(indexes)

        for index in singles:
            if hits[index] is None:
                hits[index] = await self.lookup_one(tracks[index])

        return [hit if hit is not None else self._empty(tracks[index]) for index, hit in enumerate(hits)]

    async def lookup_one(self, track: dict[str, Any]) -> StyleLookupHit:
        title = (track.get("title") or "").strip()
        artist = (track.get("artist") or "").strip()
        if not title:
            return self._empty(track)
        cached = self._cache.get(weak_identity(title, artist))
        if cached is not None:
            return StyleLookupHit(
                title=title,
                artist=artist,
                style=cached.style,
                raw_genre=cached.raw_genre,
                provider=cached.provider,
            )
        itunes = await self._from_itunes_song(track)
        if itunes.style:
            return self._remember(track, itunes)
        mb = await self._from_musicbrainz(title, artist)
        if mb.style:
            return self._remember(track, mb)
        chosen = itunes if itunes.raw_genre else mb
        if chosen.style:
            return self._remember(track, chosen)
        marked = _title_marker_hit(track)
        if marked is not None:
            return self._remember(track, marked)
        return self._remember(track, chosen)

    async def _from_itunes_song(self, track: dict[str, Any]) -> StyleLookupHit:
        title = (track.get("title") or "").strip()
        artist = (track.get("artist") or "").strip()
        query = " ".join(part for part in (title, artist) if part)
        return await self._itunes_search(
            term=query,
            entity="song",
            title=title,
            artist=artist,
            match="song",
        )

    async def _from_itunes_album(self, track: dict[str, Any]) -> StyleLookupHit | None:
        title = (track.get("title") or "").strip()
        artist = (track.get("artist") or "").strip()
        album = (track.get("album") or "").strip()
        if not album or not artist:
            return None
        query = " ".join(part for part in (artist, album) if part)
        hit = await self._itunes_search(
            term=query,
            entity="album",
            title=title,
            artist=artist,
            match="album",
        )
        return hit if hit.style else None

    async def _itunes_search(
        self,
        *,
        term: str,
        entity: str,
        title: str,
        artist: str,
        match: str,
    ) -> StyleLookupHit:
        empty = StyleLookupHit(
            title=title,
            artist=artist,
            style=None,
            raw_genre=None,
            provider=None,
        )
        for country in script_storefronts(title, artist):
            payload = await self._itunes_get(term, entity, country)
            if payload is None:
                continue
            results = payload.get("results") if isinstance(payload, dict) else None
            if not isinstance(results, list):
                continue
            picked = _pick_itunes(results, title=title, artist=artist, match=match)
            if picked is None:
                continue
            raw_genre = extract_genre_text(picked.get("primaryGenreName"))
            style = map_closed_style(raw_genre, title=title, artist=artist)
            if style or raw_genre:
                return StyleLookupHit(
                    title=title,
                    artist=artist,
                    style=style,
                    raw_genre=raw_genre,
                    provider="itunes",
                )
        return empty

    async def _itunes_get(
        self, term: str, entity: str, country: str
    ) -> dict[str, Any] | None:
        await self._throttle(self._itunes_lock, "_itunes_next", self._itunes_interval)
        try:
            response = await self._client.get(
                _ITUNES_URL,
                params={
                    "term": term,
                    "entity": entity,
                    "limit": 5,
                    "country": country,
                },
                headers={"User-Agent": _USER_AGENT},
            )
            if response.status_code == 403:
                await asyncio.sleep(10)
                await self._throttle(
                    self._itunes_lock, "_itunes_next", self._itunes_interval
                )
                response = await self._client.get(
                    _ITUNES_URL,
                    params={
                        "term": term,
                        "entity": entity,
                        "limit": 5,
                        "country": country,
                    },
                    headers={"User-Agent": _USER_AGENT},
                )
            response.raise_for_status()
            payload = response.json()
        except Exception:  # noqa: BLE001 - lookup is best-effort
            return None
        return payload if isinstance(payload, dict) else None

    async def _from_musicbrainz(self, title: str, artist: str) -> StyleLookupHit:
        query = f'recording:"{_escape_mb(title)}"'
        if artist:
            query += f' AND artist:"{_escape_mb(artist)}"'
        payload = await self._mb_get(
            _MB_SEARCH_URL, params={"query": query, "fmt": "json", "limit": 5}
        )
        recordings = payload.get("recordings") if isinstance(payload, dict) else None
        if not isinstance(recordings, list):
            return StyleLookupHit(
                title=title,
                artist=artist,
                style=None,
                raw_genre=None,
                provider=None,
            )
        target = weak_identity(title, artist)
        chosen: dict[str, Any] | None = None
        for recording in recordings:
            if not isinstance(recording, dict):
                continue
            rec_title = str(recording.get("title") or "")
            rec_artist = _mb_artist(recording)
            if rec_title and weak_identity(rec_title, rec_artist or artist) != target:
                continue
            chosen = recording
            break
        if chosen is None and recordings and isinstance(recordings[0], dict):
            first_artist = _mb_artist(recordings[0])
            if first_artist and primary_artist(first_artist) == primary_artist(artist):
                chosen = recordings[0]
        if chosen is None:
            return StyleLookupHit(
                title=title,
                artist=artist,
                style=None,
                raw_genre=None,
                provider=None,
            )
        raw_genre = _mb_best_tag(chosen)
        if raw_genre is None:
            mbid = str(chosen.get("id") or "")
            if mbid:
                detail = await self._mb_get(
                    _MB_LOOKUP_URL.format(mbid=mbid),
                    params={"inc": "genres+tags", "fmt": "json"},
                )
                if isinstance(detail, dict):
                    raw_genre = _mb_best_tag(detail)
        style = map_closed_style(raw_genre, title=title, artist=artist)
        return StyleLookupHit(
            title=title,
            artist=artist,
            style=style,
            raw_genre=raw_genre,
            provider="musicbrainz" if raw_genre else None,
        )

    async def _mb_get(
        self, url: str, params: dict[str, str]
    ) -> dict[str, Any] | None:
        await self._throttle(self._mb_lock, "_mb_next", self._mb_interval)
        try:
            response = await self._client.get(
                url,
                params=params,
                headers={"User-Agent": _USER_AGENT},
            )
            response.raise_for_status()
            payload = response.json()
        except Exception:  # noqa: BLE001 - lookup is best-effort
            return None
        return payload if isinstance(payload, dict) else None

    async def _throttle(self, lock: asyncio.Lock, attr: str, interval: float) -> None:
        if interval <= 0:
            return
        async with lock:
            wait = getattr(self, attr) - time.monotonic()
            if wait > 0:
                await asyncio.sleep(wait)
            setattr(self, attr, time.monotonic() + interval)

    def _remember(self, track: dict[str, Any], hit: StyleLookupHit) -> StyleLookupHit:
        title = (track.get("title") or "").strip()
        artist = (track.get("artist") or "").strip()
        album = (track.get("album") or "").strip()
        style = hit.style
        refined = refine_coarse_style(
            style,
            title=title,
            artist=artist,
            album=album,
            year=_track_year(track),
        )
        if refined:
            style = refined
        stored = StyleLookupHit(
            title=title,
            artist=artist,
            style=style,
            raw_genre=hit.raw_genre,
            provider=hit.provider,
        )
        if title:
            self._cache[weak_identity(title, artist)] = stored
        return stored

    def _empty(self, track: dict[str, Any]) -> StyleLookupHit:
        return StyleLookupHit(
            title=(track.get("title") or "").strip(),
            artist=(track.get("artist") or "").strip(),
            style=None,
            raw_genre=None,
            provider=None,
        )


def _pick_itunes(
    results: list[Any],
    *,
    title: str,
    artist: str,
    match: str,
) -> dict[str, Any] | None:
    target = weak_identity(title, artist)
    target_artist = primary_artist(artist)
    exact: dict[str, Any] | None = None
    artist_only: dict[str, Any] | None = None
    for item in results:
        if not isinstance(item, dict):
            continue
        rec_artist = str(item.get("artistName") or "")
        if match == "song":
            rec_title = str(item.get("trackName") or item.get("collectionCensoredName") or "")
            if rec_title and weak_identity(rec_title, rec_artist or artist) == target:
                exact = item
                break
        if rec_artist and primary_artist(rec_artist) == target_artist:
            artist_only = artist_only or item
    return exact or artist_only


def _title_marker_hit(track: dict[str, Any]) -> StyleLookupHit | None:
    """When upstreams miss, still apply specific title/album/year markers."""
    title = (track.get("title") or "").strip()
    artist = (track.get("artist") or "").strip()
    album = (track.get("album") or "").strip()
    if not title:
        return None
    specific = map_closed_style(f"{title} {album}", title=title, artist=artist)
    if specific and specific not in COARSE_STYLES:
        return StyleLookupHit(
            title=title,
            artist=artist,
            style=specific,
            raw_genre=None,
            provider="title-markers",
        )
    for bucket in ("华语流行", "欧美流行"):
        refined = refine_coarse_style(
            bucket,
            title=title,
            artist=artist,
            album=album,
            year=_track_year(track),
        )
        if refined is not None:
            return StyleLookupHit(
                title=title,
                artist=artist,
                style=refined,
                raw_genre=None,
                provider="title-markers",
            )
    return None


def _track_year(track: dict[str, Any]) -> int | None:
    raw = track.get("year")
    if isinstance(raw, bool):
        return None
    if isinstance(raw, int):
        return raw if 1900 <= raw < 2090 else None
    if isinstance(raw, str) and raw.strip().isdigit():
        value = int(raw.strip())
        return value if 1900 <= value < 2090 else None
    return None


def _escape_mb(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _mb_artist(recording: dict[str, Any]) -> str:
    credits = recording.get("artist-credit")
    if not isinstance(credits, list):
        return ""
    names: list[str] = []
    for credit in credits:
        if isinstance(credit, dict):
            artist = credit.get("name") or (credit.get("artist") or {}).get("name")
            if artist:
                names.append(str(artist))
    return " / ".join(names)


def _mb_best_tag(recording: dict[str, Any]) -> str | None:
    for key in ("genres", "tags"):
        tags = recording.get(key)
        if not isinstance(tags, list) or not tags:
            continue
        scored: list[tuple[int, str]] = []
        for tag in tags:
            if not isinstance(tag, dict):
                continue
            name = str(tag.get("name") or "").strip()
            if not name:
                continue
            count = tag.get("count")
            score = int(count) if isinstance(count, int) else 0
            scored.append((score, name))
        if scored:
            scored.sort(reverse=True)
            return scored[0][1]
    return extract_genre_text(recording)
