#!/usr/bin/env python3
"""Συνθέτει τους ενσωματωμένους προεπιλεγμένους ήχους (WAV, mono, 16-bit).

Χρήση (από τη ρίζα του project):
    python3 tools/generate_demo_sounds.py

Μόνο standard library. Τα αρχεία είναι ήδη στο repo· το script χρειάζεται
μόνο για να τα ξαναφτιάξεις ή να τα αλλάξεις.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 22050


def note(n):
    """Συχνότητα από MIDI νότα."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env(t, dur, a=0.005, r=0.08):
    if t < a:
        return t / a
    if t > dur - r:
        return max(0.0, (dur - t) / r)
    return 1.0


def tone(freq, dur, vol=0.5, shape="sine", decay=0.0, a=0.005, r=0.08, vibrato=0.0):
    out = []
    n = int(dur * RATE)
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5.5 * t))
        ph += 2 * math.pi * f / RATE
        if shape == "sine":
            s = math.sin(ph)
        elif shape == "tri":
            s = 2 / math.pi * math.asin(math.sin(ph))
        elif shape == "square":
            s = 0.6 * (1 if math.sin(ph) >= 0 else -1)
        else:
            s = math.sin(ph) + 0.3 * math.sin(2 * ph) + 0.15 * math.sin(3 * ph)
        g = env(t, dur, a, r) * (math.exp(-decay * t) if decay else 1.0)
        out.append(s * g * vol)
    return out


def mix(buf, part, at):
    start = int(at * RATE)
    need = start + len(part)
    if len(buf) < need:
        buf.extend([0.0] * (need - len(buf)))
    for i, v in enumerate(part):
        buf[start + i] += v


def save(name, buf, peak=0.85):
    m = max(1e-9, max(abs(v) for v in buf))
    k = min(1.0, peak / m) if m > peak else 1.0
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * k)) * 32767)) for v in buf))


def countdown():
    buf = []
    mix(buf, tone(note(81), 0.16, 0.6, "tri", decay=12, r=0.05), 0)
    mix(buf, tone(note(93), 0.10, 0.15, "sine", decay=20, r=0.05), 0)
    return buf


def stop():
    buf = []
    # «Κλακ»: σύντομος θόρυβος + χαμηλός τόνος με γρήγορη πτώση συχνότητας.
    rnd = random.Random(3)
    n = int(0.03 * RATE)
    mix(buf, [rnd.uniform(-1, 1) * 0.5 * (1 - i / n) ** 2 for i in range(n)], 0)
    out = []
    ph = 0.0
    dur = 0.18
    for i in range(int(dur * RATE)):
        t = i / RATE
        f = 220 * math.exp(-t * 14) + 70
        ph += 2 * math.pi * f / RATE
        out.append(math.sin(ph) * 0.8 * math.exp(-t * 22))
    mix(buf, out, 0)
    return buf


def win():
    buf = []
    seq = [72, 76, 79, 84]
    for i, n in enumerate(seq):
        mix(buf, tone(note(n), 0.22, 0.45, "rich", decay=4, r=0.06), i * 0.09)
    mix(buf, tone(note(84), 0.9, 0.35, "rich", decay=2.5, r=0.3, vibrato=0.004), 0.36)
    mix(buf, tone(note(88), 0.9, 0.25, "sine", decay=2.5, r=0.3), 0.36)
    mix(buf, tone(note(91), 0.9, 0.2, "sine", decay=2.5, r=0.3), 0.36)
    # λαμπύρισμα
    rnd = random.Random(7)
    for k in range(10):
        mix(buf, tone(note(rnd.choice([96, 100, 103, 108])), 0.08, 0.10, "sine", decay=30, r=0.03),
            0.4 + k * 0.06)
    return buf


def lose():
    buf = []
    mix(buf, tone(note(67), 0.30, 0.45, "tri", r=0.08, vibrato=0.01), 0.0)
    out = []
    ph = 0.0
    dur = 0.7
    for i in range(int(dur * RATE)):
        t = i / RATE
        f = note(62) * (1 - 0.06 * t / dur) * (1 + 0.012 * math.sin(2 * math.pi * 6 * t))
        ph += 2 * math.pi * f / RATE
        out.append(2 / math.pi * math.asin(math.sin(ph)) * 0.45 * env(t, dur, 0.01, 0.25))
    mix(buf, out, 0.32)
    return buf


def music():
    """Ήρεμο, χαρούμενο loop: 8 μέτρα 4/4 στα 112 BPM (C – Am – F – G)."""
    bpm = 112
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    buf = [0.0] * int(total * RATE)
    chords = [(60, 64, 67), (57, 60, 64), (53, 57, 60), (55, 59, 62)] * 2
    rnd = random.Random(1)
    melody_pool = [72, 74, 76, 79, 81, 84]
    for b, chord in enumerate(chords):
        t0 = b * 4 * beat
        # μπάσο σε κάθε χτύπο
        for k in range(4):
            mix(buf, tone(note(chord[0] - 12), beat * 0.9, 0.30, "tri", decay=2.0, r=0.05), t0 + k * beat)
        # αρπέζ σε όγδοα
        for k in range(8):
            n = chord[k % 3] + (12 if k >= 4 else 0)
            mix(buf, tone(note(n), beat * 0.45, 0.10, "sine", decay=5, r=0.04), t0 + k * beat / 2)
        # απλή μελωδία
        if b % 2 == 0:
            for k in range(3):
                n = rnd.choice([m for m in melody_pool if (m % 12) in [c % 12 for c in chord]] or melody_pool)
                mix(buf, tone(note(n), beat * 0.9, 0.12, "rich", decay=2.5, r=0.1), t0 + k * beat * 1.333)
        # hi-hat
        for k in range(8):
            n = int(0.03 * RATE)
            hat = [rnd.uniform(-1, 1) * 0.05 * (1 - i / n) ** 3 for i in range(n)]
            mix(buf, hat, t0 + k * beat / 2 + beat / 4)
    # Ό,τι «ουρά» ξεπερνά το τέλος προστίθεται στην αρχή ⇒ αδιάκοπο loop.
    n = int(total * RATE)
    for i, v in enumerate(buf[n:]):
        buf[i % n] += v
    return buf[:n]


def main():
    save("countdown.wav", countdown())
    save("stop.wav", stop())
    save("win.wav", win())
    save("lose.wav", lose())
    save("music.wav", music(), peak=0.6)
    print("OK:", OUT)


if __name__ == "__main__":
    main()
