import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../domain/commentary.dart';

/// Live commentary (spec §7). Uses provider commentary when available;
/// otherwise a feed written from confirmed events, clearly labelled.
class CommentaryTab extends ConsumerWidget {
  const CommentaryTab({super.key, required this.match});
  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final caps = ref.watch(capabilitiesProvider);
    final providerLines = caps.commentary ? ref.watch(analyticsProvider(match.id)).value?.data?.commentary : null;
    final lines = (providerLines != null && providerLines.isNotEmpty) ? providerLines.reversed.toList() : commentaryFromEvents(match);
    final generated = providerLines == null || providerLines.isEmpty;

    if (match.status.isScheduled) {
      return ListView(children: const [EmptyState(art: EmptyArt.matches, title: 'Commentary starts at kick-off', message: 'Every goal, card and substitution will appear here as it happens — no refresh needed.', compact: true)]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 48),
      itemCount: lines.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(children: [
              ProvenanceTag(generated ? Provenance.generated : Provenance.confirmed, source: generated ? 'written from confirmed events' : ref.watch(repositoryProvider).providerName, compact: true),
              const Spacer(),
              if (match.status.isLive) Row(children: [LiveDot(size: 5, color: c.live), Text('Auto-updating', style: AppType.body(12, color: c.textMuted))]),
            ]),
          );
        }
        final l = lines[i - 1];
        return _Line(key: ValueKey('${l.minute}-${l.extra}-${l.text.hashCode}'), line: l, match: match, last: i == lines.length);
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.line, required this.match, required this.last});
  final CommentaryLine line;
  final Match match;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = line;
    final isGoal = l.kind == EventKind.goal || l.kind == EventKind.penaltyGoal || l.kind == EventKind.ownGoal;
    final label = switch (l.kind) {
      EventKind.goal || EventKind.penaltyGoal => 'GOAL',
      EventKind.ownGoal => 'OWN GOAL',
      EventKind.yellow => 'Yellow card',
      EventKind.secondYellow => 'Second yellow',
      EventKind.red => 'Red card',
      EventKind.sub => 'Substitution',
      EventKind.varDecision => 'VAR',
      EventKind.missedPenalty => 'Penalty missed',
      _ => null,
    };
    final minute = l.extra != null && l.extra! >= 99 ? '' : (l.extra != null && l.extra! > 0 ? "${l.minute}+${l.extra}'" : (l.minute == 0 ? '' : "${l.minute}'"));
    final team = l.teamId == null ? null : match.teamById(l.teamId!);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 48, child: Text(minute, style: AppType.numeric(15, color: isGoal ? c.accentInk : c.text))),
        Column(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isGoal ? c.accent : c.surface2),
            alignment: Alignment.center,
            child: l.kind == null ? Icon(Icons.sports_rounded, size: 14, color: c.textMuted) : (isGoal ? Icon(Icons.sports_soccer, size: 15, color: c.onAccent) : EventIcon(kind: l.kind!, size: 15)),
          ),
          if (!last) Expanded(child: Container(width: 1.5, color: c.hairline)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (label != null)
                Row(children: [
                  Text(label, style: AppType.overline(color: isGoal ? c.accentInk : c.textMuted)),
                  if (team != null) ...[const SizedBox(width: 8), TeamCrest(team: team, size: 14), const SizedBox(width: 4), Text(team.short, style: AppType.body(11.5, color: c.textFaint))],
                ]),
              const SizedBox(height: 3),
              Text(l.text, style: AppType.body(isGoal ? 16 : 14.5, weight: isGoal ? 650 : 450, color: c.text)),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: Motion.slow).slideY(begin: -0.15, curve: Motion.emphasized);
  }
}
