#!/usr/bin/env python3
"""Turns a body sheet and dressed copies of it (SpriteCook edits that keep every pixel of the figures where it
was) into layers: the body, and for each outfit just what the clothes changed, so that any outfit can be drawn
over any body. Each sheet has two figures, front on the left and back on the right.

  python3 tools/make_layers.py SETNAME DIR   (DIR holds body.png and one <outfit>.png per outfit)
writes assets/art/people/SETNAME/<layer>_front.png and <layer>_back.png, all the same size so they stack.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAD = 6


def dilate(mask, steps):
    for _ in range(steps):
        n = mask.copy()
        n[1:] |= mask[:-1]; n[:-1] |= mask[1:]; n[:, 1:] |= mask[:, :-1]; n[:, :-1] |= mask[:, 1:]
        mask = n
    return mask


def erode(mask, steps):
    return ~dilate(~mask, steps)


def outfit_layer(body, dressed):
    b = body.astype(int); d = dressed.astype(int)
    diff = (np.abs(b[..., :3] - d[..., :3]).sum(axis=2) > 60) | (np.abs(b[..., 3] - d[..., 3]) > 80)
    diff &= d[..., 3] > 0
    mask = erode(dilate(diff, 2), 1) & (d[..., 3] > 0)
    out = dressed.copy()
    out[~mask] = 0
    return out


def main(name, folder):
    folder = Path(folder)
    layers = {p.stem: np.array(Image.open(p).convert("RGBA")) for p in sorted(folder.glob("*.png"))}
    body = layers["body"]
    height, width = body.shape[:2]
    half = width // 2
    out_dir = ROOT / "assets" / "art" / "people" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    result = {"body": body}
    for key, image in layers.items():
        if key != "body":
            result[key] = outfit_layer(body, image)
    for side, (x0, x1) in (("front", (0, half)), ("back", (half, width))):
        # one box for every layer of this figure, so they stack
        ys, xs = np.where(np.stack([layers[k][:, x0:x1, 3] > 20 for k in layers]).any(axis=0))
        box = (max(0, x0 + xs.min() - PAD), max(0, ys.min() - PAD), min(width, x0 + xs.max() + 1 + PAD), min(height, ys.max() + 1 + PAD))
        for key, image in result.items():
            Image.fromarray(image).crop(box).save(out_dir / f"{key}_{side}.png")
    print(name, "layers:", ", ".join(result), "box", box)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
