import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/motion_widgets.dart';

/// Animated splash: the mark drops in with a lime ring drawing around it,
/// the wordmark letters stagger up, then the tagline fades in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final ms = Motion.reduced(context) ? 300 : 1700;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted) ref.read(splashDoneProvider.notifier).done();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    const word = 'BODYFORGE';
    return Scaffold(
      backgroundColor: BfPalette.canvasDark,
      body: Stack(children: [
        const Positioned.fill(child: ConcentricRings(color: Color(0x0FFFFFFF), alignment: Alignment(0, -0.1), rings: 9, animate: true)),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RingProgress(
              progress: 1,
              size: 150,
              stroke: 6,
              color: c.primary,
              track: Colors.white.withValues(alpha: 0.06),
              duration: const Duration(milliseconds: 1100),
              child: const SizedBox(width: 84, height: 84, child: AppImage(Img.logoMark, alignment: Alignment.center)),
            ).pop(context),
            const SizedBox(height: Space.xl),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < word.length; i++)
                Text(word[i], style: BfType.number(34, color: Colors.white, weight: FontWeight.w800))
                    .animate(delay: (350 + i * 45).ms)
                    .fadeIn(duration: Motion.of(context, Motion.medium))
                    .moveY(begin: 14, end: 0, curve: Motion.emphasized, duration: Motion.of(context, Motion.slow)),
            ]),
            const SizedBox(height: Space.sm),
            Text('Build your body anywhere.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.7)))
                .animate(delay: 900.ms)
                .fadeIn(duration: Motion.of(context, Motion.slow)),
          ]),
        ),
      ]),
    );
  }
}
