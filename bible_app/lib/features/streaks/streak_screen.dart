import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../bible/canon.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/progress.dart';
import '../../data/repos/reading_repository.dart';
import '../../domain/days.dart';

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = ref.watch(readingStatsProvider).value ?? ReadingStats.empty;
    final read = ref.watch(readChaptersProvider).value ?? const <String>{};
    final s = stats.streak;
    final big = AppType.displayL.copyWith(
      fontFamily: 'Urbanist',
      fontSize: 64,
      height: 1,
      color: p.onPastel,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.x14),
          children: [
            ScreenHeader(
              title: 'Your reading',
              subtitle: s.readToday ? 'read today' : 'every day counts',
              leading: CircleIconButton(
                icon: PhosphorIconsBold.caretLeft,
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
            ),
            Reveal(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(
                  children: [
                    Expanded(
                      child: PastelCard(
                        color: p.butter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedCount(value: s.current, style: big),
                            const SizedBox(height: Space.x2),
                            Text(
                              'Current streak',
                              style: AppType.label.copyWith(color: p.onPastel),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: PastelCard(
                        color: p.sage,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedCount(value: s.longest, style: big),
                            const SizedBox(height: Space.x2),
                            Text(
                              'Longest streak',
                              style: AppType.label.copyWith(color: p.onPastel),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Reveal(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x3,
                  Space.gutter,
                  0,
                ),
                child: Row(
                  children: [
                    _SmallStat(
                      label: 'Reading days',
                      value: s.totalDays,
                      color: p.sky,
                    ),
                    const SizedBox(width: Space.x3),
                    _SmallStat(
                      label: 'Chapters',
                      value: stats.chaptersRead,
                      color: p.blush,
                    ),
                    const SizedBox(width: Space.x3),
                    _SmallStat(
                      label: 'Books',
                      value: stats.booksCompleted,
                      color: p.cream,
                    ),
                  ],
                ),
              ),
            ),
            const SectionHeader(title: 'Calendar'),
            Reveal(
              index: 2,
              child: _MonthCalendar(
                month: _month,
                days: stats.days,
                onPrev: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext:
                    _month.year == DateTime.now().year &&
                        _month.month == DateTime.now().month
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
              ),
            ),
            const SectionHeader(title: 'Through the Bible'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Column(
                children: [
                  for (final t in Testament.values) ...[
                    Builder(
                      builder: (context) {
                        final books = Canon.testament(t);
                        final total = books.fold(
                          0,
                          (n, b) => n + b.chapterCount,
                        );
                        final done = read
                            .where(
                              (c) =>
                                  Canon.tryById(c.split('.').first)
                                      ?.testament ==
                                  t,
                            )
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.x4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.label,
                                      style: AppType.titleS.copyWith(
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$done / $total chapters',
                                    style: AppType.caption.copyWith(
                                      color: p.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.x2),
                              ProgressBar(
                                value: done / total,
                                color: t == Testament.old ? p.coral : p.sky,
                                track: p.paperDeep,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: PastelCard(
        color: color,
        radius: Radii.md,
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCount(
              value: value,
              style: AppType.titleL.copyWith(
                color: p.onPastel,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(label, style: AppType.caption.copyWith(color: p.onPastel)),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.days,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final Map<String, int> days;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Monday first
    final today = Days.today();
    final labels = DateFormat.E().dateSymbols.NARROWWEEKDAYS;
    // NARROWWEEKDAYS starts on Sunday.
    final weekdays = [...labels.sublist(1), labels.first];

    Color tileColor(int chapters) => switch (chapters) {
      0 => p.paperDeep,
      1 => p.sage.withValues(alpha: 0.55),
      2 || 3 => p.sage,
      _ => p.tangerine,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: SurfaceCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: m.fast,
                    child: Text(
                      DateFormat('MMMM yyyy').format(month),
                      key: ValueKey(month),
                      style: AppType.titleS.copyWith(color: p.ink),
                    ),
                  ),
                ),
                CircleIconButton(
                  icon: PhosphorIconsBold.caretLeft,
                  tooltip: 'Previous month',
                  size: 36,
                  onPressed: onPrev,
                ),
                const SizedBox(width: Space.x2),
                CircleIconButton(
                  icon: PhosphorIconsBold.caretRight,
                  tooltip: 'Next month',
                  size: 36,
                  onPressed: onNext,
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Row(
              children: [
                for (final w in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: AppType.caption.copyWith(color: p.inkMute),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.x2),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var d = 1; d <= daysInMonth; d++)
                  Builder(
                    builder: (context) {
                      final key = Days.key(
                        DateTime(month.year, month.month, d),
                      );
                      final chapters = days[key] ?? 0;
                      final isToday = key == today;
                      return Semantics(
                        label:
                            '${DateFormat('d MMMM').format(DateTime(month.year, month.month, d))}: '
                            '${chapters == 0 ? 'no reading' : '$chapters chapters'}',
                        child: AnimatedContainer(
                          duration: m.base,
                          decoration: BoxDecoration(
                            color: tileColor(chapters),
                            borderRadius: Radii.xsAll,
                            border: isToday
                                ? Border.all(color: p.ink, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$d',
                            style: AppType.caption.copyWith(
                              color: chapters > 0 ? p.onPastel : p.inkSoft,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Less', style: AppType.caption.copyWith(color: p.inkMute)),
                const SizedBox(width: 6),
                for (final c in [0, 1, 2, 4])
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: tileColor(c),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const SizedBox(width: 6),
                Text('More', style: AppType.caption.copyWith(color: p.inkMute)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
