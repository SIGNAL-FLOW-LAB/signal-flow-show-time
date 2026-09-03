import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:show_time/controllers/show_time_menu_controller.dart';
import 'package:show_time/screens/show_time_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  bool enabledValue = false;

  @override
  Future<void> toggle({required bool enable}) async {
    enabledValue = enable;
  }

  @override
  Future<bool> get enabled async => enabledValue;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
  });

  // Note on approach: `testWidgets` runs inside a FakeAsync zone, so
  // `WidgetTester.pump(duration)` fast-forwards Timers (including the
  // controller's periodic ticker and the control-hide Timer) without any
  // real wall-clock time passing. It does NOT fake `DateTime.now()`, which
  // ShowTimerController uses directly. So rather than racing the real clock
  // against the controller's own 100ms ticker, these tests set breakEndsAt
  // in the past *before* mounting: this reliably exercises the same
  // "resumed without an explicit button tap" code path (restoreState's
  // auto-resolve), which is exactly what the fix in _handleTimerChanged
  // needs to handle regardless of which automatic trigger caused it.
  testWidgets('Pause/Break controls auto-hide after an automatic resume '
      '(no tap on Resume Now)', (tester) async {
    final breakEndsAt = DateTime.now().subtract(const Duration(seconds: 30));
    SharedPreferences.setMockInitialValues({
      'session.timer.elapsedMilliseconds': 60000,
      'session.timer.isOnBreak': true,
      'session.timer.breakEndsAtMilliseconds':
          breakEndsAt.millisecondsSinceEpoch,
    });
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'break_feature_enabled': true,
          'break_duration_minutes': 15,
        });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final menuController = ShowTimeMenuController();
    addTearDown(menuController.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ShowTimeScreen(menuController: menuController)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // breakEndsAt had already passed when the screen loaded, so it
    // resolves straight to "running" — never showing "Resume Now" and
    // never going through the explicit _resumeFromBreakNow() button path.
    expect(find.text('今すぐ再開'), findsNothing);
    expect(find.text('一時停止'), findsOneWidget);
    expect(find.text('休憩'), findsOneWidget);

    // The Pause/Break row should be visible right after the automatic
    // resume (not hidden instantly).
    var opacityWidget = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('running-controls')),
    );
    expect(opacityWidget.opacity, 1.0);

    // Advance past the control auto-hide delay without any interaction.
    await tester.pump(const Duration(milliseconds: 2600));

    opacityWidget = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('running-controls')),
    );
    expect(
      opacityWidget.opacity,
      0.0,
      reason:
          'Pause/Break controls must auto-hide even when the show resumed '
          'automatically, not only after an explicit button tap.',
    );
  });

  testWidgets(
    'controls stay visible and do not hide while genuinely on break',
    (tester) async {
      final breakEndsAt = DateTime.now().add(const Duration(minutes: 10));
      SharedPreferences.setMockInitialValues({
        'session.timer.elapsedMilliseconds': 60000,
        'session.timer.isOnBreak': true,
        'session.timer.breakEndsAtMilliseconds':
            breakEndsAt.millisecondsSinceEpoch,
      });
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'break_feature_enabled': true,
            'break_duration_minutes': 15,
          });

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final menuController = ShowTimeMenuController();
      addTearDown(menuController.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ShowTimeScreen(menuController: menuController)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('今すぐ再開'), findsOneWidget);

      // Even after waiting well past the control auto-hide delay, the
      // "Resume Now" button must stay visible — auto-hide only applies to
      // the running-state Pause/Break row.
      await tester.pump(const Duration(milliseconds: 2600));

      expect(find.text('今すぐ再開'), findsOneWidget);
    },
  );
}
