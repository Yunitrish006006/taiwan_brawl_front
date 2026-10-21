import 'api_client.dart';

abstract interface class AuthRemoteSource {
  Future<Map<String, dynamic>> updateLocale(String locale);

  Future<Map<String, dynamic>> loadCurrentUser();

  Future<Map<String, dynamic>> verifyGoogleToken(String idToken);

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> uploadAvatarImage(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> deleteAvatarImage();

  Future<Map<String, dynamic>> updateThemeMode(String themeMode);

  Future<Map<String, dynamic>> updateUiPreferences(double scale);

  Future<Map<String, dynamic>> updateLlmBotSettings(
    Map<String, dynamic> payload,
  );

  Future<Map<String, dynamic>> logout();

  Future<void> clearSession();
}

class ServerAuthRemoteSource implements AuthRemoteSource {
  const ServerAuthRemoteSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> updateLocale(String locale) {
    return _apiClient.putJson('/api/users/locale', {'locale': locale});
  }

  @override
  Future<Map<String, dynamic>> loadCurrentUser() =>
      _apiClient.getJson('/api/me');

  @override
  Future<Map<String, dynamic>> verifyGoogleToken(String idToken) {
    return _apiClient.postJson('/api/google-login', {'id_token': idToken});
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) {
    return _apiClient.putJson('/api/users/me', payload);
  }

  @override
  Future<Map<String, dynamic>> uploadAvatarImage(Map<String, dynamic> payload) {
    return _apiClient.postJson('/api/users/me/avatar-image', payload);
  }

  @override
  Future<Map<String, dynamic>> deleteAvatarImage() {
    return _apiClient.deleteJson('/api/users/me/avatar-image');
  }

  @override
  Future<Map<String, dynamic>> updateThemeMode(String themeMode) {
    return _apiClient.putJson('/api/users/theme-mode', {
      'theme_mode': themeMode,
    });
  }

  @override
  Future<Map<String, dynamic>> updateUiPreferences(double scale) {
    return _apiClient.putJson('/api/users/ui-preferences', {
      'font_size_scale': scale,
    });
  }

  @override
  Future<Map<String, dynamic>> updateLlmBotSettings(
    Map<String, dynamic> payload,
  ) {
    return _apiClient.putJson('/api/users/llm-bot-settings', payload);
  }

  @override
  Future<Map<String, dynamic>> logout() =>
      _apiClient.postJson('/api/logout', {});

  @override
  Future<void> clearSession() => _apiClient.clearSession();
}
