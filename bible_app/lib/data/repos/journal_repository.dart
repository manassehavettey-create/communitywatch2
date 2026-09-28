import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../db/database.dart';
import '../sync/sync_writer.dart';

/// A journal entry with its tag names.
class JournalItem {
  const JournalItem(this.entry, this.tags);

  final JournalEntry entry;
  final List<String> tags;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(entry.entryDate);
}

class JournalDraft {
  const JournalDraft({
    required this.title,
    required this.body,
    required this.date,
    this.scriptureRef,
    this.tags = const [],
  });

  final String title;
  final String body;
  final DateTime date;
  final String? scriptureRef;
  final List<String> tags;
}

class JournalRepository {
  JournalRepository(this._w);

  final SyncWriter _w;
  AppDatabase get _db => _w.db;

  Stream<List<JournalItem>> watchAll() {
    final entries =
        (_db.select(_db.journalEntries)
              ..where((e) => e.deletedAt.isNull())
              ..orderBy([
                (e) => OrderingTerm.desc(e.entryDate),
                (e) => OrderingTerm.desc(e.createdAt),
              ]))
            .watch();
    final links = (_db.select(
      _db.journalEntryTags,
    )..where((l) => l.deletedAt.isNull())).watch();
    final tags = (_db.select(
      _db.tags,
    )..where((t) => t.deletedAt.isNull())).watch();
    return Rx.combineLatest3(entries, links, tags, (es, ls, ts) {
      final names = {for (final t in ts) t.id: t.name};
      final byEntry = <String, List<String>>{};
      for (final l in ls) {
        final n = names[l.tagId];
        if (n != null) byEntry.putIfAbsent(l.entryId, () => []).add(n);
      }
      return [
        for (final e in es) JournalItem(e, (byEntry[e.id] ?? [])..sort()),
      ];
    });
  }

  /// All tag names in use, alphabetical.
  Stream<List<String>> watchTagNames() => watchAll().map(
    (items) => ({for (final i in items) ...i.tags}.toList()..sort()),
  );

  Future<String> save(JournalDraft d, {String? id}) async {
    final entryId = id ?? _w.newId();
    final day = DateTime(d.date.year, d.date.month, d.date.day);
    await _w.write('journal_entries', entryId, (t) async {
      final fields = JournalEntriesCompanion(
        title: Value(d.title.trim()),
        body: Value(d.body.trim()),
        entryDate: Value(day.millisecondsSinceEpoch),
        scriptureRef: Value(d.scriptureRef),
        updatedAt: Value(t),
      );
      if (id == null) {
        await _db
            .into(_db.journalEntries)
            .insert(
              fields.copyWith(
                id: Value(entryId),
                userId: Value(_w.userId),
                createdAt: Value(t),
              ),
            );
      } else {
        await (_db.update(
          _db.journalEntries,
        )..where((e) => e.id.equals(id))).write(fields);
      }
    });
    await _setTags(entryId, d.tags);
    return entryId;
  }

  Future<void> _setTags(String entryId, List<String> names) async {
    final wanted = {
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim().toLowerCase(),
    };
    final allTags = await (_db.select(
      _db.tags,
    )..where((t) => t.deletedAt.isNull())).get();
    final byName = {for (final t in allTags) t.name: t.id};
    for (final name in wanted) {
      if (byName.containsKey(name)) continue;
      final id = _w.newId();
      await _w.write(
        'tags',
        id,
        (t) => _db
            .into(_db.tags)
            .insert(
              TagsCompanion.insert(
                id: id,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
                name: name,
              ),
            ),
      );
      byName[name] = id;
    }
    final links = await (_db.select(
      _db.journalEntryTags,
    )..where((l) => l.entryId.equals(entryId) & l.deletedAt.isNull())).get();
    final wantedIds = {for (final n in wanted) byName[n]!};
    for (final l in links) {
      if (!wantedIds.contains(l.tagId)) {
        await _w.softDelete('journal_entry_tags', l.id);
      }
    }
    final have = {for (final l in links) l.tagId};
    for (final tagId in wantedIds.difference(have)) {
      // Deterministic id so the same tag added on two devices is one link.
      final id = '$entryId:$tagId';
      await _w.write(
        'journal_entry_tags',
        id,
        (t) => _db
            .into(_db.journalEntryTags)
            .insertOnConflictUpdate(
              JournalEntryTagsCompanion.insert(
                id: id,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
                entryId: entryId,
                tagId: tagId,
              ),
            ),
      );
    }
  }

  Future<void> delete(String id) async {
    final links = await (_db.select(
      _db.journalEntryTags,
    )..where((l) => l.entryId.equals(id) & l.deletedAt.isNull())).get();
    for (final l in links) {
      await _w.softDelete('journal_entry_tags', l.id);
    }
    await _w.softDelete('journal_entries', id);
  }
}
