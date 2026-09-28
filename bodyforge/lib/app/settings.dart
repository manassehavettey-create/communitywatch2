import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/units.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('overridden in main'));

/// Device-level preferences (not synced — they belong to this phone).
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.units = UnitSystem.metric,
    this.remindersEnabled = false,
    this.reminderMinutes = 7 * 60,
    this.restAlerts = true,
    this.weeklyCheckReminder = true,
    this.haptics = true,
    this.demoMode = false,
    required this.installId,
  });

  final ThemeMode themeMode;
  final UnitSystem units;
  final bool remindersEnabled;

  /// Minutes after midnight for the training reminder.
  final int reminderMinutes;
  final bool restAlerts;
  final bool weeklyCheckReminder;
  final bool haptics;

  /// Debug builds only: demo data has been loaded.
  final bool demoMode;
  final String installId;

  TimeOfDay get reminderTime => TimeOfDay(hour: reminderMinutes ~/ 60, minute: reminderMinutes % 60);

  AppSettings copyWith({
    ThemeMode? themeMode,
    UnitSystem? units,
    bool? remindersEnabled,
    int? reminderMinutes,
    bool? restAlerts,
    bool? weeklyCheckReminder,
    bool? haptics,
    bool? demoMode,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        units: units ?? this.units,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        restAlerts: restAlerts ?? this.restAlerts,
        weeklyCheckReminder: weeklyCheckReminder ?? this.weeklyCheckReminder,
        haptics: haptics ?? this.haptics,
        demoMode: demoMode ?? this.demoMode,
        installId: installId,
      );
}

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  static const _k = 'bf.settings.';

  @override
  AppSettings build() {
    final p = _p;
    var install = p.getString('${_k}installId');
    if (install == null) {
      install = const Uuid().v4();
      p.setString('${_k}installId', install);
    }
    return AppSettings(
      themeMode: ThemeMode.values.byName(p.getString('${_k}theme') ?? ThemeMode.dark.name),
      units: UnitSystem.values.byName(p.getString('${_k}units') ?? UnitSystem.metric.name),
      remindersEnabled: p.getBool('${_k}reminders') ?? false,
      reminderMinutes: p.getInt('${_k}reminderMinutes') ?? 7 * 60,
      restAlerts: p.getBool('${_k}restAlerts') ?? true,
      weeklyCheckReminder: p.getBool('${_k}weekly') ?? true,
      haptics: p.getBool('${_k}haptics') ?? true,
      demoMode: p.getBool('${_k}demo') ?? false,
      installId: install,
    );
  }

  void _save(AppSettings s) {
    final p = _p;
    p.setString('${_k}theme', s.themeMode.name);
    p.setString('${_k}units', s.units.name);
    p.setBool('${_k}reminders', s.remindersEnabled);
    p.setInt('${_k}reminderMinutes', s.reminderMinutes);
    p.setBool('${_k}restAlerts', s.restAlerts);
    p.setBool('${_k}weekly', s.weeklyCheckReminder);
    p.setBool('${_k}haptics', s.haptics);
    p.setBool('${_k}demo', s.demoMode);
    state = s;
  }

  void update(AppSettings Function(AppSettings s) f) => _save(f(state));
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
