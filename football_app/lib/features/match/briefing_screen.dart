import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../domain/form.dart';
import '../../domain/insights.dart';
import 'tabs/h2h_tab.dart';

/// Pre-match briefing (spec §26). Every block is labelled CONFIRMED,
/// REPORTED or PREDICTED.
class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Match briefing')),
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(matchProvider(id)),
        builder: (fresh) => _Body(match: fresh.data),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final m = match;
    final caps = ref.watch(capabilitiesProvider);
    final provider = ref.watch(repositoryProvider).providerName;
    final h2h = ref.watch(h2hProvider((m.home.id, m.away.id)));
    final injuries = caps.injuries ? ref.watch(injuriesProvider(m.id)) : null;
    final prediction = caps.predictions ? ref.watch(predictionProvider(m.id)) : null;
    final lineupsOut = (m.lineups ?? const []).length == 2;

    final sections = <Widget>[
      // Hero.
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Overline(m.league.name),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(children: [TeamCrest(team: m.home, size: 56), const SizedBox(height: 8), Text(m.home.name, textAlign: TextAlign.center, style: context.text.titleSmall)])),
            Column(children: [
              Text('KICK-OFF', style: AppType.overline(color: c.textMuted)),
              Text(kickoffTime(m.kickoff), style: AppType.numeric(34, color: c.accentInk)),
              Text(dayLabel(m.kickoff), style: AppType.body(12.5, color: c.textMuted)),
            ]),
            Expanded(child: Column(children: [TeamCrest(team: m.away, size: 56), const SizedBox(height: 8), Text(m.away.name, textAlign: TextAlign.center, style: context.text.titleSmall)])),
          ]),
          if (m.venue != null) ...[const SizedBox(height: 12), Text('${m.venue}${m.city != null ? ', ${m.city}' : ''}', style: AppType.body(12.5, color: c.textMuted))],
        ]),
      ),
      _Section('Form', tag: const ProvenanceTag(Provenance.confirmed, compact: true), child: _Form(match: m)),
      _Section(
        'Head-to-head',
        tag: const ProvenanceTag(Provenance.confirmed, compact: true),
        child: switch (h2h) {
          AsyncValue(:final value?) when value.data.isNotEmpty => Column(children: [
              H2HSummaryCard(summary: summarizeH2H(value.data.take(5).toList(), m.home, m.away), total: value.data.length),
              const SizedBox(height: 8),
              for (final x in value.data.take(3)) Padding(padding: const EdgeInsets.only(bottom: 6), child: MatchRow(match: x, scope: 'brief', showDate: true, showLeague: true)),
            ]),
          AsyncValue(:final value?) when value.data.isEmpty => Text('No previous meetings on record.', style: AppType.body(14, color: c.textMuted)),
          AsyncValue(:final error?) => ErrorState(error: error, compact: true),
          _ => const Skeleton(height: 120, radius: Radii.xl),
        },
      ),
      _Section(
        'Lineups',
        tag: ProvenanceTag(lineupsOut ? Provenance.confirmed : Provenance.predicted, compact: true, source: lineupsOut ? 'official' : null),
        child: lineupsOut
            ? AppCard(
                onTap: () => context.push('/match/${m.id}?tab=lineups'),
                child: Row(children: [
                  Icon(Icons.groups_rounded, color: c.accentInk),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Official lineups are out: ${m.lineups!.map((l) => '${l.team.short} ${l.formation ?? ''}').join(' · ')}', style: AppType.body(14, color: c.text))),
                  Icon(Icons.arrow_forward_rounded, color: c.textMuted),
                ]),
              )
            : NotProvided(caps.predictedLineups ? 'Expected lineups' : 'Expected lineups (official lineups arrive ~1 hour before kick-off)', provider: caps.predictedLineups ? null : provider),
      ),
      _Section('Players to watch', tag: const ProvenanceTag(Provenance.confirmed, compact: true, source: 'season stats'), child: _PlayersToWatch(match: m)),
      if (injuries != null)
        _Section(
          'Unavailable players',
          tag: ProvenanceTag(Provenance.reported, compact: true, source: provider),
          child: switch (injuries) {
            AsyncValue(:final value?) when value.data.isEmpty => Text('No absences reported.', style: AppType.body(14, color: c.textMuted)),
            AsyncValue(:final value?) => _Injuries(match: m, list: value.data),
            AsyncValue(:final error?) => ErrorState(error: error, compact: true),
            _ => const Skeleton(height: 80, radius: Radii.xl),
          },
        ),
      if (prediction != null)
        _Section(
          'Prediction',
          tag: ProvenanceTag(Provenance.predicted, compact: true, source: provider),
          child: switch (prediction) {
            AsyncValue(value: Fresh(data: final p?)) => _Prediction(match: m, p: p),
            AsyncValue(hasValue: true) => Text('No prediction available.', style: AppType.body(14, color: c.textMuted)),
            AsyncValue(:final error?) => ErrorState(error: error, compact: true),
            _ => const Skeleton(height: 80, radius: Radii.xl),
          },
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [for (var i = 0; i < sections.length; i++) sections[i].animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.06)],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child, this.tag});
  final String title;
  final Widget child;
  final Widget? tag;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: context.text.headlineSmall)), ?tag]),
          const SizedBox(height: Space.sm),
          child,
        ]),
      );
}

class _Form extends ConsumerWidget {
  const _Form({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Widget row(TeamRef t) {
      final ms = ref.watch(teamMatchesProvider(t.id));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          TeamCrest(team: t, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(t.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          switch (ms) {
            AsyncValue(:final value?) => FormStrip(results: recentForm(value.data, t.id, before: match.kickoff).map((e) => e.result).toList(), size: 24),
            AsyncValue(hasError: true) => Text('Unavailable', style: AppType.body(12, color: c.textMuted)),
            _ => const Skeleton(height: 24, width: 140),
          },
        ]),
      );
    }

    return AppCard(child: Column(children: [row(match.home), row(match.away)]));
  }
}

class _PlayersToWatch extends ConsumerWidget {
  const _PlayersToWatch({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scorers = ref.watch(topScorersProvider(match.league.id));
    return switch (scorers) {
      AsyncValue(:final value?) => () {
          final picks = value.data.where((p) => p.seasons.any((s) => s.team.id == match.home.id || s.team.id == match.away.id)).take(4).toList();
          if (picks.isEmpty) return Text('No players from these teams in the competition\'s scoring charts yet.', style: AppType.body(14, color: c.textMuted));
          return Column(children: [
            for (final p in picks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  onTap: () => context.push('/player/${p.profile.id}'),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    PlayerAvatar(name: p.profile.name, photo: p.profile.photo, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.profile.name, style: context.text.titleSmall),
                        Text(p.mainTeam?.name ?? '', style: AppType.body(12.5, color: c.textMuted)),
                      ]),
                    ),
                    Text('${p.total.goals ?? 0} G · ${p.total.assists ?? 0} A', style: AppType.numeric(14, weight: 700, color: c.text)),
                  ]),
                ),
              ),
          ]);
        }(),
      AsyncValue(:final error?) => ErrorState(error: error, compact: true),
      _ => const Skeleton(height: 120, radius: Radii.xl),
    };
  }
}

class _Injuries extends StatelessWidget {
  const _Injuries({required this.match, required this.list});
  final Match match;
  final List<Injury> list;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(children: [
        for (final team in [match.home, match.away]) ...[
          for (final i in list.where((i) => i.teamId == team.id))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                TeamCrest(team: team, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(i.player.name, style: AppType.body(14, weight: 600, color: c.text))),
                Text(i.reason, style: AppType.body(12.5, color: c.textMuted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (i.isDoubtful ? c.reported : c.loss).withValues(alpha: 0.15), borderRadius: Radii.pillAll),
                  child: Text(i.isDoubtful ? 'Doubtful' : 'Out', style: AppType.body(11.5, weight: 700, color: i.isDoubtful ? c.reported : c.loss)),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _Prediction extends StatelessWidget {
  const _Prediction({required this.match, required this.p});
  final Match match;
  final Prediction p;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = p.homePct ?? 0, d = p.drawPct ?? 0, a = p.awayPct ?? 0;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${match.home.short} ${h.round()}%', style: AppType.numeric(18, color: c.accentInk))),
          Text('Draw ${d.round()}%', style: AppType.numeric(15, weight: 650, color: c.textMuted)),
          Expanded(child: Text('${a.round()}% ${match.away.short}', textAlign: TextAlign.right, style: AppType.numeric(18, color: c.away))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: Radii.pillAll,
          child: SizedBox(
            height: 10,
            child: Row(children: [
              Expanded(flex: h.round().clamp(1, 100), child: Container(color: c.accent)),
              Expanded(flex: d.round().clamp(1, 100), child: Container(color: c.surface3)),
              Expanded(flex: a.round().clamp(1, 100), child: Container(color: c.away)),
            ]),
          ),
        ),
        if (p.advice != null) ...[const SizedBox(height: 10), Text(p.advice!, style: AppType.body(13, color: c.textMuted))],
        const SizedBox(height: 6),
        Text('A statistical prediction, not a certainty. Not betting advice.', style: AppType.body(11.5, color: c.textFaint)),
      ]),
    );
  }
}
