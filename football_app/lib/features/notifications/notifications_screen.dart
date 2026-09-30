import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'live_watcher.dart';

/// Alert inbox: everything Touchline notified you about, newest first.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final log = ref.watch(alertLogProvider);
    final byDay = groupBy(log, (LoggedAlert a) => dayLabel(a.at));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(icon: const Icon(Icons.tune_rounded), tooltip: 'Alert settings', onPressed: () => context.push('/settings/notifications')),
          if (log.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Clear', onPressed: () => ref.read(alertLogProvider.notifier).clear()),
        ],
      ),
      body: log.isEmpty
          ? ListView(children: [
              EmptyState(
                art: EmptyArt.favorites,
                title: 'No alerts yet',
                message: 'Follow teams, players or competitions and we\'ll tell you about goals, cards, lineups and results.',
                actionLabel: 'Alert settings',
                onAction: () => context.push('/settings/notifications'),
              ),
            ])
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 40),
              children: [
                for (final day in byDay.keys) ...[
                  Padding(padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm), child: Overline(day)),
                  for (final (i, a) in byDay[day]!.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        onTap: a.route == null ? null : () => context.push(a.route!),
                        padding: const EdgeInsets.all(14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: a.title.startsWith('GOAL') || a.title.startsWith('⚽') ? c.accent : c.surface2),
                            child: Icon(a.title.startsWith('GOAL') || a.title.startsWith('⚽') ? Icons.sports_soccer : Icons.notifications_rounded, size: 18, color: a.title.startsWith('GOAL') || a.title.startsWith('⚽') ? c.onAccent : c.text),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.title, style: context.text.titleSmall),
                              const SizedBox(height: 2),
                              Text(a.body, style: AppType.body(13, color: c.textMuted)),
                            ]),
                          ),
                          Text(kickoffTime(a.at), style: AppType.body(12, color: c.textFaint)),
                        ]),
                      ),
                    ).animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideX(begin: 0.05),
                ],
              ],
            ),
    );
  }
}
