import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Application adapter boundary for resolving remote notification settings.
/// Provider-specific response fields stay inside the owning adapter.
abstract interface class NotificationPushProvider implements PushProvider {
  String get providerId;

  PushProviderConfiguration? parseConfiguration(Map<String, dynamic>? payload);

  bool isEnabledForPlatform(
    PushProviderConfiguration configuration,
    String? platform,
  );

  bool canDeleteToken(PushProviderConfiguration configuration);
}

/// Firebase-only configuration, kept out of the shared contract and app service.
class FirebasePushProviderOptions implements PushProviderConfiguration {
  const FirebasePushProviderOptions({
    required this.firebaseOptions,
    required this.enabled,
    required this.deliveryEnabled,
    required this.enabledPlatforms,
    this.webVapidKey,
  });

  final FirebaseOptions firebaseOptions;
  final bool enabled;
  final bool deliveryEnabled;
  final Set<String> enabledPlatforms;
  final String? webVapidKey;

  bool get hasFirebaseOptions =>
      _hasText(firebaseOptions.projectId) &&
      _hasText(firebaseOptions.apiKey) &&
      _hasText(firebaseOptions.appId) &&
      _hasText(firebaseOptions.messagingSenderId);

  static FirebasePushProviderOptions? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawFcm = json['fcm'];
    final fcm = rawFcm is Map
        ? Map<String, dynamic>.from(rawFcm)
        : const <String, dynamic>{};
    final platforms = json['enabledPlatforms'] is List
        ? (json['enabledPlatforms'] as List)
              .whereType<String>()
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet()
        : const <String>{};
    final projectId = _readString(fcm['projectId']);
    final apiKey = _readString(fcm['apiKey']);
    final appId = _readString(fcm['appId']);
    final messagingSenderId = _readString(fcm['messagingSenderId']);
    if ([projectId, apiKey, appId, messagingSenderId].any((v) => v == null)) {
      return null;
    }

    return FirebasePushProviderOptions(
      firebaseOptions: FirebaseOptions(
        apiKey: apiKey!,
        appId: appId!,
        messagingSenderId: messagingSenderId!,
        projectId: projectId!,
        authDomain: _readString(fcm['authDomain']),
        storageBucket: _readString(fcm['storageBucket']),
        measurementId: _readString(fcm['measurementId']),
        iosBundleId: _readString(fcm['iosBundleId']),
      ),
      enabled: fcm['enabled'] == true,
      deliveryEnabled: json['deliveryEnabled'] == true,
      enabledPlatforms: platforms,
      webVapidKey: _readString(fcm['webVapidKey']),
    );
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static String? _readString(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

/// Firebase implementation of the push provider port.
class FirebasePushProvider implements NotificationPushProvider {
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _webVapidKey;

  @override
  String get providerId => 'fcm';

  @override
  PushProviderConfiguration? parseConfiguration(
    Map<String, dynamic>? payload,
  ) => FirebasePushProviderOptions.fromJson(payload);

  @override
  bool isEnabledForPlatform(
    PushProviderConfiguration configuration,
    String? platform,
  ) {
    if (configuration is! FirebasePushProviderOptions ||
        !configuration.enabled ||
        !configuration.deliveryEnabled ||
        !configuration.hasFirebaseOptions ||
        platform == null ||
        !configuration.enabledPlatforms.contains(platform)) {
      return false;
    }
    return platform != 'web' ||
        (configuration.webVapidKey ?? '').trim().isNotEmpty;
  }

  @override
  bool canDeleteToken(PushProviderConfiguration configuration) =>
      configuration is FirebasePushProviderOptions &&
      configuration.hasFirebaseOptions;

  @override
  Future<void> initialize({
    required PushProviderConfiguration configuration,
    required bool showForegroundNotifications,
    required void Function(PushMessage message) onMessageOpened,
    required void Function(PushMessage message) onForegroundMessage,
    required Future<void> Function(String token) onTokenRefresh,
  }) async {
    if (configuration is! FirebasePushProviderOptions) {
      throw ArgumentError.value(
        configuration,
        'configuration',
        'FirebasePushProviderOptions are required',
      );
    }
    _webVapidKey = configuration.webVapidKey;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: configuration.firebaseOptions);
    }

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (_) {
      // Unsupported on some platforms.
    }

    if (showForegroundNotifications &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      onMessageOpened(PushMessage(initialMessage.data));
    }

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => onMessageOpened(PushMessage(message.data)),
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => onForegroundMessage(PushMessage(message.data)),
    );
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen(onTokenRefresh);
  }

  @override
  Future<PushPermissionResult> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return PushPermissionResult(_mapStatus(settings.authorizationStatus));
  }

  @override
  Future<String?> getToken() {
    return FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? _webVapidKey : null,
    );
  }

  @override
  Future<void> deleteToken() async {
    await FirebaseMessaging.instance.deleteToken();
  }

  @override
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenRefreshSubscription = null;
  }

  PushAuthorizationStatus _mapStatus(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => PushAuthorizationStatus.authorized,
      AuthorizationStatus.provisional => PushAuthorizationStatus.provisional,
      AuthorizationStatus.denied => PushAuthorizationStatus.denied,
      AuthorizationStatus.notDetermined =>
        PushAuthorizationStatus.notDetermined,
    };
  }
}
