import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/services/indexing_service.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/progress.dart';
import '../collections/collection_editor.dart';
import '../reader/session_picker.dart';
import 'book_actions.dart';

final outlineProvider = FutureProvider.autoDispose.family<List<OutlineEntry>, int>((ref, id) {
  // Re-read when indexing progresses (outline is saved at the start).
  ref.watch(bookProvider(id).select((b) => b.value?.indexStatus));
  return ref.watch(databaseProvider).outlineFor(id);
});

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});
  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final book = bookAsync.value;
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: bookAsync.isLoading
            ? const SizedBox()
            : Center(child: Text('This book is no longer in your library.', style: context.text.bodyMedium)),
      );
    }
    return _Details(book: book);
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final m = Motion.of(context);
    final b = context.brightness;
    final counts = ref.watch(bookCountsProvider(book.id)).value;
    final pos = ref.watch(positionProvider(book.id)).value;
    final outline = ref.watch(outlineProvider(book.id)).value ?? const [];
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final memberOf = ref.watch(bookCollectionIdsProvider(book.id)).value ?? const <int>{};
    final currentPage = pos?.page ?? 1;
    final started = pos != null || book.furthestPage > 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: book.favorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(book.favorite ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                color: book.favorite ? ShelfColor.rose.strong : null),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(booksRepositoryProvider).setFavorite(book.id, !book.favorite);
            },
          ).animate(target: book.favorite ? 1 : 0).scaleXY(begin: 1, end: 1.12, duration: m.fast),
          IconButton(
            tooltip: 'More',
            icon: const Icon(PhosphorIconsRegular.dotsThree),
            onPressed: () => showBookActionsSheet(context, ref, book),
          ),
          const SizedBox(width: Space.x2),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x10),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BookCover(book: book, width: 132),
              const SizedBox(width: Space.x5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(book: book),
                    const SizedBox(height: Space.x3),
                    Text(book.title, style: context.text.headlineMedium),
                    if (book.author != null) ...[
                      const SizedBox(height: 4),
                      Text(book.author!, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x5),
          Row(
            children: [
              Text('${book.progressPercent}%', style: context.text.titleLarge),
              const SizedBox(width: Space.x3),
              Expanded(child: FolioProgressBar(value: book.progress)),
            ],
          ),
          const SizedBox(height: Space.x2),
          Wrap(
            spacing: Space.x4,
            runSpacing: 4,
            children: [
              _Meta(PhosphorIconsRegular.bookOpen, '${book.pageCount} pages'),
              if (started) _Meta(PhosphorIconsRegular.bookmarkSimple, 'On page $currentPage'),
              _Meta(
                PhosphorIconsRegular.clock,
                book.lastOpenedAt == null ? 'Never opened' : 'Opened ${relativeDay(book.lastOpenedAt!).toLowerCase()}',
              ),
              _Meta(PhosphorIconsRegular.hardDrives, formatBytes(book.fileSize)),
            ],
          ),
          const SizedBox(height: Space.x5),
          FilledButton.icon(
            onPressed: () => context.push('/read/${book.id}'),
            icon: const Icon(PhosphorIconsFill.play, size: 18),
            label: Text(started ? 'Continue reading' : 'Start reading'),
          ),
          const SizedBox(height: Space.x3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/read/${book.id}?start=1'),
                  icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise, size: 18),
                  label: const Text('From beginning'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(child: _BookmarkButton(book: book, page: currentPage)),
            ],
          ),
          const SizedBox(height: Space.x3),
          OutlinedButton.icon(
            onPressed: () async {
              final minutes = await pickSessionLength(context);
              if (minutes != null && context.mounted) context.push('/read/${book.id}?focus=$minutes');
            },
            icon: const Icon(PhosphorIconsRegular.timer, size: 18),
            label: const Text('Start a focused session'),
          ),
          const SizedBox(height: Space.x5),
          _IndexStatus(book: book),
          // Annotation counts.
          Row(
            children: [
              _CountTile(
                color: ShelfColor.butter,
                icon: PhosphorIconsRegular.highlighter,
                count: counts?.highlights ?? 0,
                label: 'Highlights',
                onTap: () => context.push('/highlights?book=${book.id}'),
              ),
              const SizedBox(width: Space.x3),
              _CountTile(
                color: ShelfColor.peach,
                icon: PhosphorIconsRegular.notePencil,
                count: counts?.notes ?? 0,
                label: 'Notes',
                onTap: () => context.push('/notes?book=${book.id}'),
              ),
              const SizedBox(width: Space.x3),
              _CountTile(
                color: ShelfColor.mint,
                icon: PhosphorIconsRegular.bookmarkSimple,
                count: counts?.bookmarks ?? 0,
                label: 'Bookmarks',
                onTap: () => context.push('/bookmarks?book=${book.id}'),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          BlockCard(
            color: ShelfColor.lilac.cardBackground(b),
            onTap: () => context.push('/ask/${book.id}'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Color(0xFF161514), shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsRegular.sparkle, color: Color(0xFFD6F26B), size: 22),
                ),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask this book',
                          style: context.text.titleMedium?.copyWith(color: ShelfColor.lilac.cardForeground(b))),
                      Text(
                        'Questions, chapter summaries and explanations, grounded in its pages.',
                        style: context.text.bodySmall?.copyWith(color: ShelfColor.lilac.cardForeground(b).withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight, color: ShelfColor.lilac.cardForeground(b)),
              ],
            ),
          ),
          if (collections.isNotEmpty || memberOf.isEmpty) ...[
            const SizedBox(height: Space.x5),
            Text('Collections', style: context.text.titleMedium),
            const SizedBox(height: Space.x2),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final cw in collections.where((cw) => memberOf.contains(cw.collection.id)))
                  ActionChip(
                    avatar: CircleAvatar(backgroundColor: ShelfColor.fromIndex(cw.collection.color).strong, radius: 6),
                    label: Text(cw.collection.name),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: c.hairline),
                    backgroundColor: c.surface,
                    onPressed: () => context.push('/collections/${cw.collection.id}'),
                  ),
                ActionChip(
                  avatar: const Icon(PhosphorIconsRegular.plus, size: 16),
                  label: Text(memberOf.isEmpty ? 'Add to a collection' : 'Edit'),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: c.hairline),
                  backgroundColor: c.surface,
                  onPressed: () => showCollectionsPicker(context, ref, book.id),
                ),
              ],
            ),
          ],
          if (outline.isNotEmpty) ...[
            const SizedBox(height: Space.x6),
            Text('Contents', style: context.text.titleMedium),
            const SizedBox(height: Space.x2),
            for (final o in outline.take(60))
              InkWell(
                onTap: () => context.push('/read/${book.id}?page=${o.page}'),
                borderRadius: Radii.smAll,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(o.level * 16.0, 10, 0, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(o.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: o.level == 0 ? context.text.titleSmall : context.text.bodyMedium),
                      ),
                      Text('${o.page}', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (book.status) {
      BookStatus.unread => ('Not started', ShelfColor.sky),
      BookStatus.reading => ('Reading', ShelfColor.lime),
      BookStatus.finished => ('Finished', ShelfColor.mint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.strong, borderRadius: Radii.pillAll),
      child: Text(label, style: context.text.labelMedium?.copyWith(color: const Color(0xFF161514))),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.inkMuted),
          const SizedBox(width: 4),
          Text(text, style: context.text.bodySmall),
        ],
      );
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.color,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });
  final ShelfColor color;
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final fg = color.cardForeground(b);
    return Expanded(
      child: BlockCard(
        color: color.cardBackground(b),
        radius: Radii.md,
        padding: const EdgeInsets.all(Space.x3),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(height: Space.x3),
            CountUp(count, style: context.text.headlineSmall?.copyWith(color: fg)),
            Text(label, style: context.text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends ConsumerStatefulWidget {
  const _BookmarkButton({required this.book, required this.page});
  final Book book;
  final int page;

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  bool? _marked;

  @override
  void didUpdateWidget(covariant _BookmarkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) _marked = null;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(annotationsRepositoryProvider);
    if (_marked == null) {
      repo.pageBookmark(widget.book.id, widget.page).then((b) {
        if (mounted) setState(() => _marked = b != null);
      });
    }
    final marked = _marked ?? false;
    return OutlinedButton.icon(
      onPressed: () async {
        HapticFeedback.lightImpact();
        final text = await ref.read(searchRepositoryProvider).pageText(widget.book.id, widget.page);
        final now = await repo.togglePageBookmark(
          bookId: widget.book.id,
          page: widget.page,
          previewText: _preview(text),
        );
        setState(() => _marked = now);
        if (context.mounted) {
          showFolioSnack(context, now ? 'Bookmarked page ${widget.page}' : 'Bookmark removed');
        }
      },
      icon: Icon(marked ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple, size: 18)
          .animate(target: marked ? 1 : 0)
          .moveY(begin: 0, end: 2, duration: Motion.of(context).fast)
          .then()
          .moveY(begin: 2, end: 0),
      label: Text(marked ? 'Bookmarked' : 'Bookmark'),
    );
  }
}

String _preview(String? text) {
  final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > 160 ? '${t.substring(0, 160)}…' : t;
}

class _IndexStatus extends ConsumerWidget {
  const _IndexStatus({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.brightness;
    Widget card(ShelfColor color, IconData icon, String title, String body, {Widget? trailing, Widget? extra}) {
      final fg = color.cardForeground(b);
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.x3),
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(color: color.cardBackground(b), borderRadius: Radii.lgAll),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleSmall?.copyWith(color: fg)),
                        const SizedBox(height: 2),
                        Text(body, style: context.text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              ?extra,
            ],
          ),
        ),
      );
    }

    switch (book.indexStatus) {
      case IndexStatus.pending:
      case IndexStatus.indexing:
        return card(
          ShelfColor.sky,
          PhosphorIconsRegular.magnifyingGlass,
          'Preparing search',
          'Reading the text of each page so you can search it. '
              '${book.indexedPages} of ${book.pageCount} pages done.',
          extra: Padding(
            padding: const EdgeInsets.only(top: Space.x3),
            child: FolioProgressBar(
              value: book.pageCount == 0 ? 0 : book.indexedPages / book.pageCount,
              height: 6,
              color: const Color(0xFF161514),
              track: const Color(0x22161514),
            ),
          ),
        );
      case IndexStatus.noText:
        return card(
          ShelfColor.peach,
          PhosphorIconsRegular.scan,
          'This looks like a scanned PDF',
          'Its pages are images without a text layer, so search, Text view, highlights and '
              'Ask This Book aren’t available. You can still read, bookmark and add page notes.',
        );
      case IndexStatus.failed:
        return card(
          ShelfColor.rose,
          PhosphorIconsRegular.warningCircle,
          'Search isn’t ready',
          'Folio couldn’t finish reading this PDF’s text.',
          trailing: TextButton(
            onPressed: () => ref.read(indexingServiceProvider).reindex(book.id),
            child: const Text('Retry'),
          ),
        );
      case IndexStatus.done:
        return const SizedBox.shrink();
    }
  }
}
