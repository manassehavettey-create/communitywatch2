import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';

/// Name + colour editor. Returns the new collection id (or null).
Future<int?> createCollection(BuildContext context, WidgetRef ref, {int? addBookId}) async {
  final result = await showModalBottomSheet<({String name, ShelfColor color})>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _CollectionForm(),
  );
  if (result == null) return null;
  final repo = ref.read(collectionsRepositoryProvider);
  final id = await repo.create(result.name, result.color.index);
  if (addBookId != null) await repo.addBook(id, addBookId);
  HapticFeedback.lightImpact();
  return id;
}

Future<void> renameCollection(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String name,
  required ShelfColor color,
}) async {
  final result = await showModalBottomSheet<({String name, ShelfColor color})>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CollectionForm(initialName: name, initialColor: color),
  );
  if (result == null) return;
  await ref.read(collectionsRepositoryProvider).rename(id, result.name, color: result.color.index);
}

class _CollectionForm extends StatefulWidget {
  const _CollectionForm({this.initialName, this.initialColor});
  final String? initialName;
  final ShelfColor? initialColor;

  @override
  State<_CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends State<_CollectionForm> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late ShelfColor _color = widget.initialColor ?? ShelfColor.collectionColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    Navigator.pop(context, (name: n, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final m = Motion.of(context);
    final editing = widget.initialName != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.viewInsetsOf(context).bottom + Space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(editing ? 'Edit collection' : 'New collection', style: context.text.headlineSmall),
          const SizedBox(height: Space.x4),
          // Live preview card.
          AnimatedContainer(
            duration: m.base,
            curve: Motion.curve,
            height: 88,
            width: double.infinity,
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(color: _color.strong, borderRadius: Radii.lgAll),
            alignment: Alignment.bottomLeft,
            child: ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, v, _) => Text(
                v.text.trim().isEmpty ? 'Collection name' : v.text.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge?.copyWith(
                  color: const Color(0xFF161514).withValues(alpha: v.text.trim().isEmpty ? 0.45 : 1),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.x4),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(hintText: 'e.g. Summer reads'),
          ),
          const SizedBox(height: Space.x4),
          Wrap(
            spacing: Space.x3,
            children: [
              for (final col in ShelfColor.collectionColors)
                Semantics(
                  label: col.label,
                  selected: col == _color,
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _color = col),
                    child: AnimatedContainer(
                      duration: m.fast,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: col.strong,
                        shape: BoxShape.circle,
                        border: Border.all(color: col == _color ? context.colors.ink : Colors.transparent, width: 2.5),
                      ),
                      child: col == _color
                          ? const Icon(PhosphorIconsRegular.check, size: 18, color: Color(0xFF161514))
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.x6),
          SizedBox(
            width: double.infinity,
            child: ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, v, _) => FilledButton(
                onPressed: v.text.trim().isEmpty ? null : _submit,
                child: Text(editing ? 'Save' : 'Create collection'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user tick which collections a book belongs to.
Future<void> showCollectionsPicker(BuildContext context, WidgetRef ref, int bookId) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CollectionsPicker(bookId: bookId),
  );
}

class _CollectionsPicker extends ConsumerWidget {
  const _CollectionsPicker({required this.bookId});
  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = ref.watch(collectionsProvider).value ?? const [];
    final selected = ref.watch(bookCollectionIdsProvider(bookId)).value ?? const <int>{};
    final repo = ref.read(collectionsRepositoryProvider);
    final m = Motion.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
              child: Text('Collections', style: context.text.headlineSmall),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final cw in cols)
                    CheckboxListTile(
                      value: selected.contains(cw.collection.id),
                      activeColor: context.colors.ink,
                      checkColor: context.colors.onInk,
                      secondary: AnimatedContainer(
                        duration: m.fast,
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ShelfColor.fromIndex(cw.collection.color).strong,
                          borderRadius: Radii.smAll,
                        ),
                      ),
                      title: Text(cw.collection.name, style: context.text.titleSmall),
                      subtitle: Text('${cw.bookIds.length} books', style: context.text.bodySmall),
                      onChanged: (v) => v == true
                          ? repo.addBook(cw.collection.id, bookId)
                          : repo.removeBook(cw.collection.id, bookId),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.plus),
              title: Text('New collection', style: context.text.titleSmall),
              onTap: () => createCollection(context, ref, addBookId: bookId),
            ),
            const SizedBox(height: Space.x2),
          ],
        ),
      ),
    );
  }
}
