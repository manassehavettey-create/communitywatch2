import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';

class _Page {
  const _Page(this.image, this.title, this.accent, this.body);
  final String image;
  final String title;
  final String accent;
  final String body;
}

const _pages = [
  _Page(
    'onboarding_read',
    'Scripture,',
    'always with you.',
    'Four complete translations on your phone. Read anywhere — no connection needed.',
  ),
  _Page(
    'onboarding_keep',
    'Keep what',
    'speaks to you.',
    'Highlight, bookmark and write notes on any verse. Find them again in seconds.',
  ),
  _Page(
    'onboarding_pray',
    'Pray and',
    'reflect.',
    'A private place for prayers and journal entries, with gentle reminders.',
  ),
  _Page(
    'onboarding_rhythm',
    'Build a gentle',
    'rhythm.',
    'Reading plans from a few days to a whole year, at your own pace.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const doneKey = 'onboarding.done';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pager = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(databaseProvider).setValue(OnboardingScreen.doneKey, '1');
    if (!mounted) return;
    final auth = ref.read(authServiceProvider);
    if (auth.available && auth.currentUser == null) {
      context.go('/auth?onboarding=1');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(Space.x2),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return AnimatedBuilder(
                    animation: _pager,
                    builder: (context, child) {
                      // Gentle parallax: the image drifts slower than the page.
                      final offset =
                          _pager.hasClients && _pager.position.haveDimensions
                          ? (_pager.page ?? 0) - i
                          : 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Transform.translate(
                              offset: Offset(m.reduced ? 0 : offset * 60, 0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.x6,
                                ),
                                child: ClipRRect(
                                  borderRadius: Radii.lgAll,
                                  child: Image.asset(
                                    'assets/images/onboarding/${page.image}.jpg',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    semanticLabel: '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.x6,
                              Space.x6,
                              Space.x6,
                              0,
                            ),
                            child: Opacity(
                              opacity: (1 - offset.abs()).clamp(0.0, 1.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    page.title,
                                    style: AppType.displayL.copyWith(
                                      color: p.ink,
                                    ),
                                  ),
                                  Text(
                                    page.accent,
                                    style: AppType.hand.copyWith(
                                      fontSize: 36,
                                      color: p.tangerineText,
                                    ),
                                  ),
                                  const SizedBox(height: Space.x3),
                                  Text(
                                    page.body,
                                    style: AppType.body.copyWith(
                                      color: p.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x6,
                Space.x6,
                Space.x6,
                Space.x6,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: m.base,
                      curve: m.standard,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? p.ink : p.line,
                        borderRadius: Radii.pillAll,
                      ),
                    ),
                  const Spacer(),
                  PillButton(
                    label: last ? 'Get started' : 'Next',
                    trailingIcon: PhosphorIconsBold.arrowRight,
                    onPressed: last
                        ? _finish
                        : () => _pager.nextPage(
                            duration: m.slow,
                            curve: m.standard,
                          ),
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
