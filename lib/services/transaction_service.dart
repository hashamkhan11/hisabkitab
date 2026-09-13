import 'dart:async';

import '../services/api_client.dart';
import '../services/local_cache.dart';
import '../services/polling.dart';

/// Centralizes transaction access against the Laravel API
/// (`/api/contacts/{contactId}/transactions`, `/api/transactions/{id}/...`).
///
/// `transactionStream` replaces the old Firestore `.snapshots()` listener with
/// ~15s polling (confirmed acceptable trade-off - see migration plan §4).
class TransactionService {
  static const _pollInterval = Duration(seconds: 15);

  static Stream<List<Map<String, dynamic>>> transactionStream({
    required String contactId,
    String? status,
  }) {
    return pollingStream(
      interval: _pollInterval,
      fetch: () => _fetchTransactions(contactId: contactId, status: status),
      initialValue: () => _cachedTransactions(contactId, status),
    );
  }

  static String _cacheKey(String contactId, String? status) =>
      'transactions_$contactId${status != null ? '_$status' : ''}';

  static Future<List<Map<String, dynamic>>> _fetchTransactions({
    required String contactId,
    String? status,
  }) async {
    final data = await ApiClient.instance.get(
      '/contacts/$contactId/transactions',
      query: {if (status != null) 'status': status, 'limit': '100'},
    ) as Map<String, dynamic>;

    final items = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    unawaited(LocalCache.putJson(_cacheKey(contactId, status), items));
    return items.map(_parseTransaction).toList();
  }

  /// Reads the raw (pre-parse) transactions cached by the last successful
  /// fetch, if any, and runs them through the same [_parseTransaction] step
  /// as a live response so cached and live data end up in the exact same
  /// shape.
  static Future<List<Map<String, dynamic>>?> _cachedTransactions(
    String contactId,
    String? status,
  ) async {
    final cached = await LocalCache.getJson(_cacheKey(contactId, status));
    if (cached == null) return null;
    return (cached as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_parseTransaction)
        .toList();
  }

  /// One-shot (non-polling) fetch across several contacts at once, merged and
  /// sorted newest-first - used to show "recent activity" for a whole
  /// category, since no backend endpoint aggregates transactions across
  /// contacts and a category only ever has a handful of them.
  static Future<List<Map<String, dynamic>>> recentAcrossContacts(
    List<Map<String, String>> contacts, {
    int limit = 5,
  }) async {
    final results = await Future.wait(contacts.map((contact) async {
      final txns = await _fetchTransactions(contactId: contact['id']!);
      return txns.map((t) => {
            ...t,
            'contactId': contact['id'],
            'contactName': contact['name'],
            if (contact['categoryId'] != null) 'categoryId': contact['categoryId'],
          });
    }));

    final merged = results.expand((x) => x).toList()
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return merged.take(limit).toList();
  }

  static Map<String, dynamic> _parseTransaction(Map<String, dynamic> json) {
    return {
      'id': json['id'],
      'date': DateTime.parse(json['date'] as String),
      'type': json['type'],
      'credit': double.tryParse(json['credit'].toString()) ?? 0.0,
      'note': json['note'] ?? '',
      'status': json['status'] ?? '',
      'sender_transaction_id': json['sender_transaction_id'],
    };
  }

  static Future<Map<String, dynamic>> addTransaction({
    required String contactId,
    required DateTime date,
    required String type,
    required double credit,
    String? note,
  }) async {
    final data = await ApiClient.instance.post('/contacts/$contactId/transactions', body: {
      'date': date.toIso8601String().split('T').first,
      'type': type,
      'credit': credit,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> updateNote({required String transactionId, required String note}) async {
    await ApiClient.instance.patch('/transactions/$transactionId/note', body: {'note': note});
  }

  static Future<void> acceptTransaction(String transactionId) async {
    await ApiClient.instance.post('/transactions/$transactionId/accept');
  }

  static Future<void> rejectTransaction(String transactionId) async {
    await ApiClient.instance.post('/transactions/$transactionId/reject');
  }

  // Not called from any UI yet - carried over unwired from the original
  // Firestore version (no delete-transaction feature exists in the app today).
  static Future<void> deleteTransaction(String transactionId) async {
    await ApiClient.instance.delete('/transactions/$transactionId');
  }

  static double calculateBalance(List<Map<String, dynamic>> txns) {
    double balance = 0.0;
    for (var tx in txns) {
      double amount = tx['credit'] ?? 0.0;
      if (tx['type'] == 'Receive') {
        balance += amount;
      } else if (tx['type'] == 'Send') {
        balance -= amount;
      }
    }
    return balance;
  }
}
