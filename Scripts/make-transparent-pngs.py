import sys, re
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/LookAndFeel/original/base-images"
DST = ROOT / "docs/LookAndFeel/use"
DST.mkdir(parents=True, exist_ok=True)

DARK = 90      # luminance below this is treated as outline (barrier to the fill)
PAD = 16
# Outline gaps narrower than ~2x this are sealed during the fill. Only needed where white
# object interiors leak to the background (padlocks + smoke). Elsewhere it would wrongly
# fill see-through areas (chain loops, hatching), so the default is 0 (off).
SEAL_RADIUS_DEFAULT = 0
SEAL_RADIUS_OVERRIDES = {"shackled-volume-and-padlocks": 4}


def slug(name):
    s = name.replace("base-", "", 1).replace("&", "and")
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def convert(path):
    name = slug(path.stem)
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)

    # Background = non-dark pixels connected to the image border.
    # Outlines are thickened first so small gaps (e.g. where smoke overlaps a padlock)
    # don't let the fill leak into white object interiors. The result is then grown back
    # through non-dark pixels by the same amount so glow/antialiased edges are preserved.
    dark = lum < DARK
    r = SEAL_RADIUS_OVERRIDES.get(name, SEAL_RADIUS_DEFAULT)
    if r > 0:
        yy, xx = np.ogrid[-r:r + 1, -r:r + 1]
        disk = (xx * xx + yy * yy) <= r * r
        sealed = ndi.binary_dilation(dark, structure=disk)
    else:
        sealed = dark
    labels, _ = ndi.label(~sealed)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    border = border[border != 0]
    core = np.isin(labels, border)
    bg = ndi.binary_dilation(core, iterations=r + 2, mask=~dark) if r > 0 else core

    # Unmultiply from white inside the background region (keeps glow as soft alpha).
    mn = rgb.min(axis=2)
    a = np.clip((255.0 - mn - 4.0) / 251.0, 0.0, 1.0)
    a = np.where(bg, a, 1.0)

    safe = np.maximum(a, 1e-3)[..., None]
    col = (rgb - 255.0 * (1.0 - a[..., None])) / safe
    col = np.where(bg[..., None], col, rgb)
    col = np.clip(col, 0, 255)

    out = np.dstack([col, a * 255.0]).round().astype(np.uint8)
    out[a == 0, :3] = 0

    ys, xs = np.where(out[..., 3] > 6)
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, out.shape[0])
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, out.shape[1])
    img = Image.fromarray(out[y0:y1, x0:x1], "RGBA")
    dest = DST / f"{name}.png"
    img.save(dest, optimize=True)
    print(dest.name, img.size)


for p in sorted(SRC.glob("*.jpg")):
    convert(p)
