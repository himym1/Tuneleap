"""Spectral checks for fake lossless and fake Hi-Res. Operates on decoded PCM."""

from __future__ import annotations

import shutil
import subprocess
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np

WINDOW_SIZE = 8192
HOP_SIZE = 4096
SEGMENT_SECONDS = 2.5
MAX_WINDOWS = 24
PEAK_RELATIVE_DB = -65.0
LOSSY_CUTOFF_HZ = 18500.0
HIRES_MIN_RATE = 48000
CD_WALL_HZ = 24000.0
HF_BAND_HZ = 26000.0
HF_EMPTY_DB = -70.0


class DeepDecodeError(RuntimeError):
    def __init__(self, message: str, *, code: str = "decode_failed") -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class SpectrumVerdict:
    cutoff_hz: float
    sample_rate: int
    hf_extension_db: float | None = None
    lossy_transcode: bool = False
    fake_hires: bool = False


def ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None


def segment_starts(duration_seconds: int | None) -> list[float]:
    if duration_seconds is not None and duration_seconds > 8:
        return [duration_seconds * 0.25, duration_seconds * 0.50, duration_seconds * 0.75]
    return [0.0]


def analyze_pcm(samples: np.ndarray, sample_rate: int) -> SpectrumVerdict:
    if sample_rate <= 0:
        raise ValueError("sample rate must be positive")
    mono = np.asarray(samples, dtype=np.float64)
    if mono.ndim > 1:
        mono = mono.mean(axis=1)
    if mono.size < WINDOW_SIZE:
        raise ValueError("not enough samples for spectral analysis")

    window = np.blackman(WINDOW_SIZE)
    acc = np.zeros(WINDOW_SIZE // 2 + 1, dtype=np.float64)
    count = 0
    for start in range(0, mono.size - WINDOW_SIZE + 1, HOP_SIZE):
        frame = mono[start : start + WINDOW_SIZE] * window
        spectrum = np.fft.rfft(frame)
        acc += np.abs(spectrum) ** 2
        count += 1
        if count >= MAX_WINDOWS:
            break
    if count == 0:
        raise ValueError("not enough samples for spectral analysis")
    acc /= count
    peak = float(acc.max())
    if peak <= 0:
        raise ValueError("audio is silent")

    rel_db = 10.0 * np.log10(acc / peak + 1e-20)
    freqs = np.fft.rfftfreq(WINDOW_SIZE, 1.0 / sample_rate)
    above = np.where(rel_db >= PEAK_RELATIVE_DB)[0]
    cutoff = float(freqs[int(above[-1])]) if above.size else 0.0

    hf_db: float | None = None
    fake_hires = False
    if sample_rate > HIRES_MIN_RATE:
        hf = acc[freqs >= HF_BAND_HZ]
        hf_db = (
            float(10.0 * np.log10(float(hf.mean()) / peak + 1e-20)) if hf.size else -120.0
        )
        fake_hires = cutoff <= CD_WALL_HZ and hf_db <= HF_EMPTY_DB

    lossy = (not fake_hires) and sample_rate <= HIRES_MIN_RATE and cutoff < LOSSY_CUTOFF_HZ
    return SpectrumVerdict(
        cutoff_hz=round(cutoff, 1),
        sample_rate=sample_rate,
        hf_extension_db=None if hf_db is None else round(hf_db, 1),
        lossy_transcode=lossy,
        fake_hires=fake_hires,
    )


def decode_segments(path: Path, duration_seconds: int | None) -> tuple[np.ndarray, int]:
    starts = segment_starts(duration_seconds)
    suffix = path.suffix.lower()
    if suffix in {".wav", ".wave"}:
        chunks, rate = _decode_wav_segments(path, starts)
        return np.concatenate(chunks), rate
    if not ffmpeg_available():
        raise DeepDecodeError(
            "ffmpeg is not available for non-WAV files",
            code="decode_failed",
        )
    chunks, rate = _decode_ffmpeg_segments(path, starts)
    return np.concatenate(chunks), rate


def _decode_wav_segments(path: Path, starts: list[float]) -> tuple[list[np.ndarray], int]:
    with wave.open(str(path), "rb") as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        total = handle.getnframes()
        if rate <= 0 or channels <= 0 or width not in {1, 2, 4}:
            raise DeepDecodeError("unsupported WAV format", code="unsupported_format")
        chunks: list[np.ndarray] = []
        for start in starts:
            frame = min(max(0, int(start * rate)), max(0, total - 1))
            count = min(int(SEGMENT_SECONDS * rate), max(0, total - frame))
            if count < WINDOW_SIZE:
                continue
            handle.setpos(frame)
            raw = handle.readframes(count)
            samples = _pcm_to_mono(raw, channels, width)
            if samples.size >= WINDOW_SIZE:
                chunks.append(samples)
        if not chunks:
            raise DeepDecodeError("WAV file is too short to analyze", code="too_short")
        return chunks, rate


def _pcm_to_mono(raw: bytes, channels: int, width: int) -> np.ndarray:
    if width == 1:
        data = np.frombuffer(raw, dtype=np.uint8).astype(np.float64)
        data = (data - 128.0) / 128.0
    elif width == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    else:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
    if channels > 1:
        usable = (data.size // channels) * channels
        data = data[:usable].reshape(-1, channels).mean(axis=1)
    return data


def _decode_ffmpeg_segments(path: Path, starts: list[float]) -> tuple[list[np.ndarray], int]:
    rate = _probe_sample_rate(path)
    chunks: list[np.ndarray] = []
    for start in starts:
        command = [
            "ffmpeg",
            "-v",
            "error",
            "-ss",
            f"{start:.3f}",
            "-t",
            str(SEGMENT_SECONDS),
            "-i",
            str(path),
            "-ac",
            "1",
            "-f",
            "f32le",
            "pipe:1",
        ]
        try:
            completed = subprocess.run(
                command,
                check=True,
                capture_output=True,
                timeout=30,
            )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as exc:
            raise DeepDecodeError("ffmpeg could not decode audio") from exc
        samples = np.frombuffer(completed.stdout, dtype="<f4").astype(np.float64)
        if samples.size >= WINDOW_SIZE:
            chunks.append(samples)
    if not chunks:
        raise DeepDecodeError("decoded audio is too short to analyze", code="too_short")
    return chunks, rate


def parse_ffprobe_sample_rate(raw: str) -> int:
    """Read the first numeric sample-rate token from ffprobe csv output.

    Cover-art / side-data streams can produce values like ``44100,``.
    """
    line = (raw or "").strip().splitlines()[0] if raw and raw.strip() else ""
    token = line.split(",")[0].strip()
    try:
        rate = int(float(token))
    except (TypeError, ValueError) as exc:
        raise DeepDecodeError(
            "ffprobe returned an invalid sample rate",
            code="invalid_sample_rate",
        ) from exc
    if rate <= 0:
        raise DeepDecodeError(
            "ffprobe returned an invalid sample rate",
            code="invalid_sample_rate",
        )
    return rate


def _probe_sample_rate(path: Path) -> int:
    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "stream=sample_rate",
        "-of",
        "csv=p=0",
        str(path),
    ]
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as exc:
        raise DeepDecodeError(
            "ffprobe could not read sample rate",
            code="invalid_sample_rate",
        ) from exc
    return parse_ffprobe_sample_rate(completed.stdout)


def analyze_file(path: Path, duration_seconds: int | None) -> SpectrumVerdict:
    samples, rate = decode_segments(path, duration_seconds)
    try:
        return analyze_pcm(samples, rate)
    except ValueError as exc:
        raise DeepDecodeError(str(exc), code="too_short") from exc
