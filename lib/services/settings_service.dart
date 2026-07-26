import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';

class AppSettings {
  const AppSettings({
    required this.showTitle,
    required this.alwaysOnTop,
    required this.showCurrentTime,
    required this.showCurrentSeconds,
    required this.use24Hour,
    required this.language,
  });

  final String showTitle;
  final bool alwaysOnTop;
  final bool showCurrentTime;
  final bool showCurrentSeconds;
  final bool use24Hour;
  final AppLanguage language;
}

class SettingsService {
  SettingsService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _showTitleKey = 'show_title';
  static const String _alwaysOnTopKey = 'always_on_top';
  static const String _showCurrentTimeKey = 'show_current_time';
  static const String _showCurrentSecondsKey = 'show_current_seconds';
  static const String _use24HourKey = 'use_24_hour';
  static const String _languageKey = 'display_language';

  final SharedPreferencesAsync _preferences;

  Future<AppSettings> load() async {
    final showTitle = await _preferences.getString(_showTitleKey) ?? '';
    final alwaysOnTop = await _preferences.getBool(_alwaysOnTopKey) ?? false;
    final showCurrentTime =
        await _preferences.getBool(_showCurrentTimeKey) ?? true;
    final showCurrentSeconds =
        await _preferences.getBool(_showCurrentSecondsKey) ?? true;
    final use24Hour = await _preferences.getBool(_use24HourKey) ?? true;
    final languageCode = await _preferences.getString(_languageKey) ?? 'ja';

    return AppSettings(
      showTitle: showTitle.trim(),
      alwaysOnTop: alwaysOnTop,
      showCurrentTime: showCurrentTime,
      showCurrentSeconds: showCurrentSeconds,
      use24Hour: use24Hour,
      language: languageCode == 'en'
          ? AppLanguage.english
          : AppLanguage.japanese,
    );
  }

  Future<void> saveShowTitle(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _preferences.remove(_showTitleKey);
      return;
    }
    await _preferences.setString(_showTitleKey, trimmed);
  }

  Future<void> saveAlwaysOnTop(bool value) =>
      _preferences.setBool(_alwaysOnTopKey, value);

  Future<void> saveShowCurrentTime(bool value) =>
      _preferences.setBool(_showCurrentTimeKey, value);

  Future<void> saveShowCurrentSeconds(bool value) =>
      _preferences.setBool(_showCurrentSecondsKey, value);

  Future<void> saveUse24Hour(bool value) =>
      _preferences.setBool(_use24HourKey, value);

  Future<void> saveLanguage(AppLanguage value) => _preferences.setString(
    _languageKey,
    value == AppLanguage.english ? 'en' : 'ja',
  );
}
