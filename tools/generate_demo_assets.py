#!/usr/bin/env python3
"""Δημιουργεί τα placeholder γραφικά του demo θέματος (εικονίδια + popups).

Χρήση (από τη ρίζα του project):
    python3 tools/generate_demo_assets.py

Απαιτεί Pillow. Τα αρχεία που παράγονται είναι ήδη commit-αρισμένα στο repo,
οπότε το script χρειάζεται μόνο αν θέλεις να τα ξαναφτιάξεις.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "assets", "demo", "icons")
POPUP_DIR = os.path.join(ROOT, "assets", "demo", "popups")
FONT_BOLD = os.path.join(ROOT, "assets", "fonts", "DejaVuSans-Bold.ttf")

SS = 2  # supersampling για ομαλές άκρες
ICON = 512

# id, όνομα, χρώμα badge (πάνω, κάτω), σχήμα
ICONS = [
    ("star", "Αστέρι", ((255, 214, 64), (245, 150, 20)), "star"),
    ("heart", "Καρδιά", ((255, 105, 130), (220, 30, 75)), "heart"),
    ("moon", "Φεγγάρι", ((120, 150, 255), (60, 70, 200)), "moon"),
    ("sun", "Ήλιος", ((255, 170, 80), (240, 95, 30)), "sun"),
    ("clover", "Τριφύλλι", ((120, 220, 120), (30, 150, 70)), "clover"),
    ("diamond", "Διαμάντι", ((110, 235, 240), (20, 160, 200)), "diamond"),
    ("drop", "Σταγόνα", ((110, 200, 255), (30, 110, 220)), "drop"),
    ("bolt", "Κεραυνός", ((200, 140, 255), (120, 50, 210)), "bolt"),
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        c = lerp(top, bottom, y / max(1, h - 1))
        d.line([(0, y), (w, y)], fill=c + (255,))
    return img


def star_points(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_glyph(d, shape, s, color):
    """Ζωγραφίζει το λευκό σύμβολο στο κέντρο ενός καμβά πλευράς s."""
    c = s / 2
    if shape == "star":
        d.polygon(star_points(c, c * 1.04, s * 0.30, s * 0.13), fill=color)
    elif shape == "heart":
        r = s * 0.115
        d.ellipse([c - 1.95 * r, c - 1.6 * r, c + 0.05 * r, c + 0.4 * r], fill=color)
        d.ellipse([c - 0.05 * r, c - 1.6 * r, c + 1.95 * r, c + 0.4 * r], fill=color)
        d.polygon([(c - 1.93 * r, c - 0.25 * r), (c + 1.93 * r, c - 0.25 * r), (c, c + 2.3 * r)], fill=color)
    elif shape == "moon":
        r = s * 0.24
        d.ellipse([c - r, c - r, c + r, c + r], fill=color)
        d.ellipse([c - r * 0.45, c - r * 1.15, c + r * 1.45, c + r * 0.75], fill=(0, 0, 0, 0))
    elif shape == "sun":
        r = s * 0.13
        d.ellipse([c - r, c - r, c + r, c + r], fill=color)
        for i in range(10):
            a = i * math.pi / 5
            x1, y1 = c + math.cos(a) * r * 1.45, c + math.sin(a) * r * 1.45
            x2, y2 = c + math.cos(a) * r * 2.25, c + math.sin(a) * r * 2.25
            d.line([(x1, y1), (x2, y2)], fill=color, width=int(s * 0.035))
    elif shape == "clover":
        r = s * 0.10
        for a in (-math.pi / 2, math.pi / 6, 5 * math.pi / 6):
            x, y = c + math.cos(a) * r * 1.05, c - s * 0.03 + math.sin(a) * r * 1.05
            d.ellipse([x - r, y - r, x + r, y + r], fill=color)
        d.line([(c, c + r * 0.4), (c + r * 0.6, c + r * 2.6)], fill=color, width=int(s * 0.035))
    elif shape == "diamond":
        w, h = s * 0.27, s * 0.30
        top = c - h * 0.55
        d.polygon([(c - w, top + h * 0.3), (c - w * 0.55, top), (c + w * 0.55, top), (c + w, top + h * 0.3),
                   (c, top + h * 1.15)], fill=color)
    elif shape == "drop":
        r = s * 0.17
        d.ellipse([c - r, c - r * 0.55, c + r, c + r * 1.45], fill=color)
        d.polygon([(c - r * 0.93, c + r * 0.15), (c + r * 0.93, c + r * 0.15), (c, c - r * 1.75)], fill=color)
    elif shape == "bolt":
        k = s * 0.30
        pts = [(0.15, -1.0), (-0.55, 0.12), (-0.02, 0.12), (-0.2, 1.0), (0.55, -0.15), (0.02, -0.15)]
        d.polygon([(c + x * k, c + y * k) for x, y in pts], fill=color)


def make_icon(shape, top, bottom):
    s = ICON * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    # μαλακή σκιά
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([s * 0.07, s * 0.10, s * 0.93, s * 0.96], fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.025))
    img.alpha_composite(shadow)
    # badge με διαβάθμιση
    grad = vertical_gradient((s, s), top, bottom)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([s * 0.06, s * 0.05, s * 0.94, s * 0.93], fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    # λευκό περίγραμμα και γυαλάδα
    d.ellipse([s * 0.06, s * 0.05, s * 0.94, s * 0.93], outline=(255, 255, 255, 235), width=int(s * 0.025))
    gloss = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).ellipse([s * 0.18, s * 0.10, s * 0.82, s * 0.45], fill=(255, 255, 255, 60))
    img.alpha_composite(gloss.filter(ImageFilter.GaussianBlur(s * 0.02)))
    # σύμβολο (με το κόψιμο του φεγγαριού να γίνεται σε ξεχωριστό layer)
    glyph = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glyph)
    draw_glyph(gd, shape, s, (255, 255, 255, 255))
    gshadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gshadow.paste((0, 0, 0, 90), (0, 0), glyph.split()[3])
    gshadow = gshadow.filter(ImageFilter.GaussianBlur(s * 0.01))
    img.alpha_composite(gshadow, (0, int(s * 0.012)))
    img.alpha_composite(glyph)
    return img.resize((ICON, ICON), Image.LANCZOS)


def rounded_card(size, radius, top, bottom):
    w, h = size
    card = vertical_gradient(size, top, bottom)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(card, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle([6, 6, w - 7, h - 7], radius=radius - 6,
                                          outline=(255, 255, 255, 200), width=8)
    return out


def centered_text(d, w, y, text, size, fill):
    font = ImageFont.truetype(FONT_BOLD, size)
    # αυτόματη σμίκρυνση αν δε χωράει
    while d.textlength(text, font=font) > w * 0.88 and size > 20:
        size -= 4
        font = ImageFont.truetype(FONT_BOLD, size)
    tw = d.textlength(text, font=font)
    d.text(((w - tw) / 2 + 4, y + 5), text, font=font, fill=(0, 0, 0, 90))
    d.text(((w - tw) / 2, y), text, font=font, fill=fill)


def confetti(img, seed, count=70):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    w, h = img.size
    palette = [(255, 214, 64), (255, 105, 130), (110, 235, 240), (120, 220, 120), (200, 140, 255), (255, 255, 255)]
    for _ in range(count):
        x, y = rnd.uniform(40, w - 40), rnd.uniform(40, h - 40)
        if 0.06 * w < x < 0.94 * w and 0.14 * h < y < 0.86 * h:
            continue
        c = rnd.choice(palette) + (230,)
        r = rnd.uniform(6, 14)
        if rnd.random() < 0.5:
            d.ellipse([x - r, y - r, x + r, y + r], fill=c)
        else:
            a = rnd.uniform(0, math.pi)
            dx, dy = math.cos(a) * r * 1.6, math.sin(a) * r * 1.6
            d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=c, width=int(r * 0.9))


def make_popup(title, subtitle, top, bottom, icon_img=None, seed=0, with_confetti=True):
    w, h = 1200, 900
    img = rounded_card((w, h), 70, top, bottom)
    if with_confetti:
        confetti(img, seed)
    d = ImageDraw.Draw(img)
    if icon_img is not None:
        ic = icon_img.resize((380, 380), Image.LANCZOS)
        img.alpha_composite(ic, ((w - 380) // 2, 140))
        centered_text(d, w, 560, title, 96, (255, 255, 255, 255))
        centered_text(d, w, 690, subtitle, 60, (255, 255, 255, 230))
    else:
        centered_text(d, w, 290, title, 120, (255, 255, 255, 255))
        centered_text(d, w, 470, subtitle, 66, (255, 255, 255, 230))
    return img


def make_logo():
    """Λογότυπο demo: τίτλος σε «κονκάρδα» με τον κύκλο-στόχο και ένα αστέρι."""
    w, h = 1400, 420
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    card = rounded_card((w - 40, h - 40), 90, (255, 214, 64), (245, 120, 30))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([30, 40, w - 10, h - 4], radius=90, fill=(0, 0, 0, 120))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    img.alpha_composite(card, (20, 12))
    d = ImageDraw.Draw(img)
    # κύκλος-στόχος με αστέρι
    cx, cy, r = 215, 202, 125
    ring = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 60),
                                 outline=(255, 255, 255, 255), width=14)
    img.alpha_composite(ring)
    d.polygon(star_points(cx, cy + 6, 82, 35), fill=(255, 255, 255, 255))
    font = ImageFont.truetype(FONT_BOLD, 112)
    for i, line in enumerate(["Σταμάτα", "στο σωστό!"]):
        x, y = 395, 62 + i * 140
        d.text((x + 5, y + 7), line, font=font, fill=(120, 50, 0, 110))
        d.text((x, y), line, font=font, fill=(255, 255, 255, 255))
    return img


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(POPUP_DIR, exist_ok=True)
    icons = {}
    for icon_id, name, (top, bottom), shape in ICONS:
        img = make_icon(shape, top, bottom)
        img.save(os.path.join(ICON_DIR, icon_id + ".png"), optimize=True)
        icons[icon_id] = (name, img, top, bottom)

    make_popup("Συγχαρητήρια!", "Κέρδισες!", (255, 190, 60), (230, 80, 40), seed=1).save(
        os.path.join(POPUP_DIR, "win.png"), optimize=True)
    make_popup("Ωχ, παραλίγο!", "Ευχαριστούμε που έπαιξες", (110, 120, 170), (50, 55, 100),
               seed=2, with_confetti=False).save(os.path.join(POPUP_DIR, "lose.png"), optimize=True)

    for i, (icon_id, (name, img, top, bottom)) in enumerate(icons.items()):
        if icon_id == "bolt":
            title, sub = "Ξαναπαίξε!", "Έχεις μία ακόμα προσπάθεια"
        else:
            title, sub = name + "!", "Κέρδισες αυτό το δώρο"
        make_popup(title, sub, lerp(top, (255, 255, 255), 0.1), lerp(bottom, (0, 0, 0), 0.25),
                   icon_img=img, seed=10 + i).save(os.path.join(POPUP_DIR, "prize_" + icon_id + ".png"),
                                                    optimize=True)
    make_logo().save(os.path.join(ROOT, "assets", "demo", "logo.png"), optimize=True)
    print("OK:", ICON_DIR, POPUP_DIR)


if __name__ == "__main__":
    main()
