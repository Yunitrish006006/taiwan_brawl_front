import 'package:test/test.dart';
import 'package:taiwan_brawl_core/taiwan_brawl_core.dart';

void main() {
  test('keeps runtime configuration separate from credentials', () {
    const configuration = AppConfiguration(
      apiBaseUrl: 'https://example.test',
      googleWebClientId: 'web-client',
      googleServerClientId: 'server-client',
      p2pChatEnabled: true,
      androidBannerAdUnitId: 'android-banner',
      iosBannerAdUnitId: 'ios-banner',
      androidInterstitialAdUnitId: 'android-interstitial',
      iosInterstitialAdUnitId: 'ios-interstitial',
      defaultLlmBaseUrl: 'https://llm.example.test/v1',
      defaultLlmModel: 'test-model',
    );

    expect(configuration.apiBaseUrl, 'https://example.test');
    expect(configuration.googleWebClientId, 'web-client');
    expect(configuration.googleServerClientId, 'server-client');
    expect(configuration.p2pChatEnabled, isTrue);
    expect(configuration.peerVerificationEnabled, isFalse);
    expect(configuration.androidBannerAdUnitId, 'android-banner');
    expect(configuration.iosBannerAdUnitId, 'ios-banner');
    expect(configuration.androidInterstitialAdUnitId, 'android-interstitial');
    expect(configuration.iosInterstitialAdUnitId, 'ios-interstitial');
    expect(configuration.defaultLlmBaseUrl, 'https://llm.example.test/v1');
    expect(configuration.defaultLlmModel, 'test-model');
  });
}
