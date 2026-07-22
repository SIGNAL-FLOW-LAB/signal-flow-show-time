import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'platform/platform_support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
  }

  runApp(const ShowTimeApp());
}
