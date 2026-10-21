import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as mini_royale;

import '../config/app_configuration.dart';
import '../game_modules/mini_royale_platform_adapters.dart';
import 'admin_remote_source.dart';
import 'api_client.dart';
import 'auth_remote_source.dart';
import 'auth_service.dart';
import 'chat_service_factory.dart';
import 'friends_remote_source.dart';
import 'legacy_chat_remote_source.dart';
import 'legacy_installation_store.dart';
import 'local_chat_repository.dart';
import 'llm_bot_remote_source.dart';
import 'messaging_core_service.dart';
import 'messaging_runtime_bootstrap.dart';
import 'peer_trust_service.dart';
import 'notification_remote_source.dart';
import 'notification_service.dart';
import 'pending_notification_source.dart';
import 'platform_credential_store.dart';
import 'royale_remote_source.dart';
import 'secure_messaging_key_provider.dart';
import 'storage_runtime.dart';

/// A deterministic HTTP boundary for the browser-only local preview.
///
/// Keeping the existing server adapters above this boundary makes the preview
/// exercise the same parsing and service contracts as production without
/// requiring OAuth, Cloudflare, or a network connection.
class PreviewHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final method = request.method;
    final body = _response(path, method);
    final encoded = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(encoded),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }

  Map<String, dynamic> _response(String path, String method) {
    if (path == '/api/me') return {'user': _user};
    if (path == '/api/friends/overview') return _friendsOverview;
    if (path == '/api/friends/search') {
      return {
        'results': [_friend(id: 102, name: '離線好友')],
      };
    }
    if (path.endsWith('/cards')) return {'cards': const []};
    if (path.endsWith('/heroes')) return {'heroes': const []};
    if (path.endsWith('/progression')) return {'progression': const {}};
    if (path.endsWith('/decks')) return {'decks': const []};
    if (path == '/api/llm-bot/decide') {
      return {'action': 'pass', 'reason': 'Local preview decision'};
    }
    if (path == '/api/notifications/config') return {'config': null};
    if (path == '/api/chat/dm/pending') return {'messages': const []};
    if (path.contains('/history')) return {'messages': const []};
    if (path.contains('/sync-download')) return {'events': const []};
    if (path.contains('/rooms/')) {
      return {
        'room': {
          'code': 'DEMO01',
          'status': 'waiting',
          'simulationMode': 'host',
          'hostUserId': 100,
          'viewerSide': 'self',
          'players': const [],
          'battle': null,
        },
      };
    }
    return {'ok': true, 'status': 'preview', 'method': method};
  }

  static final Map<String, dynamic> _user = {
    'id': 100,
    'name': '本地預覽玩家',
    'email': 'preview@local.test',
    'role': 'admin',
    'bio': 'Taiwan Brawl offline preview',
    'theme_mode': 'system',
    'font_size_scale': 1.0,
    'locale': 'zh-Hant',
    'llm_base_url': 'http://localhost/preview',
    'llm_model': 'local-preview',
    'llm_has_api_key': false,
  };

  static Map<String, dynamic> _friend({
    required int id,
    required String name,
  }) => {
    'userId': id,
    'name': name,
    'bio': '可在本地預覽中測試離線聊天',
    'avatarUrl': null,
    'lastActiveAt': '2026-10-20T00:00:00Z',
    'isOnline': true,
  };

  static final Map<String, dynamic> _friendsOverview = {
    'friends': [
      _friend(id: 101, name: 'P2P 測試好友'),
      _friend(id: 102, name: '離線好友'),
    ],
    'incomingRequests': const [],
    'outgoingRequests': const [],
    'blockedUsers': const [],
    'roomInvites': const [],
  };
}

class PreviewMessageTransport implements MessageTransport {
  bool _connected = false;

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> send(MessageEvent event) async {
    if (!_connected) throw StateError('Preview transport is not connected');
  }

  @override
  Future<void> disconnect() async => _connected = false;
}

class PreviewBattleAnimationRemoteSource
    implements mini_royale.BattleAnimationRemoteSource {
  @override
  Future<Uint8List?> download(Uri uri) async => null;

  @override
  void dispose() {}
}

class PreviewRuntime {
  PreviewRuntime._({
    required this.apiClient,
    required this.credentials,
    required this.messagingRuntime,
    required this.peerTrust,
    required this.legacyChatStore,
    required this.legacyChatRemoteSource,
    required this.adminRemoteSource,
    required this.authRemoteSource,
    required this.friendsRemoteSource,
    required this.llmBotRemoteSource,
    required this.royaleRemoteSource,
    required this.notificationRemoteSource,
    required this.pendingNotificationSource,
    required this.battleAnimationCacheService,
    required this.notificationService,
    required this.chatServiceFactory,
    required this.authService,
  });

  final ApiClient apiClient;
  final PlatformCredentialStore credentials;
  final MessagingRuntime messagingRuntime;
  final PeerTrustService peerTrust;
  final LocalChatRepository legacyChatStore;
  final LegacyChatRemoteSource legacyChatRemoteSource;
  final AdminRemoteSource adminRemoteSource;
  final AuthRemoteSource authRemoteSource;
  final FriendsRemoteSource friendsRemoteSource;
  final LlmBotRemoteSource llmBotRemoteSource;
  final RoyaleRemoteSource royaleRemoteSource;
  final NotificationRemoteSource notificationRemoteSource;
  final PendingNotificationSource pendingNotificationSource;
  final mini_royale.BattleAnimationCacheService battleAnimationCacheService;
  final NotificationService notificationService;
  final ChatServiceFactory chatServiceFactory;
  final AuthService authService;

  static Future<PreviewRuntime> create(AppConfiguration configuration) async {
    await HiveStorageRuntime().initialize();
    final credentials = PlatformCredentialStore();
    final messagingRuntime = await restoreMessagingRuntime(credentials);
    await seedPreviewMessages(messagingRuntime.core);
    final apiClient = ApiClient(
      client: PreviewHttpClient(),
      credentials: credentials,
      configuration: configuration,
    );
    final peerTrust = PeerTrustService(credentials: credentials);
    final legacyChatStore = LocalChatRepository();
    final legacyChatRemoteSource = ServerLegacyChatRemoteSource(apiClient);
    final adminRemoteSource = ServerAdminRemoteSource(apiClient);
    final authRemoteSource = ServerAuthRemoteSource(apiClient);
    final friendsRemoteSource = ServerFriendsRemoteSource(apiClient);
    final llmBotRemoteSource = ServerLlmBotRemoteSource(
      apiClient,
      client: PreviewHttpClient(),
    );
    final royaleRemoteSource = ServerRoyaleRemoteSource(apiClient);
    final notificationRemoteSource = ServerNotificationRemoteSource(apiClient);
    final pendingNotificationSource = ServerPendingNotificationSource(
      apiClient,
    );
    final battleAnimationCacheService = mini_royale.BattleAnimationCacheService(
      store: HiveBattleAnimationCacheStore(),
      remoteSource: PreviewBattleAnimationRemoteSource(),
    );
    await battleAnimationCacheService.initialize();
    final notificationService = NotificationService(
      apiClient,
      localRepository: legacyChatStore,
      messagingCore: messagingRuntime.core,
      credentials: credentials,
      legacyInstallationStore: HiveLegacyInstallationStore(),
      remoteSource: notificationRemoteSource,
      pendingNotificationSource: pendingNotificationSource,
    );
    await notificationService.initialize();
    final chatServiceFactory = ChatServiceFactory(
      apiClient: apiClient,
      messagingCore: messagingRuntime.core,
      authenticator: messagingRuntime.deviceIdentity == null
          ? null
          : DeviceEventAuthenticator(
              localIdentity: messagingRuntime.deviceIdentity!,
            ),
      deviceId: messagingRuntime.deviceIdentity?.deviceId,
      localRepository: legacyChatStore,
      remoteSource: legacyChatRemoteSource,
      transportFactory:
          ({required selfId, required friendId, required isCaller}) =>
              PreviewMessageTransport(),
      manualSignaling: ManualPeerSignaling(),
    );
    final authService = AuthService(
      apiClient,
      remoteSource: authRemoteSource,
      configuration: configuration,
    );
    await authService.init();
    return PreviewRuntime._(
      apiClient: apiClient,
      credentials: credentials,
      messagingRuntime: messagingRuntime,
      peerTrust: peerTrust,
      legacyChatStore: legacyChatStore,
      legacyChatRemoteSource: legacyChatRemoteSource,
      adminRemoteSource: adminRemoteSource,
      authRemoteSource: authRemoteSource,
      friendsRemoteSource: friendsRemoteSource,
      llmBotRemoteSource: llmBotRemoteSource,
      royaleRemoteSource: royaleRemoteSource,
      notificationRemoteSource: notificationRemoteSource,
      pendingNotificationSource: pendingNotificationSource,
      battleAnimationCacheService: battleAnimationCacheService,
      notificationService: notificationService,
      chatServiceFactory: chatServiceFactory,
      authService: authService,
    );
  }
}

Future<void> seedPreviewMessages(MessagingCoreService core) async {
  if (core.conversation('100:101').isNotEmpty) return;
  final created = await core
      .commands(actorId: '100', conversationId: '100:101')
      .create(
        '歡迎來到本地預覽',
        messageId: 'preview-welcome',
        eventId: 'preview-created-welcome',
        createdAt: DateTime.utc(2026, 10, 20, 1),
      );
  await core.repository.acknowledge(created.eventId);
  final edited = await core
      .commands(actorId: '100', conversationId: '100:101')
      .edit(
        created.messageId,
        '歡迎來到本地預覽（已編輯）',
        eventId: 'preview-edited-welcome',
        createdAt: DateTime.utc(2026, 10, 20, 1, 1),
      );
  if (edited != null) await core.repository.acknowledge(edited.eventId);
  final friend = await core
      .commands(actorId: '101', conversationId: '100:101')
      .create(
        '這是好友的離線訊息',
        messageId: 'preview-friend',
        eventId: 'preview-created-friend',
        createdAt: DateTime.utc(2026, 10, 20, 1, 2),
      );
  await core.repository.acknowledge(friend.eventId);
  final read = await core
      .commands(actorId: '100', conversationId: '100:101')
      .read(
        friend.messageId,
        eventId: 'preview-read-friend',
        createdAt: DateTime.utc(2026, 10, 20, 1, 3),
      );
  if (read != null) await core.repository.acknowledge(read.eventId);
  final recalled = await core
      .commands(actorId: '101', conversationId: '100:101')
      .create(
        '這則訊息示範收回',
        messageId: 'preview-recalled',
        eventId: 'preview-created-recalled',
        createdAt: DateTime.utc(2026, 10, 20, 1, 4),
      );
  await core.repository.acknowledge(recalled.eventId);
  final recall = await core
      .commands(actorId: '101', conversationId: '100:101')
      .recall(
        recalled.messageId,
        eventId: 'preview-recalled-event',
        createdAt: DateTime.utc(2026, 10, 20, 1, 5),
      );
  if (recall != null) await core.repository.acknowledge(recall.eventId);
}

Future<void> resetPreviewStorage(PlatformCredentialStore credentials) async {
  final key = await SecureMessagingKeyProvider(
    credentials: credentials,
  ).loadOrCreate('message-events');
  final box = await Hive.openBox<String>(
    'taiwan_brawl_message_events',
    encryptionCipher: HiveAesCipher(key),
  );
  await box.clear();
  final legacy = await Hive.openBox('chat_100_101');
  await legacy.clear();
}
