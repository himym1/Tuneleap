"""Deterministic recommendation orchestration between sources and store."""
from __future__ import annotations

import asyncio
import hashlib
import math
import secrets
import sys
from collections.abc import AsyncIterator, Mapping, Sequence
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Protocol, TypeAlias

import httpx
from typing_extensions import TypedDict

from app.models.recommendations import (
    RecommendationFeedbackEvent,
    RecommendationItem,
    RecommendationPageV1,
    RecommendationSong,
)
from app.services.recommendation_identity import (
    canonical_title,
    normalize_text,
    primary_artist,
    weak_identity,
)
from app.services.recommendation_store import FeedbackResult, Session, StaleSessionError


class SearchResult(TypedDict, total=False):
    id: str | int
    url_id: str | int
    urlId: str | int
    title: str
    name: str
    artist: str
    singer: str
    album: str
    album_id: str | int
    albumId: str | int
    artist_id: str | int
    artistId: str | int
    track: int
    year: int
    duration: int
    bit_rate: int
    cover_art: str
    suffix: str
    path: str
    comment: str
    lyric_id: str


SearchResults: TypeAlias = Sequence[Mapping[str, object]]


def _weak_identity(song_or_title: object, artist: object | None = None) -> str:
    return weak_identity(song_or_title, artist)


def _mix_candidates(
    similar: Sequence[object], explore: Sequence[object], limit: int = 20
) -> list[object]:
    if limit <= 0:
        return []
    similar_quota = min(limit, (limit * 7 + 5) // 10)
    explore_quota = min(limit - similar_quota, (limit * 3 + 5) // 10)
    selected: list[object] = []
    seen_identities: set[str] = set()
    artist_counts: dict[str, int] = {}

    def add(bucket: Sequence[object], quota: int) -> int:
        added = 0
        for item in bucket:
            song = getattr(item, "song", item)
            identity = _weak_identity(song)
            artist = (
                song.get("artist", "")
                if isinstance(song, Mapping)
                else getattr(song, "artist", "")
            )
            artist_key = primary_artist(artist)
            if identity in seen_identities or artist_counts.get(artist_key, 0) >= 2:
                continue
            selected.append(item)
            seen_identities.add(identity)
            artist_counts[artist_key] = artist_counts.get(artist_key, 0) + 1
            added += 1
            if added >= quota or len(selected) >= limit:
                break
        return added

    add(similar, similar_quota)
    add(explore, explore_quota)
    if len(selected) < limit:
        add(similar, limit - len(selected))
        add(explore, limit - len(selected))
    return selected[:limit]




class RecommendationSource(Protocol):
    async def search(
        self, source: str, query: str, *, count: int, pages: int
    ) -> SearchResults: ...

    async def get_url(self, id: str, source: str, br: int = 999) -> object: ...
    async def is_playable(self, id: str, source: str, br: int = 999) -> bool: ...


class RecommendationLibrary(Protocol):
    async def recommendation_weak_identities(self) -> set[str]: ...


class RecommendationStorePort(Protocol):
    async def current_generation(self) -> int: ...
    async def get_active_session(self) -> Session | None: ...
    async def create_session(
        self, session_id: str | None = None, *, refresh: bool = False
    ) -> Session: ...
    async def set_session_mode(self, session_id: str, mode: str) -> None: ...
    async def set_session_recent(
        self, session_id: str, recent: Sequence[Mapping[str, object]]
    ) -> None: ...
    async def get_session_recent(
        self, session_id: str
    ) -> list[dict[str, object]]: ...
    async def get_page(
        self, session_id: str, *, limit: int = 20, cursor: str | None = None
    ) -> RecommendationPageV1: ...
    async def claim_refill_lease(
        self, session_id: str, owner: str, lease_ms: int
    ) -> bool: ...
    async def renew_refill_lease(
        self, session_id: str, owner: str, lease_ms: int
    ) -> None: ...
    async def release_refill_lease(self, session_id: str, owner: str) -> None: ...
    async def append_candidates(
        self, session_id: str, owner: str, candidates: list[RecommendationItem]
    ) -> None: ...
    async def get_profile_summary(self) -> dict[str, object]: ...
    async def get_exclusions(self) -> set[str]: ...
    async def insert_feedback(
        self,
        session_id: str,
        candidate_id: str,
        event: RecommendationFeedbackEvent | str,
        idempotency_key: str,
    ) -> FeedbackResult: ...
    async def candidate_count(
        self, session_id: str, cursor: str | None = None
    ) -> int: ...
    async def candidate_identities(self, session_id: str) -> set[str]: ...
    async def block_candidate_identities(
        self, session_id: str, weak_identities: set[str]
    ) -> None: ...
    async def reset(self) -> int: ...


@dataclass(frozen=True)
class _SearchQuery:
    recommendation_type: str
    text: str
    title: str = ""
    artist: str = ""

    @property
    def is_exact(self) -> bool:
        return bool(self.title and self.artist)


@dataclass
class _RefillContext:
    queries: tuple[_SearchQuery, ...]
    next_page: int


def _as_mapping(item: object) -> dict[str, object]:
    if isinstance(item, Mapping):
        return {str(key): value for key, value in item.items()}
    if hasattr(item, "model_dump"):
        dumped = item.model_dump(by_alias=True)  # type: ignore[misc]
        if isinstance(dumped, Mapping):
            return {str(key): value for key, value in dumped.items()}
    data: dict[str, object] = {}
    for key in (
        "title",
        "artist",
        "album",
        "source",
        "sourceId",
        "source_id",
        "onlineSource",
        "online_source",
        "urlId",
        "url_id",
    ):
        if hasattr(item, key):
            data[key] = getattr(item, key)
    if "source_id" in data and "sourceId" not in data:
        data["sourceId"] = data["source_id"]
    if "online_source" in data and "onlineSource" not in data:
        data["onlineSource"] = data["online_source"]
    if "url_id" in data and "urlId" not in data:
        data["urlId"] = data["url_id"]
    return data


def _normalize_recent(recent: Sequence[object]) -> list[dict[str, object]]:
    return [_as_mapping(item) for item in recent]


def _recent_field(item: object, *keys: str, default: object = "") -> object:
    data = _as_mapping(item)
    for key in keys:
        if key in data and data[key] not in (None, ""):
            return data[key]
    return default


class RecommendationService:
    def __init__(
        self,
        *,
        store: RecommendationStorePort,
        music_proxy: RecommendationSource,
        library: RecommendationLibrary | None = None,
        sources: Sequence[str] = ("netease", "migu", "joox"),
        discovery_seeds: Sequence[str] = ("流行新歌", "热门歌曲", "经典歌曲"),
        upstream_concurrency: int = 5,
        pool_target: int = 60,
        low_watermark: int = 20,
        page_max: int = 20,
        refill_lease_ms: int = 10000,
    ) -> None:
        if refill_lease_ms <= 0:
            raise ValueError("refill_lease_ms must be positive")
        if not 1 <= page_max <= 20:
            raise ValueError("page_max must be between 1 and 20")
        self.store = store
        self.music_proxy = music_proxy
        self.library = library
        self.sources = tuple(sources)
        self.discovery_seeds = tuple(discovery_seeds)
        self.pool_target = pool_target
        self.low_watermark = low_watermark
        self.page_max = page_max
        self.refill_lease_ms = refill_lease_ms
        self._search_semaphore = asyncio.Semaphore(upstream_concurrency)
        self._background_tasks: dict[str, asyncio.Task[object]] = {}
        self._suppressed_tasks: set[asyncio.Task[object]] = set()
        self._refill_context: dict[str, _RefillContext] = {}
        self.background_errors: list[BaseException] = []

    async def _block_library_candidates(self, session_id: str) -> None:
        if self.library is None:
            return
        identities = await self.library.recommendation_weak_identities()
        await self.store.block_candidate_identities(session_id, identities)

    async def create_or_resume(
        self,
        recent: Sequence[object] = (),
        page_size: int = 20,
        refresh: bool = False,
    ) -> RecommendationPageV1:
        normalized_recent = _normalize_recent(recent)
        if not 1 <= page_size <= self.page_max:
            raise ValueError("page_size exceeds page_max")
        session = await self.store.get_active_session()
        if refresh:
            old_session_id = session.session_id if session is not None else None
            if old_session_id is not None:
                await self._clear_session_state(old_session_id)
            session = (
                await self.store.create_session(old_session_id, refresh=True)
                if old_session_id is not None
                else await self.store.create_session(refresh=False)
            )
        elif session is None:
            session = await self.store.create_session(refresh=False)
        await self.store.set_session_recent(session.session_id, normalized_recent)
        # Block library songs before filling so first-page search excludes them.
        await self._block_library_candidates(session.session_id)
        await self._ensure_first_page(session, normalized_recent, page_size)
        page = await self.store.get_page(session.session_id, limit=page_size)
        await self._schedule_needed_background(session, normalized_recent)
        return page

    async def create_session(
        self,
        *,
        session_id: str | None = None,
        refresh: bool = False,
        recent: Sequence[object] = (),
        page_size: int = 20,
    ) -> RecommendationPageV1:
        normalized_recent = _normalize_recent(recent)
        if not 1 <= page_size <= self.page_max:
            raise ValueError("page_size exceeds page_max")
        session = await self.store.create_session(session_id, refresh=refresh)
        await self.store.set_session_recent(session.session_id, normalized_recent)
        await self._block_library_candidates(session.session_id)
        await self._ensure_first_page(session, normalized_recent, page_size)
        page = await self.store.get_page(session.session_id, limit=page_size)
        await self._schedule_needed_background(session, normalized_recent)
        return page

    async def _ensure_first_page(
        self,
        session: Session,
        recent: Sequence[Mapping[str, object]],
        page_size: int,
    ) -> None:
        if await self.store.candidate_count(session.session_id) < page_size:
            await self._fill_to_target(session, recent, page_size)

    async def _schedule_needed_background(
        self,
        session: Session,
        recent: Sequence[Mapping[str, object]],
    ) -> None:
        if self.pool_target > await self.store.candidate_count(session.session_id):
            self._schedule_refill(session, recent, self.pool_target)

    async def get_page(
        self, session_id: str, *, limit: int = 20, cursor: str | None = None
    ) -> RecommendationPageV1:
        if not 1 <= limit <= self.page_max:
            raise ValueError("limit exceeds page_max")
        await self._block_library_candidates(session_id)
        page = await self.store.get_page(session_id, limit=limit, cursor=cursor)
        session = await self.store.get_active_session()
        if session is None or session.session_id != session_id:
            return page
        recent = await self.store.get_session_recent(session_id)
        if cursor is not None and not page.items and page.next_cursor is None:
            total = await self.store.candidate_count(session_id)
            await self._fill_to_target(session, recent, total + limit)
            page = await self.store.get_page(session_id, limit=limit, cursor=cursor)
        if page.next_cursor is not None:
            remaining = await self.store.candidate_count(session_id, page.next_cursor)
            if remaining <= self.low_watermark:
                total = await self.store.candidate_count(session_id)
                target = total + max(0, self.pool_target - remaining)
                self._schedule_refill(session, recent, target)
        return page

    def _track_task(self, key: str, coroutine: object) -> None:
        current = self._background_tasks.get(key)
        if current is not None and not current.done():
            if hasattr(coroutine, "close"):
                coroutine.close()  # type: ignore[attr-defined]
            return
        task = asyncio.create_task(coroutine)  # type: ignore[arg-type]
        self._background_tasks[key] = task

        def remove_done(done: asyncio.Task[object]) -> None:
            if not done.cancelled():
                error = done.exception()
                if error is not None and done not in self._suppressed_tasks:
                    self.background_errors.append(error)
            self._suppressed_tasks.discard(done)
            if self._background_tasks.get(key) is done:
                self._background_tasks.pop(key, None)

        task.add_done_callback(remove_done)

    def _schedule_refill(
        self,
        session: Session,
        recent: Sequence[Mapping[str, object]],
        target: int,
    ) -> None:
        self._track_task(
            f"work:{session.generation}:{session.session_id}",
            self._fill_to_target(session, recent, target),
        )

    @asynccontextmanager
    async def _refill_lease(self, session: Session) -> AsyncIterator[str | None]:
        owner = secrets.token_urlsafe(12)
        if not await self.store.claim_refill_lease(
            session.session_id, owner, self.refill_lease_ms
        ):
            yield None
            return

        async def heartbeat() -> None:
            while True:
                await asyncio.sleep(max(0.01, self.refill_lease_ms / 3000))
                await self.store.renew_refill_lease(
                    session.session_id, owner, self.refill_lease_ms
                )

        heartbeat_task = asyncio.create_task(heartbeat())
        primary_error = False
        cleanup_error: BaseException | None = None
        try:
            yield owner
        except BaseException:
            primary_error = True
            raise
        finally:
            if not heartbeat_task.done():
                heartbeat_task.cancel()
            try:
                await heartbeat_task
            except asyncio.CancelledError:
                pass
            except BaseException as exc:
                cleanup_error = exc
            try:
                await self.store.release_refill_lease(session.session_id, owner)
            except BaseException as exc:
                if cleanup_error is None:
                    cleanup_error = exc
            if not primary_error and cleanup_error is not None:
                raise cleanup_error

    async def shutdown(self, timeout: float = 5) -> None:
        if timeout < 0:
            raise ValueError("timeout must be non-negative")
        tasks = tuple(self._background_tasks.values())
        if tasks:
            _, pending = await asyncio.wait(tasks, timeout=timeout)
            for task in pending:
                task.cancel()
            # Cancellation is best-effort. A task that suppresses CancelledError
            # must not extend application shutdown beyond the configured bound.
            await asyncio.sleep(0)
        errors = list(self.background_errors)
        self.background_errors.clear()
        self._background_tasks.clear()
        self._refill_context.clear()
        if errors:
            raise errors[0]

    async def drain_background(self) -> None:
        while self._background_tasks:
            tasks = tuple(self._background_tasks.values())
            await asyncio.gather(*tasks, return_exceptions=True)
            await asyncio.sleep(0)
        if self.background_errors:
            error = self.background_errors.pop(0)
            self.background_errors.clear()
            raise error

    async def _clear_session_state(self, session_id: str) -> None:
        for key, task in tuple(self._background_tasks.items()):
            if session_id in key and not task.done():
                self._suppressed_tasks.add(task)
                task.cancel()
                await asyncio.gather(task, return_exceptions=True)
                self._background_tasks.pop(key, None)
        self._refill_context.pop(session_id, None)

    async def feedback(
        self,
        session_id: str,
        candidate_id: str,
        event: RecommendationFeedbackEvent | str,
        idempotency_key: str,
    ) -> FeedbackResult:
        return await self.store.insert_feedback(
            session_id, candidate_id, event, idempotency_key
        )

    async def reset(self) -> int:
        for task in tuple(self._background_tasks.values()):
            if not task.done():
                self._suppressed_tasks.add(task)
                task.cancel()
        if self._background_tasks:
            await asyncio.gather(
                *tuple(self._background_tasks.values()), return_exceptions=True
            )
        self._background_tasks.clear()
        self._refill_context.clear()
        self.background_errors.clear()
        return await self.store.reset()

    async def _search_page(
        self, queries: Sequence[_SearchQuery], page_no: int, count: int
    ) -> tuple[list[RecommendationItem], bool]:
        async def search_one(
            query_index: int, query: _SearchQuery, source: str
        ) -> tuple[int, list[RecommendationItem], bool]:
            try:
                async with self._search_semaphore:
                    results = await self.music_proxy.search(
                        source, query.text, count=count, pages=page_no
                    )
            except asyncio.CancelledError:
                raise
            except (httpx.HTTPError, ValueError, TypeError):
                return query_index, [], False
            if not isinstance(results, list):
                return query_index, [], False
            items: list[RecommendationItem] = []
            for result in results:
                if not isinstance(result, Mapping):
                    continue
                item = self._item(result, source, query.recommendation_type)
                if item is not None:
                    items.append(item)
            return query_index, items, len(results) >= count

        tasks = [
            search_one(
                query_index,
                query,
                self.sources[(query_index + source_index) % len(self.sources)],
            )
            for query_index, query in enumerate(queries)
            for source_index in range(len(self.sources))
        ]
        if not tasks:
            return [], False
        grouped: list[list[RecommendationItem]] = [[] for _ in queries]
        may_have_more = False
        for query_index, items, full_page in await asyncio.gather(*tasks):
            grouped[query_index].extend(items)
            may_have_more = may_have_more or full_page

        for query_index, query in enumerate(queries):
            matched: list[tuple[tuple[int, int], RecommendationItem]] = []
            for item in grouped[query_index]:
                actual_artist = normalize_text(item.song.artist)
                expected_artist = normalize_text(query.artist)
                if expected_artist and actual_artist == expected_artist:
                    artist_penalty = 0
                elif expected_artist and expected_artist in {
                    normalize_text(part) for part in item.song.artist.split(" / ")
                }:
                    artist_penalty = 1
                elif expected_artist:
                    continue
                else:
                    artist_penalty = 0
                if query.is_exact and (
                    canonical_title(item.song.title) != canonical_title(query.title)
                ):
                    continue
                title_penalty = int(
                    normalize_text(item.song.title) != normalize_text(query.title)
                )
                matched.append(((artist_penalty, title_penalty), item))
            if query.is_exact:
                grouped[query_index] = (
                    [min(matched, key=lambda pair: pair[0])[1]] if matched else []
                )
            elif query.artist:
                grouped[query_index] = [item for _, item in matched]

        balanced: list[RecommendationItem] = []
        for offset in range(max((len(items) for items in grouped), default=0)):
            balanced.extend(items[offset] for items in grouped if offset < len(items))
        return balanced, may_have_more

    async def _is_playable(self, item: RecommendationItem) -> bool:
        try:
            async with self._search_semaphore:
                return await self.music_proxy.is_playable(
                    item.song.url_id, item.song.online_source
                )
        except asyncio.CancelledError:
            raise
        except (httpx.HTTPError, ValueError, TypeError):
            return False

    async def _rule_queries(
        self, recent: Sequence[Mapping[str, object]]
    ) -> list[_SearchQuery]:
        similar: list[_SearchQuery] = []
        for item in recent:
            title = str(_recent_field(item, "title")).strip()
            artist = str(_recent_field(item, "artist")).strip()
            value = artist or title
            if value:
                similar.append(_SearchQuery("similar", value, "", artist))
        profile = await self.store.get_profile_summary()
        seeds = profile.get("positiveSeeds", []) if isinstance(profile, Mapping) else []
        if isinstance(seeds, Sequence) and not isinstance(seeds, (str, bytes)):
            for seed in seeds:
                if isinstance(seed, Mapping):
                    title = str(seed.get("title", "")).strip()
                    artist = str(seed.get("artist", "")).strip()
                    value = artist or title
                    query = _SearchQuery("similar", value, "", artist)
                else:
                    value = str(seed).strip()
                    query = _SearchQuery("similar", value)
                if value:
                    similar.append(query)
        similar = list(dict.fromkeys(similar))
        explore = [
            _SearchQuery("explore", seed)
            for seed in self.discovery_seeds
            if seed.strip()
        ]
        return similar + explore

    @staticmethod
    def _order_queries_for_session(
        queries: Sequence[_SearchQuery], session_id: str
    ) -> list[_SearchQuery]:
        """Vary seed priority per session while preserving recommendation buckets."""
        digest = hashlib.sha256(session_id.encode()).digest()

        def rotate(bucket: list[_SearchQuery], start: int) -> list[_SearchQuery]:
            if len(bucket) < 2:
                return bucket
            offset = int.from_bytes(digest[start : start + 4], "big") % len(bucket)
            return bucket[offset:] + bucket[:offset]

        similar = [query for query in queries if query.recommendation_type == "similar"]
        explore = [query for query in queries if query.recommendation_type == "explore"]
        return rotate(similar, 0) + rotate(explore, 4)

    async def _fill_to_target(
        self,
        session: Session,
        recent: Sequence[Mapping[str, object]],
        target: int,
    ) -> str:
        if await self.store.candidate_count(session.session_id) >= target:
            return "fallback"
        queries = self._order_queries_for_session(
            await self._rule_queries(recent), session.session_id
        )
        await self.store.set_session_mode(session.session_id, "fallback")
        async with self._refill_lease(session) as owner:
            if owner is None:
                return "fallback"
            await self._fill_with_owner(
                session, recent, target, owner=owner, queries=queries
            )
        return "fallback"

    async def _fill_with_owner(
        self,
        session: Session,
        recent: Sequence[Mapping[str, object]],
        target: int,
        *,
        owner: str,
        queries: Sequence[_SearchQuery],
    ) -> None:
        query_tuple = tuple(queries)
        if not query_tuple:
            return
        context = self._refill_context.get(session.session_id)
        if context is None or context.queries != query_tuple:
            current = await self.store.candidate_count(session.session_id)
            context = _RefillContext(
                query_tuple, max(1, math.ceil(current / self.page_max) + 1)
            )
            self._refill_context[session.session_id] = context
        existing = await self.store.candidate_identities(session.session_id)
        library_identities = (
            await self.library.recommendation_weak_identities()
            if self.library is not None
            else set()
        )
        recent_strong = {
            f"{_recent_field(item, 'source', 'onlineSource')}:{_recent_field(item, 'sourceId', 'source_id', 'urlId', 'url_id')}"
            for item in recent
            if _recent_field(item, "source", "onlineSource")
            and _recent_field(item, "sourceId", "source_id", "urlId", "url_id")
        }
        recent_weak = {
            _weak_identity(
                _recent_field(item, "title"), _recent_field(item, "artist")
            )
            for item in recent
            if _recent_field(item, "title") or _recent_field(item, "artist")
        }
        seen = (
            set(await self.store.get_exclusions())
            | existing
            | recent_strong
            | recent_weak
            | library_identities
        )
        remaining = max(0, target - await self.store.candidate_count(session.session_id))
        page_budget = max(2, math.ceil(remaining / 20) + 1)
        last_page = context.next_page + page_budget
        while context.next_page < last_page:
            current = await self.store.candidate_count(session.session_id)
            if current >= target:
                break
            page_no = context.next_page
            batch_limit = min(20, target - current)
            searched, may_have_more = await self._search_page(
                query_tuple, page_no, batch_limit
            )
            context.next_page = page_no + 1
            if not searched:
                if may_have_more:
                    continue
                self._refill_context.pop(session.session_id, None)
                break
            eligible: list[RecommendationItem] = []
            for item in searched:
                identity = f"{item.song.online_source}:{item.song.url_id}"
                weak = _weak_identity(item.song)
                if identity not in seen and weak not in seen:
                    eligible.append(item)
            similar = [
                item for item in eligible if item.recommendation_type == "similar"
            ]
            explore = [
                item for item in eligible if item.recommendation_type == "explore"
            ]
            mixed = _mix_candidates(similar, explore, limit=batch_limit)
            provisional: list[RecommendationItem] = []
            batch_seen: set[str] = set()
            for item in mixed:
                identity = f"{item.song.online_source}:{item.song.url_id}"
                weak = _weak_identity(item.song)
                if identity in batch_seen or weak in batch_seen:
                    continue
                batch_seen.update((identity, weak))
                provisional.append(item)
            seen.update(batch_seen)
            if not provisional:
                if may_have_more:
                    continue
                self._refill_context.pop(session.session_id, None)
                break
            playable = await asyncio.gather(
                *(self._is_playable(item) for item in provisional)
            )
            found: list[RecommendationItem] = []
            for item, is_playable in zip(provisional, playable, strict=True):
                if not is_playable:
                    continue
                seen.update(
                    (
                        f"{item.song.online_source}:{item.song.url_id}",
                        _weak_identity(item.song),
                    )
                )
                found.append(item)
            if found:
                await self.store.append_candidates(session.session_id, owner, found)
            if len(found) < batch_limit and not may_have_more:
                break
        if target >= self.pool_target and (
            await self.store.candidate_count(session.session_id) >= target
        ):
            self._refill_context.pop(session.session_id, None)

    @staticmethod
    def _item(
        value: Mapping[str, object], source: str, recommendation_type: str
    ) -> RecommendationItem | None:
        def text(*keys: str) -> str:
            for key in keys:
                raw = value.get(key)
                if raw is None:
                    continue
                if isinstance(raw, list):
                    raw = " / ".join(
                        str(part).strip() for part in raw if str(part).strip()
                    )
                result = str(raw).strip()
                if result:
                    return result
            return ""

        title = text("name", "title")
        artist = text("artist", "singer")
        url_id = text("url_id", "urlId", "id")
        if not title or not artist or not url_id:
            return None
        song_data: dict[str, object] = {
            "id": text("id", "url_id", "urlId"),
            "title": title,
            "album": text("album"),
            "album_id": text("album_id", "albumId"),
            "artist": artist,
            "artist_id": text("artist_id", "artistId"),
            "track": value.get("track"),
            "year": value.get("year"),
            "duration": value.get("duration"),
            "bit_rate": value.get("bit_rate"),
            "cover_art": value.get("cover_art", value.get("pic_id")),
            "suffix": value.get("suffix"),
            "path": value.get("path"),
            "comment": value.get("comment"),
            "backend": "solara",
            "online_source": source,
            "url_id": url_id,
            "lyric_id": value.get("lyric_id"),
        }
        try:
            song = RecommendationSong.model_validate(song_data)
        except Exception:
            return None
        return RecommendationItem(
            candidate_id=hashlib.sha256(f"{source}\x00{url_id}".encode()).hexdigest(),
            recommendation_type=recommendation_type,
            song=song,
        )
