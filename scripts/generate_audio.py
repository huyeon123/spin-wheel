#!/usr/bin/env python3
"""Reproduce Spin Wheel's original, sample-free sound effects.

Uses only the Python standard library. Run from any directory:
    python3 scripts/generate_audio.py
    python3 scripts/generate_audio.py --check

The app gets two mono PCM16 / 22,050 Hz WAVs. A listening preview and measured
PCM statistics go into build/audio-preview, never assets. See AUDIO-LICENSE.txt.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave


ROOT = Path(__file__).resolve().parents[1]
RATE = 22_050
TAU = 2.0 * math.pi


def frames(duration: float) -> int:
    return round(duration * RATE)


def fade_edges(samples: list[float], attack: float, release: float) -> list[float]:
    """Cosine ramps leave both endpoints exactly silent and prevent hard cuts."""
    count = len(samples)
    attack_frames = max(1, frames(attack))
    release_frames = max(1, frames(release))
    output = []
    for i, sample in enumerate(samples):
        fade_in = 0.5 - 0.5 * math.cos(math.pi * min(1.0, i / attack_frames))
        fade_out = 0.5 - 0.5 * math.cos(
            math.pi * min(1.0, (count - 1 - i) / release_frames)
        )
        output.append(sample * fade_in * fade_out)
    return output


def normalize(samples: list[float], peak: float) -> list[float]:
    maximum = max(abs(sample) for sample in samples)
    return [sample * peak / maximum for sample in samples]


def balance_dc(samples: list[float]) -> list[float]:
    """Remove residual DC without changing the silent endpoints."""
    window = [math.sin(math.pi * i / (len(samples) - 1)) ** 2 for i in range(len(samples))]
    correction = sum(samples) / sum(window)
    return [sample - correction * weight for sample, weight in zip(samples, window)]


def tick() -> list[float]:
    """A tiny dry wood/ratchet double impact; no sustained beep or reverb."""
    rng = random.Random(20261018)
    output = [0.0] * frames(0.032)
    for offset, strength in ((0.0, 1.0), (0.0072, 0.24)):
        start = frames(offset)
        previous_noise = 0.0
        for i in range(len(output) - start):
            t = i / RATE
            noise = rng.uniform(-1.0, 1.0)
            # A differenced noise transient adds the mechanical click, while
            # damped resonators keep its body warmer than a sharp digital pop.
            transient = (noise - previous_noise) * 0.25 * math.exp(-t / 0.0016)
            previous_noise = noise
            body = (
                0.68 * math.sin(TAU * 1180 * t) * math.exp(-t / 0.0035)
                + 0.25 * math.sin(TAU * 2360 * t) * math.exp(-t / 0.0022)
                + 0.17 * math.sin(TAU * 610 * t) * math.exp(-t / 0.0044)
            )
            # Sub-millisecond onset avoids an arbitrary non-zero first sample.
            onset = min(1.0, t / 0.00023)
            output[start + i] += strength * onset * (body + transient)
    return normalize(balance_dc(fade_edges(output, 0.00018, 0.005)), 0.33)


def tone(frequency: float, duration: float) -> list[float]:
    """Bright, rounded additive mallet/brass voice, with a gentle release."""
    output = []
    for i in range(frames(duration)):
        t = i / RATE
        sound = (
            math.sin(TAU * frequency * t)
            + 0.30 * math.sin(TAU * frequency * 2 * t) * math.exp(-t / 0.12)
            + 0.12 * math.sin(TAU * frequency * 3 * t) * math.exp(-t / 0.09)
            + 0.045 * math.sin(TAU * frequency * 4 * t) * math.exp(-t / 0.07)
        )
        output.append(sound * math.exp(-t / (duration * 0.47)))
    return fade_edges(output, 0.003, min(0.10, duration * 0.35))


def mix_at(target: list[float], source: list[float], time: float, gain: float = 1.0) -> None:
    start = frames(time)
    for i, sample in enumerate(source):
        if start + i >= len(target):
            break
        target[start + i] += sample * gain


def midi_pitch(note: int) -> float:
    return 440 * 2 ** ((note - 69) / 12)


def victory() -> list[float]:
    """Original C-major upward flourish, followed by a compact major chord."""
    output = [0.0] * frames(1.24)
    # C5-E5-G5-C6: rhythmically spaced notes make the short cue feel celebratory.
    for at, note, duration, gain in (
        (0.000, 72, 0.15, 0.67),
        (0.105, 76, 0.16, 0.70),
        (0.210, 79, 0.18, 0.74),
        (0.335, 84, 0.24, 0.79),
    ):
        mix_at(output, tone(midi_pitch(note), duration), at, gain)
    # A wider low-to-high resolution keeps the sound substantial on a phone.
    for note, gain in ((60, 0.28), (72, 0.52), (76, 0.39), (79, 0.40), (84, 0.65)):
        mix_at(output, tone(midi_pitch(note), 0.70), 0.51, gain)
    mix_at(output, tone(midi_pitch(91), 0.30), 0.57, 0.11)
    return normalize(fade_edges(output, 0.001, 0.06), 0.45)


def audition(click: list[float], fanfare: list[float]) -> list[float]:
    """Preview a 5 s spin: speed up briefly, then ratchet down to the landing."""
    spin_start, spin_duration = 0.25, 5.0
    output = [0.0] * frames(spin_start + spin_duration + len(fanfare) / RATE + 0.25)
    angular_progress = 0.0
    next_tooth = 0
    for i in range(frames(spin_duration)):
        t = i / RATE
        if t < 0.55:
            rate = 8 + 24 * (t / 0.55)
        else:
            fraction_left = max(0.0, (spin_duration - t) / (spin_duration - 0.55))
            rate = 0.6 + 31.4 * fraction_left ** 1.55
        angular_progress += rate / RATE
        if angular_progress >= next_tooth:
            mix_at(output, click, spin_start + t)
            next_tooth += 1
    mix_at(output, fanfare, spin_start + spin_duration)
    assert max(abs(sample) for sample in output) < 1.0
    return output


def pcm16(samples: list[float]) -> bytes:
    assert max(abs(sample) for sample in samples) < 1.0, "Audio would clip"
    return b"".join(struct.pack("<h", round(sample * 32767)) for sample in samples)


def write_wav(path: Path, pcm: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)


def measure(path: Path) -> dict:
    with wave.open(str(path), "rb") as wav:
        assert wav.getnchannels() == 1 and wav.getsampwidth() == 2
        assert wav.getframerate() == RATE
        data = wav.readframes(wav.getnframes())
        samples = [sample[0] / 32768 for sample in struct.iter_unpack("<h", data)]
    peak = max(abs(sample) for sample in samples)
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    dc = sum(samples) / len(samples)
    assert peak < 0.50, f"Insufficient headroom: {path}"
    assert abs(dc) < 0.0001, f"Excess DC offset: {path}"
    assert samples[0] == samples[-1] == 0.0, f"Hard audio edge: {path}"
    return {
        "file": str(path.relative_to(ROOT)),
        "sample_rate_hz": RATE,
        "channels": 1,
        "bits_per_sample": 16,
        "duration_seconds": round(len(samples) / RATE, 6),
        "peak_linear": round(peak, 6),
        "peak_dbfs": round(20 * math.log10(peak), 2),
        "rms_linear": round(rms, 6),
        "rms_dbfs": round(20 * math.log10(rms), 2),
        "dc_offset": round(dc, 8),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify existing WAVs match the generator")
    args = parser.parse_args()
    click, fanfare = tick(), victory()
    sounds = {
        ROOT / "assets/spin.wav": click,
        ROOT / "assets/victory.wav": fanfare,
        ROOT / "build/audio-preview/roulette-audition.wav": audition(click, fanfare),
    }
    report = []
    for path, samples in sounds.items():
        if args.check and "build" in path.relative_to(ROOT).parts and not path.exists():
            continue  # Audition is optional; shipped assets are always checked.
        pcm = pcm16(samples)
        if args.check:
            with wave.open(str(path), "rb") as existing:
                assert existing.readframes(existing.getnframes()) == pcm, f"Different PCM data: {path}"
        else:
            write_wav(path, pcm)
        report.append(measure(path))
    summary = json.dumps(report, indent=2) + "\n"
    if not args.check:
        (ROOT / "build/audio-preview/measurements.json").write_text(summary, encoding="utf-8")
    print(summary, end="")


if __name__ == "__main__":
    main()
