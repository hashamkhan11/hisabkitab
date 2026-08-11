import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralizes Firestore access for `users/{uid}/notifications`.
class NotificationRepository {
  static Stream<QuerySnapshot> notificationsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Future<void> markAllRead(String uid) async {
    final unread = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
  }
}
