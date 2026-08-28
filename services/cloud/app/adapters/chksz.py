"""ChKSz adapter: NetEase / QQ / Kugou only. Never first in MUSIC_ADAPTER_ORDER."""

from __future__ import annotations

import asyncio
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

from app.adapters.base import MusicAdapter
from app.adapters.normalize import extract_lyric_payload, normalize_songs
from app.adapters.search_window import CLOUD_SEARCH_COUNT_MAX, SearchWindow
from app.core.sources import canonicalize_music_source

SUPPORTED_SOURCES = frozenset({"netease", "tencent", "kugou"})
_KUGOU_PAGE_SIZE_MAX = 20
_REQUEST_INTERVAL_SECONDS = 0.35
_RATE_LIMIT_RETRY_DELAYS = (0.75, 1.5)
_MAX_RETRY_AFTER_SECONDS = 3.0
_NOT_FOUND_RETRY_DELAY_SECONDS = 0.75
_DETAIL_CACHE_TTL_SECONDS = 60.0
_SEARCH_CACHE_TTL_SECONDS = 45.0
_CHINA_TIMEZONE = timezone(timedelta(hours=8))
_QQ_SONG_DETAIL_URL = "https://c.y.qq.com/v8/fcg-bin/fcg_play_single_song.fcg"
_QQ_COVER_SIZES = (150, 300, 500, 800)
_QQ_COVER_TEMPLATE = (
    "https://y.gtimg.cn/music/photo_new/T002R{size}x{size}M000{album_mid}.jpg"
)


def _netease_level(br: int) -> str:
    if br >= 999:
        return "jymaster"
    if br >= 740:
        return "hires"
    if br >= 320:
        return "exhigh"
    return "standard"


def _common_size(br: int) -> str:
    if br >= 999:
        return "master"
    if br >= 740:
        return "hires"
    if br >= 320:
        return "320k"
    return "128k"


def _search_items(payload: dict[str, Any]) -> list[dict[str, Any]]:
    data = payload.get("data")
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        for key in ("songs", "list", "records"):
            items = data.get(key)
            if isinstance(items, list):
                return [item for item in items if isinstance(item, dict)]
    items = payload.get("list")
    if isinstance(items, list):
        return [item for item in items if isinstance(item, dict)]
    return []


def _is_http_url(value: str) -> bool:
    return value.startswith(("http://", "https://"))


def _qq_cover_pixel(size: int) -> int:
    for candidate in _QQ_COVER_SIZES:
        if size <= candidate:
            return candidate
    return _QQ_COVER_SIZES[-1]


def _qq_album_cover_url(album_mid: str, size: int = 300) -> str | None:
    mid = album_mid.strip().split("_", 1)[0]
    if not mid:
        return None
    return _QQ_COVER_TEMPLATE.format(size=_qq_cover_pixel(size), album_mid=mid)


def _album_mid_from_mapping(raw: dict[str, Any]) -> str | None:
    album = raw.get("album")
    candidates = (
        raw.get("albummid"),
        raw.get("albumMid"),
        raw.get("album_mid"),
        raw.get("pmid"),
        album.get("mid") if isinstance(album, dict) else None,
        album.get("pmid") if isinstance(album, dict) else None,
    )
    for value in candidates:
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _tencent_album_mid(payload: dict[str, Any]) -> str | None:
    data = payload.get("data")
    items: list[Any] = []
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        nested = data.get("list") or data.get("songs")
        items = nested if isinstance(nested, list) else [data]
    for item in items:
        if isinstance(item, dict):
            mid = _album_mid_from_mapping(item)
            if mid:
                return mid
    return _album_mid_from_mapping(payload)


def _item_cover_url(raw: dict[str, Any]) -> str | None:
    for key in ("picUrl", "cover", "pic", "img", "imgUrl", "album_img"):
        value = raw.get(key)
        if isinstance(value, str) and _is_http_url(value.strip()):
            return value.strip()
    album = raw.get("album")
    if isinstance(album, dict):
        for key in ("picUrl", "cover", "pic"):
            value = album.get(key)
            if isinstance(value, str) and _is_http_url(value.strip()):
                return value.strip()
    album_mid = _album_mid_from_mapping(raw)
    if album_mid:
        return _qq_album_cover_url(album_mid)
    return None


def _prepare_item(raw: dict[str, Any], *, source: str) -> dict[str, Any]:
    prepared = dict(raw)
    song_id = raw.get("id") or raw.get("mid") or raw.get("songid")
    if song_id not in (None, ""):
        prepared["id"] = song_id
    artist = raw.get("artist") or raw.get("artists") or raw.get("singer")
    if artist not in (None, ""):
        prepared["artist"] = artist
    cover = _item_cover_url(raw)
    if cover is not None:
        prepared["cover_id"] = cover
    prepared["source"] = source
    return prepared


def _payload_detail(payload: dict[str, Any]) -> dict[str, Any]:
    data = payload.get("data")
    return data if isinstance(data, dict) else payload


def _payload_url(payload: dict[str, Any]) -> str | None:
    data = payload.get("data")
    if isinstance(data, dict):
        url = data.get("url")
        if isinstance(url, str) and url.strip():
            return url.strip()
    url = payload.get("url")
    if isinstance(url, str) and url.strip():
        return url.strip()
    return None


def _payload_bitrate_kbps(payload: dict[str, Any], fallback: int) -> int:
    raw = _payload_detail(payload).get("br")
    if raw is None:
        raw = _payload_detail(payload).get("bitrate")
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return fallback
    if value >= 10_000:
        value //= 1000
    return value if value > 0 else fallback


def _payload_size(payload: dict[str, Any]) -> int | None:
    raw = _payload_detail(payload).get("size")
    if raw is None:
        raw = _payload_detail(payload).get("fileSize")
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return None
    return value if value > 0 else None


def _audio_type_from_url(url: str) -> str | None:
    path = url.split("?", 1)[0]
    suffix = path.rsplit(".", 1)[-1].lower() if "." in path.rsplit("/", 1)[-1] else ""
    if suffix in {"flac", "mp3", "m4a", "aac", "ogg", "wav", "ape", "dsf", "dff"}:
        return suffix
    return None


def _payload_audio_type(payload: dict[str, Any], url: str) -> str | None:
    detail = _payload_detail(payload)
    for key in ("type", "format", "encodeType", "suffix"):
        raw = detail.get(key)
        if isinstance(raw, str) and raw.strip():
            value = raw.strip().lstrip(".").lower()
            if value in {"flac", "mp3", "m4a", "aac", "ogg", "wav", "ape"}:
                return value
    return _audio_type_from_url(url)


def _payload_cover(payload: dict[str, Any]) -> str | None:
    data = payload.get("data")
    candidates = []
    if isinstance(data, dict):
        candidates.extend((data.get("cover"), data.get("picUrl")))
    candidates.extend((payload.get("cover"), payload.get("picUrl")))
    for value in candidates:
        if isinstance(value, str) and _is_http_url(value.strip()):
            return value.strip()
    return None


class ChkszAdapter(MusicAdapter):
    name = "chksz"
    supported_sources = SUPPORTED_SOURCES

    def __init__(
        self,
        client: httpx.AsyncClient,
        base_url: str,
        api_key: str,
        *,
        timeout: float = 30.0,
        request_interval: float = _REQUEST_INTERVAL_SECONDS,
        retry_delays: tuple[float, ...] = _RATE_LIMIT_RETRY_DELAYS,
    ) -> None:
        self._client = client
        self._base = base_url.rstrip("/")
        self._api_key = api_key
        self._timeout = timeout
        self._request_interval = max(request_interval, 0.0)
        self._retry_delays = retry_delays
        self._request_lock = asyncio.Lock()
        self._last_request_started = 0.0
        self._response_cache: dict[
            tuple[str, tuple[tuple[str, Any], ...]], tuple[float, dict[str, Any]]
        ] = {}
        self._detail_cache: dict[
            tuple[str, str], tuple[float, dict[str, Any]]
        ] = {}
        self._quota_exhausted_until = 0.0

    @property
    def available(self) -> bool:
        return time.time() >= self._quota_exhausted_until

    def _mark_daily_quota_exhausted(self) -> None:
        now = datetime.now(_CHINA_TIMEZONE)
        tomorrow = (now + timedelta(days=1)).date()
        reset = datetime.combine(tomorrow, datetime.min.time(), _CHINA_TIMEZONE)
        self._quota_exhausted_until = reset.timestamp()


    def _resolve_source(self, source: str | None) -> str | None:
        resolved = canonicalize_music_source(source)
        if resolved not in SUPPORTED_SOURCES:
            return None
        return resolved

    async def _get_json(
        self,
        path: str,
        params: dict[str, Any],
        *,
        not_found_is_empty: bool = False,
        cache_ttl: float = 0.0,
    ) -> dict[str, Any]:
        query = {key: value for key, value in params.items() if value is not None}
        query["apikey"] = self._api_key
        cache_key = (path, tuple(sorted(params.items())))
        async with self._request_lock:
            if not self.available:
                raise httpx.HTTPError("chksz daily quota exhausted")
            cached = self._response_cache.get(cache_key)
            now = time.monotonic()
            if cached is not None and cached[0] > now:
                return dict(cached[1])
            for attempt in range(len(self._retry_delays) + 1):
                elapsed = now - self._last_request_started
                if elapsed < self._request_interval:
                    await asyncio.sleep(self._request_interval - elapsed)
                self._last_request_started = time.monotonic()
                response = await self._client.get(
                    f"{self._base}{path}",
                    params=query,
                    headers={
                        "Accept": "application/json",
                        "User-Agent": "Mozilla/5.0",
                    },
                    timeout=self._timeout,
                )
                if response.status_code != 429 or attempt >= len(
                    self._retry_delays
                ):
                    break
                retry_after = response.headers.get("Retry-After")
                try:
                    delay = float(retry_after) if retry_after is not None else None
                except ValueError:
                    delay = None
                await asyncio.sleep(
                    min(
                        max(
                            delay
                            if delay is not None
                            else self._retry_delays[attempt],
                            0.0,
                        ),
                        _MAX_RETRY_AFTER_SECONDS,
                    )
                )
                now = time.monotonic()
            if response.status_code == 404 and not_found_is_empty:
                elapsed = time.monotonic() - self._last_request_started
                if elapsed < _NOT_FOUND_RETRY_DELAY_SECONDS:
                    await asyncio.sleep(_NOT_FOUND_RETRY_DELAY_SECONDS - elapsed)
                self._last_request_started = time.monotonic()
                response = await self._client.get(
                    f"{self._base}{path}",
                    params=query,
                    headers={
                        "Accept": "application/json",
                        "User-Agent": "Mozilla/5.0",
                    },
                    timeout=self._timeout,
                )
                if response.status_code == 404:
                    return {}
            if response.status_code == 402:
                self._mark_daily_quota_exhausted()
            if response.status_code >= 400:
                response.raise_for_status()
            try:
                payload = response.json()
            except ValueError as exc:
                raise httpx.HTTPError("chksz invalid json") from exc
            if not isinstance(payload, dict):
                raise httpx.HTTPError("chksz invalid payload")
            code = payload.get("code")
            if code not in (200, "200", None):
                raise httpx.HTTPError("chksz upstream rejected the request")
            if cache_ttl > 0:
                if len(self._response_cache) >= 256:
                    self._response_cache.pop(next(iter(self._response_cache)))
                self._response_cache[cache_key] = (
                    time.monotonic() + cache_ttl,
                    dict(payload),
                )
            return payload

    def search_window(self, source: str | None) -> SearchWindow:
        resolved = self._resolve_source(source)
        if resolved == "netease":
            return SearchWindow(max_count=CLOUD_SEARCH_COUNT_MAX, paginates=True)
        if resolved == "kugou":
            return SearchWindow(max_count=_KUGOU_PAGE_SIZE_MAX, paginates=False)
        return SearchWindow(max_count=30, paginates=False)

    async def search(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> list[dict[str, Any]]:
        resolved = self._resolve_source(source)
        if resolved is None or page < 1:
            return []
        limit = self.search_window(resolved).request_count(count)
        if resolved == "netease":
            payload = await self._get_json(
                "/api/163_search",
                {
                    "keyword": query,
                    "limit": limit,
                    "offset": (page - 1) * limit,
                },
                not_found_is_empty=True,
                cache_ttl=_SEARCH_CACHE_TTL_SECONDS,
            )
        elif page > 1:
            return []
        elif resolved == "tencent":
            payload = await self._get_json(
                "/api/qq_music",
                {
                    "msg": query,
                    "num": limit,
                    "type": "json",
                },
                not_found_is_empty=True,
                cache_ttl=_SEARCH_CACHE_TTL_SECONDS,
            )
        else:
            payload = await self._get_json(
                "/api/kugou_music",
                {
                    "msg": query,
                    "num": limit,
                    "type": "json",
                },
                not_found_is_empty=True,
                cache_ttl=_SEARCH_CACHE_TTL_SECONDS,
            )
        items = [_prepare_item(item, source=resolved) for item in _search_items(payload)]
        songs = normalize_songs(
            items, provider=self.name, default_source=resolved
        )[:limit]
        if resolved == "tencent":
            await self._attach_tencent_covers(songs)
        else:
            for song in songs:
                cover = song.get("cover_id")
                if not isinstance(cover, str) or not _is_http_url(cover):
                    song["cover_id"] = None
        return songs

    def invalidate_url_cache(self, id: str, *, source: str, br: int) -> None:
        resolved = self._resolve_source(source)
        if resolved is None:
            return
        if resolved == "netease":
            path = "/api/163_music"
            params = {"id": id, "level": _netease_level(br), "type": "json"}
        elif resolved == "tencent":
            path = "/api/qq_music"
            params = {"mid": id, "size": _common_size(br), "type": "json"}
        else:
            path = "/api/kugou_music"
            params = {"id": id, "size": _common_size(br), "type": "json"}
        self._response_cache.pop((path, tuple(sorted(params.items()))), None)
        self._detail_cache.pop((resolved, id), None)

    async def get_url(self, id: str, *, source: str, br: int) -> dict[str, Any]:
        resolved = self._resolve_source(source)
        if resolved is None:
            raise httpx.HTTPError("chksz unsupported source")
        if resolved == "netease":
            payload = await self._get_json(
                "/api/163_music",
                {"id": id, "level": _netease_level(br), "type": "json"},
                cache_ttl=_DETAIL_CACHE_TTL_SECONDS,
            )
        elif resolved == "tencent":
            payload = await self._get_json(
                "/api/qq_music",
                {"mid": id, "size": _common_size(br), "type": "json"},
                cache_ttl=_DETAIL_CACHE_TTL_SECONDS,
            )
        else:
            payload = await self._get_json(
                "/api/kugou_music",
                {"id": id, "size": _common_size(br), "type": "json"},
                cache_ttl=_DETAIL_CACHE_TTL_SECONDS,
            )
        url = _payload_url(payload)
        if not url:
            raise httpx.HTTPError("chksz url empty")
        if len(self._detail_cache) >= 256 and (resolved, id) not in self._detail_cache:
            self._detail_cache.pop(next(iter(self._detail_cache)))
        self._detail_cache[(resolved, id)] = (
            time.monotonic() + _DETAIL_CACHE_TTL_SECONDS,
            dict(payload),
        )
        result: dict[str, Any] = {
            "url": url,
            "br": _payload_bitrate_kbps(payload, br),
            "provider": self.name,
            "source": resolved,
        }
        audio_type = _payload_audio_type(payload, url)
        if audio_type is not None:
            result["type"] = audio_type
        size = _payload_size(payload)
        if size is not None:
            result["size"] = size
        cover = _payload_cover(payload)
        if cover is not None:
            result["cover_url"] = cover
        if resolved != "netease":
            result["lyric"] = extract_lyric_payload(payload)
        return result

    def _remember_cover(self, source: str, id: str, cover: str) -> None:
        if len(self._detail_cache) >= 256 and (source, id) not in self._detail_cache:
            self._detail_cache.pop(next(iter(self._detail_cache)))
        self._detail_cache[(source, id)] = (
            time.monotonic() + _DETAIL_CACHE_TTL_SECONDS,
            {"cover": cover},
        )

    async def _lookup_tencent_cover(self, song_mid: str, size: int) -> str | None:
        if not song_mid.strip():
            return None
        try:
            response = await self._client.get(
                _QQ_SONG_DETAIL_URL,
                params={
                    "songmid": song_mid,
                    "platform": "yqq",
                    "format": "json",
                },
                headers={
                    "Accept": "application/json",
                    "User-Agent": "Mozilla/5.0",
                    "Referer": "https://y.qq.com/",
                },
                timeout=min(self._timeout, 8.0),
            )
            response.raise_for_status()
            payload = response.json()
        except Exception:
            return None
        if not isinstance(payload, dict):
            return None
        album_mid = _tencent_album_mid(payload)
        if album_mid is None:
            return None
        return _qq_album_cover_url(album_mid, size)

    async def _attach_tencent_covers(self, songs: list[dict[str, Any]]) -> None:
        missing = [
            song
            for song in songs
            if not (
                isinstance(song.get("cover_id"), str)
                and _is_http_url(str(song.get("cover_id")))
            )
        ]
        if not missing:
            return

        limit = asyncio.Semaphore(5)

        async def attach(song: dict[str, Any]) -> None:
            song_id = song.get("id")
            if not isinstance(song_id, str) or not song_id:
                song["cover_id"] = None
                return
            cached = self._detail_cache.get(("tencent", song_id))
            if cached is not None and cached[0] > time.monotonic():
                cover = _payload_cover(cached[1])
                if cover is not None:
                    song["cover_id"] = cover
                    return
            async with limit:
                cover = await self._lookup_tencent_cover(song_id, 300)
            if cover is not None:
                self._remember_cover("tencent", song_id, cover)
                song["cover_id"] = cover
                return
            song["cover_id"] = song_id

        await asyncio.gather(*(attach(song) for song in missing))

    async def get_cover(self, id: str, *, source: str, size: int) -> dict[str, Any]:
        resolved = self._resolve_source(source)
        if resolved is None:
            raise httpx.HTTPError("chksz unsupported source")
        if _is_http_url(id):
            return {"url": id, "provider": self.name, "source": resolved}
        cached = self._detail_cache.get((resolved, id))
        if cached is not None and cached[0] > time.monotonic():
            cover = _payload_cover(cached[1])
            if cover is not None:
                return {"url": cover, "provider": self.name, "source": resolved}
        if resolved == "tencent":
            cover = await self._lookup_tencent_cover(id, size)
            if cover is not None:
                self._remember_cover(resolved, id, cover)
                return {"url": cover, "provider": self.name, "source": resolved}
        raise httpx.HTTPError("chksz cover empty")

    async def get_lyric(self, id: str, *, source: str) -> dict[str, Any]:
        resolved = self._resolve_source(source)
        if resolved is None:
            raise httpx.HTTPError("chksz unsupported source")
        cached = self._detail_cache.get((resolved, id))
        if cached is not None and cached[0] > time.monotonic():
            lyric = extract_lyric_payload(cached[1])
            if lyric.strip():
                return {
                    "lyric": lyric,
                    "provider": self.name,
                    "source": resolved,
                }
            # NetEase /api/163_music has play URL/cover but no lyrics.
            # Fall through to /api/163_lyric instead of returning empty.
            if resolved != "netease":
                return {
                    "lyric": lyric,
                    "provider": self.name,
                    "source": resolved,
                }
        if resolved == "netease":
            payload = await self._get_json("/api/163_lyric", {"id": id})
            data = payload.get("data")
            lyric = extract_lyric_payload(data if isinstance(data, dict) else payload)
            return {"lyric": lyric, "provider": self.name, "source": resolved}
        if resolved == "tencent":
            payload = await self._get_json(
                "/api/qq_music",
                {"mid": id, "size": "128k", "type": "json"},
            )
        else:
            payload = await self._get_json(
                "/api/kugou_music",
                {"id": id, "size": "128k", "type": "json"},
            )
        return {
            "lyric": extract_lyric_payload(payload),
            "provider": self.name,
            "source": resolved,
        }

    async def is_playable(self, id: str, *, source: str, br: int = 999) -> bool:
        result = await self.get_url(id, source=source, br=br)
        url = result.get("url")
        if not isinstance(url, str) or not url.strip():
            return False
        async with self._client.stream(
            "GET",
            url,
            headers={"Range": "bytes=0-0", "User-Agent": "Mozilla/5.0"},
            follow_redirects=True,
            timeout=self._timeout,
        ) as response:
            if response.status_code >= 400 and response.status_code != 206:
                response.raise_for_status()
            async for chunk in response.aiter_bytes():
                return bool(chunk)
        return False
