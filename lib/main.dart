import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'platform/platform_support.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();

    final sessionService = SessionService();
    final savedWindowState = await sessionService.loadWindowState();

    await windowManager.waitUntilReadyToShow(const WindowOptions(), () async {
      if (savedWindowState != null) {
        await windowManager.setSize(savedWindowState.size);
        await windowManager.setPosition(savedWindowState.position);
      }

      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ShowTimeApp());
}
