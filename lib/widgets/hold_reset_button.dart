import 'package:flutter/material.dart';

class HoldResetButton extends StatefulWidget {
  const HoldResetButton({
    super.key,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onReset,
    this.holdDuration = const Duration(milliseconds: 1200),
  });

  final double width;
  final double height;
  final double fontSize;
  final VoidCallback onReset;
  final Duration holdDuration;

  @override
  State<HoldResetButton> createState() => _HoldResetButtonState();
}

class _HoldResetButtonState extends State<HoldResetButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _progressController.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant HoldResetButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.holdDuration != widget.holdDuration) {
      _progressController.duration = widget.holdDuration;
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isHolding) {
      return;
    }

    setState(() {
      _isHolding = false;
    });

    _progressController.value = 0;
    widget.onReset();
  }

  void _startHold(TapDownDetails details) {
    if (_isHolding) {
      return;
    }

    setState(() {
      _isHolding = true;
    });

    _progressController.forward(from: 0);
  }

  void _cancelHold() {
    if (!_isHolding && _progressController.value == 0) {
      return;
    }

    if (mounted) {
      setState(() {
        _isHolding = false;
      });
    }

    _progressController.animateBack(
      0,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _progressController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.height / 2);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _startHold,
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            final progress = _progressController.value;

            return ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.red.shade800),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.width * progress,
                    child: ColoredBox(color: Colors.redAccent.shade200),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: _isHolding ? Colors.white70 : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isHolding ? 'HOLD' : 'RESET',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.fontSize * 0.82,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
