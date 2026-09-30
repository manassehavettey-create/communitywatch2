import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../domain/insights.dart';

Color zoneColor(ZoneKind k, AppColors c) => switch (k) {
      ZoneKind.champions => c.accent,
      ZoneKind.europa => c.away,
      ZoneKind.conference => c.mint,
      ZoneKind.promotion => c.mint,
      ZoneKind.playoff => c.reported,
      ZoneKind.relegation => c.loss,
      ZoneKind.other => c.textMuted,
    };

/// League table with provider-defined zones, trend arrows and animated
/// position changes: rows glide to their new place when the table updates.
class StandingsView extends ConsumerWidget {
  const StandingsView({super.key, required this.rows, this.highlightTeamId, this.compact = false});
  final List<StandingRow> rows;
  final int? highlightTeamId;
  final bool compact;

  static const rowH = 50.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final followed = ref.watch(followedTeamIdsProvider);
    final cols = compact ? const ['P', 'GD', 'Pts'] : const ['P', 'W', 'D', 'L', 'G', 'GD', 'Pts'];
    const numW = 28.0, goalsW = 44.0;
    double w(String col) => col == 'G' ? goalsW : (col == 'Pts' ? 34 : numW);

    Widget header() => Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
          child: Row(children: [
            SizedBox(width: 28, child: Text('#', style: AppType.overline(color: c.textFaint))),
            Expanded(child: Text('Team', style: AppType.overline(color: c.textFaint))),
            for (final col in cols) SizedBox(width: w(col), child: Text(col == 'G' ? 'GF–GA' : col, textAlign: TextAlign.center, style: AppType.overline(color: col == 'Pts' ? c.text : c.textFaint, size: 10.5))),
          ]),
        );

    Widget row(StandingRow r) {
      final z = zoneFor(r.description);
      final hi = r.team.id == highlightTeamId;
      final fol = followed.contains(r.team.id);
      final vals = <String, String>{'P': '${r.played}', 'W': '${r.win}', 'D': '${r.draw}', 'L': '${r.lose}', 'G': '${r.goalsFor}–${r.goalsAgainst}', 'GD': r.goalDiff > 0 ? '+${r.goalDiff}' : '${r.goalDiff}', 'Pts': '${r.points}'};
      return Pressable(
        onTap: () => context.push('/team/${r.team.id}'),
        scale: 0.99,
        semanticLabel: '${r.rank}, ${r.team.name}, ${r.points} points${z != null ? ', ${z.label}' : ''}',
        child: Container(
          height: rowH,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.only(left: 10, right: 8),
          decoration: BoxDecoration(color: hi ? c.accent.withValues(alpha: 0.14) : (fol ? c.surface2 : Colors.transparent), borderRadius: Radii.mdAll),
          child: Row(children: [
            Container(width: 3, height: 26, decoration: BoxDecoration(color: z == null ? Colors.transparent : zoneColor(z.kind, c), borderRadius: Radii.pillAll)),
            const SizedBox(width: 8),
            SizedBox(
              width: 22,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${r.rank}', style: AppType.numeric(14, weight: 700, color: c.text)),
                if (r.trend != Trend.same) Icon(r.trend == Trend.up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 16, color: r.trend == Trend.up ? c.win : c.loss),
              ]),
            ),
            const SizedBox(width: 6),
            TeamCrest(team: r.team, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Row(children: [
                Flexible(child: Text(r.team.name, style: AppType.body(14, weight: hi || fol ? 700 : 520, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (fol) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.star_rounded, size: 13, color: c.accentInk)),
              ]),
            ),
            for (final col in cols)
              SizedBox(
                width: w(col),
                child: Text(vals[col]!, textAlign: TextAlign.center, style: AppType.numeric(col == 'Pts' ? 14.5 : 13, weight: col == 'Pts' ? 800 : 560, color: col == 'Pts' ? c.text : c.textMuted)),
              ),
          ]),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(children: [
        header(),
        SizedBox(
          height: rows.length * rowH,
          child: Stack(children: [
            for (var i = 0; i < rows.length; i++)
              AnimatedPositioned(
                key: ValueKey(rows[i].team.id),
                duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
                curve: Motion.emphasized,
                top: i * rowH,
                left: 0,
                right: 0,
                height: rowH,
                child: row(rows[i]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class ZoneLegend extends StatelessWidget {
  const ZoneLegend({super.key, required this.table});
  final StandingsTable table;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final zones = legendFor(table);
    if (zones.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final z in zones)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: zoneColor(z.kind, c), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(z.label, style: AppType.body(12.5, color: c.textMuted))),
          ]),
        ),
      const SizedBox(height: 4),
      Text('Qualification and relegation places as defined by the data provider for this competition.', style: AppType.body(11.5, color: c.textFaint)),
    ]);
  }
}
