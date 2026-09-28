import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/motion_widgets.dart';
import '../domain/models/enums.dart';
import 'providers.dart';
import 'router.dart';
import 'settings.dart';
import 'sync_controller.dart';

class BodyforgeApp extends ConsumerWidget {
  const BodyforgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    Haptics.enabled = settings.haptics;
    // Keep sync alive and reminders in step with the plan.
    ref.watch(syncProvider);
    ref.listen(_reminderInputs, (_, next) => _applyReminders(ref, next));

    return MaterialApp.router(
      title: 'BODYFORGE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// (enabled, minutes, weekly check, training weekdays)
final _reminderInputs = Provider<(bool, int, bool, List<int>)>((ref) {
  final s = ref.watch(settingsProvider);
  final program = ref.watch(activeProgramProvider).value;
  final days = <int>[
    for (final d in program?.spec.days ?? const []) if (d.dayType != DayType.rest) d.weekday
  ];
  return (s.remindersEnabled, s.reminderMinutes, s.weeklyCheckReminder, days);
});

Future<void> _applyReminders(WidgetRef ref, (bool, int, bool, List<int>) v) async {
  final n = ref.read(notificationsProvider);
  final (enabled, minutes, weekly, days) = v;
  if (enabled && days.isNotEmpty) {
    await n.scheduleTrainingReminders(weekdays: days, minutes: minutes);
  } else {
    await n.cancelTrainingReminders();
  }
  if (weekly && enabled) {
    await n.scheduleWeeklyCheck();
  } else {
    await n.cancelWeeklyCheck();
  }
}
