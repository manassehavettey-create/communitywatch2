import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/features/log/data/entry_repository.dart';
import 'package:growth_log/features/settings/data/backup_service.dart';
import 'package:growth_log/features/settings/data/settings_repository.dart';
import 'package:growth_log/features/skills/data/skill_repository.dart';

import '../helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  EntryDraft draft(
    String body, {
    EntryType type = EntryType.gratitude,
    int day = 20260928,
    List<String> tags = const [],
    int? skillId,
  }) =>
      EntryDraft(type: type, body: body, dayKey: day, tags: tags, skillId: skillId);

  group('entries', () {
    test('tags are normalised, de-duplicated and counted', () async {
      final id = await env.entries.addEntry(
        draft('first', tags: ['#Family', 'family ', 'Deep Work']),
      );
      await env.entries.addEntry(draft('second', tags: ['family']));
      final e = (await env.entries.getEntry(id))!;
      expect(e.tags, ['deep-work', 'family']);
      final counts = await env.entries.tagCounts();
      expect(counts.first.name, 'family');
      expect(counts.first.count, 2);
    });

    test('filters: type, tag, skill, date range and text', () async {
      final guitar = await env.skill('Guitar');
      await env.entries.addEntry(draft('Sunny walk', day: 20260920, tags: ['outdoors']));
      await env.entries.addEntry(
        draft('Nailed the solo', type: EntryType.win, skillId: guitar, tags: ['music']),
      );
      await env.entries.addEntry(draft('Coffee with Sam', day: 20260927));

      Future<List<String>> bodies(EntryFilter f) async =>
          [for (final v in await env.entries.query(f)) v.entry.body];

      expect(await bodies(EntryFilter.none), [
        'Nailed the solo',
        'Coffee with Sam',
        'Sunny walk',
      ]);
      expect(await bodies(const EntryFilter(type: EntryType.win)), ['Nailed the solo']);
      expect(await bodies(const EntryFilter(tags: {'outdoors'})), ['Sunny walk']);
      expect(await bodies(EntryFilter(skillId: guitar)), ['Nailed the solo']);
      expect(
        await bodies(const EntryFilter(from: 20260921, to: 20260927)),
        ['Coffee with Sam'],
      );
      expect(await bodies(const EntryFilter(query: 'COFFEE')), ['Coffee with Sam']);
      // Search also matches tag names and linked skill names.
      expect(await bodies(const EntryFilter(query: 'guitar')), ['Nailed the solo']);
    });

    test('very long text is rejected, long-but-valid text round-trips', () async {
      expect(
        () => env.entries.addEntry(draft('x' * (EntryLimits.bodyMax + 1))),
        throwsA(isA<ValidationException>()),
      );
      final body = 'y' * EntryLimits.bodyMax;
      final id = await env.entries.addEntry(draft(body));
      expect((await env.entries.getEntry(id))!.entry.body, body);
    });

    test('update replaces tags and prunes orphans; delete + restore', () async {
      final id = await env.entries.addEntry(draft('a', tags: ['old']));
      await env.entries.updateEntry(id, draft('a2', tags: ['new']));
      expect((await env.entries.tagCounts()).map((t) => t.name), ['new']);

      final view = (await env.entries.getEntry(id))!;
      await env.entries.deleteEntry(id);
      expect(await env.entries.tagCounts(), isEmpty);
      await env.entries.restoreEntry(view);
      final back = (await env.entries.getEntry(id))!;
      expect(back.entry.body, 'a2');
      expect(back.tags, ['new']);
    });

    test('future-dated entries are rejected', () async {
      expect(
        () => env.entries.addEntry(draft('x', day: 20261001)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('counts and entry days', () async {
      await env.entries.addEntry(draft('a', day: 20260927));
      await env.entries.addEntry(draft('b', type: EntryType.win));
      await env.entries.addEntry(draft('c'));
      expect(await env.entries.entryDays(), {20260927, 20260928});
      final counts = await env.entries.countsBetween(20260928, 20260928);
      expect(counts[EntryType.gratitude], 1);
      expect(counts[EntryType.win], 1);
    });
  });

  group('backup', () {
    test('export → import round-trips everything', () async {
      final settings = SettingsRepository(env.db);
      await settings.set(SettingKeys.themeMode, 'dark');
      await settings.set(SettingKeys.lockEnabled, true);
      final a = await env.skill('Guitar');
      await env.skills.addSession(skillId: a, dayKey: 20260928, durationSec: 2 * 3600, note: 'scales');
      await env.milestones.reconcile(a);
      await env.entries.addEntry(draft('thanks', tags: ['family'], skillId: a));
      await env.timer.start(a);

      final backup = BackupService(env.db, env.clock);
      final json = await backup.exportJson();

      final other = TestEnv();
      addTearDown(other.dispose);
      await other.skill('Something else');
      final summary = await BackupService(other.db, other.clock).importJson(json);

      expect(summary.skills, 1);
      expect(summary.sessions, 1);
      expect(summary.entries, 2); // manual + auto milestone win
      final skills = await other.skills.watchSkills().first;
      expect(skills.single.name, 'Guitar');
      expect(await other.skills.totalSeconds(a), 7200);
      final entries = await other.entries.query(const EntryFilter(tags: {'family'}));
      expect(entries.single.entry.body, 'thanks');
      expect(await other.milestones.watchForSkill(a).first, hasLength(1));
      expect(await other.timer.active(), isNotNull);

      final restored = await SettingsRepository(other.db).load();
      expect(restored.themeMode.name, 'dark');
      // Lock state never travels with a backup.
      expect(restored.lockEnabled, isFalse);
    });

    test('invalid files are rejected without touching existing data', () async {
      final backup = BackupService(env.db, env.clock);
      await env.skill('Keep me');

      for (final bad in [
        'not json',
        '{"app":"other"}',
        jsonEncode({'app': 'growth_log', 'format': 99, 'data': {}}),
        jsonEncode({
          'app': 'growth_log',
          'format': 1,
          'data': {
            'skills': [],
            'sessions': [
              {'id': 1, 'skillId': 42, 'startedAt': 0, 'dayKey': 1, 'durationSec': 60, 'note': null, 'source': 'manual', 'createdAt': 0},
            ],
          },
        }),
        jsonEncode({
          'app': 'growth_log',
          'format': 1,
          'data': {
            'skills': [
              {'id': 'oops'},
            ],
          },
        }),
      ]) {
        await expectLater(backup.importJson(bad), throwsA(isA<BackupException>()));
      }
      final skills = await env.skills.watchSkills().first;
      expect(skills.single.name, 'Keep me');
    });
  });
}
