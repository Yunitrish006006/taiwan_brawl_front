import '../config/app_configuration.dart';

class AppConstants {
  static const String appName = '鬼島亂鬥';

  // 使用 --dart-define=API_BASE_URL 覆蓋，例如:
  // flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787
  static String get apiBaseUrl => AppConfiguration.environment.apiBaseUrl;

  /// Enables direct P2P chat while retaining the server relay fallback.
  /// Keep disabled by default until two-device WebRTC runtime validation is
  /// completed in the target deployment environment.
  static bool get p2pChatEnabled => AppConfiguration.environment.p2pChatEnabled;

  // 上線時請替換成自己的 Google OAuth Web Client ID。
  static String get googleWebClientId =>
      AppConfiguration.environment.googleWebClientId;

  // 後端若需要 Google ID token，可讓 mobile / web 共用同一個 server client ID。
  static String get googleServerClientId =>
      AppConfiguration.environment.googleServerClientId;
}
