#!/usr/bin/env python3
"""The child and youth picture sets have one body for boys and girls alike, so girls are given long hair as a
layer of its own, drawn over the body and clothes. The hair is lifted from the red-haired grown woman (whose hair
stands apart from her skin), scaled to the younger head, and made grey so the game can tint it to the look's hair.

  python3 tools/make_girl_hair.py
writes assets/art/people/{child,youth}/hair_long_front.png and hair_long_back.png, the size of each set's body.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PEOPLE = ROOT / "assets" / "art" / "people"
SOURCE = "adult_female/body_c"
SOURCE_HAIR = np.array([0xb9, 0x46, 0x29])
# where the woman's head is widest (centre x, row) and how wide, then the same for each younger set
SOURCE_HEAD = {"front": (172, 130, 259), "back": (176, 140, 253)}
TARGETS = {
    "child": {"front": (208, 172, 299), "back": (210, 172, 300)},
    "youth": {"front": (190, 160, 300), "back": (190, 160, 300)},
}


def dilate(mask, steps):
    for _ in range(steps):
        n = mask.copy()
        n[1:] |= mask[:-1]; n[:-1] |= mask[1:]; n[:, 1:] |= mask[:, :-1]; n[:, :-1] |= mask[:, 1:]
        mask = n
    return mask


def pieces(mask, smallest=1500):
    """The big connected pieces of a mask (the hair and the tail, without stray freckles)."""
    from collections import deque
    seen = np.zeros_like(mask)
    out = np.zeros_like(mask)
    for y, x in zip(*np.where(mask)):
        if seen[y, x]:
            continue
        piece = []
        queue = deque([(y, x)])
        seen[y, x] = True
        while queue:
            cy, cx = queue.popleft()
            piece.append((cy, cx))
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        if len(piece) >= smallest:
            for py, px in piece:
                out[py, px] = True
    return out


def filled(mask):
    """A mask with its holes filled: whatever the outside cannot reach."""
    from collections import deque
    outside = np.zeros_like(mask)
    h, w = mask.shape
    queue = deque((y, x) for y in range(h) for x in (0, w - 1) if not mask[y, x])
    queue.extend((y, x) for x in range(w) for y in (0, h - 1) if not mask[y, x])
    for y, x in queue:
        outside[y, x] = True
    while queue:
        cy, cx = queue.popleft()
        for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))
    return ~outside


def hair_layer(side):
    a = np.array(Image.open(PEOPLE / f"{SOURCE}_{side}.png").convert("RGBA")).astype(float)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    light_skin = (r > 200) & (g > 170)
    hair = (al > 100) & (r > 90) & (r - g > 55) & (g < 150)
    hair = ~dilate(~dilate(hair, 6), 6) & (al > 100) & ~light_skin  # close gaps (the tie over the shoulder), not the skin
    hair = pieces(hair)
    dark = (r + g + b) / 3 < 95
    outline = dilate(hair, 11) & dark & (al > 100)
    # the body's own outline (shoulders, arms) touches the hair only along its edge; keep dark pixels that are
    # mostly surrounded by hair or by nothing, not by skin
    skin = (al > 100) & ~hair & ~dark
    outline &= ~dilate(skin, 3) | dilate(hair, 3)
    keep = filled(hair | outline)  # with the tie that holds the tail
    grey = np.zeros_like(a)
    lum = (r * 0.3 + g * 0.59 + b * 0.11) / (SOURCE_HAIR @ np.array([0.3, 0.59, 0.11]))
    value = np.clip(lum, 0.0, 1.0) * 255.0
    grey[..., 0] = grey[..., 1] = grey[..., 2] = np.where(hair, value, (r + g + b) / 3)
    grey[..., 3] = np.where(keep, al, 0)
    return Image.fromarray(grey.astype(np.uint8), "RGBA")


def main():
    for side in ("front", "back"):
        layer = hair_layer(side)
        sx, sy, sw = SOURCE_HEAD[side]
        for name, heads in TARGETS.items():
            body = Image.open(PEOPLE / name / f"body_{side}.png")
            tx, ty, tw = heads[side]
            scale = tw / sw
            scaled = layer.resize((round(layer.width * scale), round(layer.height * scale)), Image.LANCZOS)
            out = Image.new("RGBA", body.size, (0, 0, 0, 0))
            out.paste(scaled, (round(tx - sx * scale), round(ty - sy * scale)), scaled)
            out.save(PEOPLE / name / f"hair_long_{side}.png")
            print("wrote", name, side)


if __name__ == "__main__":
    main()
