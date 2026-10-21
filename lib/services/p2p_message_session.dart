import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import '../models/chat_models.dart';
import 'message_chat_projection.dart';

/// Transport-neutral P2P message session.
///
/// WebRTC is only one adapter. Tests and local simulations can inject the
/// shared package's in-memory transport without creating a peer connection.
class P2PMessageSession {
  P2PMessageSession({
    required this.selfId,
    required this.friendId,
    required this.repository,
    required this.onMessage,
    this.deviceId,
    this.authenticator,
    this.onEvent,
  });

  final int selfId;
  final int friendId;
  final MessageRepository repository;
  final String? deviceId;
  final void Function(ChatMessage message) onMessage;
  final EventAuthenticator? authenticator;
  final FutureOr<void> Function(MessageEvent event, ChatMessage message)?
  onEvent;

  MessageSyncEngine? _syncEngine;

  String get conversationId {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    return '$low:$high';
  }

  Future<void> attach(MessageTransport transport) async {
    await _syncEngine?.stop();
    final engine = MessageSyncEngine(
      repository: repository,
      transport: transport,
      authenticator: authenticator,
      onRemoteEvent: _handleRemoteEvent,
      eventFilter: (event) => event.conversationId == conversationId,
    );
    _syncEngine = engine;
    await engine.start();
  }

  Future<void> send(String text) async {
    final event = await _commands.create(text);
    await _flush();
    await _emit(event.messageId, event);
  }

  Future<bool> edit(String messageId, String text) async {
    final event = await _commands.edit(messageId, text.trim());
    if (event == null) return false;
    await _flush();
    await _emit(messageId, event);
    return true;
  }

  Future<bool> recall(String messageId) async {
    final event = await _commands.recall(messageId);
    if (event == null) return false;
    await _flush();
    await _emit(messageId, event);
    return true;
  }

  Future<void> _flush() async {
    final engine = _syncEngine;
    if (engine?.started == true) {
      await engine!.syncNow();
    }
  }

  Future<void> _handleRemoteEvent(MessageEvent event) async {
    if (event.conversationId != conversationId ||
        event.actorId != friendId.toString()) {
      return;
    }
    await _emit(event.messageId, event);
  }

  Future<void> _emit(String messageId, MessageEvent event) async {
    final projection = repository.projectionFor(messageId);
    if (projection == null) return;
    final messages = MessageChatProjection.toMessages(
      projections: [projection],
      selfId: selfId,
      friendId: friendId,
      pendingMessageIds: repository.pendingOutbox.map(
        (event) => event.messageId,
      ),
    );
    if (messages.isNotEmpty) {
      final message = messages.single;
      await onEvent?.call(event, message);
      if (event.type != MessageEventType.read) onMessage(message);
    }
  }

  MessageCommandService get _commands => MessageCommandService(
    repository: repository,
    actorId: selfId.toString(),
    conversationId: conversationId,
    deviceId: deviceId,
    authenticator: authenticator,
  );

  Future<void> dispose() async {
    await _syncEngine?.stop();
    _syncEngine = null;
  }
}
