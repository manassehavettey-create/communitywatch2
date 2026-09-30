import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';
import 'local_store.dart';

/// Granular notification categories (spec §30).
enum NotifKind {
  // Teams
  matchStart('Match starting', NotifGroup.team),
  goals('Goals', NotifGroup.team),
  halfTime('Half-time', NotifGroup.team),
  fullTime('Full-time', NotifGroup.team),
  redCards('Red cards', NotifGroup.team),
  lineups('Lineups', NotifGroup.team),
  substitutions('Substitutions', NotifGroup.team),
  importantEvents('Important events (VAR, penalties)', NotifGroup.team),
  // Players
  playerGoal('Goal', NotifGroup.player),
  playerAssist('Assist', NotifGroup.player),
  playerStarting('Starting lineup', NotifGroup.player),
  playerSub('Substitution', NotifGroup.player),
  playerRed('Red card', NotifGroup.player),
  // Competitions
  results('Match results', NotifGroup.competition),
  importantFixtures('Important fixtures', NotifGroup.competition),
  leagueUpdates('League updates', NotifGroup.competition);

  const NotifKind(this.label, this.group);
  final String label;
  final NotifGroup group;

  static List<NotifKind> of(NotifGroup g) => values.where((k) => k.group == g).toList();
}

enum NotifGroup { team, player, competition }

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.reduceMotion = false,
    this.demoMode = false,
    this.dataSaver = false,
    this.seasonOverride,
    this.onboarded = false,
    this.language = 'en',
    this.notificationsEnabled = true,
    this.disabledKinds = const {},
  });

  final ThemeMode themeMode;
  final bool reduceMotion;
  final bool demoMode;
  final bool dataSaver;

  /// Lets free-tier users pick a season their plan covers.
  final int? seasonOverride;
  final bool onboarded;
  final String language;
  final bool notificationsEnabled;

  /// Categories switched off globally (overrides per-entity toggles).
  final Set<NotifKind> disabledKinds;

  /// Demo is only honoured in debug builds.
  bool get useDemo => Env.demoAllowed && (demoMode || !Env.hasKey);

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? reduceMotion,
    bool? demoMode,
    bool? dataSaver,
    int? seasonOverride,
    bool clearSeason = false,
    bool? onboarded,
    String? language,
    bool? notificationsEnabled,
    Set<NotifKind>? disabledKinds,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        demoMode: demoMode ?? this.demoMode,
        dataSaver: dataSaver ?? this.dataSaver,
        seasonOverride: clearSeason ? null : (seasonOverride ?? this.seasonOverride),
        onboarded: onboarded ?? this.onboarded,
        language: language ?? this.language,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        disabledKinds: disabledKinds ?? this.disabledKinds,
      );

  Map<String, dynamic> toJson() => {
        'theme': themeMode.name,
        'reduceMotion': reduceMotion,
        'demo': demoMode,
        'saver': dataSaver,
        'season': seasonOverride,
        'onboarded': onboarded,
        'lang': language,
        'notif': notificationsEnabled,
        'off': disabledKinds.map((k) => k.name).toList(),
      };

  static AppSettings fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AppSettings(demoMode: true);
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[j['theme']] ?? ThemeMode.dark,
      reduceMotion: j['reduceMotion'] == true,
      demoMode: j['demo'] == true,
      dataSaver: j['saver'] == true,
      seasonOverride: (j['season'] as num?)?.toInt(),
      onboarded: j['onboarded'] == true,
      language: j['lang'] as String? ?? 'en',
      notificationsEnabled: j['notif'] != false,
      disabledKinds: {for (final n in (j['off'] as List? ?? const [])) if (NotifKind.values.asNameMap()[n] != null) NotifKind.values.asNameMap()[n]!},
    );
  }
}

final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('Overridden in main()'));

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.fromJson(ref.read(localStoreProvider).readMap('settings'));

  void update(AppSettings Function(AppSettings s) f) {
    state = f(state);
    ref.read(localStoreProvider).write('settings', state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
