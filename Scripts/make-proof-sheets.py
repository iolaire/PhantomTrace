"""Build proof sheets of every transparent PNG in docs/LookAndFeel/use on black and white."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/LookAndFeel/use"
DST = ROOT / "docs/LookAndFeel/proofs"
DST.mkdir(parents=True, exist_ok=True)

COLS, CELL, LABEL_H, MARGIN = 4, 800, 48, 24


def build(bg, fg, name):
    files = sorted(SRC.glob("*.png"))
    rows = -(-len(files) // COLS)
    sheet = Image.new("RGB", (COLS * CELL, rows * (CELL + LABEL_H)), bg)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGBA")
        im.thumbnail((CELL - 2 * MARGIN, CELL - 2 * MARGIN), Image.LANCZOS)
        x0, y0 = (i % COLS) * CELL, (i // COLS) * (CELL + LABEL_H)
        sheet.paste(im, (x0 + (CELL - im.width) // 2, y0 + MARGIN + (CELL - 2 * MARGIN - im.height) // 2), im)
        draw.text((x0 + MARGIN, y0 + CELL - 4), f.stem, fill=fg, font=font)
    out = DST / name
    sheet.save(out, optimize=True)
    print(out.relative_to(ROOT), sheet.size)


build((0, 0, 0), (200, 200, 200), "proof-black.png")
build((255, 255, 255), (60, 60, 60), "proof-white.png")
