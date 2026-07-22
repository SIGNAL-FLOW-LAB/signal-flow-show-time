import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/widgets/show_elapsed_display.dart';

void main() {
  testWidgets('Show elapsed time is formatted correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShowElapsedDisplay(
            elapsed: Duration(hours: 1, minutes: 2, seconds: 3),
            color: Colors.amber,
            fontSize: 72,
          ),
        ),
      ),
    );

    expect(find.text('01:02:03'), findsOneWidget);
  });
}
