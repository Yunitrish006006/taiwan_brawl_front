import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/app_user.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._apiClient);

  final ApiClient _apiClient;
  bool _googleInitialized = false;
  AppUser? _user;

  Future<void> updateLocale(String locale) async {
    await _apiClient.putJson('/api/users/locale', {
      'locale': locale,
    });
    await refreshMe(silent: true);
  }
  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    _apiClient.updateSessionId(sessionId);

    if (sessionId != null && sessionId.isNotEmpty) {
      await refreshMe(silent: true);
    }
  }

  Future<void> refreshMe({bool silent = false}) async {
    _setLoading(!silent);
    try {
      final res = await _apiClient.getJson('/api/me');
      _user = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    } catch (_) {
      _user = null;
      await _clearSession();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setLoading(true);
    try {
      final res = await _apiClient.postJson('/api/login', {
        'email': email,
        'password': password,
      });
      await _saveSessionAndUser(res);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      await _apiClient.postJson('/api/register', {
        'name': name,
        'email': email,
        'password': password,
      });
    } finally {
      _setLoading(false);
    }
  }

  Future<void> googleLogin() async {
    _setLoading(true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await googleSignIn.initialize(
          clientId: AppConstants.googleWebClientId.isEmpty
              ? null
              : AppConstants.googleWebClientId,
        );
        _googleInitialized = true;
      }

      final account = await googleSignIn.authenticate();

      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException('Failed to get Google id token');
      }

      final res = await _apiClient.postJson('/api/google-login', {
        'id_token': idToken,
      });
      await _saveSessionAndUser(res);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {
    await _apiClient.putJson('/api/users/me', {'name': name, 'bio': bio});
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
    await _clearSession();
    notifyListeners();
  }

  Future<void> _saveSessionAndUser(Map<String, dynamic> response) async {
    final sessionId = response['session_id'] as String?;
    if (sessionId != null && sessionId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_id', sessionId);
      _apiClient.updateSessionId(sessionId);
    }

    _user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    _apiClient.updateSessionId(null);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
