import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../domain/form.dart';
import '../../../domain/insights.dart';

/// Head-to-head (spec §25) + form/team comparison.
class H2HTab extends ConsumerStatefulWidget {
  const H2HTab({super.key, required this.match});
  final Match match;
  @override
  ConsumerState<H2HTab> createState() => _H2HTabState();
}

class _H2HTabState extends ConsumerState<H2HTab> {
  int _count = 5;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final async = ref.watch(h2hProvider((m.home.id, m.away.id)));
    return AsyncView(
      value: async,
      onRetry: () => ref.invalidate(h2hProvider((m.home.id, m.away.id))),
      builder: (fresh) {
        final meetings = fresh.data.where((x) => x.id != m.id && x.status.isFinished).toList();
        if (meetings.isEmpty) {
          return ListView(children: const [EmptyState(art: EmptyArt.matches, title: 'First meeting', message: 'These teams have no previous meetings on record with the provider.', compact: true)]);
        }
        final shown = meetings.take(_count).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
          children: [
            H2HSummaryCard(summary: summarizeH2H(shown, m.home, m.away), total: meetings.length),
            const SizedBox(height: Space.sm),
            Row(children: [
              for (final n in [5, 10])
                if (meetings.length > 5 || n == 5)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChipPill(label: 'Last $n', selected: _count == n, onTap: () => setState(() => _count = n))),
            ]),
            SectionHeader('Last ${shown.length} meetings', padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm)),
            for (var i = 0; i < shown.length; i++) Padding(padding: const EdgeInsets.only(bottom: 6), child: _Meeting(match: shown[i], perspective: m.home.id)).animate(delay: Motion.staggerFor(i)).fadeIn().slideY(begin: 0.1),
            const SectionHeader('Current form', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
            _FormCompare(match: m),
          ],
        );
      },
    );
  }
}

class H2HSummaryCard extends StatelessWidget {
  const H2HSummaryCard({super.key, required this.summary, this.total});
  final H2HSummary summary;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = summary;
    final period = s.from == null ? '' : ' · ${s.from!.year == s.to!.year ? '${s.from!.year}' : '${s.from!.year}–${s.to!.year}'}';
    final n = s.count == 0 ? 1 : s.count;
    Widget col(String v, String l, Color color) => Expanded(
          child: Column(children: [
            Text(v, style: AppType.numeric(36, color: color)),
            Text(l, style: AppType.body(12, color: c.textMuted), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );
    return AppCard(
      child: Column(children: [
        Text('LAST ${s.count} MEETINGS$period', style: AppType.overline(color: c.textMuted)),
        const SizedBox(height: 14),
        Row(children: [
          TeamCrest(team: s.teamA, size: 30),
          col('${s.winsA}', '${s.teamA.short} wins', c.accentInk),
          col('${s.draws}', 'Draws', c.text),
          col('${s.winsB}', '${s.teamB.short} wins', c.away),
          TeamCrest(team: s.teamB, size: 30),
        ]),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.draw,
          curve: Motion.emphasized,
          builder: (_, t, _) => ClipRRect(
            borderRadius: Radii.pillAll,
            child: SizedBox(
              height: 10,
              child: Row(children: [
                if (s.winsA > 0) Expanded(flex: (s.winsA * 100 * t).round().clamp(1, 100000), child: Container(color: c.accent)),
                if (s.draws > 0) Expanded(flex: (s.draws * 100 * t).round().clamp(1, 100000), child: Container(color: c.surface3)),
                if (s.winsB > 0) Expanded(flex: (s.winsB * 100 * t).round().clamp(1, 100000), child: Container(color: c.away)),
                Expanded(flex: ((1 - t) * n * 100).round().clamp(0, 100000) + 0, child: const SizedBox()),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Goals: ${s.teamA.short} ${s.goalsA} – ${s.goalsB} ${s.teamB.short}${total != null && total! > s.count ? ' · ${total!} meetings on record' : ''}', style: AppType.body(12.5, color: c.textMuted)),
      ]),
    );
  }
}

class _Meeting extends StatelessWidget {
  const _Meeting({required this.match, required this.perspective});
  final Match match;
  final int perspective;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = match.resultFor(perspective);
    return MatchRow(
      match: match,
      scope: 'h2h',
      showLeague: true,
      showDate: true,
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (r != null)
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: r == 'W' ? c.win : (r == 'L' ? c.loss : c.surface3), borderRadius: BorderRadius.circular(7)),
            child: Text(r, style: AppType.display(11, color: r == 'D' ? c.text : c.onAccent)),
          ),
        const SizedBox(height: 4),
        Text('${match.kickoff.year}', style: AppType.body(11, color: c.textFaint)),
        if (match.venue != null) SizedBox(width: 72, child: Text(match.venue!, style: AppType.body(10.5, color: c.textFaint), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _FormCompare extends ConsumerWidget {
  const _FormCompare({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Widget team(TeamRef t) {
      final ms = ref.watch(teamMatchesProvider(t.id));
      return Row(children: [
        TeamCrest(team: t, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Text(t.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
        switch (ms) {
          AsyncValue(:final value?) => () {
              final f = recentForm(value.data.where((x) => x.kickoff.isBefore(match.kickoff) || x.id != match.id), t.id, count: 5, before: match.status.isScheduled ? null : match.kickoff);
              final sum = summarizeForm(f, t.id);
              return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                FormStrip(results: f.map((e) => e.result).toList(), size: 22),
                const SizedBox(height: 4),
                Text('${sum.points} pts · ${sum.goalsFor}–${sum.goalsAgainst}', style: AppType.body(11.5, color: c.textMuted)),
              ]);
            }(),
          AsyncValue(hasError: true) => Text('Unavailable', style: AppType.body(12, color: c.textMuted)),
          _ => const Skeleton(height: 22, width: 130),
        },
      ]);
    }

    return AppCard(child: Column(children: [team(match.home), const Divider(height: 28), team(match.away), const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: Text('Last 5 results before this match · oldest → newest', style: AppType.body(11, color: c.textFaint)))]));
  }
}

String h2hPeriod(H2HSummary s) => s.from == null ? '' : '${shortDate(s.from!)} – ${shortDate(s.to!)}';
