"""Generate the game's sound effects as 16-bit mono WAV (numpy + wave, no external services).

Run from the project root:  python tools/gen_sfx.py
Writes swing.wav, hurt.wav, pickup.wav, explosion.wav to assets/Audio/.
(The folder already exists as "Audio"; res:// paths are case-sensitive outside Windows.)
"""
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "Audio"
RNG = np.random.default_rng(6)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n: int, attack: float, release_curve: float) -> np.ndarray:
    """Short linear attack, then exponential-ish release to zero."""
    a = max(1, int(RATE * attack))
    env = np.ones(n)
    env[:a] = np.linspace(0.0, 1.0, a)
    env[a:] = np.linspace(1.0, 0.0, n - a) ** release_curve
    return env


def lowpass(x: np.ndarray, cutoff: np.ndarray | float) -> np.ndarray:
    """One-pole low-pass; cutoff may vary per sample (Hz)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, (s, a) in enumerate(zip(x, alpha)):
        acc += a * (s - acc)
        y[i] = acc
    return y


def swing() -> np.ndarray:
    t = t_axis(0.22)
    noise = RNG.uniform(-1, 1, t.size)
    # band-limited whoosh: cutoff sweeps up then down
    sweep = 600 + 3400 * np.sin(np.pi * t / t[-1])
    body = lowpass(noise, sweep) - lowpass(noise, 250)
    return body * envelope(t.size, 0.02, 1.6) * 2.2


def hurt() -> np.ndarray:
    t = t_axis(0.3)
    freq = 420 * np.exp(-3.5 * t)  # falling pitch
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    square = np.sign(np.sin(phase)) * 0.6 + np.sin(phase * 0.5) * 0.4
    return lowpass(square, 2500) * envelope(t.size, 0.005, 1.4)


def pickup() -> np.ndarray:
    notes = [(784.0, 0.07), (1175.0, 0.16)]  # G5 -> D6
    parts = []
    for freq, dur in notes:
        t = t_axis(dur)
        tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)
        parts.append(tone * envelope(t.size, 0.004, 1.2))
    return np.concatenate(parts) * 0.8


def explosion() -> np.ndarray:
    t = t_axis(1.1)
    noise = RNG.uniform(-1, 1, t.size)
    crack = lowpass(noise, 4000 * np.exp(-6 * t) + 200)
    rumble = lowpass(noise, 120) * 4.0
    boom = np.sin(2 * np.pi * 55 * np.exp(-1.5 * t) * t) * np.exp(-4 * t)
    return (crack + rumble + boom) * envelope(t.size, 0.003, 2.2)


def write(name: str, signal: np.ndarray) -> None:
    peak = np.max(np.abs(signal))
    data = (signal / peak * 0.9 * 32767).astype("<i2") if peak > 0 else signal.astype("<i2")
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(data.tobytes())
    print(f"{name}: {data.size / RATE:.2f} s")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write("swing.wav", swing())
    write("hurt.wav", hurt())
    write("pickup.wav", pickup())
    write("explosion.wav", explosion())


if __name__ == "__main__":
    main()
