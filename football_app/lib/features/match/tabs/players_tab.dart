import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../widgets/match_widgets.dart';

/// Every player's performance in this match, sorted by provider rating.
class PlayersTab extends ConsumerStatefulWidget {
  const PlayersTab({super.key, required this.match});
  final Match match;
  @override
  ConsumerState<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends ConsumerState<PlayersTab> {
  int? _team;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.match;
    final provider = ref.watch(repositoryProvider).providerName;
    final all = [...?m.players?.where((p) => (p.stats.minutes ?? 0) > 0)];
    if (all.isEmpty) {
      return ListView(children: [
        EmptyState(
          art: EmptyArt.matches,
          title: m.status.isScheduled ? 'Player stats start at kick-off' : 'No player statistics',
          message: m.status.isScheduled ? 'Ratings, shots, passes and duels update live during the match.' : '$provider has not published player statistics for this match.',
          compact: true,
        ),
      ]);
    }
    final list = all.where((p) => _team == null || p.teamId == _team).toList()..sort((a, b) => (b.stats.rating ?? 0).compareTo(a.stats.rating ?? 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [
        Row(children: [
          ChoiceChipPill(label: 'All', selected: _team == null, onTap: () => setState(() => _team = null)),
          const SizedBox(width: 8),
          ChoiceChipPill(label: m.home.short, selected: _team == m.home.id, onTap: () => setState(() => _team = m.home.id), leading: TeamCrest(team: m.home, size: 18)),
          const SizedBox(width: 8),
          ChoiceChipPill(label: m.away.short, selected: _team == m.away.id, onTap: () => setState(() => _team = m.away.id), leading: TeamCrest(team: m.away, size: 18)),
        ]),
        const SizedBox(height: Space.sm),
        Text('Ratings are official $provider figures.', style: AppType.body(12, color: c.textFaint)),
        const SizedBox(height: Space.sm),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PlayerRow(match: m, line: list[i]),
          ).animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.1),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.match, required this.line});
  final Match match;
  final PlayerMatchLine line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = line.stats;
    final chips = <String>[
      if ((s.goals ?? 0) > 0) '⚽ ${s.goals}',
      if ((s.assists ?? 0) > 0) 'A ${s.assists}',
      if (s.shots != null && s.shots! > 0) '${s.shots} shots',
      if ((s.keyPasses ?? 0) > 0) '${s.keyPasses} key passes',
      if ((s.saves ?? 0) > 0) '${s.saves} saves',
      if (s.duels != null && s.duels! > 0) '${s.duelsWon ?? 0}/${s.duels} duels',
    ];
    return AppCard(
      onTap: () => showPerformanceSheet(context, match, line),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          PlayerAvatar(name: line.player.name, photo: line.player.photo, size: 42),
          Positioned(right: -4, bottom: -4, child: TeamCrest(team: match.teamById(line.teamId) ?? match.home, size: 18)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(line.player.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (line.captain) Padding(padding: const EdgeInsets.only(left: 6), child: Text('C', style: AppType.body(11, weight: 800, color: c.accentInk))),
              if ((s.yellow ?? 0) > 0) const Padding(padding: EdgeInsets.only(left: 6), child: CardChip(red: false, size: 11)),
              if ((s.red ?? 0) > 0) const Padding(padding: EdgeInsets.only(left: 4), child: CardChip(red: true, size: 11)),
            ]),
            const SizedBox(height: 2),
            Text(
              [positionGroupOf(line.position).abbr, "${s.minutes}'", ...chips.take(3)].join(' · '),
              style: AppType.body(12.5, color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        s.rating == null ? Text('—', style: AppType.body(13, color: c.textFaint)) : RatingBadge(rating: s.rating, size: 14),
      ]),
    );
  }
}
