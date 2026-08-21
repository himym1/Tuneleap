"""HTTP client for the private NAS library agent."""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from typing import Any

import httpx

from app.core.config import Settings

_logger = logging.getLogger(__name__)


class NasAgentError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


class NasLibraryClient:
    def __init__(
        self,
        client: httpx.AsyncClient,
        settings: Settings,
        *,
        identity_cache_ttl_seconds: float = 300,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._client = client
        self._base_url = settings.nas_agent_url.strip().rstrip("/")
        self._api_key = settings.nas_agent_key.strip()
        self._timeout = settings.http_timeout_seconds
        self._identity_cache_ttl_seconds = identity_cache_ttl_seconds
        self._clock = clock
        self._cached_weak_identities: set[str] | None = None
        self._identity_cached_at = 0.0

    @property
    def enabled(self) -> bool:
        return bool(self._base_url and self._api_key)


    async def recommendation_weak_identities(self) -> set[str]:
        if not self.enabled:
            return set()
        try:
            payload = await self._request_json(
                "GET",
                "/v1/songs/library-identities",
                params={"include_strong": "false", "limit": 100000},
            )
            identities = payload.get("identities", [])
            if not isinstance(identities, list):
                raise TypeError("NAS agent identities response is invalid")
            weak = {
                item["weak"] if isinstance(item, dict) else item
                for item in identities
                if (isinstance(item, str) and item)
                or (
                    isinstance(item, dict)
                    and isinstance(item.get("weak"), str)
                    and item["weak"]
                )
            }
            self._cached_weak_identities = weak
            self._identity_cached_at = self._clock()
            return set(weak)
        except httpx.TransportError:
            if self._cached_weak_identities is not None and (
                self._clock() - self._identity_cached_at
                <= self._identity_cache_ttl_seconds
            ):
                _logger.warning("NAS identities unavailable; using recent cache")
                return set(self._cached_weak_identities)
            raise

    async def import_song(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._request_json(
            "POST",
            "/v1/nas/import",
            json=payload,
            timeout=max(self._timeout, 120.0),
        )

    async def delete_songs(self, song_ids: list[str]) -> dict[str, Any]:
        return await self._request_json(
            "POST",
            "/v1/songs/delete",
            json={"song_ids": song_ids},
        )

    async def _request_json(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json: dict[str, Any] | None = None,
        timeout: float | None = None,
    ) -> dict[str, Any]:
        if not self.enabled:
            raise RuntimeError("NAS agent client is not configured")

        for attempt in range(2):
            try:
                response = await self._client.request(
                    method,
                    f"{self._base_url}{path}",
                    params=params,
                    json=json,
                    headers={"X-API-Key": self._api_key},
                    timeout=timeout or self._timeout,
                )
                if response.status_code >= 400:
                    raise NasAgentError(
                        response.status_code,
                        _nas_error_detail(response),
                    )
                data = response.json()
                if not isinstance(data, dict):
                    raise TypeError("NAS agent response must be a JSON object")
                return data
            except httpx.TransportError:
                if attempt == 0:
                    _logger.warning("NAS agent transport failed; retrying once")
                    continue
                raise

        raise RuntimeError("unreachable")


def _nas_error_detail(response: httpx.Response) -> str:
    try:
        data = response.json()
    except ValueError:
        data = None
    if isinstance(data, dict):
        detail = data.get("detail") or data.get("error") or data.get("msg")
        if isinstance(detail, str) and detail.strip():
            return detail.strip()
    text = response.text.strip()
    return text or f"NAS agent error {response.status_code}"
