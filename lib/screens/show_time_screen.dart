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
import '../widgets/break_resume_display.dart';
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

  ShowTimerStatus _lastPersistedTimerStatus = ShowTimerStatus.idle;

  Timer? _controlHideTimer;
  Timer? _windowSaveTimer;

  Offset? _lastPointerPosition;

  String _showTitle = '';
  bool _isTitleDialogOpen = false;
  bool _isSettingsOpen = false;
  bool _isAboutOpen = false;
  bool _isBreakDialogOpen = false;
  bool _isClosingWindow = false;

  bool _isAlwaysOnTop = false;
  bool _showCurrentTime = true;
  bool _showCurrentSeconds = true;
  bool _use24Hour = true;

  bool _breakFeatureEnabled = false;
  Duration _breakDuration = const Duration(minutes: 15);

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
      _breakFeatureEnabled = settings.breakFeatureEnabled;
      _breakDuration = settings.breakDuration;
    });

    widget.menuController.language.value = _language;
    widget.menuController.alwaysOnTop.value = _isAlwaysOnTop;
  }

  Future<void> _loadSavedTimerState() async {
    final savedTimerState = await _sessionService.loadTimerState();

    if (!mounted) {
      return;
    }

    _timerController.restoreState(
      elapsed: savedTimerState.elapsed,
      isOnBreak: savedTimerState.isOnBreak,
      breakEndsAt: savedTimerState.breakEndsAt,
    );
  }

  Future<void> _saveTimerState() async {
    await _sessionService.saveTimerState(
      elapsed: _timerController.elapsed,
      isOnBreak: _timerController.isOnBreak,
      breakEndsAt: _timerController.breakEndsAt,
    );
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
    if (!mounted) {
      return;
    }

    setState(() {});

    final currentStatus = _timerController.status;

    // 休憩終了予定時刻に達した自動再開など、ボタン操作を経ない状態遷移も保存します。
    if (currentStatus != _lastPersistedTimerStatus) {
      _lastPersistedTimerStatus = currentStatus;
      unawaited(_saveTimerState());

      // 休憩の自動終了などボタン操作を経ずに進行中へ戻った場合も、
      // 一時停止・休憩ボタンを一定時間後に自動で非表示にします。
      if (currentStatus == ShowTimerStatus.running) {
        _scheduleControlHide();
      }
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
    if (_isTitleDialogOpen ||
        _isSettingsOpen ||
        _isAboutOpen ||
        _isBreakDialogOpen) {
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

  Future<void> _startBreakFlow() async {
    if (!_timerController.isRunning ||
        !_breakFeatureEnabled ||
        _isBreakDialogOpen ||
        _isTitleDialogOpen ||
        _isSettingsOpen ||
        _isAboutOpen) {
      return;
    }

    _controlHideTimer?.cancel();

    setState(() {
      _isBreakDialogOpen = true;
      _controlsVisible = true;
    });

    final resumeAt = DateTime.now().add(_breakDuration);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _BreakConfirmDialog(
          language: _language,
          breakDuration: _breakDuration,
          resumeAt: resumeAt,
          formatTime: _formatClockTime,
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isBreakDialogOpen = false;
    });

    _shortcutFocusNode.requestFocus();

    if (confirmed == true && _timerController.isRunning) {
      _timerController.startBreak(_breakDuration);
      unawaited(_saveTimerState());
      setState(() {
        _controlsVisible = true;
      });
    } else if (_timerController.status == ShowTimerStatus.running) {
      _scheduleControlHide();
    }
  }

  void _resumeFromBreakNow() {
    if (!_timerController.isOnBreak) {
      return;
    }

    _timerController.resumeFromBreakNow();
    unawaited(_saveTimerState());
    setState(() {
      _controlsVisible = true;
    });
    _scheduleControlHide();
  }

  void _handlePrimaryShortcut() {
    if (_isTitleDialogOpen ||
        _isSettingsOpen ||
        _isAboutOpen ||
        _isBreakDialogOpen) {
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
      case ShowTimerStatus.onBreak:
        _resumeFromBreakNow();
        return;
    }
  }

  // ---------------------------------------------------------------------------
  // 操作ボタンの自動非表示
  // ---------------------------------------------------------------------------

  void _showControlsTemporarily() {
    if (_timerController.status != ShowTimerStatus.running ||
        _isTitleDialogOpen ||
        _isBreakDialogOpen) {
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
        _isTitleDialogOpen ||
        _isBreakDialogOpen) {
      return;
    }

    _controlHideTimer = Timer(_controlHideDelay, () {
      if (!mounted ||
          _timerController.status != ShowTimerStatus.running ||
          _isTitleDialogOpen ||
          _isBreakDialogOpen) {
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

  Future<void> _setBreakFeatureEnabled(bool value) async {
    setState(() {
      _breakFeatureEnabled = value;
    });

    await _settingsService.saveBreakFeatureEnabled(value);
  }

  Future<void> _setBreakDuration(Duration value) async {
    setState(() {
      _breakDuration = value;
    });

    await _settingsService.saveBreakDuration(value);
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
    if (_isAboutOpen || _isSettingsOpen || _isBreakDialogOpen) {
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
    if (_isSettingsOpen || _isBreakDialogOpen) {
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
      breakFeatureEnabled: _breakFeatureEnabled,
      breakDuration: _breakDuration,
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
      onBreakFeatureEnabledChanged: _setBreakFeatureEnabled,
      onBreakDurationChanged: _setBreakDuration,
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
      case ShowTimerStatus.onBreak:
        return const Color(0xFFFF9100);
    }
  }

  double _clamp(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
  }

  String _formatClockTime(DateTime time) {
    final hours = _use24Hour
        ? time.hour.toString()
        : (() {
            var displayHour = time.hour % 12;
            if (displayHour == 0) {
              displayHour = 12;
            }
            return displayHour.toString();
          })();

    final minutes = time.minute.toString().padLeft(2, '0');

    if (_use24Hour) {
      return '$hours:$minutes';
    }

    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hours:$minutes $period';
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
            icon: const Icon(Icons.settings),
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
  // 休憩中の再開予定時刻
  // ---------------------------------------------------------------------------

  DateTime? get _breakEndsAt => _timerController.breakEndsAt;

  bool get _isOnBreakWithEndTime =>
      _timerController.isOnBreak && _breakEndsAt != null;

  bool get _isBreakEndingSoon {
    final endsAt = _breakEndsAt;
    if (!_isOnBreakWithEndTime || endsAt == null) {
      return false;
    }

    final remaining = endsAt.difference(DateTime.now());
    return !remaining.isNegative && remaining <= const Duration(minutes: 1);
  }

  // 休憩中の再開予定時刻。「再開予定」ラベル＋大きな時刻の2段表示。
  // timeFontSizeは現在時刻表示の50〜65%を目安に、currentTimeFontSizeから算出します。
  Widget _buildBreakResumeArea({
    required double currentTimeFontSize,
    required double labelFontSize,
    required double labelGap,
    required double outerGap,
    double? maxWidth,
  }) {
    final breakEndsAt = _breakEndsAt;
    final isOnBreak = _isOnBreakWithEndTime;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !isOnBreak
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.symmetric(vertical: outerGap),
              child: BreakResumeDisplay(
                resumeAt: breakEndsAt!,
                use24Hour: _use24Hour,
                isEndingSoon: _isBreakEndingSoon,
                label: _t('再開予定', 'RESUMES AT'),
                labelFontSize: labelFontSize,
                timeFontSize: currentTimeFontSize * 0.58,
                labelGap: labelGap,
                maxWidth: maxWidth,
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // iPad横画面
  // 左: 上部余白＋コメント（下寄せ・上限付き）＋操作ボタン
  // 右: 現在時刻・再開予定・公演時間
  // ---------------------------------------------------------------------------

  Widget _buildTabletLandscapeLayout({
    required double width,
    required double height,
  }) {
    final horizontalPadding = _clamp(width * 0.040, 28, 56);
    final verticalPadding = _clamp(height * 0.030, 18, 32);
    final columnGap = _clamp(width * 0.035, 28, 52);

    final contentWidth = width - (horizontalPadding * 2);
    final contentHeight = height - (verticalPadding * 2);

    final leftWidth = (contentWidth - columnGap) * 0.45;
    final rightWidth = (contentWidth - columnGap) * 0.55;

    final commentFontSize = _clamp(leftWidth * 0.070, 18, 26);
    final commentMaxLines = 6;

    // コメントは左カラム内で高さの上限を持たせ、余った分は上の空白に
    // 回します（Flexibleのため、極端に低いウィンドウでも溢れません）。
    final commentMaxHeight = _clamp(contentHeight * 0.22, 90, 220);

    final buttonHeight = _clamp(contentHeight * 0.13, 56, 84);
    final buttonFontSize = _clamp(leftWidth * 0.090, 19, 26);
    final buttonGap = _clamp(contentHeight * 0.028, 12, 24);

    final labelFontSize = _clamp(rightWidth * 0.050, 15, 20);
    final labelGap = _clamp(contentHeight * 0.012, 6, 12);
    final currentTimeFontSize = _clamp(rightWidth * 0.200, 44, 92);
    final showTimeFontSize = _clamp(rightWidth * 0.300, 60, 140);
    final blockGap = _clamp(contentHeight * 0.020, 8, 20);

    final isOnBreak = _isOnBreakWithEndTime;

    final controlsAreVisible =
        _controlsVisible &&
        !_isTitleDialogOpen &&
        !_isSettingsOpen &&
        !_isAboutOpen &&
        !_isBreakDialogOpen;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 上部の空白。コメントとボタンを左カラム下側へまとめて配置する
        // ための余白で、コメントが短い／未入力でも巨大な空白ができる
        // 主因だった「コメントのExpanded一択」構成を解消します。
        const Expanded(
          key: ValueKey('tablet-landscape-left-spacer'),
          flex: 5,
          child: SizedBox.shrink(),
        ),

        Flexible(
          key: const ValueKey('tablet-landscape-comment'),
          flex: 3,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: commentMaxHeight),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: leftWidth,
                child: _buildShowTitle(
                  fontSize: commentFontSize,
                  availableWidth: leftWidth,
                  maxLines: commentMaxLines,
                ),
              ),
            ),
          ),
        ),

        SizedBox(
          key: const ValueKey('tablet-landscape-gap-comment-button'),
          height: buttonGap,
        ),

        SizedBox(
          key: const ValueKey('tablet-landscape-button'),
          height: buttonHeight,
          child: AnimatedSwitcher(
            duration: Duration.zero,
            child: MainControls(
              status: _timerController.status,
              controlsVisible: controlsAreVisible,
              width: leftWidth,
              height: buttonHeight,
              fontSize: buttonFontSize,
              onStart: _startShowTime,
              onPause: _pauseShowTime,
              onResume: _resumeShowTime,
              breakFeatureEnabled: _breakFeatureEnabled,
              onStartBreak: () {
                unawaited(_startBreakFlow());
              },
              onResumeFromBreakNow: _resumeFromBreakNow,
              startLabel: _t('スタート', 'START'),
              pauseLabel: _t('一時停止', 'PAUSE'),
              resumeLabel: _t('再開', 'RESUME'),
              breakLabel: _t('休憩', 'Start Break'),
              resumeFromBreakLabel: _t('今すぐ再開', 'Resume Now'),
              resetButton: HoldResetButton(
                width: (leftWidth - 12) / 2,
                height: buttonHeight,
                fontSize: buttonFontSize,
                onReset: _resetShowTime,
                resetLabel: _t('リセット', 'RESET'),
                holdLabel: _t('ホールド', 'HOLD'),
              ),
            ),
          ),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showCurrentTime) ...[
          Expanded(
            key: const ValueKey('tablet-landscape-current-time'),
            flex: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: rightWidth,
                child: CurrentTimeDisplay(
                  label: _t('現在時刻', 'CURRENT TIME'),
                  showSeconds: _showCurrentSeconds,
                  use24Hour: _use24Hour,
                  labelFontSize: labelFontSize,
                  timeFontSize: currentTimeFontSize,
                  labelGap: labelGap,
                ),
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('tablet-landscape-gap-after-current-time'),
            height: blockGap,
          ),
        ],

        if (isOnBreak) ...[
          Expanded(
            key: const ValueKey('tablet-landscape-resume'),
            flex: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: BreakResumeDisplay(
                resumeAt: _breakEndsAt!,
                use24Hour: _use24Hour,
                isEndingSoon: _isBreakEndingSoon,
                label: _t('再開予定', 'RESUMES AT'),
                labelFontSize: labelFontSize,
                timeFontSize: currentTimeFontSize * 0.58,
                labelGap: labelGap,
                maxWidth: rightWidth,
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('tablet-landscape-gap-after-resume'),
            height: blockGap,
          ),
        ],

        Expanded(
          key: const ValueKey('tablet-landscape-show-time'),
          flex: 32,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: rightWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: leftWidth, child: leftColumn),
          SizedBox(width: columnGap),
          SizedBox(width: rightWidth, child: rightColumn),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 縦画面共通レイアウト（iPhone縦・iPad縦で共有）
  // 現在時刻 → 再開予定専用の固定高領域 → 公演時間 → コメント（下寄せ・
  // 上限付き） → 操作ボタン
  // Widget構成そのものは共通化し、寸法・文字サイズ・コメント行数など
  // 端末ごとに変わる値だけを呼び出し側から渡します。ボタンは固定サイズの
  // 非フレキシブル要素として最後に確保し、コメントはExpanded+
  // ConstrainedBox(maxHeight)で上限付き（かつ極端に低いウィンドウでも
  // 溢れない）にすることで、コメントの有無・長さに関わらずボタン位置が
  // 動かないようにしています。
  //
  // 現在時刻・公演時間の位置固定: 再開予定は現在時刻と公演時間の間に
  // 常に同じ高さ（resumeAreaHeight）のSizedBoxとして予約し、休憩中だけ
  // その中身を描画します。中身が無いときはchildをnull（=SizedBox.shrink
  // ではなく本当に何もない）にすることで、アクセシビリティツリーに
  // 不要な非表示テキストを残しません。この領域の有無で現在時刻・公演時間
  // 側のflex構成が変化しないため、休憩の開始・終了で時計位置が動きません。
  // ---------------------------------------------------------------------------

  Widget _buildPortraitLayout({
    required String keyPrefix,
    required double horizontalPadding,
    required double topPadding,
    required double bottomPadding,
    required double contentWidth,
    required double labelFontSize,
    required double labelGap,
    required double currentTimeFontSize,
    required double showTimeFontSize,
    required double blockGap,
    required double commentFontSize,
    required int commentMaxLines,
    required double commentMaxHeight,
    required double commentGap,
    required double buttonWidth,
    required double buttonHeight,
    required double buttonFontSize,
    required double buttonTopGap,
    required int clockGroupFlex,
    required int commentFlex,
    required int currentTimeFlex,
    required int showTimeFlex,
  }) {
    final isOnBreak = _isOnBreakWithEndTime;

    final controlsAreVisible =
        _controlsVisible &&
        !_isTitleDialogOpen &&
        !_isSettingsOpen &&
        !_isAboutOpen &&
        !_isBreakDialogOpen;

    final resumeTimeFontSize = currentTimeFontSize * 0.58;
    // ラベル1行＋ラベルとの間隔＋時刻表示（BreakResumeDisplay内部の
    // SizedBox(height: timeFontSize*1.2)と同じ倍率）に収まる高さ。
    final resumeAreaHeight =
        (labelFontSize * 1.3) + labelGap + (resumeTimeFontSize * 1.2);

    final clockGroupChildren = <Widget>[
      if (_showCurrentTime) ...[
        Expanded(
          key: ValueKey('$keyPrefix-current-time'),
          flex: currentTimeFlex,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: contentWidth,
              child: CurrentTimeDisplay(
                label: _t('現在時刻', 'CURRENT TIME'),
                showSeconds: _showCurrentSeconds,
                use24Hour: _use24Hour,
                labelFontSize: labelFontSize,
                timeFontSize: currentTimeFontSize,
                labelGap: labelGap,
              ),
            ),
          ),
        ),
        SizedBox(
          key: ValueKey('$keyPrefix-gap-after-current-time'),
          height: blockGap,
        ),
      ],

      SizedBox(
        key: ValueKey('$keyPrefix-resume-area'),
        height: resumeAreaHeight,
        child: !isOnBreak
            ? null
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: BreakResumeDisplay(
                  resumeAt: _breakEndsAt!,
                  use24Hour: _use24Hour,
                  isEndingSoon: _isBreakEndingSoon,
                  label: _t('再開予定', 'RESUMES AT'),
                  labelFontSize: labelFontSize,
                  timeFontSize: resumeTimeFontSize,
                  labelGap: labelGap,
                  maxWidth: contentWidth,
                ),
              ),
      ),
      SizedBox(key: ValueKey('$keyPrefix-gap-after-resume'), height: blockGap),

      Expanded(
        key: ValueKey('$keyPrefix-show-time'),
        flex: showTimeFlex,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
        ),
      ),
    ];

    final children = <Widget>[
      Expanded(
        key: ValueKey('$keyPrefix-clock-group'),
        flex: clockGroupFlex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: clockGroupChildren,
        ),
      ),

      SizedBox(
        key: ValueKey('$keyPrefix-gap-before-comment'),
        height: commentGap,
      ),

      // コメントはExpanded（tight）で包み、常に同じflex比率の高さを
      // 確保します。中の見え方（未入力時の鉛筆アイコン／入力済み
      // テキスト）が変わってもこの外枠の高さは変化しないため、
      // 入力の有無でボタンや時計の位置が動きません。
      Expanded(
        key: ValueKey('$keyPrefix-comment-slot'),
        flex: commentFlex,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: commentMaxHeight),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: ValueKey('$keyPrefix-comment'),
              width: contentWidth,
              child: _buildShowTitle(
                fontSize: commentFontSize,
                availableWidth: contentWidth,
                maxLines: commentMaxLines,
              ),
            ),
          ),
        ),
      ),

      SizedBox(
        key: ValueKey('$keyPrefix-gap-before-button'),
        height: buttonTopGap,
      ),

      SizedBox(
        key: ValueKey('$keyPrefix-button'),
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
            breakFeatureEnabled: _breakFeatureEnabled,
            onStartBreak: () {
              unawaited(_startBreakFlow());
            },
            onResumeFromBreakNow: _resumeFromBreakNow,
            startLabel: _t('スタート', 'START'),
            pauseLabel: _t('一時停止', 'PAUSE'),
            resumeLabel: _t('再開', 'RESUME'),
            breakLabel: _t('休憩', 'Start Break'),
            resumeFromBreakLabel: _t('今すぐ再開', 'Resume Now'),
            resetButton: HoldResetButton(
              width: (buttonWidth - 12) / 2,
              height: buttonHeight,
              fontSize: buttonFontSize,
              onReset: _resetShowTime,
              resetLabel: _t('リセット', 'RESET'),
              holdLabel: _t('ホールド', 'HOLD'),
            ),
          ),
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      // クロス軸はcenter: 時計グループ・コメントは内部のSizedBox(width:
      // contentWidth)でcontentWidth幅を確保しつつ、ボタンだけはそれより
      // 狭いbuttonWidthで中央寄せにします。
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // iPad縦画面
  // 現在時刻 → 再開予定 → 公演時間 → コメント（下寄せ・上限付き） → 操作ボタン
  // ---------------------------------------------------------------------------

  Widget _buildTabletPortraitLayout({
    required double width,
    required double height,
  }) {
    final horizontalPadding = _clamp(width * 0.055, 28, 64);
    final topPadding = _clamp(height * 0.025, 16, 32);
    final bottomPadding = _clamp(height * 0.020, 16, 28);

    final contentWidth = width - (horizontalPadding * 2);

    final commentFontSize = _clamp(contentWidth * 0.024, 15, 20);
    const commentMaxLines = 4;

    // コメント領域の高さの上限。時計グループ（現在時刻・再開予定・公演
    // 時間）を主役にするため、コメントは下部に小さくまとめます。
    // Expanded(flex)で包むため、これより低いウィンドウでも溢れません。
    final commentMaxHeight = _clamp(height * 0.16, 90, 200);

    final labelFontSize = _clamp(contentWidth * 0.026, 16, 22);
    final labelGap = _clamp(height * 0.008, 6, 12);
    final currentTimeFontSize = _clamp(contentWidth * 0.160, 56, 100);
    final showTimeFontSize = _clamp(contentWidth * 0.220, 80, 160);
    final blockGap = _clamp(height * 0.014, 8, 22);

    final buttonHeight = _clamp(height * 0.075, 60, 84);
    final buttonWidth = _clamp(width * 0.65, 320, 680);
    final buttonFontSize = _clamp(contentWidth * 0.045, 22, 30);
    final buttonTopGap = _clamp(height * 0.022, 14, 28);

    return _buildPortraitLayout(
      keyPrefix: 'tablet-portrait',
      horizontalPadding: horizontalPadding,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      contentWidth: contentWidth,
      labelFontSize: labelFontSize,
      labelGap: labelGap,
      currentTimeFontSize: currentTimeFontSize,
      showTimeFontSize: showTimeFontSize,
      blockGap: blockGap,
      commentFontSize: commentFontSize,
      commentMaxLines: commentMaxLines,
      commentMaxHeight: commentMaxHeight,
      commentGap: blockGap,
      buttonWidth: buttonWidth,
      buttonHeight: buttonHeight,
      buttonFontSize: buttonFontSize,
      buttonTopGap: buttonTopGap,
      clockGroupFlex: 8,
      commentFlex: 2,
      currentTimeFlex: 2,
      showTimeFlex: 3,
    );
  }

  // ---------------------------------------------------------------------------
  // iPhone縦画面
  // 4領域（topClockRegion / performanceTimeRegion / commentRegion /
  // controlsRegion）に明示的に分割したStack/Positionedレイアウトです。
  //
  // - controlsRegionは画面下端からbottomPadding+buttonHeightで固定します
  //   （以前の数式のまま）。これにより操作ボタンの位置は今回の変更で
  //   一切動きません。
  // - performanceTimeRegionは、現在時刻・再開予定・コメントの内容量とは
  //   無関係に「利用可能な高さ(height)の中央」を基準に高さを算出して
  //   配置します。SpacerやspaceEvenlyなどの再配分には依存していません。
  // - topClockRegion（現在時刻＋再開予定専用の固定高スロット）は
  //   topPaddingからperformanceTimeRegionの上端までの範囲です。
  // - commentRegionはperformanceTimeRegionの下端からcontrolsRegionの
  //   上端までの残り領域で、コメント最大8行（iPhoneのコメント編集
  //   ダイアログの仕様と一致）を目安に、実際に高さが足りるかを
  //   _resolveCommentMaxLinesで検証してから行数を決定します。
  // ---------------------------------------------------------------------------

  Widget _buildPhonePortraitLayout({
    required double width,
    required double height,
  }) {
    // 横方向の余白・文字サイズはwidth基準、縦方向の余白・ギャップは
    // height基準（従来のiPhone縦画面の数式を踏襲）。
    final horizontalPadding = _clamp(width * 0.035, 12, 80);
    // 設定アイコン（右上オーバーレイ）と現在時刻が重ならないよう、
    // 上部に十分な余白を確保します。
    final topPadding = _clamp(height * 0.045, 24, 56);
    final bottomPadding = _clamp(height * 0.020, 12, 28);

    final contentWidth = width - (horizontalPadding * 2);

    // 現在時刻・公演時間の文字サイズ、操作ボタンの寸法は既存の視認性・
    // 位置を維持するため、以前と同じ数式のままにしています。
    final labelFontSize = _clamp(width * 0.036, 12, 18);
    final labelGap = _clamp(height * 0.009, 5, 14);
    final currentTimeFontSize = _clamp(width * 0.155, 52, 66);
    final baseShowTimeFontSize = _clamp(width * 0.205, 72, 92);
    final showTimeFontSize = _clamp(baseShowTimeFontSize * 1.20, 38, 215);

    // 現在時刻と再開予定を明確に別ブロックとして認識できるよう、
    // 画面高に応じた余白を確保します。短い端末では上限を抑えます。
    final gapAfterCurrentTime = _clamp(height * 0.018, 10, 20);
    // topClockRegionとperformanceTimeRegion、performanceTimeRegionと
    // commentRegionの間の余白。
    final gapBeforeShowTime = _clamp(height * 0.014, 8, 20);
    final gapAfterShowTime = _clamp(height * 0.014, 8, 20);

    final buttonWidth = _clamp(width * 0.72, 250, 330);
    final buttonHeight = _clamp(height * 0.072, 58, 70);
    final buttonFontSize = _clamp(width * 0.055, 20, 24);
    // commentRegionとcontrolsRegionの間の余白（誤操作防止）。
    final buttonTopGap = _clamp(height * 0.020, 12, 24);

    final resumeTimeFontSize = currentTimeFontSize * 0.58;
    final resumeAreaHeight =
        (labelFontSize * 1.3) + labelGap + (resumeTimeFontSize * 1.2);

    // performanceTimeRegion: 高さのみ内容から算出し、位置は
    // height全体の中央に固定します（現在時刻・再開予定・コメントの
    // 内容量には一切依存しません）。
    final performanceTimeRegionHeight =
        (labelFontSize * 1.3) + labelGap + (showTimeFontSize * 1.3);
    final performanceTimeRegionTop =
        ((height - performanceTimeRegionHeight) / 2).clamp(0.0, height);

    // controlsRegion: 画面下端からbottomPadding+buttonHeightで固定
    // （以前の数式のまま。ボタンの位置は変わりません）。
    final controlsTop = (height - bottomPadding - buttonHeight).clamp(
      0.0,
      height,
    );

    // commentRegion: performanceTimeRegionの下端からcontrolsRegionの
    // 上端までの残り。
    final commentRegionTop =
        performanceTimeRegionTop +
        performanceTimeRegionHeight +
        gapAfterShowTime;
    final commentRegionBottom = (controlsTop - buttonTopGap).clamp(0.0, height);
    final commentRegionHeight = (commentRegionBottom - commentRegionTop).clamp(
      0.0,
      height,
    );

    // topClockRegion: topPaddingからperformanceTimeRegionの上端まで。
    final topClockRegionTop = topPadding;
    final topClockRegionBottom = (performanceTimeRegionTop - gapBeforeShowTime)
        .clamp(0.0, height);
    final topClockRegionHeight = (topClockRegionBottom - topClockRegionTop)
        .clamp(0.0, height);

    // コメントは補助情報。標準・大型iPhoneでは最大8行（コメント編集
    // ダイアログの仕様と一致）、高さが不足する端末では6行・4行へ
    // 段階的に縮小します（RenderFlex overflowを避けるためのフォール
    // バックで、標準・大型・SE相当のいずれでも実測上は8行に収まって
    // います。詳細は完了報告を参照）。
    // 同じ端末を横向きにしたときのコメントと同じ算出規則です。
    // portraitのwidth == landscapeのshortestSideなので、向きによって
    // コメントの見かけの大きさが変わりません。
    final commentFontSize = _clamp(width * 0.050, 16, 20);
    final commentMaxLines = _resolveCommentMaxLines(
      candidates: const [8, 6, 4],
      fontSize: commentFontSize,
      availableHeight: commentRegionHeight,
    );

    final isOnBreak = _isOnBreakWithEndTime;

    final controlsAreVisible =
        _controlsVisible &&
        !_isTitleDialogOpen &&
        !_isSettingsOpen &&
        !_isAboutOpen &&
        !_isBreakDialogOpen;

    final topClockContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_showCurrentTime) ...[
          SizedBox(
            width: contentWidth,
            child: CurrentTimeDisplay(
              label: _t('現在時刻', 'CURRENT TIME'),
              showSeconds: _showCurrentSeconds,
              use24Hour: _use24Hour,
              labelFontSize: labelFontSize,
              timeFontSize: currentTimeFontSize,
              labelGap: labelGap,
            ),
          ),
          SizedBox(height: gapAfterCurrentTime),
        ],

        // 再開予定専用の固定高スロット。休憩中でなくても常に同じ高さを
        // 確保するため、現在時刻・公演時間の位置は休憩の開始・終了で
        // 動きません。中身が無いときはchildをnullにし、アクセシビリ
        // ティツリーに不要な非表示テキストを残しません。
        SizedBox(
          key: const ValueKey('phone-portrait-resume-area'),
          height: resumeAreaHeight,
          child: !isOnBreak
              ? null
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BreakResumeDisplay(
                    resumeAt: _breakEndsAt!,
                    use24Hour: _use24Hour,
                    isEndingSoon: _isBreakEndingSoon,
                    label: _t('再開予定', 'RESUMES AT'),
                    labelFontSize: labelFontSize,
                    timeFontSize: resumeTimeFontSize,
                    labelGap: labelGap,
                    maxWidth: contentWidth,
                  ),
                ),
        ),
      ],
    );

    final performanceTimeContent = SizedBox(
      width: contentWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _t('公演時間', 'SHOW TIME'),
            style: TextStyle(color: Colors.white70, fontSize: labelFontSize),
          ),
          SizedBox(height: labelGap),
          ShowElapsedDisplay(
            elapsed: _timerController.elapsed,
            color: _showTimeColor,
            fontSize: showTimeFontSize,
          ),
        ],
      ),
    );

    final commentContent = SizedBox(
      key: const ValueKey('phone-portrait-comment'),
      width: contentWidth,
      child: _buildShowTitle(
        fontSize: commentFontSize,
        availableWidth: contentWidth,
        maxLines: commentMaxLines,
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          children: [
            Positioned(
              key: const ValueKey('phone-portrait-top-clock-region'),
              top: topClockRegionTop,
              left: 0,
              right: 0,
              height: topClockRegionHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: topClockRegionHeight),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: topClockContent,
                  ),
                ),
              ),
            ),

            Positioned(
              key: const ValueKey('phone-portrait-performance-time-region'),
              top: performanceTimeRegionTop,
              left: 0,
              right: 0,
              height: performanceTimeRegionHeight,
              child: Center(
                key: const ValueKey('phone-portrait-show-time'),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: performanceTimeContent,
                ),
              ),
            ),

            Positioned(
              key: const ValueKey('phone-portrait-comment-region'),
              top: commentRegionTop,
              left: 0,
              right: 0,
              height: commentRegionHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: commentRegionHeight),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: commentContent,
                  ),
                ),
              ),
            ),

            Positioned(
              key: const ValueKey('phone-portrait-controls-region'),
              top: controlsTop,
              left: 0,
              right: 0,
              height: buttonHeight,
              child: Center(
                child: SizedBox(
                  key: const ValueKey('phone-portrait-button'),
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
                      breakFeatureEnabled: _breakFeatureEnabled,
                      onStartBreak: () {
                        unawaited(_startBreakFlow());
                      },
                      onResumeFromBreakNow: _resumeFromBreakNow,
                      startLabel: _t('スタート', 'START'),
                      pauseLabel: _t('一時停止', 'PAUSE'),
                      resumeLabel: _t('再開', 'RESUME'),
                      breakLabel: _t('休憩', 'Start Break'),
                      resumeFromBreakLabel: _t('今すぐ再開', 'Resume Now'),
                      resetButton: HoldResetButton(
                        width: (buttonWidth - 12) / 2,
                        height: buttonHeight,
                        fontSize: buttonFontSize,
                        onReset: _resetShowTime,
                        resetLabel: _t('リセット', 'RESET'),
                        holdLabel: _t('ホールド', 'HOLD'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // コメント表示の最大行数を、実際に確保できる高さから決定します。
  // candidatesは大きい順（例: [8, 6, 4]）に試し、fontSize*1.18*行数が
  // availableHeightの94%（安全マージン）に収まる最初の値を返します。
  // どれも収まらない場合は最後の候補（最小値）を返します。
  int _resolveCommentMaxLines({
    required List<int> candidates,
    required double fontSize,
    required double availableHeight,
  }) {
    const lineHeightMultiplier = 1.18;
    final usableHeight = availableHeight * 0.94;
    for (final lines in candidates) {
      if (fontSize * lineHeightMultiplier * lines <= usableHeight) {
        return lines;
      }
    }
    return candidates.last;
  }

  // ---------------------------------------------------------------------------
  // macOS等デスクトップウィンドウ
  // コメント → 現在時刻（休憩中は右に再開予定を横並び） → 公演時間 → 操作ボタン
  // ボタン領域は先に高さを確保し、残りをExpandedで時計類に配分することで、
  // コメントの有無・長さに関わらず「今すぐ再開」が画面外へ押し出されないようにします。
  // ---------------------------------------------------------------------------

  Widget _buildDesktopLayout({required double width, required double height}) {
    final horizontalPadding = _clamp(width * 0.050, 20, 72);
    final topPadding = _clamp(height * 0.030, 16, 32);
    final bottomPadding = _clamp(height * 0.030, 20, 40);

    final contentWidth = width - (horizontalPadding * 2);

    // 十分な横幅がある場合のみ、現在時刻と再開予定を横並びにします。
    // 幅が足りないウィンドウでは縦積みへフォールバックします。
    final isWideEnoughForRow = width >= 640;
    final rowGap = _clamp(width * 0.05, 24, 80);

    final commentFontSize = _clamp(contentWidth * 0.026, 18, 30);
    const commentMaxLines = 4;

    final labelFontSize = _clamp(contentWidth * 0.018, 14, 22);
    final labelGap = _clamp(height * 0.010, 6, 14);
    final currentTimeFontSize = _clamp(contentWidth * 0.100, 48, 130);
    final showTimeFontSize = _clamp(contentWidth * 0.135, 68, 200);
    final blockGap = _clamp(height * 0.018, 10, 24);

    // 休憩中の「再開予定」表示専用のサイズ。現在時刻・公演時間の文字サイズ
    // には影響させず、再開予定のラベル・時刻のみを拡大して視認性を高めます。
    final resumeLabelFontSize = labelFontSize * 1.2;
    final resumeTimeFontSize = currentTimeFontSize * 0.68;

    final buttonHeight = _clamp(height * 0.090, 54, 82);
    final buttonWidth = _clamp(width * 0.26, 220, 340);
    final buttonFontSize = _clamp(width * 0.022, 18, 30);
    final buttonTopGap = _clamp(height * 0.024, 14, 28);

    final isOnBreak = _isOnBreakWithEndTime;

    final controlsAreVisible =
        _controlsVisible &&
        !_isTitleDialogOpen &&
        !_isSettingsOpen &&
        !_isAboutOpen &&
        !_isBreakDialogOpen;

    final currentTimeBlock = _showCurrentTime
        ? CurrentTimeDisplay(
            label: _t('現在時刻', 'CURRENT TIME'),
            showSeconds: _showCurrentSeconds,
            use24Hour: _use24Hour,
            labelFontSize: labelFontSize,
            timeFontSize: currentTimeFontSize,
            labelGap: labelGap,
          )
        : const SizedBox.shrink();

    Widget clockArea = currentTimeBlock;

    if (isOnBreak) {
      final resumeBlock = BreakResumeDisplay(
        resumeAt: _breakEndsAt!,
        use24Hour: _use24Hour,
        isEndingSoon: _isBreakEndingSoon,
        label: _t('再開予定', 'RESUMES AT'),
        labelFontSize: resumeLabelFontSize,
        timeFontSize: resumeTimeFontSize,
        labelGap: labelGap,
        maxWidth: isWideEnoughForRow
            ? (contentWidth - rowGap) / 2
            : contentWidth,
        normalColor: const Color(0xFFFFA726),
      );

      clockArea = isWideEnoughForRow
          ? Row(
              key: const ValueKey('desktop-clock-row'),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: currentTimeBlock,
                  ),
                ),
                SizedBox(width: rowGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: resumeBlock,
                  ),
                ),
              ],
            )
          : Column(
              key: const ValueKey('desktop-clock-column'),
              mainAxisSize: MainAxisSize.min,
              children: [
                currentTimeBlock,
                SizedBox(height: blockGap),
                resumeBlock,
              ],
            );
    }

    final children = <Widget>[
      Expanded(
        key: const ValueKey('desktop-comment'),
        flex: 3,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: _buildShowTitle(
              fontSize: commentFontSize,
              availableWidth: contentWidth,
              maxLines: commentMaxLines,
            ),
          ),
        ),
      ),

      SizedBox(
        key: const ValueKey('desktop-gap-after-comment'),
        height: blockGap,
      ),

      Expanded(
        key: const ValueKey('desktop-clock-area'),
        flex: 4,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: contentWidth, child: clockArea),
        ),
      ),

      SizedBox(
        key: const ValueKey('desktop-gap-after-clock'),
        height: blockGap,
      ),

      Expanded(
        key: const ValueKey('desktop-show-time'),
        flex: 5,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
        ),
      ),

      SizedBox(
        key: const ValueKey('desktop-gap-before-button'),
        height: buttonTopGap,
      ),

      SizedBox(
        key: const ValueKey('desktop-button'),
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
            breakFeatureEnabled: _breakFeatureEnabled,
            onStartBreak: () {
              unawaited(_startBreakFlow());
            },
            onResumeFromBreakNow: _resumeFromBreakNow,
            startLabel: _t('スタート', 'START'),
            pauseLabel: _t('一時停止', 'PAUSE'),
            resumeLabel: _t('再開', 'RESUME'),
            breakLabel: _t('休憩', 'Start Break'),
            resumeFromBreakLabel: _t('今すぐ再開', 'Resume Now'),
            resetButton: HoldResetButton(
              width: (buttonWidth - 12) / 2,
              height: buttonHeight,
              fontSize: buttonFontSize,
              onReset: _resetShowTime,
              resetLabel: _t('リセット', 'RESET'),
              holdLabel: _t('ホールド', 'HOLD'),
            ),
          ),
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Column(children: children),
    );
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
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_isTitleDialogOpen ||
                _isSettingsOpen ||
                _isAboutOpen ||
                _isBreakDialogOpen) {
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

                    // iPad等のタブレット端末（macOS/Windows/Linuxのデスクトップ
                    // ウィンドウは対象外）。shortestSide >= 600を目安に判定します。
                    final isTabletFormFactor =
                        !kIsWeb && !isDesktopPlatform && !isPhone;
                    final isTabletPortrait =
                        isTabletFormFactor && height >= width;
                    final isTabletLandscape =
                        isTabletFormFactor && width > height;

                    if (isTabletLandscape) {
                      return _buildTabletLandscapeLayout(
                        width: width,
                        height: height,
                      );
                    }

                    if (isTabletPortrait) {
                      return _buildTabletPortraitLayout(
                        width: width,
                        height: height,
                      );
                    }

                    // macOS等のデスクトップウィンドウは専用レイアウトを使い、
                    // タイトル・コメントの長さに関わらず「今すぐ再開」ボタンが
                    // 画面外へ押し出されないようにします。
                    if (isDesktopPlatform && !isKeyboardVisible) {
                      return _buildDesktopLayout(width: width, height: height);
                    }

                    // iPhone縦画面はiPad縦画面と同じ情報順序（現在時刻→再開予定
                    // →公演時間→コメント→ボタン）の専用レイアウトを使います。
                    // コメント編集は別モーダルダイアログで行われるため、このメイン
                    // 画面自体でソフトウェアキーボードを気にする必要はありません
                    // が、念のため同じガードを付けています。
                    if (isPhonePortrait && !isKeyboardVisible) {
                      return _buildPhonePortraitLayout(
                        width: width,
                        height: height,
                      );
                    }

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

                    // 休憩中の「再開予定」表示の上下余白。
                    // 公演時間表示を不必要に下へ押しすぎないよう控えめに設定します。
                    final breakResumeGap = _clamp(
                      height *
                          (isPhoneLandscape
                              ? 0.020
                              : isPhonePortrait
                              ? 0.014
                              : isCompactHeight
                              ? 0.012
                              : 0.020),
                      6,
                      18,
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
                        !_isAboutOpen &&
                        !_isBreakDialogOpen;

                    // -----------------------------------------------------------
                    // iPhone横画面・左側
                    // コメント＋操作ボタン
                    // -----------------------------------------------------------
                    //
                    // このパネルは実際にはRowのCrossAxisAlignment.center
                    // （デフォルト）によって全体がまとめて縦方向中央寄せ
                    // されています（内側のColumnはSingleChildScrollView
                    // による無限高さの中で完全に中身の高さへ縮むため、
                    // Column自身のmainAxisAlignment.centerは実効しません）。
                    // 未入力時の鉛筆アイコンだけを右上の歯車アイコンに
                    // 近い高さへ寄せるため、コメントと操作ボタンをStackで
                    // 個別に配置し、操作ボタンの位置は中央寄せ時と同じ式
                    // （centeringTop + コメント予約高 + 間隔）で計算する
                    // ことで、これまでどおり動かさないようにしています。

                    final landscapeTitleAvailableWidth =
                        landscapeLeftWidth - 8 < portraitEquivalentTitleWidth
                        ? landscapeLeftWidth - 8
                        : portraitEquivalentTitleWidth;

                    final landscapeTitleReservedHeight =
                        ShowTitle.reservedHeightFor(
                          fontSize: titleFontSize,
                          maxLines: 8,
                        );

                    final landscapePanelHeight = contentMinHeight < 0
                        ? 0.0
                        : contentMinHeight;

                    final landscapeGroupHeight =
                        landscapeTitleReservedHeight +
                        buttonTopGap +
                        buttonHeight;

                    // Rowが中央寄せしていた場合と同じ余白（センタリングで
                    // 生じる上側の余白）。
                    final landscapeCenteringTop =
                        ((landscapePanelHeight - landscapeGroupHeight) / 2)
                            .clamp(0.0, double.infinity);

                    // 鉛筆アイコンは歯車アイコンに近い高さまで引き上げます
                    // が、中央寄せの余白より下がることはありません。
                    const landscapeTitleTopInset = 4.0;
                    final landscapeTitleTop =
                        landscapeCenteringTop < landscapeTitleTopInset
                        ? landscapeCenteringTop
                        : landscapeTitleTopInset;

                    final landscapeControlsPanel = SizedBox(
                      height: landscapePanelHeight,
                      child: Stack(
                        children: [
                          Positioned(
                            top: landscapeTitleTop,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _buildShowTitle(
                                fontSize: titleFontSize,
                                availableWidth: landscapeTitleAvailableWidth,
                                maxLines: 8,
                              ),
                            ),
                          ),

                          Positioned(
                            top:
                                landscapeCenteringTop +
                                landscapeTitleReservedHeight +
                                buttonTopGap,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: SizedBox(
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
                                    breakFeatureEnabled: _breakFeatureEnabled,
                                    onStartBreak: () {
                                      unawaited(_startBreakFlow());
                                    },
                                    onResumeFromBreakNow: _resumeFromBreakNow,
                                    startLabel: _t('スタート', 'START'),
                                    pauseLabel: _t('一時停止', 'PAUSE'),
                                    resumeLabel: _t('再開', 'RESUME'),
                                    breakLabel: _t('休憩', 'Start Break'),
                                    resumeFromBreakLabel: _t(
                                      '今すぐ再開',
                                      'Resume Now',
                                    ),
                                    resetButton: HoldResetButton(
                                      width: (buttonWidth - 12) / 2,
                                      height: buttonHeight,
                                      fontSize: buttonFontSize,
                                      onReset: _resetShowTime,
                                      resetLabel: _t('リセット', 'RESET'),
                                      holdLabel: _t('ホールド', 'HOLD'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

                        Transform.translate(
                          key: const ValueKey(
                            'phone-landscape-resume-position',
                          ),
                          // 再開予定だけを少し上へ寄せます。レイアウト上の
                          // 占有高は変えないため、公演時間や操作ボタンの位置
                          // には影響しません。
                          offset: Offset(0, -_clamp(height * 0.025, 8, 12)),
                          child: _buildBreakResumeArea(
                            currentTimeFontSize: currentTimeFontSize,
                            labelFontSize: labelFontSize,
                            labelGap: labelGap,
                            outerGap: breakResumeGap,
                            maxWidth: landscapeRightWidth,
                          ),
                        ),

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

                                          _buildBreakResumeArea(
                                            currentTimeFontSize:
                                                currentTimeFontSize,
                                            labelFontSize: labelFontSize,
                                            labelGap: labelGap,
                                            outerGap: breakResumeGap,
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

                                          controlsVisible: controlsAreVisible,

                                          width: buttonWidth,

                                          height: buttonHeight,

                                          fontSize: buttonFontSize,

                                          onStart: _startShowTime,

                                          onPause: _pauseShowTime,

                                          onResume: _resumeShowTime,

                                          breakFeatureEnabled:
                                              _breakFeatureEnabled,

                                          onStartBreak: () {
                                            unawaited(_startBreakFlow());
                                          },

                                          onResumeFromBreakNow:
                                              _resumeFromBreakNow,

                                          startLabel: _t('スタート', 'START'),

                                          pauseLabel: _t('一時停止', 'PAUSE'),

                                          resumeLabel: _t('再開', 'RESUME'),

                                          breakLabel: _t('休憩', 'Start Break'),

                                          resumeFromBreakLabel: _t(
                                            '今すぐ再開',
                                            'Resume Now',
                                          ),

                                          resetButton: HoldResetButton(
                                            width: (buttonWidth - 12) / 2,

                                            height: buttonHeight,

                                            fontSize: buttonFontSize,

                                            onReset: _resetShowTime,

                                            resetLabel: _t('リセット', 'RESET'),

                                            holdLabel: _t('ホールド', 'HOLD'),
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
      bindings: _isTitleDialogOpen || _isBreakDialogOpen
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

class _BreakConfirmDialog extends StatelessWidget {
  const _BreakConfirmDialog({
    required this.language,
    required this.breakDuration,
    required this.resumeAt,
    required this.formatTime,
  });

  final AppLanguage language;
  final Duration breakDuration;
  final DateTime resumeAt;
  final String Function(DateTime time) formatTime;

  String _t(String japanese, String english) {
    return language == AppLanguage.japanese ? japanese : english;
  }

  String get _durationLabel {
    final hours = breakDuration.inHours;
    final minutes = breakDuration.inMinutes.remainder(60);

    if (language == AppLanguage.japanese) {
      final buffer = StringBuffer();
      if (hours > 0) {
        buffer.write('$hours時間');
      }
      if (minutes > 0 || hours == 0) {
        buffer.write('$minutes分');
      }
      return buffer.toString();
    }

    final parts = <String>[
      if (hours > 0) '${hours}h',
      if (minutes > 0 || hours == 0) '${minutes}m',
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final resumeLabel = formatTime(resumeAt);

    return Dialog(
      backgroundColor: const Color(0xFF171717),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t('休憩', 'Start Break'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _t(
                  '$_durationLabel休憩します。再開は$resumeLabelです。',
                  'Break for $_durationLabel. Resumes at $resumeLabel.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_t('キャンセル', 'Cancel')),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: const Color(0xFFFF9100),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _t('休憩', 'Start Break'),
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
