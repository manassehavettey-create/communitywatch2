import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/annotations_repository.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import '../reader/reader_sheets.dart';
import 'annotation_common.dart';

class HighlightsScreen extends ConsumerStatefulWidget {
  const HighlightsScreen({super.key, this.bookId});
  final int? bookId;

  @override
  ConsumerState<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends ConsumerState<HighlightsScreen> {
  late int? _book = widget.bookId;
  int? _color;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final repo = ref.watch(annotationsRepositoryProvider);
    return AnnotationScaffold(
      title: 'Highlights',
      bookId: _book,
      onBookFilter: (id) => setState(() => _book = id),
      header: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.x1),
          children: [
            PillChip(label: 'All colours', selected: _color == null, dense: true, onTap: () => setState(() => _color = null)),
            for (final c in ShelfColor.highlightColors) ...[
              const SizedBox(width: Space.x2),
              Semantics(
                label: '${c.label} highlights',
                selected: _color == c.index,
                button: true,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _color = _color == c.index ? null : c.index),
                  child: AnimatedContainer(
                    duration: m.fast,
                    width: 36,
                    decoration: BoxDecoration(
                      color: c.strong,
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == c.index ? context.colors.ink : Colors.transparent, width: 2.5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: StreamBuilder<List<WithBook<Highlight>>>(
        stream: repo.watchAllHighlights(bookId: _book, color: _color),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          final list = snap.data!;
          if (list.isEmpty) {
            return SingleChildScrollView(
              child: EmptyState(
                art: Art.emptyHighlights,
                title: _color != null || _book != null ? 'No highlights match' : 'No highlights yet',
                message: 'While reading, select a passage and tap a colour. Your highlights from every '
                    'book collect here.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x10),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
            itemBuilder: (context, i) {
              final h = list[i].item;
              final color = ShelfColor.fromIndex(h.color);
              return BlockCard(
                padding: EdgeInsets.zero,
                radius: Radii.lg,
                onTap: () => context.push('/read/${h.bookId}?page=${h.page}'),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 8, color: color.strong),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Space.x4, Space.x4, Space.x2, Space.x4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('“${h.content}”', style: context.text.bodyLarge),
                              const SizedBox(height: Space.x3),
                              Text(
                                '${list[i].bookTitle} · p. ${h.page} · ${relativeDay(h.createdAt)}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Highlight options',
                        onPressed: () => showHighlightSheet(context, ref, h),
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: m.base, delay: m.stagger(i));
            },
          );
        },
      ),
    );
  }
}
