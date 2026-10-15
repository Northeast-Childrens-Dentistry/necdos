#!/usr/bin/env python3
"""Render a flat-color logo PNG as colored ASCII art for fastfetch (no smoothing).
Usage: python3 branding/make-ansi-logo.py branding/necd-badge.png system_files/usr/share/necdos/logo.ans
Needs: python3-pillow."""
import sys
from collections import Counter
from PIL import Image

src, dst = sys.argv[1:3]
W = 40  # columns; rows follow the aspect ratio (terminal cells are ~2x taller than wide)
im = Image.open(src).convert("RGBA")
counts = Counter(p[:3] for p in im.getdata() if p[3] == 255)
pal = []
for c, _ in counts.most_common():  # up to 4 dominant, clearly different colors
    if all(sum((c[i] - q[i]) ** 2 for i in range(3)) > 40 ** 2 for q in pal): pal.append(c)
    if len(pal) == 4: break
H = round(im.height / im.width * W * 0.5)
sm = im.resize((W, H), Image.NEAREST)
rows = []
for y in range(H):
    s, last = "", None
    for x in range(W):
        r, g, b, a = sm.getpixel((x, y))
        if a < 128: s += " "; continue
        c = min(pal, key=lambda p: sum((p[i] - (r, g, b)[i]) ** 2 for i in range(3)))
        if c != last: s += f"\x1b[38;2;{c[0]};{c[1]};{c[2]}m"; last = c
        s += "#"
    rows.append(s + "\x1b[0m")
open(dst, "w").write("\n".join(rows) + "\n")
