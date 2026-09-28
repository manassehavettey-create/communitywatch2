import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../../core/db/database.dart';

abstract final class SettingKeys {
  static const themeMode = 'theme_mode';
  static const onboardingDone = 'onboarding_done';
  static const weekStartsMonday = 'week_starts_monday';
  static const logReminderEnabled = 'log_reminder_enabled';
  static const logReminderMinutes = 'log_reminder_minutes';
  static const lockEnabled = 'lock_enabled';
  static const biometricEnabled = 'biometric_enabled';
  static const hapticsEnabled = 'haptics_enabled';

  /// Keys that must never be restored from a backup (the PIN lives in
  /// secure storage, so importing a "locked" flag could lock you out).
  static const notPortable = {lockEnabled, biometricEnabled};
}

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.onboardingDone = false,
    this.weekStartsMonday = true,
    this.logReminderEnabled = false,
    this.logReminderMinutes = 21 * 60,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.hapticsEnabled = true,
  });

  final ThemeMode themeMode;
  final bool onboardingDone;
  final bool weekStartsMonday;
  final bool logReminderEnabled;
  final int logReminderMinutes;
  final bool lockEnabled;
  final bool biometricEnabled;
  final bool hapticsEnabled;

  factory AppSettings.fromMap(Map<String, String> m) {
    bool b(String k, bool d) => m[k] == null ? d : m[k] == 'true';
    int i(String k, int d) => int.tryParse(m[k] ?? '') ?? d;
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (t) => t.name == m[SettingKeys.themeMode],
        orElse: () => ThemeMode.system,
      ),
      onboardingDone: b(SettingKeys.onboardingDone, false),
      weekStartsMonday: b(SettingKeys.weekStartsMonday, true),
      logReminderEnabled: b(SettingKeys.logReminderEnabled, false),
      logReminderMinutes:
          i(SettingKeys.logReminderMinutes, 21 * 60).clamp(0, 1439),
      lockEnabled: b(SettingKeys.lockEnabled, false),
      biometricEnabled: b(SettingKeys.biometricEnabled, false),
      hapticsEnabled: b(SettingKeys.hapticsEnabled, true),
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, String>> all() async => {
        for (final r in await _db.select(_db.settings).get()) r.key: r.value,
      };

  Future<AppSettings> load() async => AppSettings.fromMap(await all());

  Future<void> set(String key, Object value) =>
      _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion(key: Value(key), value: Value(value.toString())),
          );
}
