import 'dart:async';

import '../services/api_client.dart';
import '../services/local_cache.dart';
import '../services/polling.dart';

/// Home screen's total Send/Receive balance across every transaction the
/// user owns, via `/api/summary/balance` (replaces the old
/// `collectionGroup('transactions')` listener).
class SummaryRepository {
  static const _pollInterval = Duration(seconds: 15);
  static const _cacheKey = 'summary_balance';

  static Stream<Map<String, dynamic>> balanceStream() {
    return pollingStream(
      interval: _pollInterval,
      fetch: () async {
        final data = await ApiClient.instance.get('/summary/balance') as Map<String, dynamic>;
        unawaited(LocalCache.putJson(_cacheKey, data));
        return data;
      },
      initialValue: () async {
        final cached = await LocalCache.getJson(_cacheKey);
        return cached == null ? null : cached as Map<String, dynamic>;
      },
    );
  }
}
