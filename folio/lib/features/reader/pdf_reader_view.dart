import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/db/database.dart';
import '../../core/theme/reader_themes.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/annotations_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'reader_selection.dart';

/// Where to put the viewer when it opens.
class ReaderAnchor {
  const ReaderAnchor({required this.page, this.offset = 0, this.zoom = 1});
  final int page;

  /// Viewport top inside the page, 0..1.
  final double offset;

  /// Zoom relative to the fit zoom (1 = fit).
  final double zoom;
}

/// Renders the PDF with pdfrx. Pages are rendered on demand in tiles on
/// PDFium's worker isolate, so memory stays flat even for huge documents.
class PdfReaderView extends StatefulWidget {
  const PdfReaderView({
    super.key,
    required this.book,
    required this.controller,
    required this.mode,
    required this.fit,
    required this.theme,
    required this.anchor,
    required this.highlights,
    required this.searchMarks,
    required this.onTap,
    required this.onPageChanged,
    required this.onPositionChanged,
    required this.onSelectionChanged,
    required this.onHighlightTap,
    required this.onInteraction,
    required this.onReady,
  });

  final Book book;
  final PdfViewerController controller;
  final ReaderViewMode mode;
  final FitMode fit;
  final ReaderTheme theme;
  final ReaderAnchor anchor;
  final List<Highlight> highlights;

  /// Search matches to paint, per page, in PDF coordinates.
  final Map<int, List<Rect>> searchMarks;
  final VoidCallback onTap;
  final ValueChanged<int> onPageChanged;
  final void Function(ReaderAnchor anchor) onPositionChanged;
  final ValueChanged<ReaderSelection?> onSelectionChanged;
  final ValueChanged<Highlight> onHighlightTap;
  final VoidCallback onInteraction;
  final VoidCallback onReady;

  @override
  State<PdfReaderView> createState() => PdfReaderViewState();
}

class PdfReaderViewState extends State<PdfReaderView> {
  static const double _margin = 12;

  bool _ready = false;
  int _gestureStartPage = 1;
  Offset _gestureStartCenter = Offset.zero;
  Timer? _posDebounce;
  Timer? _selDebounce;
  int _selectionToken = 0;

  PdfViewerController get _c => widget.controller;
  bool get _pageMode => widget.mode == ReaderViewMode.page;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onMatrixChanged);
  }

  @override
  void didUpdateWidget(covariant PdfReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onMatrixChanged);
      widget.controller.addListener(_onMatrixChanged);
    }
    if (old.mode != widget.mode) {
      // The viewer is rebuilt (keyed by mode) with a new page layout and
      // reopens at widget.anchor; wait for it to be ready again.
      _ready = false;
    } else if (_ready && old.fit != widget.fit) {
      applyFit(animate: true);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onMatrixChanged);
    _posDebounce?.cancel();
    _selDebounce?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ geometry

  Rect _pageRect(int page) => _c.layout.pageLayouts[(page - 1).clamp(0, _c.layout.pageLayouts.length - 1)];

  double _fitZoom(int page, {FitMode? fit}) {
    final view = _c.viewSize;
    final r = _pageRect(page);
    final byWidth = view.width / (r.width + _margin * 2);
    final byPage = math.min(byWidth, view.height / (r.height + _margin * 2));
    final f = _pageMode ? FitMode.page : (fit ?? widget.fit);
    return f == FitMode.width ? byWidth : byPage;
  }

  int get currentPage => _c.pageNumber ?? widget.anchor.page;

  /// Current exact position: page, offset within page, zoom relative to fit.
  ReaderAnchor currentAnchor() {
    if (!_ready || !_c.isReady) return widget.anchor;
    final vis = _c.visibleRect;
    final layouts = _c.layout.pageLayouts;
    var page = currentPage;
    if (!_pageMode) {
      // First page whose bottom is below the viewport top.
      for (var i = 0; i < layouts.length; i++) {
        if (layouts[i].bottom > vis.top) {
          page = i + 1;
          break;
        }
      }
    }
    final r = _pageRect(page);
    final offset = r.height == 0 ? 0.0 : ((vis.top - r.top) / r.height).clamp(0.0, 1.0);
    final zoomRel = _c.currentZoom / _fitZoom(page);
    return ReaderAnchor(page: page, offset: offset, zoom: zoomRel);
  }

  Future<void> goToAnchor(ReaderAnchor a, {bool animate = false}) async {
    if (!_c.isReady) return;
    final page = a.page.clamp(1, _c.pageCount);
    final r = _pageRect(page);
    final view = _c.viewSize;
    final zoom = _fitZoom(page) * (a.zoom.isFinite && a.zoom > 0 ? a.zoom : 1);
    Offset center;
    if (_pageMode && a.zoom <= 1.01) {
      center = r.center;
    } else {
      final top = r.top + a.offset * r.height - (a.offset == 0 ? _margin : 0);
      center = Offset(r.center.dx, top + view.height / zoom / 2);
    }
    final m = _c.calcMatrixFor(center, zoom: zoom);
    await _c.goTo(m, duration: animate ? const Duration(milliseconds: 260) : Duration.zero);
  }

  Future<void> goToPage(int page, {bool animate = true}) =>
      goToAnchor(ReaderAnchor(page: page), animate: animate);

  Future<void> nextPage() => goToPage((currentPage + 1).clamp(1, _c.pageCount));
  Future<void> previousPage() => goToPage((currentPage - 1).clamp(1, _c.pageCount));

  /// Scrolls so that [rects] (PDF coords) on [page] are visible.
  Future<void> revealRects(int page, List<Rect> rects) async {
    if (!_c.isReady || rects.isEmpty) return;
    var u = rects.first;
    for (final r in rects.skip(1)) {
      u = Rect.fromLTRB(math.min(u.left, r.left), math.max(u.top, r.top), math.max(u.right, r.right),
          math.min(u.bottom, r.bottom));
    }
    if (_pageMode) {
      await goToPage(page, animate: false);
      return;
    }
    await _c.goToRectInsidePage(
      pageNumber: page,
      rect: PdfRect(u.left, u.top, u.right, u.bottom),
      anchor: PdfPageAnchor.center,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> applyFit({bool animate = false}) async {
    final a = currentAnchor();
    await goToAnchor(ReaderAnchor(page: a.page, offset: a.offset, zoom: 1), animate: animate);
    _reportPosition();
  }

  Future<void> resetZoom() => applyFit(animate: true);

  // ------------------------------------------------------------ events

  void _onMatrixChanged() {
    if (!_ready) return;
    _posDebounce?.cancel();
    _posDebounce = Timer(const Duration(milliseconds: 500), _reportPosition);
  }

  void _reportPosition() {
    if (!mounted || !_ready) return;
    widget.onPositionChanged(currentAnchor());
  }

  PdfPageLayout _horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (p, e) => math.max(p, e.height)) + _margin * 2;
    final layouts = <Rect>[];
    var x = _margin;
    for (final page in pages) {
      layouts.add(Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height));
      x += page.width + _margin * 4;
    }
    return PdfPageLayout(pageLayouts: layouts, documentSize: Size(x - _margin * 3, height));
  }

  void _onInteractionStart(ScaleStartDetails d) {
    widget.onInteraction();
    if (!_c.isReady) return;
    _gestureStartPage = currentPage;
    _gestureStartCenter = _c.visibleRect.center;
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (!_pageMode || !_c.isReady) return;
    final fit = _fitZoom(_gestureStartPage);
    if (_c.currentZoom > fit * 1.08) return; // zoomed in: free panning
    final dx = _c.visibleRect.center.dx - _gestureStartCenter.dx;
    final threshold = _pageRect(_gestureStartPage).width * 0.12;
    final v = d.velocity.pixelsPerSecond.dx;
    var target = _gestureStartPage;
    if (dx > threshold || v < -350) target++;
    if (dx < -threshold || v > 350) target--;
    goToPage(target.clamp(1, _c.pageCount));
  }

  bool _onGeneralTap(BuildContext context, PdfViewerController c, PdfViewerGeneralTapHandlerDetails d) {
    widget.onInteraction();
    if (d.type == PdfViewerGeneralTapType.doubleTap) {
      final page = currentPage;
      final fit = _fitZoom(page);
      final target = _c.currentZoom > fit * 1.3 ? fit : fit * 2.2;
      _c.setZoom(d.documentPosition, target, duration: const Duration(milliseconds: 220));
      return true;
    }
    if (d.type != PdfViewerGeneralTapType.tap) return false;
    if (_c.textSelectionDelegate.hasSelectedText) {
      _c.textSelectionDelegate.clearTextSelection();
      return true;
    }
    // Tap on a highlight?
    final hit = _highlightAt(d.documentPosition);
    if (hit != null) {
      widget.onHighlightTap(hit);
      return true;
    }
    if (_pageMode) {
      final w = _c.viewSize.width;
      if (d.localPosition.dx < w * 0.22) {
        previousPage();
        return true;
      }
      if (d.localPosition.dx > w * 0.78) {
        nextPage();
        return true;
      }
    }
    widget.onTap();
    return true;
  }

  Highlight? _highlightAt(Offset docPos) {
    if (!_c.isReady) return null;
    final layouts = _c.layout.pageLayouts;
    for (var i = 0; i < layouts.length; i++) {
      if (!layouts[i].contains(docPos)) continue;
      final page = _c.pages[i];
      for (final h in widget.highlights.where((h) => h.page == i + 1)) {
        for (final r in decodeRects(h.rects)) {
          if (pdfRectToPage(r, page, layouts[i]).inflate(3).contains(docPos)) return h;
        }
      }
      break;
    }
    return null;
  }

  void _onSelection(PdfTextSelection sel) {
    final token = ++_selectionToken;
    _selDebounce?.cancel();
    if (!sel.hasSelectedText) {
      widget.onSelectionChanged(null);
      return;
    }
    // Wait until the handles settle before showing the toolbar.
    _selDebounce = Timer(const Duration(milliseconds: 250), () async {
      final ranges = await sel.getSelectedTextRanges();
      if (!mounted || token != _selectionToken) return;
      final segs = [for (final r in ranges) if (r.end > r.start) segmentFromRange(r)];
      widget.onSelectionChanged(segs.isEmpty ? null : ReaderSelection(segs));
    });
  }

  // ------------------------------------------------------------ painting

  void _paintHighlights(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    final list = widget.highlights.where((h) => h.page == page.pageNumber);
    for (final h in list) {
      final paint = Paint()
        ..color = ShelfColor.fromIndex(h.color).strong.withValues(alpha: 0.42)
        ..blendMode = BlendMode.multiply;
      for (final r in decodeRects(h.rects)) {
        final rr = pdfRectToPage(r, page, pageRect).inflate(1);
        canvas.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(2)), paint);
      }
    }
  }

  void _paintSearch(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    final marks = widget.searchMarks[page.pageNumber];
    if (marks == null) return;
    final paint = Paint()
      ..color = const Color(0xFFA58BF7).withValues(alpha: 0.45)
      ..blendMode = BlendMode.multiply;
    for (final r in marks) {
      final rr = pdfRectToPage(r, page, pageRect).inflate(2);
      canvas.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(3)), paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rr, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF7C5CF0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final filter = t.pageFilter;
    final viewer = PdfViewer.file(
      widget.book.filePath,
      // pdfrx only re-runs layoutPages on a fresh viewer, so switching
      // between Scroll and Page view rebuilds it.
      key: ValueKey(widget.mode),
      controller: _c,
      params: PdfViewerParams(
        margin: _margin,
        backgroundColor: Colors.transparent,
        pageDropShadow: t == ReaderTheme.night
            ? null
            : const BoxShadow(color: Color(0x1F161514), blurRadius: 10, offset: Offset(0, 3)),
        layoutPages: _pageMode ? _horizontalLayout : null,
        calculateInitialPageNumber: (doc, _) => widget.anchor.page.clamp(1, doc.pages.length),
        onViewerReady: (doc, controller) async {
          await goToAnchor(widget.anchor);
          if (!mounted) return;
          setState(() => _ready = true);
          widget.onReady();
        },
        onPageChanged: (p) {
          if (p != null) widget.onPageChanged(p);
        },
        onInteractionStart: _onInteractionStart,
        onInteractionEnd: _onInteractionEnd,
        onGeneralTap: _onGeneralTap,
        pagePaintCallbacks: [_paintHighlights, _paintSearch],
        textSelectionParams: PdfTextSelectionParams(
          onTextSelectionChange: _onSelection,
          showContextMenuAutomatically: false,
        ),
        buildContextMenu: (_, _) => null,
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => const SizedBox.shrink(),
        errorBannerBuilder: (context, error, stackTrace, documentRef) => _OpenError(error: error),
        scrollByArrowKey: 60,
      ),
    );

    return ColoredBox(
      color: t.canvas,
      child: filter == null ? viewer : ColorFiltered(colorFilter: filter, child: viewer),
    );
  }
}

class _OpenError extends StatelessWidget {
  const _OpenError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.x8),
        child: Text(
          error is PdfPasswordException
              ? 'This PDF is password-protected.'
              : 'Folio couldn’t open this PDF. The file may be damaged.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium,
        ),
      ),
    );
  }
}
