import 'canon.dart';
import 'references.dart';

/// Catalogue entry for a translation (from translations.json, or from an
/// installed file).
class TranslationInfo {
  const TranslationInfo({
    required this.id,
    required this.abbreviation,
    required this.name,
    required this.edition,
    required this.license,
    required this.licenseNote,
    required this.suppliedWords,
    required this.location,
  });

  final String id;
  final String abbreviation;
  final String name;
  final String edition;
  final String license;
  final String licenseNote;

  /// Whether `[brackets]` mark translator-supplied words (KJV).
  final bool suppliedWords;

  /// Where the text lives: an asset path, or a file path when installed.
  final TranslationLocation location;

  factory TranslationInfo.fromJson(
    Map<String, dynamic> j,
    TranslationLocation location,
  ) => TranslationInfo(
    id: j['id'] as String,
    abbreviation: j['abbreviation'] as String,
    name: j['name'] as String,
    edition: (j['edition'] ?? '') as String,
    license: j['license'] as String,
    licenseNote: (j['license_note'] ?? '') as String,
    suppliedWords: (j['supplied_words'] ?? false) as bool,
    location: location,
  );
}

sealed class TranslationLocation {
  const TranslationLocation();
}

class AssetLocation extends TranslationLocation {
  const AssetLocation(this.assetPath);
  final String assetPath;
}

class FileLocation extends TranslationLocation {
  const FileLocation(this.filePath);
  final String filePath;
}

/// A translation listed in the selector as not available yet.
class UnavailableTranslation {
  const UnavailableTranslation(this.abbreviation, this.name, this.reason);
  final String abbreviation;
  final String name;
  final String reason;
}

class Heading {
  const Heading({required this.text, this.before, this.after});

  final String text;

  /// Shown above this verse number.
  final int? before;

  /// Shown after this verse number (KJV epistle colophons).
  final int? after;
}

/// The text of one chapter in one translation.
class ChapterText {
  const ChapterText({
    required this.ref,
    required this.verses,
    this.paragraphStarts = const {},
    this.headings = const [],
  });

  final ChapterRef ref;

  /// Index 0 is verse 1. An empty string is a verse number the translation
  /// leaves without text.
  final List<String> verses;
  final Set<int> paragraphStarts;
  final List<Heading> headings;

  int get verseCount => verses.length;

  String verse(int n) => (n >= 1 && n <= verses.length) ? verses[n - 1] : '';

  bool isOmitted(int n) => verse(n).isEmpty;
}

/// A fully loaded translation: every book, chapter and verse.
class BibleText {
  BibleText(this.info, this._chapters);

  final TranslationInfo info;

  /// Keyed by [ChapterRef.key].
  final Map<int, ChapterText> _chapters;

  ChapterText? chapter(ChapterRef ref) => _chapters[ref.key];

  /// Verse text, or '' if the verse is missing or omitted.
  String verse(VerseRef ref) => chapter(ref.chapterRef)?.verse(ref.verse) ?? '';

  /// Every verse in [range], in order, skipping omitted ones.
  List<(VerseRef, String)> versesIn(VerseRange range) {
    final out = <(VerseRef, String)>[];
    var c = range.start.chapterRef;
    while (true) {
      final ch = chapter(c);
      if (ch != null) {
        final from = c == range.start.chapterRef ? range.start.verse : 1;
        final to = c == range.end.chapterRef ? range.end.verse : ch.verseCount;
        for (var v = from; v <= to && v <= ch.verseCount; v++) {
          final t = ch.verse(v);
          if (t.isNotEmpty) out.add((VerseRef(c.bookId, c.chapter, v), t));
        }
      }
      if (c == range.end.chapterRef) break;
      final next = c.next;
      if (next == null) break;
      c = next;
    }
    return out;
  }

  /// All chapters in canonical order (used to build the search index).
  Iterable<ChapterText> get allChapters sync* {
    for (final b in Canon.books) {
      for (var c = 1; c <= b.chapterCount; c++) {
        final ch = _chapters[ChapterRef(b.id, c).key];
        if (ch != null) yield ch;
      }
    }
  }

  /// Parses a translation JSON document (schema 1). Pure; safe to run in an
  /// isolate.
  static BibleText parse(
    Map<String, dynamic> doc,
    TranslationLocation location,
  ) {
    final schema = doc['schema'];
    if (schema != 1) {
      throw FormatException('Unsupported Bible schema $schema');
    }
    final info = TranslationInfo.fromJson(doc, location);
    final chapters = <int, ChapterText>{};
    for (final b in (doc['books'] as List).cast<Map<String, dynamic>>()) {
      final bookId = b['id'] as String;
      if (Canon.tryById(bookId) == null) continue;
      for (final c in (b['chapters'] as List).cast<Map<String, dynamic>>()) {
        final ref = ChapterRef(bookId, c['n'] as int);
        chapters[ref.key] = ChapterText(
          ref: ref,
          verses: (c['verses'] as List).cast<String>(),
          paragraphStarts: {
            ...((c['paragraphs'] as List?) ?? const []).cast<int>(),
          },
          headings: [
            for (final h
                in ((c['headings'] as List?) ?? const [])
                    .cast<Map<String, dynamic>>())
              Heading(
                text: h['text'] as String,
                before: h['before'] as int?,
                after: h['after'] as int?,
              ),
          ],
        );
      }
    }
    return BibleText(info, chapters);
  }
}

/// Text helpers shared by reader, copy, share and search.
abstract final class VerseText {
  static final _brackets = RegExp(r'[\[\]]');
  static final _newlines = RegExp(r'\s*\n\s*');

  /// Plain text for copying/sharing/search: supplied-word brackets removed
  /// (only where they mean that) and poetry lines joined.
  static String plain(String text, {required bool suppliedWords}) {
    var t = text.replaceAll(_newlines, ' ');
    if (suppliedWords) t = t.replaceAll(_brackets, '');
    return t;
  }

  /// Splits text into (segment, isSupplied) runs for italic rendering.
  static List<(String, bool)> runs(String text, {required bool suppliedWords}) {
    if (!suppliedWords || !text.contains('[')) return [(text, false)];
    final out = <(String, bool)>[];
    final buf = StringBuffer();
    var supplied = false;
    for (final ch in text.split('')) {
      if (ch == '[' || ch == ']') {
        if (buf.isNotEmpty) out.add((buf.toString(), supplied));
        buf.clear();
        supplied = ch == '[';
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) out.add((buf.toString(), supplied));
    return out;
  }
}
