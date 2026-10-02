"""Prepare UI textures from the generated source renders in assets_src/ui/.

Run from the project root:  python tools/prep_ui_assets.py [--preview DIR]
Needs Pillow, NumPy and SciPy.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets_src" / "ui"
OUT = ROOT / "assets" / "ui_gen"

ALPHA_CROP = 10   # pixels at or below this alpha don't count for the bbox
CROP_PAD = 2
# palette quantisation leaves the solid body at alpha 250-254, so "opaque" can't mean 255
ALPHA_OPAQUE = 250
GOLD = (0xF2, 0xB3, 0x3D)
LAVENDER = (0x8E, 0x93, 0xCF)
DARK = (0x25, 0x26, 0x3A)


def load_rgba(path: Path) -> Image.Image:
    # palette PNGs carry alpha in the tRNS chunk; convert() applies it
    return Image.open(path).convert("RGBA")


def crop_to_content(im: Image.Image) -> Image.Image:
    alpha = np.asarray(im.getchannel("A"))
    ys, xs = np.nonzero(alpha > ALPHA_CROP)
    if xs.size == 0:
        raise ValueError("image is fully transparent")
    left = max(int(xs.min()) - CROP_PAD, 0)
    top = max(int(ys.min()) - CROP_PAD, 0)
    right = min(int(xs.max()) + 1 + CROP_PAD, im.width)
    bottom = min(int(ys.max()) + 1 + CROP_PAD, im.height)
    return im.crop((left, top, right, bottom))


def defringe(im: Image.Image) -> Image.Image:
    """Give every non-opaque pixel (alpha < ALPHA_OPAQUE) the RGB of its nearest opaque pixel, keeping alpha.

    The renders were keyed off a magenta backdrop, so the soft edge still holds pink.
    Fully transparent pixels get recoloured too, so filtering during resize can't
    bleed the backdrop colour back in.
    """
    arr = np.asarray(im).copy()
    opaque = arr[..., 3] >= ALPHA_OPAQUE
    if not opaque.any():
        return im
    # for every non-opaque pixel: indices of the nearest opaque one
    _, (iy, ix) = distance_transform_edt(~opaque, return_indices=True)
    fix = ~opaque
    arr[fix, :3] = arr[iy[fix], ix[fix], :3]
    return Image.fromarray(arr, "RGBA")


def resize_to_width(im: Image.Image, width: int) -> Image.Image:
    height = round(im.height * width / im.width)
    return im.resize((width, height), Image.LANCZOS)


def make_grabber(size: int = 36, supersample: int = 8) -> Image.Image:
    big = size * supersample
    im = Image.new("RGBA", (big, big), LAVENDER + (0,))
    draw = ImageDraw.Draw(im)
    outline = round(3 * supersample)
    draw.ellipse((0, 0, big - 1, big - 1), fill=LAVENDER + (255,))
    draw.ellipse((outline, outline, big - 1 - outline, big - 1 - outline), fill=GOLD + (255,))
    # soft highlight in the upper-left for a bit of volume
    hl = round(big * 0.22)
    draw.ellipse((hl, hl, hl + round(big * 0.28), hl + round(big * 0.2)), fill=(0xFF, 0xD9, 0x8A, 255))
    return im.resize((size, size), Image.LANCZOS)


def preview(im: Image.Image, name: str, out_dir: Path) -> None:
    """Composite on dark and light backgrounds side by side to eyeball the fringe."""
    w, h = im.size
    sheet = Image.new("RGB", (w * 2, h))
    for i, bg in enumerate((DARK, (0xF4, 0xF4, 0xF4))):
        tile = Image.new("RGBA", (w, h), bg + (255,))
        tile.alpha_composite(im)
        sheet.paste(tile.convert("RGB"), (i * w, 0))
    sheet.save(out_dir / f"preview_{name}.png")


def process(src: str, outputs: dict[str, int], preview_dir: Path | None) -> None:
    im = defringe(crop_to_content(load_rgba(SRC / src)))
    print(f"{src}: cropped to {im.size}")
    for name, width in outputs.items():
        out = resize_to_width(im, width)
        out.save(OUT / name, optimize=True)
        print(f"  -> {name} {out.size}")
        if preview_dir is not None:
            preview(out, Path(name).stem, preview_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, help="write dark/light composites here")
    args = parser.parse_args()
    if args.preview is not None:
        args.preview.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    process("button_src.png", {"button.png": 640}, args.preview)
    process("frame_src.png", {"frame_large.png": 768, "frame_small.png": 384}, args.preview)
    process("sign_src.png", {"sign.png": 680}, args.preview)

    bg = Image.open(SRC / "bg_menu_src.jpg").convert("RGB")
    bg = resize_to_width(bg, 1920)
    bg.save(OUT / "bg_menu.jpg", quality=90, optimize=True)
    print(f"bg_menu_src.jpg -> bg_menu.jpg {bg.size}")

    grabber = make_grabber()
    grabber.save(OUT / "grabber.png", optimize=True)
    print(f"grabber.png {grabber.size}")
    if args.preview is not None:
        preview(grabber.resize((144, 144), Image.NEAREST), "grabber", args.preview)


if __name__ == "__main__":
    main()
