"""Secure media import, metadata tagging, and atomic file placement."""

import asyncio
import ipaddress
import logging
import os
import shutil
import socket
import sqlite3
import tempfile
from pathlib import Path
from urllib.parse import urljoin, urlsplit

import httpx
from mutagen.flac import FLAC, Picture
from mutagen.id3 import APIC, ID3, TALB, TDRC, TIT2, TPE1, TRCK, TXXX, USLT, ID3NoHeaderError
from mutagen.mp4 import MP4, MP4Cover

from app.core.audit import audit_event
from app.core.config import Settings
from app.models.schemas import ImportResult, SongMeta
from app.services.recommendation_identity import weak_identity

_logger = logging.getLogger(__name__)
_SUPPORTED_EXTENSIONS = frozenset({".mp3", ".flac", ".m4a", ".mp4"})
_DANGEROUS_FILENAME_CHARS = frozenset('<>:"|?*')


class DownloadTooLargeError(RuntimeError):
    pass


class InsufficientStorageError(RuntimeError):
    pass


class UpstreamContentError(RuntimeError):
    pass


class DuplicateTrackError(RuntimeError):
    pass


class DuplicateCheckUnavailableError(RuntimeError):
    pass


class ImporterService:
    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self._client = client
        self._settings = settings
        # ponytail: one NAS-wide import lock avoids duplicate writes and disk thrash;
        # replace with per-target locks only if measured concurrency requires it.
        self._import_lock = asyncio.Lock()

    async def import_track(
        self,
        *,
        url: str,
        filename: str,
        song: SongMeta | None = None,
        pic_url: str | None = None,
        lyric: str | None = None,
        force: bool = False,
    ) -> ImportResult:
        async with self._import_lock:
            download_root, target = self._resolve_target(filename)
            sidecar = target.with_suffix(".lrc")

            if target.exists():
                if target.is_symlink() or not target.is_file():
                    raise ValueError("target path is not a regular file")
                if lyric is not None:
                    if not sidecar.exists():
                        self._write_text_atomic(sidecar, lyric)
                    try:
                        self._embed_metadata(target, None, None, None, lyric)
                    except Exception as exc:
                        _logger.warning("lyric embed skipped: %s", type(exc).__name__)
                audit_event("import_idempotent", filename=target.name)
                return ImportResult(ok=True, path=str(target), message="already imported")

            if not force and self._has_duplicate(song):
                audit_event(
                    "import_duplicate_rejected",
                    title=song.title if song else None,
                    artist=song.artist if song else None,
                )
                raise DuplicateTrackError("song already exists in the Navidrome library")

            await self._validate_remote_url(url)
            self._ensure_disk_space(download_root)

            media_tmp = self._new_temp_path(download_root, target.stem, target.suffix)
            lyric_tmp: Path | None = None
            target_created = False
            try:
                await self._download_to_file(url, media_tmp, download_root)
                cover_data = await self._download_cover(pic_url) if pic_url else None
                cover_mime = self._cover_mime(cover_data) if cover_data else None
                self._embed_metadata(media_tmp, song, cover_data, cover_mime, lyric)

                if lyric is not None:
                    lyric_tmp = self._new_temp_path(download_root, target.stem, ".lrc")
                    self._write_text_file(lyric_tmp, lyric)

                os.replace(media_tmp, target)
                target_created = True
                os.chmod(target, 0o644)
                if lyric_tmp is not None:
                    os.replace(lyric_tmp, sidecar)
                    os.chmod(sidecar, 0o644)

                audit_event(
                    "import_completed",
                    filename=target.name,
                    bytes=target.stat().st_size,
                    source=song.source if song else None,
                    has_cover=cover_data is not None,
                    has_lyric=lyric is not None,
                )
                return ImportResult(ok=True, path=str(target), message="imported")
            except Exception:
                media_tmp.unlink(missing_ok=True)
                if lyric_tmp is not None:
                    lyric_tmp.unlink(missing_ok=True)
                if target_created:
                    target.unlink(missing_ok=True)
                    sidecar.unlink(missing_ok=True)
                audit_event("import_failed", filename=target.name)
                raise

    def _has_duplicate(self, song: SongMeta | None) -> bool:
        if song is None or not song.title:
            return False
        database = Path(self._settings.navidrome_db_path)
        if not database.is_file():
            return False

        identity = weak_identity(song.title, song.artist or "")
        try:
            with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as db:
                try:
                    rows = db.execute(
                        "SELECT title, artist FROM media_file WHERE COALESCE(missing, 0)=0"
                    )
                except sqlite3.OperationalError:
                    rows = db.execute("SELECT title, artist FROM media_file")
                return any(
                    weak_identity(title or "", artist or "") == identity for title, artist in rows
                )
        except sqlite3.Error as exc:
            raise DuplicateCheckUnavailableError(
                "Navidrome duplicate check is unavailable"
            ) from exc

    def _resolve_target(self, filename: str) -> tuple[Path, Path]:
        if (
            not filename
            or filename != filename.strip(" .")
            or filename.startswith(".")
            or filename in {".", ".."}
            or "/" in filename
            or "\\" in filename
            or "\x00" in filename
            or any(ord(char) < 32 for char in filename)
            or any(char in _DANGEROUS_FILENAME_CHARS for char in filename)
            or Path(filename).name != filename
        ):
            raise ValueError("invalid filename")

        extension = Path(filename).suffix.lower()
        if extension not in _SUPPORTED_EXTENSIONS:
            raise ValueError("unsupported audio extension")

        music_root = Path(self._settings.music_dir).expanduser().resolve()
        configured_download_root = Path(self._settings.download_dir).expanduser()
        download_root = configured_download_root.resolve(strict=False)
        self._require_within(download_root, music_root, "DOWNLOAD_DIR must be under MUSIC_DIR")
        configured_download_root.mkdir(parents=True, exist_ok=True)
        download_root = configured_download_root.resolve()
        self._require_within(download_root, music_root, "DOWNLOAD_DIR must be under MUSIC_DIR")

        target = download_root / filename
        resolved_target = target.resolve(strict=False)
        self._require_within(resolved_target, download_root, "target path escapes DOWNLOAD_DIR")
        if target.is_symlink():
            raise ValueError("target path must not be a symlink")
        return download_root, target

    async def _download_to_file(
        self,
        url: str,
        destination: Path,
        download_root: Path,
    ) -> None:
        response = await self._open_stream(url)
        try:
            expected_size = self._content_length(response)
            if expected_size is not None and expected_size > self._settings.max_download_bytes:
                raise DownloadTooLargeError("media exceeds MAX_DOWNLOAD_BYTES")
            self._ensure_disk_space(download_root, expected_size or 0)

            total = 0
            with destination.open("wb") as output:
                async for chunk in response.aiter_bytes(256 * 1024):
                    if not chunk:
                        continue
                    total += len(chunk)
                    if total > self._settings.max_download_bytes:
                        raise DownloadTooLargeError("media exceeds MAX_DOWNLOAD_BYTES")
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
            if total == 0:
                raise UpstreamContentError("media response was empty")
        finally:
            await response.aclose()

    async def _download_cover(self, url: str) -> bytes | None:
        try:
            response = await self._open_stream(url)
            try:
                expected_size = self._content_length(response)
                if expected_size is not None and expected_size > self._settings.max_cover_bytes:
                    raise DownloadTooLargeError("cover exceeds MAX_COVER_BYTES")
                chunks: list[bytes] = []
                total = 0
                async for chunk in response.aiter_bytes(64 * 1024):
                    total += len(chunk)
                    if total > self._settings.max_cover_bytes:
                        raise DownloadTooLargeError("cover exceeds MAX_COVER_BYTES")
                    chunks.append(chunk)
                data = b"".join(chunks)
                if not data or self._cover_mime(data) is None:
                    raise UpstreamContentError("unsupported cover image")
                return data
            finally:
                await response.aclose()
        except Exception as exc:
            _logger.warning("cover download skipped: %s", type(exc).__name__)
            audit_event("cover_skipped", reason=type(exc).__name__)
            return None

    async def _open_stream(self, url: str) -> httpx.Response:
        current_url = url
        for redirect_count in range(self._settings.max_redirects + 1):
            await self._validate_remote_url(current_url)
            request = self._client.build_request(
                "GET",
                current_url,
                headers={
                    "User-Agent": "navidrome-nas-agent/0.1",
                    "Referer": self._referer(current_url),
                },
            )
            response = await self._client.send(request, stream=True, follow_redirects=False)
            if not response.is_redirect:
                response.raise_for_status()
                return response

            location = response.headers.get("location")
            await response.aclose()
            if not location:
                raise UpstreamContentError("redirect response omitted Location")
            if redirect_count >= self._settings.max_redirects:
                raise httpx.TooManyRedirects("too many media redirects", request=request)
            current_url = urljoin(current_url, location)

        raise RuntimeError("unreachable redirect state")

    async def _validate_remote_url(self, url: str) -> None:
        try:
            parsed = urlsplit(url)
            port = parsed.port
        except ValueError as exc:
            raise ValueError("invalid media URL") from exc

        if parsed.scheme not in {"http", "https"} or not parsed.hostname:
            raise ValueError("media URL must use http or https")
        if parsed.username or parsed.password:
            raise ValueError("media URL must not contain credentials")
        if self._settings.allow_private_media_urls:
            return

        hostname = parsed.hostname.rstrip(".").lower()
        if hostname == "localhost" or hostname.endswith((".localhost", ".local")):
            raise ValueError("private media URLs are disabled")

        addresses: set[str] = set()
        try:
            addresses.add(str(ipaddress.ip_address(hostname)))
        except ValueError:
            try:
                results = await asyncio.to_thread(
                    socket.getaddrinfo,
                    hostname,
                    port or (443 if parsed.scheme == "https" else 80),
                    type=socket.SOCK_STREAM,
                )
            except socket.gaierror as exc:
                raise ValueError("media URL host could not be resolved") from exc
            addresses.update(result[4][0] for result in results)

        if any(not ipaddress.ip_address(address).is_global for address in addresses):
            raise ValueError("private media URLs are disabled")

    def _ensure_disk_space(self, root: Path, expected_size: int = 0) -> None:
        free = shutil.disk_usage(root).free
        if free - expected_size < self._settings.min_free_bytes:
            raise InsufficientStorageError("reserved free disk space would be exceeded")

    @staticmethod
    def _content_length(response: httpx.Response) -> int | None:
        raw = response.headers.get("content-length")
        if raw is None:
            return None
        try:
            return max(0, int(raw))
        except ValueError:
            return None

    @staticmethod
    def _new_temp_path(root: Path, stem: str, suffix: str) -> Path:
        descriptor, path = tempfile.mkstemp(prefix=f".{stem}-", suffix=suffix, dir=root)
        os.close(descriptor)
        return Path(path)

    def _write_text_atomic(self, target: Path, content: str) -> None:
        temporary = self._new_temp_path(target.parent, target.stem, target.suffix)
        try:
            self._write_text_file(temporary, content)
            os.replace(temporary, target)
            os.chmod(target, 0o644)
        finally:
            temporary.unlink(missing_ok=True)

    @staticmethod
    def _write_text_file(target: Path, content: str) -> None:
        with target.open("w", encoding="utf-8", newline="\n") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())

    def _embed_metadata(
        self,
        path: Path,
        song: SongMeta | None,
        cover: bytes | None,
        cover_mime: str | None,
        lyric: str | None = None,
    ) -> None:
        if song is None and cover is None and not lyric:
            return
        extension = path.suffix.lower()
        if extension == ".mp3":
            self._embed_mp3(path, song, cover, cover_mime, lyric)
        elif extension == ".flac":
            self._embed_flac(path, song, cover, cover_mime, lyric)
        elif extension in {".m4a", ".mp4"}:
            self._embed_mp4(path, song, cover, cover_mime, lyric)

    @staticmethod
    def _embed_mp3(
        path: Path,
        song: SongMeta | None,
        cover: bytes | None,
        cover_mime: str | None,
        lyric: str | None = None,
    ) -> None:
        try:
            audio = ID3(path)
        except ID3NoHeaderError:
            audio = ID3()
        if song:
            if song.title:
                audio["TIT2"] = TIT2(encoding=3, text=song.title)
            if song.artist:
                audio["TPE1"] = TPE1(encoding=3, text=song.artist)
            if song.album:
                audio["TALB"] = TALB(encoding=3, text=song.album)
            if song.track is not None:
                audio["TRCK"] = TRCK(encoding=3, text=str(song.track))
            if song.year is not None:
                audio["TDRC"] = TDRC(encoding=3, text=str(song.year))
            if song.source:
                audio["TXXX:SOURCE"] = TXXX(encoding=3, desc="SOURCE", text=song.source)
        if cover and cover_mime:
            audio.delall("APIC")
            audio.add(APIC(encoding=3, mime=cover_mime, type=3, desc="Cover", data=cover))
        if lyric:
            audio.delall("USLT")
            audio.add(USLT(encoding=3, lang="xxx", desc="", text=lyric))
        audio.save(path)

    @staticmethod
    def _embed_flac(
        path: Path,
        song: SongMeta | None,
        cover: bytes | None,
        cover_mime: str | None,
        lyric: str | None = None,
    ) -> None:
        audio = FLAC(path)
        if song:
            if song.title:
                audio["title"] = song.title
            if song.artist:
                audio["artist"] = song.artist
            if song.album:
                audio["album"] = song.album
            if song.track is not None:
                audio["tracknumber"] = str(song.track)
            if song.year is not None:
                audio["date"] = str(song.year)
            if song.source:
                audio["source"] = song.source
        if cover and cover_mime:
            picture = Picture()
            picture.type = 3
            picture.mime = cover_mime
            picture.data = cover
            audio.clear_pictures()
            audio.add_picture(picture)
        if lyric:
            audio["LYRICS"] = lyric
        audio.save()

    @staticmethod
    def _embed_mp4(
        path: Path,
        song: SongMeta | None,
        cover: bytes | None,
        cover_mime: str | None,
        lyric: str | None = None,
    ) -> None:
        audio = MP4(path)
        if song:
            if song.title:
                audio["\xa9nam"] = [song.title]
            if song.artist:
                audio["\xa9ART"] = [song.artist]
            if song.album:
                audio["\xa9alb"] = [song.album]
            if song.track is not None:
                audio["trkn"] = [(song.track, 0)]
            if song.year is not None:
                audio["\xa9day"] = [str(song.year)]
            if song.source:
                audio["----:com.apple.iTunes:SOURCE"] = [song.source.encode()]
        if cover and cover_mime:
            image_format = (
                MP4Cover.FORMAT_PNG if cover_mime == "image/png" else MP4Cover.FORMAT_JPEG
            )
            audio["covr"] = [MP4Cover(cover, imageformat=image_format)]
        if lyric:
            audio["\xa9lyr"] = [lyric]
        audio.save()

    @staticmethod
    def _cover_mime(data: bytes | None) -> str | None:
        if not data:
            return None
        if data.startswith(b"\xff\xd8\xff"):
            return "image/jpeg"
        if data.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png"
        return None

    @staticmethod
    def _referer(url: str) -> str:
        hostname = (urlsplit(url).hostname or "").lower()
        if hostname == "kuwo.cn" or hostname.endswith(".kuwo.cn"):
            return "https://www.kuwo.cn/"
        return "https://music.163.com/"

    @staticmethod
    def _require_within(path: Path, root: Path, message: str) -> None:
        try:
            path.relative_to(root)
        except ValueError as exc:
            raise ValueError(message) from exc
