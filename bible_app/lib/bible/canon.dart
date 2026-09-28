part 'canon.g.dart';

enum Testament {
  old('Old Testament', 'OT'),
  newT('New Testament', 'NT');

  const Testament(this.label, this.code);
  final String label;
  final String code;
}

/// One book of the 66-book canon. Identical for every translation.
class BookInfo {
  const BookInfo({
    required this.index,
    required this.id,
    required this.name,
    required this.abbr,
    required this.testament,
    required this.chapterCount,
  });

  /// Position in canonical order, 0 (Genesis) to 65 (Revelation).
  final int index;

  /// USFM code, e.g. "JHN".
  final String id;
  final String name;
  final String abbr;
  final Testament testament;
  final int chapterCount;

  @override
  String toString() => name;
}

abstract final class Canon {
  static const List<BookInfo> books = _books;

  static final Map<String, BookInfo> _byId = {for (final b in books) b.id: b};

  static BookInfo byId(String id) {
    final b = _byId[id];
    if (b == null) throw ArgumentError.value(id, 'id', 'Unknown book id');
    return b;
  }

  static BookInfo? tryById(String id) => _byId[id];

  static Iterable<BookInfo> testament(Testament t) =>
      books.where((b) => b.testament == t);

  static int get totalChapters => books.fold(0, (n, b) => n + b.chapterCount);
}
