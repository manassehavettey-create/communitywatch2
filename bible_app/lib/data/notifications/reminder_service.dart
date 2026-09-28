import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/database.dart';

/// Local notifications: the daily reading reminder and prayer reminders.
/// Scheduling is inexact (no exact-alarm permission needed) and survives
/// reboots on Android via the plugin's boot receiver.
class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const readingId = 1;
  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Reading and prayer reminders you set',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  bool _ready = false;

  /// Notifications aren't scheduled on web.
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      // Unknown zone name: fall back to UTC offsets as reported.
      tz.setLocalLocation(tz.UTC);
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

  /// Asks for permission; returns whether notifications are allowed.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
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

  tz.TZDateTime _nextAt(int minutesAfterMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesAfterMidnight ~/ 60,
      minutesAfterMidnight % 60,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  Future<void> scheduleReading(int minutesAfterMidnight) async {
    if (!supported) return;
    await init();
    await _plugin.zonedSchedule(
      id: readingId,
      title: 'Time to read',
      body: 'A few quiet minutes in Scripture.',
      scheduledDate: _nextAt(minutesAfterMidnight),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'reading',
    );
  }

  Future<void> cancelReading() async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id: readingId);
  }

  /// Stable notification id for a prayer (ids 1000+).
  static int prayerNotificationId(String prayerId) =>
      1000 + (prayerId.hashCode & 0x3FFFFFF);

  /// Re-schedules every prayer reminder from the database.
  Future<void> syncPrayerReminders(List<Prayer> prayers) async {
    if (!supported) return;
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= 1000) await _plugin.cancel(id: p.id);
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final p in prayers) {
      final v = p.reminderValue;
      if (v == null || p.status != 'active') continue;
      final id = prayerNotificationId(p.id);
      if (p.reminderKind == 'daily') {
        await _plugin.zonedSchedule(
          id: id,
          title: 'Prayer reminder',
          body: p.title,
          scheduledDate: _nextAt(v),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'prayer:${p.id}',
        );
      } else if (p.reminderKind == 'once' && v > now) {
        await _plugin.zonedSchedule(
          id: id,
          title: 'Prayer reminder',
          body: p.title,
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, v),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'prayer:${p.id}',
        );
      }
    }
  }
}
