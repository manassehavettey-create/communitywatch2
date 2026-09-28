#!/usr/bin/env python3
"""Turns the generated artwork in design/raw/ into app assets.

The generator returned every image as a 768x1376 JPEG, and painted a
checkerboard where transparency was requested. This script:
  * crops each subject to its bounding box and pads it to the target size
  * removes painted checkerboards by flood-filling neutral-grey pixels from
    the image border (artwork colours and ink outlines stop the fill)
  * redraws an ink outline where a dark checkerboard ate the original one
  * writes PNG/JPG files into assets/images/

Requires Pillow:  pip install pillow
Run from bible_app/:  python3 tools/images/process_assets.py
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "design" / "raw"
OUT = ROOT / "assets" / "images"

INK = (20, 20, 20)
PAPER = (246, 240, 230)

# Neutral pixels (max channel minus min channel) at or below this are
# treated as checkerboard when connected to the border.
CHROMA_LIMIT = 7


def chroma(px: tuple[int, int, int]) -> int:
    return max(px) - min(px)


def remove_checkerboard(
    im: Image.Image, *, dark: bool, chroma_limit: int = CHROMA_LIMIT
) -> Image.Image:
    """Returns RGBA with the border-connected neutral background cleared."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    bg = bytearray(w * h)

    def is_bg(x: int, y: int) -> bool:
        p = px[x, y]
        if chroma(p) > chroma_limit:
            return False
        # Light checkerboards: stop at ink outlines. Dark ones contain
        # black squares, so every neutral tone counts as background.
        return True if dark else sum(p) / 3 >= 120

    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if bg[i] or not is_bg(x, y):
            continue
        bg[i] = 1
        if x > 0:
            q.append((x - 1, y))
        if x < w - 1:
            q.append((x + 1, y))
        if y > 0:
            q.append((x, y - 1))
        if y < h - 1:
            q.append((x, y + 1))

    alpha = Image.new("L", (w, h))
    alpha.putdata([0 if b else 255 for b in bg])
    alpha = keep_main_shapes(alpha)
    # Drop JPEG halo pixels on the edge, then soften by a pixel.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)

    if dark:
        # The dark checkerboard removed the outer ink line; draw a new one.
        ring = alpha.filter(ImageFilter.MaxFilter(7))
        stroke = Image.new("RGBA", (w, h), INK + (0,))
        stroke.putalpha(ring)
        stroke.alpha_composite(out)
        out = stroke
    return out


def keep_main_shapes(alpha: Image.Image, min_share: float = 0.01) -> Image.Image:
    """Clears specks: keeps only opaque regions at least [min_share] of the
    largest region's size."""
    w, h = alpha.size
    a = alpha.load()
    label = [0] * (w * h)
    sizes: list[int] = [0]
    for sy in range(h):
        for sx in range(w):
            if a[sx, sy] == 0 or label[sy * w + sx]:
                continue
            lid = len(sizes)
            sizes.append(0)
            q = deque([(sx, sy)])
            label[sy * w + sx] = lid
            while q:
                x, y = q.popleft()
                sizes[lid] += 1
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and not label[ny * w + nx]:
                        label[ny * w + nx] = lid
                        q.append((nx, ny))
    biggest = max(sizes)
    keep = {i for i, n in enumerate(sizes) if i and n >= biggest * min_share}
    out = Image.new("L", (w, h))
    out.putdata([255 if l in keep else 0 for l in label])
    return out


def crop_to_subject(im: Image.Image, pad: float = 0.08) -> Image.Image:
    box = im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if box is None:
        return im
    x0, y0, x1, y1 = box
    side = max(x1 - x0, y1 - y0)
    side = int(side * (1 + pad * 2))
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im.crop(box), (side // 2 - (cx - x0), side // 2 - (cy - y0)))
    return canvas


def fit(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    return im.resize(size, Image.LANCZOS)


def save_png(im: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    print(f"  {rel}  {im.size[0]}x{im.size[1]}  {path.stat().st_size // 1024} KB")


def save_jpg(im: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(path, quality=88, optimize=True, progressive=True)
    print(f"  {rel}  {im.size[0]}x{im.size[1]}  {path.stat().st_size // 1024} KB")


def raw(name: str) -> Image.Image:
    return Image.open(RAW / f"{name}.jpg")


def main() -> None:
    print("Brand")
    # App icon: square crop around the mark on its solid ink background.
    icon = raw("app_icon").convert("RGB")
    w, h = icon.size
    top = (h - w) // 2 - 10
    save_png(fit(icon.crop((0, top, w, top + w)), (1024, 1024)), "brand/app_icon.png")

    fg = crop_to_subject(remove_checkerboard(raw("app_icon_foreground"), dark=False), pad=0.26)
    save_png(fit(fg, (1024, 1024)), "brand/app_icon_foreground.png")

    splash = crop_to_subject(remove_checkerboard(raw("splash_mark"), dark=False), pad=0.2)
    save_png(fit(splash, (1152, 1152)), "brand/splash_mark.png")

    print("Onboarding (4:5, subject kept on its paper background)")
    for name in ["onboarding_read", "onboarding_keep", "onboarding_pray", "onboarding_rhythm", "welcome_reader"]:
        im = raw(name).convert("RGB")
        w, h = im.size
        ch = int(w * 5 / 4)
        top = max(0, min(h - ch, (h - ch) // 2))
        save_jpg(fit(im.crop((0, top, w, top + ch)), (960, 1200)), f"onboarding/{name}.jpg")

    print("Empty states (transparent)")
    dark_bg = {"empty_search", "empty_notes"}
    # The journal art has a warm drop shadow painted over its checkerboard.
    limits = {"empty_journal": 26}
    for name in ["empty_journal", "empty_prayer", "empty_search", "empty_notes", "empty_saved", "offline_state"]:
        cut = remove_checkerboard(
            raw(name), dark=name in dark_bg, chroma_limit=limits.get(name, CHROMA_LIMIT)
        )
        im = crop_to_subject(cut)
        save_png(fit(im, (800, 800)), f"empty/{name}.png")

    print("Scripture card backgrounds (9:16)")
    for name in ["card_botanical_corner", "card_dusk"]:
        im = raw(name).convert("RGB")
        save_jpg(fit(im, (1080, 1920)), f"cards/{name}.jpg")


if __name__ == "__main__":
    main()
