import 'package:flutter/material.dart';

import '../models/app_user.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeModeText = 'system';

  void syncFromUser(AppUser? user) {
    final next = user?.themeMode ?? 'system';
    if (_themeModeText == next) return;
    _themeModeText = next;
    notifyListeners();
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
