from __future__ import annotations

import secrets

from fastapi import Header, HTTPException, Query

from app.core.config import get_settings
from app.services.auth_service import AuthError, verify_access_token


async def verify_api_key(
    x_api_key: str | None = Header(None, alias="X-API-Key"),
    api_key: str | None = Query(None, alias="api_key"),
    authorization: str | None = Header(None, alias="Authorization"),
) -> None:
    """Accept shared API key or Bearer access token."""
    settings = get_settings()
    key = x_api_key or api_key
    if key and secrets.compare_digest(key, settings.api_key):
        return

    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
        if token:
            try:
                verify_access_token(token, settings)
                return
            except AuthError:
                pass

    raise HTTPException(status_code=401, detail="Invalid API Key")
