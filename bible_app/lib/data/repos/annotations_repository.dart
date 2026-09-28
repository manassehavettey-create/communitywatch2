import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../../bible/references.dart';
import '../../core/theme/tokens.dart';
import '../db/database.dart';
import '../sync/sync_writer.dart';

/// Contiguous runs of selected verses, e.g. {3:16, 3:17, 3:19} →
/// [3:16–17, 3:19]. [isNext] decides adjacency, which lets a run continue
/// from the last verse of a chapter into the next chapter.
List<VerseRange> contiguousRuns(
  Iterable<VerseRef> verses,
  bool Function(VerseRef a, VerseRef b) isNext,
) {
  final sorted = verses.toSet().toList()..sort();
  final runs = <VerseRange>[];
  VerseRef? start, prev;
  for (final v in sorted) {
    if (start == null) {
      start = prev = v;
    } else if (isNext(prev!, v)) {
      prev = v;
    } else {
      runs.add(VerseRange(start, prev));
      start = prev = v;
    }
  }
  if (start != null) runs.add(VerseRange(start, prev!));
  return runs;
}

/// Everything anchored to verses in one view (used by the reader).
class ChapterAnnotations {
  const ChapterAnnotations({
    this.highlights = const [],
    this.notes = const [],
    this.bookmarks = const [],
  });

  final List<Highlight> highlights;
  final List<Note> notes;
  final List<Bookmark> bookmarks;

  static const empty = ChapterAnnotations();

  HighlightColor? highlightFor(VerseRef v) {
    for (final h in highlights.reversed) {
      if (v.key >= h.startKey && v.key <= h.endKey) {
        return HighlightColor.fromName(h.color);
      }
    }
    return null;
  }

  bool hasNote(VerseRef v) =>
      notes.any((n) => v.key >= n.startKey && v.key <= n.endKey);

  bool isBookmarked(VerseRef v) =>
      bookmarks.any((b) => v.key >= b.startKey && v.key <= b.endKey);

  List<Note> notesFor(VerseRef v) => [
    for (final n in notes)
      if (v.key >= n.startKey && v.key <= n.endKey) n,
  ];
}

class AnnotationsRepository {
  AnnotationsRepository(this._w);

  final SyncWriter _w;
  AppDatabase get _db => _w.db;

  // ------------------------------------------------------------- reading

  Stream<ChapterAnnotations> watchChapter(ChapterRef c) {
    final lo = VerseRef(c.bookId, c.chapter, 0).key;
    final hi = VerseRef(c.bookId, c.chapter, 999).key;
    final hs =
        (_db.select(_db.highlights)
              ..where(
                (h) =>
                    h.deletedAt.isNull() &
                    h.startKey.isSmallerOrEqualValue(hi) &
                    h.endKey.isBiggerOrEqualValue(lo),
              )
              ..orderBy([(h) => OrderingTerm.asc(h.updatedAt)]))
            .watch();
    final ns =
        (_db.select(_db.notes)..where(
              (n) =>
                  n.deletedAt.isNull() &
                  n.startKey.isSmallerOrEqualValue(hi) &
                  n.endKey.isBiggerOrEqualValue(lo),
            ))
            .watch();
    final bs =
        (_db.select(_db.bookmarks)..where(
              (b) =>
                  b.deletedAt.isNull() &
                  b.startKey.isSmallerOrEqualValue(hi) &
                  b.endKey.isBiggerOrEqualValue(lo),
            ))
            .watch();
    return Rx.combineLatest3(
      hs,
      ns,
      bs,
      (h, n, b) => ChapterAnnotations(highlights: h, notes: n, bookmarks: b),
    );
  }

  Stream<List<Highlight>> watchHighlights() =>
      (_db.select(_db.highlights)
            ..where((h) => h.deletedAt.isNull())
            ..orderBy([(h) => OrderingTerm.desc(h.updatedAt)]))
          .watch();

  Stream<List<Note>> watchNotes() =>
      (_db.select(_db.notes)
            ..where((n) => n.deletedAt.isNull())
            ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
          .watch();

  Stream<List<Bookmark>> watchBookmarks() =>
      (_db.select(_db.bookmarks)
            ..where((b) => b.deletedAt.isNull())
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .watch();

  Stream<List<SavedVerse>> watchSaved() =>
      (_db.select(_db.savedVerses)
            ..where((s) => s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch();

  // ------------------------------------------------------------ highlights

  /// Highlights [runs] in [color], replacing any highlight they overlap
  /// (the overlapped parts outside the new runs are kept).
  Future<void> highlight(List<VerseRange> runs, HighlightColor color) async {
    for (final r in runs) {
      await _clearHighlight(r);
      final id = _w.newId();
      await _w.write(
        'highlights',
        id,
        (t) => _db
            .into(_db.highlights)
            .insert(
              HighlightsCompanion.insert(
                id: id,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
                startRef: r.start.code,
                endRef: r.end.code,
                startKey: r.start.key,
                endKey: r.end.key,
                color: color.name,
              ),
            ),
      );
    }
  }

  Future<void> removeHighlight(List<VerseRange> runs) async {
    for (final r in runs) {
      await _clearHighlight(r);
    }
  }

  /// Removes [r] from existing highlights, trimming ones that extend past
  /// it. Trimming only happens within a chapter; a highlight spanning
  /// chapters that partly overlaps is removed whole.
  Future<void> _clearHighlight(VerseRange r) async {
    final hits =
        await (_db.select(_db.highlights)..where(
              (h) =>
                  h.deletedAt.isNull() &
                  h.startKey.isSmallerOrEqualValue(r.end.key) &
                  h.endKey.isBiggerOrEqualValue(r.start.key),
            ))
            .get();
    for (final h in hits) {
      await _w.softDelete('highlights', h.id);
      final hs = VerseRef.parseCode(h.startRef);
      final he = VerseRef.parseCode(h.endRef);
      Future<void> keep(VerseRef a, VerseRef b) async {
        final id = _w.newId();
        await _w.write(
          'highlights',
          id,
          (t) => _db
              .into(_db.highlights)
              .insert(
                HighlightsCompanion.insert(
                  id: id,
                  userId: Value(_w.userId),
                  createdAt: h.createdAt,
                  updatedAt: t,
                  startRef: a.code,
                  endRef: b.code,
                  startKey: a.key,
                  endKey: b.key,
                  color: h.color,
                ),
              ),
        );
      }

      if (hs < r.start && hs.chapterRef == r.start.chapterRef) {
        await keep(hs, VerseRef(hs.bookId, hs.chapter, r.start.verse - 1));
      }
      if (he > r.end && he.chapterRef == r.end.chapterRef) {
        await keep(VerseRef(he.bookId, he.chapter, r.end.verse + 1), he);
      }
    }
  }

  // ------------------------------------------------------------- bookmarks

  Future<void> toggleBookmark(VerseRange r, String translationId) async {
    final existing =
        await (_db.select(_db.bookmarks)..where(
              (b) =>
                  b.deletedAt.isNull() &
                  b.startKey.equals(r.start.key) &
                  b.endKey.equals(r.end.key),
            ))
            .get();
    if (existing.isNotEmpty) {
      for (final b in existing) {
        await _w.softDelete('bookmarks', b.id);
      }
      return;
    }
    final id = _w.newId();
    await _w.write(
      'bookmarks',
      id,
      (t) => _db
          .into(_db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: id,
              userId: Value(_w.userId),
              createdAt: t,
              updatedAt: t,
              startRef: r.start.code,
              endRef: r.end.code,
              startKey: r.start.key,
              endKey: r.end.key,
              translationId: Value(translationId),
            ),
          ),
    );
  }

  Future<bool> isBookmarked(VerseRange r) async {
    final rows =
        await (_db.select(_db.bookmarks)..where(
              (b) =>
                  b.deletedAt.isNull() &
                  b.startKey.equals(r.start.key) &
                  b.endKey.equals(r.end.key),
            ))
            .get();
    return rows.isNotEmpty;
  }

  Future<void> deleteBookmark(String id) => _w.softDelete('bookmarks', id);

  // ----------------------------------------------------------------- notes

  Future<String> saveNote({
    String? id,
    required VerseRange r,
    required String body,
  }) async {
    final noteId = id ?? _w.newId();
    await _w.write('notes', noteId, (t) async {
      if (id == null) {
        await _db
            .into(_db.notes)
            .insert(
              NotesCompanion.insert(
                id: noteId,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
                startRef: r.start.code,
                endRef: r.end.code,
                startKey: r.start.key,
                endKey: r.end.key,
                body: body,
              ),
            );
      } else {
        await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
          NotesCompanion(body: Value(body), updatedAt: Value(t)),
        );
      }
    });
    return noteId;
  }

  Future<void> deleteNote(String id) => _w.softDelete('notes', id);

  // ----------------------------------------------------------- saved verses

  Future<void> saveVerses(
    VerseRange r,
    String translationId,
    String text,
  ) async {
    final existing =
        await (_db.select(_db.savedVerses)..where(
              (s) =>
                  s.deletedAt.isNull() &
                  s.startKey.equals(r.start.key) &
                  s.endKey.equals(r.end.key),
            ))
            .get();
    if (existing.isNotEmpty) return;
    final id = _w.newId();
    await _w.write(
      'saved_verses',
      id,
      (t) => _db
          .into(_db.savedVerses)
          .insert(
            SavedVersesCompanion.insert(
              id: id,
              userId: Value(_w.userId),
              createdAt: t,
              updatedAt: t,
              startRef: r.start.code,
              endRef: r.end.code,
              startKey: r.start.key,
              endKey: r.end.key,
              translationId: translationId,
              snapshot: text,
            ),
          ),
    );
  }

  Future<void> deleteSaved(String id) => _w.softDelete('saved_verses', id);

  Future<void> deleteHighlight(String id) => _w.softDelete('highlights', id);
}
