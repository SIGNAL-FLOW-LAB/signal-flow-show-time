import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const ShowTimeApp());
}

class ShowTimeApp extends StatelessWidget {
  const ShowTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SIGNAL FLOW Show Time',
      debugShowCheckedModeBanner: false,
      home: ShowTimeScreen(),
    );
  }
}

enum ShowTimerStatus { idle, running, paused }

class ShowTimeScreen extends StatefulWidget {
  const ShowTimeScreen({super.key});

  @override
  State<ShowTimeScreen> createState() => _ShowTimeScreenState();
}

class _ShowTimeScreenState extends State<ShowTimeScreen> {
  late final Timer _screenTimer;

  DateTime _currentTime = DateTime.now();

  ShowTimerStatus _timerStatus = ShowTimerStatus.idle;

  DateTime? _currentRunStartedAt;
  Duration _completedRunTime = Duration.zero;
  Duration _showElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    _screenTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();

      setState(() {
        _currentTime = now;

        if (_timerStatus == ShowTimerStatus.running &&
            _currentRunStartedAt != null) {
          _showElapsed =
              _completedRunTime + now.difference(_currentRunStartedAt!);
        }
      });
    });
  }

  @override
  void dispose() {
    _screenTimer.cancel();
    super.dispose();
  }

  void _startShowTime() {
    setState(() {
      _completedRunTime = Duration.zero;
      _showElapsed = Duration.zero;
      _currentRunStartedAt = DateTime.now();
      _timerStatus = ShowTimerStatus.running;
    });
  }

  void _pauseShowTime() {
    if (_timerStatus != ShowTimerStatus.running ||
        _currentRunStartedAt == null) {
      return;
    }

    final now = DateTime.now();

    setState(() {
      _completedRunTime += now.difference(_currentRunStartedAt!);
      _showElapsed = _completedRunTime;
      _currentRunStartedAt = null;
      _timerStatus = ShowTimerStatus.paused;
    });
  }

  void _resumeShowTime() {
    if (_timerStatus != ShowTimerStatus.paused) {
      return;
    }

    setState(() {
      _currentRunStartedAt = DateTime.now();
      _timerStatus = ShowTimerStatus.running;
    });
  }

  void _resetShowTime() {
    setState(() {
      _timerStatus = ShowTimerStatus.idle;
      _currentRunStartedAt = null;
      _completedRunTime = Duration.zero;
      _showElapsed = Duration.zero;
    });
  }

  String _formatCurrentTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    final seconds = time.second.toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _formatElapsedTime(Duration duration) {
    final totalHours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final hoursText = totalHours.toString().padLeft(2, '0');
    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = seconds.toString().padLeft(2, '0');

    return '$hoursText:$minutesText:$secondsText';
  }

  String get _statusText {
    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        return 'READY';
      case ShowTimerStatus.running:
        return 'RUNNING';
      case ShowTimerStatus.paused:
        return 'PAUSED';
    }
  }

  Color get _statusColor {
    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        return Colors.green;
      case ShowTimerStatus.running:
        return Colors.greenAccent;
      case ShowTimerStatus.paused:
        return Colors.amber;
    }
  }

  Color get _showTimeColor {
    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        return Colors.white;
      case ShowTimerStatus.running:
        return Colors.greenAccent;
      case ShowTimerStatus.paused:
        return Colors.amber;
    }
  }

  double _clamp(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
  }

  Widget _buildStatusIndicator({required double fontSize}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              _statusText,
              key: ValueKey(_timerStatus),
              style: TextStyle(
                color: _statusColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainControl({
    required double width,
    required double height,
    required double fontSize,
  }) {
    Widget control;

    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        control = SizedBox(
          key: const ValueKey('idle-controls'),
          width: width,
          height: height,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            onPressed: _startShowTime,
            child: Text(
              'START',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        );

      case ShowTimerStatus.running:
        control = SizedBox(
          key: const ValueKey('running-controls'),
          width: width,
          height: height,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.zero,
            ),
            onPressed: _pauseShowTime,
            child: Text(
              'PAUSE',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
            ),
          ),
        );

      case ShowTimerStatus.paused:
        final smallButtonWidth = width * 0.72;

        control = Wrap(
          key: const ValueKey('paused-controls'),
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: smallButtonWidth,
              height: height,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                onPressed: _resumeShowTime,
                child: Text(
                  'RESUME',
                  style: TextStyle(
                    fontSize: fontSize * 0.82,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onLongPress: _resetShowTime,
                child: SizedBox(
                  width: smallButtonWidth,
                  height: height,
                  child: Center(
                    child: Text(
                      'RESET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize * 0.82,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: control,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final shortestSide = width < height ? width : height;

            final horizontalPadding = _clamp(width * 0.06, 16, 64);

            final brandFontSize = _clamp(shortestSide * 0.045, 15, 22);

            final statusFontSize = _clamp(shortestSide * 0.025, 10, 13);

            final labelFontSize = _clamp(shortestSide * 0.036, 13, 18);

            final currentTimeFontSize = _clamp(shortestSide * 0.115, 34, 56);

            final showTimeFontSize = _clamp(shortestSide * 0.125, 36, 60);

            final brandStatusGap = _clamp(height * 0.025, 10, 18);

            final largeGap = _clamp(height * 0.035, 14, 30);

            final sectionGap = _clamp(height * 0.06, 22, 52);

            final labelGap = _clamp(height * 0.018, 8, 16);

            final buttonTopGap = _clamp(height * 0.05, 18, 45);

            final buttonWidth = _clamp(width * 0.38, 160, 220);

            final buttonHeight = _clamp(height * 0.085, 48, 60);

            final buttonFontSize = _clamp(shortestSide * 0.048, 18, 24);

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SIGNAL FLOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: brandFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                    SizedBox(height: brandStatusGap),
                    _buildStatusIndicator(fontSize: statusFontSize),
                    SizedBox(height: largeGap),
                    Text(
                      'CURRENT TIME',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: labelFontSize,
                      ),
                    ),
                    SizedBox(height: labelGap),
                    SizedBox(
                      width: double.infinity,
                      height: currentTimeFontSize * 1.25,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatCurrentTime(_currentTime),
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: currentTimeFontSize,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Text(
                      'SHOW TIME',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: labelFontSize,
                      ),
                    ),
                    SizedBox(height: labelGap),
                    SizedBox(
                      width: double.infinity,
                      height: showTimeFontSize * 1.25,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: _showTimeColor,
                            fontSize: showTimeFontSize,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          child: Text(
                            _formatElapsedTime(_showElapsed),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: buttonTopGap),
                    _buildMainControl(
                      width: buttonWidth,
                      height: buttonHeight,
                      fontSize: buttonFontSize,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
