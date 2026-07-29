"""Auth routes — product accounts (not Navidrome Subsonic credentials)."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.core.limiter import limiter
from app.services.auth_service import AuthError, AuthService

router = APIRouter(prefix="/v1/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    email: str | None = None
    username: str = Field(min_length=2, max_length=64)
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    username: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int | None = None


def _service() -> AuthService:
    return AuthService(get_settings())


def _map_auth(exc: AuthError) -> HTTPException:
    return HTTPException(status_code=exc.status_code, detail=exc.detail)


@router.post("/register", response_model=TokenResponse)
@limiter.limit("20/minute")
async def register(request: Request, body: RegisterRequest):
    try:
        return _service().register(
            username=body.username, password=body.password, email=body.email
        )
    except AuthError as exc:
        raise _map_auth(exc) from exc


@router.post("/login", response_model=TokenResponse)
@limiter.limit("20/minute")
async def login(request: Request, body: LoginRequest):
    try:
        return _service().login(username=body.username, password=body.password)
    except AuthError as exc:
        raise _map_auth(exc) from exc


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("20/minute")
async def refresh(request: Request, body: RefreshRequest):
    try:
        return _service().refresh(body.refresh_token)
    except AuthError as exc:
        raise _map_auth(exc) from exc
