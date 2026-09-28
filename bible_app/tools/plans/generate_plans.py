#!/usr/bin/env python3
"""Generates the reading plans: assets/plans/plans.json (bundled, used
offline by the app) and supabase/seed.sql (reference data for the backend).

Whole-book plans are split by verse count so each day takes a similar
time. Plans that claim to cover a set of books are checked to include
every chapter exactly once.

Run from bible_app/:  python3 tools/plans/generate_plans.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "bible_data"))
import canon  # noqa: E402

KJV = json.loads((ROOT / "assets" / "bible" / "kjv.json").read_text(encoding="utf-8"))
VERSES = {
    (b["id"], c["n"]): len(c["verses"]) for b in KJV["books"] for c in b["chapters"]
}
VERSES_PER_MINUTE = 9  # unhurried reading pace

Chapter = tuple[str, int]


def chapters(book: str, first: int = 1, last: int | None = None) -> list[Chapter]:
    last = last or canon.BY_ID[book].chapters
    return [(book, c) for c in range(first, last + 1)]


def books(ids: list[str]) -> list[Chapter]:
    return [ch for b in ids for ch in chapters(b)]


def testament(t: str) -> list[str]:
    return [b.id for b in canon.BOOKS if b.testament == t]


def split_by_verses(seq: list[Chapter], days: int) -> list[list[Chapter]]:
    """Consecutive groups of chapters with balanced verse totals."""
    if days > len(seq):
        raise ValueError("more days than chapters")
    total = sum(VERSES[c] for c in seq)
    out: list[list[Chapter]] = []
    i = 0
    running = 0
    for day in range(1, days + 1):
        target = total * day / days
        group: list[Chapter] = []
        remaining_days = days - day
        while i < len(seq):
            # Leave at least one chapter for each remaining day.
            if len(seq) - i <= remaining_days:
                break
            v = VERSES[seq[i]]
            if group and running + v / 2 > target:
                break
            group.append(seq[i])
            running += v
            i += 1
        out.append(group)
    assert i == len(seq) and all(out), "split failed"
    return out


def passages(group: list[Chapter]) -> list[dict]:
    """Merges consecutive chapters of one book into passages."""
    out: list[dict] = []
    for book, ch in group:
        if out and out[-1]["b"] == book and out[-1].get("c2", out[-1]["c1"]) == ch - 1:
            out[-1]["c2"] = ch
        else:
            out.append({"b": book, "c1": ch})
    return out


def ref(book: str, c1: int, v1: int | None = None, c2: int | None = None,
        v2: int | None = None) -> dict:
    p = {"b": book, "c1": c1}
    if c2 is not None and c2 != c1:
        p["c2"] = c2
    if v1 is not None:
        p["v1"] = v1
        p["v2"] = v2
    return p


def verses_in(p: dict) -> int:
    if "v1" in p:
        c2 = p.get("c2", p["c1"])
        if c2 == p["c1"]:
            return p["v2"] - p["v1"] + 1
        n = VERSES[(p["b"], p["c1"])] - p["v1"] + 1 + p["v2"]
        return n + sum(VERSES[(p["b"], c)] for c in range(p["c1"] + 1, c2))
    return sum(VERSES[(p["b"], c)] for c in range(p["c1"], p.get("c2", p["c1"]) + 1))


def plan(pid, title, subtitle, description, category, days_passages,
         covers: list[Chapter] | None = None) -> dict:
    if covers is not None:
        seen = [(p["b"], c) for day in days_passages for p in day
                for c in range(p["c1"], p.get("c2", p["c1"]) + 1)]
        assert sorted(seen, key=_order) == sorted(covers, key=_order), f"{pid} coverage"
        assert len(seen) == len(set(seen)), f"{pid} repeats a chapter"
    per_day = [sum(verses_in(p) for p in d) for d in days_passages]
    minutes = max(1, math.ceil(sum(per_day) / len(per_day) / VERSES_PER_MINUTE))
    return {
        "id": pid,
        "title": title,
        "subtitle": subtitle,
        "description": description,
        "category": category,
        "minutes": minutes,
        "days": days_passages,
    }


def _order(ch: Chapter) -> tuple[int, int]:
    return ([b.id for b in canon.BOOKS].index(ch[0]), ch[1])


def balanced(pid, title, subtitle, description, category, seq, days):
    return plan(pid, title, subtitle, description, category,
                [passages(g) for g in split_by_verses(seq, days)], covers=seq)


# Approximate historical order: books and sections placed where their
# events or writing most likely fall. Every chapter appears once.
CHRONOLOGICAL: list[Chapter] = (
    chapters("GEN", 1, 11) + books(["JOB"]) + chapters("GEN", 12, 50)
    + books(["EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1CH", "PSA"])
    + chapters("1KI", 1, 11) + books(["PRO", "ECC", "SNG"]) + chapters("1KI", 12, 22)
    + chapters("2KI", 1, 14) + books(["JOL", "JON", "AMO", "HOS", "ISA", "MIC"])
    + chapters("2KI", 15, 25) + books(["2CH", "NAM", "ZEP", "JER", "LAM", "HAB", "OBA", "EZK", "DAN"])
    + chapters("EZR", 1, 6) + books(["HAG", "ZEC", "EST"]) + chapters("EZR", 7, 10)
    + books(["NEH", "MAL", "MAT", "MRK", "LUK", "JHN"])
    + chapters("ACT", 1, 12) + books(["JAS"]) + chapters("ACT", 13, 14) + books(["GAL"])
    + chapters("ACT", 15, 18) + books(["1TH", "2TH"]) + chapters("ACT", 19, 19)
    + books(["1CO", "2CO", "ROM"]) + chapters("ACT", 20, 28)
    + books(["EPH", "PHP", "COL", "PHM", "1TI", "TIT", "1PE", "2TI", "2PE", "HEB", "JUD",
             "1JN", "2JN", "3JN", "REV"])
)

ALL = books([b.id for b in canon.BOOKS])
GOSPELS = books(["MAT", "MRK", "LUK", "JHN"])


def build() -> list[dict]:
    return [
        balanced("bible-1y", "Bible in One Year", "Genesis to Revelation, 365 days",
                 "Read the whole Bible in order over a year, in portions of similar length.",
                 "whole", ALL, 365),
        balanced("bible-90", "Bible in 90 Days", "The whole story, fast",
                 "An immersive pace: the entire Bible in three months. Plan for about "
                 "45 minutes a day.", "whole", ALL, 90),
        balanced("chronological-1y", "Chronological Bible", "In the order events happened",
                 "The whole Bible over a year, arranged in approximate historical order: "
                 "Job after Genesis 11, the prophets alongside the kings they spoke to, the "
                 "letters within Acts.", "whole", CHRONOLOGICAL, 365),
        balanced("nt-90", "New Testament", "Gospels to Revelation in 90 days",
                 "The life of Jesus, the early church and the letters, in three months.",
                 "testament", books(testament("NT")), 90),
        balanced("ot-240", "Old Testament", "Creation to the prophets in 8 months",
                 "The Hebrew Scriptures in order, from Genesis to Malachi.",
                 "testament", books(testament("OT")), 240),
        balanced("gospels-40", "The Four Gospels", "Matthew, Mark, Luke and John",
                 "Walk through the life and teaching of Jesus in forty days.",
                 "gospels", GOSPELS, 40),
        plan("mark-16", "Mark: The Life of Jesus", "One chapter a day, 16 days",
             "The shortest Gospel, fast-moving and vivid. A good first book to read.",
             "beginner", [[ref("MRK", c)] for c in range(1, 17)],
             covers=chapters("MRK")),
        balanced("psalms-30", "Psalms in 30 Days", "All 150 psalms in a month",
                 "Songs and prayers for every season, about five a day.",
                 "wisdom", chapters("PSA"), 30),
        plan("proverbs-31", "Proverbs in a Month", "One chapter for each day",
             "Thirty-one chapters of practical wisdom, one for each day of the month.",
             "wisdom", [[ref("PRO", c)] for c in range(1, 32)], covers=chapters("PRO")),
        plan("first-steps-14", "First Steps", "Fourteen days through the big story",
             "New to the Bible? Start with creation, the life of Jesus, and the hope "
             "at the end, in short daily readings.", "beginner",
             [[ref("JHN", 1)], [ref("JHN", 3)], [ref("GEN", 1)], [ref("GEN", 2, c2=3)],
              [ref("PSA", 1), ref("PSA", 23)], [ref("MAT", 5)], [ref("MAT", 6)],
              [ref("MAT", 7)], [ref("LUK", 15)], [ref("JHN", 15)], [ref("ROM", 8)],
              [ref("1CO", 13)], [ref("PHP", 4)], [ref("REV", 21)]]),
        plan("sermon-mount-3", "The Sermon on the Mount", "Three days in Matthew 5–7",
             "Jesus' best-known teaching, one chapter a day.", "short",
             [[ref("MAT", 5)], [ref("MAT", 6)], [ref("MAT", 7)]], covers=chapters("MAT", 5, 7)),
        plan("peace-7", "Seven Days of Peace", "For anxious seasons",
             "Short passages on worry, trust and rest.", "short",
             [[ref("PHP", 4, 4, v2=9)], [ref("MAT", 6, 25, v2=34)], [ref("JHN", 14, 1, v2=27)],
              [ref("PSA", 46)], [ref("ISA", 26, 1, v2=4)], [ref("1PE", 5, 6, v2=11)],
              [ref("PSA", 131)]]),
        plan("love-7", "Love in Seven Days", "What love looks like",
             "A week with the Bible's great passages on love.", "short",
             [[ref("1CO", 13)], [ref("1JN", 4, 7, v2=21)], [ref("JHN", 15, 9, v2=17)],
              [ref("ROM", 12, 9, v2=21)], [ref("RUT", 1)], [ref("LUK", 10, 25, v2=37)],
              [ref("COL", 3, 12, v2=17)]]),
        plan("hope-7", "Hope for Hard Days", "Seven readings for difficult times",
             "Honest, hope-filled passages for grief, waiting and weariness.", "short",
             [[ref("PSA", 23)], [ref("PSA", 121)], [ref("ISA", 40, 25, v2=31)],
              [ref("LAM", 3, 19, v2=33)], [ref("ROM", 8, 18, v2=39)],
              [ref("2CO", 4, 7, v2=18)], [ref("REV", 21, 1, v2=7)]]),
    ]


PRAYER_CATEGORIES = ["Personal", "Family", "Friends", "Work", "School",
                     "Relationships", "Gratitude", "Other"]


def sql_text(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main() -> None:
    plans = build()
    for p in plans:
        for d in p["days"]:
            for x in d:
                b = canon.BY_ID[x["b"]]
                assert 1 <= x["c1"] <= x.get("c2", x["c1"]) <= b.chapters, (p["id"], x)
                if "v1" in x:
                    assert 1 <= x["v1"] <= x["v2"] <= VERSES[(x["b"], x.get("c2", x["c1"]))], (p["id"], x)
    out = ROOT / "assets" / "plans" / "plans.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"version": 1, "plans": plans}, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")
    for p in plans:
        print(f"  {p['id']:18} {len(p['days']):4} days  ~{p['minutes']:3} min/day  {p['title']}")

    lines = [
        "-- GENERATED by tools/plans/generate_plans.py. Reference data only;",
        "-- safe to re-run (upserts, never deletes user data).",
        "",
        "insert into public.prayer_categories (id, label, sort_order) values",
        ",\n".join(f"  ({sql_text(c.lower())}, {sql_text(c)}, {i})"
                   for i, c in enumerate(PRAYER_CATEGORIES)),
        "on conflict (id) do update set label = excluded.label, sort_order = excluded.sort_order;",
        "",
    ]
    for i, p in enumerate(plans):
        lines += [
            "insert into public.reading_plans",
            "  (id, title, subtitle, description, category, minutes_per_day, total_days, days, sort_order)",
            f"values ({sql_text(p['id'])}, {sql_text(p['title'])}, {sql_text(p['subtitle'])},",
            f"  {sql_text(p['description'])}, {sql_text(p['category'])}, {p['minutes']}, {len(p['days'])},",
            f"  {sql_text(json.dumps(p['days'], separators=(',', ':')))}::jsonb, {i})",
            "on conflict (id) do update set title = excluded.title, subtitle = excluded.subtitle,",
            "  description = excluded.description, category = excluded.category,",
            "  minutes_per_day = excluded.minutes_per_day, total_days = excluded.total_days,",
            "  days = excluded.days, sort_order = excluded.sort_order;",
            "",
        ]
    seed = ROOT / "supabase" / "seed.sql"
    seed.parent.mkdir(parents=True, exist_ok=True)
    seed.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {seed.relative_to(ROOT)} ({seed.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
