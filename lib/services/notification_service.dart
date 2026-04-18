import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_user.dart';
import '../models/chat_models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'local_chat_repository.dart';
import 'web_push_bridge.dart' as web_push_bridge;

class PushConfiguration {
  const PushConfiguration({
    required this.iosEnabled,
    required this.webEnabled,
    required this.webPublicKey,
    required this.webServiceWorkerPath,
    required this.webServiceWorkerScope,
  });

  final bool iosEnabled;
  final bool webEnabled;
  final String? webPublicKey;
  final String webServiceWorkerPath;
  final String webServiceWorkerScope;

  bool get isEnabledForCurrentPlatform {
    if (kIsWeb) {
      return webEnabled && (webPublicKey ?? '').trim().isNotEmpty;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => iosEnabled,
      _ => false,
    };
  }

  static PushConfiguration? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final ios = json['ios'] is Map<String, dynamic>
        ? json['ios'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final web = json['web'] is Map<String, dynamic>
        ? json['web'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return PushConfiguration(
      iosEnabled: ios['enabled'] == true,
      webEnabled: web['enabled'] == true,
      webPublicKey: (web['publicKey'] as String?)?.trim(),
      webServiceWorkerPath:
          (web['serviceWorkerPath'] as String?)?.trim().isNotEmpty == true
          ? (web['serviceWorkerPath'] as String).trim()
          : '/web-push-sw.js',
      webServiceWorkerScope:
          (web['serviceWorkerScope'] as String?)?.trim().isNotEmpty == true
          ? (web['serviceWorkerScope'] as String).trim()
          : '/push-notifications/',
    );
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService(this._apiClient, {LocalChatRepository? localRepository})
      : _localRepository = localRepository ?? LocalChatRepository();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const String _metaBoxName = 'app_meta';
  static const String _installationIdKey = 'push.installation_id';
  static const MethodChannel _iosChannel = MethodChannel(
    'taiwan_brawl/notifications',
  );

  final ApiClient _apiClient;
  final LocalChatRepository _localRepository;

  Future<void> _syncQueue = Future.value();
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _didSyncLoggedOutState = false;
  bool _platformHooksInitialized = false;
  bool _pushConfigLoaded = false;
  PushConfiguration? _pushConfiguration;
  int? _currentUserId;
  int? _registeredPushUserId;
  int? _activeConversationUserId;
  int? _pendingConversationUserId;
  String? _installationId;

  int? get pendingConversationUserId => _pendingConversationUserId;

  bool get canRequestWebPushPermission {
    if (!kIsWeb) return false;
    final permission = web_push_bridge.getNotificationPermission();
    return permission == 'default';
  }

  Future<void> initialize() async {
    await _ensurePlatformHooksInitialized();
  }

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

    await _ensurePlatformHooksInitialized();

    final user = auth.user;
    if (user == null) {
      final shouldNotify =
          _currentUserId != null || _pendingConversationUserId != null;
      _currentUserId = null;
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
      await _apiClient.postJson('/api/notifications/unregister', {
        'installationId': installationId,
        'platform': platform,
      });
    } catch (error, stackTrace) {
      debugPrint('Unregister push device failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (kIsWeb) {
      await web_push_bridge.unregisterWebPush();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _iosChannel.invokeMethod<void>('unregisterForRemoteNotifications');
      } catch (_) {
        // Best effort only.
      }
    }
  }

  Future<void> _ensurePlatformHooksInitialized() async {
    if (_platformHooksInitialized) {
      return;
    }
    _platformHooksInitialized = true;

    if (kIsWeb) {
      final conversationUserId =
          await web_push_bridge.consumePendingConversationUserId();
      _handleOpenedConversationUserId(conversationUserId);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _iosChannel.setMethodCallHandler(_handleIosMethodCall);
      try {
        final initialPayload = await _iosChannel
            .invokeMapMethod<Object?, Object?>('consumeNotificationOpen');
        _handleOpenedConversationPayload(initialPayload);
      } catch (error, stackTrace) {
        debugPrint('Read initial iOS notification failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<dynamic> _handleIosMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'notificationOpened':
        _handleOpenedConversationPayload(call.arguments);
        return null;
      default:
        return null;
    }
  }

  void _handleOpenedConversationPayload(Object? raw) {
    if (raw is! Map) {
      return;
    }
    final map = Map<String, dynamic>.from(raw);
    _handleOpenedConversationUserId(
      _readInt(map['conversationUserId'] ?? map['senderId']),
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
    final config = await _loadPushConfiguration();
    if (config == null || !config.isEnabledForCurrentPlatform) {
      return;
    }

    final installationId = await _loadInstallationId();
    if (installationId == null || installationId.isEmpty) {
      return;
    }

    final registrationBody = await _buildRegistrationBody(config);
    if (registrationBody == null) {
      await unregisterCurrentDevice();
      return;
    }

    final packageInfo = await _loadPackageInfo();
    final platform = registrationBody['platform'] as String?;
    if ((platform ?? '').isEmpty) {
      return;
    }

    try {
      await _apiClient.postJson('/api/notifications/register', {
        'installationId': installationId,
        'platform': platform,
        'locale': user.locale,
        'appVersion': packageInfo,
        'userAgent': _platformUserAgent,
        ...registrationBody,
      });
    } catch (error, stackTrace) {
      debugPrint('Register push device failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 由使用者手勢觸發，用於 iOS Safari PWA 等需要 user gesture 才能請求通知權限的情境。
  Future<void> requestPushPermission(AppUser user) async {
    _registeredPushUserId = null;
    await _registerCurrentDevice(user);
    _registeredPushUserId = user.id;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _buildRegistrationBody(
    PushConfiguration config,
  ) async {
    if (kIsWeb) {
      final publicKey = (config.webPublicKey ?? '').trim();
      if (publicKey.isEmpty) {
        return null;
      }

      final subscription = await web_push_bridge.registerWebPush(
        publicKey: publicKey,
        serviceWorkerPath: config.webServiceWorkerPath,
        serviceWorkerScope: config.webServiceWorkerScope,
      );
      if (subscription == null) {
        return null;
      }

      return {
        'platform': 'web',
        'subscription': subscription,
      };
    }

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    try {
      final token = await _iosChannel.invokeMethod<String>(
        'registerForRemoteNotifications',
      );
      final normalizedToken = token?.trim();
      if ((normalizedToken ?? '').isEmpty) {
        return null;
      }
      return {
        'platform': 'ios',
        'token': normalizedToken,
      };
    } catch (error, stackTrace) {
      debugPrint('APNs registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<PushConfiguration?> _loadPushConfiguration() async {
    if (_pushConfigLoaded) {
      return _pushConfiguration;
    }
    _pushConfigLoaded = true;

    try {
      final response = await _apiClient.getJson('/api/notifications/config');
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

    final box = await Hive.openBox(_metaBoxName);
    final stored = (box.get(_installationIdKey) as String?)?.trim();
    if ((stored ?? '').isNotEmpty) {
      _installationId = stored;
      return stored;
    }

    final generated = _generateInstallationId();
    await box.put(_installationIdKey, generated);
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
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  String get _platformUserAgent {
    if (kIsWeb) {
      return 'flutter-web';
    }

    return 'flutter-${defaultTargetPlatform.name}';
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
      final response = await _apiClient.getJson('/api/chat/dm/pending');
      final rawMessages = response['messages'];
      if (rawMessages is! List || rawMessages.isEmpty) {
        return;
      }

      final ackIds = <int>[];
      int? nextConversationUserId;

      for (final rawItem in rawMessages) {
        if (rawItem is! Map) {
          continue;
        }

        final item = Map<String, dynamic>.from(rawItem);
        final senderId = _readInt(item['senderId'] ?? item['sender_id']);
        if (senderId == null) {
          continue;
        }

        if (_activeConversationUserId != null &&
            senderId == _activeConversationUserId) {
          continue;
        }

        final pendingId = _readInt(item['id']);
        final type = (item['type'] as String? ?? 'message').trim();

        if (type == 'recall') {
          final messageKey = (item['text'] as String? ?? '').trim();
          if (messageKey.isNotEmpty) {
            await _localRepository.markRecalled(selfId, senderId, messageKey);
          }
          if (pendingId != null) {
            ackIds.add(pendingId);
          }
          continue;
        }

        final message = ChatMessage.fromJson(item);
        await _localRepository.saveMessage(selfId, message);
        if (message.pendingId != null) {
          ackIds.add(message.pendingId!);
        } else if (pendingId != null) {
          ackIds.add(pendingId);
        }
        nextConversationUserId ??= senderId;
      }

      if (ackIds.isNotEmpty) {
        await _apiClient.postJson('/api/chat/dm/ack', {'ids': ackIds});
      }

      if (nextConversationUserId != null &&
          _pendingConversationUserId != nextConversationUserId) {
        _pendingConversationUserId = nextConversationUserId;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint('Notification poll failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _pollInFlight = false;
    }
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
    super.dispose();
  }
}
