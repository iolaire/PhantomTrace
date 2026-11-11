"""Build the app icon from the owner's Gemini squircle image.
Reads docs/LookAndFeel/original/icon/Native macOS Dock Squircle Icon.jpg (never modified).
Removes the white frame and soft shadow outside the squircle's black outline by flood fill
from the image border, crops to the squircle, centres it on a 1024 canvas with the standard
macOS margin, and writes Packaging/AppIcon.png (master) plus Packaging/AppIcon.icns (iconutil).
Developer tooling only. Requirements 17.2, 17.12.
Run: .venv/bin/python Scripts/export-app-icon.py
"""
import subprocess
import sys
import tempfile
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/LookAndFeel/original/icon/Native macOS Dock Squircle Icon.jpg"
OUT_DIR = ROOT / "Packaging"
BG_MIN = 150      # luminance above this, connected to the border, is background/shadow
CANVAS = 1024
SQUIRCLE = 832    # squircle edge length on the canvas (macOS icon grid leaves ~100 px margin)
SIZES = [16, 32, 64, 128, 256, 512, 1024]


def background_mask(gray):
    h, w = gray.shape
    cand = gray > BG_MIN
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if cand[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if cand[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and cand[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def main():
    img = Image.open(SRC).convert("RGB")
    gray = np.asarray(img.convert("L")).astype(np.float32)
    bg = background_mask(gray)
    inside = ~bg
    # Keep the largest region only is implicit: everything not reached from the border is inside.
    mask = Image.fromarray((inside * 255).astype(np.uint8))
    # Pull the edge in 1 px (removes light fringe), then soften for an antialiased edge.
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    rgba = img.convert("RGBA")
    rgba.putalpha(mask)
    a = np.asarray(mask)
    ys, xs = np.where(a > 6)
    rgba = rgba.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    scale = SQUIRCLE / max(rgba.size)
    rgba = rgba.resize((round(rgba.width * scale), round(rgba.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(rgba, ((CANVAS - rgba.width) // 2, (CANVAS - rgba.height) // 2), rgba)
    OUT_DIR.mkdir(exist_ok=True)
    canvas.save(OUT_DIR / "AppIcon.png")
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for s in SIZES[:-1]:
            canvas.resize((s, s), Image.LANCZOS).save(iconset / f"icon_{s}x{s}.png")
            if s >= 16 and s * 2 <= 1024:
                canvas.resize((s * 2, s * 2), Image.LANCZOS).save(iconset / f"icon_{s}x{s}@2x.png")
        canvas.save(iconset / "icon_512x512@2x.png")
        # 64 is not a standard iconset name; drop it.
        for extra in (iconset / "icon_64x64.png", iconset / "icon_64x64@2x.png"):
            extra.unlink(missing_ok=True)
        r = subprocess.run(["/usr/bin/iconutil", "-c", "icns", str(iconset),
                            "-o", str(OUT_DIR / "AppIcon.icns")], capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stderr, file=sys.stderr)
            sys.exit(1)
    print("wrote Packaging/AppIcon.png and Packaging/AppIcon.icns")


if __name__ == "__main__":
    main()
