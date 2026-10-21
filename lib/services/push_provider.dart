import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Firebase implementation of the push provider port.
class FirebasePushProvider implements PushProvider {
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  Future<void> initialize({
    required PushProviderOptions options,
    required bool isWeb,
    required bool showForegroundNotifications,
    required void Function(PushMessage message) onMessageOpened,
    required void Function(PushMessage message) onForegroundMessage,
    required Future<void> Function(String token) onTokenRefresh,
  }) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: options.apiKey,
          appId: options.appId,
          messagingSenderId: options.messagingSenderId,
          projectId: options.projectId,
          authDomain: options.authDomain,
          storageBucket: options.storageBucket,
          measurementId: options.measurementId,
          iosBundleId: options.iosBundleId,
        ),
      );
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
  Future<String?> getToken({String? vapidKey}) {
    return FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
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
