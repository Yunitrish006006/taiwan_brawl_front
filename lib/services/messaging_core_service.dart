import 'dart:async';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

enum MessagingStorageMode { inMemory, durable, degraded }

/// Explicitly describes whether the messaging core can survive a restart.
class MessagingStorageStatus {
  const MessagingStorageStatus({required this.mode, this.failureDescription});

  const MessagingStorageStatus.inMemory()
    : mode = MessagingStorageMode.inMemory,
      failureDescription = null;

  const MessagingStorageStatus.durable()
    : mode = MessagingStorageMode.durable,
      failureDescription = null;

  MessagingStorageStatus.degraded(Object error)
    : mode = MessagingStorageMode.degraded,
      failureDescription = error.toString();

  final MessagingStorageMode mode;
  final String? failureDescription;

  bool get isDurable => mode == MessagingStorageMode.durable;
}

/// Frontend-facing seam for the transport-neutral messaging core.
///
/// Existing chat pages still use [ChatService] during migration. New code can
/// depend on this seam without knowing whether delivery is WebRTC, server
/// backed, or local-only.
class MessagingCoreService {
  MessagingCoreService({
    MessageRepository? repository,
    this.storageStatus = const MessagingStorageStatus.inMemory(),
  }) : repository = repository ?? MessageRepository();

  MessagingCoreService._(this.repository, this.storageStatus);

  static Future<MessagingCoreService> restore(
    MessageEventStore store, {
    EventAuthenticator? authenticator,
  }) async {
    return MessagingCoreService._(
      await MessageRepository.restore(store, authenticator: authenticator),
      const MessagingStorageStatus.durable(),
    );
  }

  final MessageRepository repository;
  final MessagingStorageStatus storageStatus;

  Stream<MessageProjection> get changes => repository.changes;

  /// Builds the shared command boundary for one actor and conversation.
  MessageCommandService commands({
    required String actorId,
    required String conversationId,
    String? deviceId,
    EventAuthenticator? authenticator,
  }) {
    return MessageCommandService(
      repository: repository,
      actorId: actorId,
      conversationId: conversationId,
      deviceId: deviceId,
      authenticator: authenticator,
    );
  }

  /// Builds a sync coordinator without exposing transport-specific lifecycle
  /// decisions to product pages.
  MessageSyncEngine syncEngine({
    required MessageTransport transport,
    EventAuthenticator? authenticator,
    FutureOr<void> Function(MessageEvent event)? onRemoteEvent,
    bool Function(MessageEvent event)? eventFilter,
  }) {
    return MessageSyncEngine(
      repository: repository,
      transport: transport,
      authenticator: authenticator,
      onRemoteEvent: onRemoteEvent,
      eventFilter: eventFilter,
    );
  }

  List<MessageProjection> conversation(String conversationId) =>
      repository.projectionsFor(conversationId);

  Future<void> acceptRemote(
    MessageEvent event, {
    EventAuthenticator? authenticator,
  }) async {
    await repository.acceptRemote(event, authenticator: authenticator);
  }

  Future<void> dispose() => repository.dispose();
}
