"""Draw the HUD heart icons (full / empty) in the UI palette.

The Rubik font has no U+2665, so a Label with "♥" would fall back to whatever
system font exists; a texture looks the same everywhere.
Run from the project root:  python tools/gen_heart_icons.py   (needs Pillow)
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui_gen"
SIZE = 40
SUPERSAMPLE = 8
TERRACOTTA = (0xD9, 0x84, 0x50, 255)
DARK = (0x25, 0x26, 0x3A, 255)
LAVENDER = (0x8E, 0x93, 0xCF, 255)
HIGHLIGHT = (0xF2, 0xB3, 0x3D, 255)


def heart_mask(size: int, inset: float) -> Image.Image:
    """Two circles on top of a triangle, shrunk by `inset` pixels on every side."""
    im = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(im)
    s = size - 2 * inset
    r = s * 0.27
    cy = inset + s * 0.32
    for cx in (inset + s * 0.29, inset + s * 0.71):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    draw.polygon([(inset + s * 0.035, cy + s * 0.05), (inset + s * 0.965, cy + s * 0.05),
                  (inset + s * 0.5, inset + s * 0.95)], fill=255)
    return im


def make_heart(fill: tuple, outline: tuple, shine: bool) -> Image.Image:
    big = SIZE * SUPERSAMPLE
    border = 3 * SUPERSAMPLE
    im = Image.new("RGBA", (big, big), outline[:3] + (0,))
    im.paste(Image.new("RGBA", (big, big), outline), mask=heart_mask(big, 0))
    im.paste(Image.new("RGBA", (big, big), fill), mask=heart_mask(big, border))
    if shine:
        draw = ImageDraw.Draw(im)
        d = big * 0.13
        cx, cy = big * 0.3, big * 0.3
        draw.ellipse((cx - d, cy - d * 0.7, cx + d, cy + d * 0.7), fill=HIGHLIGHT)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_heart(TERRACOTTA, DARK, True).save(OUT / "heart_full.png", optimize=True)
    make_heart(DARK, LAVENDER, False).save(OUT / "heart_empty.png", optimize=True)
    print("heart_full.png, heart_empty.png ->", OUT)


if __name__ == "__main__":
    main()
