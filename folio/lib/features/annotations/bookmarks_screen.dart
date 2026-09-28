import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/annotations_repository.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import 'annotation_common.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key, this.bookId});
  final int? bookId;

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  late int? _book = widget.bookId;

  Future<void> _rename(Bookmark b) async {
    final ctl = TextEditingController(text: b.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename bookmark'),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      await ref.read(annotationsRepositoryProvider).renameBookmark(b.id, ctl.text);
    }
    ctl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final repo = ref.watch(annotationsRepositoryProvider);
    return AnnotationScaffold(
      title: 'Bookmarks',
      bookId: _book,
      onBookFilter: (id) => setState(() => _book = id),
      body: StreamBuilder<List<WithBook<Bookmark>>>(
        stream: repo.watchAllBookmarks(bookId: _book),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          final list = snap.data!;
          if (list.isEmpty) {
            return const SingleChildScrollView(
              child: EmptyState(
                art: Art.emptyBookmarks,
                title: 'No bookmarks yet',
                message: 'Tap the bookmark at the top of the reader to save a page, or select a '
                    'passage and tap Bookmark.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x10),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
            itemBuilder: (context, i) {
              final bm = list[i].item;
              return Dismissible(
                key: ValueKey(bm.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Space.x6),
                  decoration: BoxDecoration(color: context.colors.danger, borderRadius: Radii.lgAll),
                  child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await repo.deleteBookmark(bm.id);
                  if (context.mounted) {
                    showFolioSnack(context, 'Bookmark removed', action: 'Undo', onAction: () => repo.restoreBookmark(bm));
                  }
                },
                child: BlockCard(
                  onTap: () => context.push('/read/${bm.bookId}?page=${bm.page}'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ShelfColor.mint.cardBackground(context.brightness),
                          borderRadius: Radii.smAll,
                        ),
                        alignment: Alignment.center,
                        child: Text('${bm.page}', style: context.text.titleSmall?.copyWith(
                          color: ShelfColor.mint.cardForeground(context.brightness),
                        )),
                      ),
                      const SizedBox(width: Space.x4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bm.title, style: context.text.titleMedium),
                            if (bm.previewText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(bm.previewText, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                            ],
                            const SizedBox(height: Space.x2),
                            Text('${list[i].bookTitle} · ${relativeDay(bm.createdAt)}', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rename',
                        onPressed: () => _rename(bm),
                        icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20),
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
