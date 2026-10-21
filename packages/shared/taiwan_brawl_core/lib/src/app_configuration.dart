/// Runtime values supplied by an application's composition root.
///
/// This type intentionally contains deployment configuration and feature
/// switches only. Session tokens, provider API keys, and device secrets belong
/// to credential/key ports or server-side environment injection.
class AppConfiguration {
  const AppConfiguration({
    required this.apiBaseUrl,
    required this.googleWebClientId,
    required this.googleServerClientId,
    required this.p2pChatEnabled,
    this.peerVerificationEnabled = false,
    this.previewMode = false,
    this.androidBannerAdUnitId = 'ca-app-pub-7069919778314728/8321532705',
    this.iosBannerAdUnitId = 'ca-app-pub-7069919778314728/9690454693',
    this.androidInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712',
    this.iosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910',
    this.defaultLlmBaseUrl = 'https://api.openai.com/v1',
    this.defaultLlmModel = 'gpt-4o-mini',
  });

  static const AppConfiguration environment = AppConfiguration(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://taiwan-brawl-api.yunitrish0419.workers.dev',
    ),
    // OAuth client IDs are public identifiers, not session or provider secrets.
    // Keep the existing deployment defaults for compatibility; deployments
    // can override them with dart-defines.
    googleWebClientId: String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '310421071956-1ctfspu1f772ehkatigsgd2vq1ui4bks.apps.googleusercontent.com',
    ),
    googleServerClientId: String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue:
          '310421071956-1ctfspu1f772ehkatigsgd2vq1ui4bks.apps.googleusercontent.com',
    ),
    p2pChatEnabled: bool.fromEnvironment(
      'P2P_CHAT_ENABLED',
      defaultValue: false,
    ),
    peerVerificationEnabled: bool.fromEnvironment(
      'PEER_VERIFICATION_ENABLED',
      defaultValue: false,
    ),
    previewMode: bool.fromEnvironment(
      'PREVIEW_MODE',
      defaultValue: false,
    ),
    androidBannerAdUnitId: String.fromEnvironment(
      'ANDROID_BANNER_AD_UNIT_ID',
      defaultValue: 'ca-app-pub-7069919778314728/8321532705',
    ),
    iosBannerAdUnitId: String.fromEnvironment(
      'IOS_BANNER_AD_UNIT_ID',
      defaultValue: 'ca-app-pub-7069919778314728/9690454693',
    ),
    androidInterstitialAdUnitId: String.fromEnvironment(
      'ANDROID_INTERSTITIAL_AD_UNIT_ID',
      defaultValue: 'ca-app-pub-3940256099942544/1033173712',
    ),
    iosInterstitialAdUnitId: String.fromEnvironment(
      'IOS_INTERSTITIAL_AD_UNIT_ID',
      defaultValue: 'ca-app-pub-3940256099942544/4411468910',
    ),
    defaultLlmBaseUrl: String.fromEnvironment(
      'DEFAULT_LLM_BASE_URL',
      defaultValue: 'https://api.openai.com/v1',
    ),
    defaultLlmModel: String.fromEnvironment(
      'DEFAULT_LLM_MODEL',
      defaultValue: 'gpt-4o-mini',
    ),
  );

  final String apiBaseUrl;
  final String googleWebClientId;
  final String googleServerClientId;
  final bool p2pChatEnabled;
  final bool peerVerificationEnabled;
  final bool previewMode;
  final String androidBannerAdUnitId;
  final String iosBannerAdUnitId;
  final String androidInterstitialAdUnitId;
  final String iosInterstitialAdUnitId;
  final String defaultLlmBaseUrl;
  final String defaultLlmModel;
}
