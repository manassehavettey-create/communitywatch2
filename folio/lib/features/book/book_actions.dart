import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../collections/collection_editor.dart';
import '../../shared/widgets/controls.dart';

/// Quick actions for a book (long-press in Library, "More" in details).
Future<void> showBookActionsSheet(BuildContext context, WidgetRef ref, Book book) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      Widget item(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
        final c = ctx.colors;
        return ListTile(
          leading: Icon(icon, color: danger ? c.danger : c.ink),
          title: Text(label, style: ctx.text.titleSmall?.copyWith(color: danger ? c.danger : null)),
          onTap: () {
            Navigator.pop(ctx);
            onTap();
          },
        );
      }

      final repo = ref.read(booksRepositoryProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
              child: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.text.titleLarge),
            ),
            item(
              book.favorite ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
              book.favorite ? 'Remove from favorites' : 'Add to favorites',
              () => repo.setFavorite(book.id, !book.favorite),
            ),
            item(PhosphorIconsRegular.folderSimple, 'Add to collection',
                () => showCollectionsPicker(context, ref, book.id)),
            item(PhosphorIconsRegular.pencilSimple, 'Edit title and author',
                () => editBookInfo(context, ref, book)),
            if (book.status != BookStatus.finished)
              item(PhosphorIconsRegular.checkCircle, 'Mark as finished',
                  () => repo.setStatus(book.id, BookStatus.finished))
            else
              item(PhosphorIconsRegular.arrowCounterClockwise, 'Mark as unread',
                  () => repo.setStatus(book.id, BookStatus.unread)),
            item(PhosphorIconsRegular.trash, 'Remove from library', () => deleteBookFlow(context, ref, book),
                danger: true),
            const SizedBox(height: Space.x2),
          ],
        ),
      );
    },
  );
}

Future<void> editBookInfo(BuildContext context, WidgetRef ref, Book book) async {
  final title = TextEditingController(text: book.title);
  final author = TextEditingController(text: book.author ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit book info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Title'),
          ),
          const SizedBox(height: Space.x3),
          TextField(
            controller: author,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Author (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true && title.text.trim().isNotEmpty) {
    await ref.read(booksRepositoryProvider).rename(book.id, title: title.text, author: author.text);
  }
  title.dispose();
  author.dispose();
}

/// Always asks, and states exactly what is (and isn't) deleted.
Future<bool> deleteBookFlow(BuildContext context, WidgetRef ref, Book book) async {
  final counts = await ref.read(booksRepositoryProvider).watchCounts(book.id).first;
  if (!context.mounted) return false;
  final parts = [
    if (counts.highlights > 0) plural(counts.highlights, 'highlight'),
    if (counts.notes > 0) plural(counts.notes, 'note'),
    if (counts.bookmarks > 0) plural(counts.bookmarks, 'bookmark'),
  ];
  final attached = parts.isEmpty ? '' : ', along with its ${parts.join(', ')}';
  final c = context.colors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Remove “${book.title}”?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Folio will delete its own copy of this PDF (${formatBytes(book.fileSize)})$attached.',
            style: ctx.text.bodyMedium,
          ),
          const SizedBox(height: Space.x3),
          Container(
            padding: const EdgeInsets.all(Space.x3),
            decoration: BoxDecoration(color: ShelfColor.mint.cardBackground(ctx.brightness), borderRadius: Radii.mdAll),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIconsRegular.shieldCheck, size: 20, color: ShelfColor.mint.cardForeground(ctx.brightness)),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    'Your original file “${book.originalFileName}” is not deleted. '
                    'Folio only removes files it created inside the app.',
                    style: ctx.text.bodySmall?.copyWith(color: ShelfColor.mint.cardForeground(ctx.brightness)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x2),
          Text('Your reading history and streak are kept.', style: ctx.text.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove from library'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final removed = await ref.read(booksRepositoryProvider).deleteBook(book.id);
  if (removed != null) {
    await ref.read(libraryStorageProvider).deleteFiles(filePath: removed.filePath, coverPath: removed.coverPath);
  }
  if (context.mounted) {
    showFolioSnack(context, 'Removed “${book.title}” from your library');
    if (GoRouterState.of(context).matchedLocation.startsWith('/book/')) context.pop();
  }
  return true;
}
