#!/usr/bin/env python3
"""Validates the bundled Bible assets before the app is allowed to use them.

Checks, per translation:
  * schema fields present, 66 books in canonical order with correct ids
  * every book has the canonical chapter count, numbered 1..N
  * KJV per-book verse totals equal the reference table in canon.py (31,102)
  * KJV per-chapter verse counts equal an independent second dataset
    (scrollmapper/bible_databases KJV) chapter by chapter
  * every other translation's per-chapter verse counts equal KJV except for
    the documented versification differences below, and no verse is empty
    except the verses that translation deliberately omits
  * text hygiene: no stray markup, doubled spaces or edge whitespace, and
    balanced [supplied word] brackets
  * paragraph and heading anchors point at verses that exist
  * exact-text spot checks of well-known verses

Exit code is non-zero if any check fails.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import canon
from build_bible_data import ASSETS, fetch

SECOND_KJV = "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/KJV.json"

# WEB follows the Majority Text in these places. Values are WEB verse counts.
WEB_VERSE_COUNT_DIFFS = {("ROM", 14): 26, ("ROM", 16): 25}
# Verse numbers WEB keeps but leaves without text (omitted on text-critical
# grounds; Romans 16:25-27 is printed at 14:24-26).
WEB_EMPTY_VERSES = {("LUK", 17, 36), ("ACT", 8, 37), ("ACT", 15, 34), ("ACT", 24, 7), ("ROM", 16, 25)}
# ASV and BSB (critical-text translations) leave these verse numbers empty.
CRITICAL_TEXT_EMPTY_VERSES = {
    ("MAT", 17, 21), ("MAT", 18, 11), ("MAT", 23, 14), ("MRK", 7, 16), ("MRK", 9, 44),
    ("MRK", 9, 46), ("MRK", 11, 26), ("MRK", 15, 28), ("LUK", 17, 36), ("LUK", 23, 17),
    ("JHN", 5, 4), ("ACT", 8, 37), ("ACT", 15, 34), ("ACT", 24, 7), ("ACT", 28, 29),
    ("ROM", 16, 24),
}
ALLOWED_EMPTY = {"kjv": set(), "web": WEB_EMPTY_VERSES, "asv": CRITICAL_TEXT_EMPTY_VERSES,
                 "bsb": CRITICAL_TEXT_EMPTY_VERSES}
VERSE_COUNT_DIFFS = {"kjv": {}, "web": WEB_VERSE_COUNT_DIFFS, "asv": {}, "bsb": {}}

SPOT_CHECKS = {
    "kjv": {
        ("GEN", 1, 1): "In the beginning God created the heaven and the earth.",
        ("PSA", 23, 1): "The LORD [is] my shepherd; I shall not want.",
        ("JHN", 3, 16): "For God so loved the world, that he gave his only begotten Son, that "
                        "whosoever believeth in him should not perish, but have everlasting life.",
        ("JHN", 11, 35): "Jesus wept.",
        ("REV", 22, 21): "The grace of our Lord Jesus Christ [be] with you all. Amen.",
    },
    "web": {
        ("GEN", 1, 1): "In the beginning, God created the heavens and the earth.",
        ("PSA", 23, 1): "Yahweh is my shepherd:\nI shall lack nothing.",
        ("JHN", 3, 16): "For God so loved the world, that he gave his one and only Son, that "
                        "whoever believes in him should not perish, but have eternal life.",
        ("JHN", 11, 35): "Jesus wept.",
        ("REV", 22, 21): "The grace of the Lord Jesus Christ be with all the saints. Amen.",
    },
    "asv": {
        ("GEN", 1, 1): "In the beginning God created the heavens and the earth.",
        ("PSA", 23, 1): "A Psalm of David. Jehovah is my shepherd; I shall not want.",
        ("JHN", 3, 16): "For God so loved the world, that he gave his only begotten Son, that "
                        "whosoever believeth on him should not perish, but have eternal life.",
        ("JHN", 11, 35): "Jesus wept.",
        ("REV", 22, 21): "The grace of the Lord Jesus be with the saints. Amen.",
    },
    "bsb": {
        ("GEN", 1, 1): "In the beginning God created the heavens and the earth.",
        ("PSA", 23, 1): "A Psalm of David. The LORD is my shepherd; I shall not want.",
        ("JHN", 3, 16): "For God so loved the world that He gave His one and only Son, that "
                        "everyone who believes in Him shall not perish but have eternal life.",
        ("JHN", 11, 35): "Jesus wept.",
        ("REV", 22, 21): "The grace of the Lord Jesus be with all the saints. Amen.",
    },
}

REQUIRED_FIELDS = ("schema", "id", "abbreviation", "name", "language", "license", "supplied_words",
                   "source", "books")
STRAY_MARKUP = re.compile(r"[#<>{}\\*|_]|\s{2,}")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def check(self, ok: bool, message: str) -> None:
        if not ok:
            self.errors.append(message)


def chapter_counts(doc: dict) -> dict[tuple[str, int], int]:
    return {(b["id"], c["n"]): len(c["verses"]) for b in doc["books"] for c in b["chapters"]}


def second_kjv_counts() -> dict[tuple[str, int], int]:
    data = json.loads(fetch(SECOND_KJV))
    return {
        (canon.book_id_for(b["name"]), c["chapter"]): len(c["verses"])
        for b in data["books"]
        for c in b["chapters"]
    }


def verse(doc: dict, book: str, ch: int, v: int) -> str:
    b = next(b for b in doc["books"] if b["id"] == book)
    return b["chapters"][ch - 1]["verses"][v - 1]


def verify_structure(doc: dict, r: Report) -> None:
    tid = doc.get("id", "?")
    for field in REQUIRED_FIELDS:
        r.check(field in doc, f"{tid}: missing field {field!r}")
    r.check(doc.get("schema") == 1, f"{tid}: unexpected schema {doc.get('schema')}")
    books = doc.get("books", [])
    r.check(len(books) == canon.TOTAL_BOOKS, f"{tid}: {len(books)} books, expected 66")
    for expected, book in zip(canon.BOOKS, books):
        r.check(book["id"] == expected.id, f"{tid}: book {book['id']} where {expected.id} expected")
        r.check(book["testament"] == expected.testament, f"{tid}: {book['id']} testament")
        numbers = [c["n"] for c in book["chapters"]]
        r.check(numbers == list(range(1, expected.chapters + 1)),
                f"{tid}: {book['id']} has chapters {numbers[:3]}…{numbers[-3:]}, expected 1..{expected.chapters}")
        for c in book["chapters"]:
            count = len(c["verses"])
            r.check(count > 0, f"{tid}: {book['id']} {c['n']} has no verses")
            for p in c.get("paragraphs", []):
                r.check(1 <= p <= count, f"{tid}: {book['id']} {c['n']} paragraph at missing verse {p}")
            for h in c.get("headings", []):
                anchor = h.get("before", h.get("after"))
                r.check(anchor is not None and 1 <= anchor <= count and h["text"],
                        f"{tid}: {book['id']} {c['n']} bad heading {h}")


def verify_text(doc: dict, r: Report, allowed_empty: set) -> None:
    tid = doc["id"]
    for b in doc["books"]:
        for c in b["chapters"]:
            for i, text in enumerate(c["verses"], start=1):
                ref = f"{tid}: {b['id']} {c['n']}:{i}"
                if (b["id"], c["n"], i) in allowed_empty:
                    r.check(text == "", f"{ref} expected to be omitted but has text")
                    continue
                r.check(bool(text), f"{ref} is empty")
                r.check(text == text.strip(), f"{ref} has edge whitespace")
                lines = text.split("\n")
                r.check(all(line and line == line.strip() for line in lines), f"{ref} has a blank/untrimmed line")
                r.check(not STRAY_MARKUP.search(text), f"{ref} has stray markup: {text[:60]!r}")
                if doc["supplied_words"]:
                    # Brackets mark supplied words, so they must pair up within
                    # a verse. (ASV uses a lone "[" typographically, e.g. "[Selah".)
                    r.check(text.count("[") == text.count("]"), f"{ref} has unbalanced brackets")


def verify_kjv(doc: dict, r: Report) -> None:
    counts = chapter_counts(doc)
    total = sum(counts.values())
    r.check(total == canon.TOTAL_KJV_VERSES, f"kjv: {total} verses, expected {canon.TOTAL_KJV_VERSES}")
    for book in canon.BOOKS:
        got = sum(n for (bid, _), n in counts.items() if bid == book.id)
        r.check(got == book.kjv_verses, f"kjv: {book.id} has {got} verses, reference says {book.kjv_verses}")
    second = second_kjv_counts()
    r.check(set(second) == set(counts), "kjv: chapter set differs from second KJV dataset")
    for key, n in counts.items():
        r.check(second.get(key) == n, f"kjv: {key} has {n} verses, second dataset has {second.get(key)}")
    text = " ".join(v for b in doc["books"] for c in b["chapters"] for v in c["verses"])
    lord = len(re.findall(r"\bLORD\b", text))
    r.check(lord > 6000, f"kjv: only {lord} occurrences of LORD; small caps were probably flattened")


def verify_versification(doc: dict, kjv: dict, r: Report) -> None:
    counts, kjv_counts = chapter_counts(doc), chapter_counts(kjv)
    diffs = VERSE_COUNT_DIFFS[doc["id"]]
    for key, n in counts.items():
        expected = diffs.get(key, kjv_counts.get(key))
        r.check(n == expected, f"{doc['id']}: {key} has {n} verses, expected {expected}")


def verify_spot_checks(doc: dict, r: Report) -> None:
    for (book, ch, v), expected in SPOT_CHECKS[doc["id"]].items():
        got = verse(doc, book, ch, v)
        r.check(got == expected, f"{doc['id']}: {book} {ch}:{v} is {got!r}")


def main() -> int:
    r = Report()
    docs = {}
    manifest = json.loads((ASSETS / "translations.json").read_text(encoding="utf-8"))
    listed = sorted(t["id"] for t in manifest["available"])
    r.check(listed == sorted(SPOT_CHECKS), f"manifest lists {listed}, verifier knows {sorted(SPOT_CHECKS)}")
    for tid in SPOT_CHECKS:
        path = ASSETS / f"{tid}.json"
        if not path.exists():
            r.check(False, f"{path} is missing; run build_bible_data.py")
            continue
        docs[tid] = json.loads(path.read_text(encoding="utf-8"))

    for tid, doc in docs.items():
        verify_structure(doc, r)
        verify_text(doc, r, allowed_empty=ALLOWED_EMPTY[tid])
        verify_spot_checks(doc, r)
        if tid == "kjv":
            verify_kjv(doc, r)
        elif "kjv" in docs:
            verify_versification(doc, docs["kjv"], r)

    for tid, doc in docs.items():
        counts = chapter_counts(doc)
        chapters = doc["books"]
        headings = sum(len(c.get("headings", [])) for b in chapters for c in b["chapters"])
        paragraphs = sum(len(c.get("paragraphs", [])) for b in chapters for c in b["chapters"])
        print(f"{doc['abbreviation']}: {len(chapters)} books, {len(counts)} chapters, "
              f"{sum(counts.values())} verses, {paragraphs} paragraph starts, {headings} headings")

    if r.errors:
        print(f"\nFAILED with {len(r.errors)} problem(s):")
        for e in r.errors[:200]:
            print(f"  - {e}")
        return 1
    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
