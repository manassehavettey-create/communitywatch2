import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../repositories/settings_repository.dart';

/// Local-only reading reminders. Nothing is sent to a server; the OS
/// schedules the notification on-device.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const int _reminderId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() async {
    if (!isSupported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC-based scheduling.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks the OS for permission. Returns true if notifications can be shown.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Schedules (or cancels) the daily reading reminder to match [s].
  Future<void> applySettings(AppSettings s) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancel(id: _reminderId);
    if (!s.reminderEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      s.reminderMinutes ~/ 60,
      s.reminderMinutes % 60,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _reminderId,
      scheduledDate: at,
      title: 'Time for a few pages',
      body: 'Your goal today is ${s.dailyGoalMinutes} minutes. Pick up where you left off.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reminders',
          'Reading reminders',
          channelDescription: 'A daily nudge to read, at the time you choose.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact is fine for a reading nudge and needs no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
