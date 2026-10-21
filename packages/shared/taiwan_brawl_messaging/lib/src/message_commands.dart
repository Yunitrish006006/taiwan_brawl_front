import 'message_event.dart';
import 'message_projection.dart';
import 'message_repository.dart';
import 'message_transport.dart';

/// Application-level commands for a single actor and conversation.
///
/// Transport adapters and product features use this class instead of manually
/// constructing revisions. It owns author checks, sequential revisions and
/// durable outbox insertion; delivery remains the responsibility of a
/// [MessageSyncEngine].
class MessageCommandService {
  MessageCommandService({
    required this.repository,
    required this.actorId,
    required this.conversationId,
    this.deviceId,
    DateTime Function()? clock,
    String Function({
      required String type,
      required String messageId,
      required int revision,
      required int timestamp,
    })?
    eventIdFactory,
    this.authenticator,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()),
       _eventIdFactory = eventIdFactory;

  final MessageRepository repository;
  final String actorId;
  final String conversationId;
  final String? deviceId;
  final EventAuthenticator? authenticator;
  final DateTime Function() _clock;
  final String Function({
    required String type,
    required String messageId,
    required int revision,
    required int timestamp,
  })?
  _eventIdFactory;

  Future<MessageEvent> create(
    String body, {
    String? messageId,
    String? eventId,
    DateTime? createdAt,
  }) async {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) {
      throw const FormatException('A created event requires a body');
    }
    final timestamp = _clock().toUtc();
    final resolvedMessageId =
        messageId ?? '$actorId-${timestamp.microsecondsSinceEpoch}';
    final event = MessageEvent(
      eventId:
          eventId ??
          _eventId(
            type: MessageEventType.created,
            messageId: resolvedMessageId,
            revision: 0,
            timestamp: timestamp.microsecondsSinceEpoch,
          ),
      messageId: resolvedMessageId,
      conversationId: conversationId,
      actorId: actorId,
      deviceId: deviceId,
      type: MessageEventType.created,
      revision: 0,
      createdAt: (createdAt ?? timestamp).toUtc(),
      body: normalizedBody,
    );
    return repository.addLocal(event, authenticator: authenticator);
  }

  Future<MessageEvent?> edit(
    String messageId,
    String body, {
    String? eventId,
    DateTime? createdAt,
  }) async {
    final normalizedBody = body.trim();
    final projection = repository.projectionFor(messageId);
    if (normalizedBody.isEmpty || !_canMutate(projection)) return null;
    if (projection!.visibleBody == normalizedBody) return null;
    return _append(
      messageId: messageId,
      type: MessageEventType.edited,
      revision: projection.revision + 1,
      body: normalizedBody,
      eventId: eventId,
      createdAt: createdAt,
    );
  }

  Future<MessageEvent?> recall(
    String messageId, {
    String? eventId,
    DateTime? createdAt,
  }) async {
    final projection = repository.projectionFor(messageId);
    if (!_canMutate(projection) || projection!.recalled) return null;
    return _append(
      messageId: messageId,
      type: MessageEventType.recalled,
      revision: projection.revision + 1,
      eventId: eventId,
      createdAt: createdAt,
    );
  }

  Future<MessageEvent?> read(
    String messageId, {
    String? eventId,
    DateTime? createdAt,
  }) async {
    final projection = repository.projectionFor(messageId);
    if (projection == null) return null;
    return _append(
      messageId: messageId,
      type: MessageEventType.read,
      revision: projection.revision + 1,
      eventId: eventId,
      createdAt: createdAt,
    );
  }

  bool _canMutate(MessageProjection? projection) {
    return projection != null &&
        projection.authorId == actorId &&
        !projection.recalled;
  }

  Future<MessageEvent> _append({
    required String messageId,
    required MessageEventType type,
    required int revision,
    String? body,
    String? eventId,
    DateTime? createdAt,
  }) async {
    final timestamp = _clock().toUtc();
    final event = MessageEvent(
      eventId:
          eventId ??
          _eventId(
            type: type,
            messageId: messageId,
            revision: revision,
            timestamp: timestamp.microsecondsSinceEpoch,
          ),
      messageId: messageId,
      conversationId: conversationId,
      actorId: actorId,
      deviceId: deviceId,
      type: type,
      revision: revision,
      createdAt: (createdAt ?? timestamp).toUtc(),
      body: body,
    );
    return repository.addLocal(event, authenticator: authenticator);
  }

  String _eventId({
    required MessageEventType type,
    required String messageId,
    required int revision,
    required int timestamp,
  }) {
    return _eventIdFactory?.call(
          type: type.name,
          messageId: messageId,
          revision: revision,
          timestamp: timestamp,
        ) ??
        '$actorId:${type.name}:$messageId:$revision:$timestamp';
  }
}
