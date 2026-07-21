import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktopPlatform) await windowManager.ensureInitialized();
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

class _ShowTimeScreenState extends State<ShowTimeScreen>
    with TickerProviderStateMixin {
  static const String _showTitleKey = 'show_title';
  static const String _alwaysOnTopKey = 'always_on_top';
  static const String _showCurrentTimeKey = 'show_current_time';
  static const String _showCurrentSecondsKey = 'show_current_seconds';
  static const String _use24HourKey = 'use_24_hour';

  static const Duration _controlHideDelay = Duration(milliseconds: 2500);
  static const Duration _resetHoldDuration = Duration(milliseconds: 1200);

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  late final Timer _screenTimer;
  late final AppLifecycleListener _lifecycleListener;
  late final AnimationController _resetProgressController;

  Timer? _controlHideTimer;
  DateTime _currentTime = DateTime.now();
  ShowTimerStatus _timerStatus = ShowTimerStatus.idle;
  DateTime? _currentRunStartedAt;
  Duration _completedRunTime = Duration.zero;
  Duration _showElapsed = Duration.zero;
  String _showTitle = '';
  bool _isEditingTitle = false;
  bool _isAlwaysOnTop = false;
  bool _showCurrentTime = true;
  bool _showCurrentSeconds = true;
  bool _use24Hour = true;
  bool _controlsVisible = true;
  bool _isHoldingReset = false;
  bool _pointerUpdateQueued = false;

  bool get _shouldShowMainControl =>
      _timerStatus != ShowTimerStatus.running || _controlsVisible;

  @override
  void initState() {
    super.initState();

    _resetProgressController = AnimationController(
      vsync: this,
      duration: _resetHoldDuration,
    );
    _resetProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHoldingReset) {
        _completeResetHold();
      }
    });

    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onShow: _handleAppResume,
    );

    _enableWakelock();
    unawaited(_loadSavedSettings());

    _screenTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = DateTime.now();
      if (!mounted) return;
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

  Future<void> _loadSavedSettings() async {
    final savedTitle = await _preferences.getString(_showTitleKey) ?? '';
    final savedAlwaysOnTop =
        await _preferences.getBool(_alwaysOnTopKey) ?? false;
    final savedShowCurrentTime =
        await _preferences.getBool(_showCurrentTimeKey) ?? true;
    final savedShowCurrentSeconds =
        await _preferences.getBool(_showCurrentSecondsKey) ?? true;
    final savedUse24Hour = await _preferences.getBool(_use24HourKey) ?? true;

    if (isDesktopPlatform) {
      await windowManager.setAlwaysOnTop(savedAlwaysOnTop);
    }
    if (!mounted) return;

    setState(() {
      _showTitle = savedTitle.trim();
      _titleController.text = _showTitle;
      _isAlwaysOnTop = savedAlwaysOnTop;
      _showCurrentTime = savedShowCurrentTime;
      _showCurrentSeconds = savedShowCurrentSeconds;
      _use24Hour = savedUse24Hour;
    });
  }

  void _enableWakelock() {
    if (!kIsWeb) unawaited(WakelockPlus.enable());
  }

  void _disableWakelock() {
    if (!kIsWeb) unawaited(WakelockPlus.disable());
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
    _controlHideTimer?.cancel();
    _resetProgressController.dispose();
    _lifecycleListener.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _disableWakelock();
    super.dispose();
  }

  void _beginTitleEditing() {
    _controlHideTimer?.cancel();
    _titleController.text = _showTitle;
    setState(() {
      _isEditingTitle = true;
      _controlsVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    if (_timerStatus == ShowTimerStatus.running) _showControlsTemporarily();
  }

  void _cancelTitleEditing() {
    _titleController.text = _showTitle;
    _titleFocusNode.unfocus();
    setState(() => _isEditingTitle = false);
    if (_timerStatus == ShowTimerStatus.running) _showControlsTemporarily();
  }

  void _startShowTime() {
    _controlHideTimer?.cancel();
    setState(() {
      _completedRunTime = Duration.zero;
      _showElapsed = Duration.zero;
      _currentRunStartedAt = DateTime.now();
      _timerStatus = ShowTimerStatus.running;
      _controlsVisible = true;
      _isHoldingReset = false;
    });
    _resetProgressController.reset();
    _scheduleControlHide();
  }

  void _pauseShowTime() {
    if (_timerStatus != ShowTimerStatus.running || _currentRunStartedAt == null)
      return;
    final now = DateTime.now();
    _controlHideTimer?.cancel();
    setState(() {
      _completedRunTime += now.difference(_currentRunStartedAt!);
      _showElapsed = _completedRunTime;
      _currentRunStartedAt = null;
      _timerStatus = ShowTimerStatus.paused;
      _controlsVisible = true;
      _isHoldingReset = false;
    });
    _resetProgressController.reset();
  }

  void _resumeShowTime() {
    if (_timerStatus != ShowTimerStatus.paused) return;
    _controlHideTimer?.cancel();
    setState(() {
      _currentRunStartedAt = DateTime.now();
      _timerStatus = ShowTimerStatus.running;
      _controlsVisible = true;
      _isHoldingReset = false;
    });
    _resetProgressController.reset();
    _scheduleControlHide();
  }

  void _resetShowTime() {
    _controlHideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _timerStatus = ShowTimerStatus.idle;
      _currentRunStartedAt = null;
      _completedRunTime = Duration.zero;
      _showElapsed = Duration.zero;
      _controlsVisible = true;
      _isHoldingReset = false;
    });
    _resetProgressController.reset();
  }

  void _showControlsTemporarily() {
    if (_timerStatus != ShowTimerStatus.running || _isEditingTitle) return;
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlHide();
  }

  void _scheduleControlHide() {
    _controlHideTimer?.cancel();
    if (_timerStatus != ShowTimerStatus.running || _isEditingTitle) return;
    _controlHideTimer = Timer(_controlHideDelay, () {
      if (!mounted ||
          _timerStatus != ShowTimerStatus.running ||
          _isEditingTitle)
        return;
      setState(() => _controlsVisible = false);
    });
  }

  void _queuePointerActivity() {
    if (_pointerUpdateQueued) return;
    _pointerUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pointerUpdateQueued = false;
      if (!mounted || _timerStatus != ShowTimerStatus.running) return;
      _showControlsTemporarily();
    });
  }

  void _startResetHold() {
    if (_timerStatus != ShowTimerStatus.paused) return;
    setState(() => _isHoldingReset = true);
    _resetProgressController.forward(from: 0);
  }

  void _cancelResetHold() {
    if (!_isHoldingReset && _resetProgressController.value == 0) return;
    if (mounted) {
      setState(() => _isHoldingReset = false);
    } else {
      _isHoldingReset = false;
    }
    _resetProgressController.animateBack(
      0,
      duration: const Duration(milliseconds: 160),
    );
  }

  void _completeResetHold() {
    if (!_isHoldingReset) return;
    _isHoldingReset = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetShowTime();
    });
  }

  Future<void> _toggleAlwaysOnTop() async {
    if (!isDesktopPlatform) return;
    final newValue = !_isAlwaysOnTop;
    await windowManager.setAlwaysOnTop(newValue);
    await _preferences.setBool(_alwaysOnTopKey, newValue);
    if (!mounted) return;
    setState(() => _isAlwaysOnTop = newValue);
  }

  Future<void> _setShowCurrentTime(bool value) async {
    setState(() => _showCurrentTime = value);
    await _preferences.setBool(_showCurrentTimeKey, value);
  }

  Future<void> _setShowCurrentSeconds(bool value) async {
    setState(() => _showCurrentSeconds = value);
    await _preferences.setBool(_showCurrentSecondsKey, value);
  }

  Future<void> _setUse24Hour(bool value) async {
    setState(() => _use24Hour = value);
    await _preferences.setBool(_use24HourKey, value);
  }

  void _openSettings() {
    _controlHideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, updateSheet) {
            Future<void> updateShowCurrentTime(bool value) async {
              await _setShowCurrentTime(value);
              if (sheetContext.mounted) updateSheet(() {});
            }

            Future<void> updateShowCurrentSeconds(bool value) async {
              await _setShowCurrentSeconds(value);
              if (sheetContext.mounted) updateSheet(() {});
            }

            Future<void> updateUse24Hour(bool value) async {
              await _setUse24Hour(value);
              if (sheetContext.mounted) updateSheet(() {});
            }

            Future<void> updateAlwaysOnTop(bool value) async {
              if (!isDesktopPlatform) return;
              await _toggleAlwaysOnTop();
              if (sheetContext.mounted) updateSheet(() {});
            }

            return SafeArea(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 620,
                  maxHeight: 650,
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
                      const Text(
                        '表示設定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSettingSwitch(
                        title: '現在時刻を表示',
                        subtitle: '公演用ストップウォッチの上に現在時刻を表示します',
                        value: _showCurrentTime,
                        onChanged: updateShowCurrentTime,
                      ),
                      const SizedBox(height: 8),
                      _buildSettingSwitch(
                        title: '現在時刻に秒を表示',
                        subtitle: 'OFFにすると「17:45」のように表示します',
                        value: _showCurrentSeconds,
                        enabled: _showCurrentTime,
                        onChanged: updateShowCurrentSeconds,
                      ),
                      const SizedBox(height: 8),
                      _buildSettingSwitch(
                        title: '24時間表記',
                        subtitle: _use24Hour
                            ? '17:45形式で表示します'
                            : '05:45 PM形式で表示します',
                        value: _use24Hour,
                        enabled: _showCurrentTime,
                        onChanged: updateUse24Hour,
                      ),
                      if (isDesktopPlatform) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: Colors.white24, height: 1),
                        ),
                        _buildSettingSwitch(
                          title: '常に最前面に表示',
                          subtitle: 'ほかのアプリを操作してもShow Timeを手前に残します',
                          value: _isAlwaysOnTop,
                          onChanged: updateAlwaysOnTop,
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF69F0AE),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text(
                            '閉じる',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (_timerStatus == ShowTimerStatus.running) {
        _showControlsTemporarily();
      }
    });
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
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
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrentTime(DateTime time) {
    if (_use24Hour) {
      final hours = time.hour.toString().padLeft(2, '0');
      final minutes = time.minute.toString().padLeft(2, '0');
      if (!_showCurrentSeconds) return '$hours:$minutes';
      final seconds = time.second.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }

    final period = time.hour >= 12 ? 'PM' : 'AM';
    var displayHour = time.hour % 12;
    if (displayHour == 0) displayHour = 12;
    final hours = displayHour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    if (!_showCurrentSeconds) return '$hours:$minutes $period';
    final seconds = time.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds $period';
  }

  String _formatElapsedTime(Duration duration) {
    final totalHours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${totalHours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Color get _showTimeColor {
    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        return Colors.white;
      case ShowTimerStatus.running:
        return const Color(0xFF69F0AE);
      case ShowTimerStatus.paused:
        return const Color(0xFFFFC107);
    }
  }

  double _clamp(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
  }

  Widget _buildTopRightControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '表示設定',
          child: IconButton(
            onPressed: _openSettings,
            iconSize: 23,
            splashRadius: 22,
            color: Colors.white54,
            icon: const Icon(Icons.settings_outlined),
          ),
        ),
        if (isDesktopPlatform)
          Tooltip(
            message: _isAlwaysOnTop ? '最前面固定を解除' : '常に最前面に固定',
            child: IconButton(
              onPressed: _toggleAlwaysOnTop,
              iconSize: 23,
              splashRadius: 22,
              color: _isAlwaysOnTop ? const Color(0xFF69F0AE) : Colors.white38,
              icon: Icon(
                _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShowTitle({
    required double fontSize,
    required double availableWidth,
  }) {
    if (_isEditingTitle) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: availableWidth),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                maxLines: 2,
                minLines: 1,
                maxLength: 80,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: 0.4,
                ),
                decoration: InputDecoration(
                  hintText: '公演名・会場名・開演時刻など',
                  hintStyle: TextStyle(
                    color: Colors.white38,
                    fontSize: fontSize * 0.76,
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
                onSubmitted: (_) => unawaited(_saveShowTitle()),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '保存',
              onPressed: _saveShowTitle,
              icon: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF69F0AE),
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
          constraints: BoxConstraints(minHeight: 48, maxWidth: availableWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      height: 1.18,
                      letterSpacing: 0.4,
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

  Widget _buildHoldResetButton({
    required double width,
    required double height,
    required double fontSize,
  }) {
    final radius = BorderRadius.circular(height / 2);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startResetHold(),
      onTapUp: (_) => _cancelResetHold(),
      onTapCancel: _cancelResetHold,
      child: AnimatedBuilder(
        animation: _resetProgressController,
        builder: (context, child) {
          final progress = _resetProgressController.value;
          return SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.red.shade800),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1,
                      child: ColoredBox(color: Colors.redAccent.shade200),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: _isHoldingReset
                            ? Colors.white70
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      _isHoldingReset ? 'HOLD' : 'RESET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize * 0.82,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainControl({
    required double width,
    required double height,
    required double fontSize,
  }) {
    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        return SizedBox(
          key: const ValueKey('idle-controls'),
          width: width,
          height: height,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            onPressed: _startShowTime,
            child: Text(
              'START',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        );

      case ShowTimerStatus.running:
        return SizedBox(
          key: const ValueKey('running-controls'),
          width: width,
          height: height,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            onPressed: _pauseShowTime,
            child: Text(
              'PAUSE',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
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
            const SizedBox(width: 12),
            _buildHoldResetButton(
              width: availableButtonWidth,
              height: height,
              fontSize: fontSize,
            ),
          ],
        );
    }
  }

  Widget _buildAnimatedMainControl({
    required double width,
    required double height,
    required double fontSize,
  }) {
    final showControl = _shouldShowMainControl;
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: showControl ? height : 0,
        child: ClipRect(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: showControl ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showControl,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildMainControl(
                  width: width,
                  height: height,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => _queuePointerActivity(),
        onHover: (_) => _queuePointerActivity(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _queuePointerActivity(),
          child: Stack(
            children: [
              SafeArea(
                minimum: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final keyboardHeight = MediaQuery.viewInsetsOf(
                      context,
                    ).bottom;
                    final isKeyboardVisible = keyboardHeight > 0;
                    final isNarrow = width < 600;
                    final isCompactHeight = height < 600;
                    final isLargeDesktop = width >= 1100 && height >= 700;
                    final isVeryLargeDesktop = width >= 1400 && height >= 850;
                    final shortestSide = width < height ? width : height;

                    final horizontalPadding = _clamp(
                      width * (isNarrow ? 0.045 : 0.06),
                      12,
                      80,
                    );
                    final verticalPadding = isCompactHeight ? 6.0 : 12.0;
                    final titleWidth = width - (horizontalPadding * 2);

                    final titleFontSize = isCompactHeight
                        ? _clamp(shortestSide * 0.045, 15, 22)
                        : isNarrow
                        ? _clamp(width * 0.052, 17, 25)
                        : _clamp(width * 0.032, 20, 42);

                    final labelFontSize = isCompactHeight
                        ? _clamp(shortestSide * 0.034, 11, 16)
                        : isNarrow
                        ? _clamp(width * 0.036, 12, 18)
                        : _clamp(width * 0.020, 14, 28);

                    final currentTimeFontSize = isCompactHeight
                        ? _clamp(shortestSide * 0.135, 34, 54)
                        : isNarrow
                        ? _clamp(width * 0.13, 42, 66)
                        : _clamp(width * 0.10, 56, 122);

                    double showTimeScale = 1;
                    if (isLargeDesktop) showTimeScale *= 1.10;
                    if (isVeryLargeDesktop) showTimeScale *= 1.08;
                    if (_timerStatus == ShowTimerStatus.running &&
                        !_shouldShowMainControl) {
                      showTimeScale *= isNarrow ? 1.08 : 1.16;
                    }

                    final baseShowTimeFontSize = isCompactHeight
                        ? _clamp(shortestSide * 0.16, 38, 66)
                        : isNarrow
                        ? _clamp(width * 0.16, 48, 82)
                        : _clamp(width * 0.135, 68, 165);

                    final showTimeFontSize = _clamp(
                      baseShowTimeFontSize * showTimeScale,
                      38,
                      isVeryLargeDesktop ? 220 : 190,
                    );

                    final titleGap = _clamp(
                      height * (isCompactHeight ? 0.014 : 0.028),
                      6,
                      26,
                    );
                    final sectionGap = _clamp(
                      height * (isCompactHeight ? 0.025 : 0.045),
                      10,
                      44,
                    );
                    final labelGap = _clamp(height * 0.012, 5, 14);
                    final buttonTopGap =
                        _timerStatus == ShowTimerStatus.running &&
                            !_shouldShowMainControl
                        ? _clamp(height * 0.012, 4, 14)
                        : _clamp(
                            height * (isCompactHeight ? 0.022 : 0.038),
                            9,
                            38,
                          );
                    final buttonWidth = isCompactHeight
                        ? _clamp(width * 0.30, 140, 220)
                        : isNarrow
                        ? _clamp(width * 0.55, 170, 240)
                        : _clamp(width * 0.30, 210, 360);
                    final buttonHeight = isCompactHeight
                        ? _clamp(height * 0.13, 44, 54)
                        : _clamp(height * 0.085, 50, 82);
                    final buttonFontSize = isCompactHeight
                        ? _clamp(shortestSide * 0.048, 16, 21)
                        : isNarrow
                        ? _clamp(width * 0.048, 18, 25)
                        : _clamp(width * 0.026, 21, 34);
                    final contentMinHeight = isKeyboardVisible
                        ? 0.0
                        : height - (verticalPadding * 2);

                    return AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
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
                            minHeight: contentMinHeight < 0
                                ? 0
                                : contentMinHeight,
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
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                child: _showCurrentTime
                                    ? Column(
                                        children: [
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
                                                _formatCurrentTime(
                                                  _currentTime,
                                                ),
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
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Text(
                                'SHOW TIME',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: labelFontSize,
                                ),
                              ),
                              SizedBox(height: labelGap),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: double.infinity,
                                height: showTimeFontSize * 1.24,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
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
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                height: buttonTopGap,
                              ),
                              _buildAnimatedMainControl(
                                width: buttonWidth,
                                height: buttonHeight,
                                fontSize: buttonFontSize,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildTopRightControls(),
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
