import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/plans.dart';
import 'plan_widgets.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  PlanCategory? _category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final catalog = ref.watch(planCatalogProvider);
    final mine = ref.watch(userPlansProvider).value ?? const [];
    final started = {for (final u in mine) u.plan.id};

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Reading\nplans',
                subtitle: 'a gentle rhythm',
              ),
            ),
            if (mine.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Your plans'),
              ),
              SliverList.builder(
                itemCount: mine.length,
                itemBuilder: (context, i) {
                  final u = mine[i];
                  final s = u.state;
                  final status = switch (s.status) {
                    PlanStatus.active =>
                      'Day ${s.currentDay} of ${s.totalDays}',
                    PlanStatus.paused => 'Paused · day ${s.currentDay}',
                    PlanStatus.completed => 'Completed',
                  };
                  return Reveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        0,
                        Space.gutter,
                        Space.x3,
                      ),
                      child: PastelCard(
                        color: s.status == PlanStatus.paused
                            ? p.paperDeep
                            : planColor(u.plan.category, p),
                        semanticLabel:
                            '${u.plan.title}, $status, ${s.percent} percent',
                        onTap: () => context.push('/plans/${u.plan.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    u.plan.title,
                                    style: AppType.titleM.copyWith(
                                      color: p.onPastel,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${s.percent}%',
                                  style: AppType.titleM.copyWith(
                                    color: p.onPastel,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.x1),
                            Text(
                              status,
                              style: AppType.bodySmall.copyWith(
                                color: p.onPastel,
                              ),
                            ),
                            const SizedBox(height: Space.x3),
                            ProgressBar(
                              value: s.fraction,
                              color: p.onPastel,
                              track: p.onPastel.withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SectionHeader(title: 'Browse')),
            SliverToBoxAdapter(
              child: ChipRow<PlanCategory?>(
                options: const [null, ...PlanCategory.values],
                selected: _category,
                labelOf: (c) => c?.label ?? 'All',
                onSelected: (c) => setState(() => _category = c),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x3)),
            catalog.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(Space.gutter),
                  child: Column(
                    children: [
                      Skeleton(height: 96, radius: Radii.lg),
                      SizedBox(height: 12),
                      Skeleton(height: 96, radius: Radii.lg),
                    ],
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(child: Text('$e')),
              data: (plans) {
                final shown = plans
                    .where(
                      (pl) => _category == null || pl.category == _category,
                    )
                    .toList();
                return SliverList.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final pl = shown[i];
                    return Reveal(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          0,
                          Space.gutter,
                          Space.x3,
                        ),
                        child: SurfaceCard(
                          semanticLabel:
                              '${pl.title}, ${durationLabel(pl.totalDays)}, about ${pl.minutesPerDay} minutes a day'
                              '${started.contains(pl.id) ? ', started' : ''}',
                          onTap: () => context.push('/plans/${pl.id}'),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: planColor(pl.category, p),
                                  borderRadius: Radii.smAll,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${pl.totalDays}',
                                  style: AppType.titleM.copyWith(
                                    color: p.onPastel,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: Space.x4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pl.title,
                                      style: AppType.titleS.copyWith(
                                        color: p.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${durationLabel(pl.totalDays)} · about ${pl.minutesPerDay} min a day',
                                      style: AppType.caption.copyWith(
                                        color: p.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (started.contains(pl.id))
                                Icon(
                                  PhosphorIconsFill.checkCircle,
                                  color: p.tangerine,
                                )
                              else
                                Icon(
                                  PhosphorIconsRegular.caretRight,
                                  color: p.inkMute,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: Space.tabBarClearance),
            ),
          ],
        ),
      ),
    );
  }
}
