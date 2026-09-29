import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/illustration.dart';

class _Page {
  const _Page(this.art, this.title, this.highlight, this.body);
  final Art art;
  final String title;
  final String highlight;
  final String body;
}

const _pages = [
  _Page(
    Art.onboardingLibrary,
    'Your PDFs, ',
    'beautifully shelved',
    'Import PDFs from your phone and Folio turns them into a calm, private library. '
        'Everything stays on this device.',
  ),
  _Page(
    Art.onboardingHighlight,
    'Highlight, note, ',
    'remember',
    'Mark passages in five colours, attach notes, bookmark pages and find any line '
        'again with instant search.',
  ),
  _Page(
    Art.onboardingHabit,
    'A little reading, ',
    'every day',
    'Set a gentle daily goal, keep a streak and try focused reading sessions. '
        'No account needed.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _name = TextEditingController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length;

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingDone: true, name: _name.text.trim()));
  }

  void _next() {
    final m = Motion.of(context);
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: m.slow == Duration.zero ? const Duration(milliseconds: 1) : m.slow,
        curve: Motion.emphasized,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.x2, 0),
              child: Row(
                children: [
                  Text('Folio', style: context.text.titleLarge),
                  const Spacer(),
                  if (!_isLast)
                    TextButton(
                      onPressed: () => _controller.animateToPage(
                        _pages.length,
                        duration: Motion.of(context).slow,
                        curve: Motion.emphasized,
                      ),
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final p in _pages) _IntroPage(page: p),
                  _NamePage(controller: _name, onSubmit: _finish),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, Space.x5),
              child: Row(
                children: [
                  for (var i = 0; i <= _pages.length; i++)
                    AnimatedContainer(
                      duration: Motion.of(context).base,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: i == _index ? c.ink : c.hairline, borderRadius: Radii.pillAll),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(PhosphorIconsRegular.arrowRight, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: Text(_isLast ? 'Start reading' : 'Next'),
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

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.page});
  final _Page page;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = Motion.of(context);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Space.x4),
            Center(child: Illustration(page.art, width: (box.maxHeight * 0.52 * 3 / 4).clamp(200.0, box.maxWidth)))
                .animate()
                .fadeIn(duration: m.slow)
                .moveY(begin: 12, end: 0, duration: m.slow, curve: Motion.curve),
            const SizedBox(height: Space.x6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: page.title),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: c.lime, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        page.highlight,
                        style: context.text.displaySmall?.copyWith(color: const Color(0xFF161514)),
                      ),
                    ),
                  ),
                ],
              ),
              style: context.text.displaySmall,
            ),
            const SizedBox(height: Space.x3),
            Text(page.body, style: context.text.bodyLarge?.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Space.x10),
          Text('What should we call you?', style: context.text.displaySmall),
          const SizedBox(height: Space.x3),
          Text(
            'Optional. It’s only used for the greeting on Home and never leaves your phone.',
            style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Space.x6),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(hintText: 'Your first name'),
          ),
          const SizedBox(height: Space.x6),
          const _PrivacyCard(),
        ],
      ),
    );
  }
}

/// Small privacy promise shown at the end of onboarding.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final fg = ShelfColor.mint.cardForeground(context.brightness);
    return Container(
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(color: ShelfColor.mint.cardBackground(context.brightness), borderRadius: Radii.lgAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIconsRegular.shieldCheck, color: fg),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              'Your books, highlights and notes are stored encrypted on this device. '
              'Folio has no account and no cloud sync.',
              style: context.text.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
