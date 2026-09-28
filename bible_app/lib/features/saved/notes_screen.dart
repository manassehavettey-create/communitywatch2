import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../bible/translation.dart';
import '../../core/motion/reveal.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/layout.dart';
import '../reader/reader_screen.dart';
import '../reader/verse_actions.dart';

/// Every note attached to Scripture, with the verses it belongs to.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final notes = ref.watch(notesProvider).value ?? const [];
    final bible = ref.watch(currentBibleProvider).value;
    final q = _query.toLowerCase();

    final shown = [
      for (final n in notes)
        if (q.isEmpty ||
            n.body.toLowerCase().contains(q) ||
            VerseRange(
              VerseRef.parseCode(n.startRef),
              VerseRef.parseCode(n.endRef),
            ).label.toLowerCase().contains(q))
          n,
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Notes',
                subtitle: '${notes.length} on Scripture',
                leading: CircleIconButton(
                  icon: PhosphorIconsBold.caretLeft,
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            if (notes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.x4,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search notes',
                      prefixIcon: Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        color: p.inkMute,
                      ),
                    ),
                  ),
                ),
              ),
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: PhosphorIconsRegular.notePencil,
                  color: p.blush,
                  asset: 'assets/images/empty/empty_notes.png',
                  title: notes.isEmpty ? 'No notes yet' : 'No notes match',
                  message: notes.isEmpty
                      ? 'Select a verse while reading and choose Note to write your thoughts.'
                      : 'Try another word.',
                ),
              )
            else
              SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final n = shown[i];
                  final range = VerseRange(
                    VerseRef.parseCode(n.startRef),
                    VerseRef.parseCode(n.endRef),
                  );
                  final verse = bible == null
                      ? ''
                      : bible
                            .versesIn(range)
                            .map(
                              (e) => VerseText.plain(
                                e.$2,
                                suppliedWords: bible.info.suppliedWords,
                              ),
                            )
                            .join(' ');
                  return Reveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        0,
                        Space.gutter,
                        Space.x3,
                      ),
                      child: SurfaceCard(
                        onTap: () => context.push(
                          ReaderArgs.location(range.start, flash: range),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    range.label,
                                    style: AppType.label.copyWith(
                                      color: p.tangerineText,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('d MMM y').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      n.updatedAt,
                                    ),
                                  ),
                                  style: AppType.caption.copyWith(
                                    color: p.inkMute,
                                  ),
                                ),
                                const SizedBox(width: Space.x2),
                                CircleIconButton(
                                  icon: PhosphorIconsRegular.pencilSimple,
                                  tooltip: 'Edit note',
                                  size: 32,
                                  onPressed: () async {
                                    final result = await showAppSheet<String>(
                                      context,
                                      builder: (_) => NoteEditorSheet(
                                        reference: range.label,
                                        initial: n.body,
                                        existing: true,
                                      ),
                                    );
                                    if (result == null) return;
                                    final repo = ref.read(
                                      annotationsRepositoryProvider,
                                    );
                                    if (result.isEmpty) {
                                      await repo.deleteNote(n.id);
                                    } else {
                                      await repo.saveNote(
                                        id: n.id,
                                        r: range,
                                        body: result,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.x2),
                            Text(
                              n.body,
                              style: AppType.body.copyWith(color: p.ink),
                            ),
                            if (verse.isNotEmpty) ...[
                              const SizedBox(height: Space.x3),
                              Container(
                                padding: const EdgeInsets.all(Space.x3),
                                decoration: BoxDecoration(
                                  color: p.paperDeep,
                                  borderRadius: Radii.smAll,
                                ),
                                child: Text(
                                  verse,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: fontStyle(
                                    'Literata',
                                    size: 14,
                                    height: 1.5,
                                    color: p.inkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x14)),
          ],
        ),
      ),
    );
  }
}
