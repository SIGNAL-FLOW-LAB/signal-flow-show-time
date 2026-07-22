import 'dart:async';
import 'package:flutter/material.dart';

class CurrentTimeDisplay extends StatefulWidget {
  const CurrentTimeDisplay({
    super.key,
    required this.label,
    required this.showSeconds,
    required this.use24Hour,
    required this.labelFontSize,
    required this.timeFontSize,
    required this.labelGap,
  });

  final String label;
  final bool showSeconds;
  final bool use24Hour;
  final double labelFontSize;
  final double timeFontSize;
  final double labelGap;

  @override
  State<CurrentTimeDisplay> createState() => _CurrentTimeDisplayState();
}

class _CurrentTimeDisplayState extends State<CurrentTimeDisplay> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _startTimer();
  }

  @override
  void didUpdateWidget(CurrentTimeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSeconds != widget.showSeconds) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final interval = widget.showSeconds
        ? const Duration(milliseconds: 250)
        : const Duration(seconds: 1);
    _timer = Timer.periodic(interval, (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  String _format(DateTime time) {
    if (widget.use24Hour) {
      final hours = time.hour.toString().padLeft(2, '0');
      final minutes = time.minute.toString().padLeft(2, '0');
      if (!widget.showSeconds) {
        return '$hours:$minutes';
      }
      final seconds = time.second.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }

    final period = time.hour >= 12 ? 'PM' : 'AM';
    var displayHour = time.hour % 12;
    if (displayHour == 0) {
      displayHour = 12;
    }
    final hours = displayHour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    if (!widget.showSeconds) {
      return '$hours:$minutes $period';
    }
    final seconds = time.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds $period';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: widget.labelFontSize,
          ),
        ),
        SizedBox(height: widget.labelGap),
        SizedBox(
          width: double.infinity,
          height: widget.timeFontSize * 1.25,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _format(_now),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.timeFontSize,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
