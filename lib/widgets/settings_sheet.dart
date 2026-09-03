import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_language.dart';
import '../models/comment_alignment.dart';

typedef AsyncBoolChanged = Future<void> Function(bool value);
typedef AsyncLanguageChanged = Future<void> Function(AppLanguage value);
typedef AsyncCommentAlignmentChanged =
    Future<void> Function(CommentAlignment value);
typedef AsyncDurationChanged = Future<void> Function(Duration value);

Future<void> showSettingsSheet({
  required BuildContext context,
  required AppLanguage language,
  required CommentAlignment commentAlignment,
  required bool showCurrentTime,
  required bool showCurrentSeconds,
  required bool use24Hour,
  required bool isAlwaysOnTop,
  required bool showAlwaysOnTopOption,
  required bool breakFeatureEnabled,
  required Duration breakDuration,
  required AsyncLanguageChanged onLanguageChanged,
  required AsyncCommentAlignmentChanged onCommentAlignmentChanged,
  required AsyncBoolChanged onShowCurrentTimeChanged,
  required AsyncBoolChanged onShowCurrentSecondsChanged,
  required AsyncBoolChanged onUse24HourChanged,
  required AsyncBoolChanged onAlwaysOnTopChanged,
  required AsyncBoolChanged onBreakFeatureEnabledChanged,
  required AsyncDurationChanged onBreakDurationChanged,
}) {
  AppLanguage currentLanguage = language;
  CommentAlignment currentCommentAlignment = commentAlignment;
  bool currentShowCurrentTime = showCurrentTime;
  bool currentShowCurrentSeconds = showCurrentSeconds;
  bool currentUse24Hour = use24Hour;
  bool currentIsAlwaysOnTop = isAlwaysOnTop;
  bool currentBreakFeatureEnabled = breakFeatureEnabled;
  Duration currentBreakDuration = breakDuration;

  String translate(String japanese, String english) {
    return currentLanguage == AppLanguage.japanese ? japanese : english;
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, updateSheet) {
          Future<void> updateShowCurrentTime(bool value) async {
            await onShowCurrentTimeChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentShowCurrentTime = value;
              });
            }
          }

          Future<void> updateShowCurrentSeconds(bool value) async {
            await onShowCurrentSecondsChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentShowCurrentSeconds = value;
              });
            }
          }

          Future<void> updateUse24Hour(bool value) async {
            await onUse24HourChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentUse24Hour = value;
              });
            }
          }

          Future<void> updateAlwaysOnTop(bool value) async {
            await onAlwaysOnTopChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentIsAlwaysOnTop = value;
              });
            }
          }

          Future<void> updateLanguage(AppLanguage value) async {
            await onLanguageChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentLanguage = value;
              });
            }
          }

          Future<void> updateCommentAlignment(CommentAlignment value) async {
            await onCommentAlignmentChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentCommentAlignment = value;
              });
            }
          }

          Future<void> updateBreakFeatureEnabled(bool value) async {
            await onBreakFeatureEnabledChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentBreakFeatureEnabled = value;
              });
            }
          }

          Future<void> updateBreakDuration(Duration value) async {
            await onBreakDurationChanged(value);

            if (sheetContext.mounted) {
              updateSheet(() {
                currentBreakDuration = value;
              });
            }
          }

          return CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): () {
                Navigator.of(sheetContext).pop();
              },
            },
            child: Focus(
              autofocus: true,
              child: SafeArea(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 620,
                      maxHeight: 700,
                    ),
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            translate('表示設定', 'Display Settings'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 18),

                          _LanguageSelector(
                            language: currentLanguage,
                            translate: translate,
                            onChanged: updateLanguage,
                          ),

                          const SizedBox(height: 12),

                          _CommentAlignmentSelector(
                            alignment: currentCommentAlignment,
                            translate: translate,
                            onChanged: updateCommentAlignment,
                          ),

                          const SizedBox(height: 12),

                          _SettingSwitch(
                            title: translate('現在時刻を表示', 'Show Current Time'),
                            subtitle: translate(
                              '公演用ストップウォッチの上に現在時刻を表示します',
                              'Shows the current time above the show timer.',
                            ),
                            value: currentShowCurrentTime,
                            onChanged: updateShowCurrentTime,
                          ),

                          const SizedBox(height: 8),

                          _SettingSwitch(
                            title: translate(
                              '現在時刻に秒を表示',
                              'Show Current Seconds',
                            ),
                            subtitle: translate(
                              'OFFにすると「17:45」のように表示します',
                              'When off, the time is shown like “17:45”.',
                            ),
                            value: currentShowCurrentSeconds,
                            enabled: currentShowCurrentTime,
                            onChanged: updateShowCurrentSeconds,
                          ),

                          const SizedBox(height: 8),

                          _SettingSwitch(
                            title: translate('24時間表記', '24-Hour Format'),
                            subtitle: currentUse24Hour
                                ? translate(
                                    '17:45形式で表示します',
                                    'Displays time in 17:45 format.',
                                  )
                                : translate(
                                    '05:45 PM形式で表示します',
                                    'Displays time in 05:45 PM format.',
                                  ),
                            value: currentUse24Hour,
                            enabled: currentShowCurrentTime,
                            onChanged: updateUse24Hour,
                          ),

                          if (showAlwaysOnTopOption) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: Colors.white24, height: 1),
                            ),
                            _SettingSwitch(
                              title: translate('常に最前面に表示', 'Always on Top'),
                              subtitle: translate(
                                'ほかのアプリを操作してもShow Timeを手前に残します',
                                'Keeps Show Time above other apps.',
                              ),
                              value: currentIsAlwaysOnTop,
                              onChanged: updateAlwaysOnTop,
                            ),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white24, height: 1),
                          ),

                          _SettingSwitch(
                            title: translate('休憩機能', 'Break'),
                            subtitle: translate(
                              '公演中に予定された休憩を挟めるようにします',
                              'Lets you insert a scheduled break during the show.',
                            ),
                            value: currentBreakFeatureEnabled,
                            onChanged: updateBreakFeatureEnabled,
                          ),

                          if (currentBreakFeatureEnabled) ...[
                            const SizedBox(height: 8),
                            _BreakDurationSelector(
                              duration: currentBreakDuration,
                              translate: translate,
                              onChanged: updateBreakDuration,
                            ),
                          ],

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF69F0AE),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
                              child: Text(
                                translate('閉じる', 'Close'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.language,
    required this.translate,
    required this.onChanged,
  });

  final AppLanguage language;
  final String Function(String japanese, String english) translate;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('表示言語', 'Display Language'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  translate(
                    '画面内の固定ラベルを切り替えます',
                    'Changes the fixed labels in the app.',
                  ),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          ToggleButtons(
            isSelected: [
              language == AppLanguage.japanese,
              language == AppLanguage.english,
            ],
            onPressed: (index) {
              onChanged(
                index == 0 ? AppLanguage.japanese : AppLanguage.english,
              );
            },
            borderRadius: BorderRadius.circular(9),
            constraints: const BoxConstraints(minWidth: 52, minHeight: 36),
            color: Colors.white70,
            selectedColor: Colors.black,
            fillColor: const Color(0xFF69F0AE),
            borderColor: Colors.white24,
            selectedBorderColor: const Color(0xFF69F0AE),
            children: const [Text('日本語'), Text('EN')],
          ),
        ],
      ),
    );
  }
}

class _CommentAlignmentSelector extends StatelessWidget {
  const _CommentAlignmentSelector({
    required this.alignment,
    required this.translate,
    required this.onChanged,
  });

  final CommentAlignment alignment;
  final String Function(String japanese, String english) translate;
  final ValueChanged<CommentAlignment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('コメント位置', 'Comment Alignment'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            translate(
              '表示コメントの文字揃えを選択します',
              'Choose the alignment of the display comment.',
            ),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: Center(
              child: ToggleButtons(
                isSelected: [
                  alignment == CommentAlignment.left,
                  alignment == CommentAlignment.center,
                  alignment == CommentAlignment.right,
                ],
                onPressed: (index) {
                  switch (index) {
                    case 0:
                      onChanged(CommentAlignment.left);
                      break;
                    case 1:
                      onChanged(CommentAlignment.center);
                      break;
                    case 2:
                      onChanged(CommentAlignment.right);
                      break;
                  }
                },
                borderRadius: BorderRadius.circular(9),
                constraints: const BoxConstraints(minWidth: 82, minHeight: 38),
                color: Colors.white70,
                selectedColor: Colors.black,
                fillColor: const Color(0xFF69F0AE),
                borderColor: Colors.white24,
                selectedBorderColor: const Color(0xFF69F0AE),
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.format_align_left, size: 17),
                      const SizedBox(width: 5),
                      Text(translate('左', 'Left')),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.format_align_center, size: 17),
                      const SizedBox(width: 5),
                      Text(translate('中央', 'Center')),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.format_align_right, size: 17),
                      const SizedBox(width: 5),
                      Text(translate('右', 'Right')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakDurationSelector extends StatelessWidget {
  const _BreakDurationSelector({
    required this.duration,
    required this.translate,
    required this.onChanged,
  });

  final Duration duration;
  final String Function(String japanese, String english) translate;
  final ValueChanged<Duration> onChanged;

  static const List<int> _hourOptions = [0, 1, 2, 3, 4, 5];
  static const List<int> _minuteOptions = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
  ];

  @override
  Widget build(BuildContext context) {
    final totalMinutes = duration.inMinutes;
    final hours = (totalMinutes ~/ 60)
        .clamp(_hourOptions.first, _hourOptions.last)
        .toInt();
    final minutes = (totalMinutes % 60).clamp(0, 59).toInt();

    // 分の選択肢のうち、現在値以下で最も近い値に丸めます。
    final nearestMinuteOption = _minuteOptions.lastWhere(
      (option) => option <= minutes,
      orElse: () => 0,
    );

    void notifyChange({int? newHours, int? newMinutes}) {
      final resolvedHours = newHours ?? hours;
      final resolvedMinutes = newMinutes ?? nearestMinuteOption;

      var next = Duration(hours: resolvedHours, minutes: resolvedMinutes);

      if (next <= Duration.zero) {
        next = const Duration(minutes: 5);
      }

      onChanged(next);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('休憩時間', 'Break Duration'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  translate('休憩ボタンを押したときの休憩時間です', 'Length of a break.'),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          DropdownButton<int>(
            value: hours,
            dropdownColor: const Color(0xFF222222),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) {
                notifyChange(newHours: value);
              }
            },
            items: [
              for (final option in _hourOptions)
                DropdownMenuItem(
                  value: option,
                  child: Text(translate('$option時間', '${option}h')),
                ),
            ],
          ),

          const SizedBox(width: 8),

          DropdownButton<int>(
            value: nearestMinuteOption,
            dropdownColor: const Color(0xFF222222),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) {
                notifyChange(newMinutes: value);
              }
            },
            items: [
              for (final option in _minuteOptions)
                DropdownMenuItem(
                  value: option,
                  child: Text(translate('$option分', '${option}m')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeTrackColor: Colors.green.shade600,
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
