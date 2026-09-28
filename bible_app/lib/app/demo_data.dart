import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bible/references.dart';
import '../core/theme/tokens.dart';
import '../data/db/database.dart';
import '../data/repos/journal_repository.dart';
import '../data/repos/prayer_repository.dart';
import '../domain/days.dart';
import 'providers.dart';

/// Sample content for trying the app. Only reachable in debug builds
/// (Settings → Developer); release builds never create demo data.
class DemoData {
  DemoData(this.ref);

  final Ref ref;

  Future<void> load() async {
    assert(kDebugMode, 'Demo data is for debug builds only');
    if (!kDebugMode) return;
    final ann = ref.read(annotationsRepositoryProvider);
    final w = ref.read(syncWriterProvider);
    final db = ref.read(databaseProvider);

    VerseRange r(String code) => VerseRange.parseCode(code);
    await ann.highlight([r('JHN.3.16')], HighlightColor.butter);
    await ann.highlight([r('PSA.23.1-PSA.23.3')], HighlightColor.sage);
    await ann.highlight([r('ROM.8.28')], HighlightColor.sky);
    await ann.toggleBookmark(r('PHP.4.6-PHP.4.7'), 'kjv');
    await ann.saveNote(
      r: r('PSA.23.4'),
      body: 'Even here — not avoided, but accompanied.',
    );
    await ann.saveVerses(
      r('ISA.40.31'),
      'kjv',
      'But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.',
    );

    final prayers = ref.read(prayerRepositoryProvider);
    await prayers.save(
      const PrayerDraft(
        title: 'Wisdom for the new job',
        body: 'Clarity in the first weeks.',
        category: PrayerCategory.work,
        scriptureRef: 'JAS.1.5',
      ),
    );
    await prayers.save(
      const PrayerDraft(
        title: 'Mum’s recovery',
        category: PrayerCategory.family,
      ),
    );
    final answered = await prayers.save(
      const PrayerDraft(
        title: 'Safe travel home',
        category: PrayerCategory.personal,
      ),
    );
    await prayers.markAnswered(answered, note: 'Arrived early, no delays.');

    final journal = ref.read(journalRepositoryProvider);
    await journal.save(
      JournalDraft(
        title: 'Psalm 23 again',
        body: 'Read it slowly this morning. “He restoreth my soul” — restoring, not replacing.',
        date: DateTime.now().subtract(const Duration(days: 1)),
        scriptureRef: 'PSA.23.1-PSA.23.6',
        tags: const ['psalms', 'rest'],
      ),
    );
    await journal.save(
      JournalDraft(
        title: 'Grateful',
        body: 'Long walk, good conversation, early night.',
        date: DateTime.now(),
        tags: const ['gratitude'],
      ),
    );

    // Reading history: most of the last two weeks.
    final today = Days.today();
    for (var i = 13; i >= 0; i--) {
      if (i == 6 || i == 9) continue;
      final day = Days.add(today, -i);
      await w.write(
        'reading_activity',
        day,
        (t) => db
            .into(db.readingActivity)
            .insertOnConflictUpdate(
              ReadingActivityCompanion.insert(
                id: day,
                userId: Value(w.userId),
                createdAt: t,
                updatedAt: t,
                chapters: Value(1 + i % 3),
                seconds: Value(300 + i * 20),
              ),
            ),
      );
    }
    for (var c = 1; c <= 21; c++) {
      await ref
          .read(readingRepositoryProvider)
          .recordChapterRead(ChapterRef('JHN', c));
    }
    final plans = ref.read(plansRepositoryProvider);
    final id = await plans.start('proverbs-31');
    for (var d = 1; d <= 9; d++) {
      await plans.setDayComplete(id, d, true, totalDays: 31);
    }
  }
}

final demoDataProvider = Provider((ref) => DemoData(ref));
