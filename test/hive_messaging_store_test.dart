import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/services/hive_messaging_store.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  late Directory directory;
  const boxName = 'messaging_store_round_trip_test';
  final key = List<int>.filled(32, 7);

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('taiwan-brawl-hive-');
    Hive.init(directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('restores encrypted event history and pending outbox', () async {
    final store = HiveMessageEventStore(encryptionKey: key, boxName: boxName);
    final created = MessageEvent(
      eventId: 'store-created',
      messageId: 'store-message',
      conversationId: 'store-conversation',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'durable',
    );

    final first = MessageRepository(store: store);
    await first.addLocal(created);
    await store.appendInbox(created);
    await first.dispose();

    final restored = await MessageRepository.restore(store);
    expect(restored.projectionFor('store-message')?.visibleBody, 'durable');
    expect(restored.pendingOutbox, hasLength(1));
    expect(await store.loadInbox(), isEmpty);
    await restored.acknowledge('store-created');
    await restored.dispose();

    final afterAck = await MessageRepository.restore(store);
    expect(afterAck.events, hasLength(1));
    expect(afterAck.pendingOutbox, isEmpty);
    await afterAck.dispose();
    await Hive.deleteBoxFromDisk(boxName);
  });

  test('restores friend-scoped relay cursors after Hive reopens', () async {
    const cursorBoxName = 'messaging_store_cursor_restart_test';
    final store = HiveMessageEventStore(
      encryptionKey: key,
      boxName: cursorBoxName,
    );
    await store.saveSyncCursor('dm:1:2', '17');
    await store.saveSyncCursor('dm:1:3', '9');

    await Hive.close();
    Hive.init(directory.path);

    final restored = HiveMessageEventStore(
      encryptionKey: key,
      boxName: cursorBoxName,
    );
    expect(await restored.loadSyncCursor('dm:1:2'), '17');
    expect(await restored.loadSyncCursor('dm:1:3'), '9');
    expect(await restored.loadSyncCursor('dm:2:1'), isNull);
    await Hive.deleteBoxFromDisk(cursorBoxName);
  });

  test('replays and clears a durable multi-event inbox batch', () async {
    const batchBoxName = 'messaging_store_batch_inbox_test';
    final store = HiveMessageEventStore(
      encryptionKey: key,
      boxName: batchBoxName,
    );
    final created = MessageEvent(
      eventId: 'batch-created',
      messageId: 'batch-message',
      conversationId: 'batch-conversation',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'before batch recovery',
    );
    final edited = MessageEvent(
      eventId: 'batch-edited',
      messageId: 'batch-message',
      conversationId: 'batch-conversation',
      actorId: 'alice',
      type: MessageEventType.edited,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 20, 1),
      body: 'after batch recovery',
    );
    await store.appendInboxBatch([created, edited]);

    final restored = await MessageRepository.restore(store);

    expect(
      restored.projectionFor(created.messageId)?.visibleBody,
      'after batch recovery',
    );
    expect((await store.loadAll()).map((event) => event.eventId), [
      'batch-created',
      'batch-edited',
    ]);
    expect((await store.loadInboxBatches()).map((batch) => batch.id), isEmpty);
    await restored.dispose();
    await Hive.deleteBoxFromDisk(batchBoxName);
  });

  test('recovers an outbox-only event after an interrupted write', () async {
    const recoveryBoxName = 'messaging_store_outbox_recovery_test';
    final box = await Hive.openBox<String>(
      recoveryBoxName,
      encryptionCipher: HiveAesCipher(key),
    );
    final event = MessageEvent(
      eventId: 'recovery-created',
      messageId: 'recovery-message',
      conversationId: 'recovery-conversation',
      actorId: 'alice',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 20),
      body: 'recovered',
    );
    await box.put('outbox:${event.eventId}', jsonEncode(event.toJson()));

    final store = HiveMessageEventStore(
      encryptionKey: key,
      boxName: recoveryBoxName,
    );
    final restored = await MessageRepository.restore(store);

    expect(restored.projectionFor(event.messageId)?.visibleBody, 'recovered');
    expect(restored.pendingOutbox.single.eventId, event.eventId);
    expect(restored.pendingOutbox.single.toJson(), event.toJson());
    expect(box.containsKey('event:${event.eventId}'), isTrue);

    await restored.dispose();
    await Hive.deleteBoxFromDisk(recoveryBoxName);
  });

  test('restores encrypted message conflicts', () async {
    const conflictBoxName = 'messaging_store_conflict_test';
    final store = HiveMessageEventStore(
      encryptionKey: key,
      boxName: conflictBoxName,
    );
    final repository = MessageRepository(store: store);
    await repository.acceptRemote(
      MessageEvent(
        eventId: 'conflict-created',
        messageId: 'conflict-message',
        conversationId: 'conflict-conversation',
        actorId: 'alice',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 10, 20),
        body: 'original',
      ),
    );
    final accepted = await repository.acceptRemote(
      MessageEvent(
        eventId: 'conflict-edit',
        messageId: 'conflict-message',
        conversationId: 'conflict-conversation',
        actorId: 'bob',
        type: MessageEventType.edited,
        revision: 1,
        createdAt: DateTime.utc(2026, 10, 20, 1),
        body: 'tampered',
      ),
    );

    expect(accepted, isFalse);
    await repository.dispose();

    final restored = await MessageRepository.restore(store);
    expect(restored.conflicts.single.eventId, 'conflict-edit');
    await restored.dispose();
    await Hive.deleteBoxFromDisk(conflictBoxName);
  });

  test('isolates a corrupt encrypted event record during restore', () async {
    const corruptBoxName = 'messaging_store_corrupt_test';
    final box = await Hive.openBox<String>(
      corruptBoxName,
      encryptionCipher: HiveAesCipher(key),
    );
    await box.put(
      'event:corrupt',
      '{"eventId":"bad","messageId":"bad","conversationId":"1:2",'
          '"actorId":"alice","type":"created","revision":0,'
          '"createdAt":123}',
    );
    await box.put(
      'outbox:corrupt',
      '{"eventId":"bad-outbox","messageId":"bad-outbox",'
          '"conversationId":"1:2","actorId":"alice","type":"created",'
          '"revision":0,"createdAt":123}',
    );
    await box.put(
      'inbox:corrupt',
      '{"eventId":"bad-inbox","messageId":"bad-inbox",'
          '"conversationId":"1:2","actorId":"alice","type":"created",'
          '"revision":0,"createdAt":123}',
    );
    await box.put(
      'inbox-batch:corrupt',
      '{"events":[{"eventId":"bad-batch","messageId":"bad-batch",'
          '"conversationId":"1:2","actorId":"alice",'
          '"type":"created","revision":0,"createdAt":123}]}',
    );

    final store = HiveMessageEventStore(
      encryptionKey: key,
      boxName: corruptBoxName,
    );
    final restored = await MessageRepository.restore(store);

    expect(restored.events, isEmpty);
    expect(restored.conflicts, hasLength(4));
    expect(
      restored.conflicts.map((conflict) => conflict.eventId),
      containsAll([
        'corrupt:event:corrupt',
        'corrupt:outbox:corrupt',
        'corrupt:inbox:corrupt',
        'corrupt:inbox-batch:corrupt',
      ]),
    );
    expect(box.containsKey('inbox:corrupt'), isFalse);
    expect(box.containsKey('inbox-batch:corrupt'), isFalse);
    await restored.dispose();
    await Hive.deleteBoxFromDisk(corruptBoxName);
  });
}
