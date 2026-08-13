import secrets
from typing import Annotated

from fastapi import Header, HTTPException, Request


async def verify_agent_key(
    request: Request,
    x_api_key: Annotated[str | None, Header(alias="X-API-Key")] = None,
) -> None:
    """Authenticate agent operations with the dedicated header key."""
    expected = request.app.state.settings.nas_agent_key
    if not x_api_key or not secrets.compare_digest(x_api_key, expected):
        raise HTTPException(status_code=401, detail="Invalid NAS agent key")
