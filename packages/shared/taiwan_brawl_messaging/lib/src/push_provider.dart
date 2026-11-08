/// Opaque provider-owned initialization data.
///
/// Implementations define their concrete configuration in the adapter layer;
/// shared messaging code never names provider keys or deployment fields.
abstract interface class PushProviderConfiguration {}

class PushMessage {
  const PushMessage(this.data);

  final Map<String, dynamic> data;
}

enum PushAuthorizationStatus {
  authorized,
  provisional,
  denied,
  notDetermined,
  unknown,
}

class PushPermissionResult {
  const PushPermissionResult(this.status);

  final PushAuthorizationStatus status;
}

/// Notification provider boundary, independent of a delivery vendor.
abstract interface class PushProvider {
  Future<void> initialize({
    required PushProviderConfiguration configuration,
    required bool showForegroundNotifications,
    required void Function(PushMessage message) onMessageOpened,
    required void Function(PushMessage message) onForegroundMessage,
    required Future<void> Function(String token) onTokenRefresh,
  });

  Future<PushPermissionResult> requestPermission();

  Future<String?> getToken();

  Future<void> deleteToken();

  Future<void> dispose();
}
