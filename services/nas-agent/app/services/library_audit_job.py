"""Single in-flight library audit job. Reads navidrome.db and music files only."""

from __future__ import annotations

import asyncio
from collections import Counter
from contextlib import suppress
from dataclasses import replace
from pathlib import Path

import aiosqlite

from app.core.audit import audit_event
from app.core.config import Settings
from app.models.schemas import (
    LibraryAuditFinding as LibraryAuditFindingModel,
    LibraryAuditFindingsResponse,
    LibraryAuditSnapshot,
    LibraryAuditSummary,
)
from app.services.library import DatabaseUnavailableError, LibraryService
from app.services.library_audit import (
    CODE_DEEP_FAILED,
    CODE_DUPLICATE_VERSION,
    LibraryAuditFinding,
    LibraryAuditRules,
    LibraryTrack,
    apply_spectrum_codes,
    classify_metadata,
    classify_track,
    duplicate_version_ids,
    is_deep_scan_suffix,
    normalize_suffix,
    read_file_tags,
    sidecar_lyrics_present,
    severity_for_codes,
    summarize_codes,
)
from app.services.library_audit_spectrum import DeepDecodeError, analyze_file
from app.services.library_audit_store import load_audit_state, save_audit_state

_OPTIONAL_COLUMNS = (
    "title",
    "artist",
    "album",
    "album_id",
    "suffix",
    "bit_rate",
    "duration",
    "sample_rate",
    "size",
    "missing",
    "has_cover_art",
    "track_number",
    "year",
    "lyrics",
)


class LibraryAuditBusyError(RuntimeError):
    pass


class LibraryAuditNotReadyError(RuntimeError):
    pass


def _as_int(value: object) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(round(value))
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return None


class LibraryAuditService:
    def __init__(self, settings: Settings, library: LibraryService) -> None:
        self._settings = settings
        self._library = library
        self._lock = asyncio.Lock()
        self._task: asyncio.Task[None] | None = None
        self._cancel = asyncio.Event()
        self._snapshot = LibraryAuditSnapshot()
        self._findings: list[LibraryAuditFinding] = []
        self._tracks: list[LibraryTrack] = []
        self._track_count = 0
        self._rules = LibraryAuditRules()
        loaded = load_audit_state(settings)
        if loaded is not None:
            self._snapshot, self._findings = loaded

    async def aclose(self) -> None:
        self._cancel.set()
        task = self._task
        if task is None:
            return
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task
        self._task = None

    def snapshot(self) -> LibraryAuditSnapshot:
        return self._snapshot.model_copy(deep=True)

    def findings(
        self,
        *,
        offset: int = 0,
        limit: int = 50,
        code: str | None = None,
    ) -> LibraryAuditFindingsResponse:
        items = self._findings
        if code:
            items = [item for item in items if code in item.codes]
        start = max(0, offset)
        page = items[start : start + max(1, min(limit, 200))]
        return LibraryAuditFindingsResponse(
            items=[LibraryAuditFindingModel.model_validate(item.as_dict()) for item in page],
            offset=start,
            limit=max(1, min(limit, 200)),
            total=len(items),
        )

    async def start(self, rules: LibraryAuditRules | None = None) -> LibraryAuditSnapshot:
        database = Path(self._settings.navidrome_db_path)
        if not database.is_file():
            raise DatabaseUnavailableError("Navidrome database is not available")
        async with self._lock:
            if self._is_running():
                raise LibraryAuditBusyError("library audit already running")
            self._cancel = asyncio.Event()
            self._findings = []
            self._tracks = []
            self._track_count = 0
            self._rules = rules or LibraryAuditRules()
            self._snapshot = LibraryAuditSnapshot(
                active=True,
                stage="scanning",
                message="started",
            )
            self._task = asyncio.create_task(self._run())
            audit_event("library_audit_started")
            return self.snapshot()

    async def start_deep(
        self,
        *,
        scope: str = "findings",
        song_ids: list[str] | None = None,
    ) -> LibraryAuditSnapshot:
        async with self._lock:
            if self._is_running():
                raise LibraryAuditBusyError("library audit already running")
            if not self._tracks:
                self._tracks = await self._load_tracks()
                self._track_count = len(self._tracks)
            targets = self._deep_targets(scope=scope, song_ids=song_ids or [])
            if scope == "findings" and not song_ids and not self._findings:
                raise LibraryAuditNotReadyError("run a fast library audit before deep scanning findings")
            self._cancel = asyncio.Event()
            self._snapshot = LibraryAuditSnapshot(
                active=True,
                stage="deep_scanning",
                scanned=0,
                total=len(targets),
                message="deep scan started",
                summary=self._snapshot.summary.model_copy(deep=True),
            )
            self._task = asyncio.create_task(self._run_deep(targets))
            audit_event("library_audit_deep_started", targets=len(targets), scope=scope)
            return self.snapshot()

    async def cancel(self) -> LibraryAuditSnapshot:
        if self._is_running():
            self._cancel.set()
        return self.snapshot()

    def _is_running(self) -> bool:
        return self._snapshot.stage in {"scanning", "deep_scanning"}

    async def _run(self) -> None:
        try:
            tracks = await self._load_tracks()
            self._tracks = tracks
            self._track_count = len(tracks)
            if self._cancel.is_set():
                self._snapshot = self._completed_snapshot(
                    tracks,
                    [],
                    stage="cancelled",
                    message="cancelled",
                )
                self._persist()
                audit_event("library_audit_cancelled", scanned=0, issues=0)
                return
            self._snapshot = self._snapshot.model_copy(update={"total": len(tracks)})
            findings = await self._evaluate(tracks)
            if self._cancel.is_set():
                self._findings = findings
                self._snapshot = self._completed_snapshot(
                    tracks,
                    findings,
                    stage="cancelled",
                    message="cancelled",
                )
                self._persist()
                audit_event("library_audit_cancelled", scanned=len(tracks), issues=len(findings))
                return
            self._findings = findings
            self._snapshot = self._completed_snapshot(
                tracks,
                findings,
                stage="completed",
                message="completed",
            )
            self._persist()
            audit_event(
                "library_audit_completed",
                scanned=len(tracks),
                issues=len(findings),
            )
        except asyncio.CancelledError:
            self._snapshot = self._snapshot.model_copy(
                update={"active": False, "stage": "cancelled", "message": "cancelled"}
            )
            self._persist()
            raise
        except Exception as exc:
            self._snapshot = self._snapshot.model_copy(
                update={
                    "active": False,
                    "stage": "failed",
                    "error": str(exc),
                    "message": None,
                }
            )
            self._persist()
            audit_event("library_audit_failed", reason=type(exc).__name__)

    def _completed_snapshot(
        self,
        tracks: list[LibraryTrack],
        findings: list[LibraryAuditFinding],
        *,
        stage: str,
        message: str,
    ) -> LibraryAuditSnapshot:
        counts = summarize_codes([item.codes for item in findings])
        return LibraryAuditSnapshot(
            active=False,
            stage=stage,
            scanned=len(tracks),
            total=len(tracks),
            message=message,
            summary=LibraryAuditSummary(
                scanned=len(tracks),
                passed=max(0, len(tracks) - len(findings)),
                issues=len(findings),
                missing=counts["missing"],
                low_bitrate=counts["low_bitrate"],
                suspect_transcode=counts["suspect_transcode"],
                duplicate_version=counts["duplicate_version"],
                lossy_transcode=counts["lossy_transcode"],
                fake_hires=counts["fake_hires"],
                deep_failed=counts["deep_failed"],
                missing_title=counts["missing_title"],
                missing_artist=counts["missing_artist"],
                missing_album=counts["missing_album"],
                suspicious_text=counts["suspicious_text"],
                missing_cover=counts["missing_cover"],
                missing_track=counts["missing_track"],
                missing_year=counts["missing_year"],
                missing_lyrics=counts["missing_lyrics"],
                tag_mismatch=counts["tag_mismatch"],
            ),
        )

    def _snapshot_from_findings(self, *, stage: str, message: str) -> LibraryAuditSnapshot:
        tracks = self._tracks or []
        return self._completed_snapshot(tracks, self._findings, stage=stage, message=message)

    def _persist(self) -> None:
        save_audit_state(self._settings, self._snapshot, self._findings)

    def _deep_targets(self, *, scope: str, song_ids: list[str]) -> list[LibraryTrack]:
        wanted = set(song_ids)
        finding_ids = {item.song_id for item in self._findings}
        targets: list[LibraryTrack] = []
        for track in self._tracks:
            if track.missing_file:
                continue
            if wanted:
                if track.song_id in wanted:
                    targets.append(track)
                continue
            if scope == "lossless":
                if is_deep_scan_suffix(track.suffix):
                    targets.append(track)
                continue
            if track.song_id in finding_ids and is_deep_scan_suffix(track.suffix):
                targets.append(track)
        return targets

    async def _run_deep(self, targets: list[LibraryTrack]) -> None:
        try:
            by_id = {item.song_id: item for item in self._findings}
            for index, track in enumerate(targets, start=1):
                if self._cancel.is_set():
                    break
                finding = by_id.get(track.song_id) or LibraryAuditFinding(
                    song_id=track.song_id,
                    title=track.title,
                    artist=track.artist,
                    album=track.album,
                    album_id=track.album_id,
                    suffix=track.suffix,
                    bit_rate=track.bit_rate,
                    duration=track.duration,
                    sample_rate=track.sample_rate,
                )
                updated = await asyncio.to_thread(self._analyze_track, track, finding)
                if updated is None:
                    by_id.pop(track.song_id, None)
                else:
                    by_id[track.song_id] = updated
                self._findings = list(by_id.values())
                self._snapshot = self._snapshot.model_copy(update={"scanned": index})
                await asyncio.sleep(0)
            stage = "cancelled" if self._cancel.is_set() else "completed"
            message = "deep scan cancelled" if stage == "cancelled" else "deep scan completed"
            self._findings = list(by_id.values())
            self._snapshot = self._snapshot_from_findings(stage=stage, message=message)
            self._persist()
            audit_event(
                "library_audit_deep_finished",
                stage=stage,
                targets=len(targets),
                issues=len(self._findings),
            )
        except asyncio.CancelledError:
            self._snapshot = self._snapshot.model_copy(
                update={"active": False, "stage": "cancelled", "message": "cancelled"}
            )
            self._persist()
            raise
        except Exception as exc:
            self._snapshot = self._snapshot.model_copy(
                update={
                    "active": False,
                    "stage": "failed",
                    "error": str(exc),
                    "message": None,
                }
            )
            self._persist()
            audit_event("library_audit_deep_failed", reason=type(exc).__name__)

    def _analyze_track(
        self,
        track: LibraryTrack,
        finding: LibraryAuditFinding,
    ) -> LibraryAuditFinding | None:
        path = self._library.resolve_media_path(track.stored_path)
        if path is None:
            return self._mark_deep_failed(finding, "unresolved_path")
        try:
            verdict = analyze_file(path, track.duration)
        except DeepDecodeError as exc:
            return self._mark_deep_failed(finding, exc.code)
        except ValueError:
            return self._mark_deep_failed(finding, "unknown")
        codes = apply_spectrum_codes(
            finding.codes,
            lossy=verdict.lossy_transcode,
            fake_hires=verdict.fake_hires,
        )
        finding.codes = codes
        finding.cutoff_hz = verdict.cutoff_hz
        finding.hf_extension_db = verdict.hf_extension_db
        finding.sample_rate = finding.sample_rate or verdict.sample_rate
        finding.deep_error = None
        finding.severity = severity_for_codes(codes)
        if not codes:
            return None
        return finding

    def _mark_deep_failed(
        self,
        finding: LibraryAuditFinding,
        code: str,
    ) -> LibraryAuditFinding:
        codes = [item for item in finding.codes if item != CODE_DEEP_FAILED]
        codes.append(CODE_DEEP_FAILED)
        finding.codes = codes
        finding.deep_error = code
        finding.severity = severity_for_codes(codes)
        return finding

    async def _evaluate(self, tracks: list[LibraryTrack]) -> list[LibraryAuditFinding]:
        duplicates = duplicate_version_ids(tracks, self._rules)
        findings: list[LibraryAuditFinding] = []
        for index, track in enumerate(tracks, start=1):
            if self._cancel.is_set():
                break
            codes = classify_track(track, self._rules)
            codes.extend(classify_metadata(track))
            if track.song_id in duplicates:
                codes.append(CODE_DUPLICATE_VERSION)
            if codes:
                findings.append(
                    LibraryAuditFinding(
                        song_id=track.song_id,
                        title=track.title,
                        artist=track.artist,
                        album=track.album,
                        album_id=track.album_id,
                        suffix=track.suffix,
                        bit_rate=track.bit_rate,
                        duration=track.duration,
                        sample_rate=track.sample_rate,
                        codes=codes,
                        severity=severity_for_codes(codes),
                    )
                )
            if index == len(tracks) or index % 25 == 0:
                self._snapshot = self._snapshot.model_copy(update={"scanned": index})
                await asyncio.sleep(0)
        return findings

    async def _load_tracks(self) -> list[LibraryTrack]:
        database = Path(self._settings.navidrome_db_path)
        if not database.is_file():
            raise DatabaseUnavailableError("Navidrome database is not available")

        async with aiosqlite.connect(f"file:{database}?mode=ro", uri=True) as db:
            cursor = await db.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'media_file'"
            )
            if await cursor.fetchone() is None:
                raise DatabaseUnavailableError("Navidrome media_file table is missing")

            cursor = await db.execute("PRAGMA table_info(media_file)")
            columns = {row[1] for row in await cursor.fetchall()}
            if "id" not in columns or "path" not in columns:
                raise DatabaseUnavailableError("Navidrome media_file table is missing required columns")

            selected = ["id", "path", *[name for name in _OPTIONAL_COLUMNS if name in columns]]
            quoted = ", ".join(selected)
            cursor = await db.execute(f"SELECT {quoted} FROM media_file")
            rows = await cursor.fetchall()

        tracks: list[LibraryTrack] = []
        album_counts: Counter[str] = Counter()
        for row in rows:
            record = dict(zip(selected, row, strict=True))
            album_id = str(record.get("album_id") or "")
            if album_id:
                album_counts[album_id] += 1
            marked_missing = _as_int(record.get("missing")) == 1
            present, _size = (False, None)
            path = None
            if not marked_missing:
                present, _size = self._library.inspect_media_file(str(record.get("path") or ""))
                if present:
                    path = self._library.resolve_media_path(str(record.get("path") or ""))
            file_tags = read_file_tags(path) if path is not None else {}
            sidecar = sidecar_lyrics_present(path) if path is not None else False
            cover = record.get("has_cover_art") if "has_cover_art" in record else None
            year = record.get("year") if "year" in record else None
            track_number = record.get("track_number") if "track_number" in record else None
            lyrics = record.get("lyrics") if "lyrics" in record else None
            tracks.append(
                LibraryTrack(
                    song_id=str(record["id"]),
                    title=str(record.get("title") or ""),
                    artist=str(record.get("artist") or ""),
                    album=str(record.get("album") or ""),
                    album_id=album_id,
                    suffix=normalize_suffix(record.get("suffix")),
                    bit_rate=_as_int(record.get("bit_rate")),
                    duration=_as_int(record.get("duration")),
                    sample_rate=_as_int(record.get("sample_rate")),
                    missing_file=marked_missing or not present,
                    stored_path=str(record.get("path") or ""),
                    has_cover_art=None if cover is None else _as_int(cover) == 1,
                    track_number=None if track_number is None else (_as_int(track_number) or 0),
                    year=None if year is None else (_as_int(year) or 0),
                    lyrics=None if lyrics is None else str(lyrics),
                    album_track_count=1,
                    file_title=str(file_tags.get("title") or ""),
                    file_artist=str(file_tags.get("artist") or ""),
                    file_album=str(file_tags.get("album") or ""),
                    file_has_lyrics=bool(file_tags.get("has_lyrics")),
                    sidecar_lyrics=sidecar,
                    tags_readable=bool(file_tags.get("readable")),
                )
            )
        return [
            replace(track, album_track_count=album_counts.get(track.album_id, 1))
            for track in tracks
        ]
