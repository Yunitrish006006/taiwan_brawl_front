import 'dart:async';

import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('does not lose events emitted during transport connect', () async {
    final transport = _ConnectEmittingTransport();
    final repository = MessageRepository();
    final engine = MessageSyncEngine(
      repository: repository,
      transport: transport,
    );

    await engine.start();
    await Future<void>.delayed(Duration.zero);

    expect(repository.projectionFor('connect-message')?.visibleBody, 'hello');

    await engine.stop();
    await repository.dispose();
  });

  test('rejects an invalid remote signature without projecting it', () async {
    final repository = MessageRepository();
    final event = MessageEvent(
      eventId: 'invalid-event',
      messageId: 'invalid-message',
      conversationId: 'conversation',
      actorId: 'friend',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'tampered',
      signature: 'bad',
    );

    final accepted = await repository.acceptRemote(
      event,
      authenticator: _RejectingAuthenticator(),
    );

    expect(accepted, isFalse);
    expect(repository.projectionFor('invalid-message'), isNull);
    expect(repository.conflicts.single.reason, contains('signature'));
    await repository.dispose();
  });

  test('acknowledges a remote event only after local ingestion', () async {
    final repository = MessageRepository(store: _DelayedStore([]));
    final transport = _ReceiptTransport();
    final engine = MessageSyncEngine(
      repository: repository,
      transport: transport,
    );

    await engine.start();

    expect(repository.projectionFor('receipt-message')?.visibleBody, 'hello');
    expect(transport.acknowledged, ['receipt-event']);
    await engine.stop();
    await repository.dispose();
  });

  test(
    'rejects out-of-scope events durably before acknowledging the relay',
    () async {
      final store = _FlakyConflictStore();
      final repository = MessageRepository(store: store);
      final event = _createdEvent('wrong-conversation-event', 'other');
      final transport = _FilteredReceiptTransport(
        event,
        conflictCountAtAcknowledgement: () => store.conflicts.length,
      );
      var projectedCallbacks = 0;
      final engine = MessageSyncEngine(
        repository: repository,
        transport: transport,
        eventFilter: (candidate) => candidate.conversationId == 'conversation',
        onRemoteEvent: (_) => projectedCallbacks++,
      );

      await engine.start();
      expect(
        transport.acknowledgements,
        isEmpty,
        reason:
            'a failed durable conflict write must leave the relay row pending',
      );
      expect(repository.projectionFor(event.messageId), isNull);
      expect(
        repository.conflicts,
        isEmpty,
        reason: 'a conflict whose disk write failed is not reported as durable',
      );

      transport.emit(event);
      await transport.acknowledged.future.timeout(const Duration(seconds: 1));

      expect(transport.acknowledgements, [false]);
      expect(transport.conflictCountsAtAcknowledgement, [1]);
      expect(repository.projectionFor(event.messageId), isNull);
      expect(
        repository.conflicts.single.reason,
        contains('outside the active sync scope'),
      );
      expect(projectedCallbacks, 0);

      await engine.stop();
      await repository.dispose();
    },
  );

  test(
    'does not acknowledge accepted events without durable local storage',
    () async {
      final repository = MessageRepository();
      final transport = _FilteredReceiptTransport(
        _createdEvent('volatile-event', 'conversation'),
      );
      final engine = MessageSyncEngine(
        repository: repository,
        transport: transport,
        eventFilter: (event) => event.conversationId == 'conversation',
      );

      await engine.start();
      await Future<void>.delayed(Duration.zero);
      expect(repository.projectionFor('volatile-event'), isNotNull);
      expect(transport.acknowledgements, isEmpty);

      await engine.stop();
      await repository.dispose();
    },
  );

  test('disconnects a transport when connect fails', () async {
    final transport = _FailingTransport();
    final engine = MessageSyncEngine(
      repository: MessageRepository(),
      transport: transport,
    );

    await expectLater(engine.start(), throwsStateError);
    expect(transport.disconnected, isTrue);
    await engine.stop();
  });

  test(
    'cleans up after initial flush failure so start can be retried',
    () async {
      final repository = MessageRepository();
      await repository.addLocal(
        MessageEvent(
          eventId: 'retry-event',
          messageId: 'retry-message',
          conversationId: 'conversation',
          actorId: 'self',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 10, 20),
          body: 'retry me',
        ),
      );
      final transport = _FailOnceTransport();
      final engine = MessageSyncEngine(
        repository: repository,
        transport: transport,
      );

      await expectLater(engine.start(), throwsStateError);
      expect(engine.started, isFalse);
      expect(transport.disconnectCalls, 1);
      expect(repository.pendingOutbox, hasLength(1));

      await engine.start();
      expect(engine.started, isTrue);
      expect(transport.sent, ['retry-event']);
      await engine.stop();
      await repository.dispose();
    },
  );

  test('retries filtered pending outbox events until stopped', () async {
    final repository = MessageRepository();
    final transport = _PeriodicRetryTransport();
    final engine = MessageSyncEngine(
      repository: repository,
      transport: transport,
      retryInterval: const Duration(milliseconds: 10),
      eventFilter: (event) => event.conversationId == 'conversation',
    );

    await engine.start();
    await repository.addLocal(_createdEvent('target-event', 'conversation'));
    await repository.addLocal(_createdEvent('other-event', 'other'));
    await transport.retrySucceeded.future.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(transport.attemptedEventIds, ['target-event', 'target-event']);
    expect(repository.pendingOutbox.map((event) => event.eventId), [
      'other-event',
    ]);

    await engine.stop();
    await repository.addLocal(_createdEvent('after-stop', 'conversation'));
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(transport.attemptedEventIds, ['target-event', 'target-event']);
    await repository.dispose();
  });

  test(
    'waits for an active retry before disconnecting its transport',
    () async {
      final repository = MessageRepository();
      final transport = _BlockingRetryTransport();
      final engine = MessageSyncEngine(
        repository: repository,
        transport: transport,
        retryInterval: const Duration(milliseconds: 5),
      );

      await engine.start();
      await repository.addLocal(_createdEvent('blocked-send', 'conversation'));
      await transport.sendStarted.future.timeout(const Duration(seconds: 1));

      var stopped = false;
      final stopping = engine.stop().then((_) => stopped = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(stopped, isFalse);
      expect(transport.disconnected, isFalse);

      transport.releaseSend.complete();
      await stopping;
      expect(transport.disconnected, isTrue);
      await repository.dispose();
    },
  );

  test('serializes a burst of remote events before sync completes', () async {
    final storedOrder = <String>[];
    final repository = MessageRepository(store: _DelayedStore(storedOrder));
    final transport = _BurstTransport();
    final created = MessageEvent(
      eventId: 'burst-created',
      messageId: 'burst-message',
      conversationId: 'conversation',
      actorId: 'friend',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'original',
    );
    final edited = MessageEvent(
      eventId: 'burst-edited',
      messageId: 'burst-message',
      conversationId: 'conversation',
      actorId: 'friend',
      type: MessageEventType.edited,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 20, 1),
      body: 'edited',
    );
    transport.eventsToEmit.addAll([created, edited]);
    final engine = MessageSyncEngine(
      repository: repository,
      transport: transport,
    );

    await engine.start();

    expect(storedOrder, ['burst-created', 'burst-edited']);
    expect(repository.projectionFor('burst-message')?.visibleBody, 'edited');
    await engine.stop();
    await repository.dispose();
  });
}

MessageEvent _createdEvent(String eventId, String conversationId) =>
    MessageEvent(
      eventId: eventId,
      messageId: eventId,
      conversationId: conversationId,
      actorId: 'self',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: eventId,
    );

class _RejectingAuthenticator implements EventAuthenticator {
  @override
  Future<String> sign(MessageEvent event) async => 'valid';

  @override
  Future<bool> verify(MessageEvent event) async => false;
}

class _ReceiptTransport implements MessageReceiptTransport {
  final eventsController = StreamController<MessageEvent>.broadcast();
  final acknowledged = <String>[];

  @override
  Stream<MessageEvent> get events => eventsController.stream;

  @override
  Future<void> connect() async {
    eventsController.add(
      MessageEvent(
        eventId: 'receipt-event',
        messageId: 'receipt-message',
        conversationId: 'conversation',
        actorId: 'friend',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 10, 20),
        body: 'hello',
      ),
    );
  }

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> acknowledgeReceived(
    MessageEvent event, {
    required bool accepted,
  }) async {
    acknowledged.add(event.eventId);
  }

  @override
  Future<void> disconnect() async => eventsController.close();
}

class _FailingTransport implements MessageTransport {
  bool disconnected = false;

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async => throw StateError('connect failed');

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> disconnect() async => disconnected = true;
}

class _FailOnceTransport implements MessageTransport {
  final sent = <String>[];
  int disconnectCalls = 0;
  bool fail = true;

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> send(MessageEvent event) async {
    if (fail) {
      fail = false;
      throw StateError('initial flush failed');
    }
    sent.add(event.eventId);
  }

  @override
  Future<void> disconnect() async => disconnectCalls++;
}

class _PeriodicRetryTransport implements MessageTransport {
  final retrySucceeded = Completer<void>();
  final attemptedEventIds = <String>[];
  bool _failNext = true;

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> send(MessageEvent event) async {
    attemptedEventIds.add(event.eventId);
    if (_failNext) {
      _failNext = false;
      throw StateError('temporary send failure');
    }
    if (event.eventId == 'target-event' && !retrySucceeded.isCompleted) {
      retrySucceeded.complete();
    }
  }

  @override
  Future<void> disconnect() async {}
}

class _BlockingRetryTransport implements MessageTransport {
  final sendStarted = Completer<void>();
  final releaseSend = Completer<void>();
  bool disconnected = false;

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> send(MessageEvent event) async {
    if (!sendStarted.isCompleted) sendStarted.complete();
    await releaseSend.future;
  }

  @override
  Future<void> disconnect() async => disconnected = true;
}

class _FlakyConflictStore implements MessageEventStore, MessageConflictStore {
  final events = <MessageEvent>[];
  final pending = <MessageEvent>[];
  final conflicts = <MessageConflict>[];
  bool failNextConflictWrite = true;

  @override
  Future<void> acknowledgeOutbox(String eventId) async {
    pending.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    events.add(event);
    if (pendingOutbox) pending.add(event);
  }

  @override
  Future<void> appendConflict(MessageConflict conflict) async {
    if (failNextConflictWrite) {
      failNextConflictWrite = false;
      throw StateError('conflict storage unavailable');
    }
    conflicts.add(conflict);
  }

  @override
  Future<List<MessageConflict>> loadConflicts() async => List.of(conflicts);

  @override
  Future<List<MessageEvent>> loadAll() async => List.of(events);

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async => List.of(pending);
}

class _FilteredReceiptTransport implements MessageReceiptTransport {
  _FilteredReceiptTransport(
    this.incoming, {
    this.conflictCountAtAcknowledgement,
  });

  final MessageEvent incoming;
  final int Function()? conflictCountAtAcknowledgement;
  final eventsController = StreamController<MessageEvent>.broadcast();
  final acknowledged = Completer<void>();
  final acknowledgements = <bool>[];
  final conflictCountsAtAcknowledgement = <int>[];

  @override
  Stream<MessageEvent> get events => eventsController.stream;

  @override
  Future<void> connect() async => eventsController.add(incoming);

  void emit(MessageEvent event) => eventsController.add(event);

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> acknowledgeReceived(
    MessageEvent event, {
    required bool accepted,
  }) async {
    acknowledgements.add(accepted);
    final count = conflictCountAtAcknowledgement?.call();
    if (count != null) conflictCountsAtAcknowledgement.add(count);
    if (!acknowledged.isCompleted) acknowledged.complete();
  }

  @override
  Future<void> disconnect() async => eventsController.close();
}

class _BurstTransport implements MessageTransport {
  final eventsController = StreamController<MessageEvent>.broadcast();
  final eventsToEmit = <MessageEvent>[];

  @override
  Stream<MessageEvent> get events => eventsController.stream;

  @override
  Future<void> connect() async {
    for (final event in eventsToEmit) {
      eventsController.add(event);
    }
  }

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> disconnect() async => eventsController.close();
}

class _DelayedStore implements MessageEventStore {
  _DelayedStore(this.storedOrder);

  final List<String> storedOrder;

  @override
  Future<void> acknowledgeOutbox(String eventId) async {}

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    if (event.eventId == 'burst-created') {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    storedOrder.add(event.eventId);
  }

  @override
  Future<List<MessageEvent>> loadAll() async => const [];

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async => const [];
}

class _ConnectEmittingTransport implements MessageTransport {
  final StreamController<MessageEvent> _events =
      StreamController<MessageEvent>.broadcast();

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    _events.add(
      MessageEvent(
        eventId: 'connect-event',
        messageId: 'connect-message',
        conversationId: 'conversation',
        actorId: 'friend',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 10, 20),
        body: 'hello',
      ),
    );
  }

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> disconnect() => _events.close();
}
