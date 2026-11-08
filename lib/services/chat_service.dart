import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/direct_message.dart';
import '../models/message_history_page.dart';
import 'direct_message_session.dart';
import 'direct_message_sync_service.dart';
import 'legacy_chat_delivery_adapter.dart';
import 'legacy_chat_history_adapter.dart';
import 'legacy_chat_sync_snapshot_adapter.dart';
import 'manual_p2p_dm_service.dart';
import 'messaging_core_service.dart';
import 'fallback_message_transport.dart';
import 'relay_fallback_dm_service.dart';
import 'remote_source_exception.dart';
import 'retryable_dm_service.dart';

typedef DirectMessageTransportFactory =
    MessageTransport Function({
      required int selfId,
      required int friendId,
      required bool isCaller,
    });

typedef ManualP2PTransportFactory =
    NegotiatingMessageTransport Function({
      required int friendId,
      required PeerSignalingChannel signalingService,
      required bool isCaller,
    });

/// Chat service supplying the app-owned DM UI contract during event migration.
/// Storage, remote compatibility, and event transport are supplied by ports.
class ChatService
    implements
        DirectMessageSession,
        DirectMessageSyncService,
        RetryableDmService,
        ManualP2pDmService,
        RelayFallbackDmService {
  ChatService({
    required MessagingCoreService messagingCore,
    EventAuthenticator? authenticator,
    EventAuthenticator? remoteAuthenticator,
    EventAuthenticator? p2pAuthenticator,
    String? deviceId,
    required DirectMessageTransportFactory transportFactory,
    required LegacyChatDeliveryAdapter legacyDelivery,
    required LegacyChatHistoryAdapter legacyHistory,
    required LegacyChatSyncSnapshotAdapter legacySyncSnapshots,
    PeerSignalingChannel? manualSignaling,
    ManualP2PTransportFactory? manualTransportFactory,
    this.outboxRetryInterval = const Duration(seconds: 5),
  }) : _messagingCore = messagingCore,
       _authenticator = authenticator,
       _remoteAuthenticator = remoteAuthenticator,
       _p2pAuthenticator = p2pAuthenticator,
       _deviceId = deviceId,
       _transportFactory = transportFactory,
       _legacyDelivery = legacyDelivery,
       _legacyHistory = legacyHistory,
       _legacySyncSnapshots = legacySyncSnapshots,
       _manualSignaling = manualSignaling,
       _manualTransportFactory = manualTransportFactory;

  final MessagingCoreService _messagingCore;
  final EventAuthenticator? _authenticator;
  final EventAuthenticator? _remoteAuthenticator;
  final EventAuthenticator? _p2pAuthenticator;
  final String? _deviceId;
  final DirectMessageTransportFactory _transportFactory;
  final LegacyChatDeliveryAdapter _legacyDelivery;
  final LegacyChatHistoryAdapter _legacyHistory;
  final LegacyChatSyncSnapshotAdapter _legacySyncSnapshots;
  final PeerSignalingChannel? _manualSignaling;
  final ManualP2PTransportFactory? _manualTransportFactory;
  final Duration outboxRetryInterval;

  final StreamController<DirectMessage> _directMessageStream =
      StreamController.broadcast();
  final StreamController<void> _connectionStateChanges =
      StreamController<void>.broadcast();

  @override
  Stream<DirectMessage> get directMessageStream => _directMessageStream.stream;

  int? _currentSelfId;
  int? _currentFriendId;
  MessageSyncEngine? _syncEngine;
  MessageTransport? _activeTransport;
  StreamSubscription<void>? _transportStateSubscription;
  Future<void> _lifecycleTail = Future<void>.value();
  Future<void>? _disposeFuture;
  bool _manualPrepared = false;

  bool get manualP2pEnabled => _manualSignaling != null;

  String? get manualDeviceId => _deviceId;

  @override
  Duration get p2pRetryInterval => outboxRetryInterval;

  @override
  Stream<void> get connectionStateChanges => _connectionStateChanges.stream;

  @override
  bool get relayFallbackChoiceRequired {
    final transport = _activeTransport;
    return transport is FallbackMessageTransport &&
        transport.relayChoiceRequired;
  }

  @override
  bool get relayFallbackActive {
    final transport = _activeTransport;
    return transport is FallbackMessageTransport && transport.relayActive;
  }

  @override
  bool get p2pActive {
    final transport = _activeTransport;
    return transport is FallbackMessageTransport && transport.p2pActive;
  }

  @override
  Future<bool> retryP2PConnection() async {
    var connected = false;
    await _enqueueLifecycle(() async {
      final transport = _activeTransport;
      final engine = _syncEngine;
      if (transport is! FallbackMessageTransport || engine == null) return;
      if (!await transport.retryPrimary()) return;
      try {
        if (engine.started) {
          await engine.syncNow();
        } else {
          await engine.start();
        }
        connected = transport.p2pActive;
      } catch (_) {
        connected = false;
      }
    });
    return connected;
  }

  @override
  bool get enabled => manualP2pEnabled;

  @override
  String? get localDeviceId => manualDeviceId;

  @override
  Future<List<DirectMessage>> loadConversation(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    await _legacyHistory.loadAndPromote(selfId, friendId, before: before);
    return _projectedDirectMessages(selfId, friendId);
  }

  @override
  Future<MessageHistoryPage<DirectMessage>> loadConversationPage(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    final legacyPage = await _legacyHistory.loadPageAndPromote(
      selfId,
      friendId,
      before: before,
    );
    return MessageHistoryPage(
      messages: _projectedDirectMessages(selfId, friendId),
      hasMore: legacyPage.hasMore,
      nextCursor: legacyPage.nextCursor,
    );
  }

  @override
  Future<List<DirectMessage>> refreshConversation(
    int selfId,
    int friendId,
  ) async {
    await _legacyHistory.refreshAndPromote(selfId, friendId);
    return _projectedDirectMessages(selfId, friendId);
  }

  /// Export local chat history for one conversation and upload to server.
  /// Valid for 1 hour, one-time download. Both participants share the same key.
  @override
  Future<void> uploadSyncData(int selfId, int friendId) async {
    await _legacySyncSnapshots.upload(selfId, friendId);
  }

  /// Download sync data for one conversation and merge into local cache.
  @override
  Future<void> downloadAndMergeSyncData(int friendId) async {
    await _legacySyncSnapshots.downloadAndMerge(
      friendId,
      selfId: _currentSelfId,
    );
  }

  // ── connect ───────────────────────────────────────────────────────────────

  @override
  Future<void> connectToDm(int selfId, int friendId, {bool isCaller = true}) {
    return _enqueueLifecycle(
      () => _connectToDm(selfId, friendId, isCaller: isCaller),
    );
  }

  Future<void> _enqueueLifecycle(Future<void> Function() action) {
    if (_disposeFuture != null) {
      return Future<void>.error(StateError('The DM session is disposed'));
    }
    final operation = _lifecycleTail.then<void>((_) => action());
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
    final transport = _transportFactory(
      selfId: selfId,
      friendId: friendId,
      isCaller: isCaller,
    );
    _activeTransport = transport;
    if (transport is FallbackMessageTransport) {
      _transportStateSubscription = transport.connectionStateChanges.listen((
        _,
      ) {
        if (!_connectionStateChanges.isClosed) {
          _connectionStateChanges.add(null);
        }
      });
    }
    final engine = _messagingCore.syncEngine(
      transport: transport,
      authenticator: _remoteAuthenticator,
      onRemoteEvent: _handleRemoteEvent,
      eventFilter: (event) =>
          event.conversationId == _conversationId(selfId, friendId),
      retryInterval: outboxRetryInterval,
    );
    _syncEngine = engine;
    await engine.start();
  }

  @override
  Future<void> useRelayFallback() => _enqueueLifecycle(() async {
    final transport = _activeTransport;
    final engine = _syncEngine;
    if (transport is! FallbackMessageTransport || engine == null) {
      throw StateError('Relay fallback is unavailable for this conversation');
    }
    transport.selectRelayFallback();
    if (engine.started) {
      await transport.connect();
      await engine.syncNow();
    } else {
      await engine.start();
    }
  });

  /// Prepares a serverless P2P transport without waiting for its DataChannel.
  /// The caller can then export a negotiation bundle for out-of-band exchange.
  @override
  Future<void> prepare({required bool isCaller}) =>
      _enqueueLifecycle(() => _prepare(isCaller: isCaller));

  Future<void> _prepare({required bool isCaller}) async {
    final signaling = _manualSignaling;
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (signaling == null) {
      throw StateError('Manual P2P signaling is not configured');
    }
    if (selfId == null || friendId == null) {
      throw StateError('A DM must be connected before manual P2P setup');
    }
    final p2pAuthenticator = _p2pAuthenticator;
    if (p2pAuthenticator == null) {
      throw StateError(
        'P2P requires a device identity and an explicitly trusted peer',
      );
    }
    if (_manualPrepared) return;
    await _stopEngine();
    final transportFactory = _manualTransportFactory;
    if (transportFactory == null) {
      throw StateError('Manual P2P transport is not configured');
    }
    final transport = transportFactory(
      friendId: friendId,
      signalingService: signaling,
      isCaller: isCaller,
    );
    _activeTransport = transport;
    _syncEngine = _messagingCore.syncEngine(
      transport: transport,
      authenticator: p2pAuthenticator,
      onRemoteEvent: _handleRemoteEvent,
      eventFilter: (event) =>
          event.conversationId == _conversationId(selfId, friendId),
      retryInterval: outboxRetryInterval,
    );
    await transport.prepare();
    _manualPrepared = true;
  }

  @override
  Future<String> exportBundle({
    required String sessionId,
    required String senderDeviceId,
  }) {
    if (_disposeFuture != null) {
      return Future<String>.error(StateError('The DM session is disposed'));
    }
    final signaling = _manualSignaling;
    if (signaling is! ManualPeerSignaling) {
      throw StateError('Manual P2P signaling is not configured');
    }
    final authenticator = _p2pAuthenticator;
    if (authenticator == null) {
      throw StateError('Manual P2P requires a local device signer');
    }
    return signaling.exportSignedBundle(
      sessionId: sessionId,
      senderDeviceId: senderDeviceId,
      authenticator: authenticator,
    );
  }

  @override
  Future<void> importBundle(
    String encoded, {
    String? expectedSessionId,
    String? expectedSenderDeviceId,
  }) {
    if (_disposeFuture != null) {
      return Future<void>.error(StateError('The DM session is disposed'));
    }
    final signaling = _manualSignaling;
    if (signaling is! ManualPeerSignaling) {
      throw StateError('Manual P2P signaling is not configured');
    }
    final authenticator = _p2pAuthenticator;
    if (authenticator == null) {
      throw StateError('Manual P2P requires a trusted-device verifier');
    }
    return signaling.importSignedBundle(
      encoded,
      authenticator: authenticator,
      expectedSessionId: expectedSessionId,
      expectedSenderDeviceId: expectedSenderDeviceId,
    );
  }

  @override
  Future<void> complete() => _enqueueLifecycle(() async {
    final engine = _syncEngine;
    if (engine == null) {
      throw StateError('Manual P2P has not been prepared');
    }
    await engine.start();
  });

  // ── send ──────────────────────────────────────────────────────────────────

  Future<void> _sendText(int receiverId, String text) async {
    final createdAt = DateTime.now().toIso8601String();
    final selfId = _currentSelfId;

    try {
      MessageEvent? event;
      if (selfId != null) {
        event = await _messageCommands(
          selfId,
          receiverId,
        ).create(text, createdAt: DateTime.parse(createdAt).toUtc());
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
      await _legacyDelivery.sendText(
        receiverId,
        text,
        selfId: selfId,
        fallbackCreatedAt: createdAt,
        persistLegacyCopy: event == null,
      );
      if (event != null) {
        await _messagingCore.repository.acknowledge(event.eventId);
        _emitProjected(selfId!, receiverId);
        return;
      }
    } catch (_) {
      // Keep the durable outbox event for reconnect, but surface the failure
      // so the composer can preserve the text and explain what happened.
      rethrow;
    }
  }

  @override
  Future<void> sendText(int receiverId, String text) =>
      _sendText(receiverId, text);

  @override
  Future<void> retryPendingMessage(int receiverId, String text) async {
    final selfId = _currentSelfId;
    if (selfId == null) {
      throw StateError('The chat is not connected to a user session');
    }
    final normalizedText = text.trim();
    final conversationId = _conversationId(selfId, receiverId);
    final pending = _messagingCore.repository.pendingOutbox
        .where(
          (event) =>
              event.type == MessageEventType.created &&
              event.actorId == selfId.toString() &&
              event.conversationId == conversationId &&
              event.body == normalizedText,
        )
        .lastOrNull;

    // The automatic reconnect may already have delivered the event while the
    // draft remained visible. In that case, consider retry complete.
    if (pending == null) return;
    final sentAsEvent = await _tryFlushEvent(pending);
    if (sentAsEvent) {
      _emitProjected(selfId, receiverId, messageId: pending.messageId);
      return;
    }
    if (_syncEngine?.started != true) return;

    // Compatibility with deployments that do not yet expose the event route.
    await _legacyDelivery.sendText(receiverId, normalizedText);
    await _messagingCore.repository.acknowledge(pending.eventId);
    _emitProjected(selfId, receiverId, messageId: pending.messageId);
  }

  /// Edits a locally owned message through the shared event outbox.
  ///
  /// There is no legacy edit endpoint. When the event transport is offline,
  /// the edit remains durable locally and is flushed when a compatible
  /// transport becomes available.
  @override
  Future<void> editProjectedMessage(String messageId, String newText) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    final text = newText.trim();
    final projection = _messagingCore.repository.projectionFor(messageId);
    if (selfId == null ||
        friendId == null ||
        projection == null ||
        projection.authorId != selfId.toString() ||
        projection.recalled ||
        text.isEmpty) {
      return;
    }
    final pendingEdit = _messagingCore.repository.pendingOutbox
        .where(
          (candidate) =>
              candidate.messageId == messageId &&
              candidate.type == MessageEventType.edited &&
              candidate.body == text,
        )
        .lastOrNull;
    final event = projection.visibleBody == text
        ? pendingEdit
        : await _messageCommands(selfId, friendId).edit(
            messageId,
            text,
            eventId: 'edited:$messageId:${projection.revision + 1}',
          );
    if (event == null) return;
    _emitProjected(selfId, friendId, messageId: event.messageId);
    if (_syncEngine?.started != true) {
      throw StateError(
        'Edit is saved locally but the message transport is not connected',
      );
    }
    final delivered = await _tryFlushEvent(event);
    if (!delivered) {
      throw RemoteSourceException(
        'The server does not support message edit events yet',
        statusCode: 404,
      );
    }
  }

  @override
  Future<void> markProjectedMessageRead(String messageId) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    final projection = _messagingCore.repository.projectionFor(messageId);
    if (selfId == null ||
        friendId == null ||
        projection == null ||
        projection.authorId != friendId.toString() ||
        projection.readBy.contains(selfId.toString())) {
      return;
    }
    final event = await _messageCommands(
      selfId,
      friendId,
    ).read(messageId, eventId: 'read:$messageId:$selfId');
    if (event == null) return;
    _emitProjected(selfId, friendId, messageId: event.messageId);
    if (_syncEngine?.started == true) {
      try {
        await _syncEngine!.syncNow();
      } on RemoteSourceException catch (error) {
        if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      } catch (_) {
        // The read event remains in the durable outbox for reconnect.
      }
    }
  }

  // ── recall ────────────────────────────────────────────────────────────────

  /// Recalls a locally owned projection through the shared event outbox.
  @override
  Future<void> recallProjectedMessage(String messageId) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    final projection = _messagingCore.repository.projectionFor(messageId);
    if (selfId == null ||
        friendId == null ||
        projection == null ||
        projection.authorId != selfId.toString()) {
      return;
    }

    final pendingRecall = _messagingCore.repository.pendingOutbox
        .where(
          (candidate) =>
              candidate.messageId == messageId &&
              candidate.type == MessageEventType.recalled,
        )
        .lastOrNull;
    if (projection.recalled) {
      if (pendingRecall == null) return;
      if (_syncEngine?.started != true) {
        throw StateError(
          'Recall is saved locally but the message transport is not connected',
        );
      }
      if (!await _tryFlushEvent(pendingRecall)) {
        await _messagingCore.repository.acknowledge(pendingRecall.eventId);
        await _sendLegacyRecall(friendId, projection, selfId, messageId);
      }
      return;
    }

    final event = await _messageCommands(
      selfId,
      friendId,
    ).recall(messageId, eventId: 'legacy-recalled:$messageId');
    if (event == null) return;
    _emitProjected(selfId, friendId, messageId: event.messageId);
    if (await _tryFlushEvent(event)) return;
    if (_syncEngine?.started != true) {
      throw StateError(
        'Recall is saved locally but the message transport is not connected',
      );
    }
    await _messagingCore.repository.acknowledge(event.eventId);
    await _sendLegacyRecall(friendId, projection, selfId, messageId);
  }

  Future<void> _sendLegacyRecall(
    int friendId,
    MessageProjection projection,
    int selfId,
    String eventMessageId,
  ) async {
    await _legacyDelivery.recallProjection(
      friendId,
      projection,
      selfId: selfId,
    );
    _emitProjected(selfId, friendId, messageId: eventMessageId);
  }

  Future<bool> _tryFlushEvent(MessageEvent event) async {
    final engine = _syncEngine;
    if (engine == null || !engine.started) return false;
    try {
      await engine.syncNow();
      return !_messagingCore.repository.pendingOutbox.any(
        (pending) => pending.eventId == event.eventId,
      );
    } on RemoteSourceException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) return false;
      rethrow;
    }
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

  List<DirectMessage> _projectedDirectMessages(int selfId, int friendId) {
    final projections = _messagingCore.repository.projectionsFor(
      _conversationId(selfId, friendId),
    )..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final pendingIds = _pendingMessageIds.toSet();
    return [
      for (final projection in projections)
        DirectMessage.fromProjection(
          projection,
          isPending: pendingIds.contains(projection.messageId),
        ),
    ];
  }

  void _emitProjected(int selfId, int friendId, {String? messageId}) {
    if (_directMessageStream.isClosed) return;
    if (messageId != null) {
      final projection = _messagingCore.repository.projectionFor(messageId);
      if (projection != null) {
        _directMessageStream.add(
          DirectMessage.fromProjection(
            projection,
            isPending: _pendingMessageIds.contains(projection.messageId),
          ),
        );
      }
      if (projection != null) return;
    }
    final direct = _projectedDirectMessages(selfId, friendId);
    if (direct.isNotEmpty) _directMessageStream.add(direct.last);
  }

  Iterable<String> get _pendingMessageIds => _messagingCore
      .repository
      .pendingOutbox
      .where((event) => event.type == MessageEventType.created)
      .map((event) => event.messageId);

  // ── event projection bridge ──────────────────────────────────────────────

  Future<void> _handleRemoteEvent(MessageEvent event) async {
    final selfId = _currentSelfId;
    final friendId = _currentFriendId;
    if (selfId == null || friendId == null) return;

    final senderId = int.tryParse(event.actorId);
    if (senderId == null || senderId != friendId) return;

    _emitProjected(selfId, friendId, messageId: event.messageId);
  }

  // ── disconnect / dispose ──────────────────────────────────────────────────

  /// Waits for the active sync engine to release its transport.
  Future<void> disconnectAsync() {
    final disposal = _disposeFuture;
    if (disposal != null) return disposal;
    return _enqueueLifecycle(_stopEngine);
  }

  /// Synchronous lifecycle operation exposed by the app-owned DM port.
  @override
  void disconnect() {
    unawaited(disconnectAsync());
  }

  Future<void> _stopEngine() async {
    final engine = _syncEngine;
    _syncEngine = null;
    _activeTransport = null;
    _manualPrepared = false;
    await _transportStateSubscription?.cancel();
    _transportStateSubscription = null;
    await engine?.stop();
  }

  Future<void> disposeAsync() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    final operation = _lifecycleTail.then<void>((_) async {
      try {
        await _stopEngine();
      } finally {
        _manualSignaling?.dispose();
        if (!_directMessageStream.isClosed) {
          await _directMessageStream.close();
        }
        if (!_connectionStateChanges.isClosed) {
          await _connectionStateChanges.close();
        }
      }
    });
    _lifecycleTail = operation.catchError((Object _, StackTrace _) {});
    _disposeFuture = operation;
    return operation;
  }

  @override
  void dispose() {
    unawaited(disposeAsync());
  }
}
