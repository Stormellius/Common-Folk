#!/usr/bin/env python3
"""Cuts the game's pictures out of the source sheets in assets/source (made with SpriteCook).

  python3 tools/build_art.py                  cut everything listed in tools/art_sheets.json
  python3 tools/build_art.py --detect SHEET   print the boxes of the separate pictures on a sheet,
                                              and write SHEET.boxes.png with each one numbered

A sheet is a picture with a transparent background and many sprites on it. art_sheets.json says,
for each sheet, where each named sprite is (a box x0, y0, x1, y1 in pixels), and the result is
written as assets/art/<name>.png trimmed to what is drawn plus `pad` clear pixels. "textures" are
opaque squares cut as they are (optionally turned a quarter: "rotate": 90). Needs Pillow and numpy.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent


def trim(image, pad):
    alpha = np.array(image)[..., 3]
    ys, xs = np.where(alpha > 8)
    if len(xs) == 0:
        return image
    box = (max(0, xs.min() - pad), max(0, ys.min() - pad), min(image.width, xs.max() + 1 + pad), min(image.height, ys.max() + 1 + pad))
    return image.crop(box)


def keep_main(image):
    """Clears everything that does not touch the biggest drawn shape (slivers of the neighbouring
    sprites caught by the crop), keeping any small piece that lies inside its box (a walking stick)."""
    alpha = np.array(image)[..., 3] > 8
    height, width = alpha.shape
    label = np.zeros(alpha.shape, dtype=np.int32)
    boxes = {}
    areas = {}
    count = 0
    for y in range(height):
        for x in range(width):
            if alpha[y, x] and label[y, x] == 0:
                count += 1
                stack = [(y, x)]
                label[y, x] = count
                x0 = x1 = x
                y0 = y1 = y
                area = 0
                while stack:
                    cy, cx = stack.pop()
                    area += 1
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < height and 0 <= nx < width and alpha[ny, nx] and label[ny, nx] == 0:
                            label[ny, nx] = count
                            stack.append((ny, nx))
                boxes[count] = (x0, y0, x1, y1)
                areas[count] = area
    if count <= 1:
        return image
    main = max(areas, key=areas.get)
    mx0, my0, mx1, my1 = boxes[main]
    data = np.array(image)
    for index, (x0, y0, x1, y1) in boxes.items():
        inside = x0 >= mx0 - 2 and x1 <= mx1 + 2 and y0 >= my0 - 2 and y1 <= my1 + 2
        if index != main and not inside:
            data[label == index] = (0, 0, 0, 0)
    return Image.fromarray(data)


def build():
    spec = json.load(open(ROOT / "tools" / "art_sheets.json"))
    count = 0
    for sheet in spec["sheets"]:
        image = Image.open(ROOT / sheet["source"]).convert("RGBA")
        out = ROOT / sheet.get("out", "assets/art")
        for name, box in sheet.get("crops", {}).items():
            target = out / (name + ".png")
            target.parent.mkdir(parents=True, exist_ok=True)
            piece = image.crop(tuple(box))
            if sheet.get("clean"):
                piece = keep_main(piece)
            trim(piece, int(sheet.get("pad", 2))).save(target)
            count += 1
        for name, entry in sheet.get("textures", {}).items():
            target = out / (name + ".png")
            target.parent.mkdir(parents=True, exist_ok=True)
            piece = image.crop(tuple(entry["box"]))
            piece.putalpha(255)  # a texture has no holes
            if int(entry.get("rotate", 0)):
                piece = piece.rotate(int(entry["rotate"]), expand=True)
            piece.save(target)
            count += 1
    print("cut", count, "pictures")


def detect(path):
    image = Image.open(path).convert("RGBA")
    alpha = np.array(image)[..., 3] > 20
    height, width = alpha.shape
    seen = np.zeros_like(alpha, dtype=bool)
    boxes = []
    for y in range(height):
        for x in range(width):
            if alpha[y, x] and not seen[y, x]:
                stack = [(y, x)]
                seen[y, x] = True
                x0 = x1 = x
                y0 = y1 = y
                area = 0
                while stack:
                    cy, cx = stack.pop()
                    area += 1
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < height and 0 <= nx < width and alpha[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
                if area > 150:
                    boxes.append((x0, y0, x1 + 1, y1 + 1))
    boxes.sort(key=lambda b: (b[1] // 80, b[0]))
    shown = Image.new("RGBA", image.size, (200, 200, 200, 255))
    shown.alpha_composite(image)
    draw = ImageDraw.Draw(shown)
    for index, box in enumerate(boxes):
        draw.rectangle(box, outline=(255, 0, 0, 255))
        draw.text((box[0] + 2, box[1] + 2), str(index), fill=(0, 0, 255, 255))
        print(index, list(box))
    shown.save(str(path) + ".boxes.png")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--detect":
        detect(sys.argv[2])
    else:
        build()
