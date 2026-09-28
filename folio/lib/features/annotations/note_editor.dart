import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Bottom sheet for writing / editing a note. Returns the text, or null if
/// cancelled.
Future<String?> editNoteText(
  BuildContext context, {
  required String passage,
  String initial = '',
  String? subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _NoteEditor(passage: passage, initial: initial, subtitle: subtitle),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.passage, required this.initial, this.subtitle});
  final String passage;
  final String initial;
  final String? subtitle;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = context.brightness;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.viewInsetsOf(context).bottom + Space.x5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.initial.isEmpty ? 'New note' : 'Edit note', style: context.text.headlineSmall),
          if (widget.subtitle != null) Text(widget.subtitle!, style: context.text.bodySmall),
          const SizedBox(height: Space.x3),
          if (widget.passage.trim().isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(color: ShelfColor.butter.cardBackground(b), borderRadius: Radii.mdAll),
              child: SingleChildScrollView(
                child: Text(
                  '“${widget.passage.trim()}”',
                  style: context.text.bodyMedium?.copyWith(
                    color: ShelfColor.butter.cardForeground(b),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          const SizedBox(height: Space.x3),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What do you think?',
              border: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: Radii.mdAll,
                borderSide: BorderSide(color: c.lavender, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: Space.x4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _text,
                  builder: (context, v, _) => FilledButton(
                    onPressed: v.text.trim().isEmpty ? null : () => Navigator.pop(context, v.text.trim()),
                    child: const Text('Save note'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
