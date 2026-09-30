import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class AppAlert {
  const AppAlert({required this.id, required this.title, required this.body, this.route, this.goal = false});
  final int id;
  final String title;
  final String body;
  final String? route;
  final bool goal;
}

/// Local notifications (spec: local-only, no push server). Alerts fire while
/// the app is running or recently backgrounded; kick-off reminders are
/// scheduled with the OS and fire even when the app is closed.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// In-app banners (shown instead of system notifications while the app is
  /// in the foreground).
  final alerts = StreamController<AppAlert>.broadcast();

  /// Routes from tapped notifications.
  final taps = StreamController<String>.broadcast();

  static const _live = AndroidNotificationDetails('live', 'Live match alerts',
      channelDescription: 'Goals, cards and results for teams and players you follow', importance: Importance.high, priority: Priority.high);
  static const _reminders = AndroidNotificationDetails('kickoff', 'Kick-off reminders', channelDescription: 'Reminders when followed matches start', importance: Importance.defaultImportance);

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) taps.add(r.payload!);
        },
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return false;
  }

  bool get _foreground => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> show(AppAlert a) async {
    if (_foreground || !_ready) {
      alerts.add(a);
      return;
    }
    try {
      await _plugin.show(id: a.id, title: a.title, body: a.body, notificationDetails: const NotificationDetails(android: _live, iOS: DarwinNotificationDetails()), payload: a.route);
    } catch (_) {
      alerts.add(a);
    }
  }

  Future<void> scheduleAt({required int id, required DateTime when, required String title, required String body, String? route}) async {
    if (!_ready || when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(android: _reminders, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: route,
      );
    } catch (e) {
      debugPrint('Schedule failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id: id);
  }
}
