"""Navidrome database deletion and optional Subsonic scan trigger."""

import hashlib
import os
import secrets
from pathlib import Path, PurePosixPath
from urllib.parse import urljoin
from uuid import uuid4

import aiosqlite
import httpx

from app.core.audit import audit_event
from app.core.config import Settings
from app.models.schemas import DeleteResult
from app.services.recommendation_identity import weak_identity

# Navidrome 0.55+ added artist-link and scrobble tables. Delete these before
# media_file so FOREIGN KEY failures do not roll the whole song back.
_RELATED_DELETE_TARGETS = (
    ("playlist_tracks", "media_file_id"),
    ("annotation", "item_id"),
    ("bookmark", "item_id"),
    ("media_file_artists", "media_file_id"),
    ("scrobbles", "media_file_id"),
    ("scrobble_buffer", "media_file_id"),
)


class DatabaseUnavailableError(RuntimeError):
    pass


class ScanNotConfiguredError(RuntimeError):
    pass


class ScanRejectedError(RuntimeError):
    pass


class LibraryService:
    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self._client = client
        self._settings = settings

    async def delete_songs(self, song_ids: list[str]) -> DeleteResult:
        database = Path(self._settings.navidrome_db_path)
        if not database.is_file():
            raise DatabaseUnavailableError("Navidrome database is not available")

        details: list[dict] = []
        async with aiosqlite.connect(database) as db:
            await db.execute("PRAGMA foreign_keys=ON")
            cursor = await db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
            tables = {row[0] for row in await cursor.fetchall()}
            if "media_file" not in tables:
                raise DatabaseUnavailableError("Navidrome media_file table is missing")

            for song_id in song_ids:
                details.append(await self._delete_one(db, tables, song_id))

            if {"playlist", "playlist_tracks"}.issubset(tables):
                try:
                    await db.execute(
                        "UPDATE playlist SET song_count = ("
                        "SELECT COUNT(*) FROM playlist_tracks "
                        "WHERE playlist_id = playlist.id)"
                    )
                    await db.commit()
                except aiosqlite.Error as exc:
                    await db.rollback()
                    audit_event("playlist_count_update_failed", reason=type(exc).__name__)

        deleted = sum(detail["status"] == "deleted" for detail in details)
        skipped = sum(detail["status"] == "skipped" for detail in details)
        errors = sum(detail["status"] == "error" for detail in details)
        audit_event(
            "delete_completed",
            requested=len(song_ids),
            deleted=deleted,
            skipped=skipped,
            errors=errors,
        )
        return DeleteResult(
            deleted=deleted,
            skipped=skipped,
            errors=errors,
            msg=f"deleted {deleted}, skipped {skipped}, errors {errors}",
            details=details,
        )

    async def _delete_one(
        self,
        db: aiosqlite.Connection,
        tables: set[str],
        song_id: str,
    ) -> dict:
        staged: list[tuple[Path, Path]] = []
        try:
            await db.execute("BEGIN IMMEDIATE")
            cursor = await db.execute(
                "SELECT path FROM media_file WHERE id = ?",
                (song_id,),
            )
            row = await cursor.fetchone()
            if row is None:
                await db.rollback()
                return {"id": song_id, "status": "skipped", "reason": "not found"}

            (stored_path,) = row
            target = self._resolve_host_path(stored_path)
            staged = self._stage_related_files(target)
            await self._delete_related_rows(db, tables, song_id)
            await db.execute("DELETE FROM media_file WHERE id = ?", (song_id,))
            await db.commit()
        except Exception as exc:
            await db.rollback()
            restored = self._restore_staged(staged)
            audit_event(
                "delete_failed",
                song_id=song_id,
                reason=type(exc).__name__,
                files_restored=restored,
            )
            return {
                "id": song_id,
                "status": "error",
                "reason": str(exc),
            }

        cleanup_error: OSError | None = None
        for _, staged_path in staged:
            try:
                staged_path.unlink(missing_ok=True)
            except OSError as exc:
                cleanup_error = exc
        if cleanup_error is not None:
            audit_event(
                "delete_cleanup_failed",
                song_id=song_id,
                reason=type(cleanup_error).__name__,
            )
            return {
                "id": song_id,
                "status": "error",
                "reason": "database row deleted but staged file cleanup failed",
            }

        audit_event(
            "song_deleted",
            song_id=song_id,
            path=str(target),
            file_existed=bool(staged),
        )
        return {
            "id": song_id,
            "status": "deleted",
            "path": str(target),
            "file_existed": bool(staged),
        }

    @staticmethod
    async def _delete_related_rows(
        db: aiosqlite.Connection,
        tables: set[str],
        song_id: str,
    ) -> None:
        for table, column in _RELATED_DELETE_TARGETS:
            if table not in tables:
                continue
            await db.execute(
                f"DELETE FROM {table} WHERE {column} = ?",
                (song_id,),
            )
        # Do not DELETE from media_file_fts: Navidrome 0.55+ uses a contentless
        # FTS5 index. Direct DELETE fails; the AFTER DELETE trigger on media_file
        # issues the FTS5 'delete' command with the required column values.

    def _resolve_host_path(self, navidrome_path: str) -> Path:
        if not navidrome_path or "\x00" in navidrome_path or "\\" in navidrome_path:
            raise ValueError("invalid path stored in Navidrome database")

        normalized = "/" + navidrome_path.lstrip("/")
        prefix = self._settings.navidrome_music_prefix.strip()
        if prefix:
            normalized_prefix = "/" + prefix.strip("/")
            if normalized == normalized_prefix:
                raise ValueError("Navidrome path does not name a file")
            if not normalized.startswith(normalized_prefix + "/"):
                raise ValueError("Navidrome path is outside configured prefix")
            relative = normalized[len(normalized_prefix) :].lstrip("/")
        else:
            relative = normalized.lstrip("/")

        parts = PurePosixPath(relative).parts
        if not parts or any(part in {"", ".", ".."} for part in parts):
            raise ValueError("Navidrome path escapes MUSIC_DIR")

        music_root = Path(self._settings.music_dir).expanduser().resolve()
        candidate = music_root.joinpath(*parts)
        resolved = candidate.resolve(strict=False)
        try:
            resolved.relative_to(music_root)
        except ValueError as exc:
            raise ValueError("Navidrome path escapes MUSIC_DIR") from exc
        if candidate.is_symlink():
            raise ValueError("refusing to delete a symlinked media file")
        return candidate

    def _stage_related_files(self, target: Path) -> list[tuple[Path, Path]]:
        staged: list[tuple[Path, Path]] = []
        try:
            for original in (target, target.with_suffix(".lrc")):
                if not original.exists() and not original.is_symlink():
                    continue
                if original.is_symlink() or not original.is_file():
                    raise OSError(f"refusing to delete non-regular file: {original.name}")
                staged_path = original.with_name(f".{original.name}.delete-{uuid4().hex}")
                os.replace(original, staged_path)
                staged.append((original, staged_path))
            return staged
        except Exception:
            self._restore_staged(staged)
            raise

    @staticmethod
    def _restore_staged(staged: list[tuple[Path, Path]]) -> bool:
        restored = True
        for original, staged_path in reversed(staged):
            try:
                if staged_path.exists():
                    os.replace(staged_path, original)
            except OSError:
                restored = False
        return restored


    async def recommendation_weak_identities(self) -> set[str]:
        """Return canonical title/artist identities for active library songs."""
        database = Path(self._settings.navidrome_db_path)
        if not database.is_file():
            raise DatabaseUnavailableError("Navidrome database is not available")

        async with aiosqlite.connect(f"file:{database}?mode=ro", uri=True) as db:
            cursor = await db.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'media_file'"
            )
            if await cursor.fetchone() is None:
                raise DatabaseUnavailableError("Navidrome media_file table is missing")

            try:
                cursor = await db.execute(
                    "SELECT title, artist, album_artist FROM media_file "
                    "WHERE COALESCE(missing, 0)=0"
                )
            except aiosqlite.Error:
                cursor = await db.execute(
                    "SELECT title, artist, NULL FROM media_file "
                    "WHERE COALESCE(missing, 0)=0"
                )

            identities: set[str] = set()
            async for title, artist, album_artist in cursor:
                title_text = title or ""
                artist_text = artist or ""
                album_artist_text = album_artist or ""
                if not title_text and not artist_text and not album_artist_text:
                    continue
                if title_text or artist_text:
                    identities.add(weak_identity(title_text, artist_text))
                if album_artist_text and album_artist_text != artist_text:
                    identities.add(weak_identity(title_text, album_artist_text))
            return identities

    async def trigger_scan(self) -> dict:
        settings = self._settings
        if (
            not settings.navidrome_url
            or not settings.navidrome_user
            or not settings.navidrome_password
        ):
            raise ScanNotConfiguredError("Navidrome scan credentials are not configured")

        salt = secrets.token_hex(6)
        token = hashlib.md5(
            f"{settings.navidrome_password}{salt}".encode(),
            usedforsecurity=False,
        ).hexdigest()
        endpoint = urljoin(settings.navidrome_url.rstrip("/") + "/", "rest/startScan")
        response = await self._client.get(
            endpoint,
            params={
                "u": settings.navidrome_user,
                "t": token,
                "s": salt,
                "v": "1.16.1",
                "c": settings.app_name,
                "f": "json",
            },
        )
        response.raise_for_status()
        try:
            payload = response.json()
            envelope = payload["subsonic-response"]
        except (ValueError, KeyError, TypeError) as exc:
            raise ScanRejectedError("Navidrome returned an invalid scan response") from exc
        if envelope.get("status") != "ok":
            error = envelope.get("error") or {}
            raise ScanRejectedError(error.get("message", "Navidrome rejected the scan"))

        scan_status = envelope.get("scanStatus") or {}
        audit_event(
            "scan_triggered",
            scanning=scan_status.get("scanning"),
            count=scan_status.get("count"),
        )
        return scan_status

    def inspect_media_file(self, navidrome_path: str) -> tuple[bool, int | None]:
        """Return whether the stored path is a non-empty regular file, plus size."""
        try:
            target = self._resolve_host_path(navidrome_path)
        except ValueError:
            return False, None
        if target.is_symlink() or not target.is_file():
            return False, None
        try:
            size = target.stat().st_size
        except OSError:
            return False, None
        return size > 0, size

    def resolve_media_path(self, navidrome_path: str) -> Path | None:
        try:
            target = self._resolve_host_path(navidrome_path)
        except ValueError:
            return None
        if target.is_symlink() or not target.is_file():
            return None
        return target
