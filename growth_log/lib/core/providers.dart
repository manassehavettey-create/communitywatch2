import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/log/data/entry_repository.dart';
import '../features/settings/data/backup_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/skills/data/milestone_repository.dart';
import '../features/skills/data/skill_repository.dart';
import '../features/timer/data/timer_repository.dart';
import 'db/database.dart';
import 'services/haptics.dart';
import 'services/lock_service.dart';
import 'services/notification_service.dart';
import 'utils/clock.dart';
import 'utils/day_key.dart';

/// Overridden in `main()` with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final clockProvider = Provider<Clock>((ref) => const Clock());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final lockServiceProvider = Provider<LockService>((ref) => LockService());

final skillRepositoryProvider = Provider(
  (ref) => SkillRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final timerRepositoryProvider = Provider(
  (ref) => TimerRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final entryRepositoryProvider = Provider(
  (ref) => EntryRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final milestoneRepositoryProvider = Provider(
  (ref) =>
      MilestoneRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

// ------------------------------------------------------------------ today

/// The current local day. Ticks over at midnight and is re-checked when the
/// app resumes, so screens update after overnight use or a time-zone change.
class TodayNotifier extends Notifier<DayKey> {
  Timer? _timer;

  @override
  DayKey build() {
    ref.onDispose(() => _timer?.cancel());
    final clock = ref.watch(clockProvider);
    _schedule(clock);
    return clock.today();
  }

  void _schedule(Clock clock) {
    _timer?.cancel();
    final now = clock.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), refresh);
  }

  void refresh() {
    final clock = ref.read(clockProvider);
    final today = clock.today();
    if (today != state) state = today;
    _schedule(clock);
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DayKey>(TodayNotifier.new);

// --------------------------------------------------------------- settings

/// Overridden in `main()` with the settings read before the first frame.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> reload() async => state = await _repo.load();

  Future<void> _set(String key, Object value) async {
    await _repo.set(key, value);
    state = await _repo.load();
  }

  Future<void> setThemeMode(String name) => _set(SettingKeys.themeMode, name);
  Future<void> completeOnboarding() => _set(SettingKeys.onboardingDone, true);
  Future<void> setWeekStartsMonday(bool v) =>
      _set(SettingKeys.weekStartsMonday, v);
  Future<void> setHaptics(bool v) => _set(SettingKeys.hapticsEnabled, v);
  Future<void> setLockEnabled(bool v) => _set(SettingKeys.lockEnabled, v);
  Future<void> setBiometricEnabled(bool v) =>
      _set(SettingKeys.biometricEnabled, v);

  Future<void> setLogReminder({required bool enabled, int? minutes}) async {
    await _repo.set(SettingKeys.logReminderEnabled, enabled);
    if (minutes != null) await _repo.set(SettingKeys.logReminderMinutes, minutes);
    state = await _repo.load();
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(
    enabled: ref.watch(settingsProvider.select((s) => s.hapticsEnabled)),
  ),
);

/// Emits every second while listened to; drives live timer readouts.
final tickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => clock.now(),
  );
});
