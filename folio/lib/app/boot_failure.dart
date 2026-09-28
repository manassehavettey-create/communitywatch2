import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Shown when the encrypted database can't be opened (for example the device
/// keystore entry was lost). Never deletes anything without explicit consent.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _BootFailure(error: error),
    );
  }
}

class _BootFailure extends StatefulWidget {
  const _BootFailure({required this.error});
  final Object error;

  @override
  State<_BootFailure> createState() => _BootFailureState();
}

class _BootFailureState extends State<_BootFailure> {
  bool _reset = false;

  Future<void> _resetData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Folio’s data?'),
        content: const Text(
          'This deletes Folio’s library database (highlights, notes, bookmarks and '
          'reading history). Your imported PDF copies stay on the device and can be '
          're-imported. Files outside Folio are never touched.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    final dir = await getApplicationSupportDirectory();
    final f = File(p.join(dir.path, 'folio.db'));
    if (await f.exists()) await f.delete();
    setState(() => _reset = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Folio couldn’t open your library', style: context.text.headlineMedium),
              const SizedBox(height: Space.x3),
              Text(
                _reset
                    ? 'Done. Close and reopen Folio to start with a fresh library.'
                    : 'Your library is encrypted with a key stored in this device’s secure '
                        'storage, and that key couldn’t be read. This can happen after restoring '
                        'a backup onto a new device.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Space.x6),
              if (!_reset) FilledButton(onPressed: _resetData, child: const Text('Reset library data')),
            ],
          ),
        ),
      ),
    );
  }
}
