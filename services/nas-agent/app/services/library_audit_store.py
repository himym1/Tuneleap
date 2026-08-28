"""Persist the last completed library audit so a restart can restore the report."""

from __future__ import annotations

import json
from pathlib import Path

from app.core.config import Settings
from app.models.schemas import LibraryAuditSnapshot
from app.services.library_audit import LibraryAuditFinding

_STORE_NAME = "library-audit.json"


def audit_state_path(settings: Settings) -> Path:
    return Path(settings.navidrome_db_path).expanduser().resolve().parent / _STORE_NAME


def load_audit_state(
    settings: Settings,
) -> tuple[LibraryAuditSnapshot, list[LibraryAuditFinding]] | None:
    path = audit_state_path(settings)
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    raw_snapshot = payload.get("snapshot")
    raw_findings = payload.get("findings")
    if not isinstance(raw_snapshot, dict) or not isinstance(raw_findings, list):
        return None
    try:
        snapshot = LibraryAuditSnapshot.model_validate(raw_snapshot)
        findings = [
            LibraryAuditFinding(
                song_id=str(item.get("song_id") or ""),
                title=str(item.get("title") or ""),
                artist=str(item.get("artist") or ""),
                album=str(item.get("album") or ""),
                album_id=str(item.get("album_id") or ""),
                suffix=str(item.get("suffix") or ""),
                bit_rate=_as_int(item.get("bit_rate")),
                duration=_as_int(item.get("duration")),
                sample_rate=_as_int(item.get("sample_rate")),
                codes=[str(code) for code in item.get("codes") or [] if str(code).strip()],
                severity=str(item.get("severity") or "info"),
                cutoff_hz=_as_float(item.get("cutoff_hz")),
                hf_extension_db=_as_float(item.get("hf_extension_db")),
                deep_error=str(item["deep_error"]) if item.get("deep_error") else None,
            )
            for item in raw_findings
            if isinstance(item, dict) and item.get("song_id")
        ]
    except (TypeError, ValueError):
        return None
    if snapshot.stage in {"scanning", "deep_scanning"}:
        snapshot = snapshot.model_copy(update={"active": False, "stage": "cancelled"})
    return snapshot, findings


def save_audit_state(
    settings: Settings,
    snapshot: LibraryAuditSnapshot,
    findings: list[LibraryAuditFinding],
) -> None:
    if snapshot.stage in {"scanning", "deep_scanning", "idle"}:
        return
    path = audit_state_path(settings)
    payload = {
        "snapshot": snapshot.model_dump(),
        "findings": [item.as_dict() for item in findings],
    }
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    except OSError:
        return


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


def _as_float(value: object) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
