#!/usr/bin/env python3
"""Synthesise EchoSteps' sound effects into assets/audio/sfx/.

Everything is soft and rounded (sine bells, water droplets, a warm pad) with
gentle attacks: nothing that could startle a sound-sensitive child.
"""
import pathlib
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"


def env(n, attack=0.005, decay=None):
    t = np.arange(n) / SR
    a = np.minimum(1, t / attack)
    d = np.exp(-t / decay) if decay else np.ones(n)
    return a * d


def bell(freq, dur, decay, partials=((1, 1), (2.0, 0.25), (3.0, 0.08)), attack=0.008):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = sum(amp * np.sin(2 * np.pi * freq * m * t) for m, amp in partials)
    return y * env(n, attack=attack, decay=decay)


def place(total, parts):
    y = np.zeros(int(total * SR))
    for start, sig in parts:
        i = int(start * SR)
        y[i:i + len(sig)] += sig[:len(y) - i]
    return y


def save(name, y, peak=0.5, fade_out=True):
    y = y / (np.abs(y).max() + 1e-9) * peak
    if fade_out:
        fade = int(0.012 * SR)
        y[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # pop: tiny soft bubble (tap feedback)
    n = int(0.11 * SR)
    t = np.arange(n) / SR
    f = 520 + 700 * np.exp(-t / 0.02)
    save("pop", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.004, 0.03), 0.4)

    # droplet: water drop, a quick upward pitch sweep
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 700 + 900 * (1 - np.exp(-t / 0.03))
    save("droplet", np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.003, 0.05), 0.4)

    # chime: two soft bells (E6, B6)
    save("chime", place(1.5, [(0, bell(1318.5, 1.5, 0.4)), (0.14, bell(1975.5, 1.3, 0.35))]), 0.42)

    # bloom: gentle major arpeggio C5 E5 G5 C6 E6 for a flower blooming
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    save("bloom", place(2.4, [(i * 0.16, bell(fq, 1.8, 0.5)) for i, fq in enumerate(notes)]), 0.45)

    # sparkle: soft rising glints (card unlocked)
    save("sparkle", place(1.0, [(i * 0.07, bell(1200 * 1.1 ** i, 0.5, 0.09)) for i in range(7)]), 0.35)

    # wake: Milo waking, a slow warm two-note rise (G4 -> D5), soft attack
    save("wake", place(1.2, [(0, bell(392, 1.0, 0.45, attack=0.04)), (0.22, bell(587.3, 0.95, 0.4, attack=0.04))]), 0.4)

    # pad_loop: 16 s warm ambient pad (Cmaj9-ish), seamless loop
    dur = 16.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    pad = np.zeros(n)
    for fq, amp in [(130.81, 1), (196.0, 0.7), (246.94, 0.45), (293.66, 0.4), (329.63, 0.3)]:
        # Whole cycles per loop (and a tremolo whose period divides the loop)
        # make the loop point seamless.
        fq = round(fq * dur) / dur
        trem = 0.75 + 0.25 * np.sin(2 * np.pi * t / (dur / 2) + fq)
        pad += amp * trem * (np.sin(2 * np.pi * fq * t) + 0.15 * np.sin(2 * np.pi * 2 * fq * t))
    save("pad_loop", pad, 0.3, fade_out=False)
    print("sfx written to", OUT)


if __name__ == "__main__":
    main()
