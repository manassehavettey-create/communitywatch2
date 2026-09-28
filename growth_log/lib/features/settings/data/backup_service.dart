import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/utils/clock.dart';
import 'settings_repository.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupSummary {
  const BackupSummary({
    required this.skills,
    required this.sessions,
    required this.entries,
  });
  final int skills;
  final int sessions;
  final int entries;
}

/// JSON export / import of the whole database.
///
/// Format: `{ "app": "growth_log", "format": 1, "exportedAt": ..., "data": {...} }`
/// Row fields use drift's JSON serialisation (DateTime as epoch millis).
class BackupService {
  BackupService(this._db, this._clock);

  static const appId = 'growth_log';
  static const formatVersion = 1;

  final AppDatabase _db;
  final Clock _clock;

  Future<Map<String, Object?>> exportMap() async {
    List<Map<String, dynamic>> rows<T extends DataClass>(List<T> list) =>
        [for (final r in list) r.toJson()];

    final settings = await _db.select(_db.settings).get();
    return {
      'app': appId,
      'format': formatVersion,
      'schema': _db.schemaVersion,
      'exportedAt': _clock.now().toUtc().toIso8601String(),
      'data': {
        'skills': rows(await _db.select(_db.skills).get()),
        'sessions': rows(await _db.select(_db.practiceSessions).get()),
        'activeTimer': rows(await _db.select(_db.activeTimers).get()),
        'entries': rows(await _db.select(_db.entries).get()),
        'tags': rows(await _db.select(_db.tags).get()),
        'entryTags': rows(await _db.select(_db.entryTags).get()),
        'milestones': rows(await _db.select(_db.milestones).get()),
        'settings': rows(
          settings
              .where((s) => !SettingKeys.notPortable.contains(s.key))
              .toList(),
        ),
      },
    };
  }

  Future<String> exportJson() async =>
      const JsonEncoder.withIndent('  ').convert(await exportMap());

  /// Parses and validates a backup without touching the database.
  BackupSummary inspect(String json) => _parse(json).summary;

  /// Replaces all data with the backup. Everything happens in one
  /// transaction: if anything is invalid, the current data is untouched.
  Future<BackupSummary> importJson(String json) async {
    final parsed = _parse(json);
    await _db.transaction(() async {
      await _db.wipe();
      await _db.batch((b) {
        b.insertAll(_db.skills, parsed.skills);
        b.insertAll(_db.practiceSessions, parsed.sessions);
        b.insertAll(_db.activeTimers, parsed.activeTimer);
        b.insertAll(_db.entries, parsed.entries);
        b.insertAll(_db.tags, parsed.tags);
        b.insertAll(_db.entryTags, parsed.entryTags);
        b.insertAll(_db.milestones, parsed.milestones);
        b.insertAll(_db.settings, parsed.settings);
      });
    });
    return parsed.summary;
  }

  _Parsed _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupException("That file isn't valid JSON.");
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != appId) {
      throw const BackupException("That file isn't a Growth Log backup.");
    }
    final format = decoded['format'];
    if (format is! int || format > formatVersion) {
      throw const BackupException(
        'This backup was made by a newer version of Growth Log.',
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const BackupException('The backup is missing its data.');
    }

    List<T> list<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = data[key] ?? const <Object?>[];
      if (raw is! List) throw BackupException('"$key" is not a list.');
      try {
        return [for (final r in raw) fromJson(r as Map<String, dynamic>)];
      } catch (_) {
        throw BackupException('Some "$key" records are damaged.');
      }
    }

    final parsed = _Parsed(
      skills: list('skills', SkillRow.fromJson),
      sessions: list('sessions', SessionRow.fromJson),
      activeTimer: list('activeTimer', ActiveTimerRow.fromJson),
      entries: list('entries', EntryRow.fromJson),
      tags: list('tags', TagRow.fromJson),
      entryTags: list('entryTags', EntryTagRow.fromJson),
      milestones: list('milestones', MilestoneRow.fromJson),
      settings: list('settings', SettingRow.fromJson)
          .where((s) => !SettingKeys.notPortable.contains(s.key))
          .toList(),
    );

    // Referential checks up front so the error message is useful.
    final skillIds = {for (final s in parsed.skills) s.id};
    final entryIds = {for (final e in parsed.entries) e.id};
    final tagIds = {for (final t in parsed.tags) t.id};
    final ok = parsed.sessions.every((s) => skillIds.contains(s.skillId)) &&
        parsed.milestones.every((m) => skillIds.contains(m.skillId)) &&
        parsed.activeTimer.every((t) => skillIds.contains(t.skillId)) &&
        parsed.entries
            .every((e) => e.skillId == null || skillIds.contains(e.skillId)) &&
        parsed.entryTags.every(
          (et) => entryIds.contains(et.entryId) && tagIds.contains(et.tagId),
        );
    if (!ok) {
      throw const BackupException(
        'The backup has records that point to missing data.',
      );
    }
    return parsed;
  }
}

class _Parsed {
  _Parsed({
    required this.skills,
    required this.sessions,
    required this.activeTimer,
    required this.entries,
    required this.tags,
    required this.entryTags,
    required this.milestones,
    required this.settings,
  });

  final List<SkillRow> skills;
  final List<SessionRow> sessions;
  final List<ActiveTimerRow> activeTimer;
  final List<EntryRow> entries;
  final List<TagRow> tags;
  final List<EntryTagRow> entryTags;
  final List<MilestoneRow> milestones;
  final List<SettingRow> settings;

  BackupSummary get summary => BackupSummary(
        skills: skills.length,
        sessions: sessions.length,
        entries: entries.length,
      );
}
