#!/usr/bin/env python3
"""Trace the flat-color NECD logos in branding/*.png to SVG and build the icon variants.
Needs: python3-pillow, potrace. Usage: python3 branding/make-assets.py"""
import subprocess, tempfile, os, re
from PIL import Image

OUT = "system_files/usr/share/necdos/branding"
SCALE = 4  # trace at 4x so curves come out smooth

def trace(png):
    """Return (width, height, [(hex_color, svg_path_d), ...]) for a flat-color RGBA logo."""
    im = Image.open(png).convert("RGBA"); w, h = im.size
    big = im.resize((w * SCALE, h * SCALE), Image.LANCZOS)
    px = big.load()
    # dominant opaque colors, 4 distinct
    counts = {}
    for y in range(0, big.height, 2):
        for x in range(0, big.width, 2):
            r, g, b, a = px[x, y]
            if a == 255: counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
    pal = []
    for c, _ in sorted(counts.items(), key=lambda kv: -kv[1]):
        if all(sum((c[i] - q[i]) ** 2 for i in range(3)) > 40 ** 2 for q in pal): pal.append(c)
        if len(pal) == 4: break
    layers = []
    for c in pal:
        mask = Image.new("1", big.size, 1)  # potrace traces black pixels
        mp = mask.load()
        for y in range(big.height):
            for x in range(big.width):
                r, g, b, a = px[x, y]
                if a > 128 and min(pal, key=lambda p: sum((p[i] - (r, g, b)[i]) ** 2 for i in range(3))) == c: mp[x, y] = 0
        with tempfile.TemporaryDirectory() as t:
            mask.save(f"{t}/m.pbm")
            subprocess.run(["potrace", "-s", "-u", "1", "--flat", "-o", f"{t}/m.svg", f"{t}/m.pbm"], check=True)
            svg = open(f"{t}/m.svg").read()
        d = " ".join(re.findall(r'<path[^>]* d="([^"]+)"', svg))
        # potrace emits y-up coordinates under a flip transform; bake the flip in
        layers.append(("#%02x%02x%02x" % c, d))
    return w, h, layers

def svg(w, h, layers, square, fill=None, symbolic=False):
    s = max(w, h) if square else None
    W, H = (s, s) if square else (w, h)
    tx, ty = ((s - w) / 2, (s - h) / 2) if square else (0, 0)
    inner = ""
    for col, d in layers:
        if symbolic: f = ' class="ColorScheme-Text" style="fill:currentColor"'
        else: f = f' fill="{fill or col}"'
        inner += f'<path{f} d="{d}"/>'
    style = '<style id="current-color-scheme" type="text/css">.ColorScheme-Text{color:#232629}</style>' if symbolic else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{style}'
            f'<g transform="translate({tx} {ty + h}) scale({1/SCALE} {-1/SCALE})">{inner}</g></svg>\n')

os.makedirs(OUT, exist_ok=True)
w, h, L = trace("branding/necd-badge.png")
open(f"{OUT}/logo.svg", "w").write(svg(w, h, L, True))
open(f"{OUT}/logo-white.svg", "w").write(svg(w, h, L, True, fill="#ffffff"))
open(f"{OUT}/logo-symbolic.svg", "w").write(svg(w, h, L, True, symbolic=True))
w, h, L = trace("branding/necd-wordmark.png")
open(f"{OUT}/wordmark.svg", "w").write(svg(w, h, L, False))
print("ok")
