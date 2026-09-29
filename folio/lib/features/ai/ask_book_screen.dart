import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/books_repository.dart';
import '../book/book_details_screen.dart' show outlineProvider;
import 'ai_gate.dart';

/// Ask This Book + chapter summaries. Grounded in the book's own pages;
/// disabled with an explanation until an AI provider is configured.
class AskBookScreen extends ConsumerWidget {
  const AskBookScreen({super.key, required this.bookId, this.initialPage});
  final int bookId;
  final int? initialPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider(bookId)).value;
    final outline = ref.watch(outlineProvider(bookId)).value ?? const [];
    final configured = ref.watch(aiConfiguredProvider);
    final b = context.brightness;
    if (book == null) return Scaffold(appBar: AppBar());

    final chapters = outline.where((o) => o.level == 0).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x10),
        children: [
          Text('Ask this book', style: context.text.displaySmall),
          const SizedBox(height: 4),
          Text(book.title, style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted)),
          const SizedBox(height: Space.x5),
          if (book.isScanned)
            _Notice(
              color: ShelfColor.peach,
              title: 'Not available for this PDF',
              body:
                  'This is a scanned PDF without a text layer, so there’s no text for answers to be '
                  'grounded in.',
            )
          else if (!configured)
            _Notice(
              color: ShelfColor.lilac,
              title: 'AI features are off',
              body:
                  'Add an AI provider in Settings → AI to ask questions about this book. '
                  'Folio would send your question and only the few most relevant pages it finds on '
                  'your phone, and every answer links back to those pages.',
              action: FilledButton(onPressed: () => context.push('/profile/ai'), child: const Text('Open AI settings')),
            ),
          const SizedBox(height: Space.x4),
          TextField(
            enabled: configured && !book.isScanned,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ask a question about this book',
              prefixIcon: Icon(PhosphorIconsRegular.chatCircleText, size: 20),
            ),
          ),
          const SizedBox(height: Space.x6),
          Text('Chapter summaries', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(
            chapters.isEmpty
                ? 'Folio couldn’t find chapters in this PDF. You’ll be able to summarize a page range instead.'
                : 'Short summary, key ideas and important concepts for each chapter.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.x3),
          for (final c in chapters.take(40))
            Opacity(
              opacity: configured ? 1 : 0.5,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(PhosphorIconsRegular.listBullets, color: ShelfColor.lilac.cardForeground(b)),
                title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Starts on page ${c.page}'),
                onTap: () =>
                    showAssistantSheet(context, ref, bookId: bookId, page: c.page, action: AssistAction.summarize),
              ),
            ),
          if (chapters.isEmpty)
            OutlinedButton.icon(
              onPressed: () => showAssistantSheet(
                context,
                ref,
                bookId: bookId,
                page: initialPage ?? 1,
                action: AssistAction.summarize,
              ),
              icon: const Icon(PhosphorIconsRegular.listBullets, size: 18),
              label: const Text('Summarize a page range'),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.title, required this.body, this.action});
  final ShelfColor color;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final fg = color.cardForeground(b);
    return Container(
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(color: color.cardBackground(b), borderRadius: Radii.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleMedium?.copyWith(color: fg)),
          const SizedBox(height: 4),
          Text(body, style: context.text.bodyMedium?.copyWith(color: fg)),
          if (action != null) ...[const SizedBox(height: Space.x4), action!],
        ],
      ),
    );
  }
}
