#!/usr/bin/env python3
"""Δημιουργεί τα εικονίδια εφαρμογής (Windows/Android) σε PNG.

Χρήση: python3 tools/generate_icons.py   (απαιτεί Pillow)
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icon")
SS = 4
BG_TOP, BG_BOTTOM = (50, 60, 130), (90, 42, 110)


def star(cx, cy, ro, ri):
    pts = []
    for i in range(10):
        r = ro if i % 2 == 0 else ri
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def gradient(size):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)) + (255,))
    return img


def glyph(size, scale=1.0):
    """Δακτύλιος-στόχος με χρυσό αστέρι, σε διάφανο φόντο."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    r = s * 0.36 * scale
    w = s * 0.055 * scale
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=int(w))
    d.polygon(star(c, c + s * 0.012 * scale, s * 0.25 * scale, s * 0.105 * scale), fill=(255, 205, 50, 255))
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    # Κύριο εικονίδιο (Windows, Android legacy): στρογγυλεμένο τετράγωνο.
    size = 1024
    base = gradient(size)
    mask = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius=int(size * SS * 0.2), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(base, (0, 0), mask)
    icon.alpha_composite(glyph(size))
    icon.save(os.path.join(OUT, "icon_1024.png"))
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "android_192.png"))
    # Android adaptive: το περιεχόμενο πρέπει να χωρά στο κεντρικό 66% (safe zone).
    glyph(432, 0.62).save(os.path.join(OUT, "android_foreground_432.png"))
    gradient(432).save(os.path.join(OUT, "android_background_432.png"))
    print("OK:", OUT)


if __name__ == "__main__":
    main()
