import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/db/watch.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/day_key.dart';
import '../../skills/data/skill_repository.dart';

enum EntryType {
  gratitude('gratitude', 'Gratitude'),
  win('win', 'Win');

  const EntryType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static EntryType parse(String v) =>
      v == win.dbValue ? EntryType.win : EntryType.gratitude;
}

abstract final class EntryLimits {
  static const bodyMax = 1000;
  static const tagMax = 24;
  static const tagsPerEntry = 8;
}

abstract final class TagNames {
  /// "  #Deep Work " → "deep-work". Returns null for empty input.
  static String? normalize(String raw) {
    var t = raw.trim().toLowerCase();
    while (t.startsWith('#')) {
      t = t.substring(1);
    }
    t = t.replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'[,]'), '');
    if (t.isEmpty) return null;
    if (t.length > EntryLimits.tagMax) t = t.substring(0, EntryLimits.tagMax);
    return t;
  }
}

@immutable
class EntryDraft {
  const EntryDraft({
    required this.type,
    required this.body,
    required this.dayKey,
    this.mood,
    this.skillId,
    this.tags = const [],
  });

  final EntryType type;
  final String body;
  final DayKey dayKey;
  final String? mood;
  final int? skillId;
  final List<String> tags;
}

@immutable
class EntryView {
  const EntryView({required this.entry, required this.tags, this.skill});

  final EntryRow entry;
  final List<String> tags;
  final SkillRow? skill;

  EntryType get type => EntryType.parse(entry.type);
  bool get isMilestone => entry.milestoneRef != null;
}

@immutable
class EntryFilter {
  const EntryFilter({
    this.type,
    this.tags = const {},
    this.skillId,
    this.from,
    this.to,
    this.query = '',
  });

  static const none = EntryFilter();

  final EntryType? type;
  final Set<String> tags;
  final int? skillId;
  final DayKey? from;
  final DayKey? to;
  final String query;

  bool get isEmpty =>
      type == null &&
      tags.isEmpty &&
      skillId == null &&
      from == null &&
      to == null &&
      query.trim().isEmpty;

  int get activeCount =>
      (type == null ? 0 : 1) +
      (tags.isEmpty ? 0 : 1) +
      (skillId == null ? 0 : 1) +
      (from == null && to == null ? 0 : 1);

  EntryFilter copyWith({
    ValueGetter<EntryType?>? type,
    Set<String>? tags,
    ValueGetter<int?>? skillId,
    ValueGetter<DayKey?>? from,
    ValueGetter<DayKey?>? to,
    String? query,
  }) {
    return EntryFilter(
      type: type == null ? this.type : type(),
      tags: tags ?? this.tags,
      skillId: skillId == null ? this.skillId : skillId(),
      from: from == null ? this.from : from(),
      to: to == null ? this.to : to(),
      query: query ?? this.query,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntryFilter &&
      other.type == type &&
      setEquals(other.tags, tags) &&
      other.skillId == skillId &&
      other.from == from &&
      other.to == to &&
      other.query == query;

  @override
  int get hashCode => Object.hash(
    type,
    Object.hashAllUnordered(tags),
    skillId,
    from,
    to,
    query,
  );
}

@immutable
class TagCount {
  const TagCount(this.name, this.count);
  final String name;
  final int count;
}

class EntryRepository {
  EntryRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<T> watch<T>(Future<T> Function() load) =>
      _db.watchTables([_db.entries, _db.entryTags, _db.tags, _db.skills], load);

  Stream<List<EntryView>> watchEntries(EntryFilter filter) =>
      watch(() => query(filter));

  Future<List<EntryView>> query(EntryFilter filter) async {
    final e = _db.entries;
    final q = _db.select(e)
      ..orderBy([
        (t) => OrderingTerm.desc(t.dayKey),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (filter.type != null) {
      q.where((t) => t.type.equals(filter.type!.dbValue));
    }
    if (filter.skillId != null) {
      q.where((t) => t.skillId.equals(filter.skillId!));
    }
    if (filter.from != null) {
      q.where((t) => t.dayKey.isBiggerOrEqualValue(filter.from!));
    }
    if (filter.to != null) {
      q.where((t) => t.dayKey.isSmallerOrEqualValue(filter.to!));
    }
    if (filter.tags.isNotEmpty) {
      final sub =
          _db.selectOnly(_db.entryTags).join([
              innerJoin(_db.tags, _db.tags.id.equalsExp(_db.entryTags.tagId)),
            ])
            ..addColumns([_db.entryTags.entryId])
            ..where(_db.tags.name.isIn(filter.tags));
      q.where((t) => t.id.isInQuery(sub));
    }
    final rows = await q.get();
    var views = await _hydrate(rows);

    final needle = filter.query.trim().toLowerCase();
    if (needle.isNotEmpty) {
      views = views.where((v) {
        return v.entry.body.toLowerCase().contains(needle) ||
            v.tags.any((t) => t.contains(needle)) ||
            (v.skill?.name.toLowerCase().contains(needle) ?? false);
      }).toList();
    }
    return views;
  }

  Future<List<EntryView>> _hydrate(List<EntryRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    final tagRows =
        await (_db.select(_db.entryTags).join([
                innerJoin(_db.tags, _db.tags.id.equalsExp(_db.entryTags.tagId)),
              ])
              ..where(_db.entryTags.entryId.isIn(ids))
              ..orderBy([OrderingTerm.asc(_db.tags.name)]))
            .get();
    final tagsByEntry = <int, List<String>>{};
    for (final r in tagRows) {
      tagsByEntry
          .putIfAbsent(r.readTable(_db.entryTags).entryId, () => [])
          .add(r.readTable(_db.tags).name);
    }
    final skillIds = rows.map((r) => r.skillId).whereType<int>().toSet();
    final skills = skillIds.isEmpty
        ? <int, SkillRow>{}
        : {
            for (final s in await (_db.select(
              _db.skills,
            )..where((s) => s.id.isIn(skillIds))).get())
              s.id: s,
          };
    return [
      for (final r in rows)
        EntryView(
          entry: r,
          tags: tagsByEntry[r.id] ?? const [],
          skill: r.skillId == null ? null : skills[r.skillId],
        ),
    ];
  }

  Future<EntryView?> getEntry(int id) async {
    final row = await (_db.select(
      _db.entries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).first;
  }

  void _validate(EntryDraft d) {
    final body = d.body.trim();
    if (body.isEmpty) {
      throw const ValidationException('Write a few words first.');
    }
    if (body.length > EntryLimits.bodyMax) {
      throw const ValidationException('That entry is too long.');
    }
    if (d.dayKey > _clock.today()) {
      throw const ValidationException("Entries can't be dated in the future.");
    }
  }

  List<String> _cleanTags(List<String> raw) {
    final out = <String>[];
    for (final t in raw) {
      final n = TagNames.normalize(t);
      if (n != null && !out.contains(n)) out.add(n);
    }
    if (out.length > EntryLimits.tagsPerEntry) {
      throw const ValidationException('Up to 8 tags per entry.');
    }
    return out;
  }

  Future<int> addEntry(
    EntryDraft d, {
    bool isAuto = false,
    String? milestoneRef,
  }) {
    _validate(d);
    final tags = _cleanTags(d.tags);
    return _db.transaction(() async {
      final id = await _db
          .into(_db.entries)
          .insert(
            EntriesCompanion.insert(
              type: d.type.dbValue,
              body: d.body.trim(),
              mood: Value(d.mood),
              skillId: Value(d.skillId),
              dayKey: d.dayKey,
              createdAt: _clock.now(),
              isAuto: Value(isAuto),
              milestoneRef: Value(milestoneRef),
            ),
          );
      await _setTags(id, tags);
      return id;
    });
  }

  Future<void> updateEntry(int id, EntryDraft d) {
    _validate(d);
    final tags = _cleanTags(d.tags);
    return _db.transaction(() async {
      final n = await (_db.update(_db.entries)..where((e) => e.id.equals(id)))
          .write(
            EntriesCompanion(
              type: Value(d.type.dbValue),
              body: Value(d.body.trim()),
              mood: Value(d.mood),
              skillId: Value(d.skillId),
              dayKey: Value(d.dayKey),
              // Once a person edits an auto win it's theirs: never auto-remove.
              isAuto: const Value(false),
            ),
          );
      if (n == 0) throw const ValidationException('Entry not found.');
      await (_db.delete(
        _db.entryTags,
      )..where((t) => t.entryId.equals(id))).go();
      await _setTags(id, tags);
      await _pruneTags();
    });
  }

  Future<void> deleteEntry(int id) => _db.transaction(() async {
    await (_db.delete(_db.entries)..where((e) => e.id.equals(id))).go();
    await _pruneTags();
  });

  /// Re-inserts a deleted entry with its tags (for "Undo").
  Future<void> restoreEntry(EntryView view) => _db.transaction(() async {
    await _db
        .into(_db.entries)
        .insert(view.entry, mode: InsertMode.insertOrReplace);
    await _setTags(view.entry.id, view.tags);
  });

  Future<void> _setTags(int entryId, List<String> tags) async {
    for (final name in tags) {
      await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(name: name),
            mode: InsertMode.insertOrIgnore,
          );
      final tag = await (_db.select(
        _db.tags,
      )..where((t) => t.name.equals(name))).getSingle();
      await _db
          .into(_db.entryTags)
          .insert(
            EntryTagsCompanion.insert(entryId: entryId, tagId: tag.id),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _pruneTags() => _db.customStatement(
    'DELETE FROM tags WHERE id NOT IN (SELECT tag_id FROM entry_tags)',
  );

  /// Tags ordered by use, optionally within a day range.
  Future<List<TagCount>> tagCounts({DayKey? from, DayKey? to}) async {
    final count = _db.entryTags.entryId.count();
    final q =
        _db.selectOnly(_db.entryTags).join([
            innerJoin(_db.tags, _db.tags.id.equalsExp(_db.entryTags.tagId)),
            innerJoin(
              _db.entries,
              _db.entries.id.equalsExp(_db.entryTags.entryId),
            ),
          ])
          ..addColumns([_db.tags.name, count])
          ..groupBy([_db.tags.name])
          ..orderBy([
            OrderingTerm.desc(count),
            OrderingTerm.asc(_db.tags.name),
          ]);
    if (from != null) q.where(_db.entries.dayKey.isBiggerOrEqualValue(from));
    if (to != null) q.where(_db.entries.dayKey.isSmallerOrEqualValue(to));
    return [
      for (final r in await q.get())
        TagCount(r.read(_db.tags.name)!, r.read(count) ?? 0),
    ];
  }

  Future<Set<DayKey>> entryDays() async {
    final e = _db.entries;
    final rows = await (_db.selectOnly(
      e,
      distinct: true,
    )..addColumns([e.dayKey])).get();
    return {for (final r in rows) r.read(e.dayKey)!};
  }

  Future<List<EntryView>> between(DayKey from, DayKey to, {EntryType? type}) =>
      query(EntryFilter(from: from, to: to, type: type));

  Future<Map<EntryType, int>> countsBetween(DayKey from, DayKey to) async {
    final e = _db.entries;
    final count = e.id.count();
    final rows =
        await (_db.selectOnly(e)
              ..addColumns([e.type, count])
              ..where(e.dayKey.isBetweenValues(from, to))
              ..groupBy([e.type]))
            .get();
    final out = {EntryType.gratitude: 0, EntryType.win: 0};
    for (final r in rows) {
      out[EntryType.parse(r.read(e.type)!)] = r.read(count) ?? 0;
    }
    return out;
  }
}
