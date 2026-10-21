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
    final repository = MessageRepository();
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
