import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('provider contract accepts adapter-owned configuration', () async {
    final provider = _ExamplePushProvider();
    final opened = <PushMessage>[];
    final foreground = <PushMessage>[];
    final refreshed = <String>[];
    final configuration = _ExamplePushConfiguration('local-provider');

    await provider.initialize(
      configuration: configuration,
      showForegroundNotifications: false,
      onMessageOpened: opened.add,
      onForegroundMessage: foreground.add,
      onTokenRefresh: (token) async => refreshed.add(token),
    );
    provider.opened!(const PushMessage({'route': 'chat'}));
    provider.foreground!(const PushMessage({'route': 'home'}));
    await provider.tokenRefresh!('opaque-provider-token');

    expect(provider.configuration, same(configuration));
    expect(provider.showForegroundNotifications, isFalse);
    expect(opened.single.data, {'route': 'chat'});
    expect(foreground.single.data, {'route': 'home'});
    expect(refreshed, ['opaque-provider-token']);
    expect(
      (await provider.requestPermission()).status,
      PushAuthorizationStatus.authorized,
    );
    expect(await provider.getToken(), 'opaque-provider-token');
    await provider.deleteToken();
    await provider.dispose();
    expect(provider.deleted, isTrue);
  });
}

class _ExamplePushConfiguration implements PushProviderConfiguration {
  const _ExamplePushConfiguration(this.endpoint);

  final String endpoint;
}

class _ExamplePushProvider implements PushProvider {
  PushProviderConfiguration? configuration;
  bool? showForegroundNotifications;
  void Function(PushMessage message)? opened;
  void Function(PushMessage message)? foreground;
  Future<void> Function(String token)? tokenRefresh;
  bool deleted = false;

  @override
  Future<void> initialize({
    required PushProviderConfiguration configuration,
    required bool showForegroundNotifications,
    required void Function(PushMessage message) onMessageOpened,
    required void Function(PushMessage message) onForegroundMessage,
    required Future<void> Function(String token) onTokenRefresh,
  }) async {
    this.configuration = configuration;
    this.showForegroundNotifications = showForegroundNotifications;
    opened = onMessageOpened;
    foreground = onForegroundMessage;
    tokenRefresh = onTokenRefresh;
  }

  @override
  Future<PushPermissionResult> requestPermission() async =>
      const PushPermissionResult(PushAuthorizationStatus.authorized);

  @override
  Future<String?> getToken() async => 'opaque-provider-token';

  @override
  Future<void> deleteToken() async => deleted = true;

  @override
  Future<void> dispose() async {}
}
