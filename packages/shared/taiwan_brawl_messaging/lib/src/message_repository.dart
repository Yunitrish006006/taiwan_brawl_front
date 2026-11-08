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
  bool _eventIngestionBusy = false;
  final List<_QueuedIngestionOperation> _eventIngestionQueue = [];
  final StreamController<MessageProjection> _changes =
      StreamController<MessageProjection>.broadcast();

  Stream<MessageProjection> get changes => _changes.stream;
  List<MessageEvent> get pendingOutbox => List.unmodifiable(_outbox);
  List<MessageConflict> get conflicts => List.unmodifiable(_conflicts);
  List<MessageEvent> get events => List.unmodifiable(_eventsById.values);
  bool get canDurablyRecordEvents => store != null;
  bool get canDurablyRecordConflicts => store is MessageConflictStore;

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
    final queuedOutboxIds = <String>{};
    for (final event in await store.loadPendingOutbox()) {
      final storedEvent = repository._eventsById[event.eventId];
      if (storedEvent != null) {
        final payloadMismatch =
            storedEvent.canonicalPayload != event.canonicalPayload;
        final recordMismatch =
            payloadMismatch || storedEvent.signature != event.signature;
        if (payloadMismatch) {
          await repository._recordConflict(
            event,
            'Pending outbox event differs from the durable event row',
          );
        }
        if (recordMismatch) {
          // The event row is authoritative. Repair the redundant outbox copy
          // before exposing it for delivery; if this write fails, restore
          // fails closed and the next restore can retry the repair.
          await store.append(storedEvent, pendingOutbox: true);
        }
        if (queuedOutboxIds.add(storedEvent.eventId)) {
          repository._outbox.add(storedEvent);
        }
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
        if (queuedOutboxIds.add(event.eventId)) {
          repository._outbox.add(event);
        }
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
    if (store case final MessageBatchInboxStore batchInboxStore) {
      for (final batch in await batchInboxStore.loadInboxBatches()) {
        await repository._acceptRemoteBatch(
          batch.events,
          authenticator: authenticator,
          existingBatchId: batch.id,
        );
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
    late MessageEvent added;
    await _serializeIngestion(() async {
      final signed = authenticator == null
          ? event
          : event.withSignature(await authenticator.sign(event));
      _validateLocalEvent(signed);
      _insert(signed);
      _outbox.add(signed);
      await store?.append(signed, pendingOutbox: true);
      _emit(signed.messageId);
      added = signed;
      return true;
    });
    return added;
  }

  Future<bool> acceptRemote(
    MessageEvent event, {
    EventAuthenticator? authenticator,
  }) => _serializeIngestion(
    () => _acceptRemote(event, authenticator: authenticator),
  );

  /// Rejects an event outside the active transport scope and records why.
  ///
  /// Returns whether the rejection is durably recorded. Receipt transports
  /// must retain the event for retry when this returns false.
  Future<bool> rejectRemote(MessageEvent event, {required String reason}) {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must not be empty');
    }
    return _serializeIngestion(() async {
      await _recordConflict(event, reason);
      return canDurablyRecordConflicts;
    });
  }

  /// Preflights a remote batch before accepting any of its events.
  ///
  /// Deterministic validation conflicts are persisted and return `false`
  /// without applying otherwise-valid events from the same batch. A storage
  /// failure can leave a durable prefix, but the in-memory projection remains
  /// unchanged until every event has been persisted; the event inbox remains
  /// the recovery source for retries.
  Future<bool> acceptRemoteBatch(
    Iterable<MessageEvent> batch, {
    EventAuthenticator? authenticator,
  }) => _serializeIngestion(
    () => _acceptRemoteBatch(batch, authenticator: authenticator),
  );

  Future<bool> _acceptRemoteBatch(
    Iterable<MessageEvent> batch, {
    EventAuthenticator? authenticator,
    String? existingBatchId,
  }) async {
    final events = batch.toList(growable: false);
    if (events.isEmpty) return true;
    final batchInboxStore = store is MessageBatchInboxStore
        ? store as MessageBatchInboxStore
        : null;
    final batchId =
        existingBatchId ?? await batchInboxStore?.appendInboxBatch(events);
    final staged = MessageRepository(initialEvents: _eventsById.values);
    final rejected = <MessageConflict>[];
    for (final event in events) {
      if (await staged.acceptRemote(event, authenticator: authenticator)) {
        continue;
      }
      rejected.add(
        staged.conflicts.lastWhere(
          (conflict) => conflict.eventId == event.eventId,
        ),
      );
    }
    await staged.dispose();

    if (rejected.isNotEmpty) {
      for (final conflict in rejected) {
        final event = events.firstWhere(
          (candidate) => candidate.eventId == conflict.eventId,
        );
        await _recordConflict(event, conflict.reason);
      }
      if (batchId != null && store is MessageConflictStore) {
        await batchInboxStore!.removeInboxBatch(batchId);
      }
      return false;
    }

    final uniqueEvents = <String, MessageEvent>{};
    for (final event in events) {
      uniqueEvents.putIfAbsent(event.eventId, () => event);
    }
    final inboxStore = store is MessageInboxStore
        ? store as MessageInboxStore
        : null;
    final committedEvents = <MessageEvent>[
      for (final event in uniqueEvents.values)
        _eventsById[event.eventId] ?? event,
    ];

    // Persist inbox intent and every event before exposing any new projection.
    // A partial durable prefix remains replayable, while this repository stays
    // at its previous state if a later append fails.
    if (batchInboxStore == null && inboxStore != null) {
      for (final event in events) {
        await inboxStore.appendInbox(event);
      }
    }
    for (final event in committedEvents) {
      await store?.append(event, pendingOutbox: false);
    }

    final changedMessageIds = <String>{};
    for (final event in committedEvents) {
      if (_eventsById.containsKey(event.eventId)) continue;
      _insert(event);
      changedMessageIds.add(event.messageId);
    }
    for (final messageId in changedMessageIds) {
      _emit(messageId);
    }

    if (batchId != null) {
      await batchInboxStore!.removeInboxBatch(batchId);
    } else if (inboxStore != null) {
      for (final event in events) {
        await inboxStore.removeInbox(event.eventId);
      }
    }
    return true;
  }

  Future<bool> _acceptRemote(
    MessageEvent event, {
    EventAuthenticator? authenticator,
    bool trackInbox = true,
  }) async {
    final inboxStore = store is MessageInboxStore
        ? store as MessageInboxStore
        : null;
    if (trackInbox && inboxStore != null) await inboxStore.appendInbox(event);
    var completed = false;
    try {
      if (authenticator != null && !await authenticator.verify(event)) {
        await _recordConflict(event, 'Message event signature is invalid');
        completed = true;
        return false;
      }
      final existingEvent = _eventsById[event.eventId];
      if (existingEvent != null) {
        if (existingEvent.canonicalPayload != event.canonicalPayload) {
          await _recordConflict(
            event,
            'Event ID is already bound to a different payload',
          );
          completed = true;
          return false;
        }
        // A prior attempt may have inserted the event in memory before its
        // durable append failed. Re-append on retry before clearing the inbox.
        await store?.append(existingEvent, pendingOutbox: false);
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
      if (trackInbox && completed) await inboxStore?.removeInbox(event.eventId);
    }
  }

  Future<void> acknowledge(String eventId) async {
    await store?.acknowledgeOutbox(eventId);
    _outbox.removeWhere((event) => event.eventId == eventId);
  }

  Future<bool> _serializeIngestion(Future<bool> Function() action) {
    if (_eventIngestionBusy) {
      final queued = _QueuedIngestionOperation(action);
      _eventIngestionQueue.add(queued);
      return queued.result.future;
    }
    _eventIngestionBusy = true;
    return _runIngestionOperation(action);
  }

  Future<bool> _runIngestionOperation(Future<bool> Function() action) async {
    try {
      return await action();
    } finally {
      if (_eventIngestionQueue.isEmpty) {
        _eventIngestionBusy = false;
      } else {
        final queued = _eventIngestionQueue.removeAt(0);
        unawaited(_completeQueuedIngestionOperation(queued));
      }
    }
  }

  Future<void> _completeQueuedIngestionOperation(
    _QueuedIngestionOperation queued,
  ) async {
    try {
      queued.result.complete(await _runIngestionOperation(queued.action));
    } catch (error, stackTrace) {
      queued.result.completeError(error, stackTrace);
    }
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
      try {
        await conflictStore.appendConflict(conflict);
      } catch (_) {
        _conflicts.remove(conflict);
        rethrow;
      }
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

class _QueuedIngestionOperation {
  _QueuedIngestionOperation(this.action);

  final Future<bool> Function() action;
  final Completer<bool> result = Completer<bool>();
}
