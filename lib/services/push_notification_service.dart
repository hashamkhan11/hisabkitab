import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hisabshare/services/notification_service.dart';

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
        final userId = currentUser.uid;
        // 
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
              'title': notification.title ?? 'No Title',
              'body': messageBody,
              'timestamp': Timestamp.now(),
              'isRead': false,
            });
        //
        NotificationService().showNotification(
          title: notification.title ?? 'No Title',
          body: messageBody,
        );
      }
    });
  }
}
  