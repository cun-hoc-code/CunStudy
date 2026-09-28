#!/usr/bin/env python3
"""Generate tiny original interaction sounds; no downloaded or copyrighted audio."""
from pathlib import Path
import math
import random
import wave

RATE = 22_050
OUT = Path(__file__).resolve().parents[1] / "Resources" / "Sounds"
OUT.mkdir(parents=True, exist_ok=True)


def save(name, duration, sample):
    frames = bytearray()
    count = int(RATE * duration)
    for index in range(count):
        value = max(-1.0, min(1.0, sample(index / RATE, index, count)))
        frames += int(value * 32767).to_bytes(2, "little", signed=True)
    with wave.open(str(OUT / f"feedback-{name}.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(frames)


def envelope(index, count, power=2.2):
    attack = min(1.0, index / max(1, RATE * 0.004))
    return attack * (1.0 - index / count) ** power


save(
    "tap", 0.038,
    lambda t, i, n: envelope(i, n, 2.8)
    * (0.20 * math.sin(2 * math.pi * 630 * t) + 0.07 * math.sin(2 * math.pi * 390 * t)),
)
save(
    "selection", 0.065,
    lambda t, i, n: envelope(i, n, 2.5)
    * (0.17 * math.sin(2 * math.pi * (470 + 480 * t) * t)),
)

paper_random = random.Random(2107)
paper_noise = [paper_random.uniform(-1, 1) for _ in range(int(RATE * 0.22))]


def page_sample(t, index, count):
    sweep = math.sin(2 * math.pi * (180 + 760 * t) * t) * 0.055
    noise = paper_noise[index] * 0.10
    return envelope(index, count, 1.45) * (sweep + noise)


save("page", 0.22, page_sample)


def success_sample(t, index, count):
    first = math.sin(2 * math.pi * 523.25 * t)
    second_t = max(0.0, t - 0.075)
    second = math.sin(2 * math.pi * 659.25 * second_t) if t >= 0.075 else 0
    return envelope(index, count, 1.9) * (first * 0.12 + second * 0.16)


save("success", 0.19, success_sample)
print("Generated 4 original feedback sounds in", OUT)
