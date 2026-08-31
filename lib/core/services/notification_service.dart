import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._init();
  
  final List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  NotificationService._init();

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void addNotification(String title, String body, {String type = 'INFO'}) {
    _notifications.insert(0, {
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'isRead': false,
    });
    _unreadCount++;

    // TACTICAL FEEDBACK: Vibrate device based on alert level
    if (type == 'ADMIN' || type == 'SYSTEM') {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    } else if (type == 'AI') {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    notifyListeners();
  }

  void markAllAsRead() {
    for (var note in _notifications) {
      note['isRead'] = true;
    }
    _unreadCount = 0;
    notifyListeners();
  }
}
