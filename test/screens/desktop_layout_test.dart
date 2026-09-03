import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:show_time/controllers/show_time_menu_controller.dart';
import 'package:show_time/models/app_language.dart';
import 'package:show_time/screens/show_time_screen.dart';
import 'package:show_time/widgets/current_time_display.dart';
import 'package:show_time/widgets/main_controls.dart';
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

// A wide desktop window, well above the 640-logical-pixel row/column
// breakpoint used by _buildDesktopLayout.
const _macWide = Size(1280, 800);

// A "typical" resizable macOS window.
const _macNormal = Size(1000, 700);

// Below the 640 row breakpoint: current time and resume time must fall
// back to a vertical stack instead of squeezing into a Row.
const _macNarrow = Size(520, 700);

// A heavily shrunk window: fonts/paddings must clamp down but the
// Resume Now / Pause+Break controls must still be fully on screen.
const _macTiny = Size(480, 420);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();

    // On desktop, ShowTimeScreen awaits window_manager calls (e.g.
    // setAlwaysOnTop) as part of loading saved settings. window_manager
    // talks to the platform over a plain MethodChannel (no platform-
    // interface seam like wakelock_plus), so without a mock handler that
    // await never resolves under test and the settings load silently never
    // reaches its setState — leaving fields like breakFeatureEnabled stuck
    // at their defaults.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (
          call,
        ) async {
          switch (call.method) {
            case 'getBounds':
              return <String, double>{
                'x': 0,
                'y': 0,
                'width': 1000,
                'height': 700,
              };
            default:
              return null;
          }
        });
  });

  // debugDefaultTargetPlatformOverride must be set AND reset from within the
  // same synchronous/async test closure (not via setUp/tearDown or
  // addTearDown): flutter_test's invariant check
  // (debugAssertAllFoundationVarsUnset) runs immediately after the test
  // body's Future completes, but strictly before setUp/tearDown-style
  // callbacks fire. A try/finally around the callback guarantees the
  // override is cleared before that check runs, even if an expectation
  // throws partway through.
  void testWidgetsMac(
    String description,
    Future<void> Function(WidgetTester tester) callback,
  ) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<ShowTimeMenuController> pumpAt(
    WidgetTester tester,
    Size logicalSize,
  ) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Force any previously-mounted ShowTimeScreen to fully unmount first.
    // Flutter reconciles a same-type widget at the same tree position by
    // updating the existing State (skipping initState) rather than
    // recreating it, so calling pumpAt a second time in one test would
    // otherwise silently reuse the old State and never re-run the
    // SharedPreferences-driven settings/session load.
    await tester.pumpWidget(const SizedBox.shrink());

    final menuController = ShowTimeMenuController();
    addTearDown(menuController.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ShowTimeScreen(menuController: menuController)),
    );
    // Flush the async settings/session load futures.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    return menuController;
  }

  void expectNoOverflow(WidgetTester tester) {
    expect(tester.takeException(), isNull);
  }

  void expectWithinScreen(WidgetTester tester, Finder finder, Size screen) {
    final rect = tester.getRect(finder);
    expect(rect.left, greaterThanOrEqualTo(-0.5));
    expect(rect.top, greaterThanOrEqualTo(-0.5));
    expect(rect.right, lessThanOrEqualTo(screen.width + 0.5));
    expect(rect.bottom, lessThanOrEqualTo(screen.height + 0.5));
  }

  Finder currentTimeValueFinder() => find.descendant(
    of: find.byType(CurrentTimeDisplay),
    matching: find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(':'),
    ),
  );

  void setOnBreak({Duration remaining = const Duration(minutes: 10)}) {
    final breakEndsAt = DateTime.now().add(remaining);
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
  }

  group('macOS idle / running', () {
    testWidgetsMac('wide window: idle shows comment/clock/button/settings '
        'without overflow', (tester) async {
      await pumpAt(tester, _macWide);
      expectNoOverflow(tester);

      expect(find.text('公演時間'), findsOneWidget);
      expect(find.text('現在時刻'), findsOneWidget);
      expect(find.byType(MainControls), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      expectWithinScreen(tester, find.byType(MainControls), _macWide);
      expectWithinScreen(tester, find.byIcon(Icons.settings), _macWide);
    });

    testWidgetsMac('wide window: running START then PAUSE/BREAK stay fully '
        'on screen', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'break_feature_enabled': true,
            'break_duration_minutes': 15,
          });

      await pumpAt(tester, _macWide);
      await tester.tap(find.text('スタート'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expectNoOverflow(tester);
      expect(find.text('一時停止'), findsOneWidget);
      expect(find.text('休憩'), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _macWide);
    });
  });

  group('macOS on break: current time and resume time do not push the '
      'button off screen', () {
    testWidgetsMac(
      'wide window with a comment: Resume Now stays fully on screen '
      '(regression for the reported bug)',
      (tester) async {
        final breakEndsAt = DateTime.now().add(const Duration(minutes: 15));
        SharedPreferences.setMockInitialValues({
          'session.timer.elapsedMilliseconds': 60000,
          'session.timer.isOnBreak': true,
          'session.timer.breakEndsAtMilliseconds':
              breakEndsAt.millisecondsSinceEpoch,
        });
        SharedPreferencesAsyncPlatform
            .instance = InMemorySharedPreferencesAsync.withData({
          'break_feature_enabled': true,
          'break_duration_minutes': 15,
          'show_title': '□○△Hall ☆☆☆Concert 2026 Tour\n18:00 Open/ 19:00 Start',
        });

        await pumpAt(tester, _macWide);

        expectNoOverflow(tester);
        expect(find.text('再開予定'), findsOneWidget);
        expect(find.text('今すぐ再開'), findsOneWidget);
        // Wide enough that current time and resume time sit in a Row.
        expect(find.byKey(const ValueKey('desktop-clock-row')), findsOneWidget);

        expectWithinScreen(tester, find.byType(MainControls), _macWide);
        expectWithinScreen(tester, find.text('今すぐ再開'), _macWide);
        expectWithinScreen(tester, find.text('再開予定'), _macWide);

        // Resume Now must not overlap the show-time counter.
        final buttonRect = tester.getRect(find.byType(MainControls));
        final showTimeLabelRect = tester.getRect(find.text('公演時間'));
        expect(buttonRect.overlaps(showTimeLabelRect), isFalse);

        // Current time and resume time must not overlap each other.
        final currentTimeRect = tester.getRect(find.text('現在時刻'));
        final resumeLabelRect = tester.getRect(find.text('再開予定'));
        expect(currentTimeRect.overlaps(resumeLabelRect), isFalse);
      },
    );

    testWidgetsMac(
      'wide window with a long, multi-line comment: button still fully '
      'on screen',
      (tester) async {
        setOnBreak();
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'break_feature_enabled': true,
              'break_duration_minutes': 15,
              'show_title': List.generate(6, (i) => 'コメント行 $i').join('\n'),
            });

        await pumpAt(tester, _macWide);

        expectNoOverflow(tester);
        expect(find.text('今すぐ再開'), findsOneWidget);
        expectWithinScreen(tester, find.text('今すぐ再開'), _macWide);
      },
    );

    testWidgetsMac(
      'no comment vs. a comment present: the button does not shift far '
      'vertically',
      (tester) async {
        setOnBreak();
        await pumpAt(tester, _macNormal);
        expectNoOverflow(tester);
        final noTitleButtonTop = tester.getRect(find.byType(MainControls)).top;

        setOnBreak();
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'break_feature_enabled': true,
              'break_duration_minutes': 15,
              'show_title': '□○△Hall Concert 2026',
            });
        await pumpAt(tester, _macNormal);
        expectNoOverflow(tester);
        final withTitleButtonTop = tester
            .getRect(find.byType(MainControls))
            .top;

        expect(
          (withTitleButtonTop - noTitleButtonTop).abs(),
          lessThan(_macNormal.height * 0.05),
          reason:
              'The Resume Now button position should stay stable whether '
              'or not a show title/comment is present.',
        );
      },
    );

    testWidgetsMac('break ending within 1 minute uses no overflow either', (
      tester,
    ) async {
      setOnBreak(remaining: const Duration(seconds: 30));
      await pumpAt(tester, _macWide);

      expectNoOverflow(tester);
      expect(find.text('再開予定'), findsOneWidget);
    });

    testWidgetsMac('English labels render without overflow', (tester) async {
      setOnBreak();
      final menuController = await pumpAt(tester, _macWide);
      menuController.setLanguage!(AppLanguage.english);
      await tester.pump();

      expectNoOverflow(tester);
      expect(find.text('RESUMES AT'), findsOneWidget);
      expect(find.text('Resume Now'), findsOneWidget);
    });
  });

  group('macOS narrow window: falls back to a vertical clock stack', () {
    testWidgetsMac(
      'narrow window on break uses a Column, not a Row, and the button '
      'stays on screen',
      (tester) async {
        setOnBreak();
        await pumpAt(tester, _macNarrow);

        expectNoOverflow(tester);
        expect(
          find.byKey(const ValueKey('desktop-clock-column')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('desktop-clock-row')), findsNothing);
        expect(find.text('今すぐ再開'), findsOneWidget);
        expectWithinScreen(tester, find.text('今すぐ再開'), _macNarrow);
      },
    );

    testWidgetsMac(
      'a heavily shrunk window still keeps Resume Now fully on screen',
      (tester) async {
        setOnBreak();
        await pumpAt(tester, _macTiny);

        expectNoOverflow(tester);
        expect(find.text('今すぐ再開'), findsOneWidget);
        expectWithinScreen(tester, find.text('今すぐ再開'), _macTiny);
      },
    );
  });

  group('macOS resume-time visibility (size/color)', () {
    testWidgetsMac(
      'the resume time renders at 60-70% of the current time font size, '
      'the resume label at ~1.2x the current-time label, and both fit '
      'without overlapping the current time, settings icon, or show time',
      (tester) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'break_feature_enabled': true,
              'break_duration_minutes': 15,
              'show_title': '□○△Hall ☆☆☆Concert 2026 Tour',
            });
        setOnBreak();
        await pumpAt(tester, _macWide);
        expectNoOverflow(tester);

        final currentTimeValueStyle = tester
            .widget<Text>(currentTimeValueFinder())
            .style!;
        final resumeTimeStyle = tester
            .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
            .style!;
        final currentTimeLabelStyle = tester
            .widget<Text>(find.text('現在時刻'))
            .style!;
        final resumeLabelStyle = tester.widget<Text>(find.text('再開予定')).style!;

        final ratio =
            resumeTimeStyle.fontSize! / currentTimeValueStyle.fontSize!;
        expect(
          ratio,
          inInclusiveRange(0.60, 0.70),
          reason:
              'Resume time should render at 60-70% of the current time '
              'font size, per the requested visibility tuning.',
        );

        expect(
          resumeLabelStyle.fontSize! / currentTimeLabelStyle.fontSize!,
          closeTo(1.2, 0.01),
          reason:
              'The resume label should be about 1.2x the current-time '
              'label size.',
        );

        // Normally (not ending soon) the resume time is orange, not white.
        expect(resumeTimeStyle.color, const Color(0xFFFFA726));
        expect(resumeTimeStyle.color, isNot(Colors.white));

        // Nothing overlaps despite the larger resume-time text.
        final currentTimeRect = tester.getRect(currentTimeValueFinder());
        final resumeTimeRect = tester.getRect(
          find.byKey(const ValueKey('break-resume-time')),
        );
        final settingsRect = tester.getRect(find.byIcon(Icons.settings));
        final showTimeLabelRect = tester.getRect(find.text('公演時間'));

        expect(currentTimeRect.overlaps(resumeTimeRect), isFalse);
        expect(currentTimeRect.overlaps(settingsRect), isFalse);
        expect(resumeTimeRect.overlaps(settingsRect), isFalse);
        expect(resumeTimeRect.overlaps(showTimeLabelRect), isFalse);
        expect(currentTimeRect.overlaps(showTimeLabelRect), isFalse);

        // Left-right placement is preserved: resume sits to the right of
        // current time.
        expect(resumeTimeRect.left, greaterThan(currentTimeRect.left));
      },
    );

    testWidgetsMac(
      'the existing 1-minute warning color still applies and differs from '
      'the normal on-break orange',
      (tester) async {
        setOnBreak(remaining: const Duration(seconds: 30));
        await pumpAt(tester, _macWide);
        expectNoOverflow(tester);

        final resumeTimeStyle = tester
            .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
            .style!;

        expect(resumeTimeStyle.color, const Color(0xFFFFAB40));
        expect(resumeTimeStyle.color, isNot(const Color(0xFFFFA726)));
      },
    );

    testWidgetsMac(
      'a narrow window keeps the larger resume time on screen without '
      'overflow (12-hour format with AM/PM)',
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
              'use_24_hour': false,
            });

        await pumpAt(tester, _macNarrow);
        expectNoOverflow(tester);

        expect(
          find.byKey(const ValueKey('desktop-clock-column')),
          findsOneWidget,
        );
        expect(find.text('今すぐ再開'), findsOneWidget);
        expectWithinScreen(tester, find.text('今すぐ再開'), _macNarrow);
        expectWithinScreen(
          tester,
          find.byKey(const ValueKey('break-resume-time')),
          _macNarrow,
        );

        final resumeTimeText = tester
            .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
            .data!;
        expect(resumeTimeText, anyOf(contains('AM'), contains('PM')));
      },
    );

    testWidgetsMac('a tiny window with a comment stays overflow-free with '
        'the larger resume text', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'break_feature_enabled': true,
            'break_duration_minutes': 15,
            'show_title': '□○△Hall Concert 2026',
          });
      setOnBreak();
      await pumpAt(tester, _macTiny);

      expectNoOverflow(tester);
      expect(find.text('今すぐ再開'), findsOneWidget);
      expectWithinScreen(tester, find.text('今すぐ再開'), _macTiny);
      expectWithinScreen(
        tester,
        find.byKey(const ValueKey('break-resume-time')),
        _macTiny,
      );
    });
  });

  group('macOS window resize', () {
    testWidgetsMac(
      'resizing from wide to narrow mid-session recomputes the layout '
      'without overflow',
      (tester) async {
        setOnBreak();
        await pumpAt(tester, _macWide);
        expectNoOverflow(tester);
        expect(find.byKey(const ValueKey('desktop-clock-row')), findsOneWidget);

        tester.view.physicalSize = _macNarrow;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expectNoOverflow(tester);
        expect(
          find.byKey(const ValueKey('desktop-clock-column')),
          findsOneWidget,
        );
        expect(find.text('今すぐ再開'), findsOneWidget);
        expectWithinScreen(tester, find.text('今すぐ再開'), _macNarrow);
      },
    );
  });
}
