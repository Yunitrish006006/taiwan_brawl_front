import 'dart:async';

import 'message_conflict.dart';
import 'message_event.dart';
import 'message_projection.dart';
import 'message_transport.dart';
import 'platform_ports.dart';

class MessageRepository {
  MessageRepository({
    Iterable<MessageEvent> initialEvents = const [],
    this.store,
  }) {
    for (final event in initialEvents) {
      _insert(event);
    }
  }

  final MessageEventStore? store;

  final Map<String, MessageEvent> _eventsById = {};
  final Map<String, List<MessageEvent>> _eventsByMessage = {};
  final List<MessageEvent> _outbox = [];
  final List<MessageConflict> _conflicts = [];
  Future<void> _flushTail = Future<void>.value();
  final StreamController<MessageProjection> _changes =
      StreamController<MessageProjection>.broadcast();

  Stream<MessageProjection> get changes => _changes.stream;
  List<MessageEvent> get pendingOutbox => List.unmodifiable(_outbox);
  List<MessageConflict> get conflicts => List.unmodifiable(_conflicts);
  List<MessageEvent> get events => List.unmodifiable(_eventsById.values);

  static Future<MessageRepository> restore(
    MessageEventStore store, {
    EventAuthenticator? authenticator,
  }) async {
    final repository = MessageRepository(store: store);
    if (store case final MessageConflictStore conflictStore) {
      try {
        repository._mergeConflicts(await conflictStore.loadConflicts());
      } on FormatException {
        // A malformed conflict record must not prevent message recovery.
      }
    }
    final restoredEvents = await store.loadAll();
    final orderedEvents = [...restoredEvents]
      ..sort((a, b) {
        final message = a.messageId.compareTo(b.messageId);
        if (message != 0) return message;
        return _compareEvents(a, b);
      });
    for (final event in orderedEvents) {
      try {
        repository._insert(event);
      } on FormatException catch (error) {
        await repository._recordConflict(event, error.message);
        continue;
      }

      final result = repository._buildProjection(event.messageId);
      final hasCreated = repository._eventsByMessage[event.messageId]!.any(
        (candidate) => candidate.type == MessageEventType.created,
      );
      final isTemporaryGap =
          result.error?.startsWith('Message revision gap:') == true;
      if (hasCreated && result.error != null && !isTemporaryGap) {
        repository._remove(event);
        await repository._recordConflict(event, result.error!);
      }
    }
    for (final event in await store.loadPendingOutbox()) {
      if (repository._eventsById.containsKey(event.eventId)) {
        repository._outbox.add(event);
        continue;
      }

      // A crash can leave the outbox row durable after the main event row was
      // not written. Recover the pending event instead of silently dropping
      // the only copy of a message that still needs delivery.
      try {
        repository._insert(event);
        final result = repository._buildProjection(event.messageId);
        final hasCreated = repository._eventsByMessage[event.messageId]!.any(
          (candidate) => candidate.type == MessageEventType.created,
        );
        final isTemporaryGap =
            result.error?.startsWith('Message revision gap:') == true;
        if (hasCreated && result.error != null && !isTemporaryGap) {
          repository._remove(event);
          await repository._recordConflict(event, result.error!);
          continue;
        }
        await store.append(event, pendingOutbox: true);
        repository._outbox.add(event);
      } on FormatException catch (error) {
        await repository._recordConflict(event, error.message);
      }
    }
    if (store case final MessageConflictStore conflictStore) {
      try {
        // Storage adapters may discover corrupt records while decoding events.
        // Reload after event/outbox restore so those durable diagnostics are
        // visible in the returned repository as well.
        repository._mergeConflicts(await conflictStore.loadConflicts());
      } on FormatException {
        // A malformed conflict record must not prevent message recovery.
      }
    }
    if (store case final MessageInboxStore inboxStore) {
      for (final event in await inboxStore.loadInbox()) {
        await repository.acceptRemote(event, authenticator: authenticator);
      }
      if (store case final MessageConflictStore conflictStore) {
        try {
          repository._mergeConflicts(await conflictStore.loadConflicts());
        } on FormatException {
          // A malformed conflict record must not prevent message recovery.
        }
      }
    }
    return repository;
  }

  MessageProjection? projectionFor(String messageId) {
    return _buildProjection(messageId).projection;
  }

  List<MessageProjection> projectionsFor(String conversationId) {
    final messageIds = _eventsByMessage.entries
        .where(
          (entry) => entry.value.any(
            (event) => event.conversationId == conversationId,
          ),
        )
        .map((entry) => entry.key);
    return [
      for (final id in messageIds)
        if (projectionFor(id) case final projection?) projection,
    ]..sort((a, b) => a.messageId.compareTo(b.messageId));
  }

  Future<MessageEvent> addLocal(
    MessageEvent event, {
    EventAuthenticator? authenticator,
  }) async {
    final signed = authenticator == null
        ? event
        : event.withSignature(await authenticator.sign(event));
    _validateLocalEvent(signed);
    _insert(signed);
    _outbox.add(signed);
    await store?.append(signed, pendingOutbox: true);
    _emit(signed.messageId);
    return signed;
  }

  Future<bool> acceptRemote(
    MessageEvent event, {
    EventAuthenticator? authenticator,
  }) async {
    final inboxStore = store is MessageInboxStore
        ? store as MessageInboxStore
        : null;
    if (inboxStore != null) await inboxStore.appendInbox(event);
    var completed = false;
    try {
      if (authenticator != null && !await authenticator.verify(event)) {
        await _recordConflict(event, 'Message event signature is invalid');
        completed = true;
        return false;
      }
      if (_eventsById.containsKey(event.eventId)) {
        // A prior attempt may have inserted the event in memory before its
        // durable append failed. Re-append on retry before clearing the inbox.
        await store?.append(event, pendingOutbox: false);
        completed = true;
        return true;
      }
      try {
        _insert(event);
      } on FormatException catch (error) {
        await _recordConflict(event, error.message);
        completed = true;
        return false;
      }

      final result = _buildProjection(event.messageId);
      final hasCreated = _eventsByMessage[event.messageId]!.any(
        (candidate) => candidate.type == MessageEventType.created,
      );
      final isTemporaryGap =
          result.error?.startsWith('Message revision gap:') == true;
      if (hasCreated && result.error != null && !isTemporaryGap) {
        _remove(event);
        await _recordConflict(event, result.error!);
        completed = true;
        return false;
      }

      await store?.append(event, pendingOutbox: false);
      completed = true;
      _emit(event.messageId);
      return true;
    } finally {
      if (completed) await inboxStore?.removeInbox(event.eventId);
    }
  }

  Future<void> acknowledge(String eventId) async {
    _outbox.removeWhere((event) => event.eventId == eventId);
    await store?.acknowledgeOutbox(eventId);
  }

  Future<void> flush(
    MessageTransport transport, {
    bool Function(MessageEvent event)? shouldSend,
  }) {
    final run = _flushTail.then<void>((_) async {
      for (final event in List<MessageEvent>.from(_outbox)) {
        if (shouldSend != null && !shouldSend(event)) continue;
        await transport.send(event);
        await acknowledge(event.eventId);
      }
    });
    _flushTail = run.catchError((Object _, StackTrace __) {});
    return run;
  }

  Future<void> dispose() => _changes.close();

  void _insert(MessageEvent event) {
    if (_eventsById.containsKey(event.eventId)) return;
    final events = _eventsByMessage.putIfAbsent(event.messageId, () => []);
    final sameRevision = events.where(
      (item) => item.revision == event.revision,
    );
    if (sameRevision.isNotEmpty &&
        sameRevision.first.eventId != event.eventId) {
      throw const FormatException(
        'Conflicting events share a message revision',
      );
    }
    _eventsById[event.eventId] = event;
    events.add(event);
  }

  void _remove(MessageEvent event) {
    _eventsById.remove(event.eventId);
    final events = _eventsByMessage[event.messageId];
    events?.removeWhere((candidate) => candidate.eventId == event.eventId);
    if (events?.isEmpty == true) {
      _eventsByMessage.remove(event.messageId);
    }
  }

  _ProjectionBuildResult _buildProjection(String messageId) {
    final events = _eventsByMessage[messageId];
    if (events == null || events.isEmpty) {
      return const _ProjectionBuildResult();
    }
    final ordered = [...events]..sort(_compareEvents);
    if (ordered.first.type != MessageEventType.created) {
      return const _ProjectionBuildResult(
        error: 'A message projection must start with created',
      );
    }
    try {
      var projection = MessageProjection.fromCreated(ordered.first);
      for (final event in ordered.skip(1)) {
        projection = projection.apply(event);
      }
      return _ProjectionBuildResult(projection: projection);
    } on FormatException catch (error) {
      return _ProjectionBuildResult(error: error.message);
    }
  }

  void _validateLocalEvent(MessageEvent event) {
    final existing = _eventsByMessage[event.messageId];
    if (event.type == MessageEventType.created) {
      if (event.revision != 0 || existing != null) {
        throw const FormatException(
          'A local message must start at revision zero',
        );
      }
      return;
    }
    final projection = projectionFor(event.messageId);
    if (projection == null) {
      throw const FormatException(
        'A local event requires an existing message projection',
      );
    }
    projection.apply(event);
  }

  void _emit(String messageId) {
    final projection = projectionFor(messageId);
    if (projection != null && !_changes.isClosed) _changes.add(projection);
  }

  Future<void> _recordConflict(MessageEvent event, String reason) async {
    final conflict = MessageConflict(
      eventId: event.eventId,
      messageId: event.messageId,
      reason: reason,
    );
    if (!_mergeConflicts([conflict])) return;
    if (store case final MessageConflictStore conflictStore) {
      await conflictStore.appendConflict(conflict);
    }
  }

  bool _mergeConflicts(Iterable<MessageConflict> conflicts) {
    var added = false;
    for (final conflict in conflicts) {
      if (_conflicts.any(
        (existing) =>
            existing.eventId == conflict.eventId &&
            existing.messageId == conflict.messageId &&
            existing.reason == conflict.reason,
      )) {
        continue;
      }
      _conflicts.add(conflict);
      added = true;
    }
    return added;
  }

  static int _compareEvents(MessageEvent a, MessageEvent b) {
    final revision = a.revision.compareTo(b.revision);
    if (revision != 0) return revision;
    return a.eventId.compareTo(b.eventId);
  }
}

class _ProjectionBuildResult {
  const _ProjectionBuildResult({this.projection, this.error});

  final MessageProjection? projection;
  final String? error;
}
