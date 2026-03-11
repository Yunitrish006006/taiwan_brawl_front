import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class UiSettingsProvider extends ChangeNotifier {
  double _fontScale = 1.0;

  double get fontScale => _fontScale;

  void syncFromUser(AppUser? user) {
    final next = user?.fontSizeScale ?? 1.0;
    if (_fontScale == next) return;
    _fontScale = next;
    notifyListeners();
  }
}
