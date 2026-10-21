import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/app_user.dart';
import '../models/chat_models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'local_chat_repository.dart';
import 'legacy_chat_store.dart';
import 'legacy_installation_store.dart';
import 'messaging_core_service.dart';
import 'notification_remote_source.dart';
import 'platform_credential_store.dart';
import 'pending_notification_source.dart';
import 'push_provider.dart';
import 'server_message_transport.dart';

class PushConfiguration {
  const PushConfiguration({
    required this.fcmEnabled,
    required this.fcmDeliveryEnabled,
    required this.enabledPlatforms,
    required this.projectId,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.webVapidKey,
    this.authDomain,
    this.storageBucket,
    this.measurementId,
    this.iosBundleId,
  });

  final bool fcmEnabled;
  final bool fcmDeliveryEnabled;
  final List<String> enabledPlatforms;
  final String? projectId;
  final String? apiKey;
  final String? appId;
  final String? messagingSenderId;
  final String? webVapidKey;
  final String? authDomain;
  final String? storageBucket;
  final String? measurementId;
  final String? iosBundleId;

  bool get hasFirebaseOptions {
    return _hasText(projectId) &&
        _hasText(apiKey) &&
        _hasText(appId) &&
        _hasText(messagingSenderId);
  }

  bool isEnabledForPlatform(String? platform) {
    if (!fcmEnabled || !fcmDeliveryEnabled || !hasFirebaseOptions) {
      return false;
    }
    if (platform == null || !enabledPlatforms.contains(platform)) {
      return false;
    }
    if (platform == 'web' && !_hasText(webVapidKey)) {
      return false;
    }
    return true;
  }

  FirebaseOptions toFirebaseOptions() {
    return FirebaseOptions(
      apiKey: apiKey!.trim(),
      appId: appId!.trim(),
      messagingSenderId: messagingSenderId!.trim(),
      projectId: projectId!.trim(),
      authDomain: _nullIfBlank(authDomain),
      storageBucket: _nullIfBlank(storageBucket),
      measurementId: _nullIfBlank(measurementId),
      iosBundleId: _nullIfBlank(iosBundleId),
    );
  }

  PushProviderOptions toPushProviderOptions() {
    return PushProviderOptions(
      apiKey: apiKey!.trim(),
      appId: appId!.trim(),
      messagingSenderId: messagingSenderId!.trim(),
      projectId: projectId!.trim(),
      authDomain: _nullIfBlank(authDomain),
      storageBucket: _nullIfBlank(storageBucket),
      measurementId: _nullIfBlank(measurementId),
      iosBundleId: _nullIfBlank(iosBundleId),
    );
  }

  static PushConfiguration? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final fcm = json['fcm'] is Map<String, dynamic>
        ? json['fcm'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final platforms = json['enabledPlatforms'] is List
        ? (json['enabledPlatforms'] as List)
              .whereType<String>()
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
        : const <String>[];

    return PushConfiguration(
      fcmEnabled: fcm['enabled'] == true,
      fcmDeliveryEnabled: json['deliveryEnabled'] == true,
      enabledPlatforms: platforms,
      projectId: _readString(fcm['projectId']),
      apiKey: _readString(fcm['apiKey']),
      appId: _readString(fcm['appId']),
      messagingSenderId: _readString(fcm['messagingSenderId']),
      webVapidKey: _readString(fcm['webVapidKey']),
      authDomain: _readString(fcm['authDomain']),
      storageBucket: _readString(fcm['storageBucket']),
      measurementId: _readString(fcm['measurementId']),
      iosBundleId: _readString(fcm['iosBundleId']),
    );
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static String? _readString(Object? value) {
    final text = (value as String?)?.trim();
    return (text ?? '').isEmpty ? null : text;
  }

  static String? _nullIfBlank(String? value) {
    final text = value?.trim();
    return (text ?? '').isEmpty ? null : text;
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService(
    ApiClient apiClient, {
    LegacyChatStore? localRepository,
    MessagingCoreService? messagingCore,
    EventAuthenticator? remoteAuthenticator,
    MessageRepository? eventRepository,
    CredentialStore? credentials,
    LegacyInstallationStore? legacyInstallationStore,
    PushProvider? pushProvider,
    PendingNotificationSource? pendingNotificationSource,
    NotificationRemoteSource? remoteSource,
  }) : _localRepository = localRepository ?? LocalChatRepository(),
       _messagingCore = messagingCore,
       _remoteAuthenticator = remoteAuthenticator,
       _eventRepository = eventRepository,
       _credentials = credentials ?? PlatformCredentialStore(),
       _legacyInstallationStore =
           legacyInstallationStore ?? HiveLegacyInstallationStore(),
       _pushProvider = pushProvider ?? FirebasePushProvider(),
       _pendingNotificationSource =
           pendingNotificationSource ??
           ServerPendingNotificationSource(apiClient),
       _remoteSource =
           remoteSource ?? ServerNotificationRemoteSource(apiClient);

  static const Duration _pollInterval = Duration(seconds: 2);
  static const String _installationIdKey = 'push.installation_id';

  final NotificationRemoteSource _remoteSource;
  final LegacyChatStore _localRepository;
  final MessagingCoreService? _messagingCore;
  final EventAuthenticator? _remoteAuthenticator;
  final MessageRepository? _eventRepository;
  final CredentialStore _credentials;
  final LegacyInstallationStore _legacyInstallationStore;
  final PushProvider _pushProvider;
  final PendingNotificationSource _pendingNotificationSource;

  Future<void> _syncQueue = Future.value();
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _didSyncLoggedOutState = false;
  bool _firebaseInitialized = false;
  bool _pushConfigLoaded = false;
  bool _canRequestWebPushPermission = kIsWeb;
  PushConfiguration? _pushConfiguration;
  int? _currentUserId;
  int? _registeredPushUserId;
  int? _activeConversationUserId;
  int? _pendingConversationUserId;
  String? _currentUserLocale;
  String? _installationId;

  int? get pendingConversationUserId => _pendingConversationUserId;

  bool get canRequestWebPushPermission =>
      kIsWeb && _canRequestWebPushPermission;

  Future<void> initialize() async {}

  void clearPendingConversationUserId() {
    if (_pendingConversationUserId == null) {
      return;
    }
    _pendingConversationUserId = null;
    notifyListeners();
  }

  void syncAuth(AuthService auth) {
    _syncQueue = _syncQueue
        .catchError((Object error, StackTrace stackTrace) {})
        .then<void>((_) => _syncAuth(auth));
  }

  Future<void> _syncAuth(AuthService auth) async {
    if (!auth.hasInitialized) {
      return;
    }

    final user = auth.user;
    if (user == null) {
      final shouldNotify =
          _currentUserId != null || _pendingConversationUserId != null;
      _currentUserId = null;
      _currentUserLocale = null;
      _registeredPushUserId = null;
      _activeConversationUserId = null;
      _pendingConversationUserId = null;
      _stopPolling();
      if (!_didSyncLoggedOutState) {
        await unregisterCurrentDevice();
        _didSyncLoggedOutState = true;
      }
      if (shouldNotify) {
        notifyListeners();
      }
      return;
    }

    _didSyncLoggedOutState = false;
    final didSwitchUser = _currentUserId != user.id;
    _currentUserId = user.id;
    _currentUserLocale = user.locale;
    _startPolling();

    if (_registeredPushUserId != user.id) {
      await _registerCurrentDevice(user);
      _registeredPushUserId = user.id;
    }

    if (!didSwitchUser) {
      return;
    }

    _pendingConversationUserId = null;
    await _pollPending();
  }

  void setActiveConversation(int? friendId) {
    if (_activeConversationUserId == friendId) {
      return;
    }

    _activeConversationUserId = friendId;
    if (friendId != null && _pendingConversationUserId == friendId) {
      _pendingConversationUserId = null;
      notifyListeners();
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final platform = _currentPushPlatform;
    final installationId = await _loadInstallationId();
    if (platform == null || installationId == null || installationId.isEmpty) {
      return;
    }

    try {
      await _remoteSource.unregisterDevice({
        'installationId': installationId,
        'platform': platform,
      });
    } catch (error, stackTrace) {
      debugPrint('Unregister push device failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final config = await _loadPushConfiguration();
      if (config != null && config.hasFirebaseOptions) {
        await _ensureFirebaseInitialized(config);
        await _pushProvider.deleteToken();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _ensureFirebaseInitialized(PushConfiguration config) async {
    if (_firebaseInitialized) {
      return;
    }

    _firebaseInitialized = true;
    if (kIsWeb) {
      _handleOpenedConversationUserId(
        _readInt(Uri.base.queryParameters['conversationUserId']),
      );
    }
    await _pushProvider.initialize(
      options: config.toPushProviderOptions(),
      isWeb: kIsWeb,
      showForegroundNotifications: !kIsWeb,
      onMessageOpened: _handleRemoteMessage,
      onForegroundMessage: _handleRemoteMessage,
      onTokenRefresh: _handleTokenRefresh,
    );
  }

  void _handleRemoteMessage(PushMessage message) {
    _handleOpenedConversationUserId(
      _readInt(
        message.data['conversationUserId'] ??
            message.data['senderId'] ??
            message.data['conversation_user_id'] ??
            message.data['sender_id'],
      ),
    );
  }

  void _handleOpenedConversationUserId(int? conversationUserId) {
    if (conversationUserId == null || conversationUserId <= 0) {
      return;
    }
    if (_activeConversationUserId == conversationUserId) {
      return;
    }
    if (_pendingConversationUserId == conversationUserId) {
      return;
    }
    _pendingConversationUserId = conversationUserId;
    notifyListeners();
  }

  Future<void> _registerCurrentDevice(AppUser user) async {
    final platform = _currentPushPlatform;
    final config = await _loadPushConfiguration();
    if (config == null || !config.isEnabledForPlatform(platform)) {
      _setCanRequestWebPushPermission(false);
      return;
    }

    await _ensureFirebaseInitialized(config);
    final token = await _requestFcmToken(config);
    if ((token ?? '').isEmpty) {
      await unregisterCurrentDevice();
      return;
    }

    await _registerFcmToken(
      token!.trim(),
      platform: platform!,
      locale: user.locale,
    );
  }

  Future<void> _handleTokenRefresh(String token) async {
    final platform = _currentPushPlatform;
    final userId = _currentUserId;
    if (userId == null || platform == null || token.trim().isEmpty) {
      return;
    }

    await _registerFcmToken(
      token.trim(),
      platform: platform,
      locale: _currentUserLocale,
    );
  }

  Future<String?> _requestFcmToken(PushConfiguration config) async {
    try {
      final permission = await _pushProvider.requestPermission();
      _updateWebPermissionPrompt(permission);
      if (!_isPermissionUsable(permission.status)) {
        return null;
      }

      return _pushProvider.getToken(
        vapidKey: kIsWeb ? config.webVapidKey?.trim() : null,
      );
    } catch (error, stackTrace) {
      debugPrint('FCM registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  bool _isPermissionUsable(PushAuthorizationStatus status) {
    return status == PushAuthorizationStatus.authorized ||
        status == PushAuthorizationStatus.provisional;
  }

  void _updateWebPermissionPrompt(PushPermissionResult? settings) {
    if (!kIsWeb) {
      return;
    }
    final canRequest =
        settings == null ||
        settings.status == PushAuthorizationStatus.notDetermined;
    _setCanRequestWebPushPermission(canRequest);
  }

  void _setCanRequestWebPushPermission(bool canRequest) {
    if (!kIsWeb) {
      return;
    }
    if (_canRequestWebPushPermission == canRequest) {
      return;
    }
    _canRequestWebPushPermission = canRequest;
    notifyListeners();
  }

  Future<void> _registerFcmToken(
    String token, {
    required String platform,
    required String? locale,
  }) async {
    final installationId = await _loadInstallationId();
    if (installationId == null || installationId.isEmpty) {
      return;
    }

    final packageInfo = await _loadPackageInfo();

    try {
      await _remoteSource.registerDevice({
        'installationId': installationId,
        'platform': platform,
        'token': token,
        'locale': locale,
        'appVersion': packageInfo,
        'userAgent': _platformUserAgent,
        'provider': 'fcm',
      });
    } catch (error, stackTrace) {
      debugPrint('Register FCM device failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> requestPushPermission(AppUser user) async {
    _registeredPushUserId = null;
    await _registerCurrentDevice(user);
    _registeredPushUserId = user.id;
    notifyListeners();
  }

  Future<PushConfiguration?> _loadPushConfiguration() async {
    if (_pushConfigLoaded) {
      return _pushConfiguration;
    }
    _pushConfigLoaded = true;

    try {
      final response = await _remoteSource.loadConfiguration();
      _pushConfiguration = PushConfiguration.fromJson(
        response['config'] as Map<String, dynamic>?,
      );
    } catch (error, stackTrace) {
      debugPrint('Load push config failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _pushConfiguration = null;
    }

    return _pushConfiguration;
  }

  Future<String?> _loadInstallationId() async {
    if ((_installationId ?? '').isNotEmpty) {
      return _installationId;
    }

    final stored = (await _credentials.read(_installationIdKey))?.trim();
    if ((stored ?? '').isNotEmpty) {
      _installationId = stored;
      return stored;
    }

    // Migrate installations created before CredentialStore was introduced.
    try {
      final legacy = (await _legacyInstallationStore.readInstallationId())
          ?.trim();
      if ((legacy ?? '').isNotEmpty) {
        await _credentials.write(_installationIdKey, legacy!);
        _installationId = legacy;
        return legacy;
      }
    } catch (_) {
      // A missing legacy Hive adapter must not block identity creation.
    }

    final generated = _generateInstallationId();
    await _credentials.write(_installationIdKey, generated);
    _installationId = generated;
    return generated;
  }

  String _generateInstallationId() {
    final random = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final nonce = random.nextInt(0x7fffffff).toRadixString(36);
    return '$timestamp-$nonce';
  }

  Future<String?> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      if (version.isEmpty) {
        return null;
      }
      if (buildNumber.isEmpty) {
        return version;
      }
      return '$version+$buildNumber';
    } catch (_) {
      return null;
    }
  }

  String? get _currentPushPlatform {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      _ => null,
    };
  }

  String get _platformUserAgent {
    if (kIsWeb) {
      return 'flutter-web';
    }

    return 'flutter-${defaultTargetPlatform.name.toLowerCase()}';
  }

  void _startPolling() {
    if (_pollTimer != null) {
      return;
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollPending());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInFlight = false;
  }

  Future<void> _pollPending() async {
    final selfId = _currentUserId;
    if (selfId == null || _pollInFlight) {
      return;
    }

    _pollInFlight = true;
    try {
      await _pendingNotificationSource.poll(
        selfId: selfId,
        activeConversationUserId: _activeConversationUserId,
        onItem: (item) => _handlePendingNotificationItem(item, selfId),
      );
    } catch (error, stackTrace) {
      debugPrint('Notification poll failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _pollInFlight = false;
    }
  }

  Future<Iterable<int>> _handlePendingNotificationItem(
    Map<String, dynamic> item,
    int selfId,
  ) async {
    final senderId = _readInt(item['senderId'] ?? item['sender_id']);
    if (senderId == null) return const [];

    final pendingId = _readInt(item['id']);
    final type = (item['type'] as String? ?? 'message').trim();
    final ackIds = <int>[];

    final eventRepository = _messagingCore?.repository ?? _eventRepository;
    final event = eventRepository == null
        ? null
        : ServerMessageTransport.eventFromPendingRow(
            item,
            selfId: selfId,
            friendId: senderId,
          );
    if (event != null) {
      if (_messagingCore case final core?) {
        await core.acceptRemote(event, authenticator: _remoteAuthenticator);
      } else {
        await _eventRepository!.acceptRemote(
          event,
          authenticator: _remoteAuthenticator,
        );
      }
      if (event.type != MessageEventType.created) {
        if (pendingId != null) ackIds.add(pendingId);
        return ackIds;
      }
      final hasEnvelope =
          item['event_id'] != null &&
          item['message_id'] != null &&
          item['event_type'] != null;
      if (hasEnvelope) {
        if (pendingId != null) ackIds.add(pendingId);
        _setPendingConversation(senderId);
        return ackIds;
      }
    }

    if (type == 'recall') {
      final messageKey = (item['text'] as String? ?? '').trim();
      if (messageKey.isNotEmpty) {
        await _localRepository.markRecalled(selfId, senderId, messageKey);
      }
      if (pendingId != null) ackIds.add(pendingId);
      return ackIds;
    }

    final message = ChatMessage.fromJson(item);
    await _localRepository.saveMessage(selfId, message);
    if (message.pendingId != null) {
      ackIds.add(message.pendingId!);
    } else if (pendingId != null) {
      ackIds.add(pendingId);
    }
    _setPendingConversation(senderId);
    return ackIds;
  }

  void _setPendingConversation(int senderId) {
    if (_pendingConversationUserId == senderId) return;
    _pendingConversationUserId = senderId;
    notifyListeners();
  }

  int? _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  @override
  void dispose() {
    _stopPolling();
    _pendingNotificationSource.dispose();
    unawaited(_pushProvider.dispose());
    super.dispose();
  }
}
