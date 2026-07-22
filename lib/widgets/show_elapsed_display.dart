import 'package:flutter/material.dart';

class ShowElapsedDisplay extends StatelessWidget {
  const ShowElapsedDisplay({
    super.key,
    required this.elapsed,
    required this.color,
    required this.fontSize,
  });

  final Duration elapsed;
  final Color color;
  final double fontSize;

  String _format(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: fontSize * 1.24,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Text(_format(elapsed), maxLines: 1),
        ),
      ),
    );
  }
}
