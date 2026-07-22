import 'package:flutter/material.dart';

enum AppLanguage { japanese, english }

typedef AsyncBoolChanged = Future<void> Function(bool value);
typedef AsyncLanguageChanged = Future<void> Function(AppLanguage value);

Future<void> showSettingsSheet({
  required BuildContext context,
  required AppLanguage language,
  required bool showCurrentTime,
  required bool showCurrentSeconds,
  required bool use24Hour,
  required bool isAlwaysOnTop,
  required bool showAlwaysOnTopOption,
  required AsyncLanguageChanged onLanguageChanged,
  required AsyncBoolChanged onShowCurrentTimeChanged,
  required AsyncBoolChanged onShowCurrentSecondsChanged,
  required AsyncBoolChanged onUse24HourChanged,
  required AsyncBoolChanged onAlwaysOnTopChanged,
}) {
  AppLanguage currentLanguage = language;
  bool currentShowCurrentTime = showCurrentTime;
  bool currentShowCurrentSeconds = showCurrentSeconds;
  bool currentUse24Hour = use24Hour;
  bool currentIsAlwaysOnTop = isAlwaysOnTop;

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

          return SafeArea(
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
                        title: translate('現在時刻に秒を表示', 'Show Current Seconds'),
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
              activeColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
