import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/show_time_menu_controller.dart';
import 'models/app_info.dart';
import 'models/app_language.dart';
import 'platform/platform_support.dart';
import 'screens/show_time_screen.dart';

class ShowTimeApp extends StatefulWidget {
  const ShowTimeApp({super.key});

  @override
  State<ShowTimeApp> createState() => _ShowTimeAppState();
}

class _ShowTimeAppState extends State<ShowTimeApp> {
  late final ShowTimeMenuController _menuController;

  @override
  void initState() {
    super.initState();
    _menuController = ShowTimeMenuController();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  String _text(AppLanguage language, String japanese, String english) {
    return language == AppLanguage.japanese ? japanese : english;
  }

  Widget _buildApp() {
    return MaterialApp(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      home: ShowTimeScreen(menuController: _menuController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = _buildApp();

    if (!isMacOSPlatform) {
      return app;
    }

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: _menuController.language,
      builder: (context, language, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _menuController.alwaysOnTop,
          builder: (context, alwaysOnTop, _) {
            return PlatformMenuBar(
              menus: [
                PlatformMenu(
                  label: AppInfo.appName,
                  menus: [
                    PlatformMenuItem(
                      label: _text(
                        language,
                        'SIGNAL FLOW Show Timeについて',
                        'About SIGNAL FLOW Show Time',
                      ),
                      onSelected: () {
                        _menuController.openAbout?.call();
                      },
                    ),
                    PlatformMenuItemGroup(
                      members: [
                        PlatformMenuItem(
                          label: _text(language, '設定…', 'Preferences…'),
                          shortcut: const SingleActivator(
                            LogicalKeyboardKey.comma,
                            meta: true,
                          ),
                          onSelected: () {
                            _menuController.openSettings?.call();
                          },
                        ),
                      ],
                    ),
                    PlatformMenuItemGroup(
                      members: [
                        PlatformMenu(
                          label: _text(language, '表示言語', 'Display Language'),
                          menus: [
                            PlatformMenuItem(
                              label: language == AppLanguage.japanese
                                  ? '✓ 日本語'
                                  : '日本語',
                              onSelected: () {
                                _menuController.setLanguage?.call(
                                  AppLanguage.japanese,
                                );
                              },
                            ),
                            PlatformMenuItem(
                              label: language == AppLanguage.english
                                  ? '✓ English'
                                  : 'English',
                              onSelected: () {
                                _menuController.setLanguage?.call(
                                  AppLanguage.english,
                                );
                              },
                            ),
                          ],
                        ),
                        PlatformMenuItem(
                          label: alwaysOnTop
                              ? _text(language, '✓ 常に最前面に表示', '✓ Always on Top')
                              : _text(language, '常に最前面に表示', 'Always on Top'),
                          onSelected: () {
                            _menuController.toggleAlwaysOnTop?.call();
                          },
                        ),
                      ],
                    ),
                    PlatformMenuItemGroup(
                      members: [
                        PlatformMenuItem(
                          label: _text(
                            language,
                            '開始／一時停止／再開',
                            'Start / Pause / Resume',
                          ),
                          shortcut: const SingleActivator(
                            LogicalKeyboardKey.space,
                          ),
                          onSelected: () {
                            _menuController.primaryAction?.call();
                          },
                        ),
                      ],
                    ),
                    PlatformMenuItem(
                      label: language == AppLanguage.japanese
                          ? 'SIGNAL FLOW Show Timeを終了'
                          : 'Quit SIGNAL FLOW Show Time',
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyQ,
                        meta: true,
                      ),
                      onSelected: SystemNavigator.pop,
                    ),
                  ],
                ),
              ],
              child: app,
            );
          },
        );
      },
    );
  }
}
