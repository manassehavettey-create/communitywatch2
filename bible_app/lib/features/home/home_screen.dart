import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/sticker.dart';
import '../../domain/plans.dart';
import '../reader/reader_screen.dart';
import 'verse_of_day.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good evening';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final user = ref.watch(currentUserProvider).value;
    final first = user?.displayName?.split(' ').first;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.tabBarClearance),
          children: [
            Reveal(
              child: ScreenHeader(
                title: first == null
                    ? greeting(now)
                    : '${greeting(now)},\n$first',
                subtitle: DateFormat('EEEE, d MMMM').format(now),
                actions: [
                  CircleIconButton(
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    tooltip: 'Search',
                    onPressed: () => context.push('/search'),
                  ),
                  CircleIconButton(
                    icon: PhosphorIconsRegular.bookmarksSimple,
                    tooltip: 'Saved',
                    onPressed: () => context.push('/saved'),
                  ),
                ],
              ),
            ),
            const Reveal(index: 1, child: _VerseAndContinue()),
            const Reveal(index: 2, child: _PlanCard()),
            const Reveal(index: 3, child: _StreakRow()),
            const Reveal(index: 4, child: _QuickAccess()),
            const Reveal(index: 5, child: _RecentlySaved()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _VerseAndContinue extends ConsumerWidget {
  const _VerseAndContinue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final bible = ref.watch(currentBibleProvider);
    final prefs = ref.watch(prefsValueProvider);
    final votd = verseOfTheDay(DateTime.now());
    final last = prefs.lastChapter;

    final verseCard = PastelCard(
      color: p.butter,
      semanticLabel: 'Verse of the day, ${votd.label}',
      onTap: () => context.push(ReaderArgs.location(votd.start, flash: votd)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'VERSE OF THE DAY',
                style: AppType.overline.copyWith(color: p.onPastel),
              ),
              const Spacer(),
              _MiniAction(
                icon: PhosphorIconsRegular.image,
                label: 'Make a card',
                onTap: () => context.push(
                  Uri(
                    path: '/share',
                    queryParameters: {
                      'r': votd.code,
                      if (bible.value != null) 't': bible.value!.info.id,
                    },
                  ).toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          bible.when(
            loading: () => const SkeletonParagraph(lines: 3),
            error: (_, _) => Text(votd.label, style: AppType.body),
            data: (b) {
              final text = b
                  .versesIn(votd)
                  .map(
                    (e) => VerseText.plain(
                      e.$2,
                      suppliedWords: b.info.suppliedWords,
                    ),
                  )
                  .join(' ');
              return Text(
                '“$text”',
                style: fontStyle(
                  'Fraunces',
                  size: 22,
                  height: 1.35,
                  weight: FontWeight.w500,
                  color: p.onPastel,
                  extraAxes: const [
                    FontVariation('SOFT', 100),
                    FontVariation('opsz', 24),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Space.x3),
          Text(
            '${votd.label}${bible.value == null ? '' : ' · ${bible.value!.info.abbreviation}'}',
            style: AppType.label.copyWith(color: p.onPastel),
          ),
        ],
      ),
    );

    final continueCard = PastelCard(
      color: p.coral,
      semanticLabel: last == null
          ? 'Start reading'
          : 'Continue reading ${last.label}',
      onTap: () => context.push(
        last == null
            ? ReaderArgs.location(const VerseRef('JHN', 1, 1))
            : ReaderArgs.location(
                VerseRef(last.bookId, last.chapter, prefs.lastVerse ?? 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null ? 'Start reading' : 'Pick up where you left off',
                  style: AppType.label.copyWith(color: p.onPastel),
                ),
                const SizedBox(height: 2),
                Text(
                  last?.label ?? 'John 1',
                  style: AppType.displayS.copyWith(color: p.onPastel),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: p.onPastel,
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorIconsBold.arrowRight, color: p.coral),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: LinkedCards(
        top: verseCard,
        bottom: continueCard,
        tabColor: p.coral,
      ),
    );
  }
}

/// Two stacked cards joined by a small tab (the bottom card's colour
/// reaching up across the seam), so they read as one unit.
class LinkedCards extends StatelessWidget {
  const LinkedCards({
    super.key,
    required this.top,
    required this.bottom,
    required this.tabColor,
  });

  final Widget top;
  final Widget bottom;
  final Color tabColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        const SizedBox(height: 6),
        Stack(
          clipBehavior: Clip.none,
          children: [
            bottom,
            Positioned(
              top: -16,
              left: 32,
              child: IgnorePointer(
                child: Container(
                  width: 64,
                  height: 22,
                  decoration: BoxDecoration(
                    color: tabColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: p.onPastel.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: p.onPastel),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlanCard extends ConsumerWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final plans = ref.watch(userPlansProvider).value ?? const [];
    final active = plans
        .where((u) => u.state.status == PlanStatus.active)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x3,
        Space.gutter,
        0,
      ),
      child: active == null
          ? PastelCard(
              color: p.sage,
              onTap: () => context.go('/plans'),
              semanticLabel: 'Choose a reading plan',
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'READING PLANS',
                          style: AppType.overline.copyWith(color: p.onPastel),
                        ),
                        const SizedBox(height: Space.x2),
                        Text(
                          'Find a rhythm that fits your days',
                          style: AppType.titleM.copyWith(color: p.onPastel),
                        ),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsBold.arrowRight),
                ],
              ),
            )
          : Builder(
              builder: (context) {
                final s = active.state;
                final day = s.currentDay;
                return PastelCard(
                  color: p.sage,
                  semanticLabel:
                      '${active.plan.title}, ${s.percent} percent complete',
                  onTap: () => context.push('/plans/${active.plan.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.isFinished
                                  ? 'COMPLETE'
                                  : 'DAY $day OF ${s.totalDays}',
                              style: AppType.overline.copyWith(
                                color: p.onPastel,
                              ),
                            ),
                            const SizedBox(height: Space.x1),
                            Text(
                              active.plan.title,
                              style: AppType.titleM.copyWith(color: p.onPastel),
                            ),
                            const SizedBox(height: Space.x2),
                            if (!s.isFinished)
                              Text(
                                'Today: ${active.plan.labelFor(day)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.bodySmall.copyWith(
                                  color: p.onPastel,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.x3),
                      ProgressRing(
                        value: s.fraction,
                        size: 72,
                        color: p.onPastel,
                        track: p.onPastel.withValues(alpha: 0.15),
                        child: Text(
                          '${s.percent}%',
                          style: AppType.label.copyWith(
                            color: p.onPastel,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StreakRow extends ConsumerWidget {
  const _StreakRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final stats = ref.watch(readingStatsProvider).value;
    final streak = stats?.streak;
    final current = streak?.current ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x3,
        Space.gutter,
        0,
      ),
      child: SurfaceCard(
        onTap: () => context.push('/streak'),
        padding: const EdgeInsets.all(Space.x4),
        child: Row(
          children: [
            Sticker(
              color: streak?.readToday ?? false ? p.tangerine : p.butter,
              size: 76,
              child: AnimatedCount(
                value: current,
                style: AppType.titleL.copyWith(
                  color: p.onPastel,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current == 1 ? 'day in a row' : 'days in a row',
                    style: AppType.titleM.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak == null || streak.totalDays == 0
                        ? 'Read a chapter to begin.'
                        : streak.readToday
                        ? 'Read today · longest ${streak.longest}'
                        : 'Read today to keep it going',
                    style: AppType.bodySmall.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.caretRight, color: p.inkMute),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _QuickAccess extends ConsumerWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prayers = ref
        .watch(prayersProvider)
        .value
        ?.where((x) => x.status == 'active')
        .length;
    final entries = ref.watch(journalProvider).value?.length;
    final saved =
        (ref.watch(savedVersesProvider).value?.length ?? 0) +
        (ref.watch(highlightsProvider).value?.length ?? 0) +
        (ref.watch(bookmarksProvider).value?.length ?? 0);

    Widget tile(
      Color color,
      IconData icon,
      String title,
      String sub,
      VoidCallback onTap,
    ) => Expanded(
      child: PastelCard(
        color: color,
        padding: const EdgeInsets.all(Space.x4),
        radius: Radii.md,
        onTap: onTap,
        semanticLabel: '$title, $sub',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: Space.x5),
            Text(title, style: AppType.titleS.copyWith(color: p.onPastel)),
            Text(sub, style: AppType.caption.copyWith(color: p.onPastel)),
          ],
        ),
      ),
    );

    return Column(
      children: [
        const SectionHeader(title: 'Your space'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              tile(
                p.sky,
                PhosphorIconsRegular.handsPraying,
                'Prayer',
                prayers == null ? '' : '$prayers active',
                () => context.go('/prayer'),
              ),
              const SizedBox(width: Space.x3),
              tile(
                p.blush,
                PhosphorIconsRegular.notebook,
                'Journal',
                entries == null
                    ? ''
                    : '$entries ${entries == 1 ? 'entry' : 'entries'}',
                () => context.push('/journal'),
              ),
              const SizedBox(width: Space.x3),
              tile(
                p.cream,
                PhosphorIconsRegular.bookmarksSimple,
                'Saved',
                '$saved items',
                () => context.push('/saved'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _RecentItem {
  const _RecentItem(this.range, this.kind, this.color, this.at, this.text);
  final VerseRange range;
  final String kind;
  final Color color;
  final int at;
  final String? text;
}

class _RecentlySaved extends ConsumerWidget {
  const _RecentlySaved();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final bible = ref.watch(currentBibleProvider).value;
    final items = <_RecentItem>[
      for (final s in ref.watch(savedVersesProvider).value ?? const [])
        _RecentItem(
          VerseRange.parseCode('${s.startRef}-${s.endRef}'),
          'Saved',
          p.cream,
          s.createdAt,
          s.snapshot,
        ),
      for (final h in ref.watch(highlightsProvider).value ?? const [])
        _RecentItem(
          VerseRange.parseCode('${h.startRef}-${h.endRef}'),
          'Highlight',
          HighlightColor.fromName(h.color).base(p),
          h.updatedAt,
          null,
        ),
      for (final b in ref.watch(bookmarksProvider).value ?? const [])
        _RecentItem(
          VerseRange.parseCode('${b.startRef}-${b.endRef}'),
          'Bookmark',
          p.sky,
          b.createdAt,
          null,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (items.isEmpty) return const SizedBox.shrink();

    String textFor(_RecentItem i) {
      if (i.text != null) return i.text!;
      if (bible == null) return '';
      return bible
          .versesIn(i.range)
          .map(
            (e) =>
                VerseText.plain(e.$2, suppliedWords: bible.info.suppliedWords),
          )
          .join(' ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recently saved',
          actionLabel: 'See all',
          onAction: () => context.push('/saved'),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: items.length.clamp(0, 8),
            separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
            itemBuilder: (context, i) {
              final it = items[i];
              return SizedBox(
                width: 240,
                child: PastelCard(
                  color: it.color,
                  radius: Radii.md,
                  padding: const EdgeInsets.all(Space.x4),
                  onTap: () => context.push(
                    ReaderArgs.location(it.range.start, flash: it.range),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.kind.toUpperCase(),
                        style: AppType.overline.copyWith(color: p.onPastel),
                      ),
                      const SizedBox(height: Space.x2),
                      Expanded(
                        child: Text(
                          textFor(it),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodySmall.copyWith(color: p.onPastel),
                        ),
                      ),
                      Text(
                        it.range.label,
                        style: AppType.label.copyWith(color: p.onPastel),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
