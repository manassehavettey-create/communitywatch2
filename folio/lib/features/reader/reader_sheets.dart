import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/reader_themes.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import '../annotations/note_editor.dart';
import '../book/book_details_screen.dart' show outlineProvider;
import '../../shared/widgets/snippet_text.dart';

// ------------------------------------------------------------------ appearance

Future<void> showAppearanceSheet(BuildContext context, {required bool textAvailable, VoidCallback? onResetZoom}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AppearanceSheet(textAvailable: textAvailable, onResetZoom: onResetZoom),
  );
}

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet({required this.textAvailable, this.onResetZoom});
  final bool textAvailable;
  final VoidCallback? onResetZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final c = context.colors;
    final isText = s.viewMode == ReaderViewMode.text;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: Space.x5, bottom: Space.x2),
          child: Text(t.toUpperCase(), style: context.text.labelSmall),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reading appearance', style: context.text.headlineSmall),
            label('Page theme'),
            Row(
              children: [
                for (final t in ReaderTheme.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: Space.x2),
                      child: _ThemeSwatch(
                        theme: t,
                        selected: !s.followSystemForReader && s.readerTheme == t,
                        onTap: () => n.update((x) => x.copyWith(readerTheme: t, followSystemForReader: false)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.x2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Match app theme', style: context.text.titleSmall),
              subtitle: Text('Night pages when the app is in dark mode', style: context.text.bodySmall),
              value: s.followSystemForReader,
              onChanged: (v) => n.update((x) => x.copyWith(followSystemForReader: v)),
            ),
            label('View'),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final m in ReaderViewMode.values)
                  PillChip(
                    label: m.label,
                    icon: switch (m) {
                      ReaderViewMode.scroll => PhosphorIconsRegular.rows,
                      ReaderViewMode.page => PhosphorIconsRegular.bookOpen,
                      ReaderViewMode.text => PhosphorIconsRegular.textAa,
                    },
                    selected: s.viewMode == m,
                    onTap: () {
                      if (m == ReaderViewMode.text && !textAvailable) {
                        showFolioSnack(context, 'Text view needs a PDF with a text layer.');
                        return;
                      }
                      n.update((x) => x.copyWith(viewMode: m));
                    },
                  ),
              ],
            ),
            if (!isText) ...[
              label('Fit'),
              Row(
                children: [
                  for (final f in FitMode.values) ...[
                    PillChip(
                      label: f.label,
                      selected: s.fitMode == f,
                      onTap: () => n.update((x) => x.copyWith(fitMode: f)),
                    ),
                    const SizedBox(width: Space.x2),
                  ],
                  const Spacer(),
                  if (onResetZoom != null)
                    TextButton.icon(
                      onPressed: () {
                        onResetZoom!();
                        Navigator.pop(context);
                      },
                      icon: const Icon(PhosphorIconsRegular.cornersOut, size: 18),
                      label: const Text('Reset zoom'),
                    ),
                ],
              ),
              if (s.viewMode == ReaderViewMode.page)
                Padding(
                  padding: const EdgeInsets.only(top: Space.x2),
                  child: Text('Page by page always fits the whole page. Pinch to zoom in.',
                      style: context.text.bodySmall),
                ),
            ],
            label('Text view'),
            if (!isText)
              Text(
                'Text size, line spacing and width apply in Text view, where Folio reflows the '
                'book’s text. PDF pages keep their original layout.',
                style: context.text.bodySmall,
              )
            else ...[
              _SliderRow(
                icon: PhosphorIconsRegular.textT,
                label: 'Size',
                value: s.textScale,
                min: 14,
                max: 28,
                divisions: 14,
                display: '${s.textScale.round()}',
                onChanged: (v) => n.update((x) => x.copyWith(textScale: v)),
              ),
              _SliderRow(
                icon: PhosphorIconsRegular.lineSegments,
                label: 'Spacing',
                value: s.lineHeight,
                min: 1.3,
                max: 2.0,
                divisions: 7,
                display: s.lineHeight.toStringAsFixed(1),
                onChanged: (v) => n.update((x) => x.copyWith(lineHeight: v)),
              ),
              _SliderRow(
                icon: PhosphorIconsRegular.arrowsHorizontal,
                label: 'Width',
                value: s.textWidth,
                min: 420,
                max: 900,
                divisions: 8,
                display: s.textWidth < 560 ? 'Narrow' : s.textWidth < 760 ? 'Medium' : 'Wide',
                onChanged: (v) => n.update((x) => x.copyWith(textWidth: v)),
              ),
            ],
            const SizedBox(height: Space.x2),
            Divider(color: c.hairline),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.selected, required this.onTap});
  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} theme',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 72,
          decoration: BoxDecoration(
            color: theme.page,
            borderRadius: Radii.mdAll,
            border: Border.all(color: selected ? context.colors.lavender : context.colors.hairline, width: selected ? 2.5 : 1),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Aa', style: context.text.titleLarge?.copyWith(color: theme.text)),
              Text(theme.label, style: context.text.labelSmall?.copyWith(color: theme.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: Space.x2),
          SizedBox(width: 64, child: Text(label, style: context.text.labelMedium)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 56, child: Text(display, textAlign: TextAlign.end, style: context.text.bodySmall)),
        ],
      );
}

// ------------------------------------------------------------------ contents

Future<void> showContentsSheet(
  BuildContext context, {
  required Book book,
  required int currentPage,
  required ValueChanged<int> onJump,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.8,
      child: _ContentsSheet(book: book, currentPage: currentPage, onJump: onJump),
    ),
  );
}

class _ContentsSheet extends ConsumerStatefulWidget {
  const _ContentsSheet({required this.book, required this.currentPage, required this.onJump});
  final Book book;
  final int currentPage;
  final ValueChanged<int> onJump;

  @override
  ConsumerState<_ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends ConsumerState<_ContentsSheet> {
  final _page = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _jump(int p) {
    Navigator.pop(context);
    widget.onJump(p.clamp(1, widget.book.pageCount));
  }

  @override
  Widget build(BuildContext context) {
    final outline = ref.watch(outlineProvider(widget.book.id)).value ?? const [];
    final repo = ref.read(annotationsRepositoryProvider);
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
            child: Row(
              children: [
                Expanded(child: Text('Go to', style: context.text.headlineSmall)),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _page,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.go,
                    onSubmitted: (v) {
                      final p = int.tryParse(v);
                      if (p != null) _jump(p);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Page (1–${widget.book.pageCount})',
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            labelStyle: context.text.labelLarge,
            labelColor: context.colors.ink,
            unselectedLabelColor: context.colors.inkMuted,
            indicatorColor: context.colors.ink,
            dividerColor: context.colors.hairline,
            tabs: const [Tab(text: 'Contents'), Tab(text: 'Bookmarks'), Tab(text: 'Highlights')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                outline.isEmpty
                    ? _Hint(
                        'This PDF has no table of contents.',
                        'Use Go to page above, or the page slider in the reader.',
                      )
                    : ListView.builder(
                        itemCount: outline.length,
                        itemBuilder: (context, i) {
                          final o = outline[i];
                          final isCurrent = o.page <= widget.currentPage &&
                              (i == outline.length - 1 || outline[i + 1].page > widget.currentPage);
                          return ListTile(
                            contentPadding: EdgeInsets.only(left: Space.gutter + o.level * 16.0, right: Space.gutter),
                            title: Text(o.title,
                                style: (o.level == 0 ? context.text.titleSmall : context.text.bodyMedium)?.copyWith(
                                  color: isCurrent ? context.colors.lavender : null,
                                )),
                            trailing: Text('${o.page}', style: context.text.bodySmall),
                            onTap: () => _jump(o.page),
                          );
                        },
                      ),
                StreamBuilder(
                  stream: repo.watchBookmarksForBook(widget.book.id),
                  builder: (context, snap) {
                    final list = snap.data ?? const <Bookmark>[];
                    if (list.isEmpty) {
                      return _Hint('No bookmarks yet', 'Tap the bookmark icon at the top of the reader to save a page.');
                    }
                    return ListView(
                      children: [
                        for (final b in list)
                          ListTile(
                            leading: Icon(b.isPassage ? PhosphorIconsRegular.quotes : PhosphorIconsFill.bookmarkSimple, size: 20),
                            title: Text(b.title, style: context.text.titleSmall),
                            subtitle: Text(b.previewText, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Text('p. ${b.page}', style: context.text.bodySmall),
                            onTap: () => _jump(b.page),
                          ),
                      ],
                    );
                  },
                ),
                StreamBuilder(
                  stream: repo.watchHighlightsForBook(widget.book.id),
                  builder: (context, snap) {
                    final list = snap.data ?? const <Highlight>[];
                    if (list.isEmpty) {
                      return _Hint('No highlights yet', 'Select text on a page and pick a colour.');
                    }
                    return ListView(
                      children: [
                        for (final h in list)
                          ListTile(
                            leading: Container(
                              width: 6,
                              height: 36,
                              decoration: BoxDecoration(
                                color: ShelfColor.fromIndex(h.color).strong,
                                borderRadius: Radii.pillAll,
                              ),
                            ),
                            title: Text(h.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                            trailing: Text('p. ${h.page}', style: context.text.bodySmall),
                            onTap: () => _jump(h.page),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(body, style: context.text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

// ------------------------------------------------------------------ search

Future<void> showBookSearchSheet(
  BuildContext context, {
  required Book book,
  required void Function(SearchHit hit, String query) onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.85,
      child: _BookSearch(book: book, onOpen: onOpen),
    ),
  );
}

class _BookSearch extends ConsumerStatefulWidget {
  const _BookSearch({required this.book, required this.onOpen});
  final Book book;
  final void Function(SearchHit hit, String query) onOpen;

  @override
  ConsumerState<_BookSearch> createState() => _BookSearchState();
}

class _BookSearchState extends ConsumerState<_BookSearch> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<SearchHit>? _hits;
  bool _loading = false;

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _run(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      if (v.trim().isEmpty) {
        setState(() => _hits = null);
        return;
      }
      setState(() => _loading = true);
      final hits = await ref.read(searchRepositoryProvider).searchBook(widget.book.id, v);
      if (!mounted || _q.text != v) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider(widget.book.id)).value ?? widget.book;
    Widget body;
    if (book.isScanned) {
      body = const EmptyState(
        art: Art.emptySearch,
        illustrationWidth: 170,
        title: 'Search isn’t available',
        message: 'This PDF is made of page images with no text layer, so there’s no text to search.',
      );
    } else if (book.isIndexing && _hits == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x8),
          child: Text(
            'Still preparing search: ${book.indexedPages} of ${book.pageCount} pages. '
            'You can search the pages done so far.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
        ),
      );
    } else if (_hits == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x8),
          child: Text(
            'Search words or "an exact phrase". Results show every page with a match.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ),
      );
    } else if (_hits!.isEmpty) {
      body = EmptyState(
        art: Art.emptySearch,
        illustrationWidth: 170,
        title: 'No matches',
        message: 'Nothing in this book matches “${_q.text.trim()}”.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x6),
        itemCount: _hits!.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: Space.x2),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: Text('${_hits!.length} ${_hits!.length == 1 ? 'page' : 'pages'}', style: context.text.labelSmall),
            );
          }
          final h = _hits![i - 1];
          return BlockCard(
            padding: const EdgeInsets.all(Space.x4),
            radius: Radii.md,
            onTap: () {
              Navigator.pop(context);
              widget.onOpen(h, _q.text);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Page ${h.page}', style: context.text.labelMedium),
                const SizedBox(height: 4),
                SnippetText(h.snippet, style: context.text.bodyMedium),
              ],
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x3),
          child: TextField(
            controller: _q,
            autofocus: !book.isScanned,
            enabled: !book.isScanned,
            textInputAction: TextInputAction.search,
            onChanged: _run,
            decoration: InputDecoration(
              hintText: 'Search in this book',
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

// ------------------------------------------------------------------ highlight

Future<void> showHighlightSheet(BuildContext context, WidgetRef ref, Highlight h) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final repo = ref.read(annotationsRepositoryProvider);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Highlight · p. ${h.page}', style: ctx.text.labelSmall),
              const SizedBox(height: Space.x2),
              Text('“${h.content}”', maxLines: 4, overflow: TextOverflow.ellipsis, style: ctx.text.bodyMedium),
              const SizedBox(height: Space.x4),
              Row(
                children: [
                  for (final c in ShelfColor.highlightColors)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.x3),
                      child: GestureDetector(
                        onTap: () {
                          repo.setHighlightColor(h.id, c.index);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c.strong,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: h.color == c.index ? ctx.colors.ink : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.x2),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(PhosphorIconsRegular.notePencil),
                title: const Text('Add a note'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final text = await editNoteText(context, passage: h.content, subtitle: 'Page ${h.page}');
                  if (text != null) {
                    await repo.addNote(bookId: h.bookId, page: h.page, passage: h.content, body: text, highlightId: h.id);
                    if (context.mounted) showFolioSnack(context, 'Note saved');
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(PhosphorIconsRegular.copy),
                title: const Text('Copy text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: h.content));
                  Navigator.pop(ctx);
                  showFolioSnack(context, 'Copied');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(PhosphorIconsRegular.trash, color: ctx.colors.danger),
                title: Text('Remove highlight', style: TextStyle(color: ctx.colors.danger)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await repo.deleteHighlight(h.id);
                  if (context.mounted) {
                    showFolioSnack(context, 'Highlight removed',
                        action: 'Undo', onAction: () => repo.restoreHighlight(h));
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
