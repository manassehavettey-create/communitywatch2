import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/controls.dart';
import '../library/book_tiles.dart';
import 'collection_editor.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});
  final int collectionId;

  Future<void> _addBooks(BuildContext context, WidgetRef ref, List<Book> all, Set<int> inside) async {
    final candidates = all.where((b) => !inside.contains(b.id)).toList();
    if (candidates.isEmpty) {
      showFolioSnack(context, 'Every book is already in this collection');
      return;
    }
    final picked = <int>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
                  child: Row(
                    children: [
                      Expanded(child: Text('Add books', style: ctx.text.headlineSmall)),
                      FilledButton(
                        onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, true),
                        child: Text(picked.isEmpty ? 'Add' : 'Add ${picked.length}'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in candidates)
                        CheckboxListTile(
                          value: picked.contains(b.id),
                          activeColor: ctx.colors.ink,
                          checkColor: ctx.colors.onInk,
                          secondary: BookCover(book: b, width: 36, hero: false, shadow: false),
                          title: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ctx.text.titleSmall),
                          subtitle: b.author == null ? null : Text(b.author!),
                          onChanged: (v) => setState(() => v == true ? picked.add(b.id) : picked.remove(b.id)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      final repo = ref.read(collectionsRepositoryProvider);
      for (final id in picked) {
        await repo.addBook(collectionId, id);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = ref.watch(collectionsProvider).value;
    final all = ref.watch(booksProvider).value ?? const <Book>[];
    final cw = cols?.where((c) => c.collection.id == collectionId).firstOrNull;
    if (cw == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox());
    }
    final byId = {for (final b in all) b.id: b};
    final books = [for (final id in cw.bookIds) ?byId[id]];
    final color = ShelfColor.fromIndex(cw.collection.color);
    final repo = ref.read(collectionsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color.strong,
        foregroundColor: const Color(0xFF161514),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit collection',
            icon: const Icon(PhosphorIconsRegular.pencilSimple),
            onPressed: () => renameCollection(context, ref, id: collectionId, name: cw.collection.name, color: color),
          ),
          IconButton(
            tooltip: 'Delete collection',
            icon: const Icon(PhosphorIconsRegular.trash),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete “${cw.collection.name}”?',
                message: 'The collection is removed. The books stay in your library.',
                confirmLabel: 'Delete collection',
                destructive: true,
              );
              if (ok) {
                await repo.delete(collectionId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x10),
        children: [
          Container(
            color: color.strong,
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cw.collection.name, style: context.text.displaySmall?.copyWith(color: const Color(0xFF161514))),
                const SizedBox(height: 4),
                Text('${books.length} ${books.length == 1 ? 'book' : 'books'}',
                    style: context.text.bodyMedium?.copyWith(color: const Color(0xB3161514))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x2),
            child: OutlinedButton.icon(
              onPressed: () => _addBooks(context, ref, all, cw.bookIds.toSet()),
              icon: const Icon(PhosphorIconsRegular.plus, size: 18),
              label: const Text('Add books'),
            ),
          ),
          if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Space.x8),
              child: Text(
                'This collection is empty. Add books here, or from a book’s page.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted),
              ),
            ),
          for (final b in books)
            Dismissible(
              key: ValueKey(b.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: Space.x6),
                color: context.colors.surfaceMuted,
                child: Text('Remove', style: context.text.labelLarge),
              ),
              onDismissed: (_) async {
                await repo.removeBook(collectionId, b.id);
                if (context.mounted) {
                  showFolioSnack(context, 'Removed from ${cw.collection.name}',
                      action: 'Undo', onAction: () => repo.addBook(collectionId, b.id));
                }
              },
              child: BookListTile(book: b, onTap: () => context.push('/book/${b.id}')),
            ),
        ],
      ),
    );
  }
}
