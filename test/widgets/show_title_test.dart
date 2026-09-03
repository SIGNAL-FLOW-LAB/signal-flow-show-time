import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/widgets/show_title.dart';

Widget _wrap(Widget child, {double width = 320}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(width: width, child: child),
    ),
  );
}

void main() {
  group('ShowTitle: empty placeholder', () {
    testWidgets('shows a pencil icon instead of placeholder text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 20,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.text('コメントを入力'), findsNothing);
    });

    testWidgets('treats a whitespace-only title as empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '   \n\t  ',
            fontSize: 20,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('positions the icon at the top-right of the reserved area', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 18,
            availableWidth: 300,
            maxLines: 8,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
          width: 320,
        ),
      );

      final areaRect = tester.getRect(find.byType(ShowTitle));
      // The icon's rendered rect is its 44x44 tap target (larger than the
      // glyph itself, for a comfortable tap area).
      final tapTargetRect = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.edit),
          matching: find.byType(InkWell),
        ),
      );

      // The tap target sits near the top-right corner (a tight 4px inset,
      // similar to the settings gear icon's own margin), not centered in
      // the (much taller, multi-line-reserved) placeholder area.
      expect(tapTargetRect.right, closeTo(areaRect.right - 4, 2));
      expect(tapTargetRect.top, closeTo(areaRect.top + 4, 2));
      expect(tapTargetRect.bottom, lessThan(areaRect.center.dy));
    });

    testWidgets('falls back to a centered icon instead of overflowing when the '
        'available area is narrower than the minimum tap size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 12,
            availableWidth: 24,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
          width: 24,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets(
      'ShowTitle.reservedHeightFor matches the actual rendered footprint '
      '(callers rely on this to independently position siblings)',
      (tester) async {
        const fontSize = 18.0;
        const maxLines = 8;

        await tester.pumpWidget(
          _wrap(
            ShowTitle(
              title: '',
              fontSize: fontSize,
              availableWidth: 300,
              maxLines: maxLines,
              emptyTitleLabel: 'コメントを入力',
              editTitleLabel: '表示コメントを編集',
              onBeginEditing: () {},
            ),
          ),
        );

        final areaRect = tester.getRect(find.byType(ShowTitle));
        final predicted = ShowTitle.reservedHeightFor(
          fontSize: fontSize,
          maxLines: maxLines,
        );

        expect(areaRect.height, closeTo(predicted, 0.5));
      },
    );

    testWidgets('exposes an accessible label equivalent to "Edit comment"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 20,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('コメントを入力'), findsOneWidget);

      handle.dispose();
    });

    testWidgets("the icon's own tap target is at least 44x44 (WCAG target "
        'size)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 10,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );

      final tapTargetRect = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.edit),
          matching: find.byType(InkWell),
        ),
      );
      expect(tapTargetRect.width, greaterThanOrEqualTo(44));
      expect(tapTargetRect.height, greaterThanOrEqualTo(44));
    });

    testWidgets('tapping the pencil icon begins editing', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 20,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit));
      expect(tapped, isTrue);
    });

    testWidgets(
      'tapping the reserved area outside the icon does not begin editing',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _wrap(
            ShowTitle(
              title: '',
              fontSize: 20,
              availableWidth: 300,
              maxLines: 4,
              emptyTitleLabel: 'コメントを入力',
              editTitleLabel: '表示コメントを編集',
              onBeginEditing: () => tapped = true,
            ),
          ),
        );

        // The reserved area is much taller than the icon (maxLines: 4), so
        // its top-left corner is well clear of the top-right icon.
        final areaRect = tester.getRect(find.byType(ShowTitle));
        await tester.tapAt(areaRect.topLeft + const Offset(4, 4));

        expect(tapped, isFalse);
      },
    );
  });

  group('ShowTitle: filled comment', () {
    testWidgets('shows the title text, not the pencil icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: 'テストコメント',
            fontSize: 20,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );

      expect(find.text('テストコメント'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    for (final entry in {
      TextAlign.left: 'left',
      TextAlign.center: 'center',
      TextAlign.right: 'right',
    }.entries) {
      testWidgets('honors ${entry.value} textAlign for filled comments', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            ShowTitle(
              title: 'テストコメント',
              fontSize: 20,
              availableWidth: 300,
              textAlign: entry.key,
              emptyTitleLabel: 'コメントを入力',
              editTitleLabel: '表示コメントを編集',
              onBeginEditing: () {},
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('テストコメント'));
        expect(text.textAlign, entry.key);
      });
    }

    testWidgets('reserves the same fixed height regardless of empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: '',
            fontSize: 18,
            availableWidth: 300,
            maxLines: 3,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );
      final emptyHeight = tester.getRect(find.byType(ShowTitle)).height;

      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: 'テストコメント',
            fontSize: 18,
            availableWidth: 300,
            maxLines: 3,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () {},
          ),
        ),
      );
      final filledHeight = tester.getRect(find.byType(ShowTitle)).height;

      expect(filledHeight, closeTo(emptyHeight, 0.5));
    });

    testWidgets('tapping the filled comment begins editing', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          ShowTitle(
            title: 'テストコメント',
            fontSize: 20,
            availableWidth: 300,
            emptyTitleLabel: 'コメントを入力',
            editTitleLabel: '表示コメントを編集',
            onBeginEditing: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('テストコメント'));
      expect(tapped, isTrue);
    });
  });
}
