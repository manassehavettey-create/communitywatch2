import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/pdf/library_storage.dart';
import '../../core/theme/tokens.dart';
import '../../data/services/import_service.dart';
import '../../shared/widgets/controls.dart';

/// Opens the system file picker (multi-select, PDFs only) and imports the
/// chosen files into Folio's private library. Nothing leaves the device.
Future<void> pickAndImportBooks(BuildContext context, WidgetRef ref) async {
  final List<PlatformFile> picked;
  try {
    picked = await FilePicker.pickFiles(
      dialogTitle: 'Add PDFs to Folio',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  } catch (e) {
    if (context.mounted) showFolioSnack(context, 'Couldn’t open the file picker.');
    return;
  }
  if (picked.isEmpty) return;

  final files = <({String path, String name, bool temporary})>[];
  final failures = <ImportResult>[];
  Directory? tmpDir;
  for (final f in picked) {
    final path = f.path;
    if (path != null && await File(path).exists()) {
      files.add((path: path, name: f.name, temporary: false));
      continue;
    }
    // Content URI (Android) or sandboxed file: stream it to a temp file so
    // large PDFs are never held in memory.
    try {
      tmpDir ??= await Directory(p.join((await getTemporaryDirectory()).path, 'import')).create(recursive: true);
      final tmp = File(p.join(tmpDir.path, '${DateTime.now().microsecondsSinceEpoch}_${f.name}'));
      final sink = tmp.openWrite();
      await sink.addStream(f.readAsByteStream());
      await sink.close();
      files.add((path: tmp.path, name: f.name, temporary: true));
    } catch (e) {
      failures.add(
        ImportResult(
          ImportOutcome.failed,
          f.name,
          message: isOutOfSpace(e) ? 'Not enough free storage to add this PDF.' : 'Folio couldn’t read this file.',
        ),
      );
    }
  }

  final results = [...failures, ...await ref.read(importControllerProvider.notifier).importAll(files)];
  if (!context.mounted) return;
  await _showResults(context, results);
  ref.read(importControllerProvider.notifier).clearFinished();
}

Future<void> _showResults(BuildContext context, List<ImportResult> results) async {
  final added = results.where((r) => r.outcome == ImportOutcome.added).toList();
  final problems = results.where((r) => r.outcome != ImportOutcome.added).toList();
  if (problems.isEmpty) {
    if (added.length == 1) {
      showFolioSnack(
        context,
        'Added to your library',
        action: 'Open',
        onAction: () {
          context.push('/book/${added.single.bookId}');
        },
      );
    } else {
      showFolioSnack(context, 'Added ${added.length} books to your library');
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.colors;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x6),
            children: [
              Text(
                added.isEmpty ? 'Nothing was added' : 'Added ${added.length} of ${results.length}',
                style: ctx.text.headlineSmall,
              ),
              const SizedBox(height: Space.x4),
              for (final r in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (r.outcome) {
                          ImportOutcome.added => PhosphorIconsFill.checkCircle,
                          ImportOutcome.duplicate => PhosphorIconsRegular.copy,
                          ImportOutcome.failed => PhosphorIconsRegular.warningCircle,
                        },
                        color: r.outcome == ImportOutcome.failed ? c.danger : c.ink,
                        size: 22,
                      ),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.fileName, style: ctx.text.titleSmall),
                            Text(r.message ?? 'Added', style: ctx.text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.x2),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        ),
      );
    },
  );
}
