import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:show_time/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionService timer state', () {
    test(
      'loadTimerState defaults to no break when nothing was saved',
      () async {
        final service = SessionService();

        final state = await service.loadTimerState();

        expect(state.elapsed, Duration.zero);
        expect(state.isOnBreak, isFalse);
        expect(state.breakEndsAt, isNull);
      },
    );

    test('saves and restores an in-progress break with breakEndsAt', () async {
      final service = SessionService();
      final breakEndsAt = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch + 900000,
      );

      await service.saveTimerState(
        elapsed: const Duration(minutes: 42),
        isOnBreak: true,
        breakEndsAt: breakEndsAt,
      );

      final state = await service.loadTimerState();

      expect(state.elapsed, const Duration(minutes: 42));
      expect(state.isOnBreak, isTrue);
      expect(state.breakEndsAt, breakEndsAt);
    });

    test('clears breakEndsAt when saving a non-break state', () async {
      final service = SessionService();

      await service.saveTimerState(
        elapsed: const Duration(minutes: 5),
        isOnBreak: true,
        breakEndsAt: DateTime.now(),
      );

      await service.saveTimerState(
        elapsed: const Duration(minutes: 6),
        isOnBreak: false,
      );

      final state = await service.loadTimerState();

      expect(state.isOnBreak, isFalse);
      expect(state.breakEndsAt, isNull);
    });
  });
}
