import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import '../../shared/widgets/progress.dart';
import '../library/import_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = Motion.of(context);
    final settings = ref.watch(settingsProvider);
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final current = ref.watch(continueReadingProvider);
    final stats = ref.watch(statsProvider).value;
    final now = DateTime.now();
    final name = settings.name.trim();

    final recent = [...books]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.navClearance),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('EEEE, d MMMM').format(now), style: context.text.bodySmall),
                        const SizedBox(height: 6),
                        Semantics(
                          header: true,
                          child: Text(
                            name.isEmpty ? '${greeting(now)}.' : '${greeting(now)},\n$name.',
                            style: context.text.displaySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleIconButton(
                    icon: PhosphorIconsRegular.plus,
                    tooltip: 'Add books',
                    filled: true,
                    onPressed: () => pickAndImportBooks(context, ref),
                  ),
                ],
              ),
            ),
            if (books.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.x8),
                child: EmptyState(
                  art: Art.emptyLibrary,
                  title: 'Your shelf is empty',
                  message: 'Add a PDF to start your library. It stays on this phone, private and searchable.',
                  action: FilledButton.icon(
                    onPressed: () => pickAndImportBooks(context, ref),
                    icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                    label: const Text('Add your first book'),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: Space.x5),
              if (current != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: _ContinueCard(book: current),
                ).animate().fadeIn(duration: m.base).moveY(begin: 10, end: 0, curve: Motion.curve)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: _StartCard(book: recent.first),
                ),
              if (stats != null) ...[
                const SizedBox(height: Space.x4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: _TodayRow(stats: stats, goalMinutes: settings.dailyGoalMinutes),
                ),
              ],
              SectionHeader('Recently added', action: 'See all', onAction: () => context.go('/library')),
              SizedBox(
                height: 236,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  itemCount: recent.length.clamp(0, 12),
                  separatorBuilder: (_, _) => const SizedBox(width: Space.x4),
                  itemBuilder: (context, i) {
                    final b = recent[i];
                    return GestureDetector(
                      onTap: () => context.push('/book/${b.id}'),
                      child: SizedBox(
                        width: 112,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BookCover(book: b, width: 112, hero: false),
                            const SizedBox(height: Space.x2),
                            Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                            Text(relativeDay(b.addedAt), style: context.text.bodySmall),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: m.base, delay: m.stagger(i));
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dark = context.brightness == Brightness.dark;
    // The one dark block on Home in light mode; a raised surface at night.
    final bg = dark ? c.surfaceMuted : c.ink;
    final fg = dark ? c.ink : c.onInk;
    final muted = fg.withValues(alpha: 0.65);
    final pos = ref.watch(positionProvider(book.id)).value;
    final page = pos?.page ?? (book.furthestPage > 0 ? book.furthestPage : 1);

    return Semantics(
      button: true,
      label: 'Continue reading ${book.title}, page $page of ${book.pageCount}',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: Radii.xlAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/read/${book.id}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.x5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(book: book, width: 92),
                const SizedBox(width: Space.x5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTINUE READING', style: context.text.labelSmall?.copyWith(color: c.lime)),
                      const SizedBox(height: Space.x2),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(color: fg),
                      ),
                      if (book.author != null)
                        Text(
                          book.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(color: muted),
                        ),
                      const SizedBox(height: Space.x4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${book.progressPercent}',
                            style: context.text.displayMedium?.copyWith(color: fg, fontSize: 36),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5, left: 2),
                            child: Text('%', style: context.text.titleMedium?.copyWith(color: fg)),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'p. $page / ${book.pageCount}',
                              style: context.text.labelMedium?.copyWith(color: muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x2),
                      FolioProgressBar(value: book.progress, track: fg.withValues(alpha: 0.14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    return BlockCard(
      color: ShelfColor.lilac.cardBackground(b),
      radius: Radii.xl,
      onTap: () => context.push('/book/${book.id}'),
      child: Row(
        children: [
          BookCover(book: book, width: 72, hero: false),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'START SOMETHING NEW',
                  style: context.text.labelSmall?.copyWith(color: ShelfColor.lilac.cardForeground(b)),
                ),
                const SizedBox(height: 6),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge?.copyWith(color: ShelfColor.lilac.cardForeground(b)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.pageCount} pages',
                  style: context.text.bodySmall?.copyWith(color: ShelfColor.lilac.cardForeground(b)),
                ),
              ],
            ),
          ),
          Icon(PhosphorIconsRegular.arrowRight, color: ShelfColor.lilac.cardForeground(b)),
        ],
      ),
    );
  }
}

/// Goal ring + three compact stats. Kept deliberately small.
class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.stats, required this.goalMinutes});
  final StatsSummary stats;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final minutes = stats.secondsToday ~/ 60;
    final goalProgress = goalMinutes <= 0 ? 0.0 : minutes / goalMinutes;
    Widget tile(ShelfColor color, String value, String label, {IconData? icon}) => Expanded(
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(Space.x3),
        decoration: BoxDecoration(color: color.cardBackground(b), borderRadius: Radii.lgAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [if (icon != null) Icon(icon, size: 16, color: color.cardForeground(b))]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: context.text.headlineMedium?.copyWith(color: color.cardForeground(b), height: 1)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(color: color.cardForeground(b).withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        GestureDetector(
          onTap: () => context.go('/stats'),
          child: Container(
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: Radii.lgAll),
            child: Row(
              children: [
                ProgressRing(
                  value: goalProgress,
                  size: 64,
                  stroke: 8,
                  child: Icon(
                    goalProgress >= 1 ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.target,
                    size: 22,
                  ),
                ),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goalProgress >= 1 ? 'Daily goal reached' : 'Today’s goal', style: context.text.titleMedium),
                      Text('$minutes of $goalMinutes min read', style: context.text.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(PhosphorIconsFill.fire, size: 18, color: ShelfColor.peach.strong),
                        const SizedBox(width: 4),
                        CountUp(stats.streak.current, style: context.text.titleLarge),
                      ],
                    ),
                    Text('day streak', style: context.text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            tile(ShelfColor.butter, '${stats.pagesToday}', 'pages today', icon: PhosphorIconsRegular.bookOpen),
            const SizedBox(width: Space.x3),
            tile(
              ShelfColor.sky,
              formatDuration(Duration(seconds: stats.secondsToday), short: true),
              'read today',
              icon: PhosphorIconsRegular.clock,
            ),
            const SizedBox(width: Space.x3),
            tile(ShelfColor.mint, '${stats.booksFinished}', 'finished', icon: PhosphorIconsRegular.checkCircle),
          ],
        ),
      ],
    );
  }
}
