import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../data/repos/annotations_repository.dart';

/// Builds copy/share text and verse runs for a selection.
class PassageText {
  PassageText(this.bible);

  final BibleText bible;

  /// Whether [b] directly follows [a] in reading order, treating verses the
  /// translation omits (and chapter boundaries) as no gap.
  bool isNext(VerseRef a, VerseRef b) {
    var cur = a;
    for (var guard = 0; guard < 8; guard++) {
      final ch = bible.chapter(cur.chapterRef);
      if (ch == null) return false;
      VerseRef next;
      if (cur.verse < ch.verseCount) {
        next = VerseRef(cur.bookId, cur.chapter, cur.verse + 1);
      } else {
        final nc = cur.chapterRef.next;
        if (nc == null) return false;
        next = VerseRef(nc.bookId, nc.chapter, 1);
      }
      if (next == b) return true;
      if (bible.verse(next).isNotEmpty) return false;
      cur = next; // skip omitted verse numbers
    }
    return false;
  }

  List<VerseRange> runs(Iterable<VerseRef> selection) =>
      contiguousRuns(selection, isNext);

  /// "John 3:16–17; 3:19" style label for a selection.
  String label(Iterable<VerseRef> selection) {
    final rs = runs(selection);
    if (rs.isEmpty) return '';
    final parts = <String>[rs.first.label];
    for (var i = 1; i < rs.length; i++) {
      final prev = rs[i - 1].end, r = rs[i];
      if (r.start.bookId != prev.bookId) {
        parts.add(r.label);
      } else if (r.start.chapter == prev.chapter && r.isSingle) {
        parts.add('${r.start.verse}');
      } else if (r.start.chapter == prev.chapter &&
          r.start.chapter == r.end.chapter) {
        parts.add('${r.start.verse}–${r.end.verse}');
      } else {
        parts.add(r.label.replaceFirst('${r.start.book.name} ', ''));
      }
    }
    return parts.join(', ');
  }

  /// Plain verse text; verse numbers are added when more than one verse
  /// is included.
  String body(Iterable<VerseRef> selection) {
    final verses = <(VerseRef, String)>[];
    for (final r in runs(selection)) {
      verses.addAll(bible.versesIn(r));
    }
    final plain = [
      for (final (ref, t) in verses)
        (ref, VerseText.plain(t, suppliedWords: bible.info.suppliedWords)),
    ];
    if (plain.length == 1) return plain.first.$2;
    return plain.map((e) => '${e.$1.verse} ${e.$2}').join(' ');
  }

  /// Text for the clipboard or share sheet.
  String shareText(Iterable<VerseRef> selection) =>
      '“${body(selection)}”\n— ${label(selection)} (${bible.info.abbreviation})';
}
