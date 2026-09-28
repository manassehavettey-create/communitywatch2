import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import '../../shared/widgets/snippet_text.dart';

/// Searches titles/authors and the full text of every book, locally.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  bool _loading = false;

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _run(String v) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      if (v.trim().isEmpty) {
        setState(() => _hits = const []);
        return;
      }
      setState(() => _loading = true);
      final hits = await ref.read(searchRepositoryProvider).searchLibrary(v);
      if (!mounted || v != _q.text) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final q = _q.text.trim();
    final titleMatches = q.isEmpty
        ? const <Book>[]
        : BooksRepository.sortAndFilter(books, sort: LibrarySort.title, filter: LibraryFilter.all, query: q);
    final grouped = <int, List<SearchHit>>{};
    for (final h in _hits) {
      grouped.putIfAbsent(h.bookId, () => []).add(h);
    }
    final indexing = books.where((b) => b.isIndexing).length;
    final scanned = books.where((b) => b.isScanned).length;

    Widget body;
    if (books.isEmpty) {
      body = const EmptyState(
        key: ValueKey('nobooks'),
        art: Art.emptySearch,
        title: 'Nothing to search yet',
        message: 'Add some PDFs and Folio will index their text here on your phone.',
      );
    } else if (q.isEmpty) {
      body = Padding(
        key: const ValueKey('hint'),
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search titles, authors and every word inside your books.', style: context.text.bodyMedium),
            const SizedBox(height: Space.x2),
            Text('Use "quotes" for an exact phrase. Search runs on this device only.', style: context.text.bodySmall),
            if (indexing > 0) ...[
              const SizedBox(height: Space.x4),
              _Notice(
                icon: PhosphorIconsRegular.hourglassMedium,
                text: '$indexing ${indexing == 1 ? 'book is' : 'books are'} still being indexed. '
                    'Results will include them as pages finish.',
              ),
            ],
            if (scanned > 0) ...[
              const SizedBox(height: Space.x3),
              _Notice(
                icon: PhosphorIconsRegular.scan,
                text: '$scanned scanned ${scanned == 1 ? 'book has' : 'books have'} no text layer, '
                    'so only their titles can be searched.',
              ),
            ],
          ],
        ),
      );
    } else if (!_loading && titleMatches.isEmpty && _hits.isEmpty) {
      body = EmptyState(
        key: const ValueKey('none'),
        art: Art.emptySearch,
        title: 'No results',
        message: 'Nothing in your library matches “$q”.',
      );
    } else {
      body = ListView(
        key: const ValueKey('results'),
        padding: const EdgeInsets.only(bottom: Space.navClearance),
        children: [
          if (titleMatches.isNotEmpty) ...[
            const SectionHeader('Books'),
            for (final b in titleMatches.take(8))
              ListTile(
                leading: BookCover(book: b, width: 36, hero: false, shadow: false),
                title: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: b.author == null ? null : Text(b.author!),
                onTap: () => context.push('/book/${b.id}'),
              ),
          ],
          if (grouped.isNotEmpty) ...[
            SectionHeader('In your books · ${_hits.length}'),
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x2),
                child: Text(entry.value.first.bookTitle, style: context.text.titleSmall),
              ),
              for (final (i, h) in entry.value.take(6).indexed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
                  child: BlockCard(
                    radius: Radii.md,
                    padding: const EdgeInsets.all(Space.x4),
                    onTap: () => context.push(
                      '/read/${h.bookId}?page=${h.page}&q=${Uri.encodeQueryComponent(q)}',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Page ${h.page}', style: context.text.labelMedium),
                        const SizedBox(height: 4),
                        SnippetText(h.snippet, style: context.text.bodyMedium),
                      ],
                    ),
                  ).animate().fadeIn(duration: m.base, delay: m.stagger(i)),
                ),
              if (entry.value.length > 6)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
                  child: Text('+ ${entry.value.length - 6} more pages. Open the book and search inside it.',
                      style: context.text.bodySmall),
                ),
            ],
          ],
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Search'),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
              child: TextField(
                controller: _q,
                onChanged: _run,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Words, phrases, titles…',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(PhosphorIconsRegular.x, size: 18),
                              onPressed: () {
                                _q.clear();
                                _run('');
                              },
                            ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: m.base,
                switchInCurve: Motion.curve,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(color: ShelfColor.sky.cardBackground(b), borderRadius: Radii.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ShelfColor.sky.cardForeground(b)),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(text, style: context.text.bodySmall?.copyWith(color: ShelfColor.sky.cardForeground(b))),
          ),
        ],
      ),
    );
  }
}
