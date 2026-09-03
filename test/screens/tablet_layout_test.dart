import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:show_time/controllers/show_time_menu_controller.dart';
import 'package:show_time/models/app_language.dart';
import 'package:show_time/screens/show_time_screen.dart';
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

// iPad 11-inch (Air/Pro) logical size.
const _iPadPortrait = Size(834, 1194);
const _iPadLandscape = Size(1194, 834);

// iPhone logical sizes, for the phone-layout regression check.
const _iPhonePortrait = Size(390, 844);
const _iPhoneLandscape = Size(844, 390);

// A narrow Split View-style column on an iPad (roughly 1/3 width).
const _iPadSplitViewNarrow = Size(320, 834);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
  });

  Future<ShowTimeMenuController> pumpAt(
    WidgetTester tester,
    Size logicalSize,
  ) async {
    // No debugDefaultTargetPlatformOverride needed: under `flutter test`,
    // defaultTargetPlatform already defaults to TargetPlatform.android
    // (see _platform_io.dart), which is not in isDesktopPlatform's list
    // (macOS/Windows/Linux only) — exactly the "non-desktop" behavior these
    // tablet/phone layout tests need, with nothing to reset afterwards.
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

  group('iPad landscape', () {
    testWidgets('idle: no overflow, comment/clock/button/settings visible', (
      tester,
    ) async {
      await pumpAt(tester, _iPadLandscape);
      expectNoOverflow(tester);

      expect(find.text('公演時間'), findsOneWidget);
      expect(find.text('現在時刻'), findsOneWidget);
      expect(find.byType(MainControls), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      expectWithinScreen(tester, find.byType(MainControls), _iPadLandscape);
      expectWithinScreen(tester, find.byIcon(Icons.settings), _iPadLandscape);

      // Settings icon must not overlap the current-time display.
      final settingsRect = tester.getRect(find.byIcon(Icons.settings));
      final currentTimeRect = tester.getRect(find.text('現在時刻'));
      expect(settingsRect.overlaps(currentTimeRect), isFalse);
    });

    testWidgets('running: START then the button stays fully on screen', (
      tester,
    ) async {
      await pumpAt(tester, _iPadLandscape);
      await tester.tap(find.text('スタート'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expectNoOverflow(tester);
      expect(find.text('一時停止'), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _iPadLandscape);
    });

    testWidgets('paused: no overflow and RESUME/RESET both on screen', (
      tester,
    ) async {
      await pumpAt(tester, _iPadLandscape);
      await tester.tap(find.text('スタート'));
      await tester.pump();
      await tester.tap(find.text('一時停止'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expectNoOverflow(tester);
      expect(find.text('再開'), findsOneWidget);
      expect(find.text('リセット'), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _iPadLandscape);
    });

    testWidgets(
      'on break: resume-time area shows and Resume Now button fits on screen',
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

        await pumpAt(tester, _iPadLandscape);

        expectNoOverflow(tester);
        expect(find.text('再開予定'), findsOneWidget);
        expect(find.text('今すぐ再開'), findsOneWidget);
        expectWithinScreen(tester, find.byType(MainControls), _iPadLandscape);
        expectWithinScreen(tester, find.text('再開予定'), _iPadLandscape);
      },
    );

    testWidgets('break ending within 1 minute uses no overflow either', (
      tester,
    ) async {
      final breakEndsAt = DateTime.now().add(const Duration(seconds: 30));
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

      await pumpAt(tester, _iPadLandscape);

      expectNoOverflow(tester);
      expect(find.text('再開予定'), findsOneWidget);
    });

    testWidgets('English labels render without overflow', (tester) async {
      final menuController = await pumpAt(tester, _iPadLandscape);
      menuController.setLanguage!(AppLanguage.english);
      await tester.pump();

      expectNoOverflow(tester);
      expect(find.text('SHOW TIME'), findsOneWidget);
      expect(find.text('CURRENT TIME'), findsOneWidget);
    });

    testWidgets('a long, 8+ line comment does not overflow', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'show_title': List.generate(12, (i) => 'コメント行 $i').join('\n'),
          });

      await pumpAt(tester, _iPadLandscape);

      expectNoOverflow(tester);
    });

    testWidgets('an empty comment sits below the vertical midpoint of the left '
        'column, not stuck to the top', (tester) async {
      await pumpAt(tester, _iPadLandscape);
      expectNoOverflow(tester);

      final commentRect = tester.getRect(
        find.byKey(const ValueKey('tablet-landscape-comment')),
      );

      expect(
        commentRect.top,
        greaterThan(_iPadLandscape.height / 2),
        reason:
            'The comment area should be pushed toward the bottom half '
            'of the left column by the new top spacer, instead of '
            'starting right under the settings icon.',
      );
    });

    testWidgets(
      'the button sits directly under the comment without a large gap',
      (tester) async {
        await pumpAt(tester, _iPadLandscape);
        expectNoOverflow(tester);

        final commentRect = tester.getRect(
          find.byKey(const ValueKey('tablet-landscape-comment')),
        );
        final buttonRect = tester.getRect(find.byType(MainControls));

        expect(
          buttonRect.top - commentRect.bottom,
          lessThan(60),
          reason:
              'Comment and button form one bottom group; the gap between '
              'them should stay small regardless of window height.',
        );
      },
    );

    testWidgets(
      'a long comment does not shift the button position (bounded height)',
      (tester) async {
        await pumpAt(tester, _iPadLandscape);
        final shortButtonTop = tester.getRect(find.byType(MainControls)).top;

        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'show_title': List.generate(12, (i) => 'コメント行 $i').join('\n'),
            });
        await pumpAt(tester, _iPadLandscape);
        final longButtonTop = tester.getRect(find.byType(MainControls)).top;

        expect(
          (longButtonTop - shortButtonTop).abs(),
          lessThan(_iPadLandscape.height * 0.05),
          reason:
              'The comment area is height-bounded, so a much longer '
              'comment must not push the button down.',
        );
      },
    );
  });

  group('iPad portrait', () {
    testWidgets('idle: no overflow, key elements visible on screen', (
      tester,
    ) async {
      await pumpAt(tester, _iPadPortrait);
      expectNoOverflow(tester);

      expect(find.text('公演時間'), findsOneWidget);
      expect(find.byType(MainControls), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _iPadPortrait);
    });

    testWidgets('on break: resume area and button fit without scrolling', (
      tester,
    ) async {
      final breakEndsAt = DateTime.now().add(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'session.timer.elapsedMilliseconds': 120000,
        'session.timer.isOnBreak': true,
        'session.timer.breakEndsAtMilliseconds':
            breakEndsAt.millisecondsSinceEpoch,
      });
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'break_feature_enabled': true,
            'break_duration_minutes': 15,
          });

      await pumpAt(tester, _iPadPortrait);

      expectNoOverflow(tester);
      expect(find.text('再開予定'), findsOneWidget);
      expect(find.text('今すぐ再開'), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _iPadPortrait);
    });

    testWidgets('after the break ends, the resume area disappears cleanly', (
      tester,
    ) async {
      final breakEndsAt = DateTime.now().add(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'session.timer.elapsedMilliseconds': 120000,
        'session.timer.isOnBreak': true,
        'session.timer.breakEndsAtMilliseconds':
            breakEndsAt.millisecondsSinceEpoch,
      });
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'break_feature_enabled': true,
            'break_duration_minutes': 15,
          });

      await pumpAt(tester, _iPadPortrait);
      expect(find.text('今すぐ再開'), findsOneWidget);

      await tester.tap(find.text('今すぐ再開'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expectNoOverflow(tester);
      expect(find.text('再開予定'), findsNothing);
      expect(find.text('一時停止'), findsOneWidget);
    });

    testWidgets('the clock group (current time, show time) renders above the '
        'comment, which sits just above the button', (tester) async {
      await pumpAt(tester, _iPadPortrait);
      expectNoOverflow(tester);

      final currentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final showTimeTop = tester.getRect(find.text('公演時間')).top;
      final commentTop = tester
          .getRect(find.byKey(const ValueKey('tablet-portrait-comment')))
          .top;
      final buttonTop = tester.getRect(find.byType(MainControls)).top;

      expect(currentTimeTop, lessThan(showTimeTop));
      expect(showTimeTop, lessThan(commentTop));
      expect(commentTop, lessThan(buttonTop));
    });

    testWidgets(
      'an empty comment does not create a large gap before the button '
      '(bounded comment height)',
      (tester) async {
        await pumpAt(tester, _iPadPortrait);
        expectNoOverflow(tester);

        final commentRect = tester.getRect(
          find.byKey(const ValueKey('tablet-portrait-comment')),
        );

        expect(
          commentRect.height,
          lessThan(_iPadPortrait.height * 0.20),
          reason:
              'The comment area is capped so an empty/short comment does '
              'not reserve a large blank block above the button.',
        );
      },
    );

    testWidgets(
      'a long comment does not shift the button position (bounded height)',
      (tester) async {
        await pumpAt(tester, _iPadPortrait);
        final shortButtonTop = tester.getRect(find.byType(MainControls)).top;

        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'show_title': List.generate(12, (i) => 'コメント行 $i').join('\n'),
            });
        await pumpAt(tester, _iPadPortrait);
        expectNoOverflow(tester);
        final longButtonTop = tester.getRect(find.byType(MainControls)).top;

        expect(
          (longButtonTop - shortButtonTop).abs(),
          lessThan(_iPadPortrait.height * 0.05),
          reason:
              'The comment area is height-bounded, so a much longer '
              'comment must not push the button down.',
        );
      },
    );

    testWidgets(
      'the button is capped to an iPad-appropriate max width, not the '
      'full screen width',
      (tester) async {
        await pumpAt(tester, _iPadPortrait);
        expectNoOverflow(tester);

        final buttonRect = tester.getRect(find.byType(MainControls));

        expect(buttonRect.width, lessThanOrEqualTo(680));
        expect(
          buttonRect.width,
          lessThan(_iPadPortrait.width * 0.8),
          reason:
              'The button should not stretch across nearly the full '
              'width of a large iPad screen.',
        );

        // Still comfortably tappable and roughly centered.
        expect(buttonRect.width, greaterThan(280));
        final screenCenter = _iPadPortrait.width / 2;
        expect((buttonRect.center.dx - screenCenter).abs(), lessThan(2));
      },
    );
  });

  group('iPhone landscape is unaffected', () {
    // iPhone portrait was intentionally changed (comment moved below the
    // clock group) — see phone_layout_test.dart for its dedicated coverage.
    // This smoke test is kept here as a baseline no-overflow check.
    testWidgets('iPhone portrait still renders without overflow', (
      tester,
    ) async {
      await pumpAt(tester, _iPhonePortrait);
      expectNoOverflow(tester);
      expect(find.byType(MainControls), findsOneWidget);
    });

    testWidgets('iPhone landscape (2-column layout) still renders without '
        'overflow', (tester) async {
      await pumpAt(tester, _iPhoneLandscape);
      expectNoOverflow(tester);
      expect(find.byType(MainControls), findsOneWidget);
    });
  });

  group('iPad Split View (narrow column)', () {
    testWidgets('a narrow iPad column falls back to a compact layout '
        'without overflow', (tester) async {
      await pumpAt(tester, _iPadSplitViewNarrow);
      expectNoOverflow(tester);
      expect(find.byType(MainControls), findsOneWidget);
      expectWithinScreen(
        tester,
        find.byType(MainControls),
        _iPadSplitViewNarrow,
      );
    });
  });

  group('iPad portrait: current time / show time position is fixed across '
      'break state', () {
    testWidgets('current time and show time do not move when entering break', (
      tester,
    ) async {
      await pumpAt(tester, _iPadPortrait);
      final normalCurrentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final normalShowTimeTop = tester.getRect(find.text('公演時間')).top;

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
      await pumpAt(tester, _iPadPortrait);
      expectNoOverflow(tester);
      expect(find.text('今すぐ再開'), findsOneWidget);

      final breakCurrentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final breakShowTimeTop = tester.getRect(find.text('公演時間')).top;

      expect(breakCurrentTimeTop, closeTo(normalCurrentTimeTop, 0.5));
      expect(breakShowTimeTop, closeTo(normalShowTimeTop, 0.5));
    });
  });

  group('iPad portrait: comment shows a pencil icon only when empty', () {
    Finder editIconFinder() => find.descendant(
      of: find.byKey(const ValueKey('tablet-portrait-comment')),
      matching: find.byIcon(Icons.edit),
    );

    testWidgets('an empty comment shows the pencil icon placeholder', (
      tester,
    ) async {
      await pumpAt(tester, _iPadPortrait);
      expectNoOverflow(tester);

      expect(editIconFinder(), findsOneWidget);
      expect(find.text('コメントを入力'), findsNothing);
    });

    testWidgets('a filled comment does not show the pencil icon '
        'placeholder', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': 'テストコメント'});
      await pumpAt(tester, _iPadPortrait);
      expectNoOverflow(tester);

      expect(editIconFinder(), findsNothing);
      expect(find.text('テストコメント'), findsOneWidget);
    });
  });
}
