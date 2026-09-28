import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/layout.dart';
import '../reader/reader_screen.dart';
import '../reader/reader_sheets.dart';

/// Bible tab: continue reading, then browse by testament → book → chapter.
class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prefs = ref.watch(prefsValueProvider);
    final translation = ref.watch(currentTranslationProvider).value;
    final last = prefs.lastChapter;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'The Bible',
                subtitle: translation?.name,
                actions: [
                  Semantics(
                    button: true,
                    label: 'Change translation',
                    child: Pressable(
                      onTap: () => showAppSheet(
                        context,
                        builder: (_) => const TranslationSheet(),
                      ),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.paperDeep,
                          borderRadius: Radii.pillAll,
                        ),
                        child: Text(
                          translation?.abbreviation ?? '…',
                          style: AppType.label.copyWith(color: p.ink),
                        ),
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    tooltip: 'Search',
                    onPressed: () => context.push('/search'),
                  ),
                ],
              ),
            ),
            if (last != null)
              SliverToBoxAdapter(
                child: Reveal(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      0,
                      Space.gutter,
                      Space.x5,
                    ),
                    child: PastelCard(
                      color: p.coral,
                      semanticLabel: 'Continue reading ${last.label}',
                      onTap: () => context.push(
                        ReaderArgs.location(
                          VerseRef(
                            last.bookId,
                            last.chapter,
                            prefs.lastVerse ?? 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Continue reading',
                                  style: AppType.label.copyWith(
                                    color: p.onPastel,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  last.label,
                                  style: AppType.displayS.copyWith(
                                    color: p.onPastel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(PhosphorIconsBold.arrowRight),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Reveal(
                index: 1,
                child: ChapterPicker(
                  scrollable: false,
                  current: last,
                  onPicked: (c) => context.push(
                    ReaderArgs.location(VerseRef(c.bookId, c.chapter, 1)),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: Space.tabBarClearance),
            ),
          ],
        ),
      ),
    );
  }
}
