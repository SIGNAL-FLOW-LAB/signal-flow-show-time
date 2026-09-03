import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';
import '../models/comment_alignment.dart';

class AppSettings {
  const AppSettings({
    required this.showTitle,
    required this.alwaysOnTop,
    required this.showCurrentTime,
    required this.showCurrentSeconds,
    required this.use24Hour,
    required this.language,
    required this.commentAlignment,
    required this.breakFeatureEnabled,
    required this.breakDuration,
  });

  final String showTitle;
  final bool alwaysOnTop;
  final bool showCurrentTime;
  final bool showCurrentSeconds;
  final bool use24Hour;
  final AppLanguage language;
  final CommentAlignment commentAlignment;
  final bool breakFeatureEnabled;
  final Duration breakDuration;
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

  // v1.0.4 コメント位置
  static const String _commentAlignmentKey = 'comment_alignment';

  // 休憩機能
  static const String _breakFeatureEnabledKey = 'break_feature_enabled';
  static const String _breakDurationMinutesKey = 'break_duration_minutes';
  static const int _defaultBreakDurationMinutes = 15;

  final SharedPreferencesAsync _preferences;

  // ---------------------------------------------------------------------------
  // 設定読み込み
  // ---------------------------------------------------------------------------

  Future<AppSettings> load() async {
    final showTitle = await _preferences.getString(_showTitleKey) ?? '';

    final alwaysOnTop = await _preferences.getBool(_alwaysOnTopKey) ?? false;

    final showCurrentTime =
        await _preferences.getBool(_showCurrentTimeKey) ?? true;

    final showCurrentSeconds =
        await _preferences.getBool(_showCurrentSecondsKey) ?? true;

    final use24Hour = await _preferences.getBool(_use24HourKey) ?? true;

    final languageCode = await _preferences.getString(_languageKey) ?? 'ja';

    final commentAlignmentName =
        await _preferences.getString(_commentAlignmentKey) ?? 'center';

    final commentAlignment = CommentAlignment.values.firstWhere(
      (value) => value.name == commentAlignmentName,
      orElse: () => CommentAlignment.center,
    );

    final breakFeatureEnabled =
        await _preferences.getBool(_breakFeatureEnabledKey) ?? false;

    final breakDurationMinutes =
        await _preferences.getInt(_breakDurationMinutesKey) ??
        _defaultBreakDurationMinutes;

    return AppSettings(
      showTitle: showTitle.trim(),
      alwaysOnTop: alwaysOnTop,
      showCurrentTime: showCurrentTime,
      showCurrentSeconds: showCurrentSeconds,
      use24Hour: use24Hour,
      language: languageCode == 'en'
          ? AppLanguage.english
          : AppLanguage.japanese,
      commentAlignment: commentAlignment,
      breakFeatureEnabled: breakFeatureEnabled,
      breakDuration: Duration(
        minutes: breakDurationMinutes <= 0
            ? _defaultBreakDurationMinutes
            : breakDurationMinutes,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 表示コメント
  // ---------------------------------------------------------------------------

  Future<void> saveShowTitle(String value) async {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      await _preferences.remove(_showTitleKey);
      return;
    }

    await _preferences.setString(_showTitleKey, trimmed);
  }

  // ---------------------------------------------------------------------------
  // コメント位置
  // ---------------------------------------------------------------------------

  Future<void> saveCommentAlignment(CommentAlignment value) async {
    await _preferences.setString(_commentAlignmentKey, value.name);
  }

  // ---------------------------------------------------------------------------
  // 常に最前面
  // ---------------------------------------------------------------------------

  Future<void> saveAlwaysOnTop(bool value) {
    return _preferences.setBool(_alwaysOnTopKey, value);
  }

  // ---------------------------------------------------------------------------
  // 現在時刻
  // ---------------------------------------------------------------------------

  Future<void> saveShowCurrentTime(bool value) {
    return _preferences.setBool(_showCurrentTimeKey, value);
  }

  Future<void> saveShowCurrentSeconds(bool value) {
    return _preferences.setBool(_showCurrentSecondsKey, value);
  }

  // ---------------------------------------------------------------------------
  // 24時間表記
  // ---------------------------------------------------------------------------

  Future<void> saveUse24Hour(bool value) {
    return _preferences.setBool(_use24HourKey, value);
  }

  // ---------------------------------------------------------------------------
  // 表示言語
  // ---------------------------------------------------------------------------

  Future<void> saveLanguage(AppLanguage value) {
    return _preferences.setString(
      _languageKey,
      value == AppLanguage.english ? 'en' : 'ja',
    );
  }

  // ---------------------------------------------------------------------------
  // 休憩機能
  // ---------------------------------------------------------------------------

  Future<void> saveBreakFeatureEnabled(bool value) {
    return _preferences.setBool(_breakFeatureEnabledKey, value);
  }

  Future<void> saveBreakDuration(Duration value) {
    final minutes = value.inMinutes <= 0
        ? _defaultBreakDurationMinutes
        : value.inMinutes;

    return _preferences.setInt(_breakDurationMinutesKey, minutes);
  }
}
