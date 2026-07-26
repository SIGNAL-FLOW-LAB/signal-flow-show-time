import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/show_time_menu_controller.dart';
import '../controllers/show_timer_controller.dart';
import '../models/app_language.dart';
import '../models/show_timer_status.dart';
import '../platform/platform_support.dart';
import '../services/settings_service.dart';
import '../widgets/about_dialog.dart';
import '../widgets/current_time_display.dart';
import '../widgets/hold_reset_button.dart';
import '../widgets/main_controls.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/show_elapsed_display.dart';
import '../widgets/show_title.dart';

class ShowTimeScreen extends StatefulWidget {
  const ShowTimeScreen({super.key, required this.menuController});

  final ShowTimeMenuController menuController;

  @override
  State<ShowTimeScreen> createState() => _ShowTimeScreenState();
}

class _ShowTimeScreenState extends State<ShowTimeScreen> {
  static const Duration _controlHideDelay = Duration(milliseconds: 2500);

  final SettingsService _settingsService = SettingsService();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();

  late final ShowTimerController _timerController;
  late final AppLifecycleListener _lifecycleListener;

  Timer? _controlHideTimer;

  Offset? _lastPointerPosition;

  String _showTitle = '';
  bool _isEditingTitle = false;
  bool _isSettingsOpen = false;
  bool _isAboutOpen = false;

  bool _isAlwaysOnTop = false;
  bool _showCurrentTime = true;
  bool _showCurrentSeconds = true;
  bool _use24Hour = true;

  AppLanguage _language = AppLanguage.japanese;

  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();

    widget.menuController.openSettings = _openSettings;
    widget.menuController.openAbout = _openAbout;
    widget.menuController.toggleAlwaysOnTop = () {
      unawaited(_toggleAlwaysOnTop());
    };
    widget.menuController.primaryAction = _handlePrimaryShortcut;
    widget.menuController.setLanguage = (value) {
      unawaited(_setLanguage(value));
    };

    _timerController = ShowTimerController();
    _timerController.addListener(_handleTimerChanged);

    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onShow: _handleAppResume,
    );

    _enableWakelock();
    unawaited(_loadSavedSettings());
  }

  Future<void> _loadSavedSettings() async {
    final settings = await _settingsService.load();

    if (isDesktopPlatform) {
      await windowManager.setAlwaysOnTop(settings.alwaysOnTop);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showTitle = settings.showTitle;
      _titleController.text = settings.showTitle;
      _isAlwaysOnTop = settings.alwaysOnTop;
      _showCurrentTime = settings.showCurrentTime;
      _showCurrentSeconds = settings.showCurrentSeconds;
      _use24Hour = settings.use24Hour;
      _language = settings.language;
    });

    widget.menuController.language.value = _language;
    widget.menuController.alwaysOnTop.value = _isAlwaysOnTop;
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

  void _handleTimerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAppResume() {
    _timerController.refreshAfterResume();
    _lastPointerPosition = null;
    _enableWakelock();
  }

  @override
  void dispose() {
    _timerController.removeListener(_handleTimerChanged);
    _timerController.dispose();
    _controlHideTimer?.cancel();

    _lifecycleListener.dispose();

    _titleController.dispose();
    _titleFocusNode.dispose();
    _shortcutFocusNode.dispose();

    widget.menuController.openSettings = null;
    widget.menuController.openAbout = null;
    widget.menuController.toggleAlwaysOnTop = null;
    widget.menuController.primaryAction = null;
    widget.menuController.setLanguage = null;

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

    await _settingsService.saveShowTitle(newTitle);

    if (_timerController.status == ShowTimerStatus.running) {
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

    if (_timerController.status == ShowTimerStatus.running) {
      _showControlsTemporarily();
    }
  }

  // ---------------------------------------------------------------------------
  // ストップウォッチ
  // ---------------------------------------------------------------------------

  void _startShowTime() {
    _timerController.start();
    setState(() {
      _controlsVisible = true;
    });
    _scheduleControlHide();
  }

  void _pauseShowTime() {
    if (!_timerController.isRunning) {
      return;
    }

    _controlHideTimer?.cancel();
    _timerController.pause();
    setState(() {
      _controlsVisible = true;
    });
  }

  void _resumeShowTime() {
    if (!_timerController.isPaused) {
      return;
    }

    _timerController.resume();
    setState(() {
      _controlsVisible = true;
    });
    _scheduleControlHide();
  }

  void _resetShowTime() {
    _controlHideTimer?.cancel();
    _timerController.reset();
    if (mounted) {
      setState(() {
        _controlsVisible = true;
      });
    }
  }

  void _handlePrimaryShortcut() {
    if (_isEditingTitle || _isSettingsOpen || _isAboutOpen) {
      return;
    }

    switch (_timerController.status) {
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

  // ---------------------------------------------------------------------------
  // 操作ボタンの自動非表示
  // ---------------------------------------------------------------------------

  void _showControlsTemporarily() {
    if (_timerController.status != ShowTimerStatus.running || _isEditingTitle) {
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

    if (_timerController.status != ShowTimerStatus.running || _isEditingTitle) {
      return;
    }

    _controlHideTimer = Timer(_controlHideDelay, () {
      if (!mounted ||
          _timerController.status != ShowTimerStatus.running ||
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
  // 設定
  // ---------------------------------------------------------------------------

  Future<void> _toggleAlwaysOnTop() async {
    if (!isDesktopPlatform) {
      return;
    }

    final newValue = !_isAlwaysOnTop;

    await windowManager.setAlwaysOnTop(newValue);
    await _settingsService.saveAlwaysOnTop(newValue);

    if (!mounted) {
      return;
    }

    setState(() {
      _isAlwaysOnTop = newValue;
    });

    widget.menuController.alwaysOnTop.value = newValue;
  }

  Future<void> _setShowCurrentTime(bool value) async {
    setState(() {
      _showCurrentTime = value;
    });

    await _settingsService.saveShowCurrentTime(value);
  }

  Future<void> _setShowCurrentSeconds(bool value) async {
    setState(() {
      _showCurrentSeconds = value;
    });

    await _settingsService.saveShowCurrentSeconds(value);
  }

  Future<void> _setUse24Hour(bool value) async {
    setState(() {
      _use24Hour = value;
    });

    await _settingsService.saveUse24Hour(value);
  }

  Future<void> _setLanguage(AppLanguage value) async {
    setState(() {
      _language = value;
    });

    widget.menuController.language.value = value;

    await _settingsService.saveLanguage(value);
  }

  void _openAbout() {
    if (_isAboutOpen || _isSettingsOpen) {
      return;
    }

    _controlHideTimer?.cancel();
    setState(() {
      _isAboutOpen = true;
      _controlsVisible = true;
    });

    showShowTimeAboutDialog(context: context, language: _language).whenComplete(
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _isAboutOpen = false;
        });
        _shortcutFocusNode.requestFocus();
        if (_timerController.status == ShowTimerStatus.running) {
          _scheduleControlHide();
        }
      },
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

      if (_timerController.status == ShowTimerStatus.running) {
        _scheduleControlHide();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 表示フォーマット
  // ---------------------------------------------------------------------------

  Color get _showTimeColor {
    switch (_timerController.status) {
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
  // 操作ボタン
  // ---------------------------------------------------------------------------

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
                        : _clamp(width * 0.032, 32, 42);

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
                                          CurrentTimeDisplay(
                                            label: _t('現在時刻', 'CURRENT TIME'),
                                            showSeconds: _showCurrentSeconds,
                                            use24Hour: _use24Hour,
                                            labelFontSize: labelFontSize,
                                            timeFontSize: currentTimeFontSize,
                                            labelGap: labelGap,
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

                              ShowElapsedDisplay(
                                elapsed: _timerController.elapsed,
                                color: _showTimeColor,
                                fontSize: showTimeFontSize,
                              ),

                              SizedBox(height: buttonTopGap),

                              // 固定領域を確保するため、PAUSEが消えても
                              // カウンター位置とサイズは変化しません。
                              SizedBox(
                                width: buttonWidth,
                                height: buttonHeight,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: MainControls(
                                    status: _timerController.status,
                                    controlsVisible: _controlsVisible,
                                    width: buttonWidth,
                                    height: buttonHeight,
                                    fontSize: buttonFontSize,
                                    onStart: _startShowTime,
                                    onPause: _pauseShowTime,
                                    onResume: _resumeShowTime,
                                    resetButton: HoldResetButton(
                                      width: (buttonWidth - 12) / 2,
                                      height: buttonHeight,
                                      fontSize: buttonFontSize,
                                      onReset: _resetShowTime,
                                    ),
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
              const SingleActivator(LogicalKeyboardKey.comma, meta: true):
                  _openSettings,
            },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: scaffold,
      ),
    );

    return shortcutLayer;
  }
}
