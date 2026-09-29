import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import 'illustration.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.action,
    this.illustrationWidth = 240,
    this.fallbackIcon,
  });

  final Art art;
  final String title;
  final String message;
  final Widget? action;
  final double illustrationWidth;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Illustration(
            art,
            width: illustrationWidth,
            fallbackIcon: fallbackIcon,
          ).animate().fadeIn(duration: m.slow).scaleXY(begin: 0.96, end: 1, duration: m.slow, curve: Motion.curve),
          const SizedBox(height: Space.x6),
          Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.x2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted),
            ),
          ),
          if (action != null) ...[const SizedBox(height: Space.x5), action!],
        ],
      ),
    );
  }
}
