"""Turns the raw Google Flow renders in assets/source/ into app assets.

  python3 tool/prepare_assets.py

The renders came out 9:16 (768x1376) with flat backgrounds, so this script:
* samples each image's real background colour (the app paints the card
  behind the illustration in exactly that colour, so edges never show),
* finds the illustration's bounding box and crops to the aspect ratio each
  screen needs, extending the flat background where required,
* cuts the book symbol out of its background for the Android adaptive icon
  and the splash screen (transparent PNG),
* paints over stray text the generator added to the lime collection cover,
* writes lib/core/theme/illustration_colors.g.dart with the sampled colours.

Requires Pillow, numpy, scipy.
"""
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source")
OUT = os.path.join(ROOT, "assets", "images")

# name -> (output subdir, target width, target height, subject fraction of the
#          shorter side)
ILLUSTRATIONS = {
    "onboarding_library": ("onboarding", 900, 1200, 0.86),
    "onboarding_highlight": ("onboarding", 900, 1200, 0.92),
    "onboarding_habit": ("onboarding", 900, 1200, 0.86),
    "empty_library": ("empty", 900, 900, 0.78),
    "empty_highlights": ("empty", 900, 900, 0.74),
    "empty_notes": ("empty", 900, 900, 0.72),
    "empty_bookmarks": ("empty", 900, 900, 0.74),
    "empty_history": ("empty", 900, 900, 0.70),
    "empty_collections": ("empty", 900, 900, 0.72),
    "empty_search": ("empty", 900, 900, 0.78),
    "session_complete": ("session", 900, 900, 0.74),
    "collection_lavender": ("collections", 1200, 900, 0.80),
    "collection_lime": ("collections", 1200, 900, 0.80),
    "collection_butter": ("collections", 1200, 900, 0.80),
    "collection_peach": ("collections", 1200, 900, 0.80),
    "collection_mint": ("collections", 1200, 900, 0.80),
    "collection_sky": ("collections", 1200, 900, 0.80),
}

# Regions (x0, y0, x1, y1) in the 768x1376 source to repaint with the
# surrounding fill colour: the generator printed "#B5D14A" on two bars.
REPAIRS = {
    "collection_lime": [(294, 984, 376, 1006), (484, 984, 569, 1006)],
}


def load(name):
    return Image.open(os.path.join(SRC, name + ".jpg")).convert("RGB")


def background_color(img):
    a = np.asarray(img).astype(np.float32)
    border = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3),
                             a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    return np.median(border, axis=0)


def distance(img, bg):
    a = np.asarray(img).astype(np.float32)
    return np.sqrt(((a - bg) ** 2).sum(axis=2))


def subject_box(img, bg, thresh=38):
    d = distance(img, bg)
    mask = ndimage.binary_opening(d > thresh, iterations=1)
    ys, xs = np.nonzero(mask)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def repair(img, name):
    for (x0, y0, x1, y1) in REPAIRS.get(name, []):
        a = np.asarray(img)
        fill = tuple(int(v) for v in np.median(a[y0 - 14:y0 - 4, x0 + 4:x1 - 4].reshape(-1, 3), axis=0))
        ImageDraw.Draw(img).rectangle((x0, y0, x1, y1), fill=fill)
    return img


def compose(img, bg, box, tw, th, frac):
    """Places the subject centred on a tw x th canvas of the background."""
    x0, y0, x1, y1 = box
    sw, sh = x1 - x0, y1 - y0
    # Scale so the subject fills `frac` of the canvas in its limiting axis.
    scale = min(tw * frac / sw, th * frac / sh)
    # Crop generously from the source (keeps the paper grain around the subject).
    pad = int(max(sw, sh) * 0.5)
    cx0, cy0 = max(0, x0 - pad), max(0, y0 - pad)
    cx1, cy1 = min(img.width, x1 + pad), min(img.height, y1 + pad)
    crop = img.crop((cx0, cy0, cx1, cy1))
    crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
                       Image.LANCZOS)
    canvas = Image.new("RGB", (tw, th), tuple(int(v) for v in bg))
    # Subject centre -> canvas centre.
    scx = (x0 + x1) / 2 - cx0
    scy = (y0 + y1) / 2 - cy0
    ox = round(tw / 2 - scx * scale)
    oy = round(th / 2 - scy * scale)
    # Feather the pasted crop's edges into the flat background.
    mask = Image.new("L", crop.size, 255)
    feather = max(8, int(min(crop.size) * 0.06))
    m = np.asarray(mask).astype(np.float32)
    yy, xx = np.mgrid[0:crop.height, 0:crop.width]
    edge = np.minimum.reduce([xx, yy, crop.width - 1 - xx, crop.height - 1 - yy]).astype(np.float32)
    m = np.clip(edge / feather, 0, 1) * 255
    canvas.paste(crop, (ox, oy), Image.fromarray(m.astype(np.uint8)))
    return canvas


def cutout(img, bg, lo=18, hi=60):
    """Removes the background connected to the image border; returns RGBA
    with anti-aliased, un-matted edges."""
    d = distance(img, bg)
    bgish = d < hi
    labels, _ = ndimage.label(bgish)
    border_labels = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    border_labels.discard(0)
    region = np.isin(labels, list(border_labels))
    alpha = np.ones(d.shape, np.float32)
    alpha[region] = np.clip((d[region] - lo) / (hi - lo), 0, 1)
    a = np.asarray(img).astype(np.float32)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha[..., None]) * bg) / safe, 0, 255)
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    return out.crop(out.getbbox())


def place_transparent(subject, size, frac):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scale = size * frac / max(subject.width, subject.height)
    s = subject.resize((round(subject.width * scale), round(subject.height * scale)), Image.LANCZOS)
    canvas.paste(s, ((size - s.width) // 2, (size - s.height) // 2), s)
    return canvas


def hexcolor(bg):
    return "0xFF%02X%02X%02X" % tuple(int(round(v)) for v in bg)


def main():
    colors = {}
    for name, (sub, tw, th, frac) in ILLUSTRATIONS.items():
        if not os.path.exists(os.path.join(SRC, name + ".jpg")):
            print("missing", name)
            continue
        img = repair(load(name), name)
        bg = background_color(img)
        box = subject_box(img, bg)
        out = compose(img, bg, box, tw, th, frac)
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
        out.save(os.path.join(OUT, sub, name + ".webp"), "WEBP", quality=88, method=6)
        colors[name] = hexcolor(bg)
        print("ok", name, box, colors[name])

    # iOS / legacy launcher icon: opaque square.
    icon = load("app_icon")
    bg = background_color(icon)
    box = subject_box(icon, bg)
    compose(icon, bg, box, 1024, 1024, 0.66).save(os.path.join(OUT, "app_icon", "app_icon.png"))
    colors["app_icon"] = hexcolor(bg)

    # Android adaptive foreground: transparent, inside the 61% safe circle.
    fg = load("app_icon_foreground")
    fbg = background_color(fg)
    book = cutout(fg, fbg)
    # Diagonal of the symbol must fit the safe circle (61% of the canvas).
    diag = (book.width ** 2 + book.height ** 2) ** 0.5
    frac = 0.60 * max(book.width, book.height) / diag
    place_transparent(book, 1024, frac).save(os.path.join(OUT, "app_icon", "app_icon_foreground.png"))
    colors["app_icon_background"] = hexcolor(fbg)

    # Splash: transparent symbol; the native splash paints Folio's paper colour.
    sp = load("splash_mark")
    sbg = background_color(sp)
    mark = cutout(sp, sbg)
    diag = (mark.width ** 2 + mark.height ** 2) ** 0.5
    place_transparent(mark, 1152, 0.62 * max(mark.width, mark.height) / diag).save(
        os.path.join(OUT, "splash", "splash_mark.png"))

    lines = [
        "// GENERATED by tool/prepare_assets.py — do not edit.",
        "// Background colours sampled from each illustration, so the card",
        "// behind an image matches its edges exactly.",
        "",
        "const Map<String, int> kIllustrationBackgrounds = {",
    ]
    for k in sorted(colors):
        lines.append(f"  '{k}': {colors[k]},")
    lines.append("};")
    with open(os.path.join(ROOT, "lib", "core", "theme", "illustration_colors.g.dart"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
