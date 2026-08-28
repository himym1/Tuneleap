import math
import wave
from pathlib import Path

import numpy as np

import pytest

from app.services.library_audit_spectrum import (
    DeepDecodeError,
    analyze_file,
    analyze_pcm,
    parse_ffprobe_sample_rate,
)


def _harmonics(sample_rate: int, seconds: float, max_hz: int) -> np.ndarray:
    n = int(sample_rate * seconds)
    freqs = list(range(200, max_hz, 250))
    t = np.arange(n) / sample_rate
    signal = np.zeros(n, dtype=np.float64)
    for freq in freqs:
        signal += np.sin(2 * math.pi * freq * t)
    return signal / max(1, len(freqs))


def _write_wav(path: Path, sample_rate: int, samples: np.ndarray) -> None:
    clipped = np.clip(samples, -1.0, 1.0)
    frames = (clipped * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(frames)


def test_analyze_pcm_detects_lossy_cutoff():
    lossy = analyze_pcm(_harmonics(44100, 3, 16000), 44100)
    genuine = analyze_pcm(_harmonics(44100, 3, 21000), 44100)
    assert lossy.lossy_transcode is True
    assert lossy.cutoff_hz < 18500
    assert genuine.lossy_transcode is False
    assert genuine.cutoff_hz >= 18500


def test_analyze_pcm_detects_fake_hires():
    fake = analyze_pcm(_harmonics(96000, 3, 20000), 96000)
    assert fake.fake_hires is True
    assert fake.lossy_transcode is False
    assert fake.hf_extension_db is not None
    assert fake.hf_extension_db <= -70


def test_parse_ffprobe_sample_rate_ignores_trailing_csv_fields():
    assert parse_ffprobe_sample_rate("44100,\n") == 44100
    assert parse_ffprobe_sample_rate("48000\n") == 48000
    with pytest.raises(DeepDecodeError) as first:
        parse_ffprobe_sample_rate("0\n")
    assert first.value.code == "invalid_sample_rate"
    with pytest.raises(DeepDecodeError) as second:
        parse_ffprobe_sample_rate("")
    assert second.value.code == "invalid_sample_rate"


def test_analyze_wav_file(tmp_path: Path):
    path = tmp_path / "lossy.wav"
    _write_wav(path, 44100, _harmonics(44100, 3, 15000))
    verdict = analyze_file(path, 3)
    assert verdict.lossy_transcode is True
