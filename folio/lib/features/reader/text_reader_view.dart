import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/reader_themes.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/logic/fts_query.dart';
import 'reader_selection.dart';

/// Reflows extracted text into readable paragraphs WITHOUT changing its
/// length, so every character index still maps onto the PDF page text (and
/// highlights made here line up with the PDF view).
String reflowPreservingIndices(String text) {
  final b = StringBuffer();
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    b.write(line.replaceAll('\r', ' '));
    if (i == lines.length - 1) break;
    final next = lines[i + 1];
    final trimmed = line.trimRight();
    final endsSentence = trimmed.isEmpty || RegExp(r'[.!?:;"”’)\]]$').hasMatch(trimmed);
    final nextStartsBlock =
        next.trim().isEmpty || RegExp(r'^\s{2,}').hasMatch(next) || RegExp(r'^\s*([•\-–—*]|\d+[.)])\s').hasMatch(next);
    final shortLine = trimmed.length < 45;
    // Keep a real line break at paragraph ends, otherwise join with a space.
    b.write((endsSentence && (shortLine || nextStartsBlock)) || nextStartsBlock ? '\n' : ' ');
  }
  return b.toString();
}

class TextReaderView extends ConsumerStatefulWidget {
  const TextReaderView({
    super.key,
    required this.book,
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.maxWidth,
    required this.initialPage,
    required this.highlights,
    required this.searchQuery,
    required this.onPageChanged,
    required this.onTap,
    required this.onSelectionChanged,
    required this.onInteraction,
  });

  final Book book;
  final ReaderTheme theme;
  final double fontSize;
  final double lineHeight;
  final double maxWidth;
  final int initialPage;
  final List<Highlight> highlights;
  final String? searchQuery;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;
  final ValueChanged<ReaderSelection?> onSelectionChanged;
  final VoidCallback onInteraction;

  @override
  ConsumerState<TextReaderView> createState() => TextReaderViewState();
}

class TextReaderViewState extends ConsumerState<TextReaderView> {
  late final PageController _pages = PageController(initialPage: widget.initialPage - 1);
  final Map<int, String> _cache = {};
  Future<PdfDocument>? _doc;
  int _clearToken = 0;
  Timer? _selDebounce;

  int get currentPage => (_pages.hasClients ? (_pages.page ?? 0).round() : widget.initialPage - 1) + 1;

  @override
  void dispose() {
    _pages.dispose();
    _selDebounce?.cancel();
    _doc?.then((d) => d.dispose());
    super.dispose();
  }

  void goToPage(int page, {bool animate = true}) {
    if (!_pages.hasClients) return;
    final i = (page - 1).clamp(0, widget.book.pageCount - 1);
    if (animate && (i - currentPage + 1).abs() <= 2) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    } else {
      _pages.jumpToPage(i);
    }
  }

  void clearSelection() => setState(() => _clearToken++);

  Future<String> _text(int page) async {
    final hit = _cache[page];
    if (hit != null) return hit;
    final t = await ref.read(searchRepositoryProvider).pageText(widget.book.id, page) ?? '';
    _cache[page] = t;
    return t;
  }

  Future<void> _onSelection(int page, TextSelection sel) async {
    _selDebounce?.cancel();
    if (sel.isCollapsed || sel.start < 0) {
      widget.onSelectionChanged(null);
      return;
    }
    _selDebounce = Timer(const Duration(milliseconds: 300), () async {
      // Map the text offsets onto the PDF page text to get highlight rects.
      _doc ??= PdfDocument.openFile(widget.book.filePath);
      try {
        final doc = await _doc!;
        final pt = await doc.pages[page - 1].loadStructuredText();
        final seg = segmentFromIndices(pt, sel.start, sel.end);
        if (!mounted) return;
        widget.onSelectionChanged(seg.text.trim().isEmpty ? null : ReaderSelection([seg]));
      } catch (_) {
        widget.onSelectionChanged(null);
      }
    });
  }

  List<TextSpan> _spans(int page, String text, TextStyle base) {
    // Paint ranges: highlights first, then search matches on top.
    final marks = List<Color?>.filled(text.length, null);
    for (final h in widget.highlights.where((h) => h.page == page)) {
      final c = ShelfColor.fromIndex(h.color).strong.withValues(alpha: widget.theme == ReaderTheme.night ? 0.38 : 0.55);
      for (var i = h.startIndex.clamp(0, text.length); i < h.endIndex.clamp(0, text.length); i++) {
        marks[i] = c;
      }
    }
    final q = widget.searchQuery;
    if (q != null && q.trim().isNotEmpty) {
      final lower = text.toLowerCase();
      final phrase = RegExp(r'"([^"]+)"').firstMatch(q)?.group(1);
      final needles = phrase != null ? [phrase.toLowerCase()] : queryTerms(q);
      for (final n in needles) {
        var from = 0;
        while (n.isNotEmpty) {
          final i = lower.indexOf(n, from);
          if (i < 0) break;
          for (var k = i; k < i + n.length; k++) {
            marks[k] = const Color(0xFFA58BF7).withValues(alpha: 0.55);
          }
          from = i + n.length;
        }
      }
    }
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || marks[i] != marks[start]) {
        spans.add(
          TextSpan(
            text: text.substring(start, i),
            style: marks[start] == null ? null : base.copyWith(backgroundColor: marks[start]),
          ),
        );
        start = i;
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final style = readingTextStyle(size: widget.fontSize, lineHeight: widget.lineHeight, color: t.text);
    return ColoredBox(
      color: t.page,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          widget.onInteraction();
          return false;
        },
        child: PageView.builder(
          controller: _pages,
          itemCount: widget.book.pageCount,
          onPageChanged: (i) {
            widget.onSelectionChanged(null);
            widget.onPageChanged(i + 1);
          },
          itemBuilder: (context, i) {
            final page = i + 1;
            return FutureBuilder<String>(
              future: _text(page),
              initialData: _cache[page],
              builder: (context, snap) {
                final raw = snap.data;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(Space.x6, Space.x14, Space.x6, Space.x14 + Space.x10),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: widget.maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PAGE $page',
                                style: context.text.labelSmall?.copyWith(color: t.mutedText, letterSpacing: 1.4),
                              ),
                              const SizedBox(height: Space.x4),
                              if (raw == null)
                                const SizedBox(height: 200)
                              else if (raw.trim().isEmpty)
                                Text(
                                  'This page has no text. It may be an image or a figure. '
                                  'Switch to Scroll or Page view to see it.',
                                  style: style.copyWith(color: t.mutedText, fontStyle: FontStyle.italic),
                                )
                              else
                                SelectableText.rich(
                                  key: ValueKey('p$page-$_clearToken'),
                                  TextSpan(style: style, children: _spans(page, reflowPreservingIndices(raw), style)),
                                  onTap: widget.onTap,
                                  onSelectionChanged: (sel, _) => _onSelection(page, sel),
                                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                                  selectionColor: const Color(0xFFA58BF7).withValues(alpha: 0.35),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
