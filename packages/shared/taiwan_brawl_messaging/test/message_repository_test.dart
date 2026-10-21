import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  final created = MessageEvent(
    eventId: 'e1',
    messageId: 'm1',
    conversationId: 'c1',
    actorId: 'alice',
    type: MessageEventType.created,
    revision: 0,
    createdAt: DateTime.utc(2026, 10, 20, 1),
    body: 'hello',
  );

  test('stores local events in the outbox and projects them', () async {
    final repository = MessageRepository();
    await repository.addLocal(created);

    expect(repository.pendingOutbox, [created]);
    expect(repository.projectionFor('m1')?.visibleBody, 'hello');
    await repository.dispose();
  });

  test('rejects malformed event fields with a recoverable format error', () {
    expect(
      () => MessageEvent.fromJson({
        'eventId': 'bad',
        'messageId': 'bad',
        'conversationId': '1:2',
        'actorId': '1',
        'type': 'created',
        'revision': 0,
        'createdAt': 123,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('supports edit and recall after read', () async {
    final repository = MessageRepository();
    await repository.addLocal(created);
    await repository.addLocal(
      MessageEvent(
        eventId: 'e2',
        messageId: 'm1',
        conversationId: 'c1',
        actorId: 'alice',
        type: MessageEventType.edited,
        revision: 1,
        createdAt: DateTime.utc(2026, 10, 20, 1, 1),
        body: 'edited',
      ),
    );
    await repository.addLocal(
      MessageEvent(
        eventId: 'e3',
        messageId: 'm1',
        conversationId: 'c1',
        actorId: 'bob',
        type: MessageEventType.read,
        revision: 2,
        createdAt: DateTime.utc(2026, 10, 20, 1, 2),
      ),
    );
    await repository.addLocal(
      MessageEvent(
        eventId: 'e4',
        messageId: 'm1',
        conversationId: 'c1',
        actorId: 'alice',
        type: MessageEventType.recalled,
        revision: 3,
        createdAt: DateTime.utc(2026, 10, 20, 1, 3),
      ),
    );

    final projection = repository.projectionFor('m1')!;
    expect(projection.recalled, isTrue);
    expect(projection.visibleBody, recalledMessageText);
    expect(projection.readBy, contains('bob'));
    await repository.dispose();
  });

  test('remote event ingestion is idempotent', () async {
    final repository = MessageRepository();
    await repository.acceptRemote(created);
    await repository.acceptRemote(created);

    expect(repository.pendingOutbox, isEmpty);
    expect(repository.projectionFor('m1')?.revision, 0);
    await repository.dispose();
  });

  test(
    'durable inbox survives a receive failure and replays on restore',
    () async {
      final store = _MemoryStore([]);
      store.inbox.add(created);

      final restored = await MessageRepository.restore(store);

      expect(restored.projectionFor('m1')?.visibleBody, 'hello');
      expect(store.inbox, isEmpty);
      await restored.dispose();
    },
  );

  test(
    'recovers a pending outbox event when its main row is missing',
    () async {
      final store = _MemoryStore([], [created]);

      final restored = await MessageRepository.restore(store);

      expect(restored.projectionFor('m1')?.visibleBody, 'hello');
      expect(restored.pendingOutbox, [created]);
      expect(store.events.map((event) => event.eventId), ['e1']);
      await restored.dispose();
    },
  );

  test(
    'inbox replay applies the same fail-closed authenticator gate',
    () async {
      final store = _MemoryStore([])..inbox.add(created);

      final restored = await MessageRepository.restore(
        store,
        authenticator: _RejectingAuthenticator(),
      );

      expect(restored.projectionFor('m1'), isNull);
      expect(restored.conflicts.single.reason, contains('signature'));
      expect(store.inbox, isEmpty);
      await restored.dispose();
    },
  );

  test('rejects conflicting revisions and unauthorized edits', () async {
    final repository = MessageRepository();
    await repository.addLocal(created);
    await expectLater(
      repository.addLocal(
        MessageEvent(
          eventId: 'other',
          messageId: 'm1',
          conversationId: 'c1',
          actorId: 'bob',
          type: MessageEventType.edited,
          revision: 1,
          createdAt: DateTime.utc(2026, 10, 20, 2),
          body: 'tampered',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(repository.projectionFor('m1')?.visibleBody, 'hello');
    await repository.dispose();
  });

  test('rejects invalid remote edits and records a conflict', () async {
    final repository = MessageRepository();
    await repository.acceptRemote(created);

    final accepted = await repository.acceptRemote(
      MessageEvent(
        eventId: 'remote-tamper',
        messageId: 'm1',
        conversationId: 'c1',
        actorId: 'bob',
        type: MessageEventType.edited,
        revision: 1,
        createdAt: DateTime.utc(2026, 10, 20, 2),
        body: 'tampered',
      ),
    );

    expect(accepted, isFalse);
    expect(repository.conflicts.single.reason, contains('Only the author'));
    expect(repository.events.map((event) => event.eventId), ['e1']);
    expect(repository.projectionFor('m1')?.visibleBody, 'hello');
    await repository.dispose();
  });

  test('restores durable conflicts without duplicating them', () async {
    final store = _MemoryStore([]);
    final repository = MessageRepository(store: store);
    await repository.acceptRemote(created);
    final tampered = MessageEvent(
      eventId: 'durable-tamper',
      messageId: 'm1',
      conversationId: 'c1',
      actorId: 'bob',
      type: MessageEventType.edited,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 20, 2),
      body: 'tampered',
    );

    expect(await repository.acceptRemote(tampered), isFalse);
    expect(await repository.acceptRemote(tampered), isFalse);
    await repository.dispose();

    final restored = await MessageRepository.restore(store);
    expect(restored.conflicts.map((conflict) => conflict.eventId), [
      'durable-tamper',
    ]);
    await restored.dispose();
  });

  test('keeps out-of-order remote revisions until the gap is filled', () async {
    final repository = MessageRepository();
    await repository.acceptRemote(created);
    final revisionTwo = MessageEvent(
      eventId: 'e3',
      messageId: 'm1',
      conversationId: 'c1',
      actorId: 'alice',
      type: MessageEventType.recalled,
      revision: 2,
      createdAt: DateTime.utc(2026, 10, 20, 3),
    );
    final revisionOne = MessageEvent(
      eventId: 'e2',
      messageId: 'm1',
      conversationId: 'c1',
      actorId: 'alice',
      type: MessageEventType.edited,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 20, 2),
      body: 'edited',
    );

    expect(await repository.acceptRemote(revisionTwo), isTrue);
    expect(repository.projectionFor('m1'), isNull);
    expect(await repository.acceptRemote(revisionOne), isTrue);
    expect(repository.projectionFor('m1')?.visibleBody, recalledMessageText);
    expect(repository.conflicts, isEmpty);
    await repository.dispose();
  });

  test(
    'restore keeps valid history when durable events contain a conflict',
    () async {
      final store = _MemoryStore([
        created,
        MessageEvent(
          eventId: 'restore-tamper',
          messageId: 'm1',
          conversationId: 'c1',
          actorId: 'bob',
          type: MessageEventType.edited,
          revision: 1,
          createdAt: DateTime.utc(2026, 10, 20, 4),
          body: 'tampered',
        ),
      ]);

      final repository = await MessageRepository.restore(store);

      expect(repository.projectionFor('m1')?.visibleBody, 'hello');
      expect(repository.conflicts.single.eventId, 'restore-tamper');
      await repository.dispose();
    },
  );

  test('flush can scope a shared outbox to one conversation', () async {
    final repository = MessageRepository();
    final first = created;
    final second = MessageEvent(
      eventId: 'other-conversation',
      messageId: 'other-message',
      conversationId: 'c2',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: created.createdAt,
      body: 'other',
    );
    await repository.addLocal(first);
    await repository.addLocal(second);

    final transport = _RecordingTransport();
    await repository.flush(
      transport,
      shouldSend: (event) => event.conversationId == 'c1',
    );

    expect(transport.sent.map((event) => event.messageId), ['m1']);
    expect(repository.pendingOutbox.map((event) => event.messageId), [
      'other-message',
    ]);
    await repository.dispose();
  });

  test('serializes concurrent flush calls', () async {
    final repository = MessageRepository();
    final commands = MessageCommandService(
      repository: repository,
      actorId: 'alice',
      conversationId: '1:2',
    );
    final event = await commands.create('once', messageId: 'once');
    final transport = _CountingTransport();

    await Future.wait([
      repository.flush(transport),
      repository.flush(transport),
    ]);

    expect(transport.sent, [event.eventId]);
    expect(repository.pendingOutbox, isEmpty);
    await repository.dispose();
  });
}

class _CountingTransport implements MessageTransport {
  final sent = <String>[];

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> send(MessageEvent event) async {
    await Future<void>.delayed(Duration.zero);
    sent.add(event.eventId);
  }

  @override
  Future<void> disconnect() async {}
}

class _RejectingAuthenticator implements EventAuthenticator {
  @override
  Future<String> sign(MessageEvent event) async => 'unused';

  @override
  Future<bool> verify(MessageEvent event) async => false;
}

class _RecordingTransport implements MessageTransport {
  final sent = <MessageEvent>[];

  @override
  Stream<MessageEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> send(MessageEvent event) async => sent.add(event);

  @override
  Future<void> disconnect() async {}
}

class _MemoryStore
    implements MessageEventStore, MessageConflictStore, MessageInboxStore {
  _MemoryStore(this.events, [List<MessageEvent>? pending])
    : pending = pending ?? <MessageEvent>[];

  final List<MessageEvent> events;
  final List<MessageEvent> pending;
  final conflicts = <MessageConflict>[];
  final inbox = <MessageEvent>[];

  @override
  Future<void> acknowledgeOutbox(String eventId) async {
    pending.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<void> appendInbox(MessageEvent event) async {
    if (!inbox.any((candidate) => candidate.eventId == event.eventId)) {
      inbox.add(event);
    }
  }

  @override
  Future<List<MessageEvent>> loadInbox() async => List.of(inbox);

  @override
  Future<void> removeInbox(String eventId) async {
    inbox.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    if (!events.any((candidate) => candidate.eventId == event.eventId)) {
      events.add(event);
    }
    if (pendingOutbox &&
        !pending.any((candidate) => candidate.eventId == event.eventId)) {
      pending.add(event);
    }
  }

  @override
  Future<List<MessageEvent>> loadAll() async => List.of(events);

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async => List.of(pending);

  @override
  Future<List<MessageConflict>> loadConflicts() async => List.of(conflicts);

  @override
  Future<void> appendConflict(MessageConflict conflict) async {
    conflicts.add(conflict);
  }
}
