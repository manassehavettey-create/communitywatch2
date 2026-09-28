import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/profile/settings_screen.dart';
import 'account.dart';
import 'providers.dart';
import 'router.dart';

class BibleApp extends ConsumerStatefulWidget {
  const BibleApp({super.key, required this.onboarded});

  final bool onboarded;

  @override
  ConsumerState<BibleApp> createState() => _BibleAppState();
}

class _BibleAppState extends ConsumerState<BibleApp> {
  late final GoRouter _router = buildRouter(onboarded: widget.onboarded);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreReminders());
  }

  /// Re-registers reminders on start (e.g. after the time zone changed).
  Future<void> _restoreReminders() async {
    final reminders = ref.read(reminderServiceProvider);
    if (!reminders.supported) return;
    final db = ref.read(databaseProvider);
    if (await db.getValue(SettingsScreen.readingReminderKey) == 'on') {
      final minutes =
          int.tryParse(
            await db.getValue(SettingsScreen.readingReminderTimeKey) ?? '',
          ) ??
          420;
      await reminders.scheduleReading(minutes);
    }
    final prayers = await ref.read(prayerRepositoryProvider).withReminders();
    if (prayers.isNotEmpty) await reminders.syncPrayerReminders(prayers);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountBinderProvider);
    final mode = ref.watch(prefsValueProvider.select((p) => p.appTheme));
    return MaterialApp.router(
      title: 'Bible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 360),
      routerConfig: _router,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
    );
  }
}
