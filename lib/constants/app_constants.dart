class AppConstants {
  static const String appName = 'Taiwan Brawl Portal';

  // 使用 --dart-define=API_BASE_URL 覆蓋，例如:
  // flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  // 上線時請替換成自己的 Google OAuth Web Client ID。
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
