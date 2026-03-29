import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._apiClient);

  final ApiClient _apiClient;
  AppUser? _user;

  Future<void> updateLocale(String locale) async {
    await _apiClient.putJson('/api/users/locale', {'locale': locale});
    await refreshMe(silent: true);
  }

  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    await refreshMe(silent: true);
  }

  Future<void> refreshMe({bool silent = false}) async {
    _setLoading(!silent);
    try {
      final res = await _apiClient.getJson('/api/me');
      _user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    } catch (_) {
      _user = null;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> verifyGoogleToken(String idToken) async {
    _setLoading(true);
    try {
      final res = await _apiClient.postJson('/api/google-login', {
        'id_token': idToken,
      });
      _saveUser(res);
    } catch (_) {
      _user = null;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    required String name,
    required String bio,
    required String avatarSource,
    required String customAvatarUrl,
  }) async {
    await _apiClient.putJson('/api/users/me', {
      'name': name,
      'bio': bio,
      'avatar_source': avatarSource,
      'custom_avatar_url': customAvatarUrl,
    });
    await refreshMe(silent: true);
  }

  Future<void> updateThemeMode(String themeMode) async {
    await _apiClient.putJson('/api/users/theme-mode', {
      'theme_mode': themeMode,
    });
    await refreshMe(silent: true);
  }

  Future<void> updateFontSizeScale(double scale) async {
    await _apiClient.putJson('/api/users/ui-preferences', {
      'font_size_scale': scale,
    });
    await refreshMe(silent: true);
  }

  Future<void> logout() async {
    try {
      await _apiClient.postJson('/api/logout', {});
    } catch (_) {
      // Ignore API failures when logging out locally.
    }
    _user = null;
    notifyListeners();
  }

  void _saveUser(Map<String, dynamic> response) {
    _user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
