import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/collections_repository.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import 'collection_editor.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  int? _justCreated;

  Future<void> _create() async {
    final id = await createCollection(context, ref);
    if (id != null) setState(() => _justCreated = id);
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final cols = ref.watch(collectionsProvider);
    final books = {for (final b in ref.watch(booksProvider).value ?? const <Book>[]) b.id: b};
    final list = cols.value ?? const <CollectionWithBooks>[];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Space.x3),
            child: CircleIconButton(icon: PhosphorIconsRegular.plus, tooltip: 'New collection', filled: true, onPressed: _create),
          ),
        ],
      ),
      body: cols.isLoading && list.isEmpty
          ? const SizedBox()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
                    child: Text('Collections', style: context.text.displaySmall),
                  ),
                ),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      art: Art.emptyCollections,
                      title: 'No collections yet',
                      message: 'Group books however you like: a course, a project, summer reads. '
                          'A book can be in as many collections as you want.',
                      action: FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                        label: const Text('Create a collection'),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x10),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                        crossAxisSpacing: Space.x3,
                        mainAxisSpacing: Space.x3,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final cw = list[i];
                        final card = CollectionCard(
                          collection: cw.collection,
                          books: [for (final id in cw.bookIds) ?books[id]],
                          onTap: () => context.push('/collections/${cw.collection.id}'),
                        );
                        if (cw.collection.id == _justCreated) {
                          // Collection-creation animation: pops in with a soft overshoot.
                          return card
                              .animate()
                              .scaleXY(begin: 0.6, end: 1, duration: m.slow * 1.4, curve: Curves.easeOutBack)
                              .fadeIn(duration: m.base);
                        }
                        return card.animate().fadeIn(duration: m.base, delay: m.stagger(i));
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.collection, required this.books, required this.onTap});
  final Collection collection;
  final List<Book> books;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ShelfColor.fromIndex(collection.color);
    return Material(
      color: color.strong,
      borderRadius: Radii.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: books.isEmpty
                    ? ClipRRect(
                        borderRadius: Radii.mdAll,
                        child: Image.asset(
                          collectionArtPath(color),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(PhosphorIconsRegular.folderSimple, size: 40, color: Color(0x80161514)),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) {
                          final shown = books.take(3).toList();
                          final w = box.maxHeight * BookCover.aspect;
                          return Stack(
                            children: [
                              for (var i = shown.length - 1; i >= 0; i--)
                                Positioned(
                                  left: i * (box.maxWidth - w).clamp(0, double.infinity) / 2.4,
                                  top: i * 6.0,
                                  bottom: 0,
                                  child: Transform.rotate(
                                    angle: (i - 1) * 0.04,
                                    child: BookCover(book: shown[i], width: w * 0.92, hero: false),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: Space.x3),
              Text(collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.copyWith(color: const Color(0xFF161514))),
              Text('${books.length} ${books.length == 1 ? 'book' : 'books'}',
                  style: context.text.bodySmall?.copyWith(color: const Color(0xB3161514))),
            ],
          ),
        ),
      ),
    );
  }
}
