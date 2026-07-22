import 'package:flutter/material.dart';

import '../controllers/show_timer_controller.dart';

class MainControls extends StatelessWidget {
  const MainControls({
    super.key,
    required this.status,
    required this.controlsVisible,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.resetButton,
  });

  final ShowTimerStatus status;
  final bool controlsVisible;
  final double width;
  final double height;
  final double fontSize;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final Widget resetButton;

  ButtonStyle _buttonStyle({
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ShowTimerStatus.idle:
        return SizedBox(
          key: const ValueKey('idle-controls'),
          width: width,
          height: height,
          child: ElevatedButton(
            style: _buttonStyle(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: onStart,
            child: Text(
              'START',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );

      case ShowTimerStatus.running:
        return AnimatedOpacity(
          key: const ValueKey('running-controls'),
          opacity: controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !controlsVisible,
            child: SizedBox(
              width: width,
              height: height,
              child: ElevatedButton(
                style: _buttonStyle(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: onPause,
                child: Text(
                  'PAUSE',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );

      case ShowTimerStatus.paused:
        final availableButtonWidth = (width - 12) / 2;

        return Row(
          key: const ValueKey('paused-controls'),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: availableButtonWidth,
              height: height,
              child: ElevatedButton(
                style: _buttonStyle(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: onResume,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'RESUME',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: fontSize * 0.82,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: availableButtonWidth,
              height: height,
              child: resetButton,
            ),
          ],
        );
    }
  }
}
