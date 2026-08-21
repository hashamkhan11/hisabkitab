import 'dart:async';

import '../services/api_client.dart';

/// Home screen's total Send/Receive balance across every transaction the
/// user owns, via `/api/summary/balance` (replaces the old
/// `collectionGroup('transactions')` listener).
class SummaryRepository {
  static const _pollInterval = Duration(seconds: 15);

  static Stream<Map<String, dynamic>> balanceStream() {
    late final StreamController<Map<String, dynamic>> controller;
    Timer? timer;

    Future<void> tick() async {
      try {
        final data = await ApiClient.instance.get('/summary/balance') as Map<String, dynamic>;
        controller.add(data);
      } catch (_) {}
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        tick();
        timer = Timer.periodic(_pollInterval, (_) => tick());
      },
      onCancel: () => timer?.cancel(),
    );

    return controller.stream;
  }
}
