import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/features/skills/domain/levels.dart';

const h = 3600;

void main() {
  group('Levels.forSeconds', () {
    test('thresholds map to the right level', () {
      expect(Levels.forSeconds(0), Levels.novice);
      expect(Levels.forSeconds(20 * h - 1), Levels.novice);
      expect(Levels.forSeconds(20 * h), Levels.apprentice);
      expect(Levels.forSeconds(99 * h), Levels.apprentice);
      expect(Levels.forSeconds(100 * h), Levels.skilled);
      expect(Levels.forSeconds(1000 * h), Levels.expert);
      expect(Levels.forSeconds(10000 * h), Levels.master);
      expect(Levels.forSeconds(50000 * h), Levels.master);
    });
  });

  group('Levels.progress', () {
    test('halfway between Novice and Apprentice', () {
      final p = Levels.progress(10 * h);
      expect(p.current, Levels.novice);
      expect(p.next, Levels.apprentice);
      expect(p.fraction, closeTo(0.5, 1e-9));
      expect(p.secondsToNext, 10 * h);
    });

    test('progress is relative to the current level band', () {
      final p = Levels.progress(60 * h); // 40 of the 80 h between 20 and 100
      expect(p.current, Levels.apprentice);
      expect(p.fraction, closeTo(0.5, 1e-9));
    });

    test('max level is complete', () {
      final p = Levels.progress(12000 * h);
      expect(p.isMax, isTrue);
      expect(p.fraction, 1);
      expect(p.secondsToNext, 0);
    });

    test('negative input is treated as zero', () {
      final p = Levels.progress(-50);
      expect(p.current, Levels.novice);
      expect(p.fraction, 0);
    });
  });

  group('milestones', () {
    test('reachedMilestones lists every crossed mark', () {
      expect(Levels.reachedMilestones(0), isEmpty);
      expect(Levels.reachedMilestones(h - 1), isEmpty);
      expect(Levels.reachedMilestones(h), [1]);
      expect(Levels.reachedMilestones(21 * h), [1, 5, 10, 20]);
    });

    test('level thresholds are milestones', () {
      for (final l in Levels.all.skip(1)) {
        expect(Levels.milestoneHours, contains(l.minHours));
        expect(Levels.levelAtExactly(l.minHours), l);
      }
      expect(Levels.levelAtExactly(5), isNull);
    });

    test('titles read naturally', () {
      expect(
        Levels.milestoneTitle(1, 'Piano'),
        'Hit 1 hour of Piano practice!',
      );
      expect(
        Levels.milestoneTitle(50, 'Piano'),
        'Hit 50 hours of Piano practice!',
      );
      expect(
        Levels.milestoneTitle(100, 'Piano'),
        'Reached Skilled in Piano — 100 hours of practice!',
      );
    });
  });
}
