import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/icons.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/illustration.dart';
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/streak_badge.dart';

/// Lets the reader choose a focused session length.
Future<int?> pickSessionLength(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) {
      final b = ctx.brightness;
      const options = [15, 30, 45, 60];
      const colors = [ShelfColor.mint, ShelfColor.sky, ShelfColor.lilac, ShelfColor.peach];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Focused session', style: ctx.text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Just the page, the time left and your progress. Everything else stays out of the way.',
                style: ctx.text.bodySmall,
              ),
              const SizedBox(height: Space.x5),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: Space.x3,
                mainAxisSpacing: Space.x3,
                childAspectRatio: 1.7,
                children: [
                  for (var i = 0; i < options.length; i++)
                    Material(
                      color: colors[i].cardBackground(b),
                      borderRadius: Radii.lgAll,
                      child: InkWell(
                        borderRadius: Radii.lgAll,
                        onTap: () => Navigator.pop(ctx, options[i]),
                        child: Padding(
                          padding: const EdgeInsets.all(Space.x4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(PhosphorIconsRegular.timer, color: colors[i].cardForeground(b)),
                              Text('${options[i]} min',
                                  style: ctx.text.headlineSmall?.copyWith(color: colors[i].cardForeground(b))),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class SessionResult {
  const SessionResult({
    required this.pages,
    required this.active,
    required this.targetMinutes,
    required this.completed,
    required this.streak,
    required this.progress,
  });
  final int pages;
  final Duration active;
  final int? targetMinutes;
  final bool completed;
  final int streak;
  final double progress;
}

/// End-of-session summary with a gentle completion animation.
Future<void> showSessionSummary(BuildContext context, SessionResult r) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    builder: (ctx) {
      final m = Motion.of(ctx);
      final b = ctx.brightness;
      Widget stat(ShelfColor color, String value, String label) => Expanded(
            child: Container(
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(color: color.cardBackground(b), borderRadius: Radii.lgAll),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: ctx.text.headlineMedium?.copyWith(color: color.cardForeground(b))),
                  Text(label, style: ctx.text.bodySmall?.copyWith(color: color.cardForeground(b))),
                ],
              ),
            ),
          );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Illustration(Art.sessionComplete, width: 190, fallbackIcon: PhosphorIconsRegular.checkCircle)
                      .animate()
                      .fadeIn(duration: m.slow)
                      .scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack, duration: m.slow * 1.5),
                ],
              ),
              const SizedBox(height: Space.x5),
              Text(
                r.completed ? 'Session complete' : 'Nice reading',
                style: ctx.text.headlineMedium,
              ).animate().fadeIn(delay: m.fast, duration: m.base),
              const SizedBox(height: 4),
              Text(
                r.targetMinutes != null
                    ? '${r.targetMinutes}-minute focus session'
                    : 'Here’s what you read',
                style: ctx.text.bodySmall,
              ),
              const SizedBox(height: Space.x5),
              Row(
                children: [
                  stat(ShelfColor.butter, '${r.pages}', r.pages == 1 ? 'page read' : 'pages read'),
                  const SizedBox(width: Space.x3),
                  stat(ShelfColor.sky, formatDuration(r.active, short: true), 'reading time'),
                ],
              ).animate().fadeIn(delay: m.base, duration: m.base).moveY(begin: 8, end: 0),
              const SizedBox(height: Space.x4),
              Row(
                children: [
                  StreakBadge(days: r.streak, size: 96),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Book progress', style: ctx.text.titleSmall),
                        const SizedBox(height: Space.x2),
                        FolioProgressBar(value: r.progress),
                        const SizedBox(height: 4),
                        Text('${(r.progress * 100).round()}% read', style: ctx.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: m.slow, duration: m.base),
              const SizedBox(height: Space.x6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ),
            ],
          ),
        ),
      );
    },
  );
}
