import 'canon.dart';
import 'references.dart';

/// A parsed Scripture reference such as "1 Cor 13", "jn 3:16-18" or
/// "Gen 1:1–2:3". Only the book is required.
class ParsedReference {
  const ParsedReference({
    required this.book,
    this.chapter,
    this.verse,
    this.endChapter,
    this.endVerse,
  });

  final BookInfo book;
  final int? chapter;
  final int? verse;
  final int? endChapter;
  final int? endVerse;

  bool get isBookOnly => chapter == null;
  bool get hasVerse => verse != null;

  ChapterRef get chapterRef => ChapterRef(book.id, chapter ?? 1);

  /// The verse range, if a verse was given.
  VerseRange? get range {
    if (chapter == null || verse == null) return null;
    final start = VerseRef(book.id, chapter!, verse!);
    if (endVerse == null) return VerseRange.single(start);
    return VerseRange(
      start,
      VerseRef(book.id, endChapter ?? chapter!, endVerse!),
    );
  }

  String get label {
    if (chapter == null) return book.name;
    final r = range;
    if (r != null) return r.label;
    if (endChapter != null && endChapter != chapter) {
      return '${book.name} $chapter–$endChapter';
    }
    return '${book.name} $chapter';
  }
}

/// Parses free-text references. Tolerates abbreviations, ordinals ("1st",
/// "I", "First"), missing spaces ("1jn"), periods and en/em dashes.
abstract final class ReferenceParser {
  static ParsedReference? parse(String input) {
    final text = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[–—]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return null;

    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    final book = resolveBook(m.group(1)!);
    if (book == null) return null;

    final numbers = m.group(2);
    if (numbers == null || numbers.trim().isEmpty) {
      return ParsedReference(book: book);
    }
    final n = _numbers.firstMatch(numbers.trim());
    if (n == null) return null;

    int? a = int.tryParse(n.group(1)!);
    int? b = n.group(2) == null ? null : int.tryParse(n.group(2)!);
    int? c = n.group(3) == null ? null : int.tryParse(n.group(3)!);
    int? d = n.group(4) == null ? null : int.tryParse(n.group(4)!);
    if (a == null || a < 1) return null;

    // Single-chapter books: "Jude 5" means verse 5 of chapter 1.
    if (book.chapterCount == 1 && b == null) {
      if (a > 1 || c != null) {
        final endVerse = d ?? c;
        return ParsedReference(
          book: book,
          chapter: 1,
          verse: a,
          endVerse: endVerse,
        );
      }
    }

    if (a > book.chapterCount) return null;

    if (b == null) {
      // "Gen 1" or a chapter range "Gen 1-3".
      if (c != null && d == null) {
        if (c < a || c > book.chapterCount) return null;
        return ParsedReference(book: book, chapter: a, endChapter: c);
      }
      if (c != null && d != null) {
        // "Gen 1-2:3" reads as 1:1 to 2:3.
        if (c < a || c > book.chapterCount) return null;
        return ParsedReference(
          book: book,
          chapter: a,
          verse: 1,
          endChapter: c,
          endVerse: d,
        );
      }
      return ParsedReference(book: book, chapter: a);
    }

    if (b < 1) return null;
    if (c == null) return ParsedReference(book: book, chapter: a, verse: b);
    if (d == null) {
      // "3:16-18" — same chapter.
      if (c < b) return null;
      return ParsedReference(book: book, chapter: a, verse: b, endVerse: c);
    }
    // "3:16-4:2"
    if (c < a || c > book.chapterCount) return null;
    return ParsedReference(
      book: book,
      chapter: a,
      verse: b,
      endChapter: c,
      endVerse: d,
    );
  }

  /// Resolves a book name or abbreviation, or null.
  static BookInfo? resolveBook(String raw) {
    final key = normaliseBookName(raw);
    if (key.isEmpty) return null;
    final exact = _aliases[key];
    if (exact != null) return Canon.byId(exact);
    // Unambiguous-enough prefix of a full name ("revel", "philipp").
    if (key.length >= 3 || RegExp(r'^\d').hasMatch(key)) {
      for (final b in Canon.books) {
        if (normaliseBookName(b.name).startsWith(key)) return b;
      }
    }
    return null;
  }

  /// Books whose name starts with [query], for search suggestions.
  static List<BookInfo> suggestBooks(String query, {int limit = 5}) {
    final key = normaliseBookName(query);
    if (key.isEmpty) return const [];
    final out = <BookInfo>[];
    final exact = _aliases[key];
    if (exact != null) out.add(Canon.byId(exact));
    for (final b in Canon.books) {
      if (out.length >= limit) break;
      if (!out.contains(b) && normaliseBookName(b.name).startsWith(key)) {
        out.add(b);
      }
    }
    return out;
  }

  static String normaliseBookName(String raw) {
    var s = raw.toLowerCase().trim();
    s = s.replaceFirstMapped(
      RegExp(r'^(first|1st|iii|ii|i|second|2nd|third|3rd)\b\.?\s*'),
      (m) => switch (m.group(1)) {
        'first' || '1st' || 'i' => '1',
        'second' || '2nd' || 'ii' => '2',
        _ => '3',
      },
    );
    return s.replaceAll(RegExp('[^a-z0-9]'), '');
  }

  // Book part: optional ordinal, then letters (spaces/periods allowed),
  // then the number part.
  static final _pattern = RegExp(
    r'^((?:(?:[1-3]|i{1,3}|first|second|third|1st|2nd|3rd)\.?\s*)?[a-z][a-z .]*?)\.?\s*(\d[\d\s:.,\-]*)?$',
  );

  // a[:b][-c[:d]]
  static final _numbers = RegExp(
    r'^(\d+)(?:\s*[:.,]\s*(\d+))?(?:\s*-\s*(\d+)(?:\s*[:.]\s*(\d+))?)?$',
  );

  static final Map<String, String> _aliases = () {
    final map = <String, String>{};
    void add(String id, List<String> names) {
      for (final n in names) {
        map[normaliseBookName(n)] = id;
      }
    }

    for (final b in Canon.books) {
      add(b.id, [b.name, b.abbr, b.id]);
    }
    add('GEN', ['ge', 'gn']);
    add('EXO', ['ex', 'exo']);
    add('LEV', ['le', 'lv']);
    add('NUM', ['nu', 'nm', 'nb']);
    add('DEU', ['de', 'dt', 'deu']);
    add('JOS', ['jos', 'jsh']);
    add('JDG', ['jdg', 'jg', 'jdgs']);
    add('RUT', ['rth', 'ru']);
    add('1SA', ['1sa', '1sm', '1s', '1sam']);
    add('2SA', ['2sa', '2sm', '2s', '2sam']);
    add('1KI', ['1ki', '1kin', '1k', '1kgs', '1kings']);
    add('2KI', ['2ki', '2kin', '2k', '2kgs', '2kings']);
    add('1CH', ['1ch', '1chr', '1chron']);
    add('2CH', ['2ch', '2chr', '2chron']);
    add('EZR', ['ezr']);
    add('NEH', ['ne']);
    add('EST', ['es', 'est']);
    add('JOB', ['jb']);
    add('PSA', ['ps', 'psa', 'psalm', 'pss', 'psm', 'pslm']);
    add('PRO', ['pr', 'pro', 'prv']);
    add('ECC', ['ec', 'ecc', 'eccles', 'qoh', 'qoheleth']);
    add('SNG', [
      'so',
      'sos',
      'sng',
      'song',
      'song of songs',
      'canticles',
      'cant',
    ]);
    add('ISA', ['is']);
    add('JER', ['je', 'jr']);
    add('LAM', ['la']);
    add('EZK', ['eze', 'ezk']);
    add('DAN', ['da', 'dn']);
    add('HOS', ['ho']);
    add('JOL', ['jl', 'joe']);
    add('AMO', ['am']);
    add('OBA', ['ob', 'oba']);
    add('JON', ['jon', 'jnh']);
    add('MIC', ['mc']);
    add('NAM', ['na']);
    add('HAB', ['hb']);
    add('ZEP', ['zep', 'zp']);
    add('HAG', ['hg']);
    add('ZEC', ['zec', 'zc']);
    add('MAL', ['ml']);
    add('MAT', ['mt', 'mat']);
    add('MRK', ['mk', 'mrk', 'mr']);
    add('LUK', ['lk', 'luk', 'lu']);
    add('JHN', ['jn', 'jhn', 'joh']);
    add('ACT', ['ac', 'act']);
    add('ROM', ['ro', 'rm']);
    add('1CO', ['1co', '1cor']);
    add('2CO', ['2co', '2cor']);
    add('GAL', ['ga']);
    add('EPH', ['ephes']);
    add('PHP', ['php', 'pp', 'phil']);
    add('COL', ['col']);
    add('1TH', ['1th', '1thes', '1thess']);
    add('2TH', ['2th', '2thes', '2thess']);
    add('1TI', ['1ti', '1tim']);
    add('2TI', ['2ti', '2tim']);
    add('TIT', ['tit']);
    add('PHM', ['philem', 'phm', 'pm']);
    add('HEB', ['heb']);
    add('JAS', ['jm', 'jam']);
    add('1PE', ['1pe', '1pt', '1p', '1pet']);
    add('2PE', ['2pe', '2pt', '2p', '2pet']);
    add('1JN', ['1jn', '1jhn', '1jo', '1j']);
    add('2JN', ['2jn', '2jhn', '2jo', '2j']);
    add('3JN', ['3jn', '3jhn', '3jo', '3j']);
    add('JUD', ['jud', 'jd']);
    add('REV', ['re', 'rv', 'revelations', 'apocalypse']);
    return map;
  }();
}
