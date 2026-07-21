import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  static const String _showTitleKey = 'show_title';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  late final Timer _screenTimer;
  late final AppLifecycleListener _lifecycleListener;

  DateTime _currentTime = DateTime.now();

  ShowTimerStatus _timerStatus = ShowTimerStatus.idle;

  DateTime? _currentRunStartedAt;
  Duration _completedRunTime = Duration.zero;
  Duration _showElapsed = Duration.zero;

  String _showTitle = '';
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();

    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onShow: _handleAppResume,
    );

    _enableWakelock();

    _loadShowTitle();

    _screenTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();

      if (!mounted) {
        return;
      }

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

  void _enableWakelock() {
    if (kIsWeb) {
      return;
    }

    unawaited(WakelockPlus.enable());
  }

  void _disableWakelock() {
    if (kIsWeb) {
      return;
    }

    unawaited(WakelockPlus.disable());
  }

  void _handleAppResume() {
    final now = DateTime.now();

    if (mounted) {
      setState(() {
        _currentTime = now;

        if (_timerStatus == ShowTimerStatus.running &&
            _currentRunStartedAt != null) {
          _showElapsed =
              _completedRunTime + now.difference(_currentRunStartedAt!);
        }
      });
    }

    _enableWakelock();
  }

  @override
  void dispose() {
    _screenTimer.cancel();
    _lifecycleListener.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();

    _disableWakelock();

    super.dispose();
  }

  Future<void> _loadShowTitle() async {
    final savedTitle = await _preferences.getString(_showTitleKey) ?? '';

    if (!mounted) {
      return;
    }

    setState(() {
      _showTitle = savedTitle.trim();
      _titleController.text = _showTitle;
    });
  }

  void _beginTitleEditing() {
    _titleController.text = _showTitle;

    setState(() {
      _isEditingTitle = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _titleFocusNode.requestFocus();

      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    });
  }

  Future<void> _saveShowTitle() async {
    final newTitle = _titleController.text.trim();

    setState(() {
      _showTitle = newTitle;
      _isEditingTitle = false;
    });

    _titleFocusNode.unfocus();

    if (newTitle.isEmpty) {
      await _preferences.remove(_showTitleKey);
    } else {
      await _preferences.setString(_showTitleKey, newTitle);
    }
  }

  void _cancelTitleEditing() {
    _titleController.text = _showTitle;
    _titleFocusNode.unfocus();

    setState(() {
      _isEditingTitle = false;
    });
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

  Widget _buildShowTitle({
    required double fontSize,
    required double availableWidth,
  }) {
    if (_isEditingTitle) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: availableWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                maxLines: 2,
                minLines: 1,
                maxLength: 60,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0.6,
                ),
                decoration: InputDecoration(
                  hintText: '公演名・会場名・開演時刻など',
                  hintStyle: TextStyle(
                    color: Colors.white38,
                    fontSize: fontSize * 0.78,
                    fontWeight: FontWeight.w400,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.white70,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _saveShowTitle(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '保存',
              onPressed: _saveShowTitle,
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
            ),
            IconButton(
              tooltip: 'キャンセル',
              onPressed: _cancelTitleEditing,
              icon: const Icon(Icons.close, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: _showTitle.isEmpty ? '公演タイトルを入力' : '公演タイトルを編集',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _beginTitleEditing,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 58, maxWidth: availableWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _showTitle.isEmpty ? '公演タイトルを入力' : _showTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _showTitle.isEmpty ? Colors.white38 : Colors.white,
                      fontSize: _showTitle.isEmpty ? fontSize * 0.72 : fontSize,
                      fontWeight: _showTitle.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: Colors.white30,
                ),
              ],
            ),
          ),
        ),
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
      child: control,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // スマートフォンでキーボードが出た際に
      // 画面サイズを自動調整します。
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        minimum: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            // 画面キーボードによって隠れている高さです。
            final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

            // キーボードが表示されているかどうか。
            final isKeyboardVisible = keyboardHeight > 0;

            // 端末名ではなく、実際の表示領域で判定します。
            final isNarrow = width < 600;
            final isCompactHeight = height < 600;

            final shortestSide = width < height ? width : height;

            final horizontalPadding = _clamp(
              width * (isNarrow ? 0.045 : 0.06),
              12,
              64,
            );

            final verticalPadding = isCompactHeight ? 6.0 : 12.0;

            final titleWidth = width - (horizontalPadding * 2);

            // 高さが600未満の横長画面では、縦方向の収まりを優先します。
            final titleFontSize = isCompactHeight
                ? _clamp(shortestSide * 0.045, 15, 21)
                : isNarrow
                ? _clamp(width * 0.052, 17, 24)
                : _clamp(width * 0.032, 20, 40);

            final labelFontSize = isCompactHeight
                ? _clamp(shortestSide * 0.034, 11, 15)
                : isNarrow
                ? _clamp(width * 0.036, 12, 17)
                : _clamp(width * 0.020, 14, 26);

            final currentTimeFontSize = isCompactHeight
                ? _clamp(shortestSide * 0.135, 34, 52)
                : isNarrow
                ? _clamp(width * 0.13, 42, 62)
                : _clamp(width * 0.10, 56, 110);

            final showTimeFontSize = isCompactHeight
                ? _clamp(shortestSide * 0.16, 38, 62)
                : isNarrow
                ? _clamp(width * 0.16, 48, 76)
                : _clamp(width * 0.135, 68, 150);

            final titleGap = _clamp(
              height * (isCompactHeight ? 0.018 : 0.035),
              8,
              28,
            );

            final sectionGap = _clamp(
              height * (isCompactHeight ? 0.03 : 0.055),
              12,
              48,
            );

            final labelGap = _clamp(height * 0.014, 6, 14);

            final buttonTopGap = _clamp(
              height * (isCompactHeight ? 0.025 : 0.045),
              10,
              42,
            );

            final buttonWidth = isCompactHeight
                ? _clamp(width * 0.30, 140, 210)
                : isNarrow
                ? _clamp(width * 0.55, 170, 230)
                : _clamp(width * 0.30, 210, 340);

            final buttonHeight = isCompactHeight
                ? _clamp(height * 0.13, 44, 52)
                : _clamp(height * 0.085, 50, 78);

            final buttonFontSize = isCompactHeight
                ? _clamp(shortestSide * 0.048, 16, 20)
                : isNarrow
                ? _clamp(width * 0.048, 18, 24)
                : _clamp(width * 0.026, 21, 32);

            // キーボード表示時はタイトル編集を優先して、
            // 時計部分の余白を小さくします。
            final contentMinHeight = isKeyboardVisible
                ? 0.0
                : height - (verticalPadding * 2);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: verticalPadding,
                bottom: verticalPadding,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,

                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: contentMinHeight < 0 ? 0 : contentMinHeight,
                  ),

                  child: Column(
                    mainAxisAlignment: isKeyboardVisible
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      _buildShowTitle(
                        fontSize: titleFontSize,
                        availableWidth: titleWidth,
                      ),

                      SizedBox(height: titleGap),

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
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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

                      // iPhoneのホームインジケーター付近に
                      // ボタンが密着しないための余白です。
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
