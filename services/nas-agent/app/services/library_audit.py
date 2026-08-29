"""Fast library quality rules. Metadata and file presence only — no decode/FFT."""

from __future__ import annotations

import json
import re
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from app.services.recommendation_identity import normalize_text, weak_identity

AUDIT_LOW_BITRATE_KBPS = 320
AUDIT_SUSPECT_LOSSLESS_KBPS = 500
AUDIT_SENTINEL_BITRATE = 999
AUDIT_DURATION_TOLERANCE_SECONDS = 3

CODE_MISSING = "missing"
CODE_LOW_BITRATE = "low_bitrate"
CODE_SUSPECT_TRANSCODE = "suspect_transcode"
CODE_DUPLICATE_VERSION = "duplicate_version"
CODE_LOSSY_TRANSCODE = "lossy_transcode"
CODE_FAKE_HIRES = "fake_hires"
CODE_DEEP_FAILED = "deep_failed"
CODE_MISSING_TITLE = "missing_title"
CODE_MISSING_ARTIST = "missing_artist"
CODE_MISSING_ALBUM = "missing_album"
CODE_SUSPICIOUS_TEXT = "suspicious_text"
CODE_MISSING_COVER = "missing_cover"
CODE_MISSING_TRACK = "missing_track"
CODE_MISSING_YEAR = "missing_year"
CODE_MISSING_LYRICS = "missing_lyrics"
CODE_TAG_MISMATCH = "tag_mismatch"

METADATA_CODES = frozenset(
    {
        CODE_MISSING_TITLE,
        CODE_MISSING_ARTIST,
        CODE_MISSING_ALBUM,
        CODE_SUSPICIOUS_TEXT,
        CODE_MISSING_COVER,
        CODE_MISSING_TRACK,
        CODE_MISSING_YEAR,
        CODE_MISSING_LYRICS,
        CODE_TAG_MISMATCH,
    }
)

SEVERITY_ERROR = "error"
SEVERITY_WARN = "warn"
SEVERITY_INFO = "info"

_LOSSY_SUFFIXES = frozenset({"mp3", "aac", "m4a", "mp4", "ogg", "opus", "wma"})
_LOSSLESS_SUFFIXES = frozenset(
    {"flac", "alac", "wav", "aiff", "aif", "ape", "wv", "tak", "dsf", "dff"}
)
_PLACEHOLDER_TAGS = frozenset(
    {
        "unknown",
        "unknown artist",
        "unknown album",
        "untitled",
        "untitled track",
        "track",
        "no title",
        "no artist",
        "n/a",
        "none",
        "null",
        "未知",
        "未知艺术家",
        "未知歌手",
        "未知专辑",
        "未命名",
        "无标题",
        "无",
    }
)
_MOJIBAKE_MARKERS = ("\ufffd", "锟斤拷", "烫烫", "屯屯", "ï¿½")
_CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")


@dataclass(frozen=True)
class LibraryAuditRules:
    low_bitrate_kbps: int = AUDIT_LOW_BITRATE_KBPS
    suspect_lossless_kbps: int = AUDIT_SUSPECT_LOSSLESS_KBPS
    duration_tolerance_seconds: int = AUDIT_DURATION_TOLERANCE_SECONDS


@dataclass(frozen=True)
class LibraryTrack:
    song_id: str
    title: str = ""
    artist: str = ""
    album: str = ""
    album_id: str = ""
    suffix: str = ""
    bit_rate: int | None = None
    duration: int | None = None
    sample_rate: int | None = None
    missing_file: bool = False
    stored_path: str = ""
    has_cover_art: bool | None = None
    track_number: int | None = None
    year: int | None = None
    lyrics: str | None = None
    album_track_count: int = 1
    file_title: str = ""
    file_artist: str = ""
    file_album: str = ""
    file_has_lyrics: bool = False
    sidecar_lyrics: bool = False
    tags_readable: bool = False


def normalize_suffix(value: object) -> str:
    text = str(value or "").strip().lower()
    if text.startswith("."):
        text = text[1:]
    return text


def usable_bit_rate(value: int | None) -> int | None:
    if value is None or value <= 0 or value == AUDIT_SENTINEL_BITRATE:
        return None
    return value


def classify_track(
    track: LibraryTrack,
    rules: LibraryAuditRules | None = None,
) -> list[str]:
    settings = rules or LibraryAuditRules()
    codes: list[str] = []
    if track.missing_file:
        codes.append(CODE_MISSING)

    suffix = normalize_suffix(track.suffix)
    rate = usable_bit_rate(track.bit_rate)
    if suffix in _LOSSY_SUFFIXES and rate is not None and rate < settings.low_bitrate_kbps:
        codes.append(CODE_LOW_BITRATE)
    if (
        suffix in _LOSSLESS_SUFFIXES
        and rate is not None
        and rate < settings.suspect_lossless_kbps
    ):
        codes.append(CODE_SUSPECT_TRANSCODE)
    return codes


def is_placeholder_tag(value: object) -> bool:
    text = unicodedata.normalize("NFKC", str(value or "")).strip()
    if not text:
        return True
    return normalize_text(text) in _PLACEHOLDER_TAGS


def is_suspicious_text(value: object) -> bool:
    text = str(value or "")
    if not text.strip():
        return False
    if _CONTROL_RE.search(text):
        return True
    if any(marker in text for marker in _MOJIBAKE_MARKERS):
        return True
    stripped = text.strip()
    if len(stripped) >= 3 and set(stripped) <= {"?", "？", "□", "■"}:
        return True
    return False


def lyrics_have_text(value: object) -> bool:
    if value is None:
        return False
    if isinstance(value, bytes):
        try:
            value = value.decode("utf-8", errors="ignore")
        except Exception:
            return False
    if isinstance(value, str):
        text = value.strip()
        if not text or text in {"[]", "{}", "null"}:
            return False
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            return bool(text)
        return lyrics_have_text(parsed)
    if isinstance(value, dict):
        for key in ("value", "text", "lyric", "lrc"):
            if lyrics_have_text(value.get(key)):
                return True
        for key in ("line", "lines"):
            if lyrics_have_text(value.get(key)):
                return True
        return False
    if isinstance(value, list):
        return any(lyrics_have_text(item) for item in value)
    return False


def sidecar_lyrics_present(path: Path) -> bool:
    sidecar = path.with_suffix(".lrc")
    if not sidecar.is_file():
        return False
    try:
        return bool(sidecar.read_text(encoding="utf-8", errors="replace").strip())
    except OSError:
        return False


def _first_tag_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        try:
            value = value.decode("utf-8", errors="ignore")
        except Exception:
            return ""
    if isinstance(value, (list, tuple)):
        for item in value:
            text = _first_tag_text(item)
            if text:
                return text
        return ""
    text_attr = getattr(value, "text", None)
    if text_attr is not None and text_attr is not value:
        return _first_tag_text(text_attr)
    text = str(value).strip()
    return text


def _extract_tag_snapshot(tags: object) -> dict[str, object]:
    title = _first_tag_text(
        tags.get("TIT2") or tags.get("title") or tags.get("\xa9nam")
    )
    artist = _first_tag_text(
        tags.get("TPE1") or tags.get("artist") or tags.get("\xa9ART")
    )
    album = _first_tag_text(
        tags.get("TALB") or tags.get("album") or tags.get("\xa9alb")
    )
    has_lyrics = False
    if hasattr(tags, "getall"):
        for item in tags.getall("USLT") or []:
            if lyrics_have_text(getattr(item, "text", item)):
                has_lyrics = True
                break
    if not has_lyrics:
        for key in ("LYRICS", "lyrics", "unsyncedlyrics", "\xa9lyr"):
            if lyrics_have_text(tags.get(key) if hasattr(tags, "get") else None):
                has_lyrics = True
                break
    return {
        "title": title,
        "artist": artist,
        "album": album,
        "has_lyrics": has_lyrics,
        "readable": True,
    }


def read_file_tags(path: Path) -> dict[str, object]:
    """Read embedded title/artist/album/lyrics. Never raises."""
    empty: dict[str, object] = {
        "title": "",
        "artist": "",
        "album": "",
        "has_lyrics": False,
        "readable": False,
    }
    tags = None
    try:
        import mutagen

        audio = mutagen.File(path)
        if audio is not None:
            tags = getattr(audio, "tags", None)
    except Exception:
        tags = None
    if tags is None:
        try:
            from mutagen.id3 import ID3

            tags = ID3(path)
        except Exception:
            return empty
    if tags is None:
        return empty
    try:
        return _extract_tag_snapshot(tags)
    except Exception:
        return empty


def tags_mismatch(library_value: str, file_value: str) -> bool:
    library = normalize_text(library_value)
    embedded = normalize_text(file_value)
    if not library or not embedded:
        return False
    return library != embedded


def classify_metadata(track: LibraryTrack) -> list[str]:
    """Flag empty/placeholder/garbled tags, missing extras, and file/DB mismatch."""
    codes: list[str] = []
    if is_placeholder_tag(track.title):
        codes.append(CODE_MISSING_TITLE)
    if is_placeholder_tag(track.artist):
        codes.append(CODE_MISSING_ARTIST)
    if is_placeholder_tag(track.album):
        codes.append(CODE_MISSING_ALBUM)
    if any(
        is_suspicious_text(value)
        for value in (track.title, track.artist, track.album)
        if not is_placeholder_tag(value)
    ):
        codes.append(CODE_SUSPICIOUS_TEXT)
    if track.has_cover_art is False:
        codes.append(CODE_MISSING_COVER)
    if (
        track.track_number is not None
        and track.track_number <= 0
        and track.album_track_count >= 2
    ):
        codes.append(CODE_MISSING_TRACK)
    if track.year is not None and track.year <= 0:
        codes.append(CODE_MISSING_YEAR)
    if track.lyrics is not None and not (
        lyrics_have_text(track.lyrics) or track.sidecar_lyrics or track.file_has_lyrics
    ):
        codes.append(CODE_MISSING_LYRICS)
    if track.tags_readable and (
        tags_mismatch(track.title, track.file_title)
        or tags_mismatch(track.artist, track.file_artist)
        or tags_mismatch(track.album, track.file_album)
    ):
        codes.append(CODE_TAG_MISMATCH)
    return codes


def duplicate_version_ids(
    tracks: list[LibraryTrack],
    rules: LibraryAuditRules | None = None,
) -> set[str]:
    grouped: dict[str, list[LibraryTrack]] = defaultdict(list)
    for track in tracks:
        identity = weak_identity(track.title, track.artist)
        if not identity.strip("\x1f"):
            continue
        grouped[identity].append(track)

    flagged: set[str] = set()
    for members in grouped.values():
        durations = [
            track.duration for track in members if track.duration is not None
        ]
        if len(members) < 2 or len(durations) < 2:
            continue
        if max(durations) - min(durations) <= (
            rules or LibraryAuditRules()
        ).duration_tolerance_seconds:
            continue
        flagged.update(track.song_id for track in members)
    return flagged


def severity_for_codes(codes: list[str]) -> str:
    if CODE_MISSING in codes or CODE_DEEP_FAILED in codes:
        return SEVERITY_ERROR
    if (
        CODE_LOSSY_TRANSCODE in codes
        or CODE_FAKE_HIRES in codes
        or CODE_SUSPECT_TRANSCODE in codes
        or CODE_LOW_BITRATE in codes
    ):
        return SEVERITY_WARN
    return SEVERITY_INFO


def summarize_codes(code_lists: list[list[str]]) -> dict[str, int]:
    summary = {
        CODE_MISSING: 0,
        CODE_LOW_BITRATE: 0,
        CODE_SUSPECT_TRANSCODE: 0,
        CODE_DUPLICATE_VERSION: 0,
        CODE_LOSSY_TRANSCODE: 0,
        CODE_FAKE_HIRES: 0,
        CODE_DEEP_FAILED: 0,
        CODE_MISSING_TITLE: 0,
        CODE_MISSING_ARTIST: 0,
        CODE_MISSING_ALBUM: 0,
        CODE_SUSPICIOUS_TEXT: 0,
        CODE_MISSING_COVER: 0,
        CODE_MISSING_TRACK: 0,
        CODE_MISSING_YEAR: 0,
        CODE_MISSING_LYRICS: 0,
        CODE_TAG_MISMATCH: 0,
    }
    for codes in code_lists:
        for code in codes:
            if code in summary:
                summary[code] += 1
    return summary


def is_deep_scan_suffix(suffix: str) -> bool:
    return normalize_suffix(suffix) in _LOSSLESS_SUFFIXES


def apply_spectrum_codes(codes: list[str], *, lossy: bool, fake_hires: bool) -> list[str]:
    next_codes = [
        code
        for code in codes
        if code
        not in {
            CODE_SUSPECT_TRANSCODE,
            CODE_LOSSY_TRANSCODE,
            CODE_FAKE_HIRES,
            CODE_DEEP_FAILED,
        }
    ]
    if fake_hires:
        next_codes.append(CODE_FAKE_HIRES)
    if lossy:
        next_codes.append(CODE_LOSSY_TRANSCODE)
    return next_codes


@dataclass
class LibraryAuditFinding:
    song_id: str
    title: str
    artist: str
    album: str
    suffix: str
    bit_rate: int | None
    duration: int | None
    sample_rate: int | None
    album_id: str = ""
    codes: list[str] = field(default_factory=list)
    severity: str = SEVERITY_INFO
    cutoff_hz: float | None = None
    hf_extension_db: float | None = None
    deep_error: str | None = None

    def as_dict(self) -> dict[str, object]:
        payload: dict[str, object] = {
            "song_id": self.song_id,
            "title": self.title,
            "artist": self.artist,
            "album": self.album,
            "album_id": self.album_id,
            "suffix": self.suffix,
            "bit_rate": self.bit_rate,
            "duration": self.duration,
            "sample_rate": self.sample_rate,
            "codes": list(self.codes),
            "severity": self.severity,
        }
        if self.cutoff_hz is not None:
            payload["cutoff_hz"] = self.cutoff_hz
        if self.hf_extension_db is not None:
            payload["hf_extension_db"] = self.hf_extension_db
        if self.deep_error:
            payload["deep_error"] = self.deep_error
        return payload
