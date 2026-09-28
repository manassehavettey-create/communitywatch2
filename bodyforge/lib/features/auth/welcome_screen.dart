import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth.dart';
import '../../app/config.dart';
import '../../core/assets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _busy = false;

  Future<void> _offline() async {
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).continueOffline();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final cloud = AppConfig.cloudEnabled;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: Space.md),
            Row(children: [
              const SizedBox(width: 30, height: 30, child: AppImage(Img.logoMark)),
              const SizedBox(width: Space.xs),
              Text('BODYFORGE', style: BfType.number(18, color: c.text, weight: FontWeight.w800)),
            ]).enter(context),
            const SizedBox(height: Space.lg),
            Expanded(
              child: BfCard(
                color: c.primary,
                padding: EdgeInsets.zero,
                rings: true,
                radius: Radii.cardLarge,
                child: Stack(children: [
                  Positioned(
                    left: Space.xl,
                    top: Space.xl,
                    right: Space.xl,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Overline('Free forever', color: BfPalette.ink.withValues(alpha: 0.6)),
                      const SizedBox(height: Space.xs),
                      Text('Build your body anywhere.',
                          style: t.displaySmall?.copyWith(color: BfPalette.ink, height: 1.05)),
                    ]).enter(context, index: 1),
                  ),
                  Positioned.fill(
                    top: 150,
                    child: const AppImage(Img.onboardingWelcome, alignment: Alignment.bottomCenter)
                        .animate()
                        .fadeIn(duration: Motion.of(context, Motion.slower))
                        .moveY(begin: 40, end: 0, curve: Motion.emphasized, duration: Motion.of(context, Motion.slower)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: Space.lg),
            Wrap(alignment: WrapAlignment.center, spacing: Space.xs, runSpacing: Space.xs, children: [
              for (final s in ['No gym', 'No equipment', 'No subscription'])
                PillChip(label: s, selected: false, icon: BfIcons.check, dense: true),
            ]).enter(context, index: 2),
            const SizedBox(height: Space.lg),
            if (cloud) ...[
              BfButton(label: 'Create account', onPressed: () => context.push('/auth?mode=signup'), trailingIcon: BfIcons.forward)
                  .enter(context, index: 3),
              const SizedBox(height: Space.sm),
              BfButton(label: 'Log in', kind: BfButtonKind.ghost, onPressed: () => context.push('/auth?mode=signin'))
                  .enter(context, index: 4),
              const SizedBox(height: Space.xs),
              TextButton(
                onPressed: _busy ? null : _offline,
                child: Text('Start without an account', style: t.labelMedium?.copyWith(color: c.textMuted)),
              ),
            ] else ...[
              BfButton(label: 'Get started', loading: _busy, onPressed: _offline, trailingIcon: BfIcons.forward)
                  .enter(context, index: 3),
              const SizedBox(height: Space.sm),
              Text('Everything is saved on this phone and works offline.',
                  textAlign: TextAlign.center, style: t.bodySmall),
            ],
            const SizedBox(height: Space.md),
          ]),
        ),
      ),
    );
  }
}
