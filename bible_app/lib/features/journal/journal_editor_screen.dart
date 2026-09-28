import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/scripture_ref_field.dart';
import '../../data/repos/journal_repository.dart';

/// Write or edit a journal entry ([entryId] null means new). A Scripture
/// reference can be passed in when starting from the reader.
class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, this.entryId, this.scriptureRef});

  final String? entryId;
  final String? scriptureRef;

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tagInput = TextEditingController();
  DateTime _date = DateTime.now();
  String? _scripture;
  final _tags = <String>[];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scripture = widget.scriptureRef;
    if (widget.entryId == null) _loaded = true;
    _body.addListener(() => setState(() {}));
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _load(JournalItem i) {
    if (_loaded) return;
    _loaded = true;
    _title.text = i.entry.title;
    _body.text = i.entry.body;
    _date = i.date;
    _scripture = i.entry.scriptureRef;
    _tags
      ..clear()
      ..addAll(i.tags);
  }

  void _addTag(String raw) {
    final t = raw.trim().replaceAll('#', '').toLowerCase();
    if (t.isEmpty || _tags.contains(t)) {
      _tagInput.clear();
      return;
    }
    setState(() {
      _tags.add(t);
      _tagInput.clear();
    });
  }

  bool get _canSave =>
      _body.text.trim().isNotEmpty || _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_tagInput.text.trim().isNotEmpty) _addTag(_tagInput.text);
    setState(() => _saving = true);
    await ref
        .read(journalRepositoryProvider)
        .save(
          JournalDraft(
            title: _title.text,
            body: _body.text,
            date: _date,
            scriptureRef: _scripture,
            tags: List.of(_tags),
          ),
          id: widget.entryId,
        );
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (await confirmDestructive(
      context,
      title: 'Delete entry?',
      message: 'This removes it from all your devices.',
    )) {
      await ref.read(journalRepositoryProvider).delete(widget.entryId!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (widget.entryId != null && !_loaded) {
      final item = ref
          .watch(journalProvider)
          .value
          ?.where((i) => i.entry.id == widget.entryId)
          .firstOrNull;
      if (item == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _load(item);
    }
    final allTags =
        ref.watch(journalProvider).value?.expand((i) => i.tags).toSet() ??
        const <String>{};
    final suggestions = allTags.where((t) => !_tags.contains(t)).toList()
      ..sort();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x3,
                Space.x3,
                Space.gutter,
                0,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.x,
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  if (widget.entryId != null) ...[
                    CircleIconButton(
                      icon: PhosphorIconsRegular.trash,
                      tooltip: 'Delete',
                      onPressed: _delete,
                    ),
                    const SizedBox(width: Space.x2),
                  ],
                  PillButton(
                    label: 'Save',
                    compact: true,
                    busy: _saving,
                    onPressed: _canSave ? _save : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.gutter),
                children: [
                  Semantics(
                    button: true,
                    label:
                        'Entry date, ${DateFormat('EEEE d MMMM y').format(_date)}',
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.calendarBlank,
                            size: 18,
                            color: p.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEEE d MMMM y').format(_date),
                            style: AppType.label.copyWith(color: p.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppType.displayS.copyWith(color: p.ink),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Title',
                      hintStyle: AppType.displayS.copyWith(color: p.inkMute),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: Space.x3,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _body,
                    autofocus: widget.entryId == null,
                    minLines: 8,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: fontStyle(
                      'Literata',
                      size: 18,
                      height: 1.6,
                      color: p.ink,
                    ),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Start writing…',
                      hintStyle: fontStyle(
                        'Literata',
                        size: 18,
                        height: 1.6,
                        color: p.inkMute,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: Space.x6),
                  ScriptureRefField(
                    initialCode: _scripture,
                    onChanged: (c) => _scripture = c,
                  ),
                  const SizedBox(height: Space.x5),
                  Text(
                    'TAGS',
                    style: AppType.overline.copyWith(color: p.inkMute),
                  ),
                  const SizedBox(height: Space.x2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _tags)
                        InputChip(
                          label: Text('#$t'),
                          onDeleted: () => setState(() => _tags.remove(t)),
                          backgroundColor: p.blush,
                          labelStyle: AppType.label.copyWith(color: p.onPastel),
                          deleteIconColor: p.onPastel,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                  TextField(
                    controller: _tagInput,
                    onSubmitted: _addTag,
                    onChanged: (v) {
                      if (v.endsWith(' ') || v.endsWith(',')) {
                        _addTag(v.substring(0, v.length - 1));
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Add a tag (e.g. gratitude)',
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: Space.x2),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final t in suggestions.take(8))
                          ActionChip(
                            label: Text('#$t'),
                            onPressed: () => _addTag(t),
                            backgroundColor: p.paperDeep,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
