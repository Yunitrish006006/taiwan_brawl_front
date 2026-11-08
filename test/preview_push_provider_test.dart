import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/preview_push_provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'preview push adapter never enables or initializes platform push',
    () async {
      final provider = PreviewPushProvider();
      const configuration = _PreviewTestConfiguration();
      var openedMessages = 0;
      var foregroundMessages = 0;
      var refreshedTokens = 0;

      expect(provider.providerId, 'preview');
      expect(
        provider.parseConfiguration({
          'fcm': {'enabled': true},
        }),
        isNull,
      );
      expect(provider.isEnabledForPlatform(configuration, 'android'), isFalse);
      expect(provider.canDeleteToken(configuration), isFalse);

      await provider.initialize(
        configuration: configuration,
        showForegroundNotifications: true,
        onMessageOpened: (_) => openedMessages++,
        onForegroundMessage: (_) => foregroundMessages++,
        onTokenRefresh: (_) async => refreshedTokens++,
      );
      expect(
        (await provider.requestPermission()).status,
        PushAuthorizationStatus.notDetermined,
      );
      expect(await provider.getToken(), isNull);
      await provider.deleteToken();
      await provider.dispose();

      expect(openedMessages, 0);
      expect(foregroundMessages, 0);
      expect(refreshedTokens, 0);
    },
  );
}

class _PreviewTestConfiguration implements PushProviderConfiguration {
  const _PreviewTestConfiguration();
}
