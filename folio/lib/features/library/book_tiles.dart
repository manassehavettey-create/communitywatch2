import 'package:flutter/material.dart';

import '../../core/theme/icons.dart';

import '../../core/db/database.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/books_repository.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/progress.dart';
import '../../shared/widgets/skeleton.dart';

String bookSubtitle(Book b) {
  if (b.status == BookStatus.finished) return 'Finished';
  if (b.status == BookStatus.unread) return '${b.pageCount} pages · Not started';
  return 'p. ${b.furthestPage} of ${b.pageCount} · ${b.progressPercent}%';
}

class BookGridTile extends StatelessWidget {
  const BookGridTile({super.key, required this.book, required this.onTap, this.onLongPress});
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '${book.title}${book.author != null ? ' by ${book.author}' : ''}, ${bookSubtitle(book)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, box) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  BookCover(book: book, width: box.maxWidth),
                  if (book.favorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(icon: PhosphorIconsFill.heart, color: ShelfColor.rose.strong),
                    ),
                  if (book.isIndexing) const Positioned(left: 8, bottom: 8, child: _IndexingBadge()),
                ],
              ),
              const SizedBox(height: Space.x2),
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              if (book.author != null)
                Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              const SizedBox(height: 6),
              if (book.status == BookStatus.reading)
                FolioProgressBar(value: book.progress, height: 5)
              else
                Text(
                  book.status == BookStatus.finished ? 'Finished' : 'New',
                  style: context.text.labelSmall?.copyWith(color: c.inkMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.book, required this.onTap, this.onLongPress});
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: Radii.lgAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.x2),
        child: Row(
          children: [
            BookCover(book: book, width: 56),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                      if (book.favorite)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(PhosphorIconsFill.heart, size: 16, color: ShelfColor.rose.strong),
                        ),
                    ],
                  ),
                  if (book.author != null)
                    Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  const SizedBox(height: Space.x2),
                  Row(
                    children: [
                      Expanded(
                        child: book.status == BookStatus.reading
                            ? FolioProgressBar(value: book.progress, height: 5)
                            : Text(bookSubtitle(book), style: context.text.labelSmall?.copyWith(color: c.inkMuted)),
                      ),
                      if (book.status == BookStatus.reading) ...[
                        const SizedBox(width: Space.x3),
                        Text('${book.progressPercent}%', style: context.text.labelMedium),
                      ],
                    ],
                  ),
                  if (book.lastOpenedAt != null) ...[
                    const SizedBox(height: 4),
                    Text('Opened ${relativeDay(book.lastOpenedAt!).toLowerCase()}', style: context.text.bodySmall),
                  ],
                  if (book.isIndexing) ...[const SizedBox(height: 4), const _IndexingBadge()],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(color: Color(0xF2FFFDF8), shape: BoxShape.circle),
    child: Icon(icon, size: 14, color: color),
  );
}

class _IndexingBadge extends StatelessWidget {
  const _IndexingBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xF2161514), borderRadius: Radii.pillAll),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: Color(0xFFD6F26B)),
        ),
        const SizedBox(width: 6),
        Text('Indexing', style: context.text.labelSmall?.copyWith(color: const Color(0xFFF6F1E7))),
      ],
    ),
  );
}

/// Placeholder shown while a PDF is being imported.
class ImportingGridTile extends StatelessWidget {
  const ImportingGridTile({super.key, required this.fileName, this.stage});
  final String fileName;
  final String? stage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: box.maxWidth, height: box.maxWidth / BookCover.aspect, radius: Radii.sm),
          const SizedBox(height: Space.x2),
          Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
          Text(stage ?? 'Waiting…', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class ImportingListTile extends StatelessWidget {
  const ImportingListTile({super.key, required this.fileName, this.stage});
  final String fileName;
  final String? stage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.x2),
    child: Row(
      children: [
        const Skeleton(width: 56, height: 84, radius: Radii.sm),
        const SizedBox(width: Space.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              const SizedBox(height: 6),
              const Skeleton(width: 140, height: 10),
              const SizedBox(height: 6),
              Text(stage ?? 'Waiting…', style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

String stageLabel(Object? stage) => switch (stage.toString().split('.').last) {
  'checking' => 'Checking for duplicates…',
  'copying' => 'Copying into Folio…',
  'reading' => 'Reading pages…',
  'cover' => 'Making the cover…',
  'done' => 'Added',
  _ => 'Waiting…',
};

LibraryFilter parseFilter(String? s) =>
    LibraryFilter.values.firstWhere((f) => f.name == s, orElse: () => LibraryFilter.all);
