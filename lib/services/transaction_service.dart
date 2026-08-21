import 'dart:async';

import '../services/api_client.dart';

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
    late final StreamController<List<Map<String, dynamic>>> controller;
    Timer? timer;

    Future<void> tick() async {
      try {
        controller.add(await _fetchTransactions(contactId: contactId, status: status));
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

  static Future<List<Map<String, dynamic>>> _fetchTransactions({
    required String contactId,
    String? status,
  }) async {
    final data = await ApiClient.instance.get(
      '/contacts/$contactId/transactions',
      query: {if (status != null) 'status': status, 'limit': '100'},
    ) as Map<String, dynamic>;

    final items = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(_parseTransaction).toList();
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
