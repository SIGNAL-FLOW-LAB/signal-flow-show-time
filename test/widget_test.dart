import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/app.dart';

void main() {
  testWidgets('Show Time app starts successfully', (tester) async {
    await tester.pumpWidget(const ShowTimeApp());
    await tester.pump();

    expect(find.text('SHOW TIME'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}
