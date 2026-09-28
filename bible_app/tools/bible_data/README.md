# Bible text data

Builds and verifies the Scripture text bundled in `bible_app/assets/bible/`.
The app reads only these files, never an API, so reading works fully offline.

```sh
cd bible_app/tools/bible_data
python3 build_bible_data.py      # downloads once into .cache/, writes assets
python3 verify_bible_data.py     # must print "All checks passed."
```

Python 3.10+ standard library only. Downloads are cached in `.cache/`
(gitignored), so re-runs don't hit the network. Output is deterministic: the
same inputs always give byte-identical files.

## Bundled translations

| Id  | Translation         | Licence       | Source (pinned by sha256)                       |
|-----|---------------------|---------------|-------------------------------------------------|
| kjv | King James Version (1769) | Public domain\* | npm `kjv@1.0.0` (released under the Unlicense) |
| web | World English Bible | Public domain | npm `world-english-bible@1.0.1` (eBible.org WEB) |

\* In the United Kingdom the KJV is under perpetual Crown rights for printed
editions. Everywhere else it is public domain.

"World English Bible" is a trademark of eBible.org. It may be used as the name
only for the unaltered text. The build only normalises whitespace.

Copyrighted translations (NIV, ESV, NKJV, NLT, NASB, CSB) appear in
`translations.json` under `not_available` with the publisher whose licence
they need.

### Why not bible-api.com?

The original plan was to fetch chapter by chapter from bible-api.com. That
source is still implemented (`--source bible-api`, throttled to the API's
15 requests / 30 s, about 90 minutes per translation), but it was **not run**:
the build environment's network policy blocks bible-api.com, so that code path
is untested. The pinned mirror sources are also richer. bible-api.com returns
plain verse text only, while the mirrors carry paragraph breaks, poetry lines,
Psalm titles and the KJV's supplied-word marks.

A third KJV dataset (scrollmapper/bible_databases) was considered and rejected
as the primary source because it lowercases "LORD" to "Lord" in 7,719 places.
The verifier still uses it to cross-check verse counts.

## File format (schema 1)

`assets/bible/<id>.json`:

```jsonc
{
  "schema": 1,
  "id": "kjv", "abbreviation": "KJV", "name": "King James Version",
  "edition": "...", "language": "en", "license": "Public Domain", "license_note": "...",
  "source": { "kind": "npm", "package": "kjv@1.0.0", "url": "...", "sha256": "...", "notes": "..." },
  "books": [
    {
      "id": "GEN",            // USFM code, stable across translations
      "name": "Genesis", "abbr": "Gen", "testament": "OT",
      "chapters": [
        {
          "n": 1,
          "verses": ["In the beginning ...", "..."],   // index 0 = verse 1
          "paragraphs": [1, 3, 6],                      // optional: verses that start a paragraph/stanza
          "headings": [                                 // optional
            { "text": "A Psalm of David.", "before": 1 },         // shown above verse 1
            { "text": "Written to the Romans ...", "after": 27 }  // KJV epistle colophon
          ]
        }
      ]
    }
  ]
}
```

Text conventions:

- **KJV** `[word]` marks words the translators supplied (printed in italics in
  KJV editions). The app renders them in italics and strips the brackets for
  search, copy and share.
- **WEB** `\n` separates poetry lines within a verse.
- An empty string is a verse number the translation deliberately leaves
  without text. WEB does this at Luke 17:36, Acts 8:37, 15:34, 24:7 and
  Romans 16:25. It prints Romans 16:25–27 at 14:24–26, following the
  Majority Text.

`assets/bible/translations.json` is the manifest the translation selector
reads. It lists each bundled translation with its asset path, sha256 and
verse count, and the `not_available` list.

## Verification

`verify_bible_data.py` fails the build unless all of these hold:

- 66 books in canonical order, each with its canonical chapter count
  (1,189 in total).
- KJV has 31,102 verses and matches the per-book reference totals in
  `canon.py`.
- KJV per-chapter verse counts match an independent second KJV dataset for
  all 1,189 chapters.
- WEB chapter lengths equal KJV's except the documented Romans 14/16
  difference, and no verse is empty except the five listed above.
- No stray markup, doubled spaces or edge whitespace, and `[ ]` brackets are
  balanced.
- Paragraph and heading anchors point at verses that exist.
- Exact-text spot checks pass for Genesis 1:1, Psalm 23:1, John 3:16,
  John 11:35 and Revelation 22:21.
- The KJV has more than 6,000 occurrences of "LORD", which guards against
  flattened small caps.

To add a translation, add a source to `build_bible_data.py`, its metadata to
`TRANSLATIONS`, and its spot checks and versification differences to the
verifier. The app picks it up from the manifest without code changes.
