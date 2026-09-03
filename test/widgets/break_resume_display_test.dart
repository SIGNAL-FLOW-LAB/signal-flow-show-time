import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/widgets/break_resume_display.dart';

Widget _wrap(Widget child, {double width = 320}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: width,
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('BreakResumeDisplay', () {
    testWidgets('renders the label and the time as separate widgets', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 20, 45),
            use24Hour: true,
            isEndingSoon: false,
            label: '再開予定',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
          ),
        ),
      );

      final labelFinder = find.byKey(const ValueKey('break-resume-label'));
      final timeFinder = find.byKey(const ValueKey('break-resume-time'));

      expect(labelFinder, findsOneWidget);
      expect(timeFinder, findsOneWidget);
      expect(tester.widget<Text>(labelFinder).data, '再開予定');
      expect(tester.widget<Text>(timeFinder).data, '20:45');

      // The time text must render larger than the label text.
      final labelStyle = tester.widget<Text>(labelFinder).style!;
      final timeStyle = tester.widget<Text>(timeFinder).style!;
      expect(timeStyle.fontSize, greaterThan(labelStyle.fontSize!));

      expect(tester.takeException(), isNull);
    });

    testWidgets('formats 24-hour time without AM/PM', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 13, 5),
            use24Hour: true,
            isEndingSoon: false,
            label: 'RESUMES AT',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
          ),
        ),
      );

      expect(find.text('13:5'), findsNothing);
      expect(find.text('13:05'), findsOneWidget);
    });

    testWidgets('formats 12-hour time with AM/PM', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 13, 5),
            use24Hour: false,
            isEndingSoon: false,
            label: 'RESUMES AT',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
          ),
        ),
      );

      expect(find.text('1:05 PM'), findsOneWidget);
    });

    testWidgets('midnight in 12-hour format shows 12 AM', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 0, 0),
            use24Hour: false,
            isEndingSoon: false,
            label: 'RESUMES AT',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
          ),
        ),
      );

      expect(find.text('12:00 AM'), findsOneWidget);
    });

    testWidgets('uses white for the normal state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 20, 45),
            use24Hour: true,
            isEndingSoon: false,
            label: '再開予定',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
          ),
        ),
      );

      final timeStyle = tester
          .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
          .style!;

      expect(timeStyle.color, Colors.white);
    });

    testWidgets('switches to the warning orange when ending soon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 20, 45),
            use24Hour: true,
            isEndingSoon: true,
            label: '再開予定',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
          ),
        ),
      );

      final timeStyle = tester
          .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
          .style!;

      expect(timeStyle.color, const Color(0xFFFFAB40));
      expect(timeStyle.color, isNot(Colors.white));
    });

    testWidgets('uses a custom normalColor when provided (macOS)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BreakResumeDisplay(
            resumeAt: DateTime(2026, 9, 2, 20, 45),
            use24Hour: true,
            isEndingSoon: false,
            label: '再開予定',
            labelFontSize: 16,
            timeFontSize: 40,
            labelGap: 6,
            normalColor: const Color(0xFFFFA726),
          ),
        ),
      );

      final timeStyle = tester
          .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
          .style!;

      expect(timeStyle.color, const Color(0xFFFFA726));
    });

    testWidgets(
      'the ending-soon warning color still overrides a custom normalColor',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BreakResumeDisplay(
              resumeAt: DateTime(2026, 9, 2, 20, 45),
              use24Hour: true,
              isEndingSoon: true,
              label: '再開予定',
              labelFontSize: 16,
              timeFontSize: 40,
              labelGap: 6,
              normalColor: const Color(0xFFFFA726),
            ),
          ),
        );

        final timeStyle = tester
            .widget<Text>(find.byKey(const ValueKey('break-resume-time')))
            .style!;

        expect(timeStyle.color, const Color(0xFFFFAB40));
      },
    );

    testWidgets(
      'does not overflow on a narrow width with a long English label',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BreakResumeDisplay(
              resumeAt: DateTime(2026, 9, 2, 13, 5),
              use24Hour: false,
              isEndingSoon: false,
              label: 'RESUMES AT',
              labelFontSize: 16,
              timeFontSize: 40,
              labelGap: 6,
              maxWidth: 140,
            ),
            width: 140,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('is not shown when the containing area is toggled off', (
      tester,
    ) async {
      final isOnBreak = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isOnBreak,
              builder: (context, onBreak, _) {
                // Mirrors the AnimatedSize/SizedBox.shrink pattern used by
                // _buildBreakResumeArea in ShowTimeScreen: the resume-time
                // area is fully removed once the break ends.
                return onBreak
                    ? BreakResumeDisplay(
                        resumeAt: DateTime(2026, 9, 2, 20, 45),
                        use24Hour: true,
                        isEndingSoon: false,
                        label: '再開予定',
                        labelFontSize: 16,
                        timeFontSize: 40,
                        labelGap: 6,
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('break-resume-time')), findsOneWidget);

      isOnBreak.value = false;
      await tester.pump();

      expect(find.byKey(const ValueKey('break-resume-time')), findsNothing);
      expect(find.byKey(const ValueKey('break-resume-label')), findsNothing);
    });
  });
}
