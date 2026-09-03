import 'package:flutter/material.dart';

class BreakResumeDisplay extends StatelessWidget {
  const BreakResumeDisplay({
    super.key,
    required this.resumeAt,
    required this.use24Hour,
    required this.isEndingSoon,
    required this.label,
    required this.labelFontSize,
    required this.timeFontSize,
    required this.labelGap,
    this.maxWidth,
    this.normalColor = Colors.white,
  });

  final DateTime resumeAt;
  final bool use24Hour;
  final bool isEndingSoon;
  final String label;
  final double labelFontSize;
  final double timeFontSize;
  final double labelGap;
  final double? maxWidth;

  // 休憩終了1分前の警告色ではないときの、時刻の色。既定は白（iPhone/iPad向け
  // の従来表示）。macOSでは視認性向上のためオレンジ系の色を渡します。
  final Color normalColor;

  String _formatResumeTime(DateTime time) {
    if (use24Hour) {
      final hours = time.hour.toString();
      final minutes = time.minute.toString().padLeft(2, '0');
      return '$hours:$minutes';
    }

    final period = time.hour >= 12 ? 'PM' : 'AM';
    var displayHour = time.hour % 12;
    if (displayHour == 0) {
      displayHour = 12;
    }
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$minutes $period';
  }

  @override
  Widget build(BuildContext context) {
    final timeColor = isEndingSoon ? const Color(0xFFFFAB40) : normalColor;

    return SizedBox(
      width: maxWidth ?? double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            key: const ValueKey('break-resume-label'),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white70,
              fontSize: labelFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          SizedBox(height: labelGap),

          SizedBox(
            width: double.infinity,
            height: timeFontSize * 1.2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatResumeTime(resumeAt),
                key: const ValueKey('break-resume-time'),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: timeColor,
                  fontSize: timeFontSize,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
