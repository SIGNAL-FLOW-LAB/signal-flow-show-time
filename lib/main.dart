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

class ShowTimeScreen extends StatefulWidget {
  const ShowTimeScreen({super.key});

  @override
  State<ShowTimeScreen> createState() => _ShowTimeScreenState();
}

class _ShowTimeScreenState extends State<ShowTimeScreen> {
  late final Timer _screenTimer;

  DateTime _currentTime = DateTime.now();
  DateTime? _showStartedAt;

  Duration _showElapsed = Duration.zero;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();

    _screenTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();

      setState(() {
        _currentTime = now;

        if (_isRunning && _showStartedAt != null) {
          _showElapsed = now.difference(_showStartedAt!);
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
    if (_isRunning) {
      return;
    }

    final now = DateTime.now();

    setState(() {
      _showStartedAt = now;
      _showElapsed = Duration.zero;
      _isRunning = true;
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

  double _clamp(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
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

            final labelFontSize = _clamp(shortestSide * 0.036, 13, 18);

            final currentTimeFontSize = _clamp(shortestSide * 0.115, 34, 56);

            final showTimeFontSize = _clamp(shortestSide * 0.125, 36, 60);

            final largeGap = _clamp(height * 0.075, 22, 60);

            final sectionGap = _clamp(height * 0.085, 26, 70);

            final labelGap = _clamp(height * 0.02, 8, 16);

            final buttonTopGap = _clamp(height * 0.085, 26, 80);

            final buttonWidth = _clamp(width * 0.38, 160, 220);

            final buttonHeight = _clamp(height * 0.09, 48, 60);

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
                        alignment: Alignment.center,
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
                        alignment: Alignment.center,
                        child: Text(
                          _formatElapsedTime(_showElapsed),
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: showTimeFontSize,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: buttonTopGap),
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning
                              ? Colors.grey.shade800
                              : Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade800,
                          disabledForegroundColor: Colors.white70,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _isRunning ? null : _startShowTime,
                        child: Text(
                          _isRunning ? 'RUNNING' : 'START',
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
