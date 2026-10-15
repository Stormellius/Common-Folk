#!/usr/bin/env python3
"""Makes clean garment pieces from pictures of a body wearing just that garment (a SpriteCook edit of the set's
body sheet that keeps every pixel of the figures where it was), the same way make_layers.py makes outfits: what the
clothes changed is the piece. Written as assets/art/people/SET/g_<garment>_<side>.png, cut with the set's own boxes.

  python3 tools/make_garments.py SET GARMENT IMAGE      e.g.  adult_female tunic_top assets/source/garments/x.png
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_layers import ROOT, outfit_layer  # noqa: E402


def main(name, garment, image_path, body_path=None):
    folder = ROOT / "assets" / "art" / "people" / name
    boxes = json.load(open(folder / "box.json"))
    dressed = np.array(Image.open(image_path).convert("RGBA"))
    body = np.array(Image.open(body_path or ROOT / "assets" / "source" / "people" / name / "body.png").convert("RGBA"))
    piece = outfit_layer(body, dressed)
    for side, box in boxes.items():
        Image.fromarray(piece).crop(tuple(box)).save(folder / f"g_{garment}_{side}.png")
    print(name, garment, "written")


if __name__ == "__main__":
    main(*sys.argv[1:])
