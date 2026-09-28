import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';

/// Soft shimmering placeholder block.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = Radii.xs});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(radius)),
    );
    if (Motion.of(context).reduced) return box;
    return box
        .animate(onPlay: (ctl) => ctl.repeat())
        .shimmer(duration: 1200.ms, color: c.surface.withValues(alpha: 0.7));
  }
}
