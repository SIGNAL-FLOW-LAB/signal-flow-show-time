import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/show_timer_status.dart';

class ShowTimerController extends ChangeNotifier {
  ShowTimerController({this.tickInterval = const Duration(milliseconds: 100)});

  final Duration tickInterval;

  Timer? _ticker;
  ShowTimerStatus _status = ShowTimerStatus.idle;
  DateTime? _currentRunStartedAt;
  Duration _completedRunTime = Duration.zero;
  Duration _elapsed = Duration.zero;

  ShowTimerStatus get status => _status;
  Duration get elapsed => _elapsed;

  bool get isIdle => _status == ShowTimerStatus.idle;
  bool get isRunning => _status == ShowTimerStatus.running;
  bool get isPaused => _status == ShowTimerStatus.paused;

  void start() {
    _ticker?.cancel();
    _completedRunTime = Duration.zero;
    _elapsed = Duration.zero;
    _currentRunStartedAt = DateTime.now();
    _status = ShowTimerStatus.running;
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (!isRunning || _currentRunStartedAt == null) {
      return;
    }

    final now = DateTime.now();
    _completedRunTime += now.difference(_currentRunStartedAt!);
    _elapsed = _completedRunTime;
    _currentRunStartedAt = null;
    _status = ShowTimerStatus.paused;
    _ticker?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!isPaused) {
      return;
    }

    _currentRunStartedAt = DateTime.now();
    _status = ShowTimerStatus.running;
    _startTicker();
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _status = ShowTimerStatus.idle;
    _currentRunStartedAt = null;
    _completedRunTime = Duration.zero;
    _elapsed = Duration.zero;
    notifyListeners();
  }

  void refreshAfterResume() {
    if (!isRunning || _currentRunStartedAt == null) {
      return;
    }

    _updateElapsed(DateTime.now());
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) {
      if (!isRunning || _currentRunStartedAt == null) {
        return;
      }

      _updateElapsed(DateTime.now());
      notifyListeners();
    });
  }

  void _updateElapsed(DateTime now) {
    _elapsed = _completedRunTime + now.difference(_currentRunStartedAt!);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
