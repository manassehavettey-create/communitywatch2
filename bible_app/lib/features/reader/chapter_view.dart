import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/reader_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/repos/annotations_repository.dart';

/// Typography and display options for the reader.
class ReaderStyle {
  const ReaderStyle({
    required this.theme,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.showVerseNumbers,
    required this.paragraphMode,
    required this.suppliedItalics,
  });

  final ReaderTheme theme;
  final ScriptureFont font;
  final double fontSize;
  final double lineHeight;
  final bool showVerseNumbers;
  final bool paragraphMode;
  final bool suppliedItalics;

  TextStyle get body => fontStyle(
    font.family,
    size: fontSize,
    height: lineHeight,
    color: theme.text,
    variable: font.variable,
  );
}

/// One block of a chapter: a heading, or a run of verses shown as one
/// paragraph.
sealed class _Block {}

class _HeadingBlock extends _Block {
  _HeadingBlock(this.text, {this.colophon = false});
  final String text;
  final bool colophon;
}

class _VerseBlock extends _Block {
  _VerseBlock(this.verses);
  final List<int> verses;
}

List<_Block> _blocksFor(ChapterText ch, {required bool paragraphMode}) {
  final blocks = <_Block>[];
  final before = <int, List<Heading>>{};
  final after = <int, List<Heading>>{};
  for (final h in ch.headings) {
    if (h.before != null) before.putIfAbsent(h.before!, () => []).add(h);
    if (h.after != null) after.putIfAbsent(h.after!, () => []).add(h);
  }
  // Translations without paragraph data read better one verse per line.
  final usesParagraphs = paragraphMode && ch.paragraphStarts.isNotEmpty;
  var current = <int>[];
  void flush() {
    if (current.isNotEmpty) blocks.add(_VerseBlock(current));
    current = <int>[];
  }

  for (var v = 1; v <= ch.verseCount; v++) {
    if (before[v] != null) {
      flush();
      blocks.addAll(before[v]!.map((h) => _HeadingBlock(h.text)));
    }
    if (ch.isOmitted(v)) continue;
    final startsBlock = !usesParagraphs || ch.paragraphStarts.contains(v);
    if (startsBlock) flush();
    current.add(v);
    if (after[v] != null) {
      flush();
      blocks.addAll(
        after[v]!.map((h) => _HeadingBlock(h.text, colophon: true)),
      );
    }
  }
  flush();
  return blocks;
}

/// Renders one chapter and maps between screen positions and verses.
class ChapterView extends StatefulWidget {
  const ChapterView({
    super.key,
    required this.chapter,
    required this.translation,
    required this.style,
    required this.annotations,
    required this.selected,
    required this.flash,
    required this.onVerseTap,
  });

  final ChapterText chapter;
  final TranslationInfo translation;
  final ReaderStyle style;
  final ChapterAnnotations annotations;
  final Set<int> selected;

  /// Verses to briefly emphasise (after jumping to a reference).
  final Set<int> flash;
  final ValueChanged<int> onVerseTap;

  @override
  State<ChapterView> createState() => ChapterViewState();
}

class ChapterViewState extends State<ChapterView>
    with SingleTickerProviderStateMixin {
  late List<_Block> _blocks;
  final _blockKeys = <GlobalKey>[];

  /// For each verse block: (verse, start offset, end offset) in its text.
  final _ranges = <int, List<(int, int, int)>>{};

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: MotionTokens.base,
    value: 1,
  );
  Map<int, Color?> _from = const {};
  Map<int, Color?> _to = const {};

  @override
  void initState() {
    super.initState();
    _rebuildBlocks();
  }

  @override
  void didUpdateWidget(ChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter != widget.chapter ||
        oldWidget.style.paragraphMode != widget.style.paragraphMode) {
      _rebuildBlocks();
    }
    _updateColors(context.palette);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fade.duration = Motion.of(context).base;
    _updateColors(context.palette);
  }

  void _rebuildBlocks() {
    _blocks = _blocksFor(
      widget.chapter,
      paragraphMode: widget.style.paragraphMode,
    );
    _blockKeys
      ..clear()
      ..addAll(List.generate(_blocks.length, (_) => GlobalKey()));
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Color? _targetColor(int v, AppPalette p) {
    final ref = VerseRef(
      widget.chapter.ref.bookId,
      widget.chapter.ref.chapter,
      v,
    );
    final dark = widget.style.theme.isDark;
    if (widget.selected.contains(v)) {
      return p.tangerine.withValues(alpha: dark ? 0.26 : 0.18);
    }
    if (widget.flash.contains(v)) {
      return p.butter.withValues(alpha: dark ? 0.3 : 0.5);
    }
    return widget.annotations.highlightFor(ref)?.fill(p, darkBackground: dark);
  }

  void _updateColors(AppPalette p) {
    final next = {
      for (var v = 1; v <= widget.chapter.verseCount; v++)
        v: _targetColor(v, p),
    };
    bool same = next.length == _to.length;
    if (same) {
      for (final e in next.entries) {
        if (_to[e.key] != e.value) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
    if (_to.isEmpty) {
      // First paint: no animation.
      _from = _to = next;
      return;
    }
    // Start from whatever is on screen now, mid-animation or not.
    final t = MotionTokens.standard.transform(_fade.value);
    _from = {for (final v in next.keys) v: Color.lerp(_from[v], _to[v], t)};
    _to = next;
    _fade.forward(from: 0);
  }

  Color? _colorAt(int v) {
    final t = MotionTokens.standard.transform(_fade.value);
    return Color.lerp(_from[v], _to[v], t);
  }

  // ------------------------------------------------------- position mapping

  /// The verse at a global y position (null if outside this chapter's text).
  int? verseAtGlobal(Offset global) {
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (block is! _VerseBlock) continue;
      final box =
          _blockKeys[i].currentContext?.findRenderObject() as RenderParagraph?;
      if (box == null || !box.attached) continue;
      final local = box.globalToLocal(global);
      if (local.dy < 0 || local.dy > box.size.height) continue;
      final pos = box.getPositionForOffset(
        Offset(local.dx.clamp(0, box.size.width), local.dy),
      );
      return _verseAtOffset(i, pos.offset);
    }
    return null;
  }

  /// First verse whose block starts at or below [global]'s y, for when the
  /// point falls between blocks.
  int? firstVerseBelowGlobal(double globalY) {
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (block is! _VerseBlock) continue;
      final box =
          _blockKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      if (bottom >= globalY) {
        return verseAtGlobal(
              Offset(box.localToGlobal(Offset.zero).dx + 1, globalY),
            ) ??
            block.verses.first;
      }
    }
    return null;
  }

  int? _verseAtOffset(int blockIndex, int offset) {
    final ranges = _ranges[blockIndex];
    if (ranges == null || ranges.isEmpty) return null;
    for (final (v, s, e) in ranges) {
      if (offset >= s && offset < e) return v;
    }
    return offset < ranges.first.$2 ? ranges.first.$1 : ranges.last.$1;
  }

  /// Distance of [verse]'s first line from the top of this chapter view.
  double? offsetOfVerse(int verse) {
    final chapterBox = context.findRenderObject() as RenderBox?;
    if (chapterBox == null) return null;
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (block is! _VerseBlock || !block.verses.contains(verse)) continue;
      final para =
          _blockKeys[i].currentContext?.findRenderObject() as RenderParagraph?;
      if (para == null) return null;
      final start = _ranges[i]!.firstWhere((r) => r.$1 == verse).$2;
      final caret = para.getOffsetForCaret(
        TextPosition(offset: start),
        Rect.zero,
      );
      final inChapter = para.localToGlobal(caret, ancestor: chapterBox);
      return inChapter.dy;
    }
    return null;
  }

  // ------------------------------------------------------------- building

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.style;
    final ref = widget.chapter.ref;
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChapterHeading(ref: ref, style: s),
          for (var i = 0; i < _blocks.length; i++) _buildBlock(i, p),
          const SizedBox(height: Space.x10),
        ],
      ),
    );
  }

  Widget _buildBlock(int i, AppPalette p) {
    final s = widget.style;
    final block = _blocks[i];
    switch (block) {
      case _HeadingBlock(:final text, :final colophon):
        return Padding(
          key: _blockKeys[i],
          padding: EdgeInsets.only(
            top: colophon ? s.fontSize : s.fontSize * 0.4,
            bottom: s.fontSize * 0.6,
          ),
          child: Text(
            VerseText.plain(
              text,
              suppliedWords: widget.translation.suppliedWords,
            ),
            style: fontStyle(
              s.font.family,
              size: s.fontSize * 0.82,
              height: 1.4,
              color: s.theme.muted,
              style: FontStyle.italic,
              variable: s.font.variable,
            ),
          ),
        );
      case _VerseBlock(:final verses):
        final spans = <InlineSpan>[];
        final ranges = <(int, int, int)>[];
        var cursor = 0;
        final ref = widget.chapter.ref;
        for (final v in verses) {
          final start = cursor;
          final vref = VerseRef(ref.bookId, ref.chapter, v);
          final bg = _colorAt(v);
          final selected = widget.selected.contains(v);
          // Verse number (verse 1 is implied by the chapter heading).
          if (s.showVerseNumbers && v != 1) {
            final label = '$v ';
            spans.add(
              TextSpan(
                text: label,
                style: fontStyle(
                  Fonts.ui,
                  size: s.fontSize * 0.62,
                  weight: FontWeight.w700,
                  color: selected ? p.tangerineText : s.theme.muted,
                ),
              ),
            );
            cursor += label.length;
          }
          if (widget.annotations.isBookmarked(vref)) {
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Icon(
                    PhosphorIconsFill.bookmarkSimple,
                    size: s.fontSize * 0.7,
                    color: p.tangerine,
                    semanticLabel: 'Bookmarked',
                  ),
                ),
              ),
            );
            cursor += 1;
          }
          final text = widget.chapter.verse(v);
          final runs = VerseText.runs(
            text,
            suppliedWords: widget.translation.suppliedWords,
          );
          for (final (run, supplied) in runs) {
            spans.add(
              TextSpan(
                text: run,
                style: TextStyle(
                  backgroundColor: bg,
                  fontStyle: supplied && s.suppliedItalics
                      ? FontStyle.italic
                      : null,
                  decoration: selected ? TextDecoration.underline : null,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: p.tangerine,
                  decorationThickness: 2,
                ),
              ),
            );
            cursor += run.length;
          }
          if (widget.annotations.hasNote(vref)) {
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    PhosphorIconsFill.notePencil,
                    size: s.fontSize * 0.72,
                    color: s.theme.muted,
                    semanticLabel: 'Has a note',
                  ),
                ),
              ),
            );
            cursor += 1;
          }
          spans.add(const TextSpan(text: ' '));
          cursor += 1;
          ranges.add((v, start, cursor));
        }
        _ranges[i] = ranges;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final para =
                _blockKeys[i].currentContext?.findRenderObject()
                    as RenderParagraph?;
            if (para == null) return;
            final pos = para.getPositionForOffset(d.localPosition);
            final v = _verseAtOffset(i, pos.offset);
            if (v != null) widget.onVerseTap(v);
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: s.fontSize * (s.paragraphMode ? 0.7 : 0.35),
            ),
            child: RichText(
              key: _blockKeys[i],
              textScaler: MediaQuery.textScalerOf(context),
              text: TextSpan(style: s.body, children: spans),
            ),
          ),
        );
    }
  }
}

class _ChapterHeading extends StatelessWidget {
  const _ChapterHeading({required this.ref, required this.style});

  final ChapterRef ref;
  final ReaderStyle style;

  @override
  Widget build(BuildContext context) {
    final showBook = ref.chapter == 1;
    return Semantics(
      header: true,
      label: ref.label,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(
            top: showBook ? Space.x6 : Space.x4,
            bottom: Space.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBook)
                Text(
                  ref.book.name,
                  style: AppType.displayM.copyWith(color: style.theme.text),
                ),
              Text(
                showBook ? 'Chapter 1' : '${ref.book.name} ${ref.chapter}',
                style: showBook
                    ? AppType.label.copyWith(color: style.theme.muted)
                    : AppType.displayS.copyWith(color: style.theme.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
