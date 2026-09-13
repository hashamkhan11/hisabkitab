import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static Future<void> initialize() async {
    try {
      await _messaging.requestPermission();
      await _messaging.getToken().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Push setup is best-effort - a slow/offline network or a denied
      // permission shouldn't crash the app or block anything else.
    }

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final messageBody = notification?.body ?? '';
      final currentUser = FirebaseAuth.instance.currentUser;
      if (notification != null && currentUser != null) {
        NotificationService().showNotification(
          title: notification.title ?? 'No Title',
          body: messageBody,
        );
      }
    });
  }
}
