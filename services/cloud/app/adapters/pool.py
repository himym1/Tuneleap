"""Shared multi-base upstream pool with cooldown failover."""

from __future__ import annotations

import secrets
import time
from collections.abc import Callable
from typing import Any

import httpx


class BasePool:
    def __init__(
        self,
        client: httpx.AsyncClient,
        bases: tuple[str, ...],
        *,
        cooldown_seconds: int = 60,
        timeout: float = 30.0,
        headers: dict[str, str] | None = None,
    ) -> None:
        if not bases:
            raise ValueError("at least one base URL is required")
        self._client = client
        self._bases = bases
        self._cooldown_seconds = max(0, cooldown_seconds)
        self._timeout = timeout
        self._headers = headers or {
            "User-Agent": "Mozilla/5.0",
            "Referer": "https://music.gdstudio.xyz/",
        }
        self._cooldown_until: dict[str, float] = {}

    @property
    def bases(self) -> tuple[str, ...]:
        return self._bases

    def _available_bases(self) -> list[str]:
        now = time.monotonic()
        available = [
            base for base in self._bases if self._cooldown_until.get(base, 0.0) <= now
        ]
        if available:
            return available
        return [min(self._bases, key=lambda base: self._cooldown_until[base])]

    def mark_failure(self, base: str) -> None:
        if self._cooldown_seconds <= 0:
            return
        self._cooldown_until[base] = time.monotonic() + self._cooldown_seconds

    def mark_success(self, base: str) -> None:
        self._cooldown_until.pop(base, None)

    @staticmethod
    def _should_cooldown(error: Exception) -> bool:
        if isinstance(error, httpx.HTTPStatusError):
            status = error.response.status_code
            return status == 429 or status >= 500
        return True

    async def request(
        self,
        *,
        params: dict[str, Any],
        attach_nonce: bool = True,
        path_builder: Callable[[str], str] | None = None,
        follow_redirects: bool = False,
        allowed_redirect_statuses: frozenset[int] = frozenset(),
    ) -> httpx.Response:
        last_error: Exception | None = None
        for base in self._available_bases():
            request_params = dict(params)
            if attach_nonce:
                request_params["s"] = secrets.token_hex(8)
            url = path_builder(base) if path_builder else base
            try:
                response = await self._client.get(
                    url,
                    params=request_params,
                    headers=self._headers,
                    timeout=self._timeout,
                    follow_redirects=follow_redirects,
                )
                if (
                    300 <= response.status_code < 400
                    and response.status_code not in allowed_redirect_statuses
                ) or response.status_code >= 400:
                    response.raise_for_status()
            except httpx.HTTPError as exc:
                last_error = exc
                if self._should_cooldown(exc):
                    self.mark_failure(base)
                else:
                    self.mark_success(base)
                continue
            self.mark_success(base)
            return response
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("all upstream bases failed")

    async def request_json(
        self,
        *,
        params: dict[str, Any],
        attach_nonce: bool = True,
        path_builder: Callable[[str], str] | None = None,
    ) -> Any:
        last_error: Exception | None = None
        for base in self._available_bases():
            request_params = dict(params)
            if attach_nonce:
                request_params["s"] = secrets.token_hex(8)
            url = path_builder(base) if path_builder else base
            try:
                response = await self._client.get(
                    url,
                    params=request_params,
                    headers=self._headers,
                    timeout=self._timeout,
                )
                response.raise_for_status()
                payload = response.json()
            except (httpx.HTTPError, ValueError, TypeError) as exc:
                last_error = exc
                if self._should_cooldown(exc):
                    self.mark_failure(base)
                else:
                    self.mark_success(base)
                continue
            self.mark_success(base)
            return payload
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("all upstream bases failed")
