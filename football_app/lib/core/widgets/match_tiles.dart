import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'pressable.dart';
import 'visuals.dart';

String crestHero(String scope, int matchId, int teamId) => 'crest-$scope-$matchId-$teamId';

void openMatch(BuildContext context, Match m, {String scope = 'x'}) => context.push('/match/${m.id}?h=$scope');

/// Large card for the LIVE NOW carousel. The [featured] card uses the lime
/// fill (one per screen — the accent is used with restraint).
class LiveMatchCard extends StatelessWidget {
  const LiveMatchCard({super.key, required this.match, this.featured = false, this.scope = 'live', this.width = 300});
  final Match match;
  final bool featured;
  final String scope;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = match;
    final fg = featured ? c.onAccent : c.text;
    final muted = featured ? c.onAccent.withValues(alpha: 0.62) : c.textMuted;
    final goals = m.goals;
    Widget side(TeamRef t) => Expanded(
          child: Column(children: [
            TeamCrest(team: t, size: 52, heroTag: crestHero(scope, m.id, t.id)),
            const SizedBox(height: 8),
            Text(t.name, style: AppType.body(13.5, weight: 650, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ]),
        );
    Widget scorers(int teamId, CrossAxisAlignment align) {
      final list = goals.where((g) => g.teamId == teamId).toList();
      return Expanded(
        child: Column(crossAxisAlignment: align, children: [
          for (final g in list.take(list.length > 2 ? 1 : 2))
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sports_soccer, size: 12, color: muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text("${shortName(g.playerName ?? '')} ${g.minuteLabel}${g.kind == EventKind.penaltyGoal ? ' (P)' : g.kind == EventKind.ownGoal ? ' (OG)' : ''}",
                      style: AppType.body(12, weight: 500, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          if (list.length > 2) Padding(padding: const EdgeInsets.only(top: 3), child: Text('+${list.length - 1} more', style: AppType.body(11.5, color: muted))),
        ]),
      );
    }

    return Pressable(
      onTap: () => openMatch(context, m, scope: scope),
      semanticLabel: '${m.home.name} ${m.homeGoals ?? 0}, ${m.away.name} ${m.awayGoals ?? 0}, ${m.status.minuteLabel}',
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          borderRadius: Radii.xlAll,
          color: featured ? null : c.surface,
          gradient: featured ? LinearGradient(colors: [c.accent, Color.lerp(c.accent, c.mint, 0.45)!], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          border: featured ? null : Border.all(color: c.hairline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(m.league.name.toUpperCase(), style: AppType.overline(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (m.status.isLive) LiveBadge(label: m.status.minuteLabel, onAccent: featured) else Text(m.status.isFinished ? 'FT' : kickoffTime(m.kickoff), style: AppType.numeric(13, weight: 700, color: muted)),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            side(m.home),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                ScoreNumber(value: m.homeGoals, style: AppType.numeric(40, color: fg), glow: featured ? c.onAccent : null),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: AppType.numeric(32, color: muted))),
                ScoreNumber(value: m.awayGoals, style: AppType.numeric(40, color: fg), glow: featured ? c.onAccent : null),
              ]),
            ),
            side(m.away),
          ]),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [scorers(m.home.id, CrossAxisAlignment.start), const SizedBox(width: 12), scorers(m.away.id, CrossAxisAlignment.end)]),
          ],
        ]),
      ),
    );
  }
}

/// Compact list row used across Matches, Team fixtures, League results…
class MatchRow extends StatelessWidget {
  const MatchRow({super.key, required this.match, this.scope = 'row', this.showLeague = false, this.showDate = false, this.highlightTeamId, this.trailing});
  final Match match;
  final String scope;
  final bool showLeague;
  final bool showDate;
  final int? highlightTeamId;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = match;
    final live = m.status.isLive;
    int reds(int teamId) => (m.events ?? const <MatchEvent>[]).where((e) => e.teamId == teamId && e.isRed).length;

    Widget teamLine(TeamRef t, int? goals, bool winner) {
      final r = reds(t.id);
      final bold = winner || highlightTeamId == t.id;
      return Row(children: [
        TeamCrest(team: t, size: 22, heroTag: crestHero(scope, m.id, t.id)),
        const SizedBox(width: 10),
        Flexible(child: Text(t.name, style: AppType.body(14.5, weight: bold ? 650 : 480, color: (m.status.isFinished && !winner) ? c.textMuted : c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
        for (var i = 0; i < r; i++) const Padding(padding: EdgeInsets.only(left: 5), child: CardChip(red: true, size: 11)),
        const Spacer(),
        if (m.hasScore || live)
          ScoreNumber(value: goals, style: AppType.numeric(17, weight: 760, color: live ? c.accentInk : (m.status.isFinished && !winner ? c.textMuted : c.text))),
      ]);
    }

    final hw = m.homeWinner == true || (m.status.isFinished && (m.homeGoals ?? 0) > (m.awayGoals ?? 0));
    final aw = m.awayWinner == true || (m.status.isFinished && (m.awayGoals ?? 0) > (m.homeGoals ?? 0));

    final left = live
        ? Column(mainAxisSize: MainAxisSize.min, children: [LiveDot(size: 6, color: c.live), Text(m.status.minuteLabel, style: AppType.numeric(12.5, weight: 700, color: c.live))])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Text(m.status.isScheduled ? kickoffTime(m.kickoff) : m.status.minuteLabel, style: AppType.numeric(12.5, weight: 650, color: m.status.isScheduled ? c.text : c.textMuted)),
            if (showDate) Text(shortDate(m.kickoff), style: AppType.body(11, color: c.textFaint)),
          ]);

    return Pressable(
      onTap: () => openMatch(context, m, scope: scope),
      scale: 0.985,
      semanticLabel: '${m.home.name} ${m.homeGoals ?? ''} ${m.away.name} ${m.awayGoals ?? ''} ${m.status.minuteLabel}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: Radii.lgAll, border: live ? Border.all(color: c.live.withValues(alpha: 0.28)) : null),
        child: Row(children: [
          SizedBox(width: 50, child: Center(child: left)),
          Container(width: 1, height: 40, color: c.hairline, margin: const EdgeInsets.only(right: 12)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showLeague) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(m.league.name.toUpperCase(), style: AppType.overline(color: c.textFaint, size: 10.5))),
              teamLine(m.home, m.homeGoals, hw),
              const SizedBox(height: 8),
              teamLine(m.away, m.awayGoals, aw),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
      ),
    );
  }
}

/// Competition header used when grouping matches.
class CompetitionHeader extends StatelessWidget {
  const CompetitionHeader({super.key, required this.league, this.onTap, this.trailing});
  final LeagueRef league;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
        child: Row(children: [
          LeagueLogo(league: league, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: league.name, style: AppType.body(14.5, weight: 650, color: c.text)),
                if (league.country != null) TextSpan(text: '  ${league.country}', style: AppType.body(13, color: c.textFaint)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: c.textFaint),
        ]),
      ),
    );
  }
}
