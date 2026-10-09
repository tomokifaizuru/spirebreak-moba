#!/usr/bin/env python3
"""Builds the Spirebreak app icons from the layers rendered by tools/make_icons.gd.

Outputs (icon-drafts/):
  icon-<V>.png            512x512 main / store icon (what a launcher shows: centre 72/108 of the layers)
  icon-<V>-1024.png       same at 1024
  icon-<V>-fg.png         1024 adaptive foreground (transparent, heroes inside the safe zone)
  icon-<V>-bg.png         1024 adaptive background
  icons-sheet.png         comparison sheet (round + squircle masks at launcher sizes)
Usage: python3 tools/compose_icons.py [default_variant]
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "icon-drafts")
L = os.path.join(D, "layers")
N = 1024
VIEW = int(round(N * 72 / 108))  # visible part of an adaptive icon


def layer(name):
    return Image.open(os.path.join(L, name + ".png")).convert("RGBA")


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def radial(c_in, c_out, center=(0.5, 0.42), radius=0.75):
    img = Image.new("RGBA", (N, N))
    px = img.load()
    cx, cy = center[0] * N, center[1] * N
    for y in range(N):
        for x in range(N):
            d = math.hypot(x - cx, y - cy) / (radius * N)
            px[x, y] = lerp(c_in, c_out, min(1.0, d) ** 1.3)
    return img


def rays(color, n=14, center=(0.5, 0.42), spread=0.45, alpha=60):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx, cy = center[0] * N, center[1] * N
    for i in range(n):
        a0 = (i / n) * 2 * math.pi
        a1 = a0 + spread * 2 * math.pi / n
        r = N * 1.2
        dr.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))],
                   fill=color[:3] + (alpha,))
    return img.filter(ImageFilter.GaussianBlur(6))


def tint(img, color, strength=0.7, alpha=1.0):
    """Recolours a layer toward `color`, keeping its shading; scales alpha."""
    r, g, b, a = img.split()
    gray = Image.merge("RGB", (r, g, b)).convert("L")
    col = Image.new("RGB", img.size, color[:3])
    shaded = ImageChops.multiply(col, Image.merge("RGB", (gray, gray, gray)))
    mixed = Image.blend(Image.merge("RGB", (r, g, b)), shaded, strength)
    a = a.point(lambda v: int(v * alpha))
    return Image.merge("RGBA", (*mixed.split(), a))


def place(canvas, img, box_w, box_h, cx, cy, anchor_bottom=False):
    bb = img.split()[3].getbbox()
    img = img.crop(bb)
    s = min(box_w / img.width, box_h / img.height)
    img = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)
    x = int(cx - img.width / 2)
    y = int(cy - img.height) if anchor_bottom else int(cy - img.height / 2)
    canvas.alpha_composite(img, (x, y))
    return (x, y, img.width, img.height)


def outline(fg, width=10, color=(255, 255, 255, 235)):
    """White sticker outline + soft dark shadow so the heroes read at 48 px."""
    a = fg.split()[3]
    grow = a.filter(ImageFilter.MaxFilter(width * 2 + 1))
    sil = Image.new("RGBA", fg.size, color)
    sil.putalpha(grow)
    shadow = Image.new("RGBA", fg.size, (10, 12, 30, 150))
    shadow.putalpha(grow.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.6)))
    out = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, 10))
    out.alpha_composite(sil)
    out.alpha_composite(fg)
    return out


def ground_glow(canvas, cx, cy, w, h, color):
    g = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(g).ellipse([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], fill=color)
    canvas.alpha_composite(g.filter(ImageFilter.GaussianBlur(28)))


def variant_A():
    """Trio: Kestrel front, Morrow + Sable behind; Dawn spire glowing behind them."""
    bg = radial(hexc("ffcf7a"), hexc("1d2350"), center=(0.5, 0.36), radius=0.78)
    bg.alpha_composite(rays(hexc("fff2c4"), center=(0.5, 0.36), alpha=50))
    sp = tint(layer("spire_0"), hexc("3a4a9a"), 0.55, 0.95)
    place(bg, sp, 440, 560, N / 2, 470)
    ground_glow(bg, N / 2, 760, 760, 170, hexc("3c4a8f", 210))
    fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    place(fg, layer("A_heroes"), 640, 470, N / 2, 800, anchor_bottom=True)
    return bg, outline(fg)


def variant_B():
    """Kestrel close-up with the spire over her shoulder, sunset sky."""
    bg = Image.new("RGBA", (N, N))
    dr = ImageDraw.Draw(bg)
    top, bot = hexc("ff8a5c"), hexc("3a1f5c")
    for y in range(N):
        dr.line([(0, y), (N, y)], fill=lerp(top, bot, y / N))
    bg.alpha_composite(rays(hexc("ffe0a8"), center=(0.66, 0.3), alpha=45))
    sp = tint(layer("spire_0"), hexc("ffd9a0"), 0.55, 0.95)
    place(bg, sp, 420, 600, 690, 420)
    fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # bottom-anchored: shoulders run off the bottom of the visible circle, face in the safe zone
    place(fg, layer("B_heroes"), 600, 640, 488, N - 160, anchor_bottom=True)
    return bg, outline(fg)


def variant_C():
    """Duel: Morrow (Dawn) vs Sable (Dusk) on a split blue / red sky."""
    bg = Image.new("RGBA", (N, N))
    blue = radial(hexc("4f8cff"), hexc("14204a"), center=(0.2, 0.4), radius=0.9)
    red = radial(hexc("ff5a6e"), hexc("4a1020"), center=(0.8, 0.4), radius=0.9)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).polygon([(N * 0.58, 0), (N, 0), (N, N), (N * 0.42, N)], fill=255)
    bg = Image.composite(red, blue, mask.filter(ImageFilter.GaussianBlur(3)))
    seam = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(seam).line([(N * 0.58, 0), (N * 0.42, N)], fill=(255, 245, 220, 255), width=14)
    bg.alpha_composite(seam.filter(ImageFilter.GaussianBlur(10)))
    bg.alpha_composite(seam.filter(ImageFilter.GaussianBlur(2)))
    fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    place(fg, layer("C_heroes"), 680, 560, N / 2, 790, anchor_bottom=True)
    return bg, outline(fg)


def main_icon(bg, fg, size):
    full = bg.copy()
    full.alpha_composite(fg)
    o = (N - VIEW) // 2
    return full.crop((o, o, o + VIEW, o + VIEW)).resize((size, size), Image.LANCZOS)


def squircle_mask(s, n=4.2):
    m = Image.new("L", (s * 4, s * 4), 0)
    px = m.load()
    S = s * 4
    for y in range(S):
        for x in range(S):
            u, v = (x + 0.5) / S * 2 - 1, (y + 0.5) / S * 2 - 1
            if abs(u) ** n + abs(v) ** n <= 1:
                px[x, y] = 255
    return m.resize((s, s), Image.LANCZOS)


def circle_mask(s):
    m = Image.new("L", (s * 4, s * 4), 0)
    ImageDraw.Draw(m).ellipse([0, 0, s * 4 - 1, s * 4 - 1], fill=255)
    return m.resize((s, s), Image.LANCZOS)


def masked(icon, size, kind):
    im = icon.resize((size, size), Image.LANCZOS)
    m = circle_mask(size) if kind == "round" else squircle_mask(size)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0), m)
    return out


def font(sz, bold=True):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def sheet(icons, default):
    W, H = 1500, 3 * 330 + 120
    img = Image.new("RGBA", (W, H), hexc("1b1f2e"))
    dr = ImageDraw.Draw(img)
    dr.text((30, 30), "Spirebreak app icon drafts  (512 store icon  ·  round + squircle at 192 / 96 / 48 px)", font=font(30), fill=(255, 255, 255))
    labels = {"A": "A  Trio: Kestrel, Morrow, Sable + Dawn spire",
              "B": "B  Kestrel close-up + spire, sunset",
              "C": "C  Duel: Morrow (Dawn) vs Sable (Dusk)"}
    for r, (k, ic) in enumerate(icons.items()):
        y = 100 + r * 330
        # fake wallpaper strip
        wall = Image.new("RGBA", (W - 40, 310))
        wd = ImageDraw.Draw(wall)
        for yy in range(310):
            wd.line([(0, yy), (W - 40, yy)], fill=lerp(hexc("2e4a7a"), hexc("6a3d6e"), yy / 310))
        img.alpha_composite(wall, (20, y))
        img.alpha_composite(ic.resize((280, 280), Image.LANCZOS), (35, y + 15))
        x = 345
        for kind in ("round", "squircle"):
            for s in (192, 96, 48):
                m = masked(ic, s, kind)
                img.alpha_composite(m, (x, y + 20 + (192 - s) // 2))
                x += s + 26
            x += 20
        name = labels[k] + ("   ★ DEFAULT" if k == default else "")
        dr.text((345, y + 245), name, font=font(26), fill=(255, 230, 150) if k == default else (255, 255, 255))
        dr.text((345, y + 280), "round masks                                                                          squircle masks",
                font=font(16, False), fill=(220, 225, 240))
    return img


def main():
    default = sys.argv[1] if len(sys.argv) > 1 else "A"
    icons = {}
    for k, f in (("A", variant_A), ("B", variant_B), ("C", variant_C)):
        bg, fg = f()
        bg.convert("RGB").save(os.path.join(D, f"icon-{k}-bg.png"))
        fg.save(os.path.join(D, f"icon-{k}-fg.png"))
        icons[k] = main_icon(bg, fg, 1024)
        icons[k].save(os.path.join(D, f"icon-{k}-1024.png"))
        icons[k].resize((512, 512), Image.LANCZOS).save(os.path.join(D, f"icon-{k}.png"))
        print("icon", k)
    sheet(icons, default).save(os.path.join(D, "icons-sheet.png"))
    print("sheet done")
    # Install the default variant as the app icon (used by the Android export preset + project icon).
    A = os.path.join(ROOT, "assets", "icon")
    os.makedirs(A, exist_ok=True)
    icons[default].resize((512, 512), Image.LANCZOS).save(os.path.join(A, "icon-512.png"))
    icons[default].resize((192, 192), Image.LANCZOS).save(os.path.join(A, "icon-192.png"))
    Image.open(os.path.join(D, f"icon-{default}-fg.png")).save(os.path.join(A, "adaptive-fg-1024.png"))
    Image.open(os.path.join(D, f"icon-{default}-bg.png")).save(os.path.join(A, "adaptive-bg-1024.png"))
    # Android 13 themed (monochrome) icon: white silhouette of the foreground heroes.
    fg = Image.open(os.path.join(D, f"icon-{default}-fg.png")).convert("RGBA")
    mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    mono.putalpha(fg.split()[3])
    mono.save(os.path.join(A, "adaptive-mono-1024.png"))
    open(os.path.join(A, "DEFAULT.txt"), "w").write(f"Default app icon: variant {default} (see icon-drafts/icons-sheet.png)\n")
    print("installed default", default, "->", A)


if __name__ == "__main__":
    main()
