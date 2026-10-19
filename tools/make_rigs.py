#!/usr/bin/env python3
"""Works out where each painted person can be cut into parts that move on their own (head, torso, two arms, two
legs), so that every layer of the person (body, hair, clothes) can be moved in the same pieces. Writes data/rigs.json.

  python3 tools/make_rigs.py          (needs numpy and Pillow)

All numbers are fractions of the picture, so the cuts are the same for every layer of a set (they are all the same
size). They come from the shape of the bare body: the neck is where the figure is narrowest above the shoulders, the
arms hang free of the body for a while above the hands (a gap on each side), and the legs separate lower down.
Layers that do not split between the legs (skirts, dresses, long coats) are found too, so that they swing as one.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PEOPLE = ROOT / "assets" / "art" / "people"


def runs_in(row):
    """The (start, end) of each stretch of opaque pixels in a row."""
    xs = np.nonzero(row)[0]
    if len(xs) == 0:
        return []
    breaks = np.nonzero(np.diff(xs) > 3)[0]
    starts = np.r_[xs[0], xs[breaks + 1]]
    ends = np.r_[xs[breaks], xs[-1]]
    return list(zip(starts.tolist(), ends.tolist()))


def body_path(set_name, look_id):
    """The bare body when the set has one, else its body as painted (hair and all)."""
    bare = PEOPLE / set_name / f"bare_{look_id}_front.png"
    return bare if bare.exists() else PEOPLE / set_name / ("body_front.png" if look_id == "a" else f"body_{look_id}_front.png")


def measure(set_name, look_id):
    alpha = np.array(Image.open(body_path(set_name, look_id)))[..., 3] > 128
    height, width = alpha.shape
    widths = np.array([(np.ptp(np.nonzero(r)[0]) if r.any() else 0) for r in alpha])
    # the neck: the narrowest row between the top of the head and the widest of the shoulders
    top = int(np.nonzero(alpha.any(axis=1))[0][0])
    search = range(int(height * 0.28), int(height * 0.46))
    neck = min(search, key=lambda y: widths[y] if widths[y] > 0 else 9999)
    # the arms hang clear of the body on rows with three stretches of figure
    three = [y for y in range(int(height * 0.5), int(height * 0.85)) if len(runs_in(alpha[y])) == 3]
    if three:
        block = [y for y in three if abs(y - np.median(three)) < height * 0.12]
        middle = runs_in(alpha[int(np.median(block))])
        cut_a = (middle[0][1] + middle[1][0]) / 2.0
        cut_b = (middle[1][1] + middle[2][0]) / 2.0
        hand = max(block) + 0.012 * height
    else:  # the arms touch the body all the way: cut a little inside the widest row
        row = int(height * 0.6)
        xs = np.nonzero(alpha[row])[0]
        span = xs.max() - xs.min()
        cut_a, cut_b = xs.min() + 0.2 * span, xs.max() - 0.2 * span
        hand = height * 0.72
    legs = [y for y in range(int(height * 0.7), int(height * 0.99)) if len(runs_in(alpha[y])) == 2]
    mid_row = int(np.median(legs)) if legs else int(height * 0.9)
    pair = runs_in(alpha[mid_row])
    mid = (pair[0][1] + pair[1][0]) / 2.0 if len(pair) == 2 else width / 2.0
    hip = hand / height
    return {
        "neck": round(neck / height, 4), "shoulder": round(neck / height + 0.025, 4), "hand": round(hand / height, 4),
        "hip": round(hip, 4), "arm_a": round(float(cut_a) / width, 4), "arm_b": round(float(cut_b) / width, 4), "mid": round(mid / width, 4),
        "top": round(top / height, 4),
    }


def skirt_like(path, hip, height_hint=None):
    """Whether a clothing layer stays in one piece between the legs (a skirt, a dress, a long coat)."""
    alpha = np.array(Image.open(path))[..., 3] > 128
    height = alpha.shape[0]
    row = int(height * (hip + (1.0 - hip) * 0.55))
    return len(runs_in(alpha[row])) == 1 and alpha[row].any()


def main():
    sprites = {e["id"]: e for e in json.load(open(ROOT / "data" / "sprites.json"))}
    out = []
    for entry_id, entry in sprites.items():
        if not entry_id.startswith("people."):
            continue
        set_name = entry["dir"].split("/")[-1]
        look_id = entry["looks"][0]["id"]
        rig = measure(set_name, look_id)
        skirts = []
        names = [f"g_{g}" for g in entry.get("garments", [])] + list(entry.get("outfits", []))
        for name in names:
            path = PEOPLE / set_name / f"{name}_front.png"
            if path.exists() and skirt_like(path, rig["hip"]):
                skirts.append(name[2:] if name.startswith("g_") else name)
        rig.update({"id": "rig." + set_name, "set": entry_id, "skirts": sorted(skirts)})
        out.append(rig)
        print(set_name, {k: v for k, v in rig.items() if k not in ("id", "set")})
    (ROOT / "data" / "rigs.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
