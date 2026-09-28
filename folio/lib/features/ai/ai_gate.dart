import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/icons.dart';

import '../../core/theme/tokens.dart';

/// The reading-assistant actions offered in the reader.
enum AssistAction {
  explain('Explain', PhosphorIconsRegular.lightbulb),
  summarize('Summarize', PhosphorIconsRegular.listBullets),
  keyPoints('Key points', PhosphorIconsRegular.listNumbers),
  ask('Ask', PhosphorIconsRegular.chatCircleText),
  simplify('Simplify', PhosphorIconsRegular.magicWand),
  define('Define', PhosphorIconsRegular.bookOpenText);

  const AssistAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Whether an AI provider key has been configured. AI features stay off
/// (with a clear explanation) until one is added in Settings → AI.
final aiConfiguredProvider = Provider<bool>((ref) => false);

/// Opens the reading assistant for a passage or page.
Future<void> showAssistantSheet(
  BuildContext context,
  WidgetRef ref, {
  required int bookId,
  required int page,
  String? passage,
  AssistAction? action,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AssistantSheet(bookId: bookId, page: page, passage: passage, action: action),
  );
}

class _AssistantSheet extends ConsumerWidget {
  const _AssistantSheet({required this.bookId, required this.page, this.passage, this.action});
  final int bookId;
  final int page;
  final String? passage;
  final AssistAction? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.brightness;
    final scope = passage != null && passage!.trim().isNotEmpty ? 'this passage' : 'page $page';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(PhosphorIconsFill.sparkle, size: 20),
                const SizedBox(width: Space.x2),
                Text('Reading assistant', style: context.text.headlineSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text('Works on $scope only, never the whole book.', style: context.text.bodySmall),
            if (passage != null && passage!.trim().isNotEmpty) ...[
              const SizedBox(height: Space.x3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.x3),
                decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: Radii.mdAll),
                child: Text('“${passage!.trim()}”',
                    maxLines: 4, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ),
            ],
            const SizedBox(height: Space.x4),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final a in AssistAction.values)
                  Opacity(
                    opacity: 0.45,
                    child: Chip(
                      avatar: Icon(a.icon, size: 16),
                      label: Text(a.label),
                      shape: StadiumBorder(side: BorderSide(color: context.colors.hairline)),
                      backgroundColor: a == action ? context.colors.surfaceMuted : context.colors.surface,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Container(
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(color: ShelfColor.lilac.cardBackground(b), borderRadius: Radii.lgAll),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI features are off',
                      style: context.text.titleMedium?.copyWith(color: ShelfColor.lilac.cardForeground(b))),
                  const SizedBox(height: 4),
                  Text(
                    'Explain, summarize, define and Ask This Book need an AI provider. '
                    'Nothing is sent anywhere until you add one in Settings → AI. '
                    'Everything else in Folio works fully offline.',
                    style: context.text.bodySmall?.copyWith(color: ShelfColor.lilac.cardForeground(b)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/profile/ai');
                },
                child: const Text('Open AI settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
