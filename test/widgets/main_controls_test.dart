import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/models/show_timer_status.dart';
import 'package:show_time/widgets/main_controls.dart';

Widget _wrap(Widget child, {double width = 320}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('MainControls break button', () {
    testWidgets(
      'shows Pause and Break buttons side by side when break feature is enabled',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            MainControls(
              status: ShowTimerStatus.running,
              controlsVisible: true,
              width: 260,
              height: 60,
              fontSize: 20,
              onStart: () {},
              onPause: () {},
              onResume: () {},
              breakFeatureEnabled: true,
              onStartBreak: () {},
              onResumeFromBreakNow: () {},
              resetButton: const SizedBox(),
              pauseLabel: '一時停止',
              breakLabel: '休憩',
            ),
          ),
        );

        expect(find.text('一時停止'), findsOneWidget);
        expect(find.text('休憩'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('hides Break button when break feature is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MainControls(
            status: ShowTimerStatus.running,
            controlsVisible: true,
            width: 260,
            height: 60,
            fontSize: 20,
            onStart: () {},
            onPause: () {},
            onResume: () {},
            breakFeatureEnabled: false,
            resetButton: const SizedBox(),
            pauseLabel: '一時停止',
            breakLabel: '休憩',
          ),
        ),
      );

      expect(find.text('一時停止'), findsOneWidget);
      expect(find.text('休憩'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a single Resume Now button while on break', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MainControls(
            status: ShowTimerStatus.onBreak,
            controlsVisible: true,
            width: 260,
            height: 60,
            fontSize: 20,
            onStart: () {},
            onPause: () {},
            onResume: () {},
            onResumeFromBreakNow: () {},
            resetButton: const SizedBox(),
            resumeFromBreakLabel: '今すぐ再開',
          ),
        ),
      );

      expect(find.text('今すぐ再開'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Resume Now invokes the callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          MainControls(
            status: ShowTimerStatus.onBreak,
            controlsVisible: true,
            width: 260,
            height: 60,
            fontSize: 20,
            onStart: () {},
            onPause: () {},
            onResume: () {},
            onResumeFromBreakNow: () => tapped = true,
            resetButton: const SizedBox(),
            resumeFromBreakLabel: '今すぐ再開',
          ),
        ),
      );

      await tester.tap(find.text('今すぐ再開'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      'does not overflow on a narrow iPhone width with Pause+Break row',
      (tester) async {
        // iPhone SE-class width.
        const narrowWidth = 320.0;
        final buttonWidth = narrowWidth - 24;

        await tester.pumpWidget(
          _wrap(
            MainControls(
              status: ShowTimerStatus.running,
              controlsVisible: true,
              width: buttonWidth,
              height: 58,
              fontSize: 20,
              onStart: () {},
              onPause: () {},
              onResume: () {},
              breakFeatureEnabled: true,
              onStartBreak: () {},
              onResumeFromBreakNow: () {},
              resetButton: const SizedBox(),
              pauseLabel: '一時停止',
              breakLabel: '休憩',
            ),
            width: narrowWidth,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
