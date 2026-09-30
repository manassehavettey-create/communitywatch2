import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../widgets/match_widgets.dart';

/// Both teams on one pitch (home attacking up), with ratings, captain,
/// goals, cards and substitutions overlaid (spec §11).
class LineupsTab extends StatelessWidget {
  const LineupsTab({super.key, required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    final lineups = match.lineups ?? const <Lineup>[];
    if (lineups.length < 2) {
      return ListView(children: [
        EmptyState(
          art: EmptyArt.matches,
          title: 'Lineups not announced',
          message: match.status.isScheduled ? 'Official lineups are usually published about an hour before kick-off. This tab updates automatically.' : 'The provider has not published lineups for this match.',
          compact: true,
        ),
      ]);
    }
    final home = lineups.firstWhere((l) => l.team.id == match.home.id, orElse: () => lineups.first);
    final away = lineups.firstWhere((l) => l.team.id == match.away.id, orElse: () => lineups.last);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [
        Row(children: [
          ProvenanceTag(home.provenance == Provenance.demo ? Provenance.demo : Provenance.confirmed, source: 'official lineups', compact: true),
        ]),
        const SizedBox(height: Space.sm),
        _FormationBar(lineup: away, top: true),
        const SizedBox(height: 8),
        _Pitch(match: match, home: home, away: away),
        const SizedBox(height: 8),
        _FormationBar(lineup: home, top: false),
        for (final lu in [home, away]) _Bench(match: match, lineup: lu),
      ],
    );
  }
}

class _FormationBar extends StatelessWidget {
  const _FormationBar({required this.lineup, required this.top});
  final Lineup lineup;
  final bool top;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      TeamCrest(team: lineup.team, size: 22),
      const SizedBox(width: 8),
      Expanded(child: Text(lineup.team.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (lineup.formation != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: c.surface2, borderRadius: Radii.pillAll),
          child: Text(lineup.formation!, style: AppType.numeric(13, weight: 700, color: c.text)),
        ),
    ]);
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch({required this.match, required this.home, required this.away});
  final Match match;
  final Lineup home;
  final Lineup away;

  /// Normalised positions (x: 0 left → 1 right, y: 0 top → 1 bottom).
  static Map<int, Offset> positions(Lineup lu, {required bool bottom}) {
    final out = <int, Offset>{};
    final withGrid = lu.startXI.where((p) => p.gridRow != null && p.gridCol != null).toList();
    List<List<LineupPlayer>> rows;
    if (withGrid.length == lu.startXI.length && withGrid.isNotEmpty) {
      final maxRow = withGrid.map((p) => p.gridRow!).reduce((a, b) => a > b ? a : b);
      rows = [for (var r = 1; r <= maxRow; r++) withGrid.where((p) => p.gridRow == r).toList()..sort((a, b) => a.gridCol!.compareTo(b.gridCol!))];
    } else {
      // No grid from the provider: group by position letter.
      rows = [for (final pos in ['G', 'D', 'M', 'F']) lu.startXI.where((p) => (p.pos ?? 'M') == pos).toList()];
    }
    rows = rows.where((r) => r.isNotEmpty).toList();
    for (var r = 0; r < rows.length; r++) {
      final n = rows[r].length;
      final depth = rows.length == 1 ? 0.0 : r / (rows.length - 1);
      final y = bottom ? 0.94 - depth * 0.38 : 0.06 + depth * 0.38;
      for (var i = 0; i < n; i++) {
        final xRaw = (i + 0.5) / n;
        out[rows[r][i].id] = Offset(bottom ? xRaw : 1 - xRaw, y);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hp = positions(home, bottom: true);
    final ap = positions(away, bottom: false);
    return AspectRatio(
      aspectRatio: 0.66,
      child: LayoutBuilder(builder: (context, box) {
        Widget place(LineupPlayer p, Offset o, Lineup lu, int idx, bool isHome) {
          const w = 76.0;
          return Positioned(
            left: o.dx * box.maxWidth - w / 2,
            top: o.dy * box.maxHeight - 22,
            width: w,
            child: _PlayerMarker(match: match, player: p, lineup: lu, isHome: isHome)
                .animate(delay: Motion.staggerFor(idx) * 1.4)
                .fadeIn(duration: Motion.slow)
                .scale(begin: const Offset(0.6, 0.6), curve: Motion.spring, duration: Motion.slow),
          );
        }

        return Container(
          decoration: BoxDecoration(borderRadius: Radii.xlAll, color: c.isDark ? const Color(0xFF0F1A13) : const Color(0xFFE3EEDF)),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: PitchPainter(line: (c.isDark ? Colors.white : c.mint).withValues(alpha: 0.16), stripe: (c.isDark ? Colors.white : c.mint).withValues(alpha: 0.025)))),
            for (var i = 0; i < away.startXI.length; i++) if (ap[away.startXI[i].id] != null) place(away.startXI[i], ap[away.startXI[i].id]!, away, i, false),
            for (var i = 0; i < home.startXI.length; i++) if (hp[home.startXI[i].id] != null) place(home.startXI[i], hp[home.startXI[i].id]!, home, i + 11, true),
          ]),
        );
      }),
    );
  }
}

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker({required this.match, required this.player, required this.lineup, required this.isHome});
  final Match match;
  final LineupPlayer player;
  final Lineup lineup;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final events = match.events ?? const <MatchEvent>[];
    final line = match.players?.where((x) => x.player.id == player.id).firstOrNull;
    final goals = events.where((e) => e.isGoal && e.kind != EventKind.ownGoal && e.playerId == player.id).length;
    final assists = events.where((e) => e.kind == EventKind.goal && e.relatedId == player.id).length;
    final yellow = events.any((e) => e.kind == EventKind.yellow && e.playerId == player.id);
    final red = events.any((e) => e.isRed && e.playerId == player.id);
    final off = events.where((e) => e.kind == EventKind.sub && e.relatedId == player.id).firstOrNull;
    final shirt = lineup.primaryColor != null ? Color(lineup.primaryColor!) : (isHome ? c.accent : c.away);
    final number = lineup.numberColor != null ? Color(lineup.numberColor!) : c.onAccent;
    final rating = line?.stats.rating;

    return GestureDetector(
      onTap: () => line != null ? showPerformanceSheet(context, match, line) : context.push('/player/${player.id}'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 50,
          height: 42,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: shirt, border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))]),
              child: Text('${player.number ?? ''}', style: AppType.numeric(14, weight: 800, color: number)),
            ),
            if (rating != null) Positioned(right: -6, top: -4, child: RatingBadge(rating: rating, size: 9.5)),
            if (line?.captain ?? false)
              Positioned(
                left: -2,
                top: -3,
                child: Container(width: 15, height: 15, alignment: Alignment.center, decoration: BoxDecoration(color: c.text, shape: BoxShape.circle), child: Text('C', style: AppType.body(9, weight: 800, color: c.bg))),
              ),
            if (goals > 0 || assists > 0)
              Positioned(
                left: -6,
                bottom: -2,
                child: Row(children: [
                  for (var i = 0; i < goals; i++) Container(margin: const EdgeInsets.only(right: 1), decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle), child: Icon(Icons.sports_soccer, size: 13, color: c.text)),
                  if (assists > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(6)), child: Text('A', style: AppType.body(9, weight: 800, color: c.accentInk))),
                ]),
              ),
            if (yellow || red) Positioned(right: -1, bottom: -2, child: CardChip(red: red, size: 12)),
            if (off != null)
              Positioned(
                right: -8,
                bottom: 10,
                child: Container(decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle), child: Icon(Icons.south_rounded, size: 13, color: c.loss)),
              ),
          ]),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6)),
          child: Text(pitchName(player.name), style: AppType.body(10.5, weight: 600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

class _Bench extends StatelessWidget {
  const _Bench({required this.match, required this.lineup});
  final Match match;
  final Lineup lineup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final events = match.events ?? const <MatchEvent>[];
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TeamCrest(team: lineup.team, size: 20),
          const SizedBox(width: 8),
          Text('Substitutes', style: context.text.titleMedium),
          const Spacer(),
          if (lineup.coach != null) Text('Coach: ${lineup.coach}', style: AppType.body(12.5, color: c.textMuted)),
        ]),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final p in lineup.substitutes)
              Builder(builder: (context) {
                final on = events.where((e) => e.kind == EventKind.sub && e.playerId == p.id).firstOrNull;
                final line = match.players?.where((x) => x.player.id == p.id).firstOrNull;
                return ListTile(
                  dense: true,
                  onTap: () => line != null && (line.stats.minutes ?? 0) > 0 ? showPerformanceSheet(context, match, line) : context.push('/player/${p.id}'),
                  leading: SizedBox(width: 28, child: Text('${p.number ?? ''}', style: AppType.numeric(15, color: c.textMuted), textAlign: TextAlign.center)),
                  title: Text(p.name, style: AppType.body(14, weight: 560, color: on != null ? c.text : c.textMuted)),
                  subtitle: on == null ? null : Text("On ${on.minuteLabel}${on.relatedName != null ? ' for ${on.relatedName}' : ''}", style: AppType.body(12, color: c.mint)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (on != null) Icon(Icons.north_rounded, size: 15, color: c.mint),
                    if (line?.stats.rating != null) ...[const SizedBox(width: 6), RatingBadge(rating: line!.stats.rating, size: 11)],
                  ]),
                );
              }),
          ]),
        ),
      ]),
    );
  }
}
