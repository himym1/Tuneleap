from __future__ import annotations

import secrets
from typing import Optional

from fastapi import Header, HTTPException, Query

from app.core.config import get_settings


async def verify_api_key(
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
    api_key: Optional[str] = Query(None, alias="api_key"),
    authorization: Optional[str] = Header(None, alias="Authorization"),
) -> None:
    """Accept shared API key or Bearer access token."""
    settings = get_settings()
    key = x_api_key or api_key
    if key and secrets.compare_digest(key, settings.api_key):
        return

    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
        if token:
            from app.services.auth_service import AuthService

            try:
                AuthService(settings).verify_access_token(token)
                return
            except Exception:  # noqa: BLE001
                pass

    raise HTTPException(status_code=401, detail="Invalid API Key")
