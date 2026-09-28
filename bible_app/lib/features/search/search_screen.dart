import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../bible/reference_parser.dart';
import '../../bible/references.dart';
import '../../bible/search.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/skeleton.dart';
import '../reader/reader_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _recentKey = 'search.recent';
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SearchScope _scope = SearchScope.all;
  SearchResults? _results;
  bool _searching = false;
  int _token = 0;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(q));
  }

  Future<void> _run(String q) async {
    final query = q.trim();
    setState(() => _query = query);
    if (query.length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    final token = ++_token;
    setState(() => _searching = true);
    final translation = await ref.read(currentTranslationProvider.future);
    final index = await ref
        .read(bibleRepositoryProvider)
        .searchIndex(translation);
    final results = index.search(SearchQuery.parse(query), scope: _scope);
    if (!mounted || token != _token) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<List<String>> _recent() async {
    final raw = await ref.read(databaseProvider).getValue(_recentKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> _remember(String q) async {
    final list = [
      q,
      ...(await _recent()).where((r) => r != q),
    ].take(8).toList();
    await ref.read(databaseProvider).setValue(_recentKey, jsonEncode(list));
  }

  void _open(VerseRef start, {VerseRange? flash}) {
    if (_query.isNotEmpty) _remember(_query);
    context.push(ReaderArgs.location(start, flash: flash));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parsed = _query.isEmpty ? null : ReferenceParser.parse(_query);
    final books = _query.isEmpty || (parsed != null && !parsed.isBookOnly)
        ? const []
        : ReferenceParser.suggestBooks(_query, limit: 4);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x3,
                Space.x3,
                Space.gutter,
                Space.x3,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.caretLeft,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: _run,
                      style: AppType.body.copyWith(color: p.ink),
                      decoration: InputDecoration(
                        hintText: 'Words, "a phrase", or John 3:16',
                        prefixIcon: Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          color: p.inkMute,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: Icon(
                                  PhosphorIconsRegular.xCircle,
                                  color: p.inkMute,
                                ),
                                onPressed: () {
                                  _controller.clear();
                                  _run('');
                                },
                              ),
                        border: const OutlineInputBorder(
                          borderRadius: Radii.pillAll,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: Radii.pillAll,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: Radii.pillAll,
                          borderSide: BorderSide(color: p.ink, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ChipRow<SearchScope>(
              options: SearchScope.values,
              selected: _scope,
              labelOf: (s) => s.label,
              onSelected: (s) {
                setState(() => _scope = s);
                _run(_query);
              },
            ),
            const SizedBox(height: Space.x2),
            Expanded(
              child: _query.length < 2 && parsed == null
                  ? _Recent(
                      load: _recent,
                      onPick: (q) {
                        _controller.text = q;
                        _run(q);
                      },
                    )
                  : CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (parsed != null && !parsed.isBookOnly)
                          SliverToBoxAdapter(
                            child: Reveal(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.gutter,
                                  Space.x2,
                                  Space.gutter,
                                  Space.x2,
                                ),
                                child: PastelCard(
                                  color: p.butter,
                                  radius: Radii.md,
                                  padding: const EdgeInsets.all(Space.x4),
                                  semanticLabel: 'Go to ${parsed.label}',
                                  onTap: () => _open(
                                    parsed.range?.start ??
                                        VerseRef(
                                          parsed.book.id,
                                          parsed.chapter!,
                                          1,
                                        ),
                                    flash: parsed.range,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        PhosphorIconsBold.arrowBendDownRight,
                                      ),
                                      const SizedBox(width: Space.x3),
                                      Expanded(
                                        child: Text(
                                          'Go to ${parsed.label}',
                                          style: AppType.titleS.copyWith(
                                            color: p.onPastel,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (books.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 52,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.gutter,
                                  vertical: 4,
                                ),
                                children: [
                                  for (final b in books)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: Space.x2,
                                      ),
                                      child: PillButton(
                                        label: b.name,
                                        icon: PhosphorIconsRegular.bookOpen,
                                        compact: true,
                                        variant: PillVariant.tonal,
                                        onPressed: () =>
                                            _open(VerseRef(b.id, 1, 1)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_searching && _results == null)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(Space.gutter),
                              child: Column(
                                children: [
                                  SkeletonParagraph(lines: 3),
                                  SizedBox(height: 16),
                                  SkeletonParagraph(lines: 3),
                                ],
                              ),
                            ),
                          )
                        else if (_results != null) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.gutter,
                                Space.x3,
                                Space.gutter,
                                Space.x2,
                              ),
                              child: Text(
                                _results!.total == 0
                                    ? ''
                                    : _results!.total > _results!.hits.length
                                    ? '${NumberFormat.decimalPattern().format(_results!.total)} verses · showing the best ${_results!.hits.length}'
                                    : '${_results!.total} ${_results!.total == 1 ? 'verse' : 'verses'}',
                                style: AppType.caption.copyWith(
                                  color: p.inkMute,
                                ),
                              ),
                            ),
                          ),
                          if (_results!.total == 0 &&
                              (parsed == null || parsed.isBookOnly))
                            SliverToBoxAdapter(
                              child: EmptyState(
                                icon: PhosphorIconsRegular.magnifyingGlass,
                                color: p.sky,
                                title: 'No verses found',
                                message: 'Try fewer words, a different spelling, or another translation.',
                                asset: 'assets/images/empty/empty_search.png',
                              ),
                            ),
                          SliverList.builder(
                            itemCount: _results!.hits.length,
                            itemBuilder: (context, i) => _Hit(
                              hit: _results!.hits[i],
                              onTap: () {
                                final h = _results!.hits[i];
                                _open(h.ref, flash: VerseRange.single(h.ref));
                              },
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(
                          child: SizedBox(height: Space.x10),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hit extends StatelessWidget {
  const _Hit({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e) in hit.matches) {
      if (s > at) spans.add(TextSpan(text: hit.text.substring(at, s)));
      spans.add(
        TextSpan(
          text: hit.text.substring(s, e),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            backgroundColor: p.butter.withValues(alpha: p.isDark ? 0.3 : 0.6),
          ),
        ),
      );
      at = e;
    }
    if (at < hit.text.length) spans.add(TextSpan(text: hit.text.substring(at)));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hit.ref.label,
              style: AppType.label.copyWith(color: p.tangerineText),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: spans),
              style: fontStyle('Literata', size: 16, height: 1.5, color: p.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.load, required this.onPick});

  final Future<List<String>> Function() load;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<List<String>>(
      future: load(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.x3,
          ),
          children: [
            Text(
              'Search the whole Bible offline — words, exact phrases in quotes, '
              'or a reference like “Ps 23” or “1 Cor 13:4-7”.',
              style: AppType.bodySmall.copyWith(color: p.inkSoft),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: Space.x6),
              Text(
                'RECENT',
                style: AppType.overline.copyWith(color: p.inkMute),
              ),
              for (final q in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: p.inkMute,
                  ),
                  title: Text(q, style: AppType.body.copyWith(color: p.ink)),
                  onTap: () => onPick(q),
                ),
            ],
          ],
        );
      },
    );
  }
}
