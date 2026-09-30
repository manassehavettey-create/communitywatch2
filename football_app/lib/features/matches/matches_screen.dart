import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/personalization.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/utils/fuzzy.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../shell/app_shell.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});
  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> with TickerProviderStateMixin {
  DateTime _day = dateOnly(DateTime.now());
  bool _favOnly = false;
  Set<int> _leagues = {};
  Set<String> _countries = {};
  late final TabController _tabs = TabController(length: 3, vsync: this);
  bool _tabChosen = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _setDay(DateTime d) {
    setState(() {
      _day = dateOnly(d);
      _tabChosen = false;
      _leagues = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dayMatchesProvider(_day));
    final p = ref.watch(personalizationProvider);
    final all = async.value?.data ?? const <Match>[];

    var filtered = all.where((m) {
      if (_favOnly && !(p.followsMatch(m) || p.followsLeague(m.league.id))) return false;
      if (_leagues.isNotEmpty && !_leagues.contains(m.league.id)) return false;
      if (_countries.isNotEmpty && !_countries.contains(m.league.country)) return false;
      return true;
    }).toList();
    final live = filtered.where((m) => m.status.isLive).toList();
    final upcoming = filtered.where((m) => m.status.isScheduled || m.status.phase == MatchPhase.postponed).toList();
    final finished = filtered.where((m) => m.status.isFinished || m.status.phase == MatchPhase.cancelled).toList();

    if (!_tabChosen && async.hasValue) {
      _tabChosen = true;
      final today = dateOnly(DateTime.now());
      final idx = _day.isBefore(today) ? 2 : (live.isNotEmpty ? 0 : (upcoming.isNotEmpty ? 1 : 2));
      if (_tabs.index != idx) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _tabs.animateTo(idx) : null);
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xs),
                child: Row(children: [
                  Expanded(child: Text('Matches', style: context.text.displaySmall)),
                  CircleIconButton(
                    icon: Icons.calendar_month_rounded,
                    tooltip: 'Pick a date',
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) _setDay(d);
                    },
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _DateStrip(selected: _day, onSelect: _setDay)),
          SliverToBoxAdapter(
            child: _FilterRow(
              favOnly: _favOnly,
              leagueCount: _leagues.length,
              countryCount: _countries.length,
              onFav: () => setState(() => _favOnly = !_favOnly),
              onLeagues: () async {
                final r = await _pickLeagues(context, all, _leagues);
                if (r != null) setState(() => _leagues = r);
              },
              onCountries: () async {
                final r = await _pickCountries(context, all, _countries);
                if (r != null) setState(() => _countries = r);
              },
              onClear: (_leagues.isEmpty && _countries.isEmpty && !_favOnly)
                  ? null
                  : () => setState(() {
                        _leagues = {};
                        _countries = {};
                        _favOnly = false;
                      }),
            ),
          ),
          SliverToBoxAdapter(child: FreshnessBanner(fresh: async.value, live: sameDay(_day, DateTime.now()))),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _tabs,
              builder: (_, _) => PillTabBar(controller: _tabs, tabs: ['Live${live.isEmpty ? '' : ' ${live.length}'}', 'Upcoming${upcoming.isEmpty ? '' : ' ${upcoming.length}'}', 'Finished${finished.isEmpty ? '' : ' ${finished.length}'}']),
            ),
          ),
        ],
        body: async.hasError && !async.hasValue
            ? ErrorState(error: async.error!, onRetry: () => ref.invalidate(dayMatchesProvider(_day)))
            : !async.hasValue
                ? const Padding(padding: EdgeInsets.only(top: Space.md), child: SkeletonList(count: 6, height: 76))
                : TabBarView(controller: _tabs, children: [
                    _GroupedList(matches: live, p: p, empty: sameDay(_day, DateTime.now()) ? 'No matches in play right now.' : 'Live matches appear here on match days.', onRefresh: () async => ref.invalidate(liveMatchesProvider)),
                    _GroupedList(matches: upcoming, p: p, empty: 'No upcoming matches for these filters.', onRefresh: () async => ref.invalidate(dayMatchesProvider(_day))),
                    _GroupedList(matches: finished, p: p, empty: 'No results for these filters.', onRefresh: () async => ref.invalidate(dayMatchesProvider(_day))),
                  ]),
      ),
    );
  }

  Future<Set<int>?> _pickLeagues(BuildContext context, List<Match> all, Set<int> current) {
    final leagues = {for (final m in all) m.league.id: m.league}.values.toList()
      ..sort((a, b) => ref.read(personalizationProvider).leaguePriority(b.id).compareTo(ref.read(personalizationProvider).leaguePriority(a.id)));
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MultiPickSheet<LeagueRef>(
        title: 'Competitions',
        items: leagues,
        selected: {for (final l in leagues) if (current.contains(l.id)) l},
        label: (l) => l.name,
        sub: (l) => l.country,
        leading: (l) => LeagueLogo(league: l, size: 26),
        onDone: (s) => s.map((l) => l.id).toSet(),
      ),
    );
  }

  Future<Set<String>?> _pickCountries(BuildContext context, List<Match> all, Set<String> current) {
    final countries = {for (final m in all) ?m.league.country}.toList()..sort();
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MultiPickSheet<String>(title: 'Countries', items: countries, selected: current, label: (s) => s, onDone: (s) => s),
    );
  }
}

class _DateStrip extends StatefulWidget {
  const _DateStrip({required this.selected, required this.onSelect});
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<_DateStrip> {
  static const _range = 7;
  static const _w = 58.0;
  late final _ctrl = ScrollController(initialScrollOffset: _offsetFor(widget.selected));

  double _offsetFor(DateTime d) {
    final i = dateOnly(d).difference(dateOnly(DateTime.now())).inDays + _range;
    return (i * (_w + 8) - 140).clamp(0, double.infinity);
  }

  @override
  void didUpdateWidget(covariant _DateStrip old) {
    super.didUpdateWidget(old);
    if (!sameDay(old.selected, widget.selected) && _ctrl.hasClients) {
      _ctrl.animateTo(_offsetFor(widget.selected).clamp(0, _ctrl.position.maxScrollExtent), duration: Motion.slow, curve: Motion.emphasized);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = dateOnly(DateTime.now());
    return SizedBox(
      height: 78,
      child: ListView.separated(
        controller: _ctrl,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _range * 2 + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = today.add(Duration(days: i - _range));
          final sel = sameDay(d, widget.selected);
          final isToday = sameDay(d, today);
          return Pressable(
            onTap: () => widget.onSelect(d),
            semanticLabel: longDate(d),
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.emphasized,
              width: _w,
              decoration: BoxDecoration(
                color: sel ? c.accent : c.surface,
                borderRadius: Radii.pillAll,
                border: Border.all(color: sel ? c.accent : (isToday ? c.accentInk.withValues(alpha: 0.5) : c.hairline)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(isToday ? 'Today' : DateFormat('EEE').format(d), style: AppType.body(11.5, weight: 600, color: sel ? c.onAccent.withValues(alpha: 0.7) : c.textMuted)),
                const SizedBox(height: 2),
                Text('${d.day}', style: AppType.numeric(19, color: sel ? c.onAccent : c.text)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.favOnly, required this.leagueCount, required this.countryCount, required this.onFav, required this.onLeagues, required this.onCountries, this.onClear});
  final bool favOnly;
  final int leagueCount;
  final int countryCount;
  final VoidCallback onFav;
  final VoidCallback onLeagues;
  final VoidCallback onCountries;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Space.gutter, 6, Space.gutter, 6),
        children: [
          ChoiceChipPill(label: 'Following', selected: favOnly, onTap: onFav, leading: Icon(Icons.star_rounded, size: 16, color: favOnly ? c.onAccent : c.textMuted)),
          const SizedBox(width: 8),
          ChoiceChipPill(label: leagueCount == 0 ? 'Competition' : 'Competitions · $leagueCount', selected: leagueCount > 0, onTap: onLeagues),
          const SizedBox(width: 8),
          ChoiceChipPill(label: countryCount == 0 ? 'Country' : 'Countries · $countryCount', selected: countryCount > 0, onTap: onCountries),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            ChoiceChipPill(label: 'Clear', selected: false, onTap: onClear!, leading: Icon(Icons.close_rounded, size: 16, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.matches, required this.p, required this.empty, required this.onRefresh});
  final List<Match> matches;
  final Personalization p;
  final String empty;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return ListView(children: [EmptyState(art: EmptyArt.matches, title: 'Nothing here', message: empty, compact: true)]);
    }
    final groups = groupBy(matches, (Match m) => m.league.id).values.toList()
      ..sort((a, b) {
        final pa = a.map(p.matchPriority).max, pb = b.map(p.matchPriority).max;
        return pb.compareTo(pa);
      });
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.onAccent,
      backgroundColor: context.colors.accent,
      child: CustomScrollView(slivers: [
        for (var gi = 0; gi < groups.length; gi++) ...[
          SliverToBoxAdapter(
            child: CompetitionHeader(
              league: groups[gi].first.league,
              onTap: () => context.push('/league/${groups[gi].first.league.id}'),
              trailing: p.followsLeague(groups[gi].first.league.id) ? Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.star_rounded, size: 16, color: context.colors.accentInk)) : null,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.separated(
              itemCount: groups[gi].length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final list = [...groups[gi]]..sort((a, b) {
                    final c = p.matchPriority(b).compareTo(p.matchPriority(a));
                    return c != 0 && (p.followsMatch(a) || p.followsMatch(b)) ? c : a.kickoff.compareTo(b.kickoff);
                  });
                final row = MatchRow(match: list[i], scope: 'm$gi-$i');
                return gi < 3 ? row.animate(delay: Motion.staggerFor(i + gi * 2)).fadeIn(duration: Motion.base).slideY(begin: 0.12, curve: Motion.emphasized) : row;
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: navClearance)),
      ]),
    );
  }
}

/// Searchable multi-select sheet (competitions / countries).
class _MultiPickSheet<T> extends StatefulWidget {
  const _MultiPickSheet({required this.title, required this.items, required this.selected, required this.label, this.sub, this.leading, required this.onDone});
  final String title;
  final List<T> items;
  final Set<T> selected;
  final String Function(T) label;
  final String? Function(T)? sub;
  final Widget Function(T)? leading;
  final Object Function(Set<T>) onDone;

  @override
  State<_MultiPickSheet<T>> createState() => _MultiPickSheetState<T>();
}

class _MultiPickSheetState<T> extends State<_MultiPickSheet<T>> {
  late final Set<T> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = _q.isEmpty ? widget.items : Fuzzy.rank(_q, widget.items, (t) => '${widget.label(t)} ${widget.sub?.call(t) ?? ''}', limit: 200);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(children: [
            Expanded(child: Text(widget.title, style: context.text.headlineSmall)),
            TextButton(onPressed: () => setState(_sel.clear), child: Text('Reset', style: AppType.body(14, weight: 600, color: c.textMuted))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xs),
          child: TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded))),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final t = items[i];
              final on = _sel.contains(t);
              return ListTile(
                leading: widget.leading?.call(t),
                title: Text(widget.label(t), style: AppType.body(15, weight: 560, color: c.text)),
                subtitle: widget.sub?.call(t) == null ? null : Text(widget.sub!(t)!, style: AppType.body(12.5, color: c.textMuted)),
                trailing: AnimatedContainer(
                  duration: Motion.fast,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.accent : Colors.transparent, border: Border.all(color: on ? c.accent : c.textFaint, width: 1.5)),
                  child: on ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
                ),
                onTap: () => setState(() => on ? _sel.remove(t) : _sel.add(t)),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: PillButton(label: _sel.isEmpty ? 'Show all' : 'Show ${_sel.length} selected', expand: true, onTap: () => Navigator.pop(context, widget.onDone(_sel))),
          ),
        ),
      ]),
    );
  }
}
