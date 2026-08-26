"""In-memory snapshot of the single in-flight NAS import."""

from __future__ import annotations

import threading
import time
from typing import Callable

from app.models.schemas import ImportProgress


class ImportProgressTracker:
    def __init__(self, clock: Callable[[], float] = time.monotonic) -> None:
        self._clock = clock
        self._lock = threading.Lock()
        self._active = False
        self._filename: str | None = None
        self._bytes_received = 0
        self._bytes_total: int | None = None
        self._speed_bps = 0.0
        self._stage = "idle"
        self._error: str | None = None
        self._message: str | None = None
        self._last_t = 0.0
        self._last_bytes = 0

    def start(self, filename: str, bytes_total: int | None = None) -> None:
        now = self._clock()
        with self._lock:
            self._active = True
            self._filename = filename
            self._bytes_received = 0
            self._bytes_total = bytes_total
            self._speed_bps = 0.0
            self._stage = "downloading"
            self._error = None
            self._message = None
            self._last_t = now
            self._last_bytes = 0

    def set_total(self, bytes_total: int | None) -> None:
        with self._lock:
            if bytes_total is not None and bytes_total > 0:
                self._bytes_total = bytes_total

    def update(self, bytes_received: int) -> None:
        now = self._clock()
        with self._lock:
            received = max(0, bytes_received)
            elapsed = now - self._last_t
            if elapsed >= 0.2:
                delta = max(0, received - self._last_bytes)
                instant = delta / elapsed
                self._speed_bps = (
                    instant if self._speed_bps <= 0 else (self._speed_bps * 0.6 + instant * 0.4)
                )
                self._last_t = now
                self._last_bytes = received
            self._bytes_received = received
            self._stage = "downloading"
            self._active = True

    def finishing(self) -> None:
        with self._lock:
            if not self._active:
                return
            self._stage = "finishing"
            self._speed_bps = 0.0
            if self._bytes_total is not None:
                self._bytes_received = self._bytes_total

    def complete(self, message: str = "imported") -> None:
        with self._lock:
            self._active = False
            self._stage = "completed"
            self._speed_bps = 0.0
            self._error = None
            self._message = message

    def fail(self, error: str) -> None:
        with self._lock:
            self._active = False
            self._stage = "failed"
            self._speed_bps = 0.0
            self._error = error
            self._message = None

    def clear(self) -> None:
        with self._lock:
            self._active = False
            self._filename = None
            self._bytes_received = 0
            self._bytes_total = None
            self._speed_bps = 0.0
            self._stage = "idle"
            self._error = None
            self._message = None
            self._last_t = 0.0
            self._last_bytes = 0

    def snapshot(self) -> ImportProgress:
        with self._lock:
            return ImportProgress(
                active=self._active,
                filename=self._filename,
                bytes_received=self._bytes_received,
                bytes_total=self._bytes_total,
                speed_bps=round(self._speed_bps, 1),
                stage=self._stage,
                error=self._error,
                message=self._message,
            )
