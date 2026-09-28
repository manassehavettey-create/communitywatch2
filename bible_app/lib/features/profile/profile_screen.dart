import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/sticker.dart';
import '../../data/repos/reading_repository.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/plans.dart';
import 'sync_label.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final user = ref.watch(currentUserProvider).value;
    final auth = ref.watch(authServiceProvider);
    final sync =
        ref.watch(syncStatusProvider).value ??
        const SyncStatus(SyncPhase.localOnly);
    final stats = ref.watch(readingStatsProvider).value ?? ReadingStats.empty;
    final plans = ref.watch(userPlansProvider).value ?? const [];
    final counts = (
      saved: ref.watch(savedVersesProvider).value?.length ?? 0,
      highlights: ref.watch(highlightsProvider).value?.length ?? 0,
      notes: ref.watch(notesProvider).value?.length ?? 0,
      bookmarks: ref.watch(bookmarksProvider).value?.length ?? 0,
      journal: ref.watch(journalProvider).value?.length ?? 0,
      prayers: ref.watch(prayersProvider).value?.length ?? 0,
    );
    final name = user?.displayName ?? user?.email?.split('@').first;
    final initial = name == null || name.trim().isEmpty
        ? null
        : name.trim().characters.first.toUpperCase();

    final headerBg = p.isDark ? p.surface : p.ink;
    final headerFg = p.isDark ? p.ink : p.paper;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.tabBarClearance),
        children: [
          // Ink header block.
          Container(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              MediaQuery.paddingOf(context).top + Space.x4,
              Space.gutter,
              Space.x6,
            ),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(Radii.xl),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Sticker(
                      color: p.butter,
                      size: 64,
                      child: initial == null
                          ? Icon(
                              PhosphorIconsRegular.user,
                              size: 28,
                              color: p.onPastel,
                            )
                          : Text(
                              initial,
                              style: AppType.titleL.copyWith(color: p.onPastel),
                            ),
                    ),
                    const Spacer(),
                    CircleIconButton(
                      icon: PhosphorIconsRegular.gearSix,
                      tooltip: 'Settings',
                      background: headerFg.withValues(alpha: 0.1),
                      foreground: headerFg,
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x5),
                Text(
                  name ?? 'Your profile',
                  style: AppType.displayM.copyWith(color: headerFg),
                ),
                const SizedBox(height: Space.x1),
                Text(
                  syncLabel(
                    sync,
                    signedIn: user != null,
                    available: auth.available,
                  ),
                  style: AppType.bodySmall.copyWith(
                    color: headerFg.withValues(alpha: 0.7),
                  ),
                ),
                if (user == null && auth.available) ...[
                  const SizedBox(height: Space.x4),
                  PillButton(
                    label: 'Sign in to sync',
                    icon: PhosphorIconsRegular.cloudArrowUp,
                    variant: PillVariant.accent,
                    compact: true,
                    onPressed: () => context.push('/auth'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.x5),
          Reveal(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Space.x3,
                crossAxisSpacing: Space.x3,
                childAspectRatio: 1.5,
                children: [
                  _StatTile(
                    label: 'Day streak',
                    value: stats.streak.current,
                    color: p.butter,
                    onTap: () => context.push('/streak'),
                  ),
                  _StatTile(
                    label: 'Longest streak',
                    value: stats.streak.longest,
                    color: p.coral,
                    onTap: () => context.push('/streak'),
                  ),
                  _StatTile(
                    label: 'Chapters read',
                    value: stats.chaptersRead,
                    color: p.sage,
                    onTap: () => context.push('/streak'),
                  ),
                  _StatTile(
                    label: 'Books completed',
                    value: stats.booksCompleted,
                    color: p.sky,
                    onTap: () => context.push('/streak'),
                  ),
                ],
              ),
            ),
          ),
          if (plans.isNotEmpty) ...[
            const SectionHeader(title: 'Plans'),
            for (final u in plans)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.x3,
                ),
                child: SurfaceCard(
                  onTap: () => context.push('/plans/${u.plan.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              u.plan.title,
                              style: AppType.titleS.copyWith(color: p.ink),
                            ),
                          ),
                          Text(
                            u.state.status == PlanStatus.completed
                                ? 'Done'
                                : '${u.state.percent}%',
                            style: AppType.label.copyWith(color: p.inkSoft),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x2),
                      ProgressBar(
                        value: u.state.fraction,
                        color: p.tangerine,
                        track: p.paperDeep,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SectionHeader(title: 'Your library'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _CountRow(
                    icon: PhosphorIconsRegular.heart,
                    label: 'Saved verses',
                    count: counts.saved,
                    onTap: () => context.push('/saved?kind=verse'),
                  ),
                  _CountRow(
                    icon: PhosphorIconsRegular.highlighter,
                    label: 'Highlights',
                    count: counts.highlights,
                    onTap: () => context.push('/saved?kind=highlight'),
                  ),
                  _CountRow(
                    icon: PhosphorIconsRegular.bookmarkSimple,
                    label: 'Bookmarks',
                    count: counts.bookmarks,
                    onTap: () => context.push('/saved?kind=bookmark'),
                  ),
                  _CountRow(
                    icon: PhosphorIconsRegular.notePencil,
                    label: 'Notes',
                    count: counts.notes,
                    onTap: () => context.push('/notes'),
                  ),
                  _CountRow(
                    icon: PhosphorIconsRegular.notebook,
                    label: 'Journal entries',
                    count: counts.journal,
                    onTap: () => context.push('/journal'),
                  ),
                  _CountRow(
                    icon: PhosphorIconsRegular.handsPraying,
                    label: 'Prayers',
                    count: counts.prayers,
                    onTap: () => context.go('/prayer'),
                    last: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PastelCard(
      color: color,
      radius: Radii.md,
      padding: const EdgeInsets.all(Space.x4),
      onTap: onTap,
      semanticLabel: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedCount(
            value: value,
            style: AppType.displayM.copyWith(
              fontFamily: 'Urbanist',
              fontSize: 40,
              height: 1,
              color: p.onPastel,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: AppType.label.copyWith(color: p.onPastel)),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: p.ink),
          title: Text(label, style: AppType.body.copyWith(color: p.ink)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: AppType.label.copyWith(
                  color: p.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: p.inkMute),
            ],
          ),
          onTap: onTap,
        ),
        if (!last) Divider(indent: 56, color: p.line),
      ],
    );
  }
}
