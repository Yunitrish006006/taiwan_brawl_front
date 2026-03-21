import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class UiSettingsProvider extends ChangeNotifier {
  double _fontScale = 1.0;
  int? _userId;
  double? _remembered;

  double get fontScale => _fontScale;

  void syncFromUser(AppUser? user) {
    // 只在 user id 變動時才同步，避免 API refresh 覆蓋本地預覽
    if (user?.id == _userId) return;
    _userId = user?.id;
    final next = user?.fontSizeScale ?? 1.0;
    if (_fontScale == next) return;
    _fontScale = next;
    notifyListeners();
  }

  void setFontScale(double value) {
    final next = value.clamp(0.8, 1.6).toDouble();
    if (_fontScale == next) return;
    _fontScale = next;
    notifyListeners();
  }

  void rememberCurrent() {
    _remembered = _fontScale;
  }

  void restoreRemembered() {
    if (_remembered != null) {
      _fontScale = _remembered!;
      notifyListeners();
      _remembered = null;
    }
  }
}
