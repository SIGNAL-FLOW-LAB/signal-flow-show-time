import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:show_time/controllers/show_time_menu_controller.dart';
import 'package:show_time/models/app_language.dart';
import 'package:show_time/models/comment_alignment.dart';
import 'package:show_time/screens/show_time_screen.dart';
import 'package:show_time/widgets/current_time_display.dart';
import 'package:show_time/widgets/main_controls.dart';
import 'package:show_time/widgets/show_elapsed_display.dart';
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

// iPhone SE (3rd gen) logical size — the shortest common iPhone height.
const _iPhoneSE = Size(375, 667);

// A standard-size iPhone.
const _iPhoneStandard = Size(390, 844);

// The same standard iPhone rotated to landscape.
const _iPhoneLandscape = Size(844, 390);

// A large iPhone (Pro Max class).
const _iPhoneLarge = Size(430, 932);

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
    // defaultTargetPlatform already defaults to TargetPlatform.android,
    // which is not a desktop platform and not a tablet form factor at
    // these shortestSide values — exactly the "phone" behavior these
    // tests need.
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

  group('iPhone portrait: new info order (current time -> resume -> show '
      'time -> comment -> button)', () {
    testWidgets('idle: current time, show time, comment, and button appear '
        'top to bottom in that order', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      final currentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final showTimeTop = tester.getRect(find.text('公演時間')).top;
      final commentTop = tester
          .getRect(find.byKey(const ValueKey('phone-portrait-comment')))
          .top;
      final buttonTop = tester.getRect(find.byType(MainControls)).top;

      expect(currentTimeTop, lessThan(showTimeTop));
      expect(showTimeTop, lessThan(commentTop));
      expect(commentTop, lessThan(buttonTop));

      expectWithinScreen(tester, find.byType(MainControls), _iPhoneStandard);
    });

    testWidgets('on break: resume time renders between current time and '
        'show time, and Resume Now stays on screen', (tester) async {
      setOnBreak();
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      final currentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final resumeTop = tester.getRect(find.text('再開予定')).top;
      final showTimeTop = tester.getRect(find.text('公演時間')).top;

      expect(currentTimeTop, lessThan(resumeTop));
      expect(resumeTop, lessThan(showTimeTop));

      expect(find.text('今すぐ再開'), findsOneWidget);
      expectWithinScreen(tester, find.text('今すぐ再開'), _iPhoneStandard);
    });

    testWidgets('on break: current time and resume time have a clear gap', (
      tester,
    ) async {
      setOnBreak();
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      final currentTimeBottom = tester
          .getRect(find.byType(CurrentTimeDisplay))
          .bottom;
      final resumeLabelTop = tester.getRect(find.text('再開予定')).top;

      expect(
        resumeLabelTop - currentTimeBottom,
        greaterThanOrEqualTo(10),
        reason: 'The two clock blocks should not appear crowded together.',
      );
    });

    testWidgets('break ending within 1 minute uses no overflow', (
      tester,
    ) async {
      setOnBreak(remaining: const Duration(seconds: 30));
      await pumpAt(tester, _iPhoneStandard);

      expectNoOverflow(tester);
      expect(find.text('再開予定'), findsOneWidget);
    });

    testWidgets('running: START, then Pause/Break stay fully on screen', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'break_feature_enabled': true,
            'break_duration_minutes': 15,
          });
      await pumpAt(tester, _iPhoneStandard);
      await tester.tap(find.text('スタート'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expectNoOverflow(tester);
      expect(find.text('一時停止'), findsOneWidget);
      expect(find.text('休憩'), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneStandard);
    });

    testWidgets('paused: RESUME and RESET stay fully on screen', (
      tester,
    ) async {
      await pumpAt(tester, _iPhoneStandard);
      await tester.tap(find.text('スタート'));
      await tester.pump();
      await tester.tap(find.text('一時停止'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expectNoOverflow(tester);
      expect(find.text('再開'), findsOneWidget);
      expect(find.text('リセット'), findsOneWidget);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneStandard);
    });

    testWidgets('English labels render without overflow', (tester) async {
      final menuController = await pumpAt(tester, _iPhoneStandard);
      menuController.setLanguage!(AppLanguage.english);
      await tester.pump();

      expectNoOverflow(tester);
      expect(find.text('SHOW TIME'), findsOneWidget);
      expect(find.text('CURRENT TIME'), findsOneWidget);
    });
  });

  group('iPhone portrait / landscape visual consistency', () {
    testWidgets('portrait comment uses the same font size as landscape', (
      tester,
    ) async {
      const comment = '横向きと同じコメントサイズ';
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': comment});
      await pumpAt(tester, _iPhoneStandard);
      final portraitFontSize = tester
          .widget<Text>(find.text(comment))
          .style!
          .fontSize;

      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': comment});
      await pumpAt(tester, _iPhoneLandscape);
      expectNoOverflow(tester);
      final landscapeFontSize = tester
          .widget<Text>(find.text(comment))
          .style!
          .fontSize;

      expect(portraitFontSize, landscapeFontSize);
    });

    testWidgets('landscape shifts only the resume block slightly upward', (
      tester,
    ) async {
      setOnBreak();
      await pumpAt(tester, _iPhoneLandscape);
      expectNoOverflow(tester);

      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('phone-landscape-resume-position')),
      );
      final verticalOffset = transform.transform.entry(1, 3);

      expect(verticalOffset, inInclusiveRange(-12, -8));
      expectWithinScreen(tester, find.text('再開予定'), _iPhoneLandscape);
      expectWithinScreen(tester, find.text('今すぐ再開'), _iPhoneLandscape);
    });
  });

  group('iPhone landscape: pencil icon position near the settings gear', () {
    testWidgets('idle: no overflow, MainControls fully on screen', (
      tester,
    ) async {
      await pumpAt(tester, _iPhoneLandscape);
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneLandscape);
    });

    testWidgets(
      'the empty-state pencil icon sits well above the button, closer to '
      'the settings gear height than to the button',
      (tester) async {
        await pumpAt(tester, _iPhoneLandscape);
        expectNoOverflow(tester);

        final iconRect = tester.getRect(find.byIcon(Icons.edit));
        final gearRect = tester.getRect(find.byIcon(Icons.settings));
        final buttonRect = tester.getRect(find.byType(MainControls));

        expect(iconRect.bottom, lessThan(buttonRect.top));

        final iconToGear = (iconRect.top - gearRect.top).abs();
        final iconToButton = (buttonRect.top - iconRect.top).abs();
        expect(iconToGear, lessThan(iconToButton));
      },
    );

    testWidgets(
      'the button stays at the same position regardless of how tall the '
      'reserved comment area is (moving the icon does not move the button)',
      (tester) async {
        await pumpAt(tester, _iPhoneLandscape);
        final emptyButtonTop = tester.getRect(find.byType(MainControls)).top;

        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'show_title': List.generate(8, (i) => 'コメント行 $i').join('\n'),
            });
        await pumpAt(tester, _iPhoneLandscape);
        expectNoOverflow(tester);
        final filledButtonTop = tester.getRect(find.byType(MainControls)).top;

        expect(filledButtonTop, closeTo(emptyButtonTop, 0.5));
      },
    );

    testWidgets('tapping the pencil icon still opens the edit dialog', (
      tester,
    ) async {
      await pumpAt(tester, _iPhoneLandscape);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expectNoOverflow(tester);
    });
  });

  group('iPhone portrait: comment does not push the clock or the button', () {
    testWidgets('an empty comment shows a compact pencil icon, not stretched '
        'to the full 8-line comment region', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      final editIcon = find.descendant(
        of: find.byKey(const ValueKey('phone-portrait-comment')),
        matching: find.byIcon(Icons.edit),
      );
      expect(editIcon, findsOneWidget);

      // The pencil glyph itself must stay compact (well under the 8-line
      // reserved region), matching the "don't grow the placeholder itself"
      // requirement. Its 44x44 tap target is intentionally larger than the
      // glyph (for a comfortable tap area), so the glyph's own `size` is
      // checked here rather than the tap target's rendered rect.
      final icon = tester.widget<Icon>(editIcon);
      expect(icon.size, lessThan(40));
    });

    testWidgets('a long comment does not shift the button position', (
      tester,
    ) async {
      await pumpAt(tester, _iPhoneStandard);
      final shortButtonTop = tester.getRect(find.byType(MainControls)).top;

      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'show_title': List.generate(12, (i) => 'コメント行 $i').join('\n'),
          });
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);
      final longButtonTop = tester.getRect(find.byType(MainControls)).top;

      expect(
        (longButtonTop - shortButtonTop).abs(),
        lessThan(_iPhoneStandard.height * 0.05),
        reason:
            'The comment area is height-bounded, so a much longer '
            'comment must not push the button down.',
      );
    });

    testWidgets('switching between not-on-break and on-break does not move the '
        'button far', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      final normalButtonTop = tester.getRect(find.byType(MainControls)).top;

      setOnBreak();
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);
      final breakButtonTop = tester.getRect(find.byType(MainControls)).top;

      expect(
        (breakButtonTop - normalButtonTop).abs(),
        lessThan(_iPhoneStandard.height * 0.08),
        reason:
            'Toggling the resume-time display on/off should not make '
            'the whole layout jump.',
      );
    });
  });

  group('short iPhone (SE-class height)', () {
    testWidgets('idle: no overflow, button fully on screen', (tester) async {
      await pumpAt(tester, _iPhoneSE);
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneSE);
    });

    testWidgets('on break: Resume Now stays fully on screen', (tester) async {
      setOnBreak();
      await pumpAt(tester, _iPhoneSE);
      expectNoOverflow(tester);
      expect(find.text('今すぐ再開'), findsOneWidget);
      expectWithinScreen(tester, find.text('今すぐ再開'), _iPhoneSE);
    });

    testWidgets('a long comment still does not overflow or push the '
        'button off screen', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'show_title': List.generate(12, (i) => 'コメント行 $i').join('\n'),
          });
      await pumpAt(tester, _iPhoneSE);

      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneSE);
    });

    testWidgets('settings icon does not overlap the current time display', (
      tester,
    ) async {
      await pumpAt(tester, _iPhoneSE);
      expectNoOverflow(tester);

      final settingsRect = tester.getRect(find.byIcon(Icons.settings));
      final currentTimeRect = tester.getRect(find.text('現在時刻'));
      expect(settingsRect.overlaps(currentTimeRect), isFalse);
    });
  });

  group('large iPhone (Pro Max-class height)', () {
    testWidgets('idle: no overflow, button fully on screen', (tester) async {
      await pumpAt(tester, _iPhoneLarge);
      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneLarge);
    });

    testWidgets('on break: Resume Now stays fully on screen', (tester) async {
      setOnBreak();
      await pumpAt(tester, _iPhoneLarge);
      expectNoOverflow(tester);
      expect(find.text('今すぐ再開'), findsOneWidget);
      expectWithinScreen(tester, find.text('今すぐ再開'), _iPhoneLarge);
    });
  });

  group('iPhone portrait: comment editing (modal dialog, not inline)', () {
    testWidgets(
      'tapping the comment opens the edit dialog with a keyboard-safe '
      'text field and no overflow',
      (tester) async {
        await pumpAt(tester, _iPhoneStandard);

        // The comment starts empty, so only the pencil icon (not the whole
        // reserved area) is tappable.
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('phone-portrait-comment')),
            matching: find.byIcon(Icons.edit),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expectNoOverflow(tester);

        // Simulate the on-screen keyboard appearing while the dialog is
        // open; the dialog manages its own keyboard-safe layout
        // independent of the main screen's clock/button layout.
        await tester.binding.setSurfaceSize(_iPhoneStandard);
        tester.view.viewInsets = FakeViewPadding(bottom: 300);
        addTearDown(() => tester.view.resetViewInsets());
        await tester.pump();

        expectNoOverflow(tester);
      },
    );
  });

  group('iPhone portrait: current time / show time position is fixed '
      'across break state', () {
    testWidgets('current time and show time do not move when entering break', (
      tester,
    ) async {
      await pumpAt(tester, _iPhoneStandard);
      final normalCurrentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final normalShowTimeTop = tester.getRect(find.text('公演時間')).top;

      setOnBreak();
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);
      final breakCurrentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final breakShowTimeTop = tester.getRect(find.text('公演時間')).top;

      expect(breakCurrentTimeTop, closeTo(normalCurrentTimeTop, 0.5));
      expect(breakShowTimeTop, closeTo(normalShowTimeTop, 0.5));
    });

    testWidgets('current time and show time do not move once the break has '
        'automatically ended', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      final normalCurrentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final normalShowTimeTop = tester.getRect(find.text('公演時間')).top;

      final breakEndsAt = DateTime.now().subtract(const Duration(seconds: 5));
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
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      // breakEndsAt already passed, so this resolves straight to running.
      expect(find.text('再開予定'), findsNothing);
      final afterBreakCurrentTimeTop = tester.getRect(find.text('現在時刻')).top;
      final afterBreakShowTimeTop = tester.getRect(find.text('公演時間')).top;

      expect(afterBreakCurrentTimeTop, closeTo(normalCurrentTimeTop, 0.5));
      expect(afterBreakShowTimeTop, closeTo(normalShowTimeTop, 0.5));
    });

    testWidgets(
      'tapping Resume Now returns current time and show time to their '
      'normal position',
      (tester) async {
        await pumpAt(tester, _iPhoneStandard);
        final normalShowTimeTop = tester.getRect(find.text('公演時間')).top;

        setOnBreak();
        await pumpAt(tester, _iPhoneStandard);
        await tester.tap(find.text('今すぐ再開'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expectNoOverflow(tester);
        expect(find.text('再開予定'), findsNothing);
        final afterResumeShowTimeTop = tester.getRect(find.text('公演時間')).top;

        expect(afterResumeShowTimeTop, closeTo(normalShowTimeTop, 0.5));
      },
    );
  });

  group('iPhone portrait: comment shows a pencil icon only when empty', () {
    Finder editIconFinder() => find.descendant(
      of: find.byKey(const ValueKey('phone-portrait-comment')),
      matching: find.byIcon(Icons.edit),
    );

    testWidgets('an empty (never-set) comment shows the pencil icon '
        'placeholder', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      expect(editIconFinder(), findsOneWidget);
      expect(find.text('コメントを入力'), findsNothing);
    });

    testWidgets('a whitespace-only comment is also treated as empty', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': '   \n\t  '});
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      expect(editIconFinder(), findsOneWidget);
    });

    testWidgets('a filled comment does not show the pencil icon '
        'placeholder', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': 'テストコメント'});
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      expect(editIconFinder(), findsNothing);
      expect(find.text('テストコメント'), findsOneWidget);
    });

    testWidgets('clearing a filled comment returns to the pencil icon '
        'immediately, without a restart', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': 'テストコメント'});
      await pumpAt(tester, _iPhoneStandard);
      expect(find.text('テストコメント'), findsOneWidget);
      expect(editIconFinder(), findsNothing);

      await tester.tap(find.text('テストコメント'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expectNoOverflow(tester);
      expect(editIconFinder(), findsOneWidget);
    });
  });

  group('iPhone portrait: show time is centered and the comment region '
      'supports up to 8 lines', () {
    testWidgets(
      'the show-time counter is vertically centered near the middle of '
      'the available screen height',
      (tester) async {
        await pumpAt(tester, _iPhoneStandard);
        expectNoOverflow(tester);

        final showTimeCenterDy = tester
            .getRect(find.byType(ShowElapsedDisplay))
            .center
            .dy;

        expect(
          showTimeCenterDy,
          closeTo(_iPhoneStandard.height / 2, _iPhoneStandard.height * 0.05),
          reason:
              'The show-time digits should sit near the vertical center '
              'of the available (SafeArea-adjusted) screen height.',
        );
      },
    );

    testWidgets('the show-time counter position (dy) does not change between '
        'normal and on-break states', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      final normalTop = tester
          .getRect(find.byKey(const ValueKey('phone-portrait-show-time')))
          .top;

      setOnBreak();
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);
      expect(find.text('今すぐ再開'), findsOneWidget);
      final breakTop = tester
          .getRect(find.byKey(const ValueKey('phone-portrait-show-time')))
          .top;

      expect(breakTop, closeTo(normalTop, 0.5));
    });

    testWidgets(
      'the button position (dy) does not change with 0, 2, or 8 comment '
      'lines',
      (tester) async {
        await pumpAt(tester, _iPhoneStandard);
        final emptyButtonTop = tester.getRect(find.byType(MainControls)).top;

        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({'show_title': '1行目\n2行目'});
        await pumpAt(tester, _iPhoneStandard);
        expectNoOverflow(tester);
        final twoLineButtonTop = tester.getRect(find.byType(MainControls)).top;

        SharedPreferencesAsyncPlatform
            .instance = InMemorySharedPreferencesAsync.withData({
          'show_title': List.generate(8, (i) => 'コメント${i + 1}行目').join('\n'),
        });
        await pumpAt(tester, _iPhoneStandard);
        expectNoOverflow(tester);
        final eightLineButtonTop = tester
            .getRect(find.byType(MainControls))
            .top;

        expect(twoLineButtonTop, closeTo(emptyButtonTop, 0.5));
        expect(eightLineButtonTop, closeTo(emptyButtonTop, 0.5));
      },
    );

    testWidgets('an 8-line comment displays all 8 lines without being '
        'truncated', (tester) async {
      final comment = List.generate(
        8,
        (i) => 'コメント${i + 1}行目のテキストです',
      ).join('\n');
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': comment});
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      final richText = find.descendant(
        of: find.byKey(const ValueKey('phone-portrait-comment')),
        matching: find.byType(RichText),
      );
      expect(richText, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(richText);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'All 8 lines should fit without ellipsis truncation.',
      );
    });

    testWidgets('a 9+ line comment is clipped to 8 lines and does not push the '
        'button', (tester) async {
      await pumpAt(tester, _iPhoneStandard);
      final baselineButtonTop = tester.getRect(find.byType(MainControls)).top;

      final comment = List.generate(
        12,
        (i) => 'コメント${i + 1}行目のテキストです',
      ).join('\n');
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': comment});
      await pumpAt(tester, _iPhoneStandard);
      expectNoOverflow(tester);

      final richText = find.descendant(
        of: find.byKey(const ValueKey('phone-portrait-comment')),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(richText);
      expect(
        paragraph.didExceedMaxLines,
        isTrue,
        reason:
            '12 lines of content should be clipped at the max line '
            'count, not overflow into the controls area.',
      );

      final clippedButtonTop = tester.getRect(find.byType(MainControls)).top;
      expect(clippedButtonTop, closeTo(baselineButtonTop, 0.5));
    });

    testWidgets('8 lines of long text each still do not overflow', (
      tester,
    ) async {
      final comment = List.generate(
        8,
        (i) => '長いコメント行のテキストがここに入ります番号$i文字数を稼ぐためのダミーテキストです',
      ).join('\n');
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'show_title': comment});
      await pumpAt(tester, _iPhoneStandard);

      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneStandard);
    });

    testWidgets('a comment with many blank lines does not overflow', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'show_title': '\n\n\n\n\n\n\n\n\n\n',
          });
      await pumpAt(tester, _iPhoneStandard);

      expectNoOverflow(tester);
      expectWithinScreen(tester, find.byType(MainControls), _iPhoneStandard);
    });
  });

  group('iPhone portrait: comment alignment settings are preserved', () {
    for (final entry in {
      CommentAlignment.left: TextAlign.left,
      CommentAlignment.center: TextAlign.center,
      CommentAlignment.right: TextAlign.right,
    }.entries) {
      testWidgets('${entry.key} alignment is applied to the comment text', (
        tester,
      ) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'show_title': 'テストコメント',
              'comment_alignment': entry.key.name,
            });
        await pumpAt(tester, _iPhoneStandard);
        expectNoOverflow(tester);

        final text = tester.widget<Text>(find.text('テストコメント'));
        expect(text.textAlign, entry.value);
      });
    }
  });
}
