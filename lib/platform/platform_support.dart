import 'package:flutter/foundation.dart';

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
