import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/annotations_repository.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/illustration.dart';
import 'annotation_common.dart';
import 'note_editor.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.bookId});
  final int? bookId;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late int? _book = widget.bookId;
  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _edit(Note n) async {
    final text = await editNoteText(
      context,
      passage: n.passage.startsWith('Page ') && n.passage.length < 12 ? '' : n.passage,
      initial: n.body,
      subtitle: 'Page ${n.page}',
    );
    if (text != null) await ref.read(annotationsRepositoryProvider).updateNote(n.id, text);
  }

  Future<void> _delete(Note n) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this note?',
      message: 'The note will be removed. Any highlight on the passage stays.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final repo = ref.read(annotationsRepositoryProvider);
    await repo.deleteNote(n.id);
    if (mounted) showFolioSnack(context, 'Note deleted', action: 'Undo', onAction: () => repo.restoreNote(n));
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final b = context.brightness;
    final repo = ref.watch(annotationsRepositoryProvider);
    return AnnotationScaffold(
      title: 'Notes',
      bookId: _book,
      onBookFilter: (id) => setState(() => _book = id),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
        child: TextField(
          controller: _search,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 200), () => setState(() => _query = v));
          },
          decoration: const InputDecoration(
            hintText: 'Search notes',
            isDense: true,
            prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
          ),
        ),
      ),
      body: StreamBuilder<List<WithBook<Note>>>(
        stream: repo.watchAllNotes(bookId: _book, query: _query),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          final list = snap.data!;
          if (list.isEmpty) {
            return SingleChildScrollView(
              child: EmptyState(
                art: Art.emptyNotes,
                title: _query.isNotEmpty ? 'No notes match' : 'No notes yet',
                message: _query.isNotEmpty
                    ? 'Nothing matches “$_query”.'
                    : 'Select a passage while reading and tap Note to write down a thought. '
                        'It’s saved with the book, page and passage.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x10),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
            itemBuilder: (context, i) {
              final n = list[i].item;
              final isPageNote = n.passage == 'Page ${n.page}';
              return BlockCard(
                onTap: () => context.push('/read/${n.bookId}?page=${n.page}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isPageNote)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Space.x3),
                        decoration: BoxDecoration(color: ShelfColor.butter.cardBackground(b), borderRadius: Radii.mdAll),
                        child: Text(
                          '“${n.passage}”',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: ShelfColor.butter.cardForeground(b),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (!isPageNote) const SizedBox(height: Space.x3),
                    Text(n.body, style: context.text.bodyLarge),
                    const SizedBox(height: Space.x3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${list[i].bookTitle} · p. ${n.page} · ${relativeDay(n.updatedAt)}',
                            style: context.text.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit note',
                          onPressed: () => _edit(n),
                          icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete note',
                          onPressed: () => _delete(n),
                          icon: const Icon(PhosphorIconsRegular.trash, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: m.base, delay: m.stagger(i));
            },
          );
        },
      ),
    );
  }
}
