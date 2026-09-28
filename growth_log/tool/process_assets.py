#!/usr/bin/env python3
"""Cuts generated artwork out of its plain light background and exports it
at the sizes the app expects.

    pip install pillow numpy scipy
    python3 tool/process_assets.py            # all images in assets_src/generated
    python3 tool/process_assets.py --preview  # also writes contact sheets

How it works
  1. Estimates the (slightly uneven) background from light, neutral pixels
     connected to the image border.
  2. Marks as foreground anything coloured, or neutral-but-dark (ink lines,
     black clay). Enclosed holes are kept opaque unless they look exactly
     like background (e.g. the hole in a torus, between an arm and a body).
  3. Soft grey contact shadows are kept as translucent ink so objects still
     sit on whatever card colour the app places them on.
  4. Crops to the content, centres it on the target canvas with padding.
"""
import argparse
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'assets_src' / 'generated'
OUT = ROOT / 'assets' / 'images'

# name -> (folder, width, height, padding fraction, vertical anchor 0..1)
TARGETS = {
    'badge_novice': ('badges', 1024, 1024, 0.08, 0.5),
    'badge_apprentice': ('badges', 1024, 1024, 0.08, 0.5),
    'badge_skilled': ('badges', 1024, 1024, 0.08, 0.5),
    'badge_expert': ('badges', 1024, 1024, 0.08, 0.5),
    'badge_master': ('badges', 1024, 1024, 0.08, 0.5),
    'trophy': ('illustrations', 1024, 1024, 0.08, 0.5),
    'streak_flame': ('illustrations', 1024, 1024, 0.08, 0.5),
    'hero_shapes': ('illustrations', 1200, 1200, 0.04, 0.5),
    'recap_mountain': ('illustrations', 1600, 1200, 0.06, 0.5),
    'empty_skills': ('empty', 1200, 900, 0.08, 0.5),
    'empty_log': ('empty', 1200, 900, 0.08, 0.5),
    'empty_insights': ('empty', 1200, 900, 0.08, 0.5),
    'empty_search': ('empty', 1200, 900, 0.08, 0.5),
    'onboarding_track': ('onboarding', 1200, 1600, 0.05, 1.0),
    'onboarding_gratitude': ('onboarding', 1200, 1600, 0.05, 1.0),
    'onboarding_grow': ('onboarding', 1200, 1600, 0.05, 1.0),
    'levelup_hero': ('onboarding', 1200, 1600, 0.05, 0.5),
    'splash_logo': ('brand', 1024, 1024, 0.12, 0.5),
    'app_icon_foreground': ('brand', 1024, 1024, 0.22, 0.5),
}

INK = np.array([14, 16, 28], dtype=np.float32)


def cut_out(rgb: np.ndarray, shadows: bool = True) -> np.ndarray:
    img = rgb.astype(np.float32)
    h, w, _ = img.shape
    lum = img.mean(axis=2)
    sat = img.max(axis=2) - img.min(axis=2)

    # 1. Background model.
    cand = (sat < 10) & (lum > 200)
    labels, _ = ndimage.label(cand)
    edge = np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    bg_ids = np.unique(edge[edge > 0])
    bg = np.isin(labels, bg_ids)
    sigma = 30
    den = ndimage.gaussian_filter(bg.astype(np.float32), sigma)
    fallback = np.median(img[bg], axis=0) if bg.any() else np.array([248.0] * 3)
    model = np.empty_like(img)
    for c in range(3):
        num = ndimage.gaussian_filter(img[..., c] * bg, sigma)
        model[..., c] = np.where(den > 1e-3, num / np.maximum(den, 1e-6), fallback[c])
    model_lum = model.mean(axis=2)
    d = np.abs(img - model).max(axis=2)

    # 2. Foreground.
    neutral = sat < 14
    # Light, weakly tinted pixels darker than the backdrop are contact
    # shadows (they pick up a warm/cool cast from the object above them).
    shadowish = (lum > 180) & (sat < 42) & (model_lum - lum > 2)
    fg = (~neutral & (d > 10)) | (lum < 150)
    fg = ndimage.binary_opening(fg, iterations=1)

    # Pale regions sitting entirely in the bottom band of the artwork are
    # contact shadows, not objects: demote them. Pale parts higher up
    # (pages, pastel shapes, light clothing) stay; enclosed ones are
    # restored by the hole filling below.
    demoted = np.zeros_like(fg)
    ys = np.nonzero(fg.any(axis=1))[0]
    if shadows and len(ys):
        top, height = ys.min(), ys.max() - ys.min() + 1
        pale = fg & (lum > 140) & (sat < 45) & (model_lum - lum > 2)
        # Erode first so thin bridges to pale object faces don't join a
        # shadow to the object, then grow the selection back.
        pl, pn = ndimage.label(ndimage.binary_erosion(pale, iterations=2))
        selected = np.zeros_like(pale)
        for i, sl in enumerate(ndimage.find_objects(pl), start=1):
            if sl is None:
                continue
            if sl[0].start >= top + 0.72 * height and sl[0].stop >= top + 0.9 * height:
                selected |= pl == i
        demoted = ndimage.binary_dilation(selected, iterations=3) & pale
        fg &= ~demoted
    lab, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = np.isin(lab, np.nonzero(sizes >= 40)[0] + 1)

    filled = ndimage.binary_fill_holes(fg)
    holes = filled & ~fg
    hl, hn = ndimage.label(holes)
    for i in range(1, hn + 1):
        comp = hl == i
        # Background-looking enclosed areas stay transparent.
        if not (comp.sum() > 150 and d[comp].mean() < 7):
            fg |= comp

    # 3. Alpha: opaque foreground, feathered 2px edge, translucent shadows.
    alpha = fg.astype(np.float32)
    shadow = np.clip((model_lum - lum) / np.maximum(model_lum, 1) * 1.7, 0, 0.45)
    shadow = np.where(fg | ~(neutral | shadowish | demoted), 0, shadow)
    shadow[shadow < 0.03] = 0

    ring = ndimage.binary_dilation(fg, iterations=2) & ~fg
    ring_alpha = np.clip(d / 24.0, 0, 1)
    if shadows:
        # Edge pixels that are really shadow get shadow opacity, not a halo.
        ring_alpha = np.where(shadowish | neutral | demoted, shadow, ring_alpha)

    out = np.zeros((h, w, 4), dtype=np.float32)
    out[..., :3] = img
    # Shadow pixels become ink at partial opacity.
    shadow_only = ~fg & ~ring & (shadow > 0)
    out[shadow_only, :3] = INK
    alpha = np.where(shadow_only, shadow, alpha)
    alpha = np.where(ring, np.maximum(ring_alpha, shadow), alpha)
    out[..., 3] = alpha * 255
    return out.clip(0, 255).astype(np.uint8)


def fit(rgba: np.ndarray, width: int, height: int, pad: float, anchor: float) -> Image.Image:
    a = rgba[..., 3]
    ys, xs = np.nonzero(a > 6)
    if len(xs) == 0:
        raise ValueError('image is empty after cut-out')
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    inner_w, inner_h = width * (1 - 2 * pad), height * (1 - 2 * pad)
    scale = min(inner_w / crop.width, inner_h / crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    crop = crop.resize(size, Image.LANCZOS)
    canvas = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    x = (width - size[0]) // 2
    top, bottom = height * pad, height * (1 - pad) - size[1]
    y = round(top + (bottom - top) * anchor)
    canvas.alpha_composite(crop, (x, y))
    return canvas


def contact_sheet(paths, dest):
    swatches = [(200, 236, 100), (242, 177, 220), (1, 42, 254), (31, 33, 39), (245, 245, 242)]
    cell = 220
    sheet = Image.new('RGB', (cell * len(swatches), cell * len(paths)), 'white')
    for r, p in enumerate(paths):
        im = Image.open(p).convert('RGBA')
        im.thumbnail((cell - 20, cell - 20))
        for c, col in enumerate(swatches):
            bgc = Image.new('RGBA', (cell, cell), col + (255,))
            bgc.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
            sheet.paste(bgc.convert('RGB'), (c * cell, r * cell))
    sheet.save(dest)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--preview', type=pathlib.Path)
    args = ap.parse_args()
    done = []
    for src in sorted(SRC.glob('*')):
        name = src.stem
        if name not in TARGETS:
            print(f'skip {src.name}: unknown asset name')
            continue
        folder, w, h, pad, anchor = TARGETS[name]
        flat = folder == 'onboarding'  # flat illustrations have no shadows
        rgba = cut_out(np.asarray(Image.open(src).convert('RGB')), shadows=not flat)
        out = OUT / folder / f'{name}.png'
        fit(rgba, w, h, pad, anchor).save(out, optimize=True)
        done.append(out)
        print(f'{name}: {w}x{h} -> {out.relative_to(ROOT)}')
    if args.preview and done:
        args.preview.mkdir(parents=True, exist_ok=True)
        for i in range(0, len(done), 6):
            contact_sheet(done[i:i + 6], args.preview / f'sheet_{i // 6}.png')


if __name__ == '__main__':
    main()


def derive_brand():
    """Builds the launcher icon, adaptive-icon foreground and splash mark
    from the Apprentice badge (a sprouting plant) until dedicated brand art
    exists. Re-run after replacing the badge to refresh them."""
    plant = Image.open(OUT / 'badges' / 'badge_apprentice.png').convert('RGBA')
    bbox = plant.getbbox()
    plant = plant.crop(bbox)

    def place(size, fraction, background=None):
        canvas = Image.new('RGBA', (size, size), background or (0, 0, 0, 0))
        p = plant.copy()
        p.thumbnail((int(size * fraction), int(size * fraction)), Image.LANCZOS)
        canvas.alpha_composite(p, ((size - p.width) // 2, (size - p.height) // 2))
        return canvas

    brand = OUT / 'brand'
    place(1024, 0.72, (14, 16, 28, 255)).convert('RGB').save(brand / 'app_icon.png')
    place(1024, 0.56).save(brand / 'app_icon_foreground.png')
    place(1024, 0.84).save(brand / 'splash_logo.png')
    print('brand: app_icon, app_icon_foreground, splash_logo')


if __name__ == '__main__' and not any(
    (SRC / f'{n}.jpg').exists() or (SRC / f'{n}.png').exists()
    for n in ('app_icon', 'splash_logo')
):
    derive_brand()
