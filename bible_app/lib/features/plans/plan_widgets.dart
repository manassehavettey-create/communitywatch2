import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/icons.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/sticker.dart';
import '../../domain/plans.dart';

Color planColor(PlanCategory c, AppPalette p) => switch (c) {
  PlanCategory.whole => p.butter,
  PlanCategory.testament => p.coral,
  PlanCategory.gospels => p.sky,
  PlanCategory.wisdom => p.sage,
  PlanCategory.beginner => p.blush,
  PlanCategory.short => p.cream,
};

String durationLabel(int days) {
  if (days % 365 == 0) return days == 365 ? '1 year' : '${days ~/ 365} years';
  if (days >= 60 && days % 30 == 0) return '${days ~/ 30} months';
  return '$days ${days == 1 ? 'day' : 'days'}';
}

/// Full-screen moment shown when a plan is finished.
Future<void> showPlanComplete(BuildContext context, String title) {
  Haptics.success();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: Motion.of(context).slow,
    pageBuilder: (context, _, _) => _PlanComplete(title: title),
    transitionBuilder: (context, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class _PlanComplete extends StatelessWidget {
  const _PlanComplete({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final shapes = [p.coral, p.butter, p.sage, p.sky, p.blush, p.tangerine];
    final rnd = math.Random(7);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pastel shapes burst outward (skipped when motion is reduced).
          if (!m.reduced)
            for (var i = 0; i < 18; i++)
              Builder(
                builder: (context) {
                  final angle = i / 18 * 2 * math.pi + rnd.nextDouble() * 0.3;
                  final dist = 130 + rnd.nextDouble() * 90;
                  final size = 14 + rnd.nextDouble() * 16;
                  final shape = i % 3 == 0
                      ? const ScallopBorder(lobes: 8, depth: 0.14)
                      : i % 3 == 1
                      ? BlobBorder(seed: i)
                      : const CircleBorder();
                  return Container(
                        width: size,
                        height: size,
                        decoration: ShapeDecoration(
                          color: shapes[i % shapes.length],
                          shape: shape,
                        ),
                      )
                      .animate()
                      .move(
                        begin: Offset.zero,
                        end: Offset(
                          math.cos(angle) * dist,
                          math.sin(angle) * dist,
                        ),
                        duration: 900.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .scale(
                        begin: const Offset(0.2, 0.2),
                        end: const Offset(1, 1),
                        duration: 500.ms,
                      )
                      .then(delay: 300.ms)
                      .fadeOut(duration: 500.ms);
                },
              ),
          Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: Radii.lgAll,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Sticker(
                      color: p.tangerine,
                      size: 104,
                      child: const Icon(
                        PhosphorIconsBold.check,
                        size: 44,
                        color: Color(0xFF141414),
                      ),
                    )
                    .animate()
                    .scale(
                      begin: m.reduced
                          ? const Offset(1, 1)
                          : const Offset(0.4, 0.4),
                      duration: m.celebrate,
                      curve: m.reduced ? Curves.linear : Curves.elasticOut,
                    )
                    .rotate(
                      begin: m.reduced ? 0 : -0.15,
                      end: 0,
                      duration: m.celebrate,
                    ),
                const SizedBox(height: Space.x6),
                Text(
                  'Plan complete',
                  style: AppType.displayM.copyWith(color: p.ink),
                ),
                const SizedBox(height: Space.x2),
                Text(
                  'You finished $title. Well done.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: p.inkSoft),
                ),
                const SizedBox(height: Space.x6),
                PillButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
