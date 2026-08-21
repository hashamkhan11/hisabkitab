import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/notification_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Save notification via the API and optionally show a banner.
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await NotificationRepository.create(title: title, body: body);

    _showInAppBanner(title: title, body: body);
  }

  void _showInAppBanner({required String title, required String body}) {
    // Print or implement in-app animated banner logic here
  }
}
