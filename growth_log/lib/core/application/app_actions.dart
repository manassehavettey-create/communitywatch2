import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/log/data/entry_repository.dart';
import '../../features/settings/data/backup_service.dart';
import '../../features/skills/data/milestone_repository.dart';
import '../../features/skills/data/skill_repository.dart';
import '../db/database.dart';
import '../providers.dart';
import '../utils/day_key.dart';

/// Use-cases that touch more than one repository or service. Screens call
/// these instead of repositories so side effects (milestones, notifications,
/// haptics) stay consistent everywhere.
class AppActions {
  AppActions(this._ref);

  final Ref _ref;

  SkillRepository get _skills => _ref.read(skillRepositoryProvider);
  EntryRepository get _entries => _ref.read(entryRepositoryProvider);
  MilestoneRepository get _milestones => _ref.read(milestoneRepositoryProvider);

  // --------------------------------------------------------------- skills

  Future<int> createSkill(SkillDraft draft) async {
    final id = await _skills.createSkill(draft);
    await _syncSkillReminder(id);
    _ref.read(hapticsProvider).medium();
    return id;
  }

  Future<void> updateSkill(int id, SkillDraft draft) async {
    await _skills.updateSkill(id, draft);
    await _syncSkillReminder(id);
    // Milestone wins mention the skill's name; they keep the old name
    // intentionally — they're a record of that moment.
  }

  Future<void> setArchived(int id, {required bool archived}) async {
    final timer = await _ref.read(timerRepositoryProvider).active();
    await _skills.setArchived(id, archived: archived);
    if (archived && timer?.skillId == id) {
      await _ref.read(notificationServiceProvider).cancelTimer();
    }
    await _syncSkillReminder(id);
  }

  Future<void> deleteSkill(int id) async {
    final timer = await _ref.read(timerRepositoryProvider).active();
    await _skills.deleteSkill(id);
    final notifications = _ref.read(notificationServiceProvider);
    await notifications.cancelSkillReminder(id);
    if (timer?.skillId == id) await notifications.cancelTimer();
    _ref.read(hapticsProvider).heavy();
  }

  Future<void> setSkillReminder(int id, {required bool enabled, int? minutes}) async {
    if (enabled) await _ref.read(notificationServiceProvider).requestPermission();
    await _skills.setReminder(id, enabled: enabled, minutes: minutes);
    await _syncSkillReminder(id);
  }

  Future<void> _syncSkillReminder(int id) async {
    final notifications = _ref.read(notificationServiceProvider);
    final skill = await _skills.getSkill(id);
    if (skill == null || !skill.reminderEnabled || skill.archivedAt != null) {
      await notifications.cancelSkillReminder(id);
      return;
    }
    await notifications.scheduleSkillReminder(
      skillId: id,
      skillName: skill.name,
      minutes: skill.reminderMinutes,
    );
  }

  // ------------------------------------------------------------- sessions

  Future<List<Achievement>> logSession({
    required int skillId,
    required DayKey dayKey,
    required int durationSec,
    String? note,
  }) async {
    await _skills.addSession(
      skillId: skillId,
      dayKey: dayKey,
      durationSec: durationSec,
      note: note,
    );
    _ref.read(hapticsProvider).medium();
    return _milestones.reconcile(skillId);
  }

  Future<List<Achievement>> updateSession(
    SessionRow before, {
    required int skillId,
    required DayKey dayKey,
    required int durationSec,
    String? note,
  }) async {
    await _skills.updateSession(
      before.id,
      skillId: skillId,
      dayKey: dayKey,
      durationSec: durationSec,
      note: note,
    );
    final result = await _milestones.reconcile(skillId);
    if (before.skillId != skillId) await _milestones.reconcile(before.skillId);
    return result;
  }

  Future<void> deleteSession(SessionRow row) async {
    await _skills.deleteSession(row.id);
    await _milestones.reconcile(row.skillId);
    _ref.read(hapticsProvider).light();
  }

  Future<List<Achievement>> restoreSession(SessionRow row) async {
    await _skills.restoreSession(row);
    return _milestones.reconcile(row.skillId);
  }

  // ---------------------------------------------------------------- timer

  Future<void> startTimer(int skillId) async {
    final row = await _ref.read(timerRepositoryProvider).start(skillId);
    final skill = await _skills.getSkill(skillId);
    _ref.read(hapticsProvider).medium();
    await _ref.read(notificationServiceProvider).showTimer(
          skillName: skill?.name ?? 'your skill',
          startedAt: row.startedAt,
        );
  }

  /// Returns null when nothing was saved (under a minute).
  Future<List<Achievement>?> stopTimer({int? durationSec, String? note}) async {
    final stopped = await _ref
        .read(timerRepositoryProvider)
        .stop(durationSec: durationSec, note: note);
    await _ref.read(notificationServiceProvider).cancelTimer();
    if (stopped == null || stopped.sessionId == null) return null;
    _ref.read(hapticsProvider).medium();
    return _milestones.reconcile(stopped.skillId);
  }

  Future<void> discardTimer() async {
    await _ref.read(timerRepositoryProvider).discard();
    await _ref.read(notificationServiceProvider).cancelTimer();
    _ref.read(hapticsProvider).light();
  }

  /// Re-shows the ongoing notification after a cold start (e.g. the app was
  /// killed and the notification swiped away).
  Future<void> restoreTimerNotification() async {
    final timer = await _ref.read(timerRepositoryProvider).active();
    if (timer == null) return;
    final skill = await _skills.getSkill(timer.skillId);
    await _ref.read(notificationServiceProvider).showTimer(
          skillName: skill?.name ?? 'your skill',
          startedAt: timer.startedAt,
        );
  }

  // --------------------------------------------------------------- journal

  Future<int> addEntry(EntryDraft draft) async {
    final id = await _entries.addEntry(draft);
    _ref.read(hapticsProvider).medium();
    unawaited(syncLogReminders());
    return id;
  }

  Future<void> updateEntry(int id, EntryDraft draft) async {
    await _entries.updateEntry(id, draft);
    unawaited(syncLogReminders());
  }

  Future<void> deleteEntry(EntryView view) async {
    await _entries.deleteEntry(view.entry.id);
    _ref.read(hapticsProvider).light();
    unawaited(syncLogReminders());
  }

  Future<void> restoreEntry(EntryView view) async {
    await _entries.restoreEntry(view);
    unawaited(syncLogReminders());
  }

  // ------------------------------------------------------------ reminders

  Future<void> setLogReminder({required bool enabled, int? minutes}) async {
    if (enabled) await _ref.read(notificationServiceProvider).requestPermission();
    await _ref
        .read(settingsProvider.notifier)
        .setLogReminder(enabled: enabled, minutes: minutes);
    await syncLogReminders();
  }

  Future<void> syncLogReminders() async {
    final settings = _ref.read(settingsProvider);
    final today = _ref.read(clockProvider).today();
    final loggedToday = (await _entries.entryDays()).contains(today);
    await _ref.read(notificationServiceProvider).scheduleLogReminders(
          enabled: settings.logReminderEnabled,
          minutes: settings.logReminderMinutes,
          loggedToday: loggedToday,
        );
  }

  /// Reschedules everything from stored state. Called at startup, on
  /// resume after a time-zone change, and after import/reset.
  Future<void> syncAllReminders() async {
    try {
      for (final s in await _skills.allSkills()) {
        await _syncSkillReminder(s.id);
      }
      await syncLogReminders();
    } catch (e) {
      debugPrint('Reminder sync failed: $e');
    }
  }

  // ----------------------------------------------------------------- data

  Future<BackupSummary> importBackup(String json) async {
    final notifications = _ref.read(notificationServiceProvider);
    final summary = await _ref.read(backupServiceProvider).importJson(json);
    await notifications.cancelAll();
    await _ref.read(settingsProvider.notifier).reload();
    await syncAllReminders();
    await restoreTimerNotification();
    return summary;
  }

  Future<void> resetAll() async {
    await _ref.read(notificationServiceProvider).cancelAll();
    await _ref.read(databaseProvider).wipe();
    await _ref.read(lockServiceProvider).clearPin();
    await _ref.read(settingsProvider.notifier).reload();
  }
}

final appActionsProvider = Provider<AppActions>(AppActions.new);
