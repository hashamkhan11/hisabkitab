import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../repositories/notification_repository.dart';
import 'notification_service.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static Future<void> initialize() async {
    await _messaging.requestPermission();
    await _messaging.getToken();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final messageBody = notification?.body ?? '';
      final currentUser = FirebaseAuth.instance.currentUser;
      if (notification != null && currentUser != null) {
        // Pre-existing bug, preserved as-is (not fixed here, flagged to user):
        // this writes the notification directly, then showNotification() below
        // writes the same title/body again, so every foreground push is
        // persisted twice.
        await NotificationRepository.create(
          title: notification.title ?? 'No Title',
          body: messageBody,
        );

        NotificationService().showNotification(
          title: notification.title ?? 'No Title',
          body: messageBody,
        );
      }
    });
  }
}
