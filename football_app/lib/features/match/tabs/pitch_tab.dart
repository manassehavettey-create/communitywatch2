import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';

enum PitchMode { shots, heatmap, passes, touches }

/// Interactive pitch (spec §10). Shows only what the provider supplies; each
/// unavailable layer is labelled rather than estimated.
class PitchTab extends ConsumerStatefulWidget {
  const PitchTab({super.key, required this.match});
  final Match match;
  @override
  ConsumerState<PitchTab> createState() => _PitchTabState();
}

class _PitchTabState extends ConsumerState<PitchTab> {
  PitchMode _mode = PitchMode.shots;
  int? _player;
  int? _team;

  bool _supported(ProviderCapabilities c, PitchMode m) => switch (m) { PitchMode.shots => c.shotMap, PitchMode.heatmap => c.heatmap, PitchMode.passes => c.passMap, PitchMode.touches => c.touches };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.match;
    final caps = ref.watch(capabilitiesProvider);
    final provider = ref.watch(repositoryProvider).providerName;
    final analytics = ref.watch(analyticsProvider(m.id)).value?.data;
    final supported = _supported(caps, _mode);
    final players = [...?m.players?.where((p) => (p.stats.minutes ?? 0) > 0 && (_team == null || p.teamId == _team))]..sort((a, b) => (b.stats.rating ?? 0).compareTo(a.stats.rating ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final mode in PitchMode.values)
            ChoiceChipPill(
              label: mode.name.toUpperCase(),
              selected: _mode == mode,
              onTap: () => setState(() => _mode = mode),
              leading: _supported(caps, mode) ? null : Icon(Icons.lock_outline_rounded, size: 14, color: _mode == mode ? c.onAccent : c.textFaint),
            ),
        ]),
        const SizedBox(height: Space.md),
        if (m.status.isScheduled)
          const EmptyState(art: EmptyArt.matches, title: 'Pitch data starts at kick-off', message: 'Shots, heatmaps, passes and touches appear here during the match where the provider supplies them.', compact: true)
        else if (!supported) ...[
          _PositionsPitch(match: m),
          const SizedBox(height: Space.md),
          NotProvided('${_mode.name[0].toUpperCase()}${_mode.name.substring(1)} data', provider: provider),
          const SizedBox(height: 6),
          Text('Showing formation positions from the official lineups instead.', style: AppType.body(12.5, color: c.textFaint)),
        ] else ...[
          _TeamToggle(match: m, team: _team, onChanged: (t) => setState(() {
                _team = t;
                _player = null;
              })),
          const SizedBox(height: Space.sm),
          AspectRatio(
            aspectRatio: 1.52,
            child: Container(
              decoration: BoxDecoration(color: c.isDark ? const Color(0xFF0F1A13) : const Color(0xFFE3EEDF), borderRadius: Radii.xlAll),
              child: analytics == null
                  ? const Center(child: CircularProgressIndicator())
                  : TweenAnimationBuilder<double>(
                      key: ValueKey('$_mode-$_player-$_team'),
                      tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                      duration: Motion.draw,
                      curve: Motion.emphasized,
                      builder: (_, t, _) => CustomPaint(
                        painter: _LayerPainter(mode: _mode, analytics: analytics, match: m, player: _player, team: _team, progress: t, colors: c),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          _Legend(mode: _mode),
          if (_mode == PitchMode.shots && analytics != null) _ShotSummary(analytics: analytics, match: m, player: _player, team: _team),
          const SizedBox(height: Space.md),
          Text(_mode == PitchMode.heatmap && _player == null ? 'Select a player to see their individual heatmap.' : 'Select a player to isolate their activity.', style: AppType.body(12.5, color: c.textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: players.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => i == 0
                  ? ChoiceChipPill(label: 'All', selected: _player == null, onTap: () => setState(() => _player = null))
                  : ChoiceChipPill(
                      label: pitchName(players[i - 1].player.name),
                      selected: _player == players[i - 1].player.id,
                      leading: TeamCrest(team: m.teamById(players[i - 1].teamId) ?? m.home, size: 18),
                      onTap: () => setState(() => _player = players[i - 1].player.id),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamToggle extends StatelessWidget {
  const _TeamToggle({required this.match, required this.team, required this.onChanged});
  final Match match;
  final int? team;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        ChoiceChipPill(label: 'Both', selected: team == null, onTap: () => onChanged(null)),
        const SizedBox(width: 8),
        ChoiceChipPill(label: match.home.short, selected: team == match.home.id, onTap: () => onChanged(match.home.id), leading: TeamCrest(team: match.home, size: 18)),
        const SizedBox(width: 8),
        ChoiceChipPill(label: match.away.short, selected: team == match.away.id, onTap: () => onChanged(match.away.id), leading: TeamCrest(team: match.away, size: 18)),
      ]);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.mode});
  final PitchMode mode;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget dot(Color col, String l, {bool ring = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: ring ? null : col, border: ring ? Border.all(color: col, width: 1.5) : null)),
          const SizedBox(width: 5),
          Text(l, style: AppType.body(11.5, color: c.textMuted)),
        ]);
    final items = switch (mode) {
      PitchMode.shots => [dot(c.accent, 'Goal'), dot(c.text, 'On target', ring: true), dot(c.textFaint, 'Off target / blocked'), Text('Size = xG', style: AppType.body(11.5, color: c.textMuted))],
      PitchMode.passes => [dot(c.accent, 'Completed'), dot(c.loss, 'Missed')],
      PitchMode.heatmap => [Text('Brighter = more time on the ball in that zone', style: AppType.body(11.5, color: c.textMuted))],
      PitchMode.touches => [dot(c.accent, 'Home touch'), dot(c.away, 'Away touch')],
    };
    return Wrap(spacing: 14, runSpacing: 6, children: [...items, Text('→ attacking direction (home)', style: AppType.body(11.5, color: c.textFaint))]);
  }
}

class _ShotSummary extends StatelessWidget {
  const _ShotSummary({required this.analytics, required this.match, this.player, this.team});
  final MatchAnalytics analytics;
  final Match match;
  final int? player;
  final int? team;
  @override
  Widget build(BuildContext context) {
    final shots = analytics.shots.where((s) => (player == null || s.playerId == player) && (team == null || s.teamId == team)).toList();
    final xg = shots.fold(0.0, (a, s) => a + (s.xg ?? 0));
    final goals = shots.where((s) => s.outcome == ShotOutcome.goal).length;
    final on = shots.where((s) => s.outcome == ShotOutcome.goal || s.outcome == ShotOutcome.saved).length;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Row(children: [
        Expanded(child: SizedBox(height: 84, child: StatTile(label: 'Shots', value: '${shots.length}'))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 84, child: StatTile(label: 'On target', value: '$on'))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 84, child: StatTile(label: 'Goals', value: '$goals'))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 84, child: StatTile(label: 'xG', value: xg.toStringAsFixed(2), highlight: true))),
      ]),
    );
  }
}

class _LayerPainter extends CustomPainter {
  _LayerPainter({required this.mode, required this.analytics, required this.match, required this.player, required this.team, required this.progress, required this.colors});
  final PitchMode mode;
  final MatchAnalytics analytics;
  final Match match;
  final int? player;
  final int? team;
  final double progress;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    PitchPainter(line: (colors.isDark ? Colors.white : colors.mint).withValues(alpha: 0.18), vertical: false).paint(canvas, size);
    final homeId = match.home.id;
    // Away attacks right-to-left on the shared pitch.
    Offset map(double x, double y, int teamId) => teamId == homeId ? Offset(x * size.width, y * size.height) : Offset((1 - x) * size.width, (1 - y) * size.height);
    bool teamOk(int t) => team == null || t == team;
    Color teamColor(int t) => t == homeId ? colors.accent : colors.away;
    final playerTeam = {for (final p in match.players ?? const <PlayerMatchLine>[]) p.player.id: p.teamId};

    switch (mode) {
      case PitchMode.shots:
        final shots = analytics.shots.where((s) => teamOk(s.teamId) && (player == null || s.playerId == player)).toList();
        for (var i = 0; i < shots.length; i++) {
          final s = shots[i];
          final local = ((progress * shots.length) - i).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final o = map(s.x, s.y, s.teamId);
          final r = (6 + (s.xg ?? 0.05) * 30) * Curves.easeOutBack.transform(local);
          final paint = Paint();
          switch (s.outcome) {
            case ShotOutcome.goal:
              canvas.drawCircle(o, r + 4, Paint()..color = colors.accent.withValues(alpha: 0.25 * local));
              paint.color = colors.accent;
              canvas.drawCircle(o, r, paint);
            case ShotOutcome.saved:
              canvas.drawCircle(o, r, Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = colors.text);
            case ShotOutcome.blocked:
              final d = r * 0.6;
              final p = Paint()
                ..strokeWidth = 2
                ..color = colors.textFaint;
              canvas.drawLine(o - Offset(d, d), o + Offset(d, d), p);
              canvas.drawLine(o - Offset(d, -d), o + Offset(d, -d), p);
            case ShotOutcome.missed:
            case ShotOutcome.post:
              canvas.drawCircle(o, r, Paint()..color = colors.textFaint.withValues(alpha: 0.55));
          }
          if (team != null || player != null) canvas.drawCircle(o, 1.5, Paint()..color = teamColor(s.teamId));
        }
      case PitchMode.heatmap:
        final sources = analytics.heat.entries.where((e) => (player == null || e.key == player) && teamOk(playerTeam[e.key] ?? homeId));
        final pts = [for (final e in sources) for (final p in e.value) (p, playerTeam[e.key] ?? homeId)];
        if (pts.isEmpty) return;
        final radius = size.width * (player == null ? 0.07 : 0.1);
        final alpha = (player == null ? 0.05 : 0.16) * progress;
        canvas.saveLayer(Offset.zero & size, Paint());
        for (final (p, t) in pts) {
          final o = map(p.x, p.y, t);
          final col = team == null && player == null ? colors.accent : teamColor(t);
          canvas.drawCircle(o, radius, Paint()
            ..shader = RadialGradient(colors: [col.withValues(alpha: alpha), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: radius))
            ..blendMode = BlendMode.plus);
        }
        canvas.restore();
      case PitchMode.passes:
        final passes = analytics.passes.where((p) => teamOk(p.teamId) && (player == null || p.playerId == player)).toList();
        final show = player == null ? passes.take(160).toList() : passes;
        final n = (show.length * progress).round();
        for (final p in show.take(n)) {
          final a = map(p.from.x, p.from.y, p.teamId), b = map(p.to.x, p.to.y, p.teamId);
          final col = p.completed ? (team == null ? teamColor(p.teamId) : colors.accent) : colors.loss;
          final paint = Paint()
            ..color = col.withValues(alpha: player == null ? 0.45 : 0.85)
            ..strokeWidth = player == null ? 1.2 : 1.8;
          canvas.drawLine(a, b, paint);
          final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
          const h = 5.0;
          canvas.drawLine(b, b - Offset(math.cos(ang - 0.5), math.sin(ang - 0.5)) * h, paint);
          canvas.drawLine(b, b - Offset(math.cos(ang + 0.5), math.sin(ang + 0.5)) * h, paint);
        }
      case PitchMode.touches:
        final sources = analytics.touches.entries.where((e) => (player == null || e.key == player) && teamOk(playerTeam[e.key] ?? homeId));
        for (final e in sources) {
          final t = playerTeam[e.key] ?? homeId;
          final list = e.value;
          final n = (list.length * progress).round();
          for (final p in list.take(n)) {
            canvas.drawCircle(map(p.x, p.y, t), player == null ? 2.2 : 3.4, Paint()..color = teamColor(t).withValues(alpha: 0.85));
          }
        }
    }
  }

  @override
  bool shouldRepaint(_LayerPainter old) => old.progress != progress || old.mode != mode || old.player != player || old.team != team || old.analytics != analytics;
}

/// Formation positions from confirmed lineups — the fallback pitch view.
class _PositionsPitch extends StatelessWidget {
  const _PositionsPitch({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lus = match.lineups ?? const <Lineup>[];
    return AspectRatio(
      aspectRatio: 1.52,
      child: Container(
        decoration: BoxDecoration(color: c.isDark ? const Color(0xFF0F1A13) : const Color(0xFFE3EEDF), borderRadius: Radii.xlAll),
        child: LayoutBuilder(builder: (context, box) {
          final children = <Widget>[Positioned.fill(child: CustomPaint(painter: PitchPainter(line: (c.isDark ? Colors.white : c.mint).withValues(alpha: 0.18), vertical: false)))];
          for (final lu in lus) {
            final home = lu.team.id == match.home.id;
            final rows = <int, List<LineupPlayer>>{};
            for (final p in lu.startXI) {
              rows.putIfAbsent(p.gridRow ?? 1, () => []).add(p);
            }
            final maxRow = rows.keys.fold(1, math.max);
            rows.forEach((r, ps) {
              ps.sort((a, b) => (a.gridCol ?? 0).compareTo(b.gridCol ?? 0));
              for (var i = 0; i < ps.length; i++) {
                final depth = maxRow == 1 ? 0.0 : (r - 1) / (maxRow - 1);
                var x = 0.05 + depth * 0.4;
                var y = (i + 0.5) / ps.length;
                if (!home) {
                  x = 1 - x;
                  y = 1 - y;
                }
                children.add(Positioned(
                  left: x * box.maxWidth - 13,
                  top: y * box.maxHeight - 13,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: home ? c.accent : c.away),
                    child: Text('${ps[i].number ?? ''}', style: AppType.numeric(11, weight: 800, color: c.onAccent)),
                  ),
                ));
              }
            });
          }
          if (lus.isEmpty) children.add(Center(child: Text('Lineups not available', style: AppType.body(13, color: c.textMuted))));
          return Stack(children: children);
        }),
      ),
    );
  }
}
