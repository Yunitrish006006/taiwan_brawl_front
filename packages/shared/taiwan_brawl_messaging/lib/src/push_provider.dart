/// Provider-neutral push notification contract shared by product clients.
class PushProviderOptions {
  const PushProviderOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.storageBucket,
    this.measurementId,
    this.iosBundleId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? authDomain;
  final String? storageBucket;
  final String? measurementId;
  final String? iosBundleId;
}

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

/// Notification provider boundary; implementations may use FCM or another
/// delivery provider without changing application services.
abstract interface class PushProvider {
  Future<void> initialize({
    required PushProviderOptions options,
    required bool isWeb,
    required bool showForegroundNotifications,
    required void Function(PushMessage message) onMessageOpened,
    required void Function(PushMessage message) onForegroundMessage,
    required Future<void> Function(String token) onTokenRefresh,
  });

  Future<PushPermissionResult> requestPermission();

  Future<String?> getToken({String? vapidKey});

  Future<void> deleteToken();

  Future<void> dispose();
}
