import 'canon.dart';

/// A chapter of a book, independent of translation.
class ChapterRef implements Comparable<ChapterRef> {
  const ChapterRef(this.bookId, this.chapter);

  final String bookId;
  final int chapter;

  BookInfo get book => Canon.byId(bookId);

  /// Globally sortable key.
  int get key => book.index * 1000 + chapter;

  /// Stable string form, e.g. "JHN.3".
  String get code => '$bookId.$chapter';

  static ChapterRef parseCode(String code) {
    final parts = code.split('.');
    return ChapterRef(parts[0], int.parse(parts[1]));
  }

  ChapterRef? get next {
    if (chapter < book.chapterCount) return ChapterRef(bookId, chapter + 1);
    final i = book.index + 1;
    return i < Canon.books.length ? ChapterRef(Canon.books[i].id, 1) : null;
  }

  ChapterRef? get previous {
    if (chapter > 1) return ChapterRef(bookId, chapter - 1);
    final i = book.index - 1;
    if (i < 0) return null;
    final b = Canon.books[i];
    return ChapterRef(b.id, b.chapterCount);
  }

  String get label => '${book.name} $chapter';

  @override
  int compareTo(ChapterRef other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) =>
      other is ChapterRef && other.bookId == bookId && other.chapter == chapter;

  @override
  int get hashCode => Object.hash(bookId, chapter);

  @override
  String toString() => code;
}

/// A single verse, independent of translation.
class VerseRef implements Comparable<VerseRef> {
  const VerseRef(this.bookId, this.chapter, this.verse);

  final String bookId;
  final int chapter;
  final int verse;

  BookInfo get book => Canon.byId(bookId);
  ChapterRef get chapterRef => ChapterRef(bookId, chapter);

  /// Globally sortable key (book, chapter, verse).
  int get key => (book.index * 1000 + chapter) * 1000 + verse;

  /// Stable string form, e.g. "JHN.3.16" (used in storage and sync).
  String get code => '$bookId.$chapter.$verse';

  static VerseRef parseCode(String code) {
    final parts = code.split('.');
    return VerseRef(parts[0], int.parse(parts[1]), int.parse(parts[2]));
  }

  String get label => '${book.name} $chapter:$verse';

  @override
  int compareTo(VerseRef other) => key.compareTo(other.key);

  bool operator <(VerseRef other) => key < other.key;
  bool operator <=(VerseRef other) => key <= other.key;
  bool operator >(VerseRef other) => key > other.key;
  bool operator >=(VerseRef other) => key >= other.key;

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.bookId == bookId &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);

  @override
  String toString() => code;
}

/// An inclusive verse range. May span chapters (and, for selections, books).
class VerseRange {
  VerseRange(VerseRef a, VerseRef b)
    : start = a <= b ? a : b,
      end = a <= b ? b : a;

  VerseRange.single(VerseRef v) : start = v, end = v;

  final VerseRef start;
  final VerseRef end;

  bool get isSingle => start == end;

  bool contains(VerseRef v) => v >= start && v <= end;

  bool overlaps(VerseRange o) => start <= o.end && o.start <= end;

  /// Stable string form, e.g. "JHN.3.16-JHN.3.18".
  String get code => isSingle ? start.code : '${start.code}-${end.code}';

  static VerseRange parseCode(String code) {
    final parts = code.split('-');
    final a = VerseRef.parseCode(parts[0]);
    return parts.length == 1
        ? VerseRange.single(a)
        : VerseRange(a, VerseRef.parseCode(parts[1]));
  }

  /// Human label: "John 3:16", "John 3:16–18", "John 3:16–4:2",
  /// "John 21:25–Acts 1:3".
  String get label {
    final s = start, e = end;
    if (isSingle) return s.label;
    if (s.bookId != e.bookId) return '${s.label}–${e.label}';
    if (s.chapter != e.chapter) {
      return '${s.book.name} ${s.chapter}:${s.verse}–${e.chapter}:${e.verse}';
    }
    return '${s.book.name} ${s.chapter}:${s.verse}–${e.verse}';
  }

  @override
  bool operator ==(Object other) =>
      other is VerseRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => code;
}

/// A passage in a reading plan: whole chapters, or a verse range within them.
class Passage {
  const Passage({
    required this.bookId,
    required this.startChapter,
    required this.endChapter,
    this.startVerse,
    this.endVerse,
  });

  final String bookId;
  final int startChapter;
  final int endChapter;
  final int? startVerse;
  final int? endVerse;

  BookInfo get book => Canon.byId(bookId);

  bool get isWholeChapters => startVerse == null && endVerse == null;

  List<ChapterRef> get chapters => [
    for (var c = startChapter; c <= endChapter; c++) ChapterRef(bookId, c),
  ];

  String get label {
    final name = book.name;
    if (!isWholeChapters) {
      if (startChapter == endChapter) {
        return '$name $startChapter:$startVerse–$endVerse';
      }
      return '$name $startChapter:$startVerse–$endChapter:$endVerse';
    }
    if (book.chapterCount == 1) return name;
    return startChapter == endChapter
        ? '$name $startChapter'
        : '$name $startChapter–$endChapter';
  }

  factory Passage.fromJson(Map<String, dynamic> j) => Passage(
    bookId: j['b'] as String,
    startChapter: j['c1'] as int,
    endChapter: (j['c2'] ?? j['c1']) as int,
    startVerse: j['v1'] as int?,
    endVerse: j['v2'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'b': bookId,
    'c1': startChapter,
    if (endChapter != startChapter) 'c2': endChapter,
    'v1': ?startVerse,
    'v2': ?endVerse,
  };
}
