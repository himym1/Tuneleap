"""Fast library quality rules. Metadata and file presence only — no decode/FFT."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field

from app.services.recommendation_identity import weak_identity

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

SEVERITY_ERROR = "error"
SEVERITY_WARN = "warn"
SEVERITY_INFO = "info"

_LOSSY_SUFFIXES = frozenset({"mp3", "aac", "m4a", "mp4", "ogg", "opus", "wma"})
_LOSSLESS_SUFFIXES = frozenset(
    {"flac", "alac", "wav", "aiff", "aif", "ape", "wv", "tak", "dsf", "dff"}
)


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
