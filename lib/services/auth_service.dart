import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../config/app_configuration.dart';
import 'api_client.dart';
import 'auth_remote_source.dart';
import 'service_utils.dart';

class AuthService extends ChangeNotifier {
  AuthService(
    ApiClient apiClient, {
    AuthRemoteSource? remoteSource,
    AppConfiguration? configuration,
  }) : _remoteSource = remoteSource ?? ServerAuthRemoteSource(apiClient),
       _configuration = configuration ?? AppConfiguration.environment;

  final AuthRemoteSource _remoteSource;
  final AppConfiguration _configuration;
  AppUser? _user;
  bool _hasInitialized = false;

  Future<void> updateLocale(String locale) async {
    await _remoteSource.updateLocale(locale);
    await refreshMe(silent: true);
  }

  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get hasInitialized => _hasInitialized;

  AppUser _readUser(Map<String, dynamic> response) {
    return jsonModel(
      response,
      'user',
      (json) => AppUser.fromJson(json, configuration: _configuration),
    );
  }

  Future<void> _writeAndRefresh(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    await request();
    await refreshMe(silent: true);
  }

  Future<void> init() async {
    await refreshMe(silent: true);
  }

  Future<void> refreshMe({bool silent = false}) async {
    _setLoading(!silent);
    try {
      final res = await _remoteSource.loadCurrentUser();
      _user = _readUser(res);
    } catch (_) {
      _user = null;
    } finally {
      _hasInitialized = true;
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> verifyGoogleToken(String idToken) async {
    _setLoading(true);
    try {
      final res = await _remoteSource.verifyGoogleToken(idToken);
      _hasInitialized = true;
      _saveUser(res);
    } catch (_) {
      await _remoteSource.clearSession();
      _user = null;
      _hasInitialized = true;
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
    await _writeAndRefresh(
      () => _remoteSource.updateProfile({
        'name': name,
        'bio': bio,
        'avatar_source': avatarSource,
        'custom_avatar_url': customAvatarUrl,
      }),
    );
  }

  Future<void> uploadAvatarImage({
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    await _writeAndRefresh(
      () => _remoteSource.uploadAvatarImage({
        'bytesBase64': bytesBase64,
        'contentType': contentType,
        'fileName': fileName,
      }),
    );
  }

  Future<void> deleteAvatarImage() async {
    await _writeAndRefresh(() => _remoteSource.deleteAvatarImage());
  }

  Future<void> updateThemeMode(String themeMode) async {
    await _writeAndRefresh(() => _remoteSource.updateThemeMode(themeMode));
  }

  Future<void> updateFontSizeScale(double scale) async {
    await _writeAndRefresh(() => _remoteSource.updateUiPreferences(scale));
  }

  Future<void> updateLlmBotSettings({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    await _writeAndRefresh(
      () => _remoteSource.updateLlmBotSettings({
        'base_url': baseUrl,
        'model': model,
        'api_key': apiKey,
      }),
    );
  }

  Future<void> logout() async {
    try {
      await _remoteSource.logout();
    } catch (_) {
      // Ignore API failures when logging out locally.
    }
    await _remoteSource.clearSession();
    _user = null;
    _hasInitialized = true;
    notifyListeners();
  }

  void _saveUser(Map<String, dynamic> response) {
    _user = _readUser(response);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
