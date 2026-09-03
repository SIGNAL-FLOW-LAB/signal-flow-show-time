import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:show_time/services/settings_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SettingsService break settings', () {
    test(
      'defaults break feature to disabled and duration to 15 minutes',
      () async {
        final service = SettingsService();

        final settings = await service.load();

        expect(settings.breakFeatureEnabled, isFalse);
        expect(settings.breakDuration, const Duration(minutes: 15));
      },
    );

    test('persists break feature enabled flag', () async {
      final service = SettingsService();

      await service.saveBreakFeatureEnabled(true);
      final settings = await service.load();

      expect(settings.breakFeatureEnabled, isTrue);
    });

    test('persists a custom break duration in hours and minutes', () async {
      final service = SettingsService();

      await service.saveBreakDuration(const Duration(hours: 1, minutes: 30));
      final settings = await service.load();

      expect(settings.breakDuration, const Duration(hours: 1, minutes: 30));
    });

    test(
      'a fresh SettingsService instance reads back persisted values',
      () async {
        final writer = SettingsService();
        await writer.saveBreakFeatureEnabled(true);
        await writer.saveBreakDuration(const Duration(minutes: 20));

        final reader = SettingsService();
        final settings = await reader.load();

        expect(settings.breakFeatureEnabled, isTrue);
        expect(settings.breakDuration, const Duration(minutes: 20));
      },
    );
  });
}
