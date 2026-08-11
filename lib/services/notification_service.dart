import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Save notification to Firestore and optionally show a banner
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Save notification in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'timestamp': Timestamp.now(),
      'isRead': false,
    });

    
    _showInAppBanner(title: title, body: body);
  }

  void _showInAppBanner({required String title, required String body}) {
    // Print or implement in-app animated banner logic here
  }
}
