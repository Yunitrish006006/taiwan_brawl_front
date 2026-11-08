import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'push_provider.dart';

/// Local preview adapter. It cannot initialize platform notifications or
/// produce a device token, even if a preview response contains push settings.
class PreviewPushProvider implements NotificationPushProvider {
  @override
  String get providerId => 'preview';

  @override
  PushProviderConfiguration? parseConfiguration(
    Map<String, dynamic>? payload,
  ) => null;

  @override
  bool isEnabledForPlatform(
    PushProviderConfiguration configuration,
    String? platform,
  ) => false;

  @override
  bool canDeleteToken(PushProviderConfiguration configuration) => false;

  @override
  Future<void> initialize({
    required PushProviderConfiguration configuration,
    required bool showForegroundNotifications,
    required void Function(PushMessage message) onMessageOpened,
    required void Function(PushMessage message) onForegroundMessage,
    required Future<void> Function(String token) onTokenRefresh,
  }) async {}

  @override
  Future<PushPermissionResult> requestPermission() async =>
      const PushPermissionResult(PushAuthorizationStatus.notDetermined);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> dispose() async {}
}
