import 'package:flutter/material.dart';

import '../models/app_user.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeModeText = 'system';
  int? _userId;
  String? _remembered;

  void syncFromUser(AppUser? user) {
    // 只在 user id 變動時才同步，避免 API refresh 覆蓋本地預覽
    if (user?.id == _userId) return;
    _userId = user?.id;
    final next = user?.themeMode ?? 'system';
    if (_themeModeText == next) return;
    _themeModeText = next;
    notifyListeners();
  }

  void setThemeModeText(String value) {
    if (_themeModeText == value) return;
    _themeModeText = value;
    notifyListeners();
  }

  void rememberCurrent() {
    _remembered = _themeModeText;
  }

  void restoreRemembered() {
    if (_remembered != null) {
      _themeModeText = _remembered!;
      notifyListeners();
      _remembered = null;
    }
  }

  String get themeModeText => _themeModeText;

  ThemeMode get themeMode {
    switch (_themeModeText) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
