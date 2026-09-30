import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../domain/commentary.dart';
import '../share/share_screen.dart';
import 'widgets/match_widgets.dart';

/// Post-match recap (spec §27).
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match recap'),
        actions: [IconButton(icon: const Icon(Icons.ios_share_rounded), tooltip: 'Share result', onPressed: () => context.push('/share', extra: ShareRequest.match(id)))],
      ),
      body: AsyncView(value: async, onRetry: () => ref.invalidate(matchProvider(id)), builder: (f) => _Body(match: f.data)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = match;
    final s = m.stats;
    final moments = keyMoments(m);
    final sections = <Widget>[
      Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(borderRadius: Radii.xlAll, gradient: LinearGradient(colors: [c.surface2, c.surface], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Column(children: [
          Text(m.status.isFinished ? 'FULL TIME' : m.status.minuteLabel, style: AppType.overline(color: c.accentInk)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(children: [TeamCrest(team: m.home, size: 58), const SizedBox(height: 8), Text(m.home.name.toUpperCase(), textAlign: TextAlign.center, style: AppType.display(14, color: c.text))])),
            Text('${m.homeGoals ?? 0}–${m.awayGoals ?? 0}', style: AppType.numeric(52, color: c.text)),
            Expanded(child: Column(children: [TeamCrest(team: m.away, size: 58), const SizedBox(height: 8), Text(m.away.name.toUpperCase(), textAlign: TextAlign.center, style: AppType.display(14, color: c.text))])),
          ]),
          if (m.penalties.isSet) Text('Penalties ${m.penalties.home}–${m.penalties.away}', style: AppType.body(13, color: c.textMuted)),
        ]),
      ),
      if (m.goals.isNotEmpty) ...[
        const SectionHeader('Goals', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
        EventTimeline(match: m, kinds: const {EventKind.goal, EventKind.penaltyGoal, EventKind.ownGoal}),
      ],
      if (s != null && !s.isEmpty) ...[
        const SectionHeader('Match stats', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
        AppCard(
          child: Column(children: [
            if (s[StatKey.possession]?.home != null) PossessionBar(home: s[StatKey.possession]!.home!.toDouble(), away: s[StatKey.possession]!.away!.toDouble()),
            for (final k in [StatKey.shotsTotal, StatKey.shotsOn, StatKey.xg, StatKey.corners])
              if (s[k] != null) StatCompareRow(label: k.label, home: s[k]!.home, away: s[k]!.away, unit: k.unit, onTap: () => showStatExplain(context, m, k)),
          ]),
        ),
      ],
      if ((m.players ?? const []).any((p) => p.stats.rating != null)) ...[
        const SectionHeader('Top performers', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
        TopPerformers(match: m),
      ],
      if (moments.isNotEmpty) ...[
        SectionHeader('Key moments', padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm), trailing: const ProvenanceTag(Provenance.generated, compact: true)),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final line in moments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(margin: const EdgeInsets.only(top: 7, right: 10), width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                  Expanded(child: Text(line, style: AppType.body(14.5, color: c.text))),
                ]),
              ),
            const SizedBox(height: 4),
            Text('Summarised by Touchline from confirmed match events.', style: AppType.body(11.5, color: c.textFaint)),
          ]),
        ),
      ],
      const SizedBox(height: Space.xl),
      PillButton(label: 'Share result card', icon: Icons.ios_share_rounded, expand: true, onTap: () => context.push('/share', extra: ShareRequest.match(m.id))),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [for (var i = 0; i < sections.length; i++) sections[i].animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.06)],
    );
  }
}
