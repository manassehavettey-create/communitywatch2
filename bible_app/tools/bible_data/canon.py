"""The 66-book Protestant canon used by every bundled translation.

Book ids are USFM codes so they stay stable across translations and sources.
`kjv_verses` is the standard KJV verse total per book (31,102 overall); the
verifier uses it as an independent reference that doesn't come from any of
the downloaded datasets.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Book:
    id: str
    name: str
    abbr: str
    testament: str  # "OT" or "NT"
    chapters: int
    kjv_verses: int


BOOKS: list[Book] = [
    Book("GEN", "Genesis", "Gen", "OT", 50, 1533),
    Book("EXO", "Exodus", "Exod", "OT", 40, 1213),
    Book("LEV", "Leviticus", "Lev", "OT", 27, 859),
    Book("NUM", "Numbers", "Num", "OT", 36, 1288),
    Book("DEU", "Deuteronomy", "Deut", "OT", 34, 959),
    Book("JOS", "Joshua", "Josh", "OT", 24, 658),
    Book("JDG", "Judges", "Judg", "OT", 21, 618),
    Book("RUT", "Ruth", "Ruth", "OT", 4, 85),
    Book("1SA", "1 Samuel", "1 Sam", "OT", 31, 810),
    Book("2SA", "2 Samuel", "2 Sam", "OT", 24, 695),
    Book("1KI", "1 Kings", "1 Kgs", "OT", 22, 816),
    Book("2KI", "2 Kings", "2 Kgs", "OT", 25, 719),
    Book("1CH", "1 Chronicles", "1 Chr", "OT", 29, 942),
    Book("2CH", "2 Chronicles", "2 Chr", "OT", 36, 822),
    Book("EZR", "Ezra", "Ezra", "OT", 10, 280),
    Book("NEH", "Nehemiah", "Neh", "OT", 13, 406),
    Book("EST", "Esther", "Esth", "OT", 10, 167),
    Book("JOB", "Job", "Job", "OT", 42, 1070),
    Book("PSA", "Psalms", "Ps", "OT", 150, 2461),
    Book("PRO", "Proverbs", "Prov", "OT", 31, 915),
    Book("ECC", "Ecclesiastes", "Eccl", "OT", 12, 222),
    Book("SNG", "Song of Solomon", "Song", "OT", 8, 117),
    Book("ISA", "Isaiah", "Isa", "OT", 66, 1292),
    Book("JER", "Jeremiah", "Jer", "OT", 52, 1364),
    Book("LAM", "Lamentations", "Lam", "OT", 5, 154),
    Book("EZK", "Ezekiel", "Ezek", "OT", 48, 1273),
    Book("DAN", "Daniel", "Dan", "OT", 12, 357),
    Book("HOS", "Hosea", "Hos", "OT", 14, 197),
    Book("JOL", "Joel", "Joel", "OT", 3, 73),
    Book("AMO", "Amos", "Amos", "OT", 9, 146),
    Book("OBA", "Obadiah", "Obad", "OT", 1, 21),
    Book("JON", "Jonah", "Jonah", "OT", 4, 48),
    Book("MIC", "Micah", "Mic", "OT", 7, 105),
    Book("NAM", "Nahum", "Nah", "OT", 3, 47),
    Book("HAB", "Habakkuk", "Hab", "OT", 3, 56),
    Book("ZEP", "Zephaniah", "Zeph", "OT", 3, 53),
    Book("HAG", "Haggai", "Hag", "OT", 2, 38),
    Book("ZEC", "Zechariah", "Zech", "OT", 14, 211),
    Book("MAL", "Malachi", "Mal", "OT", 4, 55),
    Book("MAT", "Matthew", "Matt", "NT", 28, 1071),
    Book("MRK", "Mark", "Mark", "NT", 16, 678),
    Book("LUK", "Luke", "Luke", "NT", 24, 1151),
    Book("JHN", "John", "John", "NT", 21, 879),
    Book("ACT", "Acts", "Acts", "NT", 28, 1007),
    Book("ROM", "Romans", "Rom", "NT", 16, 433),
    Book("1CO", "1 Corinthians", "1 Cor", "NT", 16, 437),
    Book("2CO", "2 Corinthians", "2 Cor", "NT", 13, 257),
    Book("GAL", "Galatians", "Gal", "NT", 6, 149),
    Book("EPH", "Ephesians", "Eph", "NT", 6, 155),
    Book("PHP", "Philippians", "Phil", "NT", 4, 104),
    Book("COL", "Colossians", "Col", "NT", 4, 95),
    Book("1TH", "1 Thessalonians", "1 Thess", "NT", 5, 89),
    Book("2TH", "2 Thessalonians", "2 Thess", "NT", 3, 47),
    Book("1TI", "1 Timothy", "1 Tim", "NT", 6, 113),
    Book("2TI", "2 Timothy", "2 Tim", "NT", 4, 83),
    Book("TIT", "Titus", "Titus", "NT", 3, 46),
    Book("PHM", "Philemon", "Phlm", "NT", 1, 25),
    Book("HEB", "Hebrews", "Heb", "NT", 13, 303),
    Book("JAS", "James", "Jas", "NT", 5, 108),
    Book("1PE", "1 Peter", "1 Pet", "NT", 5, 105),
    Book("2PE", "2 Peter", "2 Pet", "NT", 3, 61),
    Book("1JN", "1 John", "1 John", "NT", 5, 105),
    Book("2JN", "2 John", "2 John", "NT", 1, 13),
    Book("3JN", "3 John", "3 John", "NT", 1, 14),
    Book("JUD", "Jude", "Jude", "NT", 1, 25),
    Book("REV", "Revelation", "Rev", "NT", 22, 404),
]

TOTAL_BOOKS = 66
TOTAL_CHAPTERS = 1189
TOTAL_KJV_VERSES = 31102

BY_ID = {b.id: b for b in BOOKS}


def _normalise(name: str) -> str:
    return "".join(ch for ch in name.lower() if ch.isalnum())


# Name spellings used by the upstream sources, mapped to USFM ids.
_ALIASES = {
    "psalm": "PSA",
    "songofsongs": "SNG",
    "canticles": "SNG",
    "solomonssong": "SNG",
    "revelationofjohn": "REV",
    "isamuel": "1SA",
    "iisamuel": "2SA",
    "ikings": "1KI",
    "iikings": "2KI",
    "ichronicles": "1CH",
    "iichronicles": "2CH",
    "icorinthians": "1CO",
    "iicorinthians": "2CO",
    "ithessalonians": "1TH",
    "iithessalonians": "2TH",
    "itimothy": "1TI",
    "iitimothy": "2TI",
    "ipeter": "1PE",
    "iipeter": "2PE",
    "ijohn": "1JN",
    "iijohn": "2JN",
    "iiijohn": "3JN",
}

_BY_NAME = {_normalise(b.name): b.id for b in BOOKS} | _ALIASES


def book_id_for(name: str) -> str:
    """Resolves an upstream book name (e.g. "1 John", "songofsolomon")."""
    key = _normalise(name)
    if key not in _BY_NAME:
        raise KeyError(f"Unknown book name: {name!r}")
    return _BY_NAME[key]


assert len(BOOKS) == TOTAL_BOOKS
assert sum(b.chapters for b in BOOKS) == TOTAL_CHAPTERS
assert sum(b.kjv_verses for b in BOOKS) == TOTAL_KJV_VERSES
