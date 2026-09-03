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
  DateTime? _breakEndsAt;

  ShowTimerStatus get status => _status;
  Duration get elapsed => _elapsed;
  DateTime? get breakEndsAt => _breakEndsAt;

  bool get isIdle => _status == ShowTimerStatus.idle;
  bool get isRunning => _status == ShowTimerStatus.running;
  bool get isPaused => _status == ShowTimerStatus.paused;
  bool get isOnBreak => _status == ShowTimerStatus.onBreak;

  static Duration _clampNonNegative(Duration value) {
    return value.isNegative ? Duration.zero : value;
  }

  /// Restores state persisted by the previous session (or before the app was
  /// backgrounded). If [isOnBreak] is true and [breakEndsAt] has already
  /// passed, the show is resumed immediately, and the time elapsed since
  /// [breakEndsAt] is folded into the show time.
  void restoreState({
    required Duration elapsed,
    bool isOnBreak = false,
    DateTime? breakEndsAt,
  }) {
    _ticker?.cancel();
    _ticker = null;
    _currentRunStartedAt = null;
    _breakEndsAt = null;

    final safeElapsed = _clampNonNegative(elapsed);
    _completedRunTime = safeElapsed;
    _elapsed = safeElapsed;

    if (isOnBreak && breakEndsAt != null) {
      final now = DateTime.now();

      if (!now.isBefore(breakEndsAt)) {
        _resumeFrom(breakEndsAt);
      } else {
        _breakEndsAt = breakEndsAt;
        _status = ShowTimerStatus.onBreak;
        _startBreakTicker();
      }
    } else {
      _status = safeElapsed == Duration.zero
          ? ShowTimerStatus.idle
          : ShowTimerStatus.paused;
    }

    notifyListeners();
  }

  void start() {
    _ticker?.cancel();
    _completedRunTime = Duration.zero;
    _elapsed = Duration.zero;
    _breakEndsAt = null;
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

    _completedRunTime += _clampNonNegative(
      now.difference(_currentRunStartedAt!),
    );
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

  /// Starts a scheduled break, stopping the show time count and recording
  /// the absolute time the break is due to end.
  void startBreak(Duration breakDuration) {
    if (!isRunning || _currentRunStartedAt == null) {
      return;
    }

    final now = DateTime.now();

    _completedRunTime += _clampNonNegative(
      now.difference(_currentRunStartedAt!),
    );
    _elapsed = _completedRunTime;
    _currentRunStartedAt = null;
    _breakEndsAt = now.add(breakDuration);
    _status = ShowTimerStatus.onBreak;

    _startBreakTicker();
    notifyListeners();
  }

  /// Ends the break early and resumes the show time immediately. Only the
  /// time actually spent on break is excluded from the show time.
  void resumeFromBreakNow() {
    if (!isOnBreak) {
      return;
    }

    _resumeFrom(DateTime.now());
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _status = ShowTimerStatus.idle;
    _currentRunStartedAt = null;
    _completedRunTime = Duration.zero;
    _elapsed = Duration.zero;
    _breakEndsAt = null;

    notifyListeners();
  }

  void refreshAfterResume() {
    if (isOnBreak) {
      _resolveBreakOnForeground();
      return;
    }

    if (!isRunning || _currentRunStartedAt == null) {
      return;
    }

    _updateElapsed(DateTime.now());
    _startTicker();
    notifyListeners();
  }

  void _resolveBreakOnForeground() {
    final endsAt = _breakEndsAt;

    if (endsAt == null) {
      return;
    }

    final now = DateTime.now();

    if (!now.isBefore(endsAt)) {
      _resumeFrom(endsAt);
    } else {
      _startBreakTicker();
    }

    notifyListeners();
  }

  /// Resumes running with the show time continuing from [resumedAt], so any
  /// wall-clock time between the break start and [resumedAt] is excluded.
  void _resumeFrom(DateTime resumedAt) {
    _currentRunStartedAt = resumedAt;
    _breakEndsAt = null;
    _status = ShowTimerStatus.running;
    // Reflects any time already passed since resumedAt (e.g. time spent
    // backgrounded past breakEndsAt) immediately, rather than waiting for
    // the next tick.
    _updateElapsed(DateTime.now());
    _startTicker();
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

  void _startBreakTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(tickInterval, (_) {
      if (!isOnBreak || _breakEndsAt == null) {
        return;
      }

      final now = DateTime.now();

      if (!now.isBefore(_breakEndsAt!)) {
        _resumeFrom(_breakEndsAt!);
      }

      notifyListeners();
    });
  }

  void _updateElapsed(DateTime now) {
    _elapsed =
        _completedRunTime +
        _clampNonNegative(now.difference(_currentRunStartedAt!));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
