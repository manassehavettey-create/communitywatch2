import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/db/database.dart';
import '../../data/repos/prayer_repository.dart';
import 'prayer_widgets.dart';

enum _Filter { active, answered, all }

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  _Filter _filter = _Filter.active;
  PrayerCategory? _category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final async = ref.watch(prayersProvider);
    final all = async.value ?? const <Prayer>[];
    final active = all.where((x) => x.status == 'active').length;
    final answered = all.length - active;
    final shown = all.where((x) {
      final okStatus = switch (_filter) {
        _Filter.active => x.status == 'active',
        _Filter.answered => x.status == 'answered',
        _Filter.all => true,
      };
      return okStatus && (_category == null || x.category == _category!.name);
    }).toList();
    if (_filter == _Filter.answered) {
      shown.sort((a, b) => (b.answeredAt ?? 0).compareTo(a.answeredAt ?? 0));
    }

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: CircleIconButton(
          icon: PhosphorIconsBold.plus,
          tooltip: 'New prayer',
          size: 60,
          background: p.ink,
          foreground: p.paper,
          onPressed: () => context.push('/prayer/new'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Prayer',
                subtitle: active == 0
                    ? 'bring it all'
                    : '$active on your heart',
                actions: [
                  CircleIconButton(
                    icon: PhosphorIconsRegular.notebook,
                    tooltip: 'Journal',
                    onPressed: () => context.push('/journal'),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: ChipRow<_Filter>(
                options: _Filter.values,
                selected: _filter,
                labelOf: (f) => switch (f) {
                  _Filter.active => 'Active',
                  _Filter.answered => 'Answered',
                  _Filter.all => 'All',
                },
                countOf: (f) => switch (f) {
                  _Filter.active => active,
                  _Filter.answered => answered,
                  _Filter.all => all.length,
                },
                onSelected: (f) => setState(() => _filter = f),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x2)),
            SliverToBoxAdapter(
              child: ChipRow<PrayerCategory?>(
                options: const [null, ...PrayerCategory.values],
                selected: _category,
                labelOf: (c) => c?.label ?? 'Every category',
                onSelected: (c) => setState(() => _category = c),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x4)),
            if (async.isLoading && all.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(Space.gutter),
                  child: Skeleton(height: 110, radius: Radii.lg),
                ),
              )
            else if (shown.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: PhosphorIconsRegular.handsPraying,
                  color: p.sky,
                  asset: 'assets/images/empty/empty_prayer.png',
                  title: all.isEmpty
                      ? 'Nothing here yet'
                      : _filter == _Filter.answered
                      ? 'No answered prayers yet'
                      : 'No prayers match',
                  message: all.isEmpty
                      ? 'Write down what’s on your heart. You can come back to it and mark it answered.'
                      : 'Try another filter.',
                  actionLabel: all.isEmpty ? 'Add a prayer' : null,
                  onAction: all.isEmpty
                      ? () => context.push('/prayer/new')
                      : null,
                ),
              )
            else
              SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) => Reveal(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      0,
                      Space.gutter,
                      Space.x3,
                    ),
                    child: PrayerCard(prayer: shown[i]),
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: Space.tabBarClearance + 40),
            ),
          ],
        ),
      ),
    );
  }
}

class PrayerCard extends StatelessWidget {
  const PrayerCard({super.key, required this.prayer});

  final Prayer prayer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cat = PrayerCategory.fromName(prayer.category);
    final answered = prayer.status == 'answered';
    final date = DateTime.fromMillisecondsSinceEpoch(
      answered ? prayer.answeredAt ?? prayer.createdAt : prayer.createdAt,
    );
    String? scripture;
    if (prayer.scriptureRef != null) {
      try {
        scripture = VerseRange.parseCode(prayer.scriptureRef!).label;
      } on Object {
        scripture = null;
      }
    }
    return Semantics(
      button: true,
      label: '${prayer.title}, ${cat.label}${answered ? ', answered' : ''}',
      child: Pressable(
        scale: 0.98,
        onTap: () => context.push('/prayer/${prayer.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x4,
            Space.x5,
            Space.x4 + 14,
          ),
          decoration: ShapeDecoration(
            color: answered ? p.paperDeep : prayerColor(cat, p),
            shape: const BubbleBorder(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    cat.label.toUpperCase(),
                    style: AppType.overline.copyWith(color: p.onPastel),
                  ),
                  const Spacer(),
                  if (prayer.reminderKind != 'none' && !answered)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        PhosphorIconsRegular.bell,
                        size: 16,
                        color: answered ? p.inkSoft : p.onPastel,
                      ),
                    ),
                  if (answered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.tangerine,
                        borderRadius: Radii.pillAll,
                      ),
                      child: Text(
                        'Answered',
                        style: AppType.caption.copyWith(
                          color: p.onPastel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.x2),
              Text(
                prayer.title,
                style: AppType.titleM.copyWith(
                  color: answered ? p.ink : p.onPastel,
                ),
              ),
              if (prayer.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  prayer.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall.copyWith(
                    color: answered ? p.inkSoft : p.onPastel,
                  ),
                ),
              ],
              const SizedBox(height: Space.x3),
              Text(
                [
                  if (answered)
                    'Answered ${DateFormat('d MMM y').format(date)}'
                  else
                    DateFormat('d MMM y').format(date),
                  ?scripture,
                ].join(' · '),
                style: AppType.caption.copyWith(
                  color: answered ? p.inkMute : p.onPastel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
