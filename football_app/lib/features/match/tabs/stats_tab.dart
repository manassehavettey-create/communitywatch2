import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../widgets/match_widgets.dart';

const _basic = [StatKey.shotsTotal, StatKey.shotsOn, StatKey.shotsOff, StatKey.shotsBlocked, StatKey.shotsInside, StatKey.shotsOutside, StatKey.corners, StatKey.fouls, StatKey.offsides, StatKey.passes, StatKey.passesAccurate, StatKey.passAccuracy, StatKey.saves, StatKey.yellow, StatKey.red];
const _advanced = [StatKey.xg, StatKey.xa, StatKey.bigChances, StatKey.progressivePasses, StatKey.keyPasses, StatKey.duelsWon, StatKey.tackles, StatKey.interceptions, StatKey.crosses, StatKey.dribbles, StatKey.goalsPrevented];

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key, required this.match});
  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = match.stats;
    final provider = ref.watch(repositoryProvider).providerName;
    if (s == null || s.isEmpty) {
      return ListView(children: [
        EmptyState(
          art: EmptyArt.matches,
          title: match.status.isScheduled ? 'Stats arrive at kick-off' : 'No statistics',
          message: match.status.isScheduled ? 'Possession, shots, xG and more will update live here.' : '$provider has not published statistics for this match.',
          compact: true,
        ),
      ]);
    }
    final pos = s[StatKey.possession];
    final advAvail = _advanced.where((k) => s[k] != null).toList();
    final advMissing = _advanced.where((k) => s[k] == null).toList();

    Widget row(StatKey k) => StatCompareRow(
          label: k.label,
          home: s[k]!.home,
          away: s[k]!.away,
          unit: k.unit,
          note: s.derivedKeys.contains(k) ? 'Σ sum of official player stats' : null,
          onTap: () => showStatExplain(context, match, k),
        );

    final sections = <Widget>[
      _TeamsHeader(match: match),
      if (pos?.home != null && pos?.away != null) AppCard(child: PossessionBar(home: pos!.home!.toDouble(), away: pos.away!.toDouble(), onTap: () => showStatExplain(context, match, StatKey.possession))),
      const SectionHeader('Match stats', padding: EdgeInsets.only(top: Space.xl, bottom: Space.xs)),
      AppCard(child: Column(children: [for (final k in _basic) if (s[k] != null) row(k)])),
      const SectionHeader('Advanced', padding: EdgeInsets.only(top: Space.xl, bottom: Space.xs)),
      if (advAvail.isNotEmpty) AppCard(child: Column(children: [for (final k in advAvail) row(k)])),
      if (advMissing.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: NotProvided(advMissing.map((k) => k.label.replaceAll(RegExp(r' \(.*\)'), '')).join(', '), provider: provider),
        ),
      Padding(
        padding: const EdgeInsets.only(top: Space.lg),
        child: Text('Tap any statistic for a plain-English explanation.', style: AppType.body(12.5, color: c.textFaint)),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [for (var i = 0; i < sections.length; i++) sections[i].animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base)],
    );
  }
}

class _TeamsHeader extends StatelessWidget {
  const _TeamsHeader({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        TeamCrest(team: match.home, size: 20),
        const SizedBox(width: 6),
        Text(match.home.short, style: AppType.body(13, weight: 650, color: c.text)),
        const Spacer(),
        Text(match.away.short, style: AppType.body(13, weight: 650, color: c.text)),
        const SizedBox(width: 6),
        TeamCrest(team: match.away, size: 20),
        const SizedBox(width: 6),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c.away, shape: BoxShape.circle)),
      ]),
    );
  }
}
