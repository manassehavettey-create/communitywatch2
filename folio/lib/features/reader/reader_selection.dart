import 'dart:ui';

import 'package:pdfrx/pdfrx.dart';

/// One page's worth of selected text. Selections that cross pages become
/// several segments (and several highlights).
class SelectionSegment {
  const SelectionSegment({
    required this.page,
    required this.start,
    required this.end,
    required this.text,
    required this.rects,
  });

  final int page;

  /// Character range in the page text, [start, end).
  final int start;
  final int end;
  final String text;

  /// Line rects in PDF page coordinates (points, origin bottom-left),
  /// encoded as Rect.fromLTRB(left, top, right, bottom).
  final List<Rect> rects;
}

class ReaderSelection {
  const ReaderSelection(this.segments);
  final List<SelectionSegment> segments;

  bool get isEmpty => segments.isEmpty || text.trim().isEmpty;
  String get text => segments.map((s) => s.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  int get firstPage => segments.first.page;
}

/// Builds a selection segment from a text range on a page, with line rects
/// merged so a highlight paints as clean bars rather than per-word boxes.
SelectionSegment segmentFromRange(PdfPageTextRange range) {
  final rects = <Rect>[
    for (final f in range.enumerateFragmentBoundingRects())
      Rect.fromLTRB(f.bounds.left, f.bounds.top, f.bounds.right, f.bounds.bottom),
  ];
  return SelectionSegment(
    page: range.pageNumber,
    start: range.start,
    end: range.end,
    text: range.text,
    rects: mergeLineRects(rects),
  );
}

/// Segment for [start, end) of [text] (used by Text view, whose offsets map
/// 1:1 onto the PDF page text).
SelectionSegment segmentFromIndices(PdfPageText text, int start, int end) {
  final s = start.clamp(0, text.fullText.length);
  final e = end.clamp(s, text.fullText.length);
  if (e <= s) {
    return SelectionSegment(page: text.pageNumber, start: s, end: e, text: '', rects: const []);
  }
  return segmentFromRange(text.getRangeFromAB(s, e - 1));
}

/// Merges rects that sit on the same line (PDF coordinates: top > bottom).
List<Rect> mergeLineRects(List<Rect> input) {
  final rects = input.where((r) => r.width > 0 && (r.top - r.bottom).abs() > 0).toList()
    ..sort((a, b) {
      final c = b.top.compareTo(a.top);
      return c != 0 ? c : a.left.compareTo(b.left);
    });
  final out = <Rect>[];
  for (final r in rects) {
    if (out.isNotEmpty) {
      final last = out.last;
      final h = (last.top - last.bottom).abs();
      final overlap = (last.top < r.top ? last.top : r.top) - (last.bottom > r.bottom ? last.bottom : r.bottom);
      final sameLine = overlap > h * 0.5;
      final gap = r.left - last.right;
      if (sameLine && gap < h * 1.2) {
        out[out.length - 1] = Rect.fromLTRB(
          last.left < r.left ? last.left : r.left,
          last.top > r.top ? last.top : r.top,
          last.right > r.right ? last.right : r.right,
          last.bottom < r.bottom ? last.bottom : r.bottom,
        );
        continue;
      }
    }
    out.add(r);
  }
  return out;
}

/// Converts a stored PDF-space rect to a rect on the rendered page.
Rect pdfRectToPage(Rect r, PdfPage page, Rect pageRect) {
  final pr = PdfRect(r.left, r.top, r.right, r.bottom);
  return pr.toRect(page: page, scaledPageSize: pageRect.size).translate(pageRect.left, pageRect.top);
}
