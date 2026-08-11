import 'package:flutter_test/flutter_test.dart';
import 'package:hisabshare/services/transaction_service.dart';

void main() {
  group('TransactionService.calculateBalance', () {
    test('returns 0.0 for an empty transaction list', () {
      expect(TransactionService.calculateBalance([]), 0.0);
    });

    test('sums Receive transactions as positive balance', () {
      final txns = [
        {'type': 'Receive', 'credit': 100.0},
        {'type': 'Receive', 'credit': 50.0},
      ];
      expect(TransactionService.calculateBalance(txns), 150.0);
    });

    test('sums Send transactions as negative balance', () {
      final txns = [
        {'type': 'Send', 'credit': 40.0},
        {'type': 'Send', 'credit': 10.0},
      ];
      expect(TransactionService.calculateBalance(txns), -50.0);
    });

    test('nets Send and Receive transactions together', () {
      final txns = [
        {'type': 'Receive', 'credit': 200.0},
        {'type': 'Send', 'credit': 75.0},
        {'type': 'Receive', 'credit': 25.0},
      ];
      expect(TransactionService.calculateBalance(txns), 150.0);
    });

    test('ignores transactions with an unrecognized type', () {
      final txns = [
        {'type': 'Receive', 'credit': 100.0},
        {'type': 'Custom', 'credit': 999.0},
      ];
      expect(TransactionService.calculateBalance(txns), 100.0);
    });

    test('treats a missing credit as 0.0', () {
      final txns = [
        {'type': 'Receive'},
      ];
      expect(TransactionService.calculateBalance(txns), 0.0);
    });
  });
}
