"""Export the app sprite set (cropped 1x and 2x PNGs) from docs/LookAndFeel/use/.

Reads only docs/LookAndFeel/use/. Writes name.png and name@2x.png (kebab-case) plus
window-frame.insets.json to Sources/PhantomTraceUI/Resources/Sprites/. Never touches
docs/LookAndFeel/original/. Developer tooling only: not shipped in the app bundle.
Requirements 17.3, 17.6, 17.9, 17.10, 17.13.

Run: .venv/bin/python Scripts/export-sprites.py [--out DIR]
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
USE = ROOT / "docs/LookAndFeel/use"
ORIGINAL = ROOT / "docs/LookAndFeel/original"
DEFAULT_OUT = ROOT / "Sources/PhantomTraceUI/Resources/Sprites"

ALPHA_CUTOFF = 6   # same visibility threshold as make-transparent-pngs.py

# sprite name -> (source file stem in use/, fixed 1x size as ("width"|"max", points)).
# "width" fixes the 1x width; "max" fits the longer side. 2x is exactly double the 1x size.
SPRITES = {
    "window-frame": ("window", ("width", 640)),
    "shackled-volume-and-padlocks": ("shackled-volume-and-padlocks", ("max", 300)),
    "crt-diagnostic-portal": ("crt-diagnostic-portal", ("max", 300)),
    "shattered-chains-and-portullis": ("shattered-chains-and-portullis", ("max", 300)),
    "ghost-looking-left-yellow": ("ghost-looking-left-yellow", ("max", 128)),
    "ghost-looking-left-red": ("ghost-looking-left-red", ("max", 128)),
    "ghost-looking-left-green": ("ghost-looking-left-green", ("max", 128)),
}

# Interior detection for the window frame: the interior is the smooth (low local
# deviation) run around the centre, found on band-averaged row and column profiles.
STD_WINDOW = 9
STD_THRESHOLD = 4.0
BAND = 40  # half-width of the centre band averaged for profiles, full-res pixels


def crop_to_content(img):
    ys, xs = np.where(np.asarray(img)[..., 3] > ALPHA_CUTOFF)
    if ys.size == 0:
        raise ValueError("image has no visible pixels")
    return img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def one_x_size(size, rule):
    kind, value = rule
    w, h = size
    scale = value / w if kind == "width" else value / max(w, h)
    return max(1, round(w * scale)), max(1, round(h * scale))


def local_std(gray, k):
    """Box-window standard deviation via an integral image (no SciPy needed)."""
    pad = k // 2
    g = np.pad(gray, pad, mode="edge")
    out = []
    for arr in (g, g * g):
        c = np.cumsum(np.cumsum(arr, axis=0), axis=1)
        c = np.pad(c, ((1, 0), (1, 0)))
        out.append((c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k))
    return np.sqrt(np.maximum(out[1] - out[0] ** 2, 0.0))


def smooth_run(profile):
    """Return (start, end) of the smooth run containing the profile centre."""
    smooth = profile < STD_THRESHOLD
    centre = len(profile) // 2
    if not smooth[centre]:
        raise ValueError("frame centre is not smooth; cannot find interior")
    start = centre
    while start > 0 and smooth[start - 1]:
        start -= 1
    end = centre
    while end < len(profile) - 1 and smooth[end + 1]:
        end += 1
    return start, end + 1


def window_insets(cropped, size_1x):
    """9-slice insets (1x points) from the full-resolution cropped frame."""
    gray = np.asarray(cropped.convert("L"), dtype=np.float64)
    h, w = gray.shape
    std = local_std(gray, STD_WINDOW)
    x0, x1 = smooth_run(std[h // 2 - BAND:h // 2 + BAND].mean(axis=0))
    y0, y1 = smooth_run(std[:, w // 2 - BAND:w // 2 + BAND].mean(axis=1))
    sx, sy = size_1x[0] / w, size_1x[1] / h
    left, right = round(x0 * sx), round((w - x1) * sx)
    top, bottom = round(y0 * sy), round((h - y1) * sy)
    width, height = size_1x
    return {
        "top": top,
        "left": left,
        "bottom": bottom,
        "right": right,
        "interior": {
            "x": left,
            "y": top,
            "width": width - left - right,
            "height": height - top - bottom,
        },
        "size1x": {"width": width, "height": height},
        "scale": 1,
        "units": "points at 1x; origin top-left; 2x files are exactly double",
    }


def export(out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, (stem, rule) in SPRITES.items():
        src = USE / f"{stem}.png"
        cropped = crop_to_content(Image.open(src).convert("RGBA"))
        w1, h1 = one_x_size(cropped.size, rule)
        for suffix, factor in (("", 1), ("@2x", 2)):
            img = cropped.resize((w1 * factor, h1 * factor), Image.LANCZOS)
            dest = out_dir / f"{name}{suffix}.png"
            img.save(dest, optimize=True)
            print(dest.name, img.size)
        if name == "window-frame":
            insets = window_insets(cropped, (w1, h1))
            dest = out_dir / "window-frame.insets.json"
            dest.write_text(json.dumps(insets, indent=2) + "\n")
            print(dest.name, {k: insets[k] for k in ("top", "left", "bottom", "right")})


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output directory")
    out_dir = parser.parse_args().out.resolve()
    if out_dir == ORIGINAL or ORIGINAL in out_dir.parents:
        sys.exit("refusing to write into docs/LookAndFeel/original/")
    export(out_dir)


if __name__ == "__main__":
    main()
