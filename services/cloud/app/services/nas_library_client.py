"""Read-only client for NAS agent library identities (recommendation blocking)."""

from __future__ import annotations

from typing import Any

import httpx

from app.core.config import Settings


class NasLibraryClient:
    """Fetches weak identities from navidrome-nas-agent without mounting navidrome.db."""

    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self._client = client
        self._settings = settings

    @property
    def enabled(self) -> bool:
        return bool(self._settings.nas_agent_url and self._settings.nas_agent_key)

    async def recommendation_weak_identities(self) -> set[str]:
        if not self.enabled:
            return set()
        base = self._settings.nas_agent_url.rstrip("/")
        response = await self._client.get(
            f"{base}/v1/songs/library-identities",
            headers={"X-API-Key": self._settings.nas_agent_key},
            timeout=self._settings.http_timeout_seconds,
        )
        response.raise_for_status()
        payload: Any = response.json()
        if not isinstance(payload, dict):
            return set()
        raw = payload.get("identities")
        if not isinstance(raw, list):
            return set()
        return {str(item) for item in raw if isinstance(item, str) and item}
