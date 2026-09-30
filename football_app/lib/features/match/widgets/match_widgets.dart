import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../domain/catch_up.dart';
import '../../../domain/insights.dart';
import '../../share/share_screen.dart';

/// "What just happened?" card (spec §28).
class CatchUpCard extends StatelessWidget {
  const CatchUpCard({super.key, required this.summary, required this.onDismiss});
  final CatchUpSummary summary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.surface, borderRadius: Radii.xlAll, border: Border.all(color: c.accent.withValues(alpha: 0.45))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bolt_rounded, color: c.accentInk, size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text('What just happened?', style: context.text.titleMedium)),
            GestureDetector(onTap: onDismiss, child: Icon(Icons.close_rounded, size: 20, color: c.textMuted)),
          ]),
          const SizedBox(height: 4),
          Text(summary.headline, style: AppType.display(22, color: c.text)),
          const SizedBox(height: 12),
          for (var i = 0; i < summary.bullets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(margin: const EdgeInsets.only(top: 7, right: 10), width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                Expanded(child: Text(summary.bullets[i], style: AppType.body(14.5, color: c.text))),
              ]),
            ).animate(delay: 120.ms + Motion.staggerFor(i) * 2).fadeIn(duration: Motion.base).slideX(begin: 0.05),
          const SizedBox(height: 4),
          Text(summary.scoreLine, style: AppType.body(14, weight: 650, color: c.accentInk)),
          const SizedBox(height: 12),
          const ProvenanceTag(Provenance.generated, source: 'from confirmed events', compact: true),
        ]),
      ),
    );
  }
}

/// Two-sided event timeline with a centre spine: home events on the left,
/// away on the right, minute bubbles in the middle.
class EventTimeline extends StatelessWidget {
  const EventTimeline({super.key, required this.match, this.kinds});
  final Match match;
  final Set<EventKind>? kinds;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = match;
    final events = m.sortedEvents.where((e) => kinds == null || kinds!.contains(e.kind)).toList().reversed.toList();
    final rows = <Widget>[];
    if (m.status.isFinished) rows.add(_Marker(label: 'FT  ${m.homeGoals}–${m.awayGoals}'));
    var htShown = false;
    for (final e in events) {
      if (!htShown && e.minute <= 45 && (m.status.short != '1H') && m.halftime.isSet) {
        rows.add(_Marker(label: 'HT  ${m.halftime.home}–${m.halftime.away}'));
        htShown = true;
      }
      rows.add(_EventRow(key: ValueKey(e.key), event: e, home: e.teamId == m.home.id));
    }
    if (!htShown && m.halftime.isSet && m.status.short != '1H') rows.add(_Marker(label: 'HT  ${m.halftime.home}–${m.halftime.away}'));
    if (!m.status.isScheduled) rows.add(const _Marker(label: 'Kick-off'));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.xlAll),
      child: Stack(children: [
        Positioned.fill(child: Center(child: Container(width: 1.5, color: c.hairline))),
        Column(children: rows),
      ]),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: c.surface3, borderRadius: Radii.pillAll),
          child: Text(label, style: AppType.numeric(12, weight: 700, color: c.textMuted)),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({super.key, required this.event, required this.home});
  final MatchEvent event;
  final bool home;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = event;
    final title = switch (e.kind) {
      EventKind.sub => '${e.playerName ?? ''} IN',
      EventKind.ownGoal => '${e.playerName ?? ''} (OG)',
      EventKind.penaltyGoal => '${e.playerName ?? ''} (P)',
      EventKind.varDecision => 'VAR',
      _ => e.playerName ?? e.detail,
    };
    final sub = switch (e.kind) {
      EventKind.goal => e.relatedName != null ? 'Assist ${e.relatedName}' : null,
      EventKind.sub => e.relatedName != null ? '${e.relatedName} OFF' : null,
      EventKind.varDecision => e.detail,
      EventKind.missedPenalty => 'Missed penalty',
      EventKind.secondYellow => 'Second yellow',
      _ => e.comment,
    };
    final content = Flexible(
      child: Column(crossAxisAlignment: home ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(title, style: AppType.body(14, weight: e.isGoal ? 700 : 560, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: home ? TextAlign.right : TextAlign.left),
        if (sub != null) Text(sub, style: AppType.body(12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: home ? TextAlign.right : TextAlign.left),
      ]),
    );
    final side = Row(mainAxisAlignment: home ? MainAxisAlignment.end : MainAxisAlignment.start, children: home ? [content, const SizedBox(width: 10), EventIcon(kind: e.kind)] : [EventIcon(kind: e.kind), const SizedBox(width: 10), content]);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      child: Row(children: [
        Expanded(child: home ? side : const SizedBox()),
        Container(
          width: 46,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: e.isGoal ? c.accent : c.surface2, borderRadius: Radii.pillAll),
          child: Text(e.minuteLabel, textAlign: TextAlign.center, style: AppType.numeric(12, weight: 750, color: e.isGoal ? c.onAccent : c.text)),
        ),
        Expanded(child: home ? const SizedBox() : side),
      ]),
    );
    // New events (e.g. a live goal) animate in; the key keeps old ones still.
    return row.animate().fadeIn(duration: Motion.slow).slideX(begin: home ? -0.08 : 0.08, curve: Motion.emphasized);
  }
}

/// Possession + a few headline comparisons.
class KeyStats extends StatelessWidget {
  const KeyStats({super.key, required this.match});
  final Match match;
  @override
  Widget build(BuildContext context) {
    final s = match.stats!;
    final pos = s[StatKey.possession];
    return AppCard(
      child: Column(children: [
        if (pos != null && pos.home != null && pos.away != null) ...[PossessionBar(home: pos.home!.toDouble(), away: pos.away!.toDouble(), onTap: () => showStatExplain(context, match, StatKey.possession)), const SizedBox(height: 8)],
        for (final k in [StatKey.xg, StatKey.shotsTotal, StatKey.shotsOn, StatKey.corners])
          if (s[k] != null) StatCompareRow(label: k.label, home: s[k]!.home, away: s[k]!.away, unit: k.unit, onTap: () => showStatExplain(context, match, k)),
      ]),
    );
  }
}

/// "Ask / explain" a statistic (spec §45 smart features).
void showStatExplain(BuildContext context, Match m, StatKey k) {
  final c = context.colors;
  final pair = m.stats?[k];
  final ctx = pair == null ? null : statContext(k, pair, m.home.name, m.away.name);
  final derived = m.stats?.derivedKeys.contains(k) ?? false;
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.label, style: context.text.headlineSmall),
          const SizedBox(height: 10),
          Text(statDefinition(k), style: AppType.body(15, color: c.text)),
          if (pair != null) ...[
            const SizedBox(height: Space.lg),
            StatCompareRow(label: '${m.home.short}  vs  ${m.away.short}', home: pair.home, away: pair.away, unit: k.unit),
          ],
          if (ctx != null) ...[
            const SizedBox(height: Space.md),
            Text(ctx, style: AppType.body(15, weight: 600, color: c.accentInk)),
            const SizedBox(height: 8),
            const ProvenanceTag(Provenance.generated, compact: true),
          ],
          if (derived) ...[
            const SizedBox(height: Space.md),
            Text('Team total calculated by adding up the provider\'s official per-player figures.', style: AppType.body(12.5, color: c.textMuted)),
          ],
        ]),
      ),
    ),
  );
}

class TopPerformers extends ConsumerWidget {
  const TopPerformers({super.key, required this.match, this.count = 3});
  final Match match;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final provider = ref.watch(repositoryProvider).providerName;
    final ps = [...?match.players?.where((p) => p.stats.rating != null)]..sort((a, b) => b.stats.rating!.compareTo(a.stats.rating!));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < ps.length && i < count; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: () => showPerformanceSheet(context, match, ps[i]),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text('${i + 1}', style: AppType.numeric(22, color: i == 0 ? c.accentInk : c.textFaint)),
              const SizedBox(width: 12),
              PlayerAvatar(name: ps[i].player.name, photo: ps[i].player.photo, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ps[i].player.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_keyLine(ps[i]), style: AppType.body(12.5, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              TeamCrest(team: match.teamById(ps[i].teamId) ?? match.home, size: 20),
              const SizedBox(width: 10),
              RatingBadge(rating: ps[i].stats.rating, size: 15),
            ]),
          ),
        ),
      Text('Ratings: official $provider player ratings', style: AppType.body(11.5, color: c.textFaint)),
    ]);
  }

  static String _keyLine(PlayerMatchLine p) {
    final s = p.stats;
    return [
      if ((s.goals ?? 0) > 0) '${s.goals} goal${s.goals == 1 ? '' : 's'}',
      if ((s.assists ?? 0) > 0) '${s.assists} assist${s.assists == 1 ? '' : 's'}',
      if ((s.saves ?? 0) > 0) '${s.saves} saves',
      if ((s.keyPasses ?? 0) > 0) '${s.keyPasses} key passes',
      if (s.minutes != null) "${s.minutes}'",
    ].take(3).join(' · ');
  }
}

/// Live player performance (spec §12) with links to profile, comparison and
/// a shareable player card.
void showPerformanceSheet(BuildContext context, Match m, PlayerMatchLine p) {
  showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _PerformanceSheet(match: m, line: p));
}

class _PerformanceSheet extends ConsumerWidget {
  const _PerformanceSheet({required this.match, required this.line});
  final Match match;
  final PlayerMatchLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // Keep the sheet live: read the freshest line for this player.
    final m = ref.watch(matchProvider(match.id)).value?.data ?? match;
    final p = m.players?.where((x) => x.player.id == line.player.id).firstOrNull ?? line;
    final s = p.stats;
    final team = m.teamById(p.teamId) ?? m.home;
    final gk = positionGroupOf(p.position) == PositionGroup.goalkeeper;
    String frac(int? a, int? b) => (a == null || b == null) ? '—' : '$a/$b';
    final tiles = <(String, String)>[
      ('Minutes', "${s.minutes ?? 0}'"),
      if (!gk) ('Goals', '${s.goals ?? 0}'),
      if (!gk) ('Assists', '${s.assists ?? 0}'),
      if (gk) ('Saves', '${s.saves ?? 0}'),
      if (gk) ('Conceded', '${s.conceded ?? 0}'),
      if (!gk) ('Shots (on target)', s.shots == null ? '—' : '${s.shots} (${s.shotsOn ?? 0})'),
      ('Key passes', '${s.keyPasses ?? '—'}'),
      ('Passes', s.passes == null ? '—' : '${s.passes}${s.passAccuracy != null ? ' · ${s.passAccuracy!.round()}%' : ''}'),
      ('Dribbles', frac(s.dribblesWon, s.dribbles)),
      ('Duels won', frac(s.duelsWon, s.duels)),
      ('Tackles', '${s.tackles ?? '—'}'),
      ('Interceptions', '${s.interceptions ?? '—'}'),
      if (s.xg != null) ('xG', s.xg!.toStringAsFixed(2)),
      if (s.xa != null) ('xA', s.xa!.toStringAsFixed(2)),
      if ((s.yellow ?? 0) > 0 || (s.red ?? 0) > 0) ('Cards', '${s.yellow ?? 0}Y ${s.red ?? 0}R'),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        children: [
          Row(children: [
            PlayerAvatar(name: p.player.name, photo: p.player.photo, size: 64, ring: c.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.player.name.toUpperCase(), style: AppType.display(20, color: c.text), maxLines: 2),
                const SizedBox(height: 4),
                Row(children: [
                  TeamCrest(team: team, size: 16),
                  const SizedBox(width: 6),
                  Flexible(child: Text('${team.name}${p.number != null ? ' · #${p.number}' : ''} · ${positionGroupOf(p.position).label}', style: AppType.body(12.5, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
            if (m.status.isLive) LiveBadge(label: m.status.minuteLabel),
          ]),
          const SizedBox(height: Space.lg),
          Row(children: [
            Text(s.rating?.toStringAsFixed(1) ?? '—', style: AppType.numeric(48, color: s.rating == null ? c.textFaint : RatingBadge.colorFor(s.rating!, c))),
            const SizedBox(width: 10),
            Expanded(child: Text(s.rating == null ? 'No rating yet' : 'Rating\n${ref.watch(repositoryProvider).providerName} official', style: AppType.body(12.5, color: c.textMuted))),
            if (p.captain) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll), child: Text('Captain', style: AppType.body(12, weight: 650, color: c.text))),
          ]),
          const SizedBox(height: Space.md),
          StatGrid(tiles: [for (final t in tiles) StatTile(label: t.$1, value: t.$2)]),
          const SizedBox(height: Space.lg),
          Row(children: [
            Expanded(child: PillButton(label: 'Profile', icon: Icons.person_rounded, onTap: () {
              Navigator.pop(context);
              context.push('/player/${p.player.id}');
            })),
            const SizedBox(width: 10),
            Expanded(child: PillButton(label: 'Compare', primary: false, icon: Icons.compare_arrows_rounded, onTap: () {
              Navigator.pop(context);
              context.push('/compare?a=${p.player.id}');
            })),
            const SizedBox(width: 10),
            CircleIconButton(icon: Icons.ios_share_rounded, size: 52, tooltip: 'Share player card', onTap: () {
              Navigator.pop(context);
              context.push('/share', extra: ShareRequest.playerInMatch(m.id, p.player.id));
            }),
          ]),
        ],
      ),
    );
  }
}
