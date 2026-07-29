"""File-backed user auth with JWT access/refresh tokens.

Uses SQLite by default so cloud can ship without Postgres. DATABASE_URL is
reserved for a later SQLAlchemy migration without changing the HTTP contract.
"""

from __future__ import annotations

import hashlib
import secrets
import sqlite3
import time
from pathlib import Path
from typing import Any

import jwt
from passlib.context import CryptContext

from app.core.config import Settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthError(Exception):
    def __init__(self, detail: str, status_code: int = 400):
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


class AuthService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._path = Path(settings.auth_db_path)
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._path)
        conn.row_factory = sqlite3.Row
        return conn

    def _ensure_schema(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
                    email TEXT,
                    password_hash TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS refresh_tokens (
                    jti TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    token_hash TEXT NOT NULL,
                    expires_at REAL NOT NULL,
                    revoked INTEGER NOT NULL DEFAULT 0,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """
            )
            conn.commit()

    def register(self, *, username: str, password: str, email: str | None = None) -> dict[str, Any]:
        username = username.strip()
        if len(username) < 2:
            raise AuthError("username too short")
        if len(password) < 8:
            raise AuthError("password too short")
        password_hash = pwd_context.hash(password)
        now = time.time()
        try:
            with self._connect() as conn:
                cur = conn.execute(
                    "INSERT INTO users(username, email, password_hash, created_at) VALUES (?, ?, ?, ?)",
                    (username, email, password_hash, now),
                )
                user_id = int(cur.lastrowid)
                conn.commit()
        except sqlite3.IntegrityError as exc:
            raise AuthError("username already exists", status_code=409) from exc
        return self.issue_tokens(user_id=user_id, username=username)

    def login(self, *, username: str, password: str) -> dict[str, Any]:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT id, username, password_hash FROM users WHERE username = ? COLLATE NOCASE",
                (username.strip(),),
            ).fetchone()
        if row is None or not pwd_context.verify(password, row["password_hash"]):
            raise AuthError("invalid username or password", status_code=401)
        return self.issue_tokens(user_id=int(row["id"]), username=row["username"])

    def refresh(self, refresh_token: str) -> dict[str, Any]:
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
        with self._connect() as conn:
            row = conn.execute(
                "SELECT token_hash, expires_at, revoked FROM refresh_tokens WHERE jti = ?",
                (jti,),
            ).fetchone()
            if (
                row is None
                or row["revoked"]
                or row["expires_at"] < now
                or not secrets.compare_digest(row["token_hash"], token_hash)
            ):
                raise AuthError("invalid refresh token", status_code=401)
            conn.execute("UPDATE refresh_tokens SET revoked = 1 WHERE jti = ?", (jti,))
            conn.commit()
        return self.issue_tokens(user_id=int(user_id), username=str(username))

    def issue_tokens(self, *, user_id: int, username: str) -> dict[str, Any]:
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
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO refresh_tokens(jti, user_id, token_hash, expires_at, revoked) VALUES (?, ?, ?, ?, 0)",
                (jti, user_id, token_hash, float(refresh_exp)),
            )
            conn.commit()
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": self.settings.jwt_access_ttl_minutes * 60,
        }

    def verify_access_token(self, token: str) -> dict[str, Any]:
        try:
            payload = jwt.decode(token, self.settings.jwt_secret, algorithms=["HS256"])
        except jwt.PyJWTError as exc:
            raise AuthError("invalid access token", status_code=401) from exc
        if payload.get("type") != "access":
            raise AuthError("invalid access token", status_code=401)
        return payload
