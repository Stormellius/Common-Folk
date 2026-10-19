#!/usr/bin/env python3
"""Splits the painted people into layers that change independently: a bare (hairless) body for every look, and
every hair style on its own, drawn in grey so it can be tinted to any hair colour.

  python3 tools/split_hair.py [SET ...]       (all sets when none are named; needs numpy and opencv)

Reads  assets/art/people/<set>/body*_front.png and body*_back.png (a painted body with its hair) and
       tools/hair_styles.json (what to do with each set: how far down hair can reach, where the chin is, and
       which looks have a hair style of their own: the others only differ in colour).
Writes assets/art/people/<set>/bare_<look>_<view>.png     the body with no hair, the head closed in with skin
       assets/art/people/<set>/hair_<style>_<view>.png    the part of the hair that goes over the face and clothes
       assets/art/people/<set>/hairb_<style>_<view>.png   the part that falls behind the head and shoulders
       data/hairstyles.json                               which styles each set has (a set can wear another's: "hair_from")
All layers of a set are the same size as its body, so they stack without any offsets.

How: pixels of the head that are neither skin, clothes nor thin outline are hair (found by colour); the outline
next to hair goes with it. The head is a circle fitted to the face that shows, which is drawn again as skin with
an outline where the hair was. The leftover outline fringe is cleaned, and the hair's luminance is kept as grey.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PEOPLE = ROOT / "assets" / "art" / "people"
LUMA = np.array([0.299, 0.587, 0.114], np.float32)
VIEWS = ("front", "back")


def hexc(value):
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def dilate(mask, radius):
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * radius + 1, 2 * radius + 1))
    return cv2.dilate(mask.astype(np.uint8), kernel).astype(bool)


class Figure:
    """One body picture and what its pixels are."""

    def __init__(self, image, skin_hex, hair_hex, hair_rows, dark_hair=True, probe=None):
        self.image = image
        self.height, self.width = image.shape[:2]
        rgb = image[..., :3].astype(np.float32)
        self.opaque = image[..., 3] > 128
        skin = hexc(skin_hex)
        if probe is not None:  # the real colour of the face, from a patch of cheek, rather than the nominal one
            px, py = int(self.width * probe[0]), int(self.height * probe[1])
            patch = image[py - 12:py + 13, px - 12:px + 13]
            patch = patch[patch[..., 3] > 200][:, :3].astype(np.float32)
            patch = patch[(patch * LUMA).sum(axis=1) > 80]
            if len(patch) > 50:
                skin = np.median(patch, axis=0)
        hair = hexc(hair_hex)
        dist_skin = np.linalg.norm(rgb - skin, axis=2)
        for shade in (0.82, 0.7):
            dist_skin = np.minimum(dist_skin, np.linalg.norm(rgb - skin * shade, axis=2))
        dist_hair = np.linalg.norm(rgb - hair, axis=2)
        for shade in (0.8, 1.2):
            dist_hair = np.minimum(dist_hair, np.linalg.norm(rgb - np.minimum(hair * shade, 255), axis=2))
        self.luma = (rgb * LUMA).sum(axis=2)
        skin_luma = float((skin * LUMA).sum())
        self.dark = self.opaque & (self.luma < min(70.0, 0.6 * skin_luma))
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))
        self.thick = cv2.morphologyEx(self.dark.astype(np.uint8), cv2.MORPH_OPEN, kernel).astype(bool)
        self.skin = self.opaque & (dist_skin < dist_hair) & (dist_skin < 48) & ~self.dark
        top = rgb.max(axis=2)
        saturation = (top - rgb.min(axis=2)) / np.maximum(top, 1.0)
        rows = np.zeros((self.height, self.width), bool)
        rows[:int(self.height * hair_rows)] = True
        coloured = (dist_skin > 60) & (saturation > 0.35) & (self.luma > 70)
        fill = self.opaque & rows & ~self.skin & ((dist_hair < 55) | (self.thick if dark_hair else False) | coloured) & ~(self.dark & ~self.thick)
        count, labels, stats, _ = cv2.connectedComponentsWithStats(fill.astype(np.uint8), connectivity=8)
        self.fill = np.zeros_like(fill)
        for index in range(1, count):
            if stats[index, cv2.CC_STAT_AREA] >= 0.007 * self.height * self.width:  # not an eye or a speck
                self.fill |= labels == index
        cloth = self.opaque & ~self.dark & (saturation < 0.25) & (self.luma > 150) & ~self.fill
        body_fill = self.skin | cloth
        near_hair = cv2.distanceTransform((~self.fill).astype(np.uint8), cv2.DIST_L2, 3)
        near_body = cv2.distanceTransform((~body_fill).astype(np.uint8), cv2.DIST_L2, 3)
        reach = max(10.0, 0.018 * self.height)
        extra = self.opaque & ~self.fill & ~body_fill & (near_hair <= reach) & (near_hair <= near_body + 1.0)
        self.hair = self.fill | extra
        alpha = image[..., 3]
        self.hair |= (alpha > 0) & (alpha <= 128) & dilate(self.hair, 5)  # the half-transparent fringe
        closed = cv2.morphologyEx(self.hair.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))).astype(bool)
        self.hair |= closed & (alpha > 0) & ~self.skin  # gaps in the outline are filled


def fit_head(figure, chin_row, radius_percentile=90):
    """The head as a circle: (centre x, centre y, radius, face colour), from the skin of the face that shows."""
    face = figure.skin & ~figure.hair
    face[chin_row:] = False
    count, labels, stats, _ = cv2.connectedComponentsWithStats(face.astype(np.uint8), connectivity=8)
    face = labels == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    ys = np.nonzero(face)[0]
    points, widths = [], []
    for y in range(ys.min() + int((chin_row - ys.min()) * 0.25), chin_row):
        row = np.nonzero(face[y])[0]
        if len(row) > 10:
            points += [(row.min(), y), (row.max(), y)]
            widths.append(row.max() - row.min())
    radius = 0.5 * float(np.percentile(widths, radius_percentile))
    pts = np.array(points, np.float64)
    cx, cy = float(pts[:, 0].mean()), float(chin_row - radius)
    for _ in range(30):  # the centre by least squares, the radius held
        dist = np.hypot(pts[:, 0] - cx, pts[:, 1] - cy)
        residual = dist - radius
        keep = np.abs(residual) < max(2.0 * np.median(np.abs(residual)), 3.0)
        if keep.sum() < 6:
            break
        jac = -np.c_[(pts[keep, 0] - cx) / np.maximum(dist[keep], 1e-6), (pts[keep, 1] - cy) / np.maximum(dist[keep], 1e-6)]
        step, *_ = np.linalg.lstsq(jac, -residual[keep], rcond=None)
        cx += step[0]
        cy += step[1]
    yy, xx = np.mgrid[0:figure.height, 0:figure.width]
    cheek = face & (np.abs(xx - cx) < radius * 0.5) & (np.abs(yy - cy) < radius * 0.6)
    colour = np.median(figure.image[..., :3][cheek], axis=0) if cheek.any() else np.array([225, 180, 140])
    return cx, cy, radius, colour.astype(np.uint8)


def eyes_top(figure, head):
    """The top row of the eyes (thick dark blobs inside the head that are not hair), or None."""
    cx, cy, radius, _ = head
    count, labels, stats, centres = cv2.connectedComponentsWithStats((figure.thick & ~figure.hair).astype(np.uint8), connectivity=8)
    tops = [stats[i, cv2.CC_STAT_TOP] for i in range(1, count)
            if np.hypot(*(centres[i] - (cx, cy))) < radius * 0.9 and stats[i, cv2.CC_STAT_AREA] < 0.02 * figure.height * figure.width]
    return min(tops) if tops else None


def eye_mask(figure, head):
    cx, cy, radius, _ = head
    count, labels, stats, centres = cv2.connectedComponentsWithStats((figure.thick & ~figure.hair).astype(np.uint8), connectivity=8)
    mask = np.zeros((figure.height, figure.width), bool)
    for i in range(1, count):
        if np.hypot(*(centres[i] - (cx, cy))) < radius * 0.9 and stats[i, cv2.CC_STAT_AREA] < 0.02 * figure.height * figure.width:
            mask |= labels == i
    return mask


def bare_body(figure, head, chin_frac, view, clip_sky=True):
    """The body without its hair: the head closed in with skin and outline where the hair was."""
    image, height, width = figure.image, figure.height, figure.width
    cx, cy, radius, colour = head
    out = image.copy()
    out[figure.hair] = 0
    thickness = max(5.0, 0.0105 * height)
    yy, xx = np.mgrid[0:height, 0:width]
    dist = np.hypot(xx - cx, yy - cy)
    if view == "front":
        top = eyes_top(figure, head)
        eyes = eye_mask(figure, head)
        out[(dist < radius - 1) & (yy < (top - 4 if top else cy + radius)) & ~eyes] = [*colour, 255]  # the hairline and fringe
        side = (dist < radius - 2) & (dist > radius * 0.55) & (np.abs(xx - cx) > radius * 0.4) & (figure.luma < 140) & ~figure.thick & figure.opaque
        out[side & ~figure.hair & (yy < cy + 0.35 * radius)] = [*colour, 255]  # strands that lay on the cheeks
    hole = ~(figure.opaque & ~figure.hair)
    outline = image[..., :3][figure.opaque & figure.dark & ~figure.thick & ~figure.hair]
    outline_colour = np.median(outline, axis=0).astype(np.uint8) if len(outline) else np.array([40, 22, 14], np.uint8)
    out[(dist <= radius) & hole] = [*colour, 255]
    out[(dist > radius) & (dist <= radius + thickness) & hole] = [*outline_colour, 255]
    alpha = (out[..., 3] > 128).astype(np.uint8)
    opened = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    thin = (alpha > 0) & (opened == 0)
    thin[int(height * (chin_frac + 0.10)):] = False  # thin bits above the shoulders are leftovers of the hair's edge
    out[thin] = 0
    if clip_sky:
        out[(yy < cy - 0.15 * radius) & (dist > radius + thickness + 2)] = 0  # above the head there is only sky
    count, labels, stats, _ = cv2.connectedComponentsWithStats((out[..., 3] > 0).astype(np.uint8), connectivity=8)
    if count > 2:
        out[labels != 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))] = 0  # nothing floats loose
    return out


def grey_hair(figure):
    """The hair as luminance only (so any colour can tint it), with the alpha it had."""
    median = float(np.median(figure.luma[figure.fill])) if figure.fill.any() else 128.0
    grey = np.clip(figure.luma / max(median, 1.0) * 0.95, 0.0, 1.0) * 255
    out = np.zeros(figure.image.shape, np.uint8)
    out[..., :3] = grey.astype(np.uint8)[..., None]
    out[..., 3] = np.where(figure.hair, figure.image[..., 3], 0)
    return out


def split_over_and_behind(hair_image, head, extra=0.05):
    """The part of the hair that lies over the head (the fringe, the top) and the part behind it and the shoulders."""
    cx, cy, radius, _ = head
    height, width = hair_image.shape[:2]
    yy, xx = np.mgrid[0:height, 0:width]
    inside = np.hypot(xx - cx, yy - cy) <= radius * (1.0 + extra) + max(5.0, 0.0105 * height)
    over, behind = hair_image.copy(), hair_image.copy()
    over[~inside] = 0
    behind[inside] = 0
    return over, behind


def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def save(array, path):
    Image.fromarray(array).save(path)


def bounding(image):
    ys, xs = np.nonzero(image[..., 3] > 128)
    return xs.min(), xs.max(), ys.min(), ys.max()


def process(set_name, config, entry, styles_out):
    directory = PEOPLE / set_name
    chin_frac = config["chin"]
    shared = {}  # what is the same from every look: the head of the first, found from its front
    for look in entry["looks"]:
        figures = {}
        for view in VIEWS:
            path = directory / f"{look['body']}_{view}.png"
            figures[view] = Figure(load(path), look["skin"], look["hair"], config["rows"], config.get("dark_hair", True),
                                   (0.5, chin_frac - 0.05) if view == "front" else None)
        front = figures["front"]
        head = fit_head(front, int(front.height * chin_frac), config.get("radius_percentile", 90))
        for view in VIEWS:
            figure = figures[view]
            if view == "back":  # no face to fit: the head of the front, moved by how the back picture sits
                fl, fr, ft, _ = bounding(front.image)
                bl, br, bt, _ = bounding(figure.image)
                head_view = (head[0] + ((bl + br) - (fl + fr)) / 2.0, head[1] + (bt - ft), head[2], head[3])
            else:
                head_view = head
            bare = bare_body(figure, head_view, chin_frac, view, config.get("clip_sky", True))
            save(bare, directory / f"bare_{look['id']}_{view}.png")
            style = config["styles"].get(look["id"])
            if style:
                over, behind = split_over_and_behind(grey_hair(figure), head_view)
                save(over, directory / f"hair_{style[0]}_{view}.png")
                save(behind, directory / f"hairb_{style[0]}_{view}.png")
        style = config["styles"].get(look["id"])
        if style:
            styles_out.append({"id": style[0], "name": style[1], **({"for": style[2]} if len(style) > 2 else {})})
        shared[look["id"]] = head
    print(set_name, "styles:", ", ".join(s["id"] for s in styles_out))


def main(only):
    configs = json.load(open(ROOT / "tools" / "hair_styles.json"))
    sprites = {e["id"]: e for e in json.load(open(ROOT / "data" / "sprites.json"))}
    result = []
    for set_name, config in configs.items():
        if only and set_name not in only:
            continue
        entry = sprites["people." + set_name]
        styles = []
        process(set_name, config, entry, styles)
        styles += config.get("extra", [])  # styles that already exist as pictures
        result.append({"id": "hair." + set_name, "set": entry["id"], "styles": styles})
    for set_name, config in configs.items():  # sets that wear another set's hair (the head is in the same place)
        if config.get("hair_from") and (not only or set_name in only):
            source = next(e for e in result if e["id"] == "hair." + config["hair_from"])
            result = [e for e in result if e["id"] != "hair." + set_name]
            result.append({"id": "hair." + set_name, "set": "people." + set_name, "hair_dir": "people/" + config["hair_from"], "styles": source["styles"]})
    path = ROOT / "data" / "hairstyles.json"
    if only and path.exists():  # keep the sets that were not redone
        kept = [e for e in json.load(open(path)) if e["id"][5:] not in only]
        result = kept + result
    path.write_text(json.dumps(result, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
