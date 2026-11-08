import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'legacy_installation_store.dart';
import 'legacy_pending_message_adapter.dart';
import 'messaging_core_service.dart';
import 'notification_remote_source.dart';
import 'pending_notification_source.dart';
import 'push_provider.dart';

class NotificationService extends ChangeNotifier {
  NotificationService({
    required LegacyPendingMessageAdapter legacyPendingMessages,
    required MessagingCoreService messagingCore,
    required EventAuthenticator? remoteAuthenticator,
    required CredentialStore credentials,
    required LegacyInstallationStore legacyInstallationStore,
    required NotificationPushProvider pushProvider,
    required PendingNotificationSource pendingNotificationSource,
    required NotificationRemoteSource remoteSource,
  }) : _legacyPendingMessages = legacyPendingMessages,
       _messagingCore = messagingCore,
       _remoteAuthenticator = remoteAuthenticator,
       _credentials = credentials,
       _legacyInstallationStore = legacyInstallationStore,
       _pushProvider = pushProvider,
       _pendingNotificationSource = pendingNotificationSource,
       _remoteSource = remoteSource;

  static const Duration _pollInterval = Duration(seconds: 2);
  static const String _installationIdKey = 'push.installation_id';

  final NotificationRemoteSource _remoteSource;
  final LegacyPendingMessageAdapter _legacyPendingMessages;
  final MessagingCoreService _messagingCore;
  final EventAuthenticator? _remoteAuthenticator;
  final CredentialStore _credentials;
  final LegacyInstallationStore _legacyInstallationStore;
  final NotificationPushProvider _pushProvider;
  final PendingNotificationSource _pendingNotificationSource;

  Future<void> _syncQueue = Future.value();
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _didSyncLoggedOutState = false;
  bool _pushProviderInitialized = false;
  bool _pushConfigLoaded = false;
  bool _canRequestWebPushPermission = kIsWeb;
  PushProviderConfiguration? _pushConfiguration;
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
      if (config != null && _pushProvider.canDeleteToken(config)) {
        await _ensurePushProviderInitialized(config);
        await _pushProvider.deleteToken();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _ensurePushProviderInitialized(
    PushProviderConfiguration config,
  ) async {
    if (_pushProviderInitialized) {
      return;
    }

    _pushProviderInitialized = true;
    if (kIsWeb) {
      _handleOpenedConversationUserId(
        _readInt(Uri.base.queryParameters['conversationUserId']),
      );
    }
    await _pushProvider.initialize(
      configuration: config,
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
    if (config == null ||
        !_pushProvider.isEnabledForPlatform(config, platform)) {
      _setCanRequestWebPushPermission(false);
      return;
    }

    await _ensurePushProviderInitialized(config);
    final token = await _requestPushToken();
    if ((token ?? '').isEmpty) {
      await unregisterCurrentDevice();
      return;
    }

    await _registerPushToken(
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

    await _registerPushToken(
      token.trim(),
      platform: platform,
      locale: _currentUserLocale,
    );
  }

  Future<String?> _requestPushToken() async {
    try {
      final permission = await _pushProvider.requestPermission();
      _updateWebPermissionPrompt(permission);
      if (!_isPermissionUsable(permission.status)) {
        return null;
      }

      return _pushProvider.getToken();
    } catch (error, stackTrace) {
      debugPrint('Push registration failed: $error');
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

  Future<void> _registerPushToken(
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
        'provider': _pushProvider.providerId,
      });
    } catch (error, stackTrace) {
      debugPrint('Register push device failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> requestPushPermission(AppUser user) async {
    _registeredPushUserId = null;
    await _registerCurrentDevice(user);
    _registeredPushUserId = user.id;
    notifyListeners();
  }

  Future<PushProviderConfiguration?> _loadPushConfiguration() async {
    if (_pushConfigLoaded) {
      return _pushConfiguration;
    }
    _pushConfigLoaded = true;

    try {
      final response = await _remoteSource.loadConfiguration();
      final raw = response['config'];
      _pushConfiguration = _pushProvider.parseConfiguration(
        raw is Map ? Map<String, dynamic>.from(raw) : null,
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

    final event = _pendingNotificationSource.eventFromPendingRow(
      item,
      selfId: selfId,
      friendId: senderId,
    );
    if (event != null) {
      final accepted = await _messagingCore.acceptRemote(
        event,
        authenticator: _remoteAuthenticator,
      );
      if (!accepted) {
        if (_messagingCore.canDurablyRecordConflicts && pendingId != null) {
          ackIds.add(pendingId);
        }
        return ackIds;
      }
      if (event.type != MessageEventType.created) {
        if (_messagingCore.storageStatus.isDurable && pendingId != null) {
          ackIds.add(pendingId);
        }
        return ackIds;
      }
      final hasEnvelope =
          item['event_id'] != null &&
          item['message_id'] != null &&
          item['event_type'] != null;
      if (hasEnvelope) {
        if (_messagingCore.storageStatus.isDurable && pendingId != null) {
          ackIds.add(pendingId);
        }
        _setPendingConversation(senderId);
        return ackIds;
      }
    }

    final legacyResult = await _legacyPendingMessages.apply(
      item,
      selfId: selfId,
      friendId: senderId,
      type: type,
      pendingId: pendingId,
    );
    ackIds.addAll(legacyResult.acknowledgedIds);
    if (legacyResult.opensConversation) _setPendingConversation(senderId);
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
