import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme/icons.dart';

import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/reader_themes.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/logic/fts_query.dart';
import '../../data/logic/reading_tracker.dart';
import '../../data/repositories/books_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/book_cover.dart';
import '../../shared/widgets/controls.dart';
import '../ai/ai_gate.dart';
import '../annotations/note_editor.dart';
import 'pdf_reader_view.dart';
import 'reader_selection.dart';
import 'reader_sheets.dart';
import 'selection_toolbar.dart';
import 'session_picker.dart';
import 'text_reader_view.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    this.initialPage,
    this.fromStart = false,
    this.focusMinutes,
    this.highlightQuery,
  });

  final int bookId;
  final int? initialPage;
  final bool fromStart;
  final int? focusMinutes;
  final String? highlightQuery;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  Book? _book;
  ReaderAnchor? _anchor;
  String? _error;

  final _pdf = PdfViewerController();
  final _pdfKey = GlobalKey<PdfReaderViewState>();
  final _textKey = GlobalKey<TextReaderViewState>();

  bool _chrome = false;
  bool _docReady = false;
  int _page = 1;
  ReaderSelection? _selection;
  List<Highlight> _highlights = const [];
  StreamSubscription<List<Highlight>>? _hlSub;
  Map<int, List<Rect>> _searchMarks = const {};
  String? _searchQuery;
  bool _pageBookmarked = false;

  late ReadingTracker _tracker;
  late DateTime _sessionStart;
  int? _sessionId;
  Timer? _tick;
  Timer? _flush;
  Timer? _saveDebounce;
  bool _sessionEnded = false;

  // Repositories are captured up front so position and reading time can
  // still be saved while the screen is being disposed.
  late final _positions = ref.read(positionRepositoryProvider);
  late final _statsRepo = ref.read(statsRepositoryProvider);
  late final _booksRepo = ref.read(booksRepositoryProvider);

  // Focus session
  int? _focusMinutes;
  bool _focusDoneShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusMinutes = widget.focusMinutes;
    _searchQuery = widget.highlightQuery;
    // Touch the lazy fields while ref is valid.
    _positions;
    _statsRepo;
    _booksRepo;
    _viewMode = ref.read(settingsProvider).viewMode;
    _load();
  }

  Future<void> _load() async {
    final books = ref.read(booksRepositoryProvider);
    final book = await books.getBook(widget.bookId);
    if (book == null) {
      setState(() => _error = 'This book is no longer in your library.');
      return;
    }
    final pos = await ref.read(positionRepositoryProvider).get(book.id);
    ReaderAnchor anchor;
    if (widget.initialPage != null) {
      anchor = ReaderAnchor(page: widget.initialPage!.clamp(1, book.pageCount));
    } else if (widget.fromStart || pos == null) {
      anchor = const ReaderAnchor(page: 1);
    } else {
      anchor = ReaderAnchor(page: pos.page.clamp(1, book.pageCount), offset: pos.pageOffset, zoom: pos.zoom);
    }
    await books.markOpened(book.id);
    // Opening on a page counts as reaching it (drives progress %).
    await books.recordPageReached(book.id, anchor.page);

    final now = DateTime.now();
    _tracker = ReadingTracker(startPage: anchor.page, now: now);
    _sessionStart = now;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _flush = Timer.periodic(const Duration(seconds: 30), (_) => _flushActivity());
    _hlSub = ref.read(annotationsRepositoryProvider).watchHighlightsForBook(book.id).listen((h) {
      if (mounted) setState(() => _highlights = h);
    });

    if (!mounted) return;
    setState(() {
      _book = book;
      _anchor = anchor;
      _page = anchor.page;
    });
    _refreshBookmark();
    if (_searchQuery != null) unawaited(_markSearch(anchor.page, _searchQuery!));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _flush?.cancel();
    _saveDebounce?.cancel();
    _hlSub?.cancel();
    if (_book != null) {
      _savePosition();
      _endSession();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_book == null) return;
    final now = DateTime.now();
    if (state == AppLifecycleState.resumed) {
      _tracker.resume(now);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _tracker.pause(now);
      _savePosition();
      _flushActivity();
    }
  }

  // --------------------------------------------------------------- tracking

  void _onTick() {
    final now = DateTime.now();
    _tracker.tick(now);
    if (_focusMinutes != null) {
      if (!_focusDoneShown && _focusRemaining <= Duration.zero) {
        _focusDoneShown = true;
        HapticFeedback.mediumImpact();
        _finishFocus(completed: true);
      }
      if (mounted) setState(() {});
    }
  }

  Duration get _focusRemaining => Duration(minutes: _focusMinutes ?? 0) - _tracker.activeTime;

  Future<void> _flushActivity() async {
    final book = _book;
    if (book == null) return;
    final now = DateTime.now();
    final d = _tracker.takeUnflushed(now);
    await _statsRepo.addActivity(bookId: book.id, pages: d.pages, seconds: d.active.inSeconds, at: now);
    final stats = _statsRepo;
    final row = ReadingSessionsCompanion(
      bookId: Value(book.id),
      startedAt: Value(_sessionStart),
      endedAt: Value(now),
      startPage: Value(_tracker.startPage),
      endPage: Value(_tracker.currentPage),
      pagesRead: Value(_tracker.pagesRead),
      seconds: Value(_tracker.activeTime.inSeconds),
      targetMinutes: Value(_focusMinutes),
    );
    if (_tracker.activeTime.inSeconds < 5) return;
    if (_sessionId == null) {
      _sessionId = await stats.saveSession(row);
    } else {
      await stats.updateSession(_sessionId!, row);
    }
  }

  void _endSession() {
    if (_sessionEnded) return;
    _sessionEnded = true;
    _tracker.pause(DateTime.now());
    unawaited(_flushActivity());
  }

  void _interaction() {
    if (_book == null) return;
    _tracker.interaction(DateTime.now());
  }

  void _onPage(int page) {
    if (page == _page || _book == null) return;
    setState(() => _page = page);
    _tracker.pageChanged(page, DateTime.now());
    _booksRepo.recordPageReached(_book!.id, page);
    _refreshBookmark();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _savePosition);
  }

  ReaderViewMode _viewMode = ReaderViewMode.scroll;

  ReaderAnchor _currentAnchor() {
    if (_viewMode == ReaderViewMode.text) {
      return ReaderAnchor(page: _textKey.currentState?.currentPage ?? _page, zoom: _anchor?.zoom ?? 1);
    }
    return _pdfKey.currentState?.currentAnchor() ?? ReaderAnchor(page: _page);
  }

  void _savePosition([ReaderAnchor? a]) {
    final book = _book;
    if (book == null) return;
    final anchor = a ?? _currentAnchor();
    _anchor = anchor;
    _positions.save(book.id, page: anchor.page, pageOffset: anchor.offset, zoom: anchor.zoom);
  }

  Future<void> _refreshBookmark() async {
    final b = _book;
    if (b == null) return;
    final bm = await ref.read(annotationsRepositoryProvider).pageBookmark(b.id, _page);
    if (mounted) setState(() => _pageBookmarked = bm != null);
  }

  // --------------------------------------------------------------- navigation

  void _jumpTo(int page) {
    final mode = ref.read(settingsProvider).viewMode;
    if (mode == ReaderViewMode.text) {
      _textKey.currentState?.goToPage(page);
    } else {
      _pdfKey.currentState?.goToPage(page);
    }
    _onPage(page);
  }

  Future<void> _markSearch(int page, String query) async {
    final book = _book;
    if (book == null) return;
    setState(() => _searchQuery = query);
    final mode = ref.read(settingsProvider).viewMode;
    if (mode == ReaderViewMode.text) return; // Text view marks terms itself.
    try {
      final doc = await PdfDocument.openFile(book.filePath);
      try {
        final text = await doc.pages[page - 1].loadStructuredText();
        final phrase = RegExp(r'"([^"]+)"').firstMatch(query)?.group(1);
        final needles = phrase != null ? [phrase] : queryTerms(query);
        final rects = <Rect>[];
        for (final n in needles) {
          await for (final m in text.allMatches(n, caseInsensitive: true)) {
            rects.addAll(segmentFromRange(m).rects);
          }
        }
        if (!mounted) return;
        setState(() => _searchMarks = {page: rects});
        if (_docReady) await _pdfKey.currentState?.revealRects(page, rects);
      } finally {
        await doc.dispose();
      }
    } catch (_) {
      // Leave the page open without marks.
    }
  }

  void _clearSearch() => setState(() {
    _searchMarks = const {};
    _searchQuery = null;
  });

  // --------------------------------------------------------------- selection

  void _setSelection(ReaderSelection? s) {
    if (s != null) _interaction();
    setState(() => _selection = (s == null || s.isEmpty) ? null : s);
  }

  Future<void> _clearSelection() async {
    setState(() => _selection = null);
    if (_pdf.isReady) await _pdf.textSelectionDelegate.clearTextSelection();
    _textKey.currentState?.clearSelection();
  }

  Future<List<int>> _saveHighlights(ReaderSelection sel, ShelfColor color) async {
    final repo = ref.read(annotationsRepositoryProvider);
    final ids = <int>[];
    for (final s in sel.segments) {
      if (s.text.trim().isEmpty) continue;
      ids.add(
        await repo.addHighlight(
          bookId: _book!.id,
          page: s.page,
          content: s.text.replaceAll(RegExp(r'\s+'), ' '),
          color: color.index,
          startIndex: s.start,
          endIndex: s.end,
          rects: s.rects,
        ),
      );
    }
    return ids;
  }

  Future<void> _highlight(ShelfColor color) async {
    final sel = _selection;
    if (sel == null) return;
    await _saveHighlights(sel, color);
    await _clearSelection();
    if (mounted) showFolioSnack(context, 'Highlighted');
  }

  Future<void> _selectionAction(SelectionAction a) async {
    final sel = _selection;
    final book = _book;
    if (sel == null || book == null) return;
    final text = sel.text;
    switch (a) {
      case SelectionAction.copy:
        await Clipboard.setData(ClipboardData(text: text));
        await _clearSelection();
        if (mounted) showFolioSnack(context, 'Copied');
      case SelectionAction.share:
        await _clearSelection();
        await SharePlus.instance.share(
          ShareParams(
            text: '“$text”\n— ${book.title}${book.author != null ? ', ${book.author}' : ''}, p. ${sel.firstPage}',
          ),
        );
      case SelectionAction.bookmark:
        final title = text.split(' ').take(6).join(' ');
        await ref
            .read(annotationsRepositoryProvider)
            .addBookmark(
              bookId: book.id,
              page: sel.firstPage,
              title: title.length < text.length ? '$title…' : title,
              previewText: text.length > 280 ? '${text.substring(0, 280)}…' : text,
              isPassage: true,
            );
        await _clearSelection();
        HapticFeedback.lightImpact();
        if (mounted) showFolioSnack(context, 'Passage bookmarked');
      case SelectionAction.note:
        final body = await editNoteText(context, passage: text, subtitle: 'Page ${sel.firstPage}');
        if (body == null) return;
        final ids = await _saveHighlights(sel, ShelfColor.butter);
        await ref
            .read(annotationsRepositoryProvider)
            .addNote(
              bookId: book.id,
              page: sel.firstPage,
              passage: text,
              body: body,
              highlightId: ids.isEmpty ? null : ids.first,
            );
        await _clearSelection();
        if (mounted) showFolioSnack(context, 'Note saved');
      case SelectionAction.askAi:
      case SelectionAction.explain:
        await _clearSelection();
        if (!mounted) return;
        await showAssistantSheet(
          context,
          ref,
          bookId: book.id,
          page: sel.firstPage,
          passage: text,
          action: a == SelectionAction.explain ? AssistAction.explain : AssistAction.ask,
        );
    }
  }

  Future<void> _togglePageBookmark() async {
    final book = _book;
    if (book == null) return;
    HapticFeedback.lightImpact();
    final text = await ref.read(searchRepositoryProvider).pageText(book.id, _page);
    final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final now = await ref
        .read(annotationsRepositoryProvider)
        .togglePageBookmark(bookId: book.id, page: _page, previewText: t.length > 160 ? '${t.substring(0, 160)}…' : t);
    setState(() => _pageBookmarked = now);
    if (mounted) showFolioSnack(context, now ? 'Bookmarked page $_page' : 'Bookmark removed');
  }

  Future<void> _addPageNote() async {
    final book = _book;
    if (book == null) return;
    final body = await editNoteText(context, passage: '', subtitle: 'Note on page $_page');
    if (body == null) return;
    await ref
        .read(annotationsRepositoryProvider)
        .addNote(bookId: book.id, page: _page, passage: 'Page $_page', body: body);
    if (mounted) showFolioSnack(context, 'Note saved');
  }

  // --------------------------------------------------------------- focus

  Future<void> _finishFocus({required bool completed}) async {
    final book = _book;
    if (book == null) return;
    _tracker.pause(DateTime.now());
    await _flushActivity();
    final stats = await ref.read(statsRepositoryProvider).summary();
    final fresh = await ref.read(booksRepositoryProvider).getBook(book.id);
    if (!mounted) return;
    await showSessionSummary(
      context,
      SessionResult(
        pages: _tracker.pagesRead,
        active: _tracker.activeTime,
        targetMinutes: _focusMinutes,
        completed: completed,
        streak: stats.streak.current,
        progress: fresh?.progress ?? book.progress,
      ),
    );
    if (!mounted) return;
    if (_focusMinutes != null && completed) {
      // Keep reading freely after the session.
      setState(() => _focusMinutes = null);
      _tracker.resume(DateTime.now());
    } else {
      _endSession();
      if (mounted) context.pop();
    }
  }

  Future<void> _startFocus() async {
    final minutes = await pickSessionLength(context);
    if (minutes == null || !mounted) return;
    // A focus session starts its own clock and page count.
    await _flushActivity();
    setState(() {
      _sessionId = null;
      _sessionStart = DateTime.now();
      _tracker = ReadingTracker(startPage: _page, now: DateTime.now());
      _focusMinutes = minutes;
      _focusDoneShown = false;
      _chrome = false;
    });
  }

  // --------------------------------------------------------------- build

  ReaderTheme _theme(AppSettings s) {
    if (s.followSystemForReader) {
      final dark = switch (s.themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };
      if (dark) return ReaderTheme.night;
      return s.readerTheme == ReaderTheme.night ? ReaderTheme.paper : s.readerTheme;
    }
    return s.readerTheme;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!, style: context.text.bodyMedium)),
      );
    }
    final book = ref.watch(bookProvider(widget.bookId)).value ?? _book;
    final anchor = _anchor;
    final settings = ref.watch(settingsProvider);
    final theme = _theme(settings);
    final m = Motion.of(context);
    final darkChrome = theme.chromeBrightness == Brightness.dark;
    final textAvailable = book != null && book.indexStatus == IndexStatus.done && book.textPages > 0;
    var mode = settings.viewMode;
    if (mode == ReaderViewMode.text && !textAvailable) mode = ReaderViewMode.scroll;
    if (mode != _viewMode) {
      // Switching views: carry the current page over.
      _anchor = _currentAnchor();
      _viewMode = mode;
      _docReady = mode == ReaderViewMode.text;
    }
    final focus = _focusMinutes != null;

    final content = (book == null || anchor == null)
        ? const SizedBox.expand()
        : mode == ReaderViewMode.text
        ? TextReaderView(
            key: _textKey,
            book: book,
            theme: theme,
            fontSize: settings.textScale,
            lineHeight: settings.lineHeight,
            maxWidth: settings.textWidth,
            initialPage: _page,
            highlights: _highlights,
            searchQuery: _searchQuery,
            onPageChanged: _onPage,
            onTap: () => setState(() => _chrome = !_chrome),
            onSelectionChanged: _setSelection,
            onInteraction: _interaction,
          )
        : PdfReaderView(
            key: _pdfKey,
            book: book,
            controller: _pdf,
            mode: mode,
            fit: settings.fitMode,
            theme: theme,
            anchor: _anchorForMode(),
            highlights: _highlights,
            searchMarks: _searchMarks,
            onTap: () => setState(() => _chrome = !_chrome),
            onPageChanged: _onPage,
            onPositionChanged: (a) {
              _anchor = a;
              _scheduleSave();
            },
            onSelectionChanged: _setSelection,
            onHighlightTap: (h) => showHighlightSheet(context, ref, h),
            onInteraction: _interaction,
            onReady: () {
              setState(() => _docReady = true);
              final marks = _searchMarks[_page];
              if (marks != null) _pdfKey.currentState?.revealRects(_page, marks);
            },
          );

    final chromeTheme = darkChrome ? AppTheme.dark() : AppTheme.light();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkChrome ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Theme(
        data: chromeTheme,
        child: PopScope(
          canPop: _selection == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _clearSelection();
          },
          child: Scaffold(
            backgroundColor: theme.canvas,
            body: Stack(
              children: [
                Positioned.fill(child: content),
                // Cover shown while the PDF opens (target of the Hero from
                // the library), fading into the first rendered page.
                if (book != null && mode != ReaderViewMode.text)
                  IgnorePointer(
                    ignoring: _docReady,
                    child: AnimatedOpacity(
                      opacity: _docReady ? 0 : 1,
                      duration: m.slow,
                      child: Container(
                        color: theme.canvas,
                        alignment: Alignment.center,
                        child: BookCover(book: book, width: 180),
                      ),
                    ),
                  ),
                if (book != null && !focus)
                  _TopBar(
                    visible: _chrome,
                    book: book,
                    bookmarked: _pageBookmarked,
                    textAvailable: textAvailable,
                    onBack: () => context.pop(),
                    onSearch: () => showBookSearchSheet(
                      context,
                      book: book,
                      onOpen: (hit, q) {
                        _jumpTo(hit.page);
                        _markSearch(hit.page, q);
                      },
                    ),
                    onBookmark: _togglePageBookmark,
                    onAppearance: () => showAppearanceSheet(
                      context,
                      textAvailable: textAvailable,
                      onResetZoom: mode == ReaderViewMode.text ? null : () => _pdfKey.currentState?.resetZoom(),
                    ),
                    onMenu: () => _showMenu(book),
                  ),
                if (book != null && !focus)
                  _BottomBar(
                    visible: _chrome && _selection == null,
                    page: _page,
                    pageCount: book.pageCount,
                    mode: mode,
                    textAvailable: textAvailable,
                    onJump: _jumpTo,
                    onContents: () => showContentsSheet(context, book: book, currentPage: _page, onJump: _jumpTo),
                    onMode: (m) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(viewMode: m)),
                  ),
                if (book != null && focus)
                  _FocusBar(
                    remaining: _focusRemaining,
                    total: Duration(minutes: _focusMinutes!),
                    page: _page,
                    pageCount: book.pageCount,
                    dark: darkChrome,
                    onEnd: () => _finishFocus(completed: false),
                  ),
                if (_searchQuery != null && _chrome && !focus)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 72,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: InputChip(
                        avatar: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 16),
                        label: Text('“${_searchQuery!.trim()}”'),
                        onDeleted: _clearSearch,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                // Selection toolbar slides up like a mini bottom sheet.
                Positioned(
                  left: Space.x3,
                  right: Space.x3,
                  bottom: MediaQuery.paddingOf(context).bottom + Space.x3,
                  child: AnimatedSwitcher(
                    duration: m.base,
                    switchInCurve: Motion.curve,
                    transitionBuilder: (child, a) => SlideTransition(
                      position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                      child: FadeTransition(opacity: a, child: child),
                    ),
                    child: _selection == null
                        ? const SizedBox.shrink(key: ValueKey('none'))
                        : SelectionToolbar(
                            key: const ValueKey('toolbar'),
                            dark: darkChrome,
                            onHighlight: _highlight,
                            onAction: _selectionAction,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The anchor to open the PDF view at (also after switching modes).
  ReaderAnchor _anchorForMode() {
    final a = _anchor ?? ReaderAnchor(page: _page);
    return a.page == _page ? a : ReaderAnchor(page: _page);
  }

  void _showMenu(Book book) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon),
          title: Text(label, style: ctx.text.titleSmall),
          onTap: () {
            Navigator.pop(ctx);
            onTap();
          },
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(PhosphorIconsRegular.sparkle, 'Ask about this page', () {
                showAssistantSheet(context, ref, bookId: book.id, page: _page);
              }),
              item(
                PhosphorIconsRegular.chatCircleText,
                'Ask this book',
                () => context.push('/ask/${book.id}?page=$_page'),
              ),
              item(PhosphorIconsRegular.notePencil, 'Add a note to this page', _addPageNote),
              item(PhosphorIconsRegular.timer, 'Start a focused session', _startFocus),
              item(
                PhosphorIconsRegular.highlighter,
                'Highlights in this book',
                () => context.push('/highlights?book=${book.id}'),
              ),
              item(PhosphorIconsRegular.info, 'Book details', () => context.push('/book/${book.id}')),
              const SizedBox(height: Space.x2),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.visible,
    required this.book,
    required this.bookmarked,
    required this.textAvailable,
    required this.onBack,
    required this.onSearch,
    required this.onBookmark,
    required this.onAppearance,
    required this.onMenu,
  });

  final bool visible;
  final Book book;
  final bool bookmarked;
  final bool textAvailable;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onBookmark;
  final VoidCallback onAppearance;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final c = context.colors;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: m.base,
          curve: Motion.curve,
          offset: visible ? Offset.zero : const Offset(0, -1),
          child: AnimatedOpacity(
            duration: m.base,
            opacity: visible ? 1 : 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(Space.x3, MediaQuery.paddingOf(context).top + Space.x2, Space.x3, Space.x3),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.97),
                border: Border(bottom: BorderSide(color: c.hairline)),
              ),
              child: Row(
                children: [
                  CircleIconButton(icon: PhosphorIconsRegular.arrowLeft, tooltip: 'Back', onPressed: onBack),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search in book',
                    onPressed: onSearch,
                    icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                  ),
                  IconButton(
                    tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark this page',
                    onPressed: onBookmark,
                    icon:
                        Icon(
                              bookmarked ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple,
                              color: bookmarked ? c.lavender : null,
                            )
                            .animate(key: ValueKey(bookmarked), target: bookmarked ? 1 : 0)
                            .moveY(begin: bookmarked ? -6 : 0, end: 0, duration: m.base, curve: Curves.easeOutBack),
                  ),
                  IconButton(
                    tooltip: 'Appearance',
                    onPressed: onAppearance,
                    icon: const Icon(PhosphorIconsRegular.textAa),
                  ),
                  IconButton(tooltip: 'More', onPressed: onMenu, icon: const Icon(PhosphorIconsRegular.dotsThree)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.visible,
    required this.page,
    required this.pageCount,
    required this.mode,
    required this.textAvailable,
    required this.onJump,
    required this.onContents,
    required this.onMode,
  });

  final bool visible;
  final int page;
  final int pageCount;
  final ReaderViewMode mode;
  final bool textAvailable;
  final ValueChanged<int> onJump;
  final VoidCallback onContents;
  final ValueChanged<ReaderViewMode> onMode;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final c = context.colors;
    final shown = (_drag ?? widget.page.toDouble()).round();
    final modes = [ReaderViewMode.scroll, ReaderViewMode.page, if (widget.textAvailable) ReaderViewMode.text];
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedSlide(
          duration: m.base,
          curve: Motion.curve,
          offset: widget.visible ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: m.base,
            opacity: widget.visible ? 1 : 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x3,
                Space.gutter,
                MediaQuery.paddingOf(context).bottom + Space.x3,
              ),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.97),
                border: Border(top: BorderSide(color: c.hairline)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('p. $shown', style: context.text.labelLarge),
                      Expanded(
                        child: widget.pageCount > 1
                            ? Slider(
                                min: 1,
                                max: widget.pageCount.toDouble(),
                                value: (_drag ?? widget.page.toDouble()).clamp(1, widget.pageCount.toDouble()),
                                label: 'Page $shown',
                                onChanged: (v) => setState(() => _drag = v),
                                onChangeEnd: (v) {
                                  setState(() => _drag = null);
                                  widget.onJump(v.round());
                                },
                              )
                            : const SizedBox(height: 48),
                      ),
                      Text('${((shown / widget.pageCount) * 100).round()}%', style: context.text.labelMedium),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: widget.onContents,
                        icon: const Icon(PhosphorIconsRegular.list, size: 18),
                        label: const Text('Contents'),
                      ),
                      const Spacer(),
                      for (final mode in modes)
                        Padding(
                          padding: const EdgeInsets.only(left: Space.x2),
                          child: PillChip(
                            dense: true,
                            label: mode.label == 'Page by page' ? 'Pages' : mode.label,
                            selected: widget.mode == mode,
                            onTap: () => widget.onMode(mode),
                          ),
                        ),
                    ],
                  ),
                  if (widget.pageCount > 0)
                    Text('${plural(widget.pageCount - shown, 'page')} left', style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Distraction-free overlay for focused sessions: time left, page, progress.
class _FocusBar extends StatelessWidget {
  const _FocusBar({
    required this.remaining,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.dark,
    required this.onEnd,
  });

  final Duration remaining;
  final Duration total;
  final int page;
  final int pageCount;
  final bool dark;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? const Color(0xFFEDE6D8) : const Color(0xFF161514);
    final bg = dark ? const Color(0xE61C1A18) : const Color(0xE6FFFDF8);
    final left = remaining.isNegative ? Duration.zero : remaining;
    final done = 1 - (left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return Positioned(
      left: Space.x3,
      right: Space.x3,
      bottom: MediaQuery.paddingOf(context).bottom + Space.x3,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x3),
        decoration: BoxDecoration(color: bg, borderRadius: Radii.pillAll),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: done,
                strokeWidth: 3,
                color: const Color(0xFFA58BF7),
                backgroundColor: fg.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(width: Space.x3),
            Text(
              formatClock(left),
              style: context.text.titleMedium?.copyWith(color: fg, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            Text(' left', style: context.text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.7))),
            const Spacer(),
            Text(
              'p. $page / $pageCount · ${((page / pageCount) * 100).round()}%',
              style: context.text.labelMedium?.copyWith(color: fg.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: Space.x2),
            TextButton(
              onPressed: onEnd,
              style: TextButton.styleFrom(foregroundColor: fg),
              child: const Text('End'),
            ),
          ],
        ),
      ),
    );
  }
}
