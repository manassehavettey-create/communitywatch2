import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/layout.dart';

enum SavedKind {
  bookmark('Bookmarks', PhosphorIconsRegular.bookmarkSimple),
  highlight('Highlights', PhosphorIconsRegular.highlighter),
  note('Notes', PhosphorIconsRegular.notePencil),
  verse('Verses', PhosphorIconsRegular.heart);

  const SavedKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

class SavedItem {
  const SavedItem({
    required this.id,
    required this.kind,
    required this.range,
    required this.at,
    this.text,
    this.note,
    this.color,
  });

  final String id;
  final SavedKind kind;
  final VerseRange range;
  final int at;
  final String? text;
  final String? note;
  final HighlightColor? color;
}

/// All saved things, newest first.
final savedItemsProvider = Provider<List<SavedItem>>((ref) {
  VerseRange r(String a, String b) =>
      VerseRange(VerseRef.parseCode(a), VerseRef.parseCode(b));
  final items = <SavedItem>[
    for (final b in ref.watch(bookmarksProvider).value ?? const [])
      SavedItem(
        id: b.id,
        kind: SavedKind.bookmark,
        range: r(b.startRef, b.endRef),
        at: b.createdAt,
      ),
    for (final h in ref.watch(highlightsProvider).value ?? const [])
      SavedItem(
        id: h.id,
        kind: SavedKind.highlight,
        range: r(h.startRef, h.endRef),
        at: h.updatedAt,
        color: HighlightColor.fromName(h.color),
      ),
    for (final n in ref.watch(notesProvider).value ?? const [])
      SavedItem(
        id: n.id,
        kind: SavedKind.note,
        range: r(n.startRef, n.endRef),
        at: n.updatedAt,
        note: n.body,
      ),
    for (final s in ref.watch(savedVersesProvider).value ?? const [])
      SavedItem(
        id: s.id,
        kind: SavedKind.verse,
        range: r(s.startRef, s.endRef),
        at: s.createdAt,
        text: s.snapshot,
      ),
  ]..sort((a, b) => b.at.compareTo(a.at));
  return items;
});

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key, this.initialKind});

  final SavedKind? initialKind;

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  late SavedKind? _kind = widget.initialKind;
  HighlightColor? _color;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final all = ref.watch(savedItemsProvider);
    final bible = ref.watch(currentBibleProvider).value;

    String textOf(SavedItem i) {
      if (i.text != null) return i.text!;
      if (bible == null) return '';
      return bible
          .versesIn(i.range)
          .map(
            (e) =>
                VerseText.plain(e.$2, suppliedWords: bible.info.suppliedWords),
          )
          .join(' ');
    }

    final q = _query.toLowerCase();
    final shown = all.where((i) {
      if (_kind != null && i.kind != _kind) return false;
      if (_color != null && i.color != _color) return false;
      if (q.isEmpty) return true;
      return i.range.label.toLowerCase().contains(q) ||
          (i.note?.toLowerCase().contains(q) ?? false) ||
          textOf(i).toLowerCase().contains(q);
    }).toList();
    int count(SavedKind k) => all.where((i) => i.kind == k).length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Saved',
                subtitle: '${all.length} ${all.length == 1 ? 'item' : 'items'}',
                leading: CircleIconButton(
                  icon: PhosphorIconsBold.caretLeft,
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: Space.x3,
                crossAxisSpacing: Space.x3,
                childAspectRatio: 1.45,
                children: [
                  for (final (i, k) in SavedKind.values.indexed)
                    Reveal(
                      index: i,
                      child: _Folder(
                        kind: k,
                        count: count(k),
                        color: [p.sky, p.butter, p.blush, p.sage][i],
                        selected: _kind == k,
                        onTap: () => setState(() {
                          _kind = _kind == k ? null : k;
                          if (_kind != SavedKind.highlight) _color = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.x5,
                  Space.gutter,
                  Space.x2,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search saved',
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      color: p.inkMute,
                    ),
                  ),
                ),
              ),
            ),
            if (_kind == SavedKind.highlight)
              SliverToBoxAdapter(
                child: ChipRow<HighlightColor?>(
                  options: const [null, ...HighlightColor.values],
                  selected: _color,
                  labelOf: (c) => c?.label ?? 'Every colour',
                  onSelected: (c) => setState(() => _color = c),
                ),
              ),
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: PhosphorIconsRegular.bookmarkSimple,
                  color: p.cream,
                  asset: 'assets/images/empty/empty_saved.png',
                  title: all.isEmpty ? 'Nothing saved yet' : 'Nothing matches',
                  message: all.isEmpty
                      ? 'Tap a verse while reading to highlight, bookmark, add a note or save it.'
                      : 'Try another filter or search.',
                  actionLabel: all.isEmpty ? 'Open the Bible' : null,
                  onAction: all.isEmpty ? () => context.go('/bible') : null,
                ),
              )
            else
              SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) =>
                    SavedRow(item: shown[i], text: textOf(shown[i])),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x14)),
          ],
        ),
      ),
    );
  }
}

/// Folder-shaped card with a tab on its top edge.
class _Folder extends StatelessWidget {
  const _Folder({
    required this.kind,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final SavedKind kind;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${kind.label}, $count',
      child: Pressable(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder tab
            AnimatedContainer(
              duration: m.fast,
              width: 64,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: m.fast,
                padding: const EdgeInsets.all(Space.x4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(Radii.md),
                    bottomLeft: Radius.circular(Radii.md),
                    bottomRight: Radius.circular(Radii.md),
                  ),
                  border: Border.all(
                    color: selected ? p.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(kind.icon, color: p.onPastel),
                    const Spacer(),
                    Text(
                      kind.label,
                      style: AppType.titleS.copyWith(color: p.onPastel),
                    ),
                    Text(
                      '$count',
                      style: AppType.caption.copyWith(color: p.onPastel),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedRow extends ConsumerWidget {
  const SavedRow({super.key, required this.item, required this.text});

  final SavedItem item;
  final String text;

  Future<void> _delete(WidgetRef ref) {
    final repo = ref.read(annotationsRepositoryProvider);
    return switch (item.kind) {
      SavedKind.bookmark => repo.deleteBookmark(item.id),
      SavedKind.highlight => repo.deleteHighlight(item.id),
      SavedKind.note => repo.deleteNote(item.id),
      SavedKind.verse => repo.deleteSaved(item.id),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final marker =
        item.color?.base(p) ??
        switch (item.kind) {
          SavedKind.bookmark => p.sky,
          SavedKind.note => p.blush,
          SavedKind.verse => p.sage,
          SavedKind.highlight => p.butter,
        };
    return Dismissible(
      key: ValueKey('${item.kind}-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDestructive(
        context,
        title:
            'Remove this ${item.kind.label.toLowerCase().replaceAll(RegExp(r's$'), '')}?',
        message: item.range.label,
        confirmLabel: 'Remove',
      ),
      onDismissed: (_) => _delete(ref),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.x6),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => context.push(
          Uri(
            path: '/read',
            queryParameters: {
              'r': item.range.start.code,
              'flash': item.range.code,
            },
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 48,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: marker,
                  borderRadius: Radii.pillAll,
                ),
              ),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.kind.icon, size: 14, color: p.inkMute),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.range.label,
                            style: AppType.label.copyWith(color: p.ink),
                          ),
                        ),
                        Text(
                          DateFormat('d MMM').format(
                            DateTime.fromMillisecondsSinceEpoch(item.at),
                          ),
                          style: AppType.caption.copyWith(color: p.inkMute),
                        ),
                      ],
                    ),
                    if (item.note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note!,
                        style: AppType.body.copyWith(color: p.ink),
                      ),
                    ],
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: fontStyle(
                          'Literata',
                          size: 15,
                          height: 1.5,
                          color: p.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
