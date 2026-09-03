import 'package:flutter_test/flutter_test.dart';
import 'package:show_time/controllers/show_timer_controller.dart';
import 'package:show_time/models/show_timer_status.dart';

void main() {
  group('ShowTimerController break handling', () {
    test('startBreak stops the show time count and sets breakEndsAt', () {
      final controller = ShowTimerController();
      controller.start();

      controller.startBreak(const Duration(minutes: 15));

      expect(controller.status, ShowTimerStatus.onBreak);
      expect(controller.isOnBreak, isTrue);
      expect(controller.isPaused, isFalse);
      expect(controller.breakEndsAt, isNotNull);

      final elapsedAtBreakStart = controller.elapsed;

      // Elapsed show time must not advance while on break.
      expect(controller.elapsed, elapsedAtBreakStart);

      controller.dispose();
    });

    test('resumeFromBreakNow excludes only the actual time on break', () async {
      final controller = ShowTimerController();
      controller.start();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.startBreak(const Duration(minutes: 15));
      final elapsedAtBreakStart = controller.elapsed;

      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.resumeFromBreakNow();

      expect(controller.status, ShowTimerStatus.running);
      expect(controller.breakEndsAt, isNull);
      // Resuming immediately should not have added the break duration.
      expect(
        controller.elapsed.inMilliseconds,
        closeTo(elapsedAtBreakStart.inMilliseconds, 40),
      );

      controller.dispose();
    });

    test('does not allow pause while on break (states are exclusive)', () {
      final controller = ShowTimerController();
      controller.start();
      controller.startBreak(const Duration(minutes: 15));

      controller.pause();

      // pause() only operates on a running show, so it must be a no-op here.
      expect(controller.status, ShowTimerStatus.onBreak);

      controller.dispose();
    });

    test('does not allow starting a break while paused', () {
      final controller = ShowTimerController();
      controller.start();
      controller.pause();

      controller.startBreak(const Duration(minutes: 15));

      expect(controller.status, ShowTimerStatus.paused);
      expect(controller.breakEndsAt, isNull);

      controller.dispose();
    });

    test('reset clears break status and breakEndsAt', () {
      final controller = ShowTimerController();
      controller.start();
      controller.startBreak(const Duration(minutes: 15));

      controller.reset();

      expect(controller.status, ShowTimerStatus.idle);
      expect(controller.breakEndsAt, isNull);
      expect(controller.elapsed, Duration.zero);

      controller.dispose();
    });

    test(
      'restoreState resumes automatically and folds in time since breakEndsAt '
      'when breakEndsAt has already passed',
      () {
        final controller = ShowTimerController();
        final breakEndsAt = DateTime.now().subtract(
          const Duration(seconds: 30),
        );

        controller.restoreState(
          elapsed: const Duration(minutes: 10),
          isOnBreak: true,
          breakEndsAt: breakEndsAt,
        );

        expect(controller.status, ShowTimerStatus.running);
        expect(controller.breakEndsAt, isNull);
        // The 30s spent backgrounded past breakEndsAt should be added on top
        // of the 10 minutes of show time accumulated before the break.
        expect(controller.elapsed.inSeconds, greaterThanOrEqualTo(630));
        expect(controller.elapsed.inSeconds, lessThan(635));

        controller.dispose();
      },
    );

    test(
      'restoreState keeps the break active when breakEndsAt has not passed yet',
      () {
        final controller = ShowTimerController();
        final breakEndsAt = DateTime.now().add(const Duration(minutes: 5));

        controller.restoreState(
          elapsed: const Duration(minutes: 10),
          isOnBreak: true,
          breakEndsAt: breakEndsAt,
        );

        expect(controller.status, ShowTimerStatus.onBreak);
        expect(controller.breakEndsAt, breakEndsAt);
        expect(controller.elapsed, const Duration(minutes: 10));

        controller.dispose();
      },
    );

    test('restoreState without a break restores idle/paused as before', () {
      final controller = ShowTimerController();

      controller.restoreState(elapsed: Duration.zero, isOnBreak: false);
      expect(controller.status, ShowTimerStatus.idle);

      controller.restoreState(
        elapsed: const Duration(minutes: 3),
        isOnBreak: false,
      );
      expect(controller.status, ShowTimerStatus.paused);

      controller.dispose();
    });

    test(
      'refreshAfterResume auto-resumes when breakEndsAt has passed',
      () async {
        final controller = ShowTimerController();
        controller.start();
        controller.startBreak(const Duration(milliseconds: 5));

        // Simulate the app coming back from background after breakEndsAt.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        controller.refreshAfterResume();

        expect(controller.status, ShowTimerStatus.running);
        expect(controller.breakEndsAt, isNull);

        controller.dispose();
      },
    );

    test(
      'refreshAfterResume keeps the break active when breakEndsAt is still ahead',
      () {
        final controller = ShowTimerController();
        controller.start();
        controller.startBreak(const Duration(minutes: 15));

        controller.refreshAfterResume();

        expect(controller.status, ShowTimerStatus.onBreak);
        expect(controller.breakEndsAt, isNotNull);

        controller.dispose();
      },
    );

    test(
      'automatically resumes once breakEndsAt is reached (foreground tick)',
      () async {
        final controller = ShowTimerController(
          tickInterval: const Duration(milliseconds: 20),
        );
        controller.start();
        controller.startBreak(const Duration(milliseconds: 60));

        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(controller.status, ShowTimerStatus.running);
        expect(controller.breakEndsAt, isNull);

        controller.dispose();
      },
    );
  });
}
