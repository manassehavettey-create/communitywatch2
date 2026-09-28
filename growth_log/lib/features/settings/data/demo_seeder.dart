import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/day_key.dart';
import '../../log/data/entry_repository.dart';
import '../../skills/data/milestone_repository.dart';
import '../../skills/data/skill_repository.dart';

/// Fills the database with realistic sample data. Only reachable from the
/// Developer section of Settings, which exists in debug builds only.
class DemoSeeder {
  DemoSeeder(this._db, this._clock)
    : assert(kDebugMode, 'Demo data is debug-only');

  final AppDatabase _db;
  final Clock _clock;

  Future<void> seed({int days = 150}) async {
    final rnd = Random(42);
    final skills = SkillRepository(_db, _clock);
    final entries = EntryRepository(_db, _clock);
    final milestones = MilestoneRepository(_db, _clock);
    final today = _clock.today();

    final specs = [
      ('Guitar', 'guitar', Palette.lime, 1000.0, 0.8, 55),
      ('Spanish', 'translate', Palette.lavender, 500.0, 0.6, 30),
      ('Drawing', 'paint', Palette.apricot, 10000.0, 0.35, 70),
      ('Running', 'run', Palette.sky, 1000.0, 0.45, 40),
    ];
    final notes = [
      'Scales and chords',
      'Worked on a hard section',
      'Felt easy today',
      null,
      null,
      'Short but focused',
    ];

    final ids = <int>[];
    for (final (name, icon, color, target, chance, avgMin) in specs) {
      final id = await skills.createSkill(
        SkillDraft(
          name: name,
          iconKey: icon,
          colorValue: color.toARGB32(),
          targetHours: target,
        ),
      );
      ids.add(id);
      for (var d = days; d >= 0; d--) {
        if (rnd.nextDouble() > chance) continue;
        final minutes = max(10, (avgMin * (0.5 + rnd.nextDouble())).round());
        await skills.addSession(
          skillId: id,
          dayKey: Days.add(today, -d),
          durationSec: minutes * 60,
          note: notes[rnd.nextInt(notes.length)],
          source: rnd.nextBool() ? 'timer' : 'manual',
        );
      }
      await milestones.reconcile(id);
    }

    const gratitude = [
      'Coffee with an old friend',
      'The sunset on the way home',
      'A quiet morning before everyone woke up',
      'My sister calling just to chat',
      'Finding a great new album',
      'A long walk in the park',
      'Warm soup on a cold day',
    ];
    const wins = [
      'Played the whole song without stopping',
      'Had a 10-minute conversation in Spanish',
      'Finished a sketch I actually like',
      'Ran 5k without walking',
      'Shipped the project at work',
    ];
    const tags = [
      'family',
      'friends',
      'nature',
      'work',
      'music',
      'health',
      'small-joys',
    ];
    const moods = ['😊', '🥰', '😌', '🤩', '💪', null];

    for (var d = 60; d >= 0; d--) {
      if (rnd.nextDouble() < 0.25) continue;
      final day = Days.add(today, -d);
      await entries.addEntry(
        EntryDraft(
          type: EntryType.gratitude,
          body: gratitude[rnd.nextInt(gratitude.length)],
          dayKey: day,
          mood: moods[rnd.nextInt(moods.length)],
          tags: [tags[rnd.nextInt(tags.length)]],
        ),
      );
      if (rnd.nextDouble() < 0.4) {
        final i = rnd.nextInt(wins.length);
        await entries.addEntry(
          EntryDraft(
            type: EntryType.win,
            body: wins[i],
            dayKey: day,
            mood: '🔥',
            skillId: ids[i % ids.length],
            tags: [tags[rnd.nextInt(tags.length)], 'progress'],
          ),
        );
      }
    }
  }
}
