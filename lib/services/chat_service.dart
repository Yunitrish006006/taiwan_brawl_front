import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'package:user_basic_system/user_basic_system.dart' show DmService;

import '../models/chat_models.dart';
import 'api_client.dart';
import 'editable_dm_service.dart';
import 'legacy_chat_store.dart';
import 'legacy_chat_remote_source.dart';
import 'local_chat_repository.dart';
import 'message_chat_projection.dart';
import 'message_chat_sync_adapter.dart';
import 'messaging_core_service.dart';
import 'p2p_message_transport.dart';
import 'server_message_transport.dart';

typedef ChatMessageTransportFactory =
    MessageTransport Function({
      required int selfId,
      required int friendId,
      required bool isCaller,
    });

/// Chat service preserving the legacy [DmService] API during event migration.
///
/// - Send: POST /api/chat/dm/:friendId/send → stored in D1 pending_messages
/// - Receive: [ServerMessageTransport] polls the pending relay and feeds the
///   transport-neutral event repository.
/// - History: shared projection first, with injected legacy storage and server
///   history as migration fallbacks.
class ChatService implements DmService, EditableDmService {
  ChatService(
    this._apiClient, {
    MessagingCoreService? messagingCore,
    MessageRepository? eventRepository,
    EventAuthenticator? authenticator,
    EventAuthenticator? remoteAuthenticator,
    String? deviceId,
    ChatMessageTransportFactory? transportFactory,
    LegacyChatStore? localRepository,
    LegacyChatRemoteSource? remoteSource,
    PeerSignalingChannel? manualSignaling,
    P2PMessageTransportFactory? manualTransportFactory,
    this.p2pIceConfiguration = P2PMessageTransport.defaultIceConfiguration,
  }) : _messagingCore =
           messagingCore ??
           MessagingCoreService(
             repository: eventRepository ?? MessageRepository(),
           ),
       _authenticator = authenticator,
       _remoteAuthenticator = remoteAuthenticator,
       _deviceId = deviceId,
       _transportFactory = transportFactory,
       _localRepo = localRepository ?? LocalChatRepository(),
       _remoteSource = remoteSource ?? ServerLegacyChatRemoteSource(_apiClient),
       _manualSignaling = manualSignaling,
       _manualTransportFactory = manualTransportFactory;

  final ApiClient _apiClient;
  final MessagingCoreService _messagingCore;
  final EventAuthenticator? _authenticator;
  final EventAuthenticator? _remoteAuthenticator;
  final String? _deviceId;
  final ChatMessageTransportFactory? _transportFactory;
  final LegacyChatStore _localRepo;
  final LegacyChatRemoteSource _remoteSource;
  final PeerSignalingChannel? _manualSignaling;
  final P2PMessageTransportFactory? _manualTransportFactory;
  final Map<String, dynamic> p2pIceConfiguration;

  final StreamController<ChatMessage> _messageStream =
      StreamController.broadcast();

  @override
  Stream<ChatMessage> get messageStream => _messageStream.stream;

  int? _currentSelfId;
  int? _currentFriendId;
  MessageSyncEngine? _syncEngine;
  Future<void> _lifecycleTail = Future<void>.value();
  final Map<String, String> _messageEventIds = <String, String>{};

  bool get manualP2pEnabled => _manualSignaling != null;

  String? get manualDeviceId => _deviceId;

  // ── history ───────────────────────────────────────────────────────────────

  /// Returns locally stored messages. If empty, falls back to server history.
  @override
  Future<List<ChatMessage>> fetchHistory(
    int selfId,
    int friendId, {
    String? before,
  }) async {
    final projected = _projectedMessages(selfId, friendId);
    final local = await _localRepo.getMessages(selfId, friendId);
    if (local.isNotEmpty) {
      // Always replay the compatibility cache into the shared projection.
      // The projection may already contain newer events from a previous
      // session; returning early would strand older legacy rows forever.
      await _promoteLegacyMessages(local, selfId, friendId);
      final promoted = _projectedMessages(selfId, friendId);
      return promoted.isNotEmpty ? promoted : local;
    }
    if (projected.isNotEmpty) return projected;

    List<ChatMessage> serverMessages;
    try {
      serverMessages = await _remoteSource.fetchHistory(
        friendId,
        before: before,
      );
    } catch (error) {
      // An initial history read must remain usable without a network. Preserve
      // explicit HTTP responses (auth/server errors) for the UI, but treat a
      // transport-level failure as an empty local conversation.
      if (error is ApiException && error.statusCode != null) rethrow;
      return const <ChatMessage>[];
    }
    await _promoteLegacyMessages(serverMessages, selfId, friendId);
    final projectedAfterSync = _projectedMessages(selfId, friendId);
    return projectedAfterSync.isNotEmpty ? projectedAfterSync : serverMessages;
  }

  /// Force-fetch history from server and merge into local cache (no data loss).
  @override
  Future<List<ChatMessage>> syncFromServer(int selfId, int friendId) async {
    List<ChatMessage> serverMessages;
    try {
      serverMessages = await _remoteSource.fetchHistory(friendId);
    } catch (error) {
      if (error is ApiException && error.statusCode != null) rethrow;
      return _projectedMessages(selfId, friendId);
    }
    await _promoteLegacyMessages(serverMessages, selfId, friendId);
    // Return merged result (local + server)
    final projected = _projectedMessages(selfId, friendId);
    return projected.isNotEmpty
        ? projected
        : _localRepo.getMessages(selfId, friendId);
  }

  /// Export local chat history for one conversation and upload to server.
  /// Valid for 1 hour, one-time download. Both participants share the same key.
  @override
  Future<void> uploadSyncData(int selfId, int friendId) async {
    final projected = _projectedMessages(selfId, friendId);
    final exported = projected.isNotEmpty
        ? MessageChatSyncAdapter.exportMessages(projected, selfId, friendId)
        : await _localRepo.exportAll(selfId, [friendId]);
    if (exported.isEmpty) return;
    await _remoteSource.uploadSyncData(friendId, exported);
  }

  /// Download sync data for one conversation and merge into local cache.
  @override
  Future<void> downloadAndMergeSyncData(int friendId) async {
    final data = await _remoteSource.downloadSyncData(friendId);
    await _localRepo.importAll(data);
    final selfId = _currentSelfId;
    if (selfId == null) return;
    for (final event in MessageChatSyncAdapter.importEvents(
      data,
      selfId,
      friendId,
    )) {
      await _messagingCore.acceptRemote(event);
    }
  }

  // ── connect ───────────────────────────────────────────────────────────────

  @override
  Future<void> connectToDm(int selfId, int friendId, {bool isCaller = true}) {
    final operation = _lifecycleTail.then<void>(
      (_) => _connectToDm(selfId, friendId, isCaller: isCaller),
    );
    _lifecycleTail = operation.catchError((Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _connectToDm(
    int selfId,
    int friendId, {
    required bool isCaller,
  }) async {
    _currentSelfId = selfId;
    _currentFriendId = friendId;
    await _stopEngine();

    // The event transport owns polling and acknowledgements. Legacy send and
    // recall remain active until their event route is deployed and verified.
    final transport =
        _transportFactory?.call(
          selfId: selfId,
          friendId: friendId,
          isCaller: isCaller,
        ) ??
        ServerMessageTransport(
          apiClient: _apiClient,
          selfId: selfId,
          friendId: friendId,
        );
    final engine = _messagingCore.syncEngine(
      transport: transport,
      authenticator: _remoteAuthenticator,
      onRemoteEvent: _handleRemoteEvent,
      eventFilter: (event) =>
          event.conversationId == _conversationId(selfId, friendId),
    );
    _syncEngine = engine;
    await engine.start();
  }

  /// Prepares a serverless P2P transport without waiting for its DataChannel.
  /// The caller can then export a negotiation bundle for out-of-band exchange.
  Future<void> prepareManualP2p({required bool isCaller}) async {
    final signaling = _manualSignaling;
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (signaling == null) {
      throw StateError('Manual P2P signaling is not configured');
    }
    if (selfId == null || friendId == null) {
      throw StateError('A DM must be connected before manual P2P setup');
    }
    await _stopEngine();
    final transport =
        _manualTransportFactory?.call(
          friendId: friendId,
          signalingService: signaling,
          isCaller: isCaller,
          iceConfiguration: p2pIceConfiguration,
        ) ??
        P2PMessageTransport(
          friendId: friendId,
          signalingService: signaling,
          isCaller: isCaller,
          iceConfiguration: p2pIceConfiguration,
        );
    _syncEngine = _messagingCore.syncEngine(
      transport: transport,
      authenticator: _remoteAuthenticator,
      onRemoteEvent: _handleRemoteEvent,
      eventFilter: (event) =>
          event.conversationId == _conversationId(selfId, friendId),
    );
    await transport.prepare();
  }

  String exportManualP2pBundle({
    required String sessionId,
    required String senderDeviceId,
  }) {
    final signaling = _manualSignaling;
    if (signaling is! ManualPeerSignaling) {
      throw StateError('Manual P2P signaling is not configured');
    }
    return signaling.exportBundle(
      sessionId: sessionId,
      senderDeviceId: senderDeviceId,
    );
  }

  void importManualP2pBundle(
    String encoded, {
    String? expectedSessionId,
    String? expectedSenderDeviceId,
  }) {
    final signaling = _manualSignaling;
    if (signaling is! ManualPeerSignaling) {
      throw StateError('Manual P2P signaling is not configured');
    }
    signaling.importBundle(
      encoded,
      expectedSessionId: expectedSessionId,
      expectedSenderDeviceId: expectedSenderDeviceId,
    );
  }

  Future<void> completeManualP2p() async {
    final engine = _syncEngine;
    if (engine == null) {
      throw StateError('Manual P2P has not been prepared');
    }
    await engine.start();
  }

  // ── send ──────────────────────────────────────────────────────────────────

  @override
  Future<void> sendMessage(int receiverId, String text) async {
    final createdAt = DateTime.now().toIso8601String();
    final selfId = _currentSelfId;

    try {
      MessageEvent? event;
      if (selfId != null) {
        event = await _messageCommands(
          selfId,
          receiverId,
        ).create(text, createdAt: DateTime.parse(createdAt).toUtc());
        _messageEventIds['${event.createdAt.toIso8601String()}_$selfId'] =
            event.messageId;
        _emitProjected(selfId, receiverId, messageId: event.messageId);
      }
      final sentAsEvent = event != null && await _tryFlushEvent(event);
      if (sentAsEvent) {
        _emitProjected(selfId!, receiverId, messageId: event.messageId);
        return;
      }

      // A shared event is already projected and durable locally. When the
      // event transport is disconnected, do not fall through to a legacy HTTP
      // request: that would violate offline-first delivery and create two
      // competing delivery paths. The outbox will retry on the next connect.
      if (event != null && _syncEngine?.started != true) {
        return;
      }

      // Compatibility fallback: older deployments do not expose /event.
      final res = await _remoteSource.sendMessage(receiverId, text);
      if (event != null) {
        await _messagingCore.repository.acknowledge(event.eventId);
        _emitProjected(selfId!, receiverId);
        return;
      }
      final serverCreatedAt = res['createdAt'] as String? ?? createdAt;
      if (selfId != null) {
        final delivered = ChatMessage(
          senderId: selfId,
          receiverId: receiverId,
          text: text,
          createdAt: serverCreatedAt,
          isPending: false,
        );
        await _localRepo.saveMessage(selfId, delivered);
        if (!_messageStream.isClosed) _messageStream.add(delivered);
      }
    } catch (_) {
      // isPending stays true in UI
    }
  }

  /// Edits a locally owned message through the shared event outbox.
  ///
  /// There is no legacy edit endpoint. When the event transport is offline,
  /// the edit remains durable locally and is flushed when a compatible
  /// transport becomes available.
  @override
  Future<void> editMessage(ChatMessage msg, String newText) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    final text = newText.trim();
    if (selfId == null || friendId == null || text.isEmpty) return;
    if (msg.senderId != selfId || msg.isRecalled || msg.text == text) return;

    final eventMessageId = _eventMessageIdFor(msg, selfId);
    final commands = _messageCommands(selfId, friendId);
    var projection = _messagingCore.repository.projectionFor(eventMessageId);
    if (projection == null) {
      await commands.create(
        msg.text,
        messageId: eventMessageId,
        eventId: 'legacy-created:$eventMessageId',
        createdAt: DateTime.parse(msg.createdAt).toUtc(),
      );
      projection = _messagingCore.repository.projectionFor(eventMessageId);
    }
    if (projection == null || projection.recalled) return;

    final event = await commands.edit(
      eventMessageId,
      text,
      eventId: 'edited:$eventMessageId:${projection.revision + 1}',
    );
    if (event == null) return;
    _emitProjected(selfId, friendId, messageId: event.messageId);
    if (_syncEngine?.started == true) {
      try {
        await _syncEngine!.syncNow();
      } on ApiException {
        // The read event remains in the durable outbox for reconnect. Read
        // marking is best-effort from the UI and must not surface a
        // background transport failure as an unhandled async error.
      } catch (_) {
        // The local edit is durable in the outbox; retry it on reconnect.
      }
    }
  }

  /// Appends a durable read event for an incoming message.
  ///
  /// Read state follows the same offline-first path as edits and recalls: it
  /// is projected locally immediately and remains in the shared outbox until
  /// a transport can deliver it.
  Future<void> markMessageRead(ChatMessage message) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (selfId == null || friendId == null || message.senderId != friendId) {
      return;
    }
    final eventMessageId = _eventMessageIdFor(message, selfId);
    final projection = _messagingCore.repository.projectionFor(eventMessageId);
    if (projection == null || projection.readBy.contains(selfId.toString())) {
      return;
    }
    final event = await _messageCommands(
      selfId,
      friendId,
    ).read(eventMessageId, eventId: 'read:$eventMessageId:$selfId');
    if (event == null) return;
    _emitProjected(selfId, friendId, messageId: event.messageId);
    if (_syncEngine?.started == true) {
      try {
        await _syncEngine!.syncNow();
      } on ApiException catch (error) {
        if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      } catch (_) {
        // The read event remains in the durable outbox for reconnect.
      }
    }
  }

  // ── recall ────────────────────────────────────────────────────────────────

  /// Recalls a message. Marks it locally and notifies the receiver via server.
  @override
  Future<void> recallMessage(ChatMessage msg) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (selfId == null || friendId == null) return;

    try {
      final eventMessageId = _eventMessageIdFor(msg, selfId);
      final projection = _messagingCore.repository.projectionFor(
        eventMessageId,
      );
      String? legacyCreatedEventId;
      final commands = _messageCommands(selfId, friendId);
      if (projection == null) {
        legacyCreatedEventId = 'legacy-created:$eventMessageId';
        await commands.create(
          msg.text,
          messageId: eventMessageId,
          eventId: legacyCreatedEventId,
          createdAt: DateTime.parse(msg.createdAt).toUtc(),
        );
      }
      final current = _messagingCore.repository.projectionFor(eventMessageId);
      if (current?.recalled == true) return;
      if (current != null) {
        final event = await commands.recall(
          eventMessageId,
          eventId: 'legacy-recalled:$eventMessageId',
        );
        if (event == null) return;
        _emitProjected(selfId, friendId, messageId: event.messageId);
        final sentAsEvent = await _tryFlushEvent(event);
        if (sentAsEvent) return;
        if (_syncEngine?.started != true) {
          // Keep the recall event pending until a transport is available.
          // A disconnected client must not acknowledge locally or use the
          // legacy HTTP path as an accidental online fallback.
          return;
        }
        await _messagingCore.repository.acknowledge(event.eventId);
        if (legacyCreatedEventId != null) {
          await _messagingCore.repository.acknowledge(legacyCreatedEventId);
        }
      }

      // Compatibility fallback: older deployments only understand messageKey.
      await _remoteSource.recallMessage(friendId, msg.messageKey);
      _emitProjected(selfId, friendId, messageId: eventMessageId);
    } catch (_) {
      // Best-effort; local state already updated
    }
  }

  Future<bool> _tryFlushEvent(MessageEvent event) async {
    final engine = _syncEngine;
    if (engine == null || !engine.started) return false;
    try {
      await engine.syncNow();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) return false;
      rethrow;
    }
  }

  String _eventMessageIdFor(ChatMessage message, int selfId) {
    final known = _messageEventIds[message.messageKey];
    if (known != null) return known;

    final createdAt = DateTime.tryParse(message.createdAt)?.toUtc();
    if (createdAt != null) {
      MessageEvent? createdAtMatch;
      for (final event in _messagingCore.repository.events) {
        if (event.type != MessageEventType.created ||
            event.actorId != selfId.toString() ||
            event.createdAt.toUtc() != createdAt) {
          continue;
        }
        if (event.body == message.text) {
          _messageEventIds[message.messageKey] = event.messageId;
          return event.messageId;
        }
        createdAtMatch ??= event;
      }
      if (createdAtMatch != null) {
        _messageEventIds[message.messageKey] = createdAtMatch.messageId;
        return createdAtMatch.messageId;
      }
    }
    return message.messageKey;
  }

  static String _conversationId(int userIdA, int userIdB) {
    final low = userIdA < userIdB ? userIdA : userIdB;
    final high = userIdA < userIdB ? userIdB : userIdA;
    return '$low:$high';
  }

  MessageCommandService _messageCommands(int selfId, int friendId) {
    return _messagingCore.commands(
      actorId: selfId.toString(),
      conversationId: _conversationId(selfId, friendId),
      deviceId: _deviceId,
      authenticator: _authenticator,
    );
  }

  List<ChatMessage> _projectedMessages(int selfId, int friendId) {
    return MessageChatProjection.toMessages(
      projections: _messagingCore.repository.projectionsFor(
        _conversationId(selfId, friendId),
      ),
      selfId: selfId,
      friendId: friendId,
      pendingMessageIds: _messagingCore.repository.pendingOutbox.map(
        (event) => event.messageId,
      ),
    );
  }

  Future<void> _promoteLegacyMessages(
    Iterable<ChatMessage> messages,
    int selfId,
    int friendId,
  ) async {
    for (final event in MessageChatSyncAdapter.eventsFromMessages(
      messages,
      selfId,
      friendId,
    )) {
      await _messagingCore.acceptRemote(
        event,
        authenticator: _remoteAuthenticator,
      );
    }
  }

  void _emitProjected(int selfId, int friendId, {String? messageId}) {
    if (_messageStream.isClosed) return;
    if (messageId != null) {
      final projection = _messagingCore.repository.projectionFor(messageId);
      final message = projection == null
          ? null
          : MessageChatProjection.toMessage(
              projection: projection,
              selfId: selfId,
              friendId: friendId,
              pendingMessageIds: _messagingCore.repository.pendingOutbox.map(
                (event) => event.messageId,
              ),
            );
      if (message != null) {
        _messageStream.add(message);
        return;
      }
    }
    final projected = _projectedMessages(selfId, friendId);
    if (projected.isNotEmpty) _messageStream.add(projected.last);
  }

  // ── event projection bridge ──────────────────────────────────────────────

  Future<void> _handleRemoteEvent(MessageEvent event) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (selfId == null || friendId == null) return;

    final senderId = int.tryParse(event.actorId);
    if (senderId == null || senderId != friendId) return;

    _messageEventIds[event.messageId] = event.messageId;
    _messageEventIds['${event.createdAt.toIso8601String()}_$senderId'] =
        event.messageId;
    _emitProjected(selfId, friendId, messageId: event.messageId);
  }

  // ── disconnect / dispose ──────────────────────────────────────────────────

  /// Waits for the active sync engine to release its transport.
  Future<void> disconnectAsync() {
    final operation = _lifecycleTail.then<void>((_) => _stopEngine());
    _lifecycleTail = operation.catchError((Object _, StackTrace _) {});
    return operation;
  }

  /// Legacy synchronous API retained for [DmService] consumers.
  @override
  void disconnect() {
    unawaited(disconnectAsync());
  }

  Future<void> _stopEngine() async {
    final engine = _syncEngine;
    _syncEngine = null;
    await engine?.stop();
  }

  Future<void> disposeAsync() async {
    await _lifecycleTail;
    await _stopEngine();
    _manualSignaling?.dispose();
    await _messageStream.close();
  }

  void dispose() {
    unawaited(disposeAsync());
  }
}
