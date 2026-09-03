import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/models/app_language.dart';
import 'package:show_time/models/comment_alignment.dart';
import 'package:show_time/widgets/settings_sheet.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  required AppLanguage language,
  bool breakFeatureEnabled = false,
  Duration breakDuration = const Duration(minutes: 15),
  required ValueChanged<bool> onBreakFeatureEnabledChanged,
  required ValueChanged<Duration> onBreakDurationChanged,
}) async {
  // The settings sheet is taller than the default 800x600 test surface;
  // give it enough room so every row is reachable without scrolling.
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showSettingsSheet(
                context: context,
                language: language,
                commentAlignment: CommentAlignment.center,
                showCurrentTime: true,
                showCurrentSeconds: true,
                use24Hour: true,
                isAlwaysOnTop: false,
                showAlwaysOnTopOption: false,
                breakFeatureEnabled: breakFeatureEnabled,
                breakDuration: breakDuration,
                onLanguageChanged: (_) async {},
                onCommentAlignmentChanged: (_) async {},
                onShowCurrentTimeChanged: (_) async {},
                onShowCurrentSecondsChanged: (_) async {},
                onUse24HourChanged: (_) async {},
                onAlwaysOnTopChanged: (_) async {},
                onBreakFeatureEnabledChanged: (value) async {
                  onBreakFeatureEnabledChanged(value);
                },
                onBreakDurationChanged: (value) async {
                  onBreakDurationChanged(value);
                },
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Break settings in the settings sheet', () {
    testWidgets('shows Japanese labels for the break feature', (tester) async {
      await _openSheet(
        tester,
        language: AppLanguage.japanese,
        onBreakFeatureEnabledChanged: (_) {},
        onBreakDurationChanged: (_) {},
      );

      expect(find.text('休憩機能'), findsOneWidget);
    });

    testWidgets('shows English labels for the break feature', (tester) async {
      await _openSheet(
        tester,
        language: AppLanguage.english,
        onBreakFeatureEnabledChanged: (_) {},
        onBreakDurationChanged: (_) {},
      );

      expect(find.text('Break'), findsOneWidget);
    });

    testWidgets('hides the break duration selector when the feature is off', (
      tester,
    ) async {
      await _openSheet(
        tester,
        language: AppLanguage.japanese,
        breakFeatureEnabled: false,
        onBreakFeatureEnabledChanged: (_) {},
        onBreakDurationChanged: (_) {},
      );

      expect(find.text('休憩時間'), findsNothing);
    });

    testWidgets('shows the break duration selector when the feature is on', (
      tester,
    ) async {
      await _openSheet(
        tester,
        language: AppLanguage.japanese,
        breakFeatureEnabled: true,
        onBreakFeatureEnabledChanged: (_) {},
        onBreakDurationChanged: (_) {},
      );

      expect(find.text('休憩時間'), findsOneWidget);
    });

    testWidgets('toggling the break switch reports the new value', (
      tester,
    ) async {
      bool? reported;

      await _openSheet(
        tester,
        language: AppLanguage.japanese,
        breakFeatureEnabled: false,
        onBreakFeatureEnabledChanged: (value) => reported = value,
        onBreakDurationChanged: (_) {},
      );

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(reported, isTrue);
    });
  });
}
