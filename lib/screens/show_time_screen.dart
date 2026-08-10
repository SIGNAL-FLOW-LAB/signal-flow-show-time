import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/show_time_menu_controller.dart';
import '../controllers/show_timer_controller.dart';
import '../models/app_language.dart';
import '../models/comment_alignment.dart';
import '../models/show_timer_status.dart';
import '../platform/platform_support.dart';
import '../services/session_service.dart';
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

class _ShowTimeScreenState extends State<ShowTimeScreen> with WindowListener {
  static const Duration _controlHideDelay = Duration(milliseconds: 2500);
  static const Duration _windowSaveDelay = Duration(milliseconds: 300);

  final SettingsService _settingsService = SettingsService();
  final SessionService _sessionService = SessionService();
  final FocusNode _shortcutFocusNode = FocusNode();

  late final ShowTimerController _timerController;
  late final AppLifecycleListener _lifecycleListener;

  Timer? _controlHideTimer;
  Timer? _windowSaveTimer;

  Offset? _lastPointerPosition;

  String _showTitle = '';
  bool _isTitleDialogOpen = false;
  bool _isSettingsOpen = false;
  bool _isAboutOpen = false;
  bool _isClosingWindow = false;

  bool _isAlwaysOnTop = false;
  bool _showCurrentTime = true;
  bool _showCurrentSeconds = true;
  bool _use24Hour = true;

  AppLanguage _language = AppLanguage.japanese;

  CommentAlignment _commentAlignment = CommentAlignment.center;

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

    if (isDesktopPlatform) {
      windowManager.addListener(this);
    }

    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onShow: _handleAppResume,
      onDetach: _handleAppDetach,
    );

    _enableWakelock();
    unawaited(_loadSavedSettings());
    unawaited(_loadSavedTimerState());
  }

  Future<void> _setCommentAlignment(CommentAlignment value) async {
    setState(() {
      _commentAlignment = value;
    });

    await _settingsService.saveCommentAlignment(value);
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
      _isAlwaysOnTop = settings.alwaysOnTop;
      _showCurrentTime = settings.showCurrentTime;
      _showCurrentSeconds = settings.showCurrentSeconds;
      _use24Hour = settings.use24Hour;
      _language = settings.language;
      _commentAlignment = settings.commentAlignment;
    });

    widget.menuController.language.value = _language;
    widget.menuController.alwaysOnTop.value = _isAlwaysOnTop;
  }

  Future<void> _loadSavedTimerState() async {
    final savedTimerState = await _sessionService.loadTimerState();

    if (!mounted) {
      return;
    }

    _timerController.restoreElapsed(savedTimerState.elapsed);
  }

  Future<void> _saveTimerState() async {
    await _sessionService.saveTimerState(_timerController.elapsed);
  }

  Future<void> _saveWindowState() async {
    if (!isDesktopPlatform) {
      return;
    }

    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();

    await _sessionService.saveWindowState(position: position, size: size);
  }

  Future<void> _saveSession() async {
    await Future.wait([
      _saveTimerState(),
      if (isDesktopPlatform) _saveWindowState(),
    ]);
  }

  void _scheduleWindowStateSave() {
    if (!isDesktopPlatform || _isClosingWindow) {
      return;
    }

    _windowSaveTimer?.cancel();
    _windowSaveTimer = Timer(_windowSaveDelay, () {
      unawaited(_saveWindowState());
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

  void _handleAppDetach() {
    unawaited(_saveSession());
  }

  @override
  void onWindowMove() {
    _scheduleWindowStateSave();
  }

  @override
  void onWindowResize() {
    _scheduleWindowStateSave();
  }

  @override
  void onWindowClose() {
    if (_isClosingWindow) {
      return;
    }

    _isClosingWindow = true;
    _windowSaveTimer?.cancel();

    unawaited(
      _saveSession().whenComplete(() async {
        await windowManager.destroy();
      }),
    );
  }

  @override
  void dispose() {
    if (isDesktopPlatform) {
      windowManager.removeListener(this);
    }

    _timerController.removeListener(_handleTimerChanged);
    _timerController.dispose();
    _controlHideTimer?.cancel();
    _windowSaveTimer?.cancel();

    _lifecycleListener.dispose();

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
  // 表示コメント
  // ---------------------------------------------------------------------------

  Future<void> _showTitleEditDialog() async {
    if (_isTitleDialogOpen || _isSettingsOpen || _isAboutOpen) {
      return;
    }

    _controlHideTimer?.cancel();

    setState(() {
      _isTitleDialogOpen = true;
      _controlsVisible = false;
    });

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ShowCommentEditDialog(
          initialText: _showTitle,
          language: _language,
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isTitleDialogOpen = false;
    });

    _shortcutFocusNode.requestFocus();

    if (result != null) {
      setState(() {
        _showTitle = result;
      });

      await _settingsService.saveShowTitle(result);
    }
  }

  // ---------------------------------------------------------------------------
  // ストップウォッチ
  // ---------------------------------------------------------------------------

  void _startShowTime() {
    _timerController.start();
    unawaited(_saveTimerState());
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
    unawaited(_saveTimerState());
    setState(() {
      _controlsVisible = true;
    });
  }

  void _resumeShowTime() {
    if (!_timerController.isPaused) {
      return;
    }

    _timerController.resume();
    unawaited(_saveTimerState());
    setState(() {
      _controlsVisible = true;
    });
    _scheduleControlHide();
  }

  void _resetShowTime() {
    _controlHideTimer?.cancel();
    _timerController.reset();
    unawaited(_saveTimerState());
    if (mounted) {
      setState(() {
        _controlsVisible = true;
      });
    }
  }

  void _handlePrimaryShortcut() {
    if (_isTitleDialogOpen || _isSettingsOpen || _isAboutOpen) {
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
    if (_timerController.status != ShowTimerStatus.running ||
        _isTitleDialogOpen) {
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

    if (_timerController.status != ShowTimerStatus.running ||
        _isTitleDialogOpen) {
      return;
    }

    _controlHideTimer = Timer(_controlHideDelay, () {
      if (!mounted ||
          _timerController.status != ShowTimerStatus.running ||
          _isTitleDialogOpen) {
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
      _controlsVisible = false;
    });

    showSettingsSheet(
      context: context,
      language: _language,
      commentAlignment: _commentAlignment,
      showCurrentTime: _showCurrentTime,
      showCurrentSeconds: _showCurrentSeconds,
      use24Hour: _use24Hour,
      isAlwaysOnTop: _isAlwaysOnTop,
      showAlwaysOnTopOption: isDesktopPlatform,
      onLanguageChanged: _setLanguage,
      onCommentAlignmentChanged: _setCommentAlignment,
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
  // 表示コメント
  // ---------------------------------------------------------------------------

  Widget _buildShowTitle({
    required double fontSize,
    required double availableWidth,
    int maxLines = 2,
  }) {
    final textAlign = switch (_commentAlignment) {
      CommentAlignment.left => TextAlign.left,
      CommentAlignment.center => TextAlign.center,
      CommentAlignment.right => TextAlign.right,
    };

    return ShowTitle(
      title: _showTitle,
      fontSize: fontSize,
      availableWidth: availableWidth,
      maxLines: maxLines,
      textAlign: textAlign,
      emptyTitleLabel: _t('コメントを入力', 'Enter Comment'),
      editTitleLabel: _t('表示コメントを編集', 'Edit Display Comment'),
      onBeginEditing: _showTitleEditDialog,
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
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_isTitleDialogOpen || _isSettingsOpen || _isAboutOpen) {
              return;
            }

            _showControlsTemporarily();
            _shortcutFocusNode.requestFocus();
          },
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

                    final shortestSide = width < height ? width : height;

                    // iPhone縦画面と同程度の折り返し幅
                    final portraitEquivalentPadding = _clamp(
                      shortestSide * 0.035,
                      12,
                      80,
                    );

                    final portraitEquivalentTitleWidth =
                        shortestSide - (portraitEquivalentPadding * 2);

                    final isPhone = shortestSide < 600;

                    final isPhonePortrait =
                        isPhone && height > width && height >= 600;

                    final isPhoneLandscape = isPhone && width > height;

                    final isNarrow = width < 600;
                    final isCompactHeight = height < 600;
                    final isLargeDesktop = width >= 1100 && height >= 700;
                    final isVeryLargeDesktop = width >= 1400 && height >= 850;

                    final horizontalPadding = _clamp(
                      width *
                          (isPhoneLandscape
                              ? 0.025
                              : isPhonePortrait
                              ? 0.035
                              : isNarrow
                              ? 0.045
                              : 0.060),
                      12,
                      80,
                    );

                    final verticalPadding = isPhoneLandscape
                        ? 4.0
                        : isPhonePortrait
                        ? 6.0
                        : isCompactHeight
                        ? 6.0
                        : 12.0;

                    final titleWidth = width - (horizontalPadding * 2);

                    final landscapeCenterGap = _clamp(width * 0.025, 14, 28);

                    final landscapeLeftWidth =
                        (titleWidth - landscapeCenterGap) * (4 / 9);

                    final landscapeRightWidth =
                        (titleWidth - landscapeCenterGap) * (5 / 9);

                    final titleFontSize = isPhoneLandscape
                        ? _clamp(shortestSide * 0.050, 16, 20)
                        : isPhonePortrait
                        ? _clamp(width * 0.050, 17, 21)
                        : isCompactHeight
                        ? _clamp(shortestSide * 0.045, 15, 22)
                        : isNarrow
                        ? _clamp(width * 0.052, 17, 25)
                        : _clamp(width * 0.032, 32, 42);

                    final labelFontSize = isPhoneLandscape
                        ? _clamp(shortestSide * 0.034, 11, 15)
                        : isCompactHeight
                        ? _clamp(shortestSide * 0.034, 11, 16)
                        : isNarrow
                        ? _clamp(width * 0.036, 12, 18)
                        : _clamp(width * 0.020, 14, 28);

                    final currentTimeFontSize = isPhoneLandscape
                        ? _clamp(shortestSide * 0.155, 52, 66)
                        : isPhonePortrait
                        ? _clamp(width * 0.155, 52, 66)
                        : isCompactHeight
                        ? _clamp(shortestSide * 0.145, 38, 60)
                        : isNarrow
                        ? _clamp(width * 0.14, 46, 72)
                        : _clamp(width * 0.112, 64, 136);

                    double showTimeScale = 1;

                    if (isLargeDesktop) {
                      showTimeScale *= 1.10;
                    }

                    if (isVeryLargeDesktop) {
                      showTimeScale *= 1.08;
                    }

                    final baseShowTimeFontSize = isPhoneLandscape
                        ? _clamp(shortestSide * 0.205, 72, 92)
                        : isPhonePortrait
                        ? _clamp(width * 0.205, 72, 92)
                        : isCompactHeight
                        ? _clamp(shortestSide * 0.16, 38, 66)
                        : isNarrow
                        ? _clamp(width * 0.16, 48, 82)
                        : _clamp(width * 0.135, 68, 165);

                    final showTimeFontSize = _clamp(
                      baseShowTimeFontSize * showTimeScale * 1.20,
                      38,
                      isPhoneLandscape
                          ? 110
                          : isVeryLargeDesktop
                          ? 245
                          : 215,
                    );

                    final titleGap = _clamp(
                      height *
                          (isPhoneLandscape
                              ? 0.025
                              : isPhonePortrait
                              ? 0.018
                              : isCompactHeight
                              ? 0.014
                              : 0.028),
                      6,
                      26,
                    );

                    final sectionGap = _clamp(
                      height *
                          (isPhoneLandscape
                              ? 0.050
                              : isPhonePortrait
                              ? 0.024
                              : isCompactHeight
                              ? 0.020
                              : 0.032),
                      8,
                      30,
                    );

                    final labelGap = _clamp(
                      height *
                          (isPhoneLandscape
                              ? 0.018
                              : isPhonePortrait
                              ? 0.009
                              : 0.012),
                      5,
                      14,
                    );

                    final buttonTopGap = _clamp(
                      height *
                          (isPhoneLandscape
                              ? 0.055
                              : isPhonePortrait
                              ? 0.020
                              : isCompactHeight
                              ? 0.016
                              : 0.026),
                      8,
                      26,
                    );

                    final buttonWidth = isPhoneLandscape
                        ? _clamp(landscapeLeftWidth * 0.78, 180, 280)
                        : isPhonePortrait
                        ? _clamp(width * 0.72, 250, 330)
                        : isCompactHeight
                        ? _clamp(width * 0.30, 140, 220)
                        : isNarrow
                        ? _clamp(width * 0.55, 170, 240)
                        : _clamp(width * 0.30, 210, 360);

                    final buttonHeight = isPhoneLandscape
                        ? _clamp(height * 0.15, 48, 62)
                        : isPhonePortrait
                        ? _clamp(height * 0.072, 58, 70)
                        : isCompactHeight
                        ? _clamp(height * 0.13, 44, 54)
                        : _clamp(height * 0.085, 50, 82);

                    final buttonFontSize = isPhoneLandscape
                        ? _clamp(shortestSide * 0.048, 17, 22)
                        : isPhonePortrait
                        ? _clamp(width * 0.055, 20, 24)
                        : isCompactHeight
                        ? _clamp(shortestSide * 0.048, 16, 21)
                        : isNarrow
                        ? _clamp(width * 0.048, 18, 25)
                        : _clamp(width * 0.026, 21, 34);

                    final phonePortraitTopOffset = isPhonePortrait
                        ? _clamp(height * 0.078, 36, 48)
                        : 0.0;

                    final phonePortraitButtonGap = isPhonePortrait
                        ? _clamp(height * 0.120, 58, 90)
                        : buttonTopGap;

                    final contentMinHeight = isKeyboardVisible
                        ? 0.0
                        : height - (verticalPadding * 2);

                    final controlsAreVisible =
                        _controlsVisible &&
                        !_isTitleDialogOpen &&
                        !_isSettingsOpen &&
                        !_isAboutOpen;

                    // -----------------------------------------------------------
                    // iPhone横画面・左側
                    // コメント＋操作ボタン
                    // -----------------------------------------------------------

                    final landscapeControlsPanel = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildShowTitle(
                          fontSize: titleFontSize,
                          availableWidth:
                              landscapeLeftWidth - 8 <
                                  portraitEquivalentTitleWidth
                              ? landscapeLeftWidth - 8
                              : portraitEquivalentTitleWidth,
                          maxLines: 8,
                        ),

                        SizedBox(height: buttonTopGap),

                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: AnimatedSwitcher(
                            duration: Duration.zero,
                            child: MainControls(
                              status: _timerController.status,
                              controlsVisible: controlsAreVisible,
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
                      ],
                    );

                    // -----------------------------------------------------------
                    // iPhone横画面・右側
                    // 現在時刻＋公演時間
                    // -----------------------------------------------------------

                    final landscapeTimePanel = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_showCurrentTime) ...[
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

                        Text(
                          _t('公演時間', 'SHOW TIME'),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: labelFontSize,
                          ),
                        ),

                        SizedBox(height: labelGap),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: landscapeRightWidth,
                            child: Center(
                              child: ShowElapsedDisplay(
                                elapsed: _timerController.elapsed,
                                color: _showTimeColor,
                                fontSize: showTimeFontSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );

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

                          // -----------------------------------------------------
                          // iPhone横画面だけRow
                          // それ以外は従来のColumn
                          // -----------------------------------------------------
                          child: isPhoneLandscape
                              ? Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: landscapeControlsPanel,
                                    ),

                                    SizedBox(width: landscapeCenterGap),

                                    Expanded(
                                      flex: 5,
                                      child: landscapeTimePanel,
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: isKeyboardVisible
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,

                                  children: [
                                    if (isPhonePortrait && !isKeyboardVisible)
                                      SizedBox(height: phonePortraitTopOffset),

                                    Transform.translate(
                                      offset: Offset(
                                        0,

                                        isPhonePortrait && !isKeyboardVisible
                                            ? -phonePortraitTopOffset
                                            : 0,
                                      ),

                                      child: Column(
                                        children: [
                                          _buildShowTitle(
                                            fontSize: titleFontSize,

                                            availableWidth: titleWidth,

                                            maxLines:
                                                isPhonePortrait ||
                                                    isPhoneLandscape
                                                ? 8
                                                : 2,
                                          ),

                                          SizedBox(height: titleGap),

                                          AnimatedSize(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),

                                            curve: Curves.easeOutCubic,

                                            child: _showCurrentTime
                                                ? Column(
                                                    children: [
                                                      CurrentTimeDisplay(
                                                        label: _t(
                                                          '現在時刻',
                                                          'CURRENT TIME',
                                                        ),

                                                        showSeconds:
                                                            _showCurrentSeconds,

                                                        use24Hour: _use24Hour,

                                                        labelFontSize:
                                                            labelFontSize,

                                                        timeFontSize:
                                                            currentTimeFontSize,

                                                        labelGap: labelGap,
                                                      ),

                                                      SizedBox(
                                                        height: sectionGap,
                                                      ),
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
                                        ],
                                      ),
                                    ),

                                    SizedBox(
                                      height: isPhonePortrait
                                          ? phonePortraitButtonGap
                                          : buttonTopGap,
                                    ),

                                    SizedBox(
                                      width: buttonWidth,

                                      height: buttonHeight,

                                      child: AnimatedSwitcher(
                                        duration: Duration.zero,

                                        child: MainControls(
                                          status: _timerController.status,

                                          controlsVisible:
                                              _controlsVisible &&
                                              !_isTitleDialogOpen &&
                                              !_isSettingsOpen &&
                                              !_isAboutOpen,

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
      bindings: _isTitleDialogOpen
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

class _ShowCommentEditDialog extends StatefulWidget {
  const _ShowCommentEditDialog({
    required this.initialText,
    required this.language,
  });

  final String initialText;
  final AppLanguage language;

  @override
  State<_ShowCommentEditDialog> createState() => _ShowCommentEditDialogState();
}

class _ShowCommentEditDialogState extends State<_ShowCommentEditDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String _t(String japanese, String english) {
    return widget.language == AppLanguage.japanese ? japanese : english;
  }

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusNode.requestFocus();

      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_controller.text.trimRight());
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    final isTablet = screenSize.shortestSide >= 600;
    final isPhone = !isTablet;

    final isPhonePortrait = isPhone && screenSize.height > screenSize.width;

    final isPhoneLandscape = isPhone && screenSize.width > screenSize.height;

    // iPhone縦・横は最大8行。
    // iPad・Macは従来どおり最大2行。
    final maxCommentLines = isPhone ? 8 : 2;

    // 横画面では初期表示を2行に抑えます。
    final minCommentLines = isPhoneLandscape
        ? 2
        : isPhonePortrait
        ? 4
        : 2;

    // iPhoneは140文字、iPad・Macは80文字。
    final maxCommentLength = isPhone ? 140 : 80;

    // ---------------------------------------------------------------------------
    // 編集欄を実際の表示コメントに近づける
    // ---------------------------------------------------------------------------

    // 本画面のコメント表示に近い文字サイズ
    final previewFontSize = isPhoneLandscape
        ? (screenSize.shortestSide * 0.050).clamp(16.0, 20.0)
        : isPhonePortrait
        ? (screenSize.width * 0.050).clamp(17.0, 21.0)
        : isTablet
        ? (screenSize.width * 0.032).clamp(22.0, 32.0)
        : 20.0;

    // 画面からキーボード領域を引いた使用可能高さ。
    final availableHeight =
        screenSize.height - keyboardHeight - (isPhoneLandscape ? 8 : 32);

    // 明示的な改行が最大行数を超えないようにします。
    final lineLimitFormatter = TextInputFormatter.withFunction((
      oldValue,
      newValue,
    ) {
      final lineCount = '\n'.allMatches(newValue.text).length + 1;

      if (lineCount > maxCommentLines) {
        return oldValue;
      }

      return newValue;
    });

    return Dialog(
      backgroundColor: const Color(0xFF171717),

      // 横画面では余白を小さくします。
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet
            ? 80
            : isPhoneLandscape
            ? 12
            : 24,
        vertical: isPhoneLandscape ? 4 : 24,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhoneLandscape ? 18 : 22),
        side: const BorderSide(color: Colors.white12),
      ),

      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isPhoneLandscape ? 900 : 680,
          maxHeight: availableHeight > 0 ? availableHeight : screenSize.height,
        ),

        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet
                ? 32
                : isPhoneLandscape
                ? 20
                : 22,
            isTablet
                ? 30
                : isPhoneLandscape
                ? 12
                : 22,
            isTablet
                ? 32
                : isPhoneLandscape
                ? 20
                : 22,
            isTablet
                ? 24
                : isPhoneLandscape
                ? 12
                : 18,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // タイトル
              Text(
                _t('表示コメントを編集', 'Edit Display Comment'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet
                      ? 24
                      : isPhoneLandscape
                      ? 18
                      : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(
                height: isPhoneLandscape
                    ? 8
                    : isTablet
                    ? 12
                    : 10,
              ),

              // 横画面では説明文を非表示
              if (!isPhoneLandscape) ...[
                Text(
                  isPhonePortrait
                      ? _t(
                          '公演名、会場名、演目、連絡事項など、'
                              '表示したい内容を自由に入力できます。\n'
                              'iPhoneでは最大8行・140文字まで入力できます。',
                          'Enter any message you want to display, '
                              'such as a show name, venue, program, or note.\n'
                              'On iPhone, up to 8 lines and 140 characters.',
                        )
                      : _t(
                          '公演名、会場名、演目、連絡事項など、'
                              '表示したい内容を自由に入力できます。\n'
                              '最大2行・80文字まで入力できます。',
                          'Enter any message you want to display, '
                              'such as a show name, venue, program, or note.\n'
                              'Up to 2 lines and 80 characters.',
                        ),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isTablet ? 15 : 13,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: isTablet ? 18 : 14),
              ],

              // 入力欄部分だけスクロール可能
              // 入力欄部分だけスクロール可能
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,

                    minLines: minCommentLines,
                    maxLines: maxCommentLines,
                    maxLength: maxCommentLength,

                    inputFormatters: [
                      lineLimitFormatter,
                      LengthLimitingTextInputFormatter(maxCommentLength),
                    ],

                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,

                    // 編集画面では常に左寄せ
                    textAlign: TextAlign.left,

                    // 実際の表示コメントに近い文字サイズ
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: previewFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),

                    decoration: InputDecoration(
                      hintText: _t(
                        '例：公演名・会場名\n連絡事項やメモ',
                        'Example: Show or Venue\nMessage or Note',
                      ),

                      hintStyle: TextStyle(
                        color: Colors.white30,
                        fontSize: previewFontSize,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),

                      counterStyle: const TextStyle(color: Colors.white38),

                      filled: true,
                      fillColor: const Color(0xFF222222),

                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isPhone ? 12 : 16,
                        vertical: isPhone ? 14 : 18,
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF69F0AE),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: isPhoneLandscape
                    ? 8
                    : isTablet
                    ? 24
                    : 18,
              ),

              // このRowはスクロール領域の外なので、
              // キャンセル・保存ボタンが常に表示されます。
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(
                          0,
                          isTablet
                              ? 58
                              : isPhoneLandscape
                              ? 42
                              : 50,
                        ),
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_t('キャンセル', 'Cancel')),
                    ),
                  ),

                  SizedBox(width: isPhoneLandscape ? 10 : 14),

                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: Size(
                          0,
                          isTablet
                              ? 58
                              : isPhoneLandscape
                              ? 42
                              : 50,
                        ),
                        backgroundColor: const Color(0xFF69F0AE),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _t('保存', 'Save'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
