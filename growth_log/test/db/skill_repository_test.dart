import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/features/log/data/entry_repository.dart';
import 'package:growth_log/features/skills/data/skill_repository.dart';

import '../helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  group('skills', () {
    test('create assigns increasing sort order and trims input', () async {
      final a = await env.skills.createSkill(
        const SkillDraft(
          name: '  Guitar  ',
          description: '   ',
          iconKey: 'guitar',
          colorValue: 1,
        ),
      );
      final b = await env.skill('Spanish');
      final rowA = (await env.skills.getSkill(a))!;
      final rowB = (await env.skills.getSkill(b))!;
      expect(rowA.name, 'Guitar');
      expect(rowA.description, isNull);
      expect(rowB.sortOrder, greaterThan(rowA.sortOrder));
    });

    test('validation rejects empty and overly long names', () async {
      expect(
        () => env.skills.createSkill(
          const SkillDraft(name: ' ', iconKey: 'x', colorValue: 1),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => env.skills.createSkill(
          SkillDraft(name: 'x' * 41, iconKey: 'x', colorValue: 1),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => env.skills.createSkill(
          const SkillDraft(
            name: 'ok',
            iconKey: 'x',
            colorValue: 1,
            targetHours: 0,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'archive hides from active list, disables reminder, stops timer',
      () async {
        final id = await env.skill();
        await env.skills.setReminder(id, enabled: true);
        await env.timer.start(id);
        await env.skills.setArchived(id, archived: true);

        expect(await env.skills.watchSkills().first, isEmpty);
        final archived = await env.skills.watchSkills(archived: true).first;
        expect(archived.single.reminderEnabled, isFalse);
        expect(await env.timer.active(), isNull);

        await env.skills.setArchived(id, archived: false);
        expect((await env.skills.watchSkills().first).single.id, id);
      },
    );

    test(
      'deleting a skill removes sessions + milestones, keeps entries',
      () async {
        final id = await env.skill();
        await env.skills.addSession(
          skillId: id,
          dayKey: 20260928,
          durationSec: 2 * 3600,
        );
        await env.milestones.reconcile(id);
        final manual = await env.entries.addEntry(
          EntryDraft(
            type: EntryType.win,
            body: 'Played live',
            dayKey: 20260928,
            skillId: id,
          ),
        );

        await env.skills.deleteSkill(id);

        expect(await env.skills.sessionCount(id), 0);
        expect(await env.milestones.watchForSkill(id).first, isEmpty);
        final kept = await env.entries.getEntry(manual);
        expect(kept, isNotNull);
        expect(kept!.entry.skillId, isNull);
      },
    );

    test('reorder persists order', () async {
      final a = await env.skill('A');
      final b = await env.skill('B');
      final c = await env.skill('C');
      await env.skills.reorder([c, a, b]);
      final list = await env.skills.watchSkills().first;
      expect(list.map((s) => s.id), [c, a, b]);
    });
  });

  group('sessions', () {
    test('totals, daily seconds and practice days', () async {
      final a = await env.skill('A');
      final b = await env.skill('B');
      await env.skills.addSession(
        skillId: a,
        dayKey: 20260927,
        durationSec: 1800,
      );
      await env.skills.addSession(
        skillId: a,
        dayKey: 20260928,
        durationSec: 3600,
      );
      await env.skills.addSession(
        skillId: b,
        dayKey: 20260928,
        durationSec: 600,
      );

      expect(await env.skills.totalSeconds(a), 5400);
      expect(await env.skills.totalsBySkill(), {a: 5400, b: 600});
      expect(await env.skills.totalsBySkill(from: 20260928, to: 20260928), {
        a: 3600,
        b: 600,
      });
      expect(await env.skills.dailySeconds(), {20260927: 1800, 20260928: 4200});
      expect(await env.skills.dailySeconds(skillId: b), {20260928: 600});
      expect(await env.skills.practiceDays(skillId: a), {20260927, 20260928});
      expect(await env.skills.practiceDaysBySkill(), {
        a: {20260927, 20260928},
        b: {20260928},
      });
    });

    test('validation: min 1 minute, max 24 h, not in the future', () async {
      final a = await env.skill();
      expect(
        () => env.skills.addSession(
          skillId: a,
          dayKey: 20260928,
          durationSec: 59,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => env.skills.addSession(
          skillId: a,
          dayKey: 20260928,
          durationSec: 86401,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => env.skills.addSession(
          skillId: a,
          dayKey: 20260929,
          durationSec: 600,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('update moves a session to another day and skill', () async {
      final a = await env.skill('A');
      final b = await env.skill('B');
      final s = await env.skills.addSession(
        skillId: a,
        dayKey: 20260928,
        durationSec: 600,
        note: 'x',
      );
      await env.skills.updateSession(
        s,
        skillId: b,
        dayKey: 20260920,
        durationSec: 1200,
        note: '  ',
      );
      final row = (await env.skills.getSession(s))!;
      expect(row.skillId, b);
      expect(row.dayKey, 20260920);
      expect(row.startedAt.day, 20);
      expect(row.durationSec, 1200);
      expect(row.note, isNull);
    });

    test('delete and restore (undo)', () async {
      final a = await env.skill();
      final s = await env.skills.addSession(
        skillId: a,
        dayKey: 20260928,
        durationSec: 600,
      );
      final row = (await env.skills.getSession(s))!;
      await env.skills.deleteSession(s);
      expect(await env.skills.totalSeconds(a), 0);
      await env.skills.restoreSession(row);
      expect(await env.skills.totalSeconds(a), 600);
    });

    test('watch helper re-emits on change', () async {
      final a = await env.skill();
      final stream = env.skills.watch(() => env.skills.totalSeconds(a));
      final values = <int>[];
      final sub = stream.listen(values.add);
      await pumpEventQueue();
      await env.skills.addSession(
        skillId: a,
        dayKey: 20260928,
        durationSec: 600,
      );
      await pumpEventQueue();
      await sub.cancel();
      expect(values.first, 0);
      expect(values.last, 600);
    });
  });
}
