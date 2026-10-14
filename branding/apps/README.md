# Application icons

- `carestack-source.png`: CareStack green "C" icon, 1201x1201 RGBA, from `Documents/Carestack/carestack-icon.png`. Highest resolution available; already rounded.
- `iris-source.png`: Iris teal speech-bubble icon, 256x256 on opaque white, from `Documents/Carestack/CarestackIris.png`. Best available (the other candidate was 92x107).

`make-icons.py` (Pillow, potrace, rsvg-convert) writes `necd-carestack` and `necd-iris` into `system_files/usr/share/icons/hicolor/` at 16, 22, 24, 32, 48, 64, 128, 256, 512 px.

- CareStack: crop to the 1200px art, apply a 0.146 corner-radius mask (measured from the reference and the source), Lanczos downsample. No SVG (rounded square plus a "C" is not worth tracing).
- Iris: white background converted to alpha, traced to `scalable/apps/necd-iris.svg` (flat single colour, verified against the original), and PNGs rendered from the SVG. The source is only 256 px, so the 512 px PNG is rendered from the vector trace rather than upscaled pixels; it is faithful but any detail the source lacks is not invented.
- Iris has no background, so the teal is low-contrast on dark themes.
