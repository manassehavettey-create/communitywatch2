import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/features/log/data/entry_repository.dart';
import 'package:growth_log/features/skills/data/skill_repository.dart';
import 'package:growth_log/features/skills/domain/levels.dart';
import 'package:growth_log/features/timer/data/timer_repository.dart';

import '../helpers.dart';

const h = 3600;

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  group('milestones', () {
    test('crossing a mark records it and auto-logs one win', () async {
      final id = await env.skill('Piano');
      await env.skills.addSession(
        skillId: id,
        dayKey: 20260928,
        durationSec: h,
      );
      final got = await env.milestones.reconcile(id);

      expect(got.map((a) => a.hours), [1]);
      final wins = await env.entries.query(
        const EntryFilter(type: EntryType.win),
      );
      expect(wins, hasLength(1));
      expect(wins.single.entry.isAuto, isTrue);
      expect(wins.single.entry.skillId, id);
      expect(wins.single.tags, ['milestone']);
      expect(wins.single.entry.body, contains('1 hour of Piano'));
    });

    test('reconcile is idempotent — no duplicate wins', () async {
      final id = await env.skill();
      await env.skills.addSession(
        skillId: id,
        dayKey: 20260928,
        durationSec: h,
      );
      await env.milestones.reconcile(id);
      final again = await env.milestones.reconcile(id);
      expect(again, isEmpty);
      expect(await env.entries.query(EntryFilter.none), hasLength(1));
    });

    test(
      'back-filling many hours records all, logs only the highest',
      () async {
        final id = await env.skill('Chess');
        await env.skills.addSession(
          skillId: id,
          dayKey: 20260928,
          durationSec: 22 * h,
        );
        final got = await env.milestones.reconcile(id);
        expect(got.map((a) => a.hours), [1, 5, 10, 20]);
        expect(got.last.level, Levels.apprentice);
        final wins = await env.entries.query(EntryFilter.none);
        expect(wins, hasLength(1));
        expect(wins.single.entry.body, contains('Apprentice'));
      },
    );

    test(
      'deleting sessions un-reaches milestones and removes auto wins',
      () async {
        final id = await env.skill();
        final s = await env.skills.addSession(
          skillId: id,
          dayKey: 20260928,
          durationSec: 6 * h,
        );
        await env.milestones.reconcile(id);
        expect(await env.entries.query(EntryFilter.none), hasLength(1));

        await env.skills.deleteSession(s);
        await env.milestones.reconcile(id);
        expect(await env.milestones.watchForSkill(id).first, isEmpty);
        expect(await env.entries.query(EntryFilter.none), isEmpty);
      },
    );

    test('an auto win the user edited is never auto-removed', () async {
      final id = await env.skill();
      final s = await env.skills.addSession(
        skillId: id,
        dayKey: 20260928,
        durationSec: h,
      );
      await env.milestones.reconcile(id);
      final win = (await env.entries.query(EntryFilter.none)).single;
      await env.entries.updateEntry(
        win.entry.id,
        EntryDraft(
          type: EntryType.win,
          body: 'My first hour!',
          dayKey: win.entry.dayKey,
          skillId: id,
        ),
      );
      await env.skills.deleteSession(s);
      await env.milestones.reconcile(id);
      expect(await env.entries.query(EntryFilter.none), hasLength(1));
    });
  });

  group('timer', () {
    test('elapsed time survives the app being killed', () async {
      final id = await env.skill();
      await env.timer.start(id);

      // Simulate a process death: a brand-new repository instance on the same
      // database, 42 minutes later.
      env.clock.advance(const Duration(minutes: 42));
      final revived = TimerRepository(env.db, env.clock);
      final active = await revived.active();
      expect(active, isNotNull);
      expect(revived.elapsed(active!), const Duration(minutes: 42));

      final stopped = await revived.stop(note: '  scales ');
      expect(stopped!.sessionId, isNotNull);
      final session = (await env.skills.getSession(stopped.sessionId!))!;
      expect(session.durationSec, 42 * 60);
      expect(session.source, 'timer');
      expect(session.note, 'scales');
      expect(session.dayKey, 20260928);
      expect(await revived.active(), isNull);
    });

    test('only one timer at a time', () async {
      final a = await env.skill('A');
      final b = await env.skill('B');
      await env.timer.start(a);
      expect(() => env.timer.start(b), throwsA(isA<ValidationException>()));
    });

    test('under a minute saves nothing', () async {
      final a = await env.skill();
      await env.timer.start(a);
      env.clock.advance(const Duration(seconds: 30));
      final stopped = await env.timer.stop();
      expect(stopped!.sessionId, isNull);
      expect(await env.skills.totalSeconds(a), 0);
    });

    test('clock moving backwards clamps elapsed to zero', () async {
      final a = await env.skill();
      final t = await env.timer.start(a);
      env.clock.advance(const Duration(hours: -2));
      expect(env.timer.elapsed(t), Duration.zero);
    });

    test('session crossing midnight belongs to the start day', () async {
      env.clock.set(DateTime(2026, 9, 27, 23, 30));
      final a = await env.skill();
      await env.timer.start(a);
      env.clock.set(DateTime(2026, 9, 28, 0, 45));
      final stopped = await env.timer.stop();
      final s = (await env.skills.getSession(stopped!.sessionId!))!;
      expect(s.dayKey, 20260927);
      expect(s.durationSec, 75 * 60);
    });

    test(
      'forgotten timer is capped at 24 h, and a custom duration wins',
      () async {
        final a = await env.skill();
        await env.timer.start(a);
        env.clock.advance(const Duration(hours: 30));
        final capped = await env.timer.stop();
        expect(
          (await env.skills.getSession(capped!.sessionId!))!.durationSec,
          24 * h,
        );

        await env.timer.start(a);
        env.clock.advance(const Duration(hours: 5));
        final custom = await env.timer.stop(durationSec: 90 * 60);
        expect(
          (await env.skills.getSession(custom!.sessionId!))!.durationSec,
          90 * 60,
        );
      },
    );

    test('deleting the skill cancels its running timer', () async {
      final a = await env.skill();
      await env.timer.start(a);
      await env.skills.deleteSkill(a);
      expect(await env.timer.active(), isNull);
    });
  });
}
