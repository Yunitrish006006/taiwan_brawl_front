import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('application seam builds shared commands over its repository', () async {
    final service = MessagingCoreService();
    final event = await service
        .commands(actorId: 'alice', conversationId: 'alice:bob')
        .create('through application api');

    expect(event.messageId, isNotEmpty);
    expect(
      service.conversation('alice:bob').single.visibleBody,
      'through application api',
    );
    expect(service.repository.pendingOutbox, hasLength(1));
    expect(service.storageStatus.mode, MessagingStorageMode.inMemory);
    await service.dispose();
  });

  test(
    'degraded storage status exposes a restore failure explicitly',
    () async {
      final service = MessagingCoreService(
        storageStatus: MessagingStorageStatus.degraded('keychain unavailable'),
      );

      expect(service.storageStatus.mode, MessagingStorageMode.degraded);
      expect(service.storageStatus.isDurable, isFalse);
      expect(service.storageStatus.failureDescription, 'keychain unavailable');
      await service.dispose();
    },
  );

  test('application seam syncs an offline outbox between two peers', () async {
    final left = MessagingCoreService();
    final right = MessagingCoreService();
    final (leftTransport, rightTransport) = InMemoryMessageTransport.pair();
    final leftEngine = left.syncEngine(transport: leftTransport);
    final rightEngine = right.syncEngine(transport: rightTransport);

    await rightEngine.start();
    await leftEngine.start();
    final event = await left
        .commands(actorId: 'alice', conversationId: 'alice:bob')
        .create('peer sync through application api');
    await leftEngine.syncNow();
    await Future<void>.delayed(Duration.zero);

    expect(left.repository.pendingOutbox, isEmpty);
    expect(
      right.conversation('alice:bob').single.visibleBody,
      'peer sync through application api',
    );

    await leftEngine.stop();
    await rightEngine.stop();
    await left.dispose();
    await right.dispose();
    expect(event.eventId, isNotEmpty);
  });

  test(
    'frontend seam exposes offline projection and remote ingestion',
    () async {
      final service = MessagingCoreService();
      await service.repository.addLocal(
        MessageEvent(
          eventId: 'local-created',
          messageId: 'message-1',
          conversationId: 'conversation-1',
          actorId: 'alice',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 10, 20),
          body: 'offline message',
        ),
      );

      expect(
        service.conversation('conversation-1').single.visibleBody,
        'offline message',
      );
      expect(service.repository.pendingOutbox, hasLength(1));
      await service.dispose();
    },
  );

  test('can restore the frontend seam from a durable event store', () async {
    final event = MessageEvent(
      eventId: 'restored-created',
      messageId: 'restored-message',
      conversationId: 'conversation-restore',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'restored message',
    );
    final store = _MemoryEventStore([event], [event]);
    final service = await MessagingCoreService.restore(store);

    expect(
      service.conversation('conversation-restore').single.visibleBody,
      'restored message',
    );
    expect(service.repository.pendingOutbox, hasLength(1));
    expect(service.storageStatus.isDurable, isTrue);
    await service.dispose();
  });
}

class _MemoryEventStore implements MessageEventStore {
  _MemoryEventStore(this.events, this.pending);

  final List<MessageEvent> events;
  final List<MessageEvent> pending;

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
  Future<List<MessageEvent>> loadAll() async => List.of(events);

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async => List.of(pending);
}
