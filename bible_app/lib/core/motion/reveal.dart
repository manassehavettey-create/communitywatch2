import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'motion.dart';

/// Staggered entrance: fade in, rise 16 px and settle from 98% scale.
/// Falls back to a short fade when reduce motion is on.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;

  /// Position in a staggered group; later items start later (capped).
  final int index;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final effects = m.reduced
        ? <Effect<dynamic>>[FadeEffect(duration: m.base)]
        : <Effect<dynamic>>[
            FadeEffect(duration: m.slow, curve: m.standard),
            MoveEffect(
              begin: Offset(0, m.rise),
              end: Offset.zero,
              duration: m.slow,
              curve: m.standard,
            ),
            ScaleEffect(
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              duration: m.slow,
              curve: m.standard,
            ),
          ];
    return Animate(delay: m.staggerFor(index), effects: effects, child: child);
  }
}

/// Animates a number from its previous value to [value].
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: m.slow,
      curve: m.standard,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
