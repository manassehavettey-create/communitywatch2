import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/controls.dart';

/// Scaffold shared by Highlights, Notes and Bookmarks: title, optional
/// book filter chips, and a body.
class AnnotationScaffold extends ConsumerWidget {
  const AnnotationScaffold({
    super.key,
    required this.title,
    required this.bookId,
    required this.onBookFilter,
    required this.body,
    this.header,
  });

  final String title;
  final int? bookId;
  final ValueChanged<int?> onBookFilter;
  final Widget body;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
            child: Semantics(header: true, child: Text(title, style: context.text.displaySmall)),
          ),
          ?header,
          if (books.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x2),
                children: [
                  PillChip(label: 'All books', selected: bookId == null, onTap: () => onBookFilter(null), dense: true),
                  for (final b in books) ...[
                    const SizedBox(width: Space.x2),
                    PillChip(
                      label: b.title.length > 28 ? '${b.title.substring(0, 28)}…' : b.title,
                      selected: bookId == b.id,
                      onTap: () => onBookFilter(b.id),
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
