import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hisabshare/services/notification_service.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // iOS permission
    await _messaging.requestPermission();

    // Get device token (for testing with Firebase Console)
    final token = await _messaging.getToken();
    print(" FCM Token: $token");

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        NotificationService().showNotification(
          title: notification.title ?? 'No Title',
          body: notification.body ?? 'No Body',
        );
      }
    });

    // Tap on notification handling
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Optional: Navigate based on message.data
    });
  }
}
