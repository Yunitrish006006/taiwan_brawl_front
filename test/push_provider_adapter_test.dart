import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/push_provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('Firebase adapter rejects another provider configuration', () async {
    final provider = FirebasePushProvider();

    await expectLater(
      provider.initialize(
        configuration: _OtherProviderConfiguration(),
        showForegroundNotifications: false,
        onMessageOpened: (_) {},
        onForegroundMessage: (_) {},
        onTokenRefresh: (_) async {},
      ),
      throwsArgumentError,
    );
    await provider.dispose();
  });
}

class _OtherProviderConfiguration implements PushProviderConfiguration {}
