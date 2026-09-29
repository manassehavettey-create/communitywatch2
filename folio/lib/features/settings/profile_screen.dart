import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/icons.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/progress.dart';
import 'settings_pages.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final ctl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Used for the greeting on Home'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(name: ctl.text.trim()));
    }
    ctl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final stats = ref.watch(statsProvider).value;
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final c = context.colors;
    final minutesToday = (stats?.secondsToday ?? 0) ~/ 60;
    final name = s.name.trim();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.navClearance),
          children: [
            const ScreenTitle('Profile'),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
              child: BlockCard(
                onTap: () => _editName(context, ref, s.name),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: c.lime, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        name.isEmpty ? 'F' : name.characters.first.toUpperCase(),
                        style: context.text.headlineSmall?.copyWith(color: const Color(0xFF161514)),
                      ),
                    ),
                    const SizedBox(width: Space.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'Add your name' : name, style: context.text.titleLarge),
                          Text(
                            '${plural(books.length, 'book')} · ${plural(stats?.booksFinished ?? 0, 'finished', 'finished')} · no account',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(PhosphorIconsRegular.pencilSimple, color: c.inkMuted, size: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
              child: BlockCard(
                color: ShelfColor.lime.cardBackground(context.brightness),
                onTap: () => context.push('/profile/${SettingsPage.goals.path}'),
                child: Row(
                  children: [
                    ProgressRing(
                      value: s.dailyGoalMinutes == 0 ? 0 : minutesToday / s.dailyGoalMinutes,
                      size: 52,
                      stroke: 7,
                      color: const Color(0xFF161514),
                      track: const Color(0x1F161514),
                    ),
                    const SizedBox(width: Space.x4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily goal: ${s.dailyGoalMinutes} min',
                            style: context.text.titleMedium?.copyWith(
                              color: ShelfColor.lime.cardForeground(context.brightness),
                            ),
                          ),
                          Text(
                            s.reminderEnabled
                                ? 'Reminder at ${TimeOfDay(hour: s.reminderMinutes ~/ 60, minute: s.reminderMinutes % 60).format(context)}'
                                : 'No reminder set',
                            style: context.text.bodySmall?.copyWith(
                              color: ShelfColor.lime.cardForeground(context.brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.x4),
            for (final page in SettingsPage.values)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: Radii.smAll),
                  child: Icon(page.icon, size: 20),
                ),
                title: Text(page.title),
                subtitle: Text(page.subtitle),
                trailing: const Icon(PhosphorIconsRegular.caretRight, size: 18),
                onTap: () => context.push('/profile/${page.path}'),
              ),
          ],
        ),
      ),
    );
  }
}
