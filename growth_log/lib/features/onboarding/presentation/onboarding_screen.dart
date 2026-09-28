import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';

class _Page {
  const _Page({
    required this.bg,
    required this.fg,
    required this.image,
    required this.bold,
    required this.italic,
    required this.body,
    required this.arrowBg,
    required this.arrowFg,
  });

  final Color bg;
  final Color fg;
  final String image;
  final String bold;
  final String italic;
  final String body;
  final Color arrowBg;
  final Color arrowFg;
}

const _pages = [
  _Page(
    bg: Palette.lime,
    fg: Palette.ink,
    image: AppAssets.onboardingGrow,
    bold: 'Every hour',
    italic: 'counts.',
    body: 'Track the time you put into the skills you care about — one session at a time, all the way to mastery.',
    arrowBg: Palette.ink,
    arrowFg: Palette.white,
  ),
  _Page(
    bg: Palette.blush,
    fg: Palette.ink,
    image: AppAssets.onboardingGratitude,
    bold: 'Notice the',
    italic: 'good.',
    body: 'Write down one thing you are grateful for and one win each day. Tiny notes, big difference.',
    arrowBg: Palette.ink,
    arrowFg: Palette.white,
  ),
  _Page(
    bg: Palette.electric,
    fg: Palette.white,
    image: AppAssets.levelUpHero,
    bold: 'Celebrate every',
    italic: 'level.',
    body: 'Climb from Novice to Master. Milestones become wins automatically, and each month shows how far you have come.',
    arrowBg: Palette.white,
    arrowFg: Palette.ink,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _page = _controller.page ?? 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    ref.read(hapticsProvider).light();
    final i = _page.round();
    if (i >= _pages.length - 1) {
      context.go(Routes.setup);
    } else {
      _controller.nextPage(duration: Motion.slow, curve: Motion.standard);
    }
  }

  Color _lerp(Color Function(_Page) pick) {
    final i = _page.floor().clamp(0, _pages.length - 1);
    final j = (i + 1).clamp(0, _pages.length - 1);
    return Color.lerp(pick(_pages[i]), pick(_pages[j]), _page - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _lerp((p) => p.bg);
    final fg = _lerp((p) => p.fg);
    final index = _page.round();
    final last = index == _pages.length - 1;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: fg,
                      shape: BoxShape.circle,
                    ),
                    child: const AppImage(AppAssets.splashLogo),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Growth Log',
                    style: AppText.subtitle.copyWith(color: fg),
                  ),
                  const Spacer(),
                  Text(
                    '${index + 1}/${_pages.length}',
                    style: AppText.caption.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  final delta = (i - _page).clamp(-1.0, 1.0);
                  return LayoutBuilder(
                    builder: (context, c) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Transform.translate(
                              offset: Offset(delta * c.maxWidth * 0.35, 0),
                              child: Center(
                                child: AppImage(
                                  p.image,
                                  height: c.maxHeight * 0.55,
                                  semanticLabel: 'Illustration',
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            header: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${p.bold}\n',
                                    style: AppText.display.copyWith(
                                      color: p.fg,
                                      fontSize: 46,
                                    ),
                                  ),
                                  TextSpan(
                                    text: p.italic,
                                    style: AppText.displayItalic.copyWith(
                                      color: p.fg,
                                      fontSize: 46,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Text(
                            p.body,
                            style: AppText.body.copyWith(
                              color: p.fg.withValues(alpha: 0.8),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                Space.lg,
              ),
              child: Row(
                children: [
                  AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: last ? 0 : 1,
                    child: TextButton(
                      onPressed: last ? null : () => context.go(Routes.setup),
                      child: Text(
                        'Skip',
                        style: AppText.button.copyWith(color: fg),
                      ),
                    ),
                  ),
                  const Spacer(),
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: Motion.medium,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: i == index ? 1 : 0.3),
                        borderRadius: Radii.pillR,
                      ),
                    ),
                  const Spacer(),
                  ArrowCircleButton(
                    onPressed: _next,
                    color: _lerp((p) => p.arrowBg),
                    iconColor: _lerp((p) => p.arrowFg),
                    tooltip: last ? 'Get started' : 'Next',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
