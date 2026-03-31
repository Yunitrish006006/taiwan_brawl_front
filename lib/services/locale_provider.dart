import 'package:flutter/foundation.dart';

import '../constants/locale_catalog.dart';
import '../models/app_user.dart';

extension LocaleTranslationMap on Map<String, String> {
  String text(String key) => this[key] ?? key;
}

class LocaleProvider extends ChangeNotifier {
  String _locale = defaultLocaleCode;
  int? _userId;
  String? _remembered;

  Map<String, String> get translation => translationForLocale(_locale);

  String get locale => _locale;

  void syncFromUser(AppUser? user) {
    if (user?.id == _userId) return;
    _userId = user?.id;
    final next = user?.locale ?? defaultLocaleCode;
    if (_locale == next) return;
    _locale = next;
    notifyListeners();
  }

  void setLocale(String value) {
    if (_locale == value) return;
    _locale = value;
    notifyListeners();
  }

  void rememberCurrent() {
    _remembered = _locale;
  }

  void restoreRemembered() {
    if (_remembered != null) {
      _locale = _remembered!;
      notifyListeners();
      _remembered = null;
    }
  }
}
