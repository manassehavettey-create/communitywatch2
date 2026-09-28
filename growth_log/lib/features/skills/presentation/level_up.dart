import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../data/milestone_repository.dart';
import '../domain/levels.dart';

/// Shows the right celebration for newly reached milestones: a full-screen
/// level-up for level thresholds, a snackbar for smaller marks.
Future<void> celebrate(BuildContext context, List<Achievement>? achievements) async {
  if (achievements == null || achievements.isEmpty || !context.mounted) return;
  final levelUps = achievements.where((a) => a.level != null).toList();
  if (levelUps.isNotEmpty) {
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.medium,
        pageBuilder: (_, _, _) => LevelUpScreen(achievement: levelUps.last),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 1.08, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Motion.standard),
            ),
            child: child,
          ),
        ),
      ),
    );
    return;
  }
  final top = achievements.last;
  showSnack(
    context,
    '🎉 ${top.hours} ${top.hours == 1 ? 'hour' : 'hours'} of ${top.skillName}! Added to your wins.',
  );
}

class LevelUpScreen extends ConsumerStatefulWidget {
  const LevelUpScreen({super.key, required this.achievement});

  final Achievement achievement;

  @override
  ConsumerState<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends ConsumerState<LevelUpScreen>
    with SingleTickerProviderStateMixin {
  late final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) _confetti.play();
      ref.read(hapticsProvider).success();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final level = a.level!;
    final size = MediaQuery.sizeOf(context);
    final headline = AppText.display.copyWith(
      color: Palette.white,
      fontSize: math.min(size.width * 0.2, 96),
      height: 0.9,
      letterSpacing: -3,
    );

    Animation<double> step(double from, double to) => CurvedAnimation(
          parent: _intro,
          curve: Interval(from, to, curve: Curves.easeOutBack),
        );

    return Scaffold(
      backgroundColor: Palette.electric,
      body: Stack(
        children: [
          // Character sits behind the giant type, like the Strut reference.
          Positioned(
            right: -size.width * 0.08,
            bottom: size.height * 0.16,
            width: size.width * 0.78,
            child: ScaleTransition(
              scale: step(0.2, 0.8),
              alignment: Alignment.bottomCenter,
              child: const AppImage(AppAssets.levelUpHero, semanticLabel: 'Celebrating'),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GROWTH LOG',
                    style: AppText.caption.copyWith(
                      color: Palette.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  FadeTransition(
                    opacity: step(0, 0.5),
                    child: Semantics(
                      header: true,
                      child: Text('LEVEL\nUP.', style: headline),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  FadeTransition(
                    opacity: step(0.3, 0.8),
                    child: SizedBox(
                      width: size.width * 0.55,
                      child: Text(
                        'You reached ${level.name.toUpperCase()} in ${a.skillName}. '
                        '${Fmt.number(a.hours)} hours of showing up.',
                        style: AppText.subtitle.copyWith(
                          color: Palette.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  ScaleTransition(
                    scale: step(0.45, 1),
                    child: AppImage(level.badgeAsset, width: 96, height: 96),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Confidence? It\'s in the hours.',
                          style: AppText.caption.copyWith(
                            color: Palette.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PillButton(
                        label: 'Keep going',
                        trailingArrow: true,
                        background: Palette.white,
                        foreground: Palette.ink,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              maxBlastForce: 28,
              minBlastForce: 10,
              gravity: 0.25,
              colors: const [
                Palette.lime,
                Palette.butter,
                Palette.blush,
                Palette.lavender,
                Palette.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge + level name, used on cards and detail screens.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 56});

  final Level level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${level.name} level',
      child: AppImage(level.badgeAsset, width: size, height: size),
    );
  }
}
