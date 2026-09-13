import 'dart:async';

import '../services/api_client.dart';
import '../services/local_cache.dart';
import '../services/polling.dart';

/// Centralizes notification access against the Laravel API (`/api/notifications`).
///
/// `notificationsStream` replaces the old Firestore `.snapshots()` listener with
/// ~15s polling (confirmed acceptable trade-off - see migration plan §4).
class NotificationRepository {
  static const _pollInterval = Duration(seconds: 15);
  static const _cacheKey = 'notifications';

  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    return pollingStream(
      interval: _pollInterval,
      fetch: () async {
        final data = await ApiClient.instance.get('/notifications') as List<dynamic>;
        final items = data.cast<Map<String, dynamic>>();
        unawaited(LocalCache.putJson(_cacheKey, items));
        return items;
      },
      initialValue: () async {
        final cached = await LocalCache.getJson(_cacheKey);
        if (cached == null) return null;
        return (cached as List<dynamic>).cast<Map<String, dynamic>>();
      },
    );
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

  static Future<void> delete(String id) async {
    await ApiClient.instance.delete('/notifications/$id');
  }

  static Future<void> bulkDelete(List<String> ids) async {
    await ApiClient.instance.post('/notifications/bulk-delete', body: {'ids': ids});
  }

  static Future<void> clearAll() async {
    await ApiClient.instance.delete('/notifications');
  }
}
