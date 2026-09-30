import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../domain/catch_up.dart';
import '../widgets/match_widgets.dart';
import '../widgets/momentum_chart.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.match, required this.fresh, required this.seen, required this.catchUpDismissed, required this.onDismissCatchUp, required this.openTab});
  final Match match;
  final Fresh<Match> fresh;
  final SeenSnapshot? seen;
  final bool catchUpDismissed;
  final VoidCallback onDismissCatchUp;
  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = match;
    final caps = ref.watch(capabilitiesProvider);
    final analytics = ref.watch(analyticsProvider(m.id)).value?.data;
    final summary = catchUpDismissed ? null : buildCatchUp(m, seen: seen);
    final stats = m.stats;

    final children = <Widget>[
      if (m.status.isScheduled) _EntryCard(icon: Icons.insights_rounded, title: 'Match briefing', sub: 'Form, head-to-head, availability and players to watch', onTap: () => context.push('/match/${m.id}/briefing'), accent: true),
      if (m.status.isFinished) _EntryCard(icon: Icons.flag_rounded, title: 'Match recap', sub: 'Goals, key stats, top performers and key moments', onTap: () => context.push('/match/${m.id}/recap'), accent: true),
      if (summary != null && m.status.isLive) CatchUpCard(summary: summary, onDismiss: onDismissCatchUp),
      if (m.status.isScheduled) _KickoffCard(match: m),
      if ((m.events ?? const []).isNotEmpty) ...[
        const _Title('Match events'),
        EventTimeline(match: m),
      ] else if (!m.status.isScheduled)
        const Padding(padding: EdgeInsets.only(top: Space.lg), child: NotProvided('Match events')),
      if (stats != null && !stats.isEmpty) ...[
        _Title('Key stats', action: 'All stats', onAction: () => openTab(2)),
        KeyStats(match: m),
      ],
      if (caps.momentum && analytics != null && analytics.momentum.isNotEmpty) ...[
        const _Title('Momentum'),
        AppCard(child: Column(children: [MomentumChart(points: analytics.momentum, match: m, shots: analytics.shots), const SizedBox(height: 10), const MomentumLegend()])),
      ] else if (!m.status.isScheduled) ...[
        const _Title('Momentum'),
        NotProvided('Live momentum data', provider: ref.watch(repositoryProvider).providerName),
      ],
      if ((m.players ?? const []).any((p) => p.stats.rating != null)) ...[
        _Title('Top performers', action: 'All players', onAction: () => openTab(5)),
        TopPerformers(match: m),
      ],
      _Title('Match info'),
      _Info(match: m),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      children: [
        for (var i = 0; i < children.length; i++) children[i].animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.06, curve: Motion.emphasized),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => SectionHeader(text, action: action, onAction: onAction, padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm));
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.icon, required this.title, required this.sub, required this.onTap, this.accent = false});
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: AppCard(
        onTap: onTap,
        color: c.surface,
        border: true,
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle), child: Icon(icon, color: c.onAccent)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.text.titleMedium),
              Text(sub, style: AppType.body(13, color: c.textMuted)),
            ]),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.textMuted),
        ]),
      ),
    );
  }
}

class _KickoffCard extends StatelessWidget {
  const _KickoffCard({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: AppCard(
        child: StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, _) {
            final d = match.kickoff.difference(DateTime.now());
            String two(int n) => n.toString().padLeft(2, '0');
            final label = d.isNegative ? 'Kick-off imminent' : d.inDays > 0 ? '${d.inDays}d ${two(d.inHours % 24)}h ${two(d.inMinutes % 60)}m' : '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
            return Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Overline('Kick-off in'),
                  const SizedBox(height: 4),
                  Text(label, style: AppType.numeric(28, color: c.text)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(longDate(match.kickoff), style: AppType.body(13, weight: 600, color: c.text)),
                Text(kickoffTime(match.kickoff), style: AppType.numeric(18, color: c.accentInk)),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.match});
  final Match match;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = match;
    Widget row(IconData i, String label, String? v) => v == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Icon(i, size: 18, color: c.textMuted),
              const SizedBox(width: 12),
              Text(label, style: AppType.body(13.5, color: c.textMuted)),
              const Spacer(),
              Flexible(child: Text(v, style: AppType.body(13.5, weight: 600, color: c.text), textAlign: TextAlign.right, maxLines: 2)),
            ]),
          );
    return AppCard(
      child: Column(children: [
        row(Icons.emoji_events_outlined, 'Competition', m.league.name),
        row(Icons.calendar_today_rounded, 'Date', '${longDate(m.kickoff)} · ${kickoffTime(m.kickoff)}'),
        row(Icons.stadium_outlined, 'Venue', [m.venue, m.city].whereType<String>().join(', ').isEmpty ? null : [m.venue, m.city].whereType<String>().join(', ')),
        row(Icons.sports_rounded, 'Referee', m.referee),
        if (m.halftime.isSet) row(Icons.timelapse_rounded, 'Half-time', '${m.halftime.home}–${m.halftime.away}'),
      ]),
    );
  }
}
