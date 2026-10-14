#!/usr/bin/env python3
"""Generate hicolor icons for CareStack and Iris. Run from anywhere: python3 branding/apps/make-icons.py
Needs Pillow, potrace, rsvg-convert."""
import subprocess, tempfile
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ICONS = HERE.parents[1] / "system_files/usr/share/icons/hicolor"
SIZES = [16, 22, 24, 32, 48, 64, 128, 256, 512]
TEAL = (20, 123, 141)  # Iris ring colour, sampled from the source
RADIUS = 0.146         # corner radius / edge, measured from the reference (9.3px of 64) and the source (175 of 1200)

def save(img, size, name):
    d = ICONS / f"{size}x{size}/apps"; d.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(d / f"{name}.png", optimize=True)

# CareStack: source has a 1px transparent top row; crop to the 1200px art, then re-cut
# the corners with our own 8x supersampled mask so the radius is exact at 1200px.
cs = Image.open(HERE / "carestack-source.png").convert("RGBA").crop((0, 1, 1200, 1201))
S = 1200 * 4
m = Image.new("L", (S, S), 0)
ImageDraw.Draw(m).rounded_rectangle((0, 0, S - 1, S - 1), RADIUS * S, fill=255)
cs.putalpha(m.resize((1200, 1200), Image.LANCZOS))
for s in SIZES:
    save(cs, s, "necd-carestack")

# Iris: opaque white background -> alpha (un-blend teal from white), then trace the
# flat one-colour art to SVG with potrace and render every PNG from the SVG (no upscaling blur).
iris = Image.open(HERE / "iris-source.png").convert("RGB")
alpha = iris.split()[0].point(lambda v: max(0, min(255, round((255 - v) * 255 / (255 - TEAL[0])))))
big = alpha.resize((alpha.width * 8, alpha.height * 8), Image.LANCZOS).point(lambda v: 255 if v > 127 else 0)
w, h = alpha.size
with tempfile.TemporaryDirectory() as t:
    pbm = Path(t) / "i.pbm"; big.point(lambda v: 0 if v else 255).convert("1").save(pbm)
    subprocess.run(["potrace", "-s", "-o", t + "/i.svg", "--flat", str(pbm)], check=True)
    body = (Path(t) / "i.svg").read_text()
paths = body[body.index("<g"):body.index("</svg>")]
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w*8} {h*8}">'
       + paths.replace('fill="#000000"', 'fill="#%02x%02x%02x"' % TEAL) + "</svg>")
(ICONS / "scalable/apps/necd-iris.svg").write_text(svg)
for s in SIZES:
    d = ICONS / f"{s}x{s}/apps"; d.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rsvg-convert", "-w", str(s), "-h", str(s), "-o", d / "necd-iris.png",
                    ICONS / "scalable/apps/necd-iris.svg"], check=True)
