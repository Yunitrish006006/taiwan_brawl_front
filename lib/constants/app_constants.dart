class AppConstants {
  static const String appName = '鬼島亂鬥';

  // 使用 --dart-define=API_BASE_URL 覆蓋，例如:
  // flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://taiwan-brawl-api.yunitrish0419.workers.dev',
  );

  // 上線時請替換成自己的 Google OAuth Web Client ID。
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '310421071956-1ctfspu1f772ehkatigsgd2vq1ui4bks.apps.googleusercontent.com',
  );

  // 後端若需要 Google ID token，可讓 mobile / web 共用同一個 server client ID。
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '310421071956-1ctfspu1f772ehkatigsgd2vq1ui4bks.apps.googleusercontent.com',
  );
}
