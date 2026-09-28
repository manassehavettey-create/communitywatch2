import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/phosphor_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/day_key.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/headers.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/states.dart';
import '../application/log_providers.dart';
import '../data/entry_repository.dart';
import 'entry_card.dart';
import 'filter_sheet.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  late final _search = TextEditingController(
    text: ref.read(logFilterProvider).query,
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(logFilterProvider.notifier).setQuery(q);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(logFilterProvider);
    final entries = ref.watch(logEntriesProvider);
    final streak = ref.watch(logStreakProvider).value;
    final today = ref.watch(todayProvider);
    final gl = context.gl;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TabHeader(
              bold: 'The good',
              italic: 'stuff',
              actions: [
                CircleIconButton(
                  icon: PhosphorIconsBold.plus,
                  tooltip: 'New entry',
                  background: Palette.lime,
                  foreground: Palette.ink,
                  onPressed: () => context.push(Routes.newEntry()),
                ),
              ],
            ),
          ),
          if (streak != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.md,
                ),
                child: Row(
                  children: [
                    const AppImage(
                      AppAssets.streakFlame,
                      width: 26,
                      height: 26,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        streak.current == 0
                            ? 'Log something today to start a streak'
                            : '${Fmt.plural(streak.current, 'day')} journal streak'
                                  '${streak.activeToday ? '' : ' — add today to keep it'}',
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: gl.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search entries, tags, skills',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: gl.muted,
                  ),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(PhosphorIconsBold.x, size: 18),
                          onPressed: () {
                            _search.clear();
                            _onSearch('');
                          },
                        ),
                  border: const OutlineInputBorder(borderRadius: Radii.pillR),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: Radii.pillR,
                    borderSide: BorderSide(color: gl.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: Radii.pillR,
                    borderSide: BorderSide(color: gl.text, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FilterBar(filter: filter)),
          ...entries.when(
            loading: () => [const SliverToBoxAdapter(child: LoadingState())],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: ErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(logEntriesProvider),
                ),
              ),
            ],
            data: (list) => _timeline(context, list, filter, today),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: Space.dockClearance + Space.lg),
          ),
        ],
      ),
    );
  }

  List<Widget> _timeline(
    BuildContext context,
    List<EntryView> list,
    EntryFilter filter,
    DayKey today,
  ) {
    if (list.isEmpty) {
      final filtered = !filter.isEmpty;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: Space.xl),
            child: filtered
                ? EmptyState(
                    image: AppAssets.emptySearch,
                    title: 'No matches',
                    message: 'Try a different search or loosen the filters.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      _search.clear();
                      ref
                          .read(logFilterProvider.notifier)
                          .set(EntryFilter.none);
                    },
                  )
                : EmptyState(
                    image: AppAssets.emptyLog,
                    title: 'Your log is waiting',
                    message: 'Write down one thing you are grateful for, or one win — however small.',
                    actionLabel: 'Write the first one',
                    onAction: () => context.push(Routes.newEntry()),
                  ),
          ),
        ),
      ];
    }
    final groups = <DayKey, List<EntryView>>{};
    for (final v in list) {
      groups.putIfAbsent(v.entry.dayKey, () => []).add(v);
    }
    final days = groups.keys.toList();
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverList.builder(
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final items = groups[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: Space.lg,
                    bottom: Space.sm,
                  ),
                  child: Semantics(
                    header: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Fmt.dayLabel(day, today),
                          style: context.text.titleLarge,
                        ),
                        const SizedBox(width: Space.xs),
                        Text(
                          Fmt.plural(items.length, 'entry', 'entries'),
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                for (var j = 0; j < items.length; j++) ...[
                  if (j > 0) const SizedBox(height: Space.xs),
                  FadeSlideIn(
                    index: i < 3 ? j : 0,
                    child: EntryCard(view: items[j]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ];
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final EntryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(logFilterProvider.notifier);
    Widget chip(
      String label,
      bool active,
      VoidCallback onTap, {
      IconData? icon,
    }) {
      final gl = context.gl;
      return Padding(
        padding: const EdgeInsets.only(right: Space.xs),
        child: Semantics(
          button: true,
          selected: active,
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.fast,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? gl.inverse : gl.surface,
                borderRadius: Radii.pillR,
                border: Border.all(color: active ? gl.inverse : gl.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: active ? gl.onInverse : gl.text,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: AppText.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: active ? gl.onInverse : gl.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.sm + 2,
          Space.gutter,
          Space.xs,
        ),
        children: [
          chip(
            'All',
            filter.type == null,
            () => ctrl.set(filter.copyWith(type: () => null)),
          ),
          chip(
            'Gratitude',
            filter.type == EntryType.gratitude,
            () => ctrl.set(filter.copyWith(type: () => EntryType.gratitude)),
            icon: PhosphorIconsFill.heart,
          ),
          chip(
            'Wins',
            filter.type == EntryType.win,
            () => ctrl.set(filter.copyWith(type: () => EntryType.win)),
            icon: PhosphorIconsFill.trophy,
          ),
          chip(
            filter.tags.isEmpty ? 'Tags' : 'Tags · ${filter.tags.length}',
            filter.tags.isNotEmpty,
            () => showFilterSheet(context, FilterSection.tags),
            icon: PhosphorIconsRegular.tag,
          ),
          chip(
            'Skill',
            filter.skillId != null,
            () => showFilterSheet(context, FilterSection.skill),
            icon: PhosphorIconsRegular.squaresFour,
          ),
          chip(
            filter.from == null && filter.to == null
                ? 'Dates'
                : '${filter.from == null ? '…' : Fmt.shortDate(filter.from!)} – ${filter.to == null ? '…' : Fmt.shortDate(filter.to!)}',
            filter.from != null || filter.to != null,
            () => showFilterSheet(context, FilterSection.dates),
            icon: PhosphorIconsRegular.calendarBlank,
          ),
          if (filter.activeCount > 0)
            chip('Clear', false, ctrl.clear, icon: PhosphorIconsBold.x),
        ],
      ),
    );
  }
}
