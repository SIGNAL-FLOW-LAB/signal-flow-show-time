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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'SIGNAL FLOW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'CURRENT TIME',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                _formatCurrentTime(_currentTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 70),
              const Text(
                'SHOW TIME',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                _formatElapsedTime(_showElapsed),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 80),
              SizedBox(
                width: 220,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning
                        ? Colors.grey.shade800
                        : Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.white70,
                  ),
                  onPressed: _isRunning ? null : _startShowTime,
                  child: Text(
                    _isRunning ? 'RUNNING' : 'START',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
