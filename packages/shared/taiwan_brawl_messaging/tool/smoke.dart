import '../lib/taiwan_brawl_messaging.dart';

Future<void> main() async {
  final repository = MessageRepository();
  final created = MessageEvent(
    eventId: 'created',
    messageId: 'message',
    conversationId: 'conversation',
    actorId: 'alice',
    type: MessageEventType.created,
    revision: 0,
    createdAt: DateTime.utc(2026, 10, 20),
    body: 'hello',
  );
  if (created.withSignature('signature').canonicalPayload !=
      created.canonicalPayload) {
    throw StateError('canonical event payload changed when signed');
  }
  await repository.addLocal(created);
  await repository.addLocal(
    MessageEvent(
      eventId: 'read',
      messageId: 'message',
      conversationId: 'conversation',
      actorId: 'bob',
      type: MessageEventType.read,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 20, 0, 1),
    ),
  );
  await repository.addLocal(
    MessageEvent(
      eventId: 'recalled',
      messageId: 'message',
      conversationId: 'conversation',
      actorId: 'alice',
      type: MessageEventType.recalled,
      revision: 2,
      createdAt: DateTime.utc(2026, 10, 20, 0, 2),
    ),
  );

  final projection = repository.projectionFor('message');
  if (projection?.visibleBody != recalledMessageText ||
      projection?.readBy.contains('bob') != true ||
      repository.pendingOutbox.length != 3) {
    throw StateError('offline messaging smoke test failed');
  }
  await repository.dispose();

  final (left, right) = InMemoryMessageTransport.pair();
  await left.connect();
  await right.connect();
  final received = <MessageEvent>[];
  final leftSubscription = left.events.listen((_) {});
  final subscription = right.events.listen(received.add);
  await left.send(
    MessageEvent(
      eventId: 'transport-event',
      messageId: 'transport-message',
      conversationId: 'conversation',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'p2p smoke',
    ),
  );
  await Future<void>.delayed(Duration.zero);
  if (received.single.body != 'p2p smoke') {
    throw StateError('transport smoke test failed');
  }
  await subscription.cancel();
  await leftSubscription.cancel();
  await left.dispose();
  await right.dispose();

  final (syncLeftTransport, syncRightTransport) =
      InMemoryMessageTransport.pair();
  final syncLeftRepository = MessageRepository();
  final syncRightRepository = MessageRepository();
  final syncLeft = MessageSyncEngine(
    repository: syncLeftRepository,
    transport: syncLeftTransport,
  );
  final syncRight = MessageSyncEngine(
    repository: syncRightRepository,
    transport: syncRightTransport,
  );
  await syncRight.start();
  await syncLeft.start();
  await syncLeftRepository.addLocal(
    MessageEvent(
      eventId: 'synced-created',
      messageId: 'synced-message',
      conversationId: 'conversation',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'synced',
    ),
  );
  await syncLeft.syncNow();
  await Future<void>.delayed(Duration.zero);
  if (syncRightRepository.projectionFor('synced-message')?.visibleBody !=
      'synced') {
    throw StateError('sync engine smoke test failed');
  }
  await syncLeft.stop();
  await syncRight.stop();
  await syncLeftRepository.dispose();
  await syncRightRepository.dispose();
  print('offline messaging smoke test passed');
}
