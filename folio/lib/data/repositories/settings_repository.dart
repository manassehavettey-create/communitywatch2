import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../core/db/database.dart';
import '../../core/theme/reader_themes.dart';
import 'books_repository.dart';

enum ReaderViewMode {
  scroll('Scroll'),
  page('Page by page'),
  text('Text');

  const ReaderViewMode(this.label);
  final String label;
}

enum FitMode {
  width('Fit width'),
  page('Fit page');

  const FitMode(this.label);
  final String label;
}

enum LibraryLayout { grid, list }

/// All user preferences. Stored as one JSON document in `settings`.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.readerTheme = ReaderTheme.paper,
    this.followSystemForReader = true,
    this.viewMode = ReaderViewMode.scroll,
    this.fitMode = FitMode.width,
    this.textScale = 18,
    this.lineHeight = 1.6,
    this.textWidth = 640,
    this.dailyGoalMinutes = 20,
    this.reminderEnabled = false,
    this.reminderMinutes = 20 * 60 + 30,
    this.onboardingDone = false,
    this.name = '',
    this.libraryLayout = LibraryLayout.grid,
    this.librarySort = LibrarySort.recentlyOpened,
    this.showDemoData = false,
  });

  final ThemeMode themeMode;
  final ReaderTheme readerTheme;

  /// When true, the reader uses Night automatically while the app is dark.
  final bool followSystemForReader;
  final ReaderViewMode viewMode;
  final FitMode fitMode;

  /// Text view: font size (logical px), line height and max column width.
  final double textScale;
  final double lineHeight;
  final double textWidth;
  final int dailyGoalMinutes;
  final bool reminderEnabled;

  /// Reminder time as minutes after local midnight.
  final int reminderMinutes;
  final bool onboardingDone;
  final String name;
  final LibraryLayout libraryLayout;
  final LibrarySort librarySort;

  /// Debug builds only: seed sample data.
  final bool showDemoData;

  AppSettings copyWith({
    ThemeMode? themeMode,
    ReaderTheme? readerTheme,
    bool? followSystemForReader,
    ReaderViewMode? viewMode,
    FitMode? fitMode,
    double? textScale,
    double? lineHeight,
    double? textWidth,
    int? dailyGoalMinutes,
    bool? reminderEnabled,
    int? reminderMinutes,
    bool? onboardingDone,
    String? name,
    LibraryLayout? libraryLayout,
    LibrarySort? librarySort,
    bool? showDemoData,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    readerTheme: readerTheme ?? this.readerTheme,
    followSystemForReader: followSystemForReader ?? this.followSystemForReader,
    viewMode: viewMode ?? this.viewMode,
    fitMode: fitMode ?? this.fitMode,
    textScale: textScale ?? this.textScale,
    lineHeight: lineHeight ?? this.lineHeight,
    textWidth: textWidth ?? this.textWidth,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    name: name ?? this.name,
    libraryLayout: libraryLayout ?? this.libraryLayout,
    librarySort: librarySort ?? this.librarySort,
    showDemoData: showDemoData ?? this.showDemoData,
  );

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.index,
    'readerTheme': readerTheme.index,
    'followSystemForReader': followSystemForReader,
    'viewMode': viewMode.index,
    'fitMode': fitMode.index,
    'textScale': textScale,
    'lineHeight': lineHeight,
    'textWidth': textWidth,
    'dailyGoalMinutes': dailyGoalMinutes,
    'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes,
    'onboardingDone': onboardingDone,
    'name': name,
    'libraryLayout': libraryLayout.index,
    'librarySort': librarySort.index,
    'showDemoData': showDemoData,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    T pick<T>(List<T> values, Object? i, T fallback) =>
        (i is int && i >= 0 && i < values.length) ? values[i] : fallback;
    double dbl(Object? v, double f) => v is num ? v.toDouble() : f;
    int integer(Object? v, int f) => v is num ? v.toInt() : f;
    bool boolean(Object? v, bool f) => v is bool ? v : f;
    return AppSettings(
      themeMode: pick(ThemeMode.values, j['themeMode'], d.themeMode),
      readerTheme: pick(ReaderTheme.values, j['readerTheme'], d.readerTheme),
      followSystemForReader: boolean(j['followSystemForReader'], d.followSystemForReader),
      viewMode: pick(ReaderViewMode.values, j['viewMode'], d.viewMode),
      fitMode: pick(FitMode.values, j['fitMode'], d.fitMode),
      textScale: dbl(j['textScale'], d.textScale).clamp(14.0, 28.0),
      lineHeight: dbl(j['lineHeight'], d.lineHeight).clamp(1.3, 2.0),
      textWidth: dbl(j['textWidth'], d.textWidth).clamp(420.0, 900.0),
      dailyGoalMinutes: integer(j['dailyGoalMinutes'], d.dailyGoalMinutes).clamp(5, 240),
      reminderEnabled: boolean(j['reminderEnabled'], d.reminderEnabled),
      reminderMinutes: integer(j['reminderMinutes'], d.reminderMinutes).clamp(0, 24 * 60 - 1),
      onboardingDone: boolean(j['onboardingDone'], d.onboardingDone),
      name: j['name'] is String ? j['name'] as String : d.name,
      libraryLayout: pick(LibraryLayout.values, j['libraryLayout'], d.libraryLayout),
      librarySort: pick(LibrarySort.values, j['librarySort'], d.librarySort),
      showDemoData: boolean(j['showDemoData'], d.showDemoData),
    );
  }
}

class SettingsRepository {
  SettingsRepository(this.db);
  final AppDatabase db;

  static const _key = 'app';

  Future<AppSettings> load() async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(_key))).getSingleOrNull();
    if (row == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(row.value) as Map<String, Object?>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: _key, value: jsonEncode(s.toJson())));

  Future<String?> getRaw(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setRaw(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.settings)..where((s) => s.key.equals(key))).go();
    } else {
      await db.into(db.settings).insertOnConflictUpdate(SettingsCompanion(key: Value(key), value: Value(value)));
    }
  }
}
