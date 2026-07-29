"""Postgres-backed product authentication and JWT token rotation."""

from __future__ import annotations

import hashlib
import secrets
import time
from typing import Any

import jwt
from passlib.context import CryptContext
from psycopg.errors import UniqueViolation
from psycopg_pool import AsyncConnectionPool

from app.core.config import Settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthError(Exception):
    def __init__(self, detail: str, status_code: int = 400):
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


def verify_access_token(token: str, settings: Settings) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        raise AuthError("invalid access token", status_code=401) from exc
    if payload.get("type") != "access":
        raise AuthError("invalid access token", status_code=401)
    return payload


class AuthService:
    def __init__(self, pool: AsyncConnectionPool, settings: Settings):
        self.pool = pool
        self.settings = settings

    async def register(
        self, *, username: str, password: str, email: str | None = None
    ) -> dict[str, Any]:
        username = username.strip()
        if len(username) < 2:
            raise AuthError("username too short")
        if len(password) < 8:
            raise AuthError("password too short")
        password_hash = pwd_context.hash(password)
        try:
            async with self.pool.connection() as connection:
                async with connection.transaction():
                    row = await (
                        await connection.execute(
                            """
                            INSERT INTO users(
                                username, email, password_hash, created_at
                            ) VALUES (%s, %s, %s, %s)
                            RETURNING id, username
                            """,
                            (username, email, password_hash, time.time()),
                        )
                    ).fetchone()
                    assert row is not None
                    return await self._issue_tokens(
                        connection, user_id=int(row[0]), username=str(row[1])
                    )
        except UniqueViolation as exc:
            raise AuthError("username already exists", status_code=409) from exc

    async def login(self, *, username: str, password: str) -> dict[str, Any]:
        async with self.pool.connection() as connection:
            row = await (
                await connection.execute(
                    """
                    SELECT id, username, password_hash
                    FROM users
                    WHERE lower(username) = lower(%s)
                    """,
                    (username.strip(),),
                )
            ).fetchone()
        if row is None or not pwd_context.verify(password, str(row[2])):
            raise AuthError("invalid username or password", status_code=401)
        return await self.issue_tokens(user_id=int(row[0]), username=str(row[1]))

    async def refresh(self, refresh_token: str) -> dict[str, Any]:
        try:
            payload = jwt.decode(
                refresh_token,
                self.settings.jwt_secret,
                algorithms=["HS256"],
            )
        except jwt.PyJWTError as exc:
            raise AuthError("invalid refresh token", status_code=401) from exc
        if payload.get("type") != "refresh":
            raise AuthError("invalid refresh token", status_code=401)
        jti = payload.get("jti")
        user_id = payload.get("sub")
        username = payload.get("username")
        if not jti or user_id is None or not username:
            raise AuthError("invalid refresh token", status_code=401)

        token_hash = hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()
        now = time.time()
        async with self.pool.connection() as connection:
            async with connection.transaction():
                row = await (
                    await connection.execute(
                        """
                        SELECT token_hash, expires_at, revoked
                        FROM refresh_tokens
                        WHERE jti = %s
                        FOR UPDATE
                        """,
                        (jti,),
                    )
                ).fetchone()
                if (
                    row is None
                    or bool(row[2])
                    or float(row[1]) < now
                    or not secrets.compare_digest(str(row[0]), token_hash)
                ):
                    raise AuthError("invalid refresh token", status_code=401)
                await connection.execute(
                    "UPDATE refresh_tokens SET revoked = TRUE WHERE jti = %s",
                    (jti,),
                )
                return await self._issue_tokens(
                    connection, user_id=int(user_id), username=str(username)
                )

    async def issue_tokens(self, *, user_id: int, username: str) -> dict[str, Any]:
        async with self.pool.connection() as connection:
            return await self._issue_tokens(
                connection, user_id=user_id, username=username
            )

    async def _issue_tokens(
        self, connection, *, user_id: int, username: str
    ) -> dict[str, Any]:
        now = int(time.time())
        access_exp = now + self.settings.jwt_access_ttl_minutes * 60
        refresh_exp = now + self.settings.jwt_refresh_ttl_days * 86400
        access_token = jwt.encode(
            {
                "sub": str(user_id),
                "username": username,
                "type": "access",
                "iat": now,
                "exp": access_exp,
            },
            self.settings.jwt_secret,
            algorithm="HS256",
        )
        jti = secrets.token_urlsafe(16)
        refresh_token = jwt.encode(
            {
                "sub": str(user_id),
                "username": username,
                "type": "refresh",
                "jti": jti,
                "iat": now,
                "exp": refresh_exp,
            },
            self.settings.jwt_secret,
            algorithm="HS256",
        )
        token_hash = hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()
        await connection.execute(
            """
            INSERT INTO refresh_tokens(jti, user_id, token_hash, expires_at, revoked)
            VALUES (%s, %s, %s, %s, FALSE)
            """,
            (jti, user_id, token_hash, float(refresh_exp)),
        )
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": self.settings.jwt_access_ttl_minutes * 60,
        }

    def verify_access_token(self, token: str) -> dict[str, Any]:
        return verify_access_token(token, self.settings)
