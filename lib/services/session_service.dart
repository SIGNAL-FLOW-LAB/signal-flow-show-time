import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class SavedWindowState {
  const SavedWindowState({required this.position, required this.size});

  final Offset position;
  final Size size;
}

class SavedTimerState {
  const SavedTimerState({required this.elapsed});

  final Duration elapsed;
}

class SessionService {
  static const String _windowXKey = 'session.window.x';
  static const String _windowYKey = 'session.window.y';
  static const String _windowWidthKey = 'session.window.width';
  static const String _windowHeightKey = 'session.window.height';

  static const String _timerElapsedMillisecondsKey =
      'session.timer.elapsedMilliseconds';

  Future<SavedWindowState?> loadWindowState() async {
    final preferences = await SharedPreferences.getInstance();

    final x = preferences.getDouble(_windowXKey);
    final y = preferences.getDouble(_windowYKey);
    final width = preferences.getDouble(_windowWidthKey);
    final height = preferences.getDouble(_windowHeightKey);

    if (x == null || y == null || width == null || height == null) {
      return null;
    }

    if (!x.isFinite ||
        !y.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }

    return SavedWindowState(position: Offset(x, y), size: Size(width, height));
  }

  Future<void> saveWindowState({
    required Offset position,
    required Size size,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait([
      preferences.setDouble(_windowXKey, position.dx),
      preferences.setDouble(_windowYKey, position.dy),
      preferences.setDouble(_windowWidthKey, size.width),
      preferences.setDouble(_windowHeightKey, size.height),
    ]);
  }

  Future<SavedTimerState> loadTimerState() async {
    final preferences = await SharedPreferences.getInstance();

    final elapsedMilliseconds =
        preferences.getInt(_timerElapsedMillisecondsKey) ?? 0;

    return SavedTimerState(
      elapsed: Duration(
        milliseconds: elapsedMilliseconds < 0 ? 0 : elapsedMilliseconds,
      ),
    );
  }

  Future<void> saveTimerState(Duration elapsed) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setInt(
      _timerElapsedMillisecondsKey,
      elapsed.inMilliseconds,
    );
  }
}
