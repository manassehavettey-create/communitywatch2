import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: training reminders, rest-over alerts while the app is
/// in the background, and the Sunday weekly reality check. All scheduling is
/// on-device — no server involved.
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _restId = 200;
  static const _weeklyId = 300;
  static int _reminderId(int weekday) => 100 + weekday;

  static const _channelTraining = AndroidNotificationDetails(
    'bf_training',
    'Training reminders',
    channelDescription: 'Your daily mission reminders',
    importance: Importance.defaultImportance,
  );
  static const _channelRest = AndroidNotificationDetails(
    'bf_rest',
    'Rest timer',
    channelDescription: 'Tells you when your rest is over',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone init failed, using UTC: $e');
    }
    try {
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
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Ask for permission (Android 13+ / iOS). Returns whether granted.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true, badge: false) ?? false;
    return false;
  }

  Future<AndroidScheduleMode> _mode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final exact = await android.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  tz.TZDateTime _nextWeekdayAt(int weekday, int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    while (d.weekday != weekday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Weekly reminders on training [weekdays] at [minutes] after midnight.
  Future<void> scheduleTrainingReminders({required List<int> weekdays, required int minutes}) async {
    if (!_ready) return;
    await cancelTrainingReminders();
    final mode = await _mode();
    for (final w in weekdays) {
      await _plugin.zonedSchedule(
        id: _reminderId(w),
        title: 'Today\'s mission is ready',
        body: 'Something is better than nothing. Open BODYFORGE and train.',
        scheduledDate: _nextWeekdayAt(w, minutes),
        notificationDetails: const NotificationDetails(android: _channelTraining, iOS: DarwinNotificationDetails()),
        androidScheduleMode: mode == AndroidScheduleMode.exactAllowWhileIdle
            ? AndroidScheduleMode.inexactAllowWhileIdle
            : mode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelTrainingReminders() async {
    if (!_ready) return;
    for (var w = 1; w <= 7; w++) {
      await _plugin.cancel(id: _reminderId(w));
    }
  }

  Future<void> scheduleWeeklyCheck() async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id: _weeklyId,
      title: 'Your weekly reality check',
      body: 'See what actually changed this week.',
      scheduledDate: _nextWeekdayAt(DateTime.sunday, 18 * 60),
      notificationDetails: const NotificationDetails(android: _channelTraining, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelWeeklyCheck() async {
    if (_ready) await _plugin.cancel(id: _weeklyId);
  }

  /// Alert when a rest ends while the app is in the background.
  Future<void> scheduleRestEnd(DateTime at, String next) async {
    if (!_ready) return;
    final when = tz.TZDateTime.from(at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: _restId,
      title: 'Rest over — let\'s go',
      body: 'Next up: $next',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: _channelRest,
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
      androidScheduleMode: await _mode(),
    );
  }

  Future<void> cancelRestEnd() async {
    if (_ready) await _plugin.cancel(id: _restId);
  }
}
