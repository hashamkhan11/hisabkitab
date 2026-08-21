import 'dart:async';

import '../services/api_client.dart';

/// Centralizes notification access against the Laravel API (`/api/notifications`).
///
/// `notificationsStream` replaces the old Firestore `.snapshots()` listener with
/// ~15s polling (confirmed acceptable trade-off - see migration plan §4).
class NotificationRepository {
  static const _pollInterval = Duration(seconds: 15);

  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    late final StreamController<List<Map<String, dynamic>>> controller;
    Timer? timer;

    Future<void> tick() async {
      try {
        final data = await ApiClient.instance.get('/notifications') as List<dynamic>;
        controller.add(data.cast<Map<String, dynamic>>());
      } catch (_) {
        // Preserves the existing resilience style used throughout the repositories:
        // swallow and let the next poll retry rather than surfacing a stream error.
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        tick();
        timer = Timer.periodic(_pollInterval, (_) => tick());
      },
      onCancel: () => timer?.cancel(),
    );

    return controller.stream;
  }

  static Future<Map<String, dynamic>> create({required String title, String? body}) async {
    final data = await ApiClient.instance.post('/notifications', body: {
      'title': title,
      if (body != null) 'body': body,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> markRead(String id) async {
    await ApiClient.instance.patch('/notifications/$id', body: {'is_read': true});
  }

  static Future<void> markAllRead() async {
    await ApiClient.instance.post('/notifications/mark-all-read');
  }
}
