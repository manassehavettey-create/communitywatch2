import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import 'share_screen.dart';

/// Share cards always render in the dark palette (social-ready, brand
/// consistent) regardless of the app theme. Layout is designed for a
/// 360-wide logical canvas exported at 1080px.
const _c = AppColors.dark;

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.bg, required this.child, required this.format, this.demo = false, this.bgAlign = Alignment.center});
  final String bg;
  final Widget child;
  final CardFormat format;
  final bool demo;
  final Alignment bgAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 360,
        height: 360 / format.ratio,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: _c.bg),
          Opacity(opacity: 0.9, child: ArtImage(bg, alignment: bgAlign)),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_c.bg.withValues(alpha: 0.35), _c.bg.withValues(alpha: 0.55), _c.bg.withValues(alpha: 0.92)]))),
          Padding(padding: const EdgeInsets.all(22), child: child),
          Positioned(left: 22, right: 22, bottom: 18, child: _Brand(demo: demo)),
        ]),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.demo = false});
  final bool demo;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('TOUCHLINE', style: AppType.display(13, width: 125, color: _c.text)),
        Text('.', style: AppType.display(13, color: _c.accent)),
        const Spacer(),
        if (demo) Text('DEMO DATA', style: AppType.overline(color: _c.accent, size: 9)),
      ]);
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.match, required this.format, this.demo = false});
  final Match match;
  final CardFormat format;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final status = m.status.isFinished ? 'FULL TIME' : (m.status.isLive ? 'LIVE ${m.status.minuteLabel}' : kickoffTime(m.kickoff));
    Widget team(TeamRef t) => Column(children: [
          TeamCrest(team: t, size: 64),
          const SizedBox(height: 10),
          Text(t.name.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, style: AppType.display(15, width: 110, color: _c.text)),
        ]);
    return _CardFrame(
      bg: 'assets/share/bg_result.jpg',
      format: format,
      demo: demo,
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(m.league.name.toUpperCase(), style: AppType.overline(color: _c.textMuted, size: 10))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: m.status.isLive ? _c.live : _c.accent, borderRadius: Radii.pillAll),
            child: Text(status, style: AppType.overline(color: m.status.isLive ? Colors.white : _c.onAccent, size: 9.5)),
          ),
        ]),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: team(m.home)), const SizedBox(width: 12), Expanded(child: team(m.away))]),
        const SizedBox(height: 14),
        Text('${m.homeGoals ?? 0} — ${m.awayGoals ?? 0}', style: AppType.numeric(78, weight: 900, color: _c.text).copyWith(fontVariations: const [FontVariation('wght', 900), FontVariation('wdth', 112)])),
        const SizedBox(height: 10),
        for (final g in m.goals.take(6))
          Text("${g.minuteLabel}  ${g.playerName ?? ''}${g.kind == EventKind.penaltyGoal ? ' (P)' : g.kind == EventKind.ownGoal ? ' (OG)' : ''}", style: AppType.body(12, weight: 500, color: g.teamId == m.home.id ? _c.accent : _c.away)),
        const Spacer(flex: 2),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.match, required this.format, this.demo = false});
  final Match match;
  final CardFormat format;
  final bool demo;
  @override
  Widget build(BuildContext context) {
    final m = match;
    final g = m.goals.last;
    final team = m.teamById(g.teamId) ?? m.home;
    return _CardFrame(
      bg: 'assets/share/bg_result.jpg',
      format: format,
      demo: demo,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.league.name.toUpperCase(), style: AppType.overline(color: _c.textMuted, size: 10)),
        const Spacer(),
        Text(g.minuteLabel, style: AppType.display(96, weight: 900, width: 125, color: _c.accent, italic: true, spacing: -4)),
        Row(children: [
          const Icon(Icons.sports_soccer, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text((g.playerName ?? team.name).toUpperCase(), style: AppType.display(30, color: _c.text), maxLines: 2)),
        ]),
        if (g.relatedName != null && g.kind == EventKind.goal) Text('Assist: ${g.relatedName}', style: AppType.body(13, color: _c.textMuted)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(color: _c.surface2.withValues(alpha: 0.85), borderRadius: Radii.pillAll),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            TeamCrest(team: m.home, size: 22),
            const SizedBox(width: 8),
            Text('${m.home.short} ${m.homeGoals}–${m.awayGoals} ${m.away.short}', style: AppType.numeric(16, color: _c.text)),
            const SizedBox(width: 8),
            TeamCrest(team: m.away, size: 22),
          ]),
        ),
        const Spacer(),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.name, this.photo, required this.team, required this.stats, required this.context, required this.format, this.demo = false});
  final String name;
  final String? photo;
  final TeamRef team;
  final PlayerStatLine stats;
  final String context;
  final CardFormat format;
  final bool demo;

  @override
  Widget build(BuildContext ctx) {
    final parts = name.split(' ');
    final s = stats;
    final tiles = <(String, String)>[
      ('Goals', '${s.goals ?? 0}'),
      ('Assists', '${s.assists ?? 0}'),
      if (s.rating != null) ('Rating', s.rating!.toStringAsFixed(1)) else ('Minutes', '${s.minutes ?? 0}'),
    ];
    return _CardFrame(
      bg: 'assets/share/bg_player.jpg',
      bgAlign: Alignment.centerRight,
      format: format,
      demo: demo,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (team.id != 0) ...[TeamCrest(team: team, size: 26), const SizedBox(width: 8)],
          Expanded(child: Text(team.name.toUpperCase(), style: AppType.overline(color: _c.textMuted, size: 10))),
        ]),
        const Spacer(),
        PlayerAvatar(name: name, photo: photo, size: 84, ring: _c.accent),
        const SizedBox(height: 14),
        if (parts.length > 1) Text(parts.sublist(0, parts.length - 1).join(' '), style: AppType.body(16, weight: 500, color: _c.textMuted)),
        Text(parts.last.toUpperCase(), style: AppType.display(50, weight: 900, width: 118, color: _c.text, spacing: -1.5), maxLines: 1),
        const SizedBox(height: 6),
        Text(context, style: AppType.body(12.5, color: _c.textMuted)),
        const SizedBox(height: 18),
        Row(children: [
          for (final (i, t) in tiles.indexed) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(color: i == tiles.length - 1 ? _c.accent : _c.surface2.withValues(alpha: 0.9), borderRadius: Radii.lgAll),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$2, style: AppType.numeric(30, color: i == tiles.length - 1 ? _c.onAccent : _c.text)),
                  Text(t.$1, style: AppType.body(11.5, weight: 600, color: i == tiles.length - 1 ? _c.onAccent.withValues(alpha: 0.7) : _c.textMuted)),
                ]),
              ),
            ),
            if (i < tiles.length - 1) const SizedBox(width: 8),
          ],
        ]),
        const Spacer(),
        const SizedBox(height: 18),
      ]),
    );
  }
}

class TableCard extends StatelessWidget {
  const TableCard({super.key, required this.table, required this.format, this.demo = false});
  final StandingsTable table;
  final CardFormat format;
  final bool demo;
  @override
  Widget build(BuildContext context) {
    final rows = table.groups.first.rows.take(5).toList();
    return _CardFrame(
      bg: 'assets/share/bg_table.jpg',
      bgAlign: Alignment.centerRight,
      format: format,
      demo: demo,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${table.league.name.toUpperCase()} · ${seasonLabel(table.season)}', style: AppType.overline(color: _c.textMuted, size: 10)),
        const SizedBox(height: 8),
        Text('TOP 5', style: AppType.display(44, weight: 900, width: 125, color: _c.text, italic: true)),
        const Spacer(),
        for (final (i, r) in rows.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: i == 0 ? _c.accent : _c.surface2.withValues(alpha: 0.9), borderRadius: Radii.lgAll),
            child: Row(children: [
              SizedBox(width: 22, child: Text('${r.rank}', style: AppType.numeric(16, color: i == 0 ? _c.onAccent : _c.textMuted))),
              TeamCrest(team: r.team, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(r.team.name, style: AppType.body(14, weight: 650, color: i == 0 ? _c.onAccent : _c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${r.played}P', style: AppType.body(11.5, color: i == 0 ? _c.onAccent.withValues(alpha: 0.7) : _c.textMuted)),
              const SizedBox(width: 12),
              Text('${r.points}', style: AppType.numeric(18, color: i == 0 ? _c.onAccent : _c.text)),
            ]),
          ),
        const Spacer(),
        const SizedBox(height: 18),
      ]),
    );
  }
}
