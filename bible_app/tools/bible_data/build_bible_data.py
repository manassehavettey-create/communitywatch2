#!/usr/bin/env python3
"""Builds the bundled Bible text assets (assets/bible/<id>.json).

One-time, offline-friendly script: every download is cached under .cache/ so
re-running never re-fetches. Standard library only.

Sources (--source):
  mirror     (default) Pinned npm tarballs of public-domain texts:
               KJV  -> npm "kjv" 1.0.0 (Unlicense / public domain), 1769 text
                       with supplied words in [brackets], paragraph marks,
                       Psalm titles and epistle colophons.
               WEB  -> npm "world-english-bible" 1.0.1, a structured export
                       of eBible.org's public-domain World English Bible with
                       paragraphs, poetry lines and Psalm titles.
  bible-api  bible-api.com /data endpoints, chapter by chapter, throttled to
             its published limit (15 requests / 30 s). Plain verse text only
             (no paragraphs, headings or supplied-word marks).

Usage:
  python3 build_bible_data.py                     # all translations, mirror
  python3 build_bible_data.py --only web
  python3 build_bible_data.py --source bible-api  # needs bible-api.com access

Output format (schema 1) is documented in README.md next to this file.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
import tarfile
import time
import urllib.error
import urllib.request
from pathlib import Path

import canon

HERE = Path(__file__).resolve().parent
CACHE = HERE / ".cache"
ASSETS = HERE.parent.parent / "assets" / "bible"

SCHEMA_VERSION = 1

MIRRORS = {
    "kjv": {
        "url": "https://registry.npmjs.org/kjv/-/kjv-1.0.0.tgz",
        "sha256": "7d8673b737a1be6623d211cae257db6638dcdee6c1e837e31581a09411556465",
        "package": "kjv@1.0.0",
    },
    "web": {
        "url": "https://registry.npmjs.org/world-english-bible/-/world-english-bible-1.0.1.tgz",
        "sha256": "492d4692c06f0a64125d197a132a6f17a6448ac90ee1fd86ae50f2f6e8db8245",
        "package": "world-english-bible@1.0.1",
    },
}

TRANSLATIONS = {
    "kjv": {
        "id": "kjv",
        "abbreviation": "KJV",
        "name": "King James Version",
        "edition": "1769 Oxford standard text",
        "language": "en",
        "license": "Public Domain",
        "license_note": (
            "Public domain worldwide except the United Kingdom, where the "
            "Crown's perpetual rights apply to printed editions."
        ),
    },
    "web": {
        "id": "web",
        "abbreviation": "WEB",
        "name": "World English Bible",
        "edition": "eBible.org WEB (Protestant canon)",
        "language": "en",
        "license": "Public Domain",
        "license_note": (
            "Public domain. \"World English Bible\" is a trademark of eBible.org; "
            "the name may be used only for the unaltered text."
        ),
    },
}

# Shown in the translation selector as "not available yet". These are under
# copyright and need a redistribution licence from the publisher.
NOT_AVAILABLE = [
    {"abbreviation": "NIV", "name": "New International Version", "reason": "Requires a licence from Biblica"},
    {"abbreviation": "ESV", "name": "English Standard Version", "reason": "Requires a licence from Crossway"},
    {"abbreviation": "NKJV", "name": "New King James Version", "reason": "Requires a licence from Thomas Nelson"},
    {"abbreviation": "NLT", "name": "New Living Translation", "reason": "Requires a licence from Tyndale House"},
    {"abbreviation": "NASB", "name": "New American Standard Bible", "reason": "Requires a licence from The Lockman Foundation"},
    {"abbreviation": "CSB", "name": "Christian Standard Bible", "reason": "Requires a licence from Holman Bible Publishers"},
]

USER_AGENT = "bible-app-data-builder/1.0 (one-time dataset build)"


# --------------------------------------------------------------------------
# Download helpers (cached)
# --------------------------------------------------------------------------


def _cache_path(url: str) -> Path:
    digest = hashlib.sha256(url.encode()).hexdigest()[:24]
    return CACHE / digest


def fetch(url: str, *, retries: int = 5) -> bytes:
    path = _cache_path(url)
    if path.exists():
        return path.read_bytes()
    CACHE.mkdir(exist_ok=True)
    delay = 2.0
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            path.write_bytes(data)
            return data
        except urllib.error.HTTPError as err:
            # 404 is final; 429/5xx are worth waiting out.
            if err.code == 404 or attempt == retries - 1:
                raise
            retry_after = err.headers.get("Retry-After")
            wait = float(retry_after) if retry_after and retry_after.isdigit() else delay
            print(f"  HTTP {err.code} for {url}; retrying in {wait:.0f}s", file=sys.stderr)
            time.sleep(wait)
            delay *= 2
        except urllib.error.URLError as err:
            if attempt == retries - 1:
                raise
            print(f"  {err.reason} for {url}; retrying in {delay:.0f}s", file=sys.stderr)
            time.sleep(delay)
            delay *= 2
    raise RuntimeError("unreachable")


def read_tarball(url: str, expected_sha256: str) -> tuple[dict[str, bytes], str]:
    raw = fetch(url)
    sha = hashlib.sha256(raw).hexdigest()
    if sha != expected_sha256:
        raise ValueError(
            f"{url} has sha256 {sha}, expected {expected_sha256}. "
            "The upstream package changed; review it before updating the pin."
        )
    files: dict[str, bytes] = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar:
        for member in tar.getmembers():
            if member.isfile():
                extracted = tar.extractfile(member)
                assert extracted is not None
                files[member.name] = extracted.read()
    return files, sha


# --------------------------------------------------------------------------
# Text normalisation
# --------------------------------------------------------------------------

_SPACES = re.compile("[ \t\u00a0]+")


def clean(text: str) -> str:
    return _SPACES.sub(" ", text).strip()


class BookBuilder:
    """Accumulates one book's verses, paragraph starts and headings."""

    def __init__(self, book: canon.Book):
        self.book = book
        self.chapters: dict[int, dict] = {}

    def chapter(self, n: int) -> dict:
        return self.chapters.setdefault(
            n, {"n": n, "verses": {}, "paragraphs": [], "headings": []}
        )

    def add_text(self, ch: int, v: int, text: str, *, joiner: str = " ") -> None:
        verses = self.chapter(ch)["verses"]
        text = clean(text)
        if not text:
            verses.setdefault(v, "")
            return
        if verses.get(v):
            verses[v] = verses[v] + joiner + text
        else:
            verses[v] = text

    def mark_paragraph(self, ch: int, v: int) -> None:
        paragraphs = self.chapter(ch)["paragraphs"]
        if v not in paragraphs:
            paragraphs.append(v)

    def add_heading(self, ch: int, text: str, *, before: int | None = None,
                    after: int | None = None) -> None:
        heading = {"text": clean(text)}
        if before is not None:
            heading["before"] = before
        if after is not None:
            heading["after"] = after
        self.chapter(ch)["headings"].append(heading)

    def build(self) -> dict:
        chapters = []
        for n in sorted(self.chapters):
            ch = self.chapters[n]
            count = max(ch["verses"]) if ch["verses"] else 0
            verses = [ch["verses"].get(i, "") for i in range(1, count + 1)]
            out: dict = {"n": n, "verses": verses}
            if ch["paragraphs"]:
                out["paragraphs"] = sorted(ch["paragraphs"])
            if ch["headings"]:
                out["headings"] = ch["headings"]
            chapters.append(out)
        b = self.book
        return {
            "id": b.id,
            "name": b.name,
            "abbr": b.abbr,
            "testament": b.testament,
            "chapters": chapters,
        }


def _ordered(builders: dict[str, BookBuilder]) -> list[dict]:
    return [builders[b.id].build() for b in canon.BOOKS if b.id in builders]


# --------------------------------------------------------------------------
# Mirror source: KJV (npm "kjv")
# --------------------------------------------------------------------------

_REF = re.compile(r"^(?P<book>.+) (?P<ch>\d+):(?P<v>\d+)$")


def build_kjv_mirror() -> tuple[list[dict], dict]:
    mirror = MIRRORS["kjv"]
    files, sha = read_tarball(mirror["url"], mirror["sha256"])
    verses = json.loads(files["package/json/verses-1769.json"])
    layout = json.loads(files["package/json/layout-1769.json"])

    builders: dict[str, BookBuilder] = {}
    current: BookBuilder | None = None
    chapter = 0
    last_verse = 0
    pending: list[str] = []  # TXT lines waiting for the next verse

    def flush_pending_as_after() -> None:
        # Text after a book's last verse is an epistle colophon.
        if current is not None and pending:
            for text in pending:
                current.add_heading(chapter, text.lstrip("# "), after=last_verse)
        pending.clear()

    for entry in layout:
        kind, value = entry[0], (entry[1] if len(entry) > 1 else None)
        if kind == "BOOK":
            flush_pending_as_after()
            book = canon.BY_ID[canon.book_id_for(value)]
            current = builders.setdefault(book.id, BookBuilder(book))
            chapter = 0
        elif kind == "CHAPTER":
            if current is None:
                continue
            flush_pending_as_after()
            chapter = int(value)
            last_verse = 0
        elif kind == "TXT":
            # Before Genesis (the preface) and between the testaments there is
            # no current chapter; that front matter is not Scripture text.
            if current is not None and chapter:
                pending.append(value)
        elif kind == "PARAGRAPH":
            continue  # paragraph starts are carried by the "#" verse prefix
        elif kind == "VERSE":
            m = _REF.match(value)
            if not m or current is None:
                raise ValueError(f"Unexpected verse ref {value!r}")
            ch, v = int(m["ch"]), int(m["v"])
            text = verses[value]
            if text.startswith("#"):
                current.mark_paragraph(ch, v)
                text = text[1:]
            for heading in pending:
                current.add_heading(ch, heading, before=v)
            pending.clear()
            current.add_text(ch, v, text)
            last_verse = v
    # "THE END" after Revelation 22:21 is front/back matter, not a colophon.
    pending.clear()

    source = {
        "kind": "npm",
        "package": mirror["package"],
        "url": mirror["url"],
        "sha256": sha,
        "notes": "Words in [brackets] were supplied by the translators "
                 "(printed in italics in KJV editions).",
    }
    return _ordered(builders), source


# --------------------------------------------------------------------------
# Mirror source: WEB (npm "world-english-bible")
# --------------------------------------------------------------------------


def build_web_mirror() -> tuple[list[dict], dict]:
    mirror = MIRRORS["web"]
    files, sha = read_tarball(mirror["url"], mirror["sha256"])
    builders: dict[str, BookBuilder] = {}

    for name, raw in files.items():
        m = re.match(r"^package/json/(?P<book>[a-z0-9]+)\.json$", name)
        if not m:
            continue
        book = canon.BY_ID[canon.book_id_for(m["book"])]
        builder = builders.setdefault(book.id, BookBuilder(book))
        pending_headings: list[str] = []
        new_paragraph = False
        last: tuple[int, int] | None = None
        new_line = False

        for item in json.loads(raw):
            kind = item["type"]
            if kind == "header":
                pending_headings.append(item["value"])
            elif kind in ("paragraph start", "stanza start"):
                new_paragraph = True
            elif kind == "line break":
                new_line = True
            elif kind in ("paragraph text", "line text"):
                ch, v = item["chapterNumber"], item["verseNumber"]
                if pending_headings:
                    for heading in pending_headings:
                        builder.add_heading(ch, heading, before=v)
                    pending_headings.clear()
                if new_paragraph:
                    builder.mark_paragraph(ch, v)
                    new_paragraph = False
                # Poetry lines inside one verse keep their line break.
                joiner = "\n" if (kind == "line text" and new_line and last == (ch, v)) else " "
                builder.add_text(ch, v, item["value"], joiner=joiner)
                last = (ch, v)
                new_line = False
            # "paragraph end", "stanza end" and "break" carry no text.

    source = {
        "kind": "npm",
        "package": mirror["package"],
        "url": mirror["url"],
        "sha256": sha,
        "notes": "Poetry lines within a verse are separated by \\n.",
    }
    return _ordered(builders), source


# --------------------------------------------------------------------------
# bible-api.com source
# --------------------------------------------------------------------------

BIBLE_API = "https://bible-api.com/data/{translation}/{book}/{chapter}"
BIBLE_API_INTERVAL = 2.1  # seconds; the API allows 15 requests per 30 s


def build_from_bible_api(translation: str) -> tuple[list[dict], dict]:
    builders: dict[str, BookBuilder] = {}
    last_request = 0.0
    for book in canon.BOOKS:
        builder = builders.setdefault(book.id, BookBuilder(book))
        for chapter in range(1, book.chapters + 1):
            url = BIBLE_API.format(translation=translation, book=book.id, chapter=chapter)
            if not _cache_path(url).exists():
                wait = BIBLE_API_INTERVAL - (time.monotonic() - last_request)
                if wait > 0:
                    time.sleep(wait)
                last_request = time.monotonic()
            payload = json.loads(fetch(url))
            for verse in payload["verses"]:
                builder.add_text(chapter, int(verse["verse"]), verse["text"])
        print(f"  {translation.upper()} {book.name}: {book.chapters} chapters")
    source = {"kind": "bible-api.com", "url": BIBLE_API.split("{")[0]}
    return _ordered(builders), source


# --------------------------------------------------------------------------


def write_translation(tid: str, books: list[dict], source: dict) -> Path:
    ASSETS.mkdir(parents=True, exist_ok=True)
    doc = {"schema": SCHEMA_VERSION, **TRANSLATIONS[tid], "source": source, "books": books}
    path = ASSETS / f"{tid}.json"
    path.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return path


def write_manifest() -> Path:
    """Lists every bundled translation (whatever is on disk) plus the
    translations the selector shows as not available yet."""
    available = []
    for tid in sorted(TRANSLATIONS):
        path = ASSETS / f"{tid}.json"
        if not path.exists():
            continue
        doc = json.loads(path.read_text(encoding="utf-8"))
        meta = {k: doc[k] for k in ("id", "abbreviation", "name", "edition", "language", "license", "license_note")}
        meta["asset"] = f"assets/bible/{tid}.json"
        meta["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        meta["verses"] = sum(len(c["verses"]) for b in doc["books"] for c in b["chapters"])
        available.append(meta)
    manifest = {"schema": SCHEMA_VERSION, "default": "kjv", "available": available, "not_available": NOT_AVAILABLE}
    path = ASSETS / "translations.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", choices=["mirror", "bible-api"], default="mirror")
    parser.add_argument("--only", choices=sorted(TRANSLATIONS), action="append")
    args = parser.parse_args()

    for tid in args.only or sorted(TRANSLATIONS):
        print(f"Building {tid.upper()} from {args.source}…")
        if args.source == "bible-api":
            books, source = build_from_bible_api(tid)
        elif tid == "kjv":
            books, source = build_kjv_mirror()
        else:
            books, source = build_web_mirror()
        path = write_translation(tid, books, source)
        verses = sum(len(c["verses"]) for b in books for c in b["chapters"])
        print(f"  wrote {path.relative_to(HERE.parent.parent)}: {len(books)} books, {verses} verses, "
              f"{path.stat().st_size / 1e6:.1f} MB")
    print(f"  wrote {write_manifest().relative_to(HERE.parent.parent)}")
    print("Run verify_bible_data.py to validate the output.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
