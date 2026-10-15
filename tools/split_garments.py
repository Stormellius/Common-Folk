#!/usr/bin/env python3
"""Cuts each whole-outfit layer of a people set (assets/art/people/SET/<outfit>_<side>.png) into garments that can
be worn on their own: a top, a bottom and shoes (g_<outfit>_<slot>_<side>.png, same size as the outfit layer so the
pieces stack on the body). Where a garment ends is a few rows per set (tools/garment_cuts.json):
  feet      rows from here down are shoes
  arms_end  rows from here down are the bottom whatever their column (a skirt's flare); above it the sleeves and hands
            at the sides still belong to the top
  waist     rows from here down, in the middle columns (|x - centre| < band * width), are the bottom
This is the free, rough way to get separate pieces; tools/make_garments.py makes clean ones from garments drawn on their own.

  python3 tools/split_garments.py [SET ...] [--check DIR]   (--check writes a picture of each cut for looking at)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PEOPLE = ROOT / "assets" / "art" / "people"
OUTFITS = ["casual", "worker", "formal", "winter", "sleepwear"]
SLOTS = ["top", "bottom", "feet"]


def masks(shape, alpha, cut):
    height, width = shape
    ys, xs = np.mgrid[0:height, 0:width]
    where = alpha > 20
    cx = xs[where].mean() if where.any() else width / 2
    feet = ys >= cut["feet"]
    bottom = ~feet & ((ys >= cut["arms_end"]) | ((ys >= cut["waist"]) & (np.abs(xs - cx) < cut["band"] * width)))
    top = ~feet & ~bottom
    return {"top": top, "bottom": bottom, "feet": feet}


def split(name, cut, check=None):
    folder = PEOPLE / name
    for outfit in OUTFITS:
        for side in ("front", "back"):
            source = folder / f"{outfit}_{side}.png"
            if not source.exists():
                continue
            image = np.array(Image.open(source).convert("RGBA"))
            parts = masks(image.shape[:2], image[..., 3], cut)
            for slot in SLOTS:
                piece = image.copy()
                piece[~parts[slot]] = 0
                target = folder / f"g_{outfit}_{slot}_{side}.png"
                if (piece[..., 3] > 20).sum() < 150:  # nothing there (bare feet in nightclothes): no such piece
                    target.unlink(missing_ok=True)
                    continue
                Image.fromarray(piece).save(target)
    if check:
        Path(check).mkdir(parents=True, exist_ok=True)
        body = Image.open(folder / "body_front.png").convert("RGBA")
        sheet = Image.new("RGBA", (body.width * len(OUTFITS), body.height), (120, 160, 90, 255))
        for index, outfit in enumerate(OUTFITS):
            frame = Image.new("RGBA", body.size, (120, 160, 90, 255))
            frame.alpha_composite(body)
            for slot, tint in zip(SLOTS, [(255, 0, 0), (0, 0, 255), (255, 255, 0)]):
                if not (folder / f"g_{outfit}_{slot}_front.png").exists():
                    continue
                piece = Image.open(folder / f"g_{outfit}_{slot}_front.png").convert("RGBA")
                data = np.array(piece)
                data[..., :3] = (data[..., :3] * 0.6 + np.array(tint) * 0.4).astype(np.uint8)
                frame.alpha_composite(Image.fromarray(data))
            sheet.alpha_composite(frame, (index * body.width, 0))
        sheet.save(Path(check) / f"{name}.png")
    print(name, "cut into", ", ".join(SLOTS))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = None
    if "--check" in sys.argv:
        check = sys.argv[sys.argv.index("--check") + 1]
        args = [a for a in args if a != check]
    cuts = json.load(open(ROOT / "tools" / "garment_cuts.json"))
    for set_name in args or cuts:
        split(set_name, cuts[set_name], check)
