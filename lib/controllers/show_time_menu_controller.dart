import 'package:flutter/foundation.dart';

import '../models/app_language.dart';

class ShowTimeMenuController {
  final ValueNotifier<AppLanguage> language = ValueNotifier<AppLanguage>(
    AppLanguage.japanese,
  );
  final ValueNotifier<bool> alwaysOnTop = ValueNotifier<bool>(false);

  VoidCallback? openSettings;
  VoidCallback? openAbout;
  VoidCallback? toggleAlwaysOnTop;
  VoidCallback? primaryAction;
  ValueChanged<AppLanguage>? setLanguage;

  void dispose() {
    language.dispose();
    alwaysOnTop.dispose();
  }
}
