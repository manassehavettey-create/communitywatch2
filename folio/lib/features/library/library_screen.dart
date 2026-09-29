import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import '../book/book_actions.dart';
import 'book_tiles.dart';
import 'import_actions.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryFilter _filter = LibraryFilter.all;
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openSort() {
    final current = ref.read(settingsProvider).librarySort;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
              child: Text('Sort by', style: ctx.text.headlineSmall),
            ),
            for (final s in LibrarySort.values)
              ListTile(
                title: Text(s.label, style: ctx.text.titleSmall),
                trailing: s == current ? const Icon(PhosphorIconsRegular.check) : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).update((x) => x.copyWith(librarySort: s));
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: Space.x2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final settings = ref.watch(settingsProvider);
    final booksAsync = ref.watch(booksProvider);
    final jobs = ref.watch(importControllerProvider).where((j) => !j.isDone).toList();
    final all = booksAsync.value ?? const [];
    final books = BooksRepository.sortAndFilter(all, sort: settings.librarySort, filter: _filter, query: _search.text);
    final grid = settings.libraryLayout == LibraryLayout.grid;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitle(
                'Library',
                subtitle: all.isEmpty ? null : '${all.length} ${all.length == 1 ? 'book' : 'books'}',
                trailing: CircleIconButton(
                  icon: PhosphorIconsRegular.plus,
                  tooltip: 'Add books',
                  filled: true,
                  onPressed: () => pickAndImportBooks(context, ref),
                ),
              ),
            ),
            if (all.isNotEmpty || jobs.isNotEmpty) ...[
              SliverToBoxAdapter(child: _shortcuts(context)),
              SliverToBoxAdapter(child: _toolbar(context, settings, grid)),
              SliverToBoxAdapter(child: _filters()),
            ],
            if (booksAsync.isLoading && all.isEmpty)
              const SliverFillRemaining(child: SizedBox())
            else if (all.isEmpty && jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    art: Art.emptyLibrary,
                    title: 'No books yet',
                    message:
                        'Add PDFs from your phone. Folio keeps a private copy, makes a cover and '
                        'indexes the text so you can search it.',
                    action: FilledButton.icon(
                      onPressed: () => pickAndImportBooks(context, ref),
                      icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                      label: const Text('Add books'),
                    ),
                  ),
                ),
              )
            else if (books.isEmpty && jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  art: Art.emptySearch,
                  illustrationWidth: 180,
                  title: 'Nothing here',
                  message: _search.text.isNotEmpty
                      ? 'No books match “${_search.text}”.'
                      : 'No books are ${_filter.label.toLowerCase()} yet.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: Space.navClearance),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: m.base,
                    switchInCurve: Motion.curve,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(a), child: child),
                    ),
                    child: grid
                        ? _Grid(key: const ValueKey('grid'), books: books, jobs: jobs)
                        : _List(key: const ValueKey('list'), books: books, jobs: jobs),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shortcuts(BuildContext context) {
    final items = [
      (PhosphorIconsRegular.folderSimple, 'Collections', '/collections', ShelfColor.lilac),
      (PhosphorIconsRegular.highlighter, 'Highlights', '/highlights', ShelfColor.butter),
      (PhosphorIconsRegular.notePencil, 'Notes', '/notes', ShelfColor.peach),
      (PhosphorIconsRegular.bookmarkSimple, 'Bookmarks', '/bookmarks', ShelfColor.mint),
    ];
    final b = context.brightness;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, Space.x2),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
        itemBuilder: (context, i) {
          final (icon, label, path, color) = items[i];
          return BlockCard(
            color: color.cardBackground(b),
            radius: Radii.md,
            padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x3),
            onTap: () => context.push(path),
            child: SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 22, color: color.cardForeground(b)),
                  Text(label, style: context.text.labelLarge?.copyWith(color: color.cardForeground(b))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(BuildContext context, AppSettings settings, bool grid) {
    final m = Motion.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: m.base,
              child: _searching
                  ? TextField(
                      key: const ValueKey('search'),
                      controller: _search,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search title or author',
                        isDense: true,
                        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                        suffixIcon: IconButton(
                          tooltip: 'Close search',
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () => setState(() {
                            _search.clear();
                            _searching = false;
                          }),
                        ),
                      ),
                    )
                  : Align(
                      key: const ValueKey('sort'),
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openSort,
                        icon: const Icon(PhosphorIconsRegular.arrowsDownUp, size: 18),
                        label: Text(settings.librarySort.label),
                      ),
                    ),
            ),
          ),
          if (!_searching)
            CircleIconButton(
              icon: PhosphorIconsRegular.magnifyingGlass,
              tooltip: 'Search library',
              onPressed: () => setState(() => _searching = true),
            ),
          const SizedBox(width: Space.x2),
          CircleIconButton(
            icon: grid ? PhosphorIconsRegular.listBullets : PhosphorIconsRegular.squaresFour,
            tooltip: grid ? 'Show as list' : 'Show as grid',
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(libraryLayout: grid ? LibraryLayout.list : LibraryLayout.grid)),
          ),
        ],
      ),
    );
  }

  Widget _filters() => SizedBox(
    height: 56,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
      itemCount: LibraryFilter.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
      itemBuilder: (context, i) {
        final f = LibraryFilter.values[i];
        return PillChip(
          label: f.label,
          icon: f == LibraryFilter.favorites ? PhosphorIconsRegular.heart : null,
          selected: f == _filter,
          onTap: () => setState(() => _filter = f),
        );
      },
    ),
  );
}

class _Grid extends ConsumerWidget {
  const _Grid({super.key, required this.books, required this.jobs});
  final List books;
  final List<ImportJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = Motion.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final cols = width > 900
        ? 5
        : width > 600
        ? 4
        : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: Space.x4,
        mainAxisSpacing: Space.x6,
        childAspectRatio: 0.48,
      ),
      itemCount: jobs.length + books.length,
      itemBuilder: (context, i) {
        if (i < jobs.length) {
          return ImportingGridTile(fileName: jobs[i].fileName, stage: stageLabel(jobs[i].stage));
        }
        final b = books[i - jobs.length];
        return BookGridTile(
          book: b,
          onTap: () => context.push('/book/${b.id}'),
          onLongPress: () => showBookActionsSheet(context, ref, b),
        ).animate().fadeIn(duration: m.base, delay: m.stagger(i)).moveY(begin: 8, end: 0, curve: Motion.curve);
      },
    );
  }
}

class _List extends ConsumerWidget {
  const _List({super.key, required this.books, required this.jobs});
  final List books;
  final List<ImportJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = Motion.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.x3),
      child: Column(
        children: [
          for (final j in jobs) ImportingListTile(fileName: j.fileName, stage: stageLabel(j.stage)),
          for (var i = 0; i < books.length; i++)
            BookListTile(
              book: books[i],
              onTap: () => context.push('/book/${books[i].id}'),
              onLongPress: () => showBookActionsSheet(context, ref, books[i]),
            ).animate().fadeIn(duration: m.base, delay: m.stagger(i)),
        ],
      ),
    );
  }
}
