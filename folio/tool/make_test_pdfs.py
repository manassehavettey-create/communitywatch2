"""Generates PDFs used by Folio's tests and manual QA.

  python3 tool/make_test_pdfs.py <out_dir> [--large]

* sample_book.pdf  – 12 pages, title/author metadata, a 3-chapter outline.
* scanned.pdf      – 3 image-only pages (no text layer), like a scan.
* untitled.pdf     – no metadata, no outline.
* large_book.pdf   – (--large) 1,200 pages, 40 chapters, embedded photos (~30 MB).
"""
import os
import random
import sys

from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

WORDS = ("light garden season water root leaf quiet morning shadow river stone "
         "memory window reading margin letter harvest orchard winter summer field "
         "cloud meadow lantern thread paper ink story chapter silence").split()


def para(rng, n):
    return " ".join(rng.choice(WORDS) for _ in range(n)).capitalize() + "."


def write_text(c, rng, lines, y=760):
    t = c.beginText(64, y)
    t.setFont("Times-Roman", 12)
    t.setLeading(17)
    for line in lines:
        t.textLine(line)
    c.drawText(t)


def wrap(text, width=80):
    out, cur = [], ""
    for w in text.split():
        if len(cur) + len(w) + 1 > width:
            out.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        out.append(cur)
    return out


def sample(path):
    rng = random.Random(1)
    c = canvas.Canvas(path, pagesize=A4)
    c.setTitle("The Quiet Garden")
    c.setAuthor("Ada Winters")
    chapters = {1: "Chapter 1 · Seeds", 5: "Chapter 2 · Light", 9: "Chapter 3 · Harvest"}
    for p in range(1, 13):
        if p in chapters:
            c.bookmarkPage(f"p{p}")
            c.addOutlineEntry(chapters[p], f"p{p}", level=0)
            c.setFont("Helvetica-Bold", 22)
            c.drawString(64, 790, chapters[p])
        lines = []
        for _ in range(6):
            lines += wrap(para(rng, 60)) + [""]
        if p == 6:
            lines = ["Photosynthesis turns sunlight into sugar inside the thylakoid membrane."] + lines
        write_text(c, rng, lines, 750)
        c.setFont("Helvetica", 9)
        c.drawCentredString(A4[0] / 2, 30, str(p))
        c.showPage()
    c.save()


def scanned(path):
    rng = random.Random(2)
    c = canvas.Canvas(path, pagesize=A4)
    for _ in range(3):
        # Grey "text lines" drawn as shapes — no extractable text.
        for i in range(34):
            w = rng.randint(300, 460)
            c.setFillGray(0.25)
            c.rect(64, 780 - i * 21, w, 7, stroke=0, fill=1)
        c.showPage()
    c.save()


def untitled(path):
    rng = random.Random(3)
    c = canvas.Canvas(path, pagesize=A4)
    for _ in range(2):
        write_text(c, rng, wrap(para(rng, 120)))
        c.showPage()
    c.save()


def large(path, out_dir):
    rng = random.Random(4)
    imgs = []
    try:
        from PIL import Image
        for i in range(10):
            p = os.path.join(out_dir, f"_noise{i}.jpg")
            Image.frombytes("RGB", (1600, 1200), os.urandom(1600 * 1200 * 3)).save(p, quality=92)
            imgs.append(p)
    except ImportError:
        pass
    c = canvas.Canvas(path, pagesize=A4)
    c.setTitle("A Very Long Book")
    c.setAuthor("Folio QA")
    for p in range(1, 1201):
        if (p - 1) % 30 == 0:
            ch = (p - 1) // 30 + 1
            c.bookmarkPage(f"p{p}")
            c.addOutlineEntry(f"Chapter {ch}", f"p{p}", level=0)
            c.setFont("Helvetica-Bold", 22)
            c.drawString(64, 790, f"Chapter {ch}")
        if imgs and p % 120 == 0:
            c.drawImage(ImageReader(imgs[(p // 120) % len(imgs)]), 64, 380, width=460, height=345)
            write_text(c, rng, wrap(para(rng, 50)), 360)
        else:
            lines = []
            for _ in range(5):
                lines += wrap(para(rng, 70)) + [""]
            if p == 777:
                lines = ["The lighthouse keeper counted seven hundred seventy seven waves."] + lines
            write_text(c, rng, lines, 750)
        c.setFont("Helvetica", 9)
        c.drawCentredString(A4[0] / 2, 30, str(p))
        c.showPage()
    c.save()
    for p in imgs:
        os.remove(p)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sample(os.path.join(out, "sample_book.pdf"))
    scanned(os.path.join(out, "scanned.pdf"))
    untitled(os.path.join(out, "untitled.pdf"))
    if "--large" in sys.argv:
        large(os.path.join(out, "large_book.pdf"), out)
