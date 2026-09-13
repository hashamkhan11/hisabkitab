import 'dart:async';

import 'package:flutter/widgets.dart';

/// Shared polling helper for the app's `*Stream()` repositories/services.
///
/// Refetches every [interval] while there's an active listener. Guards
/// against two problems the original hand-rolled `Timer.periodic` loops all
/// had: a slow/laggy connection stacking up multiple concurrent in-flight
/// requests (skips a tick if the previous fetch hasn't finished), and
/// continuing to poll - burning battery and mobile data - while the app is
/// backgrounded and nobody can see the result.
Stream<T> pollingStream<T>({
  required Duration interval,
  required Future<T> Function() fetch,
  Future<T?> Function()? initialValue,
}) {
  late final StreamController<T> controller;
  Timer? timer;
  AppLifecycleListener? lifecycleListener;
  var inFlight = false;
  var appVisible = true;

  Future<void> tick() async {
    if (inFlight || !appVisible) return;
    inFlight = true;
    try {
      controller.add(await fetch());
    } catch (_) {
      // Swallow and let the next tick retry - matches this app's existing
      // polling resilience style.
    } finally {
      inFlight = false;
    }
  }

  // Broadcast: some screens (e.g. contact_detail.dart) attach two separate
  // StreamBuilders to the same *Stream() call - a single-subscription
  // controller would throw "Stream has already been listened to" on the
  // second one. onCancel still fires once the last listener detaches, so the
  // shared poll loop stops exactly when nobody's watching.
  controller = StreamController<T>.broadcast(
    onListen: () async {
      // Emit the last cached value first, if there is one, so the UI has
      // something to show immediately instead of a blank/loading state
      // while the first live fetch is still in flight (or fails outright
      // on a bad connection).
      if (initialValue != null) {
        final cached = await initialValue();
        if (cached != null && !controller.isClosed) controller.add(cached);
      }
      tick();
      timer = Timer.periodic(interval, (_) => tick());
      lifecycleListener = AppLifecycleListener(
        onShow: () {
          appVisible = true;
          tick();
        },
        onResume: () {
          appVisible = true;
          tick();
        },
        onHide: () => appVisible = false,
        onPause: () => appVisible = false,
      );
    },
    onCancel: () {
      timer?.cancel();
      lifecycleListener?.dispose();
    },
  );

  return controller.stream;
}
