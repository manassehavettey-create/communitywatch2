import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/day_key.dart';

/// Payloads carried by notification taps, handled by the router.
abstract final class NotificationPayload {
  static const timer = 'timer';
  static const newEntry = 'entry';
  static String skill(int id) => 'skill:$id';
}

/// Gentle prompts used by the daily journal reminder; one per day, rotating.
const gentlePrompts = <String>[
  'What made you smile today?',
  'Name one small win from today — it counts.',
  'Who are you grateful for right now?',
  'What went better than expected today?',
  'What did you learn today, even a little?',
  "What's one thing you'd like to remember about today?",
  'What are you proud of from this week?',
  'A tiny good moment is still a good moment. What was yours?',
  'What progress did you make, however small?',
  'What made today a little easier?',
  'Who helped you lately? Write it down.',
  'What are you looking forward to?',
  'What did you do today that future-you will thank you for?',
  'Take a breath. What felt good today?',
];

/// Picks the prompt for a given day so it rotates predictably.
String promptForDay(DayKey day) =>
    gentlePrompts[Days.between(20240101, day).abs() % gentlePrompts.length];

/// Local notifications: practice reminders, the rotating journal reminder
/// and the ongoing "timer running" notification.
///
/// Every method is safe to call when notifications are unavailable (tests,
/// permission denied): failures are logged, never thrown into the UI.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _timerId = 1;
  static const _skillBase = 100000;
  static const _logBase = 200000;
  static const logDaysAhead = 14;

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  /// Payload of the notification that cold-started the app, if any.
  String? launchPayload;

  Stream<String> get taps => _taps.stream;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _configureLocalTimezone();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_growth'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null) _taps.add(p);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e, st) {
      debugPrint('Notifications unavailable: $e\n$st');
    }
  }

  /// Re-reads the device time zone (call on resume: the user may have
  /// travelled). Returns true if it changed.
  Future<bool> refreshTimezone() async {
    if (!_ready) return false;
    final before = tz.local.name;
    await _configureLocalTimezone();
    return tz.local.name != before;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to any zone with the device's current UTC offset.
      final offset = DateTime.now().timeZoneOffset.inMilliseconds;
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (l) => l.currentTimeZone.offset.inMilliseconds == offset,
        orElse: () => tz.UTC,
      );
      tz.setLocalLocation(match);
    }
  }

  /// Asks for permission (Android 13+ / iOS). Returns whether granted.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
    return false;
  }

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Daily practice and journal reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Color(0xFFC8EC64),
    ),
    iOS: DarwinNotificationDetails(),
  );

  tz.TZDateTime _at(DateTime localDate, int minutes) {
    return tz.TZDateTime(
      tz.local,
      localDate.year,
      localDate.month,
      localDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  tz.TZDateTime _nextInstance(int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    var at = _at(now, minutes);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  Future<void> scheduleSkillReminder({
    required int skillId,
    required String skillName,
    required int minutes,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: _skillBase + skillId,
        title: 'Time for $skillName',
        body: 'Even 15 focused minutes moves you forward.',
        scheduledDate: _nextInstance(minutes),
        notificationDetails: _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: NotificationPayload.skill(skillId),
      );
    } catch (e) {
      debugPrint('Could not schedule skill reminder: $e');
    }
  }

  Future<void> cancelSkillReminder(int skillId) =>
      _cancel(_skillBase + skillId);

  /// Schedules the journal reminder for the next [logDaysAhead] days, each
  /// with its own rotating prompt. Today is skipped if already logged.
  Future<void> scheduleLogReminders({
    required bool enabled,
    required int minutes,
    required bool loggedToday,
  }) async {
    if (!_ready) return;
    for (var i = 0; i < logDaysAhead; i++) {
      await _cancel(_logBase + i);
    }
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    final today = Days.keyOf(now);
    for (var i = 0; i < logDaysAhead; i++) {
      final day = Days.add(today, i);
      final at = _at(Days.dateOf(day), minutes);
      if (!at.isAfter(now)) continue;
      if (i == 0 && loggedToday) continue;
      try {
        await _plugin.zonedSchedule(
          id: _logBase + i,
          title: 'Growth Log',
          body: promptForDay(day),
          scheduledDate: at,
          notificationDetails: _reminderDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: NotificationPayload.newEntry,
        );
      } catch (e) {
        debugPrint('Could not schedule log reminder: $e');
      }
    }
  }

  /// Ongoing notification with a live chronometer (Android). On iOS a quiet
  /// one-off notice is shown instead.
  Future<void> showTimer({
    required String skillName,
    required DateTime startedAt,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _timerId,
        title: 'Practising $skillName',
        body: 'Tap to open the timer',
        payload: NotificationPayload.timer,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'timer',
            'Practice timer',
            channelDescription: 'Shows while a practice timer is running',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: true,
            when: startedAt.millisecondsSinceEpoch,
            usesChronometer: true,
            category: AndroidNotificationCategory.stopwatch,
            color: const Color(0xFFC8EC64),
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: false,
            interruptionLevel: InterruptionLevel.passive,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not show timer notification: $e');
    }
  }

  Future<void> cancelTimer() => _cancel(_timerId);

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }

  Future<void> _cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('cancel($id) failed: $e');
    }
  }
}
