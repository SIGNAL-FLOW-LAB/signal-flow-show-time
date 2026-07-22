import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'widgets/settings_sheet.dart';
import 'widgets/show_title.dart';

bool get isDesktopPlatform {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

bool get isMacOSPlatform {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
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
  static const String _languageKey = 'display_language';

  static const Duration _controlHideDelay = Duration(milliseconds: 2500);
  static const Duration _resetHoldDuration = Duration(milliseconds: 1200);

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();

  late final Timer _screenTimer;
  late final AppLifecycleListener _lifecycleListener;
  late final AnimationController _resetProgressController;

  Timer? _controlHideTimer;

  DateTime _currentTime = DateTime.now();
  Offset? _lastPointerPosition;

  ShowTimerStatus _timerStatus = ShowTimerStatus.idle;

  DateTime? _currentRunStartedAt;
  Duration _completedRunTime = Duration.zero;
  Duration _showElapsed = Duration.zero;

  String _showTitle = '';
  bool _isEditingTitle = false;
  bool _isSettingsOpen = false;

  bool _isAlwaysOnTop = false;
  bool _showCurrentTime = true;
  bool _showCurrentSeconds = true;
  bool _use24Hour = true;

  AppLanguage _language = AppLanguage.japanese;

  bool _controlsVisible = true;
  bool _isHoldingReset = false;

  @override
  void initState() {
    super.initState();

    _resetProgressController = AnimationController(
      vsync: this,
      duration: _resetHoldDuration,
    );

    _resetProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHoldingReset) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isHoldingReset) {
            _completeResetHold();
          }
        });
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

  Future<void> _loadSavedSettings() async {
    final savedTitle = await _preferences.getString(_showTitleKey) ?? '';
    final savedAlwaysOnTop =
        await _preferences.getBool(_alwaysOnTopKey) ?? false;
    final savedShowCurrentTime =
        await _preferences.getBool(_showCurrentTimeKey) ?? true;
    final savedShowCurrentSeconds =
        await _preferences.getBool(_showCurrentSecondsKey) ?? true;
    final savedUse24Hour = await _preferences.getBool(_use24HourKey) ?? true;
    final savedLanguage = await _preferences.getString(_languageKey) ?? 'ja';

    if (isDesktopPlatform) {
      await windowManager.setAlwaysOnTop(savedAlwaysOnTop);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showTitle = savedTitle.trim();
      _titleController.text = _showTitle;

      _isAlwaysOnTop = savedAlwaysOnTop;
      _showCurrentTime = savedShowCurrentTime;
      _showCurrentSeconds = savedShowCurrentSeconds;
      _use24Hour = savedUse24Hour;
      _language = savedLanguage == 'en'
          ? AppLanguage.english
          : AppLanguage.japanese;
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

    _lastPointerPosition = null;
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
    _shortcutFocusNode.dispose();

    _disableWakelock();

    super.dispose();
  }

  String _t(String japanese, String english) {
    return _language == AppLanguage.japanese ? japanese : english;
  }

  // ---------------------------------------------------------------------------
  // タイトル
  // ---------------------------------------------------------------------------

  void _beginTitleEditing() {
    _controlHideTimer?.cancel();
    _titleController.text = _showTitle;

    setState(() {
      _isEditingTitle = true;
      _controlsVisible = true;
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
    _shortcutFocusNode.requestFocus();

    if (newTitle.isEmpty) {
      await _preferences.remove(_showTitleKey);
    } else {
      await _preferences.setString(_showTitleKey, newTitle);
    }

    if (_timerStatus == ShowTimerStatus.running) {
      _showControlsTemporarily();
    }
  }

  void _cancelTitleEditing() {
    _titleController.text = _showTitle;
    _titleFocusNode.unfocus();

    setState(() {
      _isEditingTitle = false;
    });

    _shortcutFocusNode.requestFocus();

    if (_timerStatus == ShowTimerStatus.running) {
      _showControlsTemporarily();
    }
  }

  // ---------------------------------------------------------------------------
  // ストップウォッチ
  // ---------------------------------------------------------------------------

  void _startShowTime() {
    setState(() {
      _completedRunTime = Duration.zero;
      _showElapsed = Duration.zero;
      _currentRunStartedAt = DateTime.now();
      _timerStatus = ShowTimerStatus.running;
      _controlsVisible = true;
    });

    _scheduleControlHide();
  }

  void _pauseShowTime() {
    if (_timerStatus != ShowTimerStatus.running ||
        _currentRunStartedAt == null) {
      return;
    }

    final now = DateTime.now();
    _controlHideTimer?.cancel();

    setState(() {
      _completedRunTime += now.difference(_currentRunStartedAt!);
      _showElapsed = _completedRunTime;
      _currentRunStartedAt = null;
      _timerStatus = ShowTimerStatus.paused;
      _controlsVisible = true;
    });
  }

  void _resumeShowTime() {
    if (_timerStatus != ShowTimerStatus.paused) {
      return;
    }

    setState(() {
      _currentRunStartedAt = DateTime.now();
      _timerStatus = ShowTimerStatus.running;
      _controlsVisible = true;
    });

    _scheduleControlHide();
  }

  void _resetShowTime() {
    _controlHideTimer?.cancel();
    _resetProgressController.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _timerStatus = ShowTimerStatus.idle;
      _currentRunStartedAt = null;
      _completedRunTime = Duration.zero;
      _showElapsed = Duration.zero;
      _controlsVisible = true;
      _isHoldingReset = false;
    });

    _resetProgressController.value = 0;
  }

  void _handlePrimaryShortcut() {
    if (_isEditingTitle || _isSettingsOpen) {
      return;
    }

    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        _startShowTime();
        return;
      case ShowTimerStatus.running:
        _pauseShowTime();
        return;
      case ShowTimerStatus.paused:
        _resumeShowTime();
        return;
    }
  }

  String get _primaryActionLabel {
    switch (_timerStatus) {
      case ShowTimerStatus.idle:
        return 'Start';
      case ShowTimerStatus.running:
        return 'Pause';
      case ShowTimerStatus.paused:
        return 'Resume';
    }
  }

  // ---------------------------------------------------------------------------
  // 操作ボタンの自動非表示
  // ---------------------------------------------------------------------------

  void _showControlsTemporarily() {
    if (_timerStatus != ShowTimerStatus.running || _isEditingTitle) {
      return;
    }

    if (!_controlsVisible && mounted) {
      setState(() {
        _controlsVisible = true;
      });
    }

    _scheduleControlHide();
  }

  void _scheduleControlHide() {
    _controlHideTimer?.cancel();

    if (_timerStatus != ShowTimerStatus.running || _isEditingTitle) {
      return;
    }

    _controlHideTimer = Timer(_controlHideDelay, () {
      if (!mounted ||
          _timerStatus != ShowTimerStatus.running ||
          _isEditingTitle) {
        return;
      }

      setState(() {
        _controlsVisible = false;
      });
    });
  }

  void _handlePointerHover(PointerHoverEvent event) {
    final previous = _lastPointerPosition;
    _lastPointerPosition = event.position;

    if (previous == null) {
      return;
    }

    if ((event.position - previous).distance < 2) {
      return;
    }

    _showControlsTemporarily();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _lastPointerPosition = event.position;
    _showControlsTemporarily();
    _shortcutFocusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // RESET長押し
  // ---------------------------------------------------------------------------

  void _startResetHold() {
    if (_timerStatus != ShowTimerStatus.paused) {
      return;
    }

    setState(() {
      _isHoldingReset = true;
    });

    _resetProgressController.forward(from: 0);
  }

  void _cancelResetHold() {
    if (!_isHoldingReset && _resetProgressController.value == 0) {
      return;
    }

    if (mounted) {
      setState(() {
        _isHoldingReset = false;
      });
    }

    _resetProgressController.animateBack(
      0,
      duration: const Duration(milliseconds: 160),
    );
  }

  void _completeResetHold() {
    if (!_isHoldingReset) {
      return;
    }

    _resetShowTime();
  }

  // ---------------------------------------------------------------------------
  // 設定
  // ---------------------------------------------------------------------------

  Future<void> _toggleAlwaysOnTop() async {
    if (!isDesktopPlatform) {
      return;
    }

    final newValue = !_isAlwaysOnTop;

    await windowManager.setAlwaysOnTop(newValue);
    await _preferences.setBool(_alwaysOnTopKey, newValue);

    if (!mounted) {
      return;
    }

    setState(() {
      _isAlwaysOnTop = newValue;
    });
  }

  Future<void> _setShowCurrentTime(bool value) async {
    setState(() {
      _showCurrentTime = value;
    });

    await _preferences.setBool(_showCurrentTimeKey, value);
  }

  Future<void> _setShowCurrentSeconds(bool value) async {
    setState(() {
      _showCurrentSeconds = value;
    });

    await _preferences.setBool(_showCurrentSecondsKey, value);
  }

  Future<void> _setUse24Hour(bool value) async {
    setState(() {
      _use24Hour = value;
    });

    await _preferences.setBool(_use24HourKey, value);
  }

  Future<void> _setLanguage(AppLanguage value) async {
    setState(() {
      _language = value;
    });

    await _preferences.setString(
      _languageKey,
      value == AppLanguage.english ? 'en' : 'ja',
    );
  }

  void _openSettings() {
    if (_isSettingsOpen) {
      return;
    }

    _controlHideTimer?.cancel();

    setState(() {
      _isSettingsOpen = true;
      _controlsVisible = true;
    });

    showSettingsSheet(
      context: context,
      language: _language,
      showCurrentTime: _showCurrentTime,
      showCurrentSeconds: _showCurrentSeconds,
      use24Hour: _use24Hour,
      isAlwaysOnTop: _isAlwaysOnTop,
      showAlwaysOnTopOption: isDesktopPlatform,
      onLanguageChanged: _setLanguage,
      onShowCurrentTimeChanged: _setShowCurrentTime,
      onShowCurrentSecondsChanged: _setShowCurrentSeconds,
      onUse24HourChanged: _setUse24Hour,
      onAlwaysOnTopChanged: (value) async {
        if (value != _isAlwaysOnTop) {
          await _toggleAlwaysOnTop();
        }
      },
    ).whenComplete(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSettingsOpen = false;
      });

      _shortcutFocusNode.requestFocus();

      if (_timerStatus == ShowTimerStatus.running) {
        _scheduleControlHide();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 表示フォーマット
  // ---------------------------------------------------------------------------

  String _formatCurrentTime(DateTime time) {
    if (_use24Hour) {
      final hours = time.hour.toString().padLeft(2, '0');
      final minutes = time.minute.toString().padLeft(2, '0');

      if (!_showCurrentSeconds) {
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

    if (!_showCurrentSeconds) {
      return '$hours:$minutes $period';
    }

    final seconds = time.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds $period';
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
        return const Color(0xFF69F0AE);
      case ShowTimerStatus.paused:
        return const Color(0xFFFFC107);
    }
  }

  double _clamp(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
  }

  // ---------------------------------------------------------------------------
  // macOSメニュー
  // ---------------------------------------------------------------------------

  Widget _buildPlatformMenu(Widget child) {
    if (!isMacOSPlatform) {
      return child;
    }

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Show Time',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: _primaryActionLabel,
                  shortcut: const SingleActivator(LogicalKeyboardKey.space),
                  onSelected: _handlePrimaryShortcut,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: _t('表示設定…', 'Display Settings…'),
                  onSelected: _openSettings,
                ),
                PlatformMenuItem(
                  label: _isAlwaysOnTop
                      ? _t('✓ 常に最前面に表示', '✓ Always on Top')
                      : _t('常に最前面に表示', 'Always on Top'),
                  onSelected: _toggleAlwaysOnTop,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // 上部アイコン
  // ---------------------------------------------------------------------------

  Widget _buildTopRightControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _t('表示設定', 'Display Settings'),
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
            message: _isAlwaysOnTop
                ? _t('最前面固定を解除', 'Disable Always on Top')
                : _t('常に最前面に固定', 'Enable Always on Top'),
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

  // ---------------------------------------------------------------------------
  // 公演タイトル
  // ---------------------------------------------------------------------------

  Widget _buildShowTitle({
    required double fontSize,
    required double availableWidth,
  }) {
    return ShowTitle(
      title: _showTitle,
      isEditing: _isEditingTitle,
      fontSize: fontSize,
      availableWidth: availableWidth,
      titleController: _titleController,
      titleFocusNode: _titleFocusNode,
      emptyTitleLabel: _t('公演タイトルを入力', 'Enter Show Title'),
      editTitleLabel: _t('公演タイトルを編集', 'Edit Show Title'),
      hintText: _t('公演名・会場名・開演時刻など', 'Show name, venue, show time, etc.'),
      saveLabel: _t('保存', 'Save'),
      cancelLabel: _t('キャンセル', 'Cancel'),
      onBeginEditing: _beginTitleEditing,
      onSave: _saveShowTitle,
      onCancel: _cancelTitleEditing,
    );
  }

  // ---------------------------------------------------------------------------
  // RESET背景充填ボタン
  // ---------------------------------------------------------------------------

  Widget _buildHoldResetButton({
    required double width,
    required double height,
    required double fontSize,
  }) {
    final radius = BorderRadius.circular(height / 2);

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startResetHold(),
        onTapUp: (_) => _cancelResetHold(),
        onTapCancel: _cancelResetHold,
        child: AnimatedBuilder(
          animation: _resetProgressController,
          builder: (context, child) {
            final progress = _resetProgressController.value;

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
                    width: width * progress,
                    child: ColoredBox(color: Colors.redAccent.shade200),
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
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 操作ボタン
  // ---------------------------------------------------------------------------

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
        return AnimatedOpacity(
          key: const ValueKey('running-controls'),
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: SizedBox(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                onPressed: _resumeShowTime,
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
            _buildHoldResetButton(
              width: availableButtonWidth,
              height: height,
              fontSize: fontSize,
            ),
          ],
        );
    }
  }

  // ---------------------------------------------------------------------------
  // メイン画面
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onHover: _handlePointerHover,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
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

                    if (isLargeDesktop) {
                      showTimeScale *= 1.10;
                    }

                    if (isVeryLargeDesktop) {
                      showTimeScale *= 1.08;
                    }

                    final baseShowTimeFontSize = isCompactHeight
                        ? _clamp(shortestSide * 0.16, 38, 66)
                        : isNarrow
                        ? _clamp(width * 0.16, 48, 82)
                        : _clamp(width * 0.135, 68, 165);

                    // v0.16:
                    // PAUSEボタンの表示・非表示に関係なく、
                    // カウンターは常に同じ大きさを維持します。
                    final showTimeFontSize = _clamp(
                      baseShowTimeFontSize * showTimeScale * 1.12,
                      38,
                      isVeryLargeDesktop ? 230 : 200,
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

                    final buttonTopGap = _clamp(
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
                                            _t('現在時刻', 'CURRENT TIME'),
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
                                _t('公演時間', 'SHOW TIME'),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: labelFontSize,
                                ),
                              ),

                              SizedBox(height: labelGap),

                              SizedBox(
                                width: double.infinity,
                                height: showTimeFontSize * 1.24,
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

                              // 固定領域を確保するため、PAUSEが消えても
                              // カウンター位置とサイズは変化しません。
                              SizedBox(
                                width: buttonWidth,
                                height: buttonHeight,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _buildMainControl(
                                    width: buttonWidth,
                                    height: buttonHeight,
                                    fontSize: buttonFontSize,
                                  ),
                                ),
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

    final shortcutLayer = CallbackShortcuts(
      bindings: _isEditingTitle
          ? const <ShortcutActivator, VoidCallback>{}
          : <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.space):
                  _handlePrimaryShortcut,
            },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: scaffold,
      ),
    );

    return _buildPlatformMenu(shortcutLayer);
  }
}
