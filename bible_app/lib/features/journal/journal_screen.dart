import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/layout.dart';
import '../../data/repos/journal_repository.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _tag;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(JournalItem i) {
    if (_tag != null && !i.tags.contains(_tag)) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return i.entry.title.toLowerCase().contains(q) ||
        i.entry.body.toLowerCase().contains(q) ||
        i.tags.any((t) => t.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = ref.watch(journalProvider).value ?? const <JournalItem>[];
    final tags = {for (final i in items) ...i.tags}.toList()..sort();
    final shown = items.where(_matches).toList();

    // Group by month for the date history.
    final groups = <String, List<JournalItem>>{};
    for (final i in shown) {
      groups.putIfAbsent(DateFormat('MMMM y').format(i.date), () => []).add(i);
    }

    return Scaffold(
      floatingActionButton: CircleIconButton(
        icon: PhosphorIconsBold.plus,
        tooltip: 'New entry',
        size: 60,
        background: p.ink,
        foreground: p.paper,
        onPressed: () => context.push('/journal/new'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Journal',
                subtitle: 'just for you',
                leading: CircleIconButton(
                  icon: PhosphorIconsBold.caretLeft,
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            if (items.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.x3,
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search your journal',
                      prefixIcon: Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        color: p.inkMute,
                      ),
                    ),
                  ),
                ),
              ),
              if (tags.isNotEmpty)
                SliverToBoxAdapter(
                  child: ChipRow<String?>(
                    options: [null, ...tags],
                    selected: _tag,
                    labelOf: (t) => t == null ? 'All' : '#$t',
                    onSelected: (t) => setState(() => _tag = t),
                  ),
                ),
            ],
            if (items.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: PhosphorIconsRegular.notebook,
                  color: p.blush,
                  asset: 'assets/images/empty/empty_journal.png',
                  title: 'A quiet page',
                  message: 'Write about what you read, what you’re learning, or what’s on your mind.',
                  actionLabel: 'Write the first entry',
                  onAction: () => context.push('/journal/new'),
                ),
              )
            else if (shown.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: PhosphorIconsRegular.magnifyingGlass,
                  title: 'No matching entries',
                  message: 'Try another word or tag.',
                ),
              )
            else
              for (final g in groups.entries) ...[
                SliverToBoxAdapter(child: SectionHeader(title: g.key)),
                SliverList.builder(
                  itemCount: g.value.length,
                  itemBuilder: (context, i) => Reveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        0,
                        Space.gutter,
                        Space.x3,
                      ),
                      child: _EntryCard(item: g.value[i]),
                    ),
                  ),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.item});

  final JournalItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = item.entry;
    String? scripture;
    if (e.scriptureRef != null) {
      try {
        scripture = VerseRange.parseCode(e.scriptureRef!).label;
      } on Object {
        scripture = null;
      }
    }
    return SurfaceCard(
      onTap: () => context.push('/journal/${e.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: p.blush,
              borderRadius: Radii.smAll,
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('d').format(item.date),
                  style: AppType.titleM.copyWith(color: p.onPastel),
                ),
                Text(
                  DateFormat('EEE').format(item.date).toUpperCase(),
                  style: AppType.overline.copyWith(color: p.onPastel),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title.isEmpty ? 'Untitled' : e.title,
                  style: AppType.titleS.copyWith(color: p.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  e.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall.copyWith(color: p.inkSoft),
                ),
                if (scripture != null || item.tags.isNotEmpty) ...[
                  const SizedBox(height: Space.x2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (scripture != null)
                        _Tag(text: scripture, color: p.butter),
                      for (final t in item.tags)
                        _Tag(text: '#$t', color: p.paperDeep),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: Radii.pillAll),
      child: Text(
        text,
        style: AppType.caption.copyWith(
          color: color == p.paperDeep ? p.ink : p.onPastel,
        ),
      ),
    );
  }
}
