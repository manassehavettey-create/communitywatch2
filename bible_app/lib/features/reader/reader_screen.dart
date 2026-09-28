import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';

import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/reader_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/db/database.dart';
import '../../data/repos/annotations_repository.dart';
import '../audio/audio_sheet.dart';
import 'chapter_view.dart';
import 'passage_text.dart';
import 'reader_sheets.dart';
import 'verse_actions.dart';

/// Where to open the reader.
class ReaderArgs {
  const ReaderArgs({
    required this.target,
    this.flash,
    this.planProgressId,
    this.planDay,
  });

  final VerseRef target;

  /// Range to briefly emphasise on arrival (from search, saved items...).
  final VerseRange? flash;
  final String? planProgressId;
  final int? planDay;

  /// Builds args from route query parameters, e.g.
  /// `/read?r=JHN.3.16&flash=JHN.3.16-JHN.3.18&plan=<id>&day=3`.
  static ReaderArgs fromQuery(Map<String, String> q) {
    VerseRef target = const VerseRef('JHN', 1, 1);
    VerseRange? flash;
    try {
      final r = q['r'];
      if (r != null) {
        final parts = r.split('.');
        target = parts.length == 2
            ? VerseRef(parts[0], int.parse(parts[1]), 1)
            : VerseRef.parseCode(r);
        target.book; // validate
      }
      if (q['flash'] != null) flash = VerseRange.parseCode(q['flash']!);
    } on Object {
      target = const VerseRef('JHN', 1, 1);
      flash = null;
    }
    return ReaderArgs(
      target: target,
      flash: flash,
      planProgressId: q['plan'],
      planDay: int.tryParse(q['day'] ?? ''),
    );
  }

  static String location(
    VerseRef target, {
    VerseRange? flash,
    String? plan,
    int? day,
  }) {
    final q = <String, String>{
      'r': target.code,
      'flash': ?flash?.code,
      'plan': ?plan,
      if (day != null) 'day': '$day',
    };
    return Uri(path: '/read', queryParameters: q).toString();
  }
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.args});

  final ReaderArgs args;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  static const _topBar = 64.0;

  late ChapterRef _anchor;
  final _before = <ChapterRef>[];
  final _after = <ChapterRef>[];
  final _keys = <ChapterRef, GlobalKey<ChapterViewState>>{};
  final _centerKey = GlobalKey();
  ScrollController _scroll = ScrollController();
  int _generation = 0;

  final _selected = <VerseRef>{};
  Set<VerseRef> _flash = {};
  late VerseRef _top;
  int? _pendingJump;
  bool _chrome = true;

  Timer? _positionSave;
  Timer? _tracker;
  bool _foreground = true;
  final _dwell = <ChapterRef, int>{};
  final _recorded = <ChapterRef>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final t = widget.args.target;
    _top = t;
    _resetTo(t.chapterRef, jumpTo: t.verse);
    if (widget.args.flash != null) {
      final f = widget.args.flash!;
      // Emphasise the range within its first chapter.
      final last = f.start.chapterRef == f.end.chapterRef ? f.end.verse : 999;
      _flash = {
        for (var v = f.start.verse; v <= last; v++)
          VerseRef(f.start.bookId, f.start.chapter, v),
      };
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _flash = {});
      });
    }
    _tracker = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _trackReading(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _positionSave?.cancel();
    _tracker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  // ----------------------------------------------------------- chapter list

  void _resetTo(ChapterRef chapter, {int? jumpTo}) {
    _anchor = chapter;
    _before.clear();
    _after
      ..clear()
      ..add(chapter);
    final next = chapter.next;
    if (next != null) _after.add(next);
    _keys.clear();
    final old = _scroll;
    _scroll = ScrollController();
    if (_generation > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _generation++;
    _pendingJump = (jumpTo ?? 1) > 1 ? jumpTo : null;
    if (_pendingJump != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _performJump());
    }
  }

  void _performJump() {
    final v = _pendingJump;
    if (v == null || !mounted) return;
    final state = _keys[_anchor]?.currentState;
    final offset = state?.offsetOfVerse(v);
    if (offset == null || !_scroll.hasClients) {
      // Layout not ready yet; try again after the next frame (and make
      // sure there is one).
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _performJump())
        ..scheduleFrame();
      return;
    }
    _pendingJump = null;
    _scroll.jumpTo(
      (offset - Space.x4).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ),
    );
  }

  void _goTo(VerseRef v) {
    setState(() {
      _selected.clear();
      _top = v;
      _resetTo(v.chapterRef, jumpTo: v.verse);
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final pos = n.metrics;
    if (pos.extentAfter < 2500) {
      final next = _after.last.next;
      if (next != null) setState(() => _after.add(next));
    }
    if (pos.pixels - pos.minScrollExtent < 2500) {
      final prev = (_before.isEmpty ? _anchor : _before.last).previous;
      if (prev != null) setState(() => _before.add(prev));
    }
    if (n is UserScrollNotification) {
      final dir = n.direction;
      if (dir == ScrollDirection.reverse && _chrome && _selected.isEmpty) {
        setState(() => _chrome = false);
      } else if (dir == ScrollDirection.forward && !_chrome) {
        setState(() => _chrome = true);
      }
    }
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      _updateTopVerse();
    }
    return false;
  }

  void _updateTopVerse() {
    final probeY = MediaQuery.paddingOf(context).top + _topBar + 8;
    final probeX = MediaQuery.sizeOf(context).width / 2;
    for (final e in _keys.entries) {
      final state = e.value.currentState;
      final box = state?.context.findRenderObject() as RenderBox?;
      if (state == null || box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (probeY < top || probeY > top + box.size.height) continue;
      final v =
          state.verseAtGlobal(Offset(probeX, probeY)) ??
          state.firstVerseBelowGlobal(probeY) ??
          1;
      final verse = VerseRef(e.key.bookId, e.key.chapter, v);
      if (verse != _top) {
        final chapterChanged = verse.chapterRef != _top.chapterRef;
        _top = verse;
        if (chapterChanged) setState(() {});
        _positionSave?.cancel();
        _positionSave = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(preferencesRepositoryProvider).setLastPosition(_top);
          }
        });
      }
      return;
    }
  }

  // ----------------------------------------------------------- reading log

  void _trackReading() {
    if (!mounted || !_foreground) return;
    final chapter = _top.chapterRef;
    final seconds = (_dwell[chapter] ?? 0) + 5;
    _dwell[chapter] = seconds;
    if (_recorded.contains(chapter)) return;
    final bible = ref.read(currentBibleProvider).value;
    final verses = bible?.chapter(chapter)?.verseCount ?? 20;
    // About 40% of an unhurried read of this chapter, within 15–90 s.
    final needed = (verses * 2.7).clamp(15, 90);
    if (seconds >= needed) {
      _recorded.add(chapter);
      ref
          .read(readingRepositoryProvider)
          .recordChapterRead(chapter, seconds: seconds);
    }
  }

  // ------------------------------------------------------------- selection

  void _toggle(ChapterRef c, int verse) {
    Haptics.select();
    final v = VerseRef(c.bookId, c.chapter, verse);
    setState(() {
      if (!_selected.remove(v)) _selected.add(v);
      _chrome = true;
    });
  }

  void _clearSelection() => setState(_selected.clear);

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsValueProvider);
    final bibleAsync = ref.watch(currentBibleProvider);
    final brightness = Theme.of(context).brightness;
    final theme = ReaderTheme.resolve(prefs.readerTheme, brightness);
    final style = ReaderStyle(
      theme: theme,
      font: prefs.font,
      fontSize: prefs.fontSize,
      lineHeight: prefs.lineHeight,
      showVerseNumbers: prefs.showVerseNumbers,
      paragraphMode: prefs.paragraphMode,
      suppliedItalics: prefs.suppliedItalics,
    );

    // Switching translation keeps the passage in view.
    ref.listen(currentBibleProvider, (prev, next) {
      final before = prev?.value?.info.id;
      final after = next.value?.info.id;
      if (before != null && after != null && before != after) {
        setState(() => _resetTo(_top.chapterRef, jumpTo: _top.verse));
      }
    });

    final overlayStyle = theme.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: AnimatedContainer(
        duration: Motion.of(context).slow,
        color: theme.background,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: bibleAsync.when(
            loading: () => _LoadingReader(theme: theme),
            error: (e, _) => _ReaderError(message: '$e', theme: theme),
            data: (bible) => _buildReader(context, bible, style),
          ),
        ),
      ),
    );
  }

  Widget _buildReader(
    BuildContext context,
    BibleText bible,
    ReaderStyle style,
  ) {
    final m = Motion.of(context);
    final pad = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 720 ? (width - 640) / 2 : 24.0;
    final passage = PassageText(bible);

    Widget chapterItem(ChapterRef c) {
      final text = bible.chapter(c);
      if (text == null) return const SizedBox.shrink();
      final key = _keys.putIfAbsent(c, GlobalKey<ChapterViewState>.new);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: side),
        child: Consumer(
          builder: (context, ref, _) {
            final ann =
                ref.watch(chapterAnnotationsProvider(c)).value ??
                ChapterAnnotations.empty;
            return ChapterView(
              key: key,
              chapter: text,
              translation: bible.info,
              style: style,
              annotations: ann,
              selected: {
                for (final v in _selected)
                  if (v.chapterRef == c) v.verse,
              },
              flash: {
                for (final v in _flash)
                  if (v.chapterRef == c) v.verse,
              },
              onVerseTap: (v) => _toggle(c, v),
            );
          },
        ),
      );
    }

    final scrollView = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        key: ValueKey(_generation),
        controller: _scroll,
        center: _centerKey,
        slivers: [
          SliverList.builder(
            itemCount: _before.length,
            itemBuilder: (context, i) => chapterItem(_before[i]),
          ),
          SliverPadding(
            key: _centerKey,
            padding: EdgeInsets.only(top: pad.top + _topBar),
            sliver: SliverList.builder(
              itemCount: _after.length,
              itemBuilder: (context, i) => chapterItem(_after[i]),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 220)),
        ],
      ),
    );

    final hasPlan =
        widget.args.planProgressId != null && widget.args.planDay != null;

    return Stack(
      children: [
        Positioned.fill(child: scrollView),
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: _chrome ? Offset.zero : const Offset(0, -1),
            duration: m.base,
            curve: m.standard,
            child: _TopBar(
              theme: style.theme,
              // Short book names keep the title readable on phones.
              title: width < 430
                  ? '${_top.chapterRef.book.abbr} ${_top.chapterRef.chapter}'
                  : _top.chapterRef.label,
              translation: bible.info.abbreviation,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/bible'),
              onPickChapter: () => _openChapterPicker(context),
              onTranslation: () => showAppSheet(
                context,
                builder: (_) => const TranslationSheet(),
              ),
              onSearch: () => context.push('/search'),
              onAudio: () => showAppSheet(
                context,
                builder: (_) => AudioSheet(chapter: _top.chapterRef),
              ),
              onSettings: () => showAppSheet(
                context,
                builder: (_) => const ReaderSettingsSheet(),
              ),
            ),
          ),
        ),
        // Selection panel / plan pill
        Positioned(
          left: 12,
          right: 12,
          bottom: pad.bottom + 12,
          child: AnimatedSwitcher(
            duration: m.base,
            switchInCurve: m.standard,
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: _selected.isNotEmpty
                ? _buildActions(context, bible, passage)
                : hasPlan
                ? _PlanPill(
                    key: const ValueKey('plan'),
                    day: widget.args.planDay!,
                    onDone: () => _completePlanDay(context),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    BibleText bible,
    PassageText passage,
  ) {
    final runs = passage.runs(_selected);
    final full = VerseRange(runs.first.start, runs.last.end);
    final annRepo = ref.read(annotationsRepositoryProvider);
    // Annotations for the chapters in the selection.
    final chapters = {for (final v in _selected) v.chapterRef};
    final anns = [
      for (final c in chapters)
        ref.watch(chapterAnnotationsProvider(c)).value ??
            ChapterAnnotations.empty,
    ];
    HighlightColor? common;
    var first = true;
    for (final v in _selected) {
      HighlightColor? h;
      for (final a in anns) {
        h ??= a.highlightFor(v);
      }
      if (first) {
        common = h;
        first = false;
      } else if (common != h) {
        common = null;
      }
    }
    final notes = <String, Note>{
      for (final a in anns)
        for (final n in a.notes)
          if (n.startKey <= full.end.key && n.endKey >= full.start.key) n.id: n,
    }.values.toList();
    final bookmarked = anns.any(
      (a) => a.bookmarks.any(
        (b) => b.startKey == full.start.key && b.endKey == full.end.key,
      ),
    );

    return VerseActionsPanel(
      key: const ValueKey('actions'),
      label: passage.label(_selected),
      currentHighlight: common,
      bookmarked: bookmarked,
      noteCount: notes.length,
      onHighlight: (c) async {
        await annRepo.highlight(runs, c);
        _clearSelection();
      },
      onClearHighlight: () async {
        await annRepo.removeHighlight(runs);
        _clearSelection();
      },
      onBookmark: () async {
        Haptics.light();
        await annRepo.toggleBookmark(full, bible.info.id);
      },
      onNote: () =>
          _editNote(context, full, notes.isEmpty ? null : notes.first),
      onCopy: () async {
        await Clipboard.setData(
          ClipboardData(text: passage.shareText(_selected)),
        );
        if (context.mounted) toast(context, 'Copied');
        _clearSelection();
      },
      onShareText: () async {
        final text = passage.shareText(_selected);
        _clearSelection();
        await SharePlus.instance.share(ShareParams(text: text));
      },
      onShareCard: () {
        final range = full;
        _clearSelection();
        context.push(
          Uri(
            path: '/share',
            queryParameters: {'r': range.code, 't': bible.info.id},
          ).toString(),
        );
      },
      onSave: () async {
        await annRepo.saveVerses(full, bible.info.id, passage.body(_selected));
        if (context.mounted) toast(context, 'Saved');
        _clearSelection();
      },
      onClose: _clearSelection,
    );
  }

  Future<void> _editNote(
    BuildContext context,
    VerseRange range,
    Note? existing,
  ) async {
    final label = PassageText(ref.read(currentBibleProvider).value!)
        .label(_selected);
    final result = await showAppSheet<String>(
      context,
      builder: (_) => NoteEditorSheet(
        reference: label,
        initial: existing?.body ?? '',
        existing: existing != null,
      ),
    );
    if (result == null) return;
    final repo = ref.read(annotationsRepositoryProvider);
    if (existing != null && result.isEmpty) {
      await repo.deleteNote(existing.id);
    } else if (result.isNotEmpty) {
      await repo.saveNote(id: existing?.id, r: range, body: result);
    }
    _clearSelection();
  }

  Future<void> _openChapterPicker(BuildContext context) async {
    final picked = await showAppSheet<ChapterRef>(
      context,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            const SheetHeader(title: 'Go to'),
            Expanded(
              child: PrimaryScrollController(
                controller: controller,
                child: ChapterPicker(
                  current: _top.chapterRef,
                  onPicked: (c) => Navigator.pop(context, c),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) _goTo(VerseRef(picked.bookId, picked.chapter, 1));
  }

  Future<void> _completePlanDay(BuildContext context) async {
    final plans = await ref.read(userPlansProvider.future);
    final plan = plans
        .where((p) => p.progressId == widget.args.planProgressId)
        .firstOrNull;
    if (plan == null) return;
    Haptics.success();
    await ref
        .read(plansRepositoryProvider)
        .setDayComplete(
          plan.progressId,
          widget.args.planDay!,
          true,
          totalDays: plan.plan.totalDays,
        );
    // Also count the passage as read.
    for (final p in plan.plan.readingFor(widget.args.planDay!)) {
      for (final c in p.chapters) {
        if (_recorded.add(c)) {
          await ref
              .read(readingRepositoryProvider)
              .recordChapterRead(c, seconds: _dwell[c] ?? 0);
        }
      }
    }
    if (context.mounted) context.pop(true);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.theme,
    required this.title,
    required this.translation,
    required this.onBack,
    required this.onPickChapter,
    required this.onTranslation,
    required this.onSearch,
    required this.onAudio,
    required this.onSettings,
  });

  final ReaderTheme theme;
  final String title;
  final String translation;
  final VoidCallback onBack;
  final VoidCallback onPickChapter;
  final VoidCallback onTranslation;
  final VoidCallback onSearch;
  final VoidCallback onAudio;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final chipBg = theme.text.withValues(alpha: 0.08);
    Widget icon(IconData i, String tip, VoidCallback onTap) => CircleIconButton(
      icon: i,
      tooltip: tip,
      size: 40,
      background: chipBg,
      foreground: theme.text,
      onPressed: onTap,
    );
    return Container(
      color: theme.background,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              icon(PhosphorIconsBold.caretLeft, 'Back', onBack),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Choose chapter, currently $title',
                  child: Pressable(
                    onTap: onPickChapter,
                    child: Row(
                      children: [
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: m.fast,
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, 0.3),
                                  end: Offset.zero,
                                ).animate(a),
                                child: c,
                              ),
                            ),
                            child: Text(
                              title,
                              key: ValueKey(title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.titleM.copyWith(color: theme.text),
                            ),
                          ),
                        ),
                        Icon(
                          PhosphorIconsBold.caretDown,
                          size: 14,
                          color: theme.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Translation $translation',
                child: Pressable(
                  onTap: onTranslation,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: Radii.pillAll,
                    ),
                    child: Text(
                      translation,
                      style: AppType.label.copyWith(color: theme.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              icon(PhosphorIconsRegular.magnifyingGlass, 'Search', onSearch),
              const SizedBox(width: 6),
              icon(PhosphorIconsRegular.headphones, 'Audio', onAudio),
              const SizedBox(width: 6),
              icon(PhosphorIconsRegular.textAa, 'Reading settings', onSettings),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({super.key, required this.day, required this.onDone});

  final int day;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PillButton(
        label: 'Mark day $day complete',
        icon: PhosphorIconsBold.check,
        variant: PillVariant.accent,
        onPressed: onDone,
      ),
    );
  }
}

class _LoadingReader extends StatelessWidget {
  const _LoadingReader({required this.theme});

  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 88, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Skeleton(width: 180, height: 32),
            SizedBox(height: 28),
            SkeletonParagraph(lines: 6, lineHeight: 16),
            SizedBox(height: 16),
            SkeletonParagraph(lines: 5, lineHeight: 16),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message, required this.theme});

  final String message;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'This translation could not be opened.\n$message',
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: theme.text),
        ),
      ),
    );
  }
}
