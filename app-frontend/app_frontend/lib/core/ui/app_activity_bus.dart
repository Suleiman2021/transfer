import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class AppActivityBus {
  AppActivityBus._();

  static final ValueNotifier<int> pending = ValueNotifier<int>(0);
  static int _rawPending = 0;
  static bool _publishScheduled = false;

  static void begin() {
    _rawPending = _rawPending + 1;
    _publish();
  }

  static void end() {
    if (_rawPending <= 0) return;
    _rawPending = _rawPending - 1;
    _publish();
  }

  static void _publish() {
    final binding = SchedulerBinding.instance;
    final inBuildPhase =
        binding.schedulerPhase == SchedulerPhase.transientCallbacks ||
        binding.schedulerPhase == SchedulerPhase.midFrameMicrotasks ||
        binding.schedulerPhase == SchedulerPhase.persistentCallbacks;

    if (!inBuildPhase) {
      if (pending.value != _rawPending) {
        pending.value = _rawPending;
      }
      return;
    }

    if (_publishScheduled) return;
    _publishScheduled = true;
    binding.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (pending.value != _rawPending) {
        pending.value = _rawPending;
      }
    });
  }
}
