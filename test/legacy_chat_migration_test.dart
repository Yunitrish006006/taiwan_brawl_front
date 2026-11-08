import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';
import 'package:taiwan_brawl/services/local_chat_repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy-chat-migration-');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'migration manifest survives restart and invalidates on legacy writes',
    () async {
      var repository = LocalChatRepository();
      await repository.saveMessage(1, _legacyMessage('row one', 0));
      await repository.saveMessage(1, _legacyMessage('row two', 1));
      final snapshot = await repository.getHistorySnapshot(1, 2);
      await repository.markEventMessagesMigrated(1, 2, {
        'message-b',
        'message-a',
      }, expectedSourceRevision: snapshot.sourceRevision);
      expect(await repository.migratedEventMessageIds(1, 2), {
        'message-a',
        'message-b',
      });

      await Hive.close();
      Hive.init(directory.path);
      repository = LocalChatRepository();

      expect(await repository.migratedEventMessageIds(1, 2), {
        'message-a',
        'message-b',
      });
      await repository.saveMessage(1, _legacyMessage('new legacy row', 2));
      expect(await repository.migratedEventMessageIds(1, 2), isNull);
      final rows = (await repository.getHistorySnapshot(1, 2)).messages;
      expect(rows, hasLength(3));
      expect(rows.last.text, 'new legacy row');
    },
  );

  test(
    'malformed migration manifest falls back to reading legacy rows',
    () async {
      final box = await Hive.openBox<String>('chat_event_migration_v1');
      await box.put('chat_1_2', '{invalid json');

      final repository = LocalChatRepository();

      expect(await repository.migratedEventMessageIds(1, 2), isNull);
      expect(box.containsKey('chat_1_2'), isFalse);
    },
  );

  test('invalid history rows are isolated and retained in Hive', () async {
    final repository = LocalChatRepository();
    final valid = _legacyMessage('readable row', 0);
    final box = await Hive.openBox<String>('chat_1_2');
    await box.put(valid.messageKey, jsonEncode(_messageJson(valid)));
    await box.put('corrupt-row-key', '{invalid row json');
    await box.put('scalar-row-key', '42');
    await box.put(
      'wrong-type-row-key',
      '{"senderId":1,"receiverId":2,"text":false}',
    );
    final mismatched = _legacyMessage('mismatched row key', 1);
    await box.put(
      'not-${mismatched.messageKey}',
      jsonEncode(_messageJson(mismatched)),
    );
    final invalidTimestamp = LegacyChatRecord(
      senderId: 1,
      receiverId: 2,
      text: 'invalid timestamp',
      createdAt: 'not-a-date',
    );
    await box.put(
      invalidTimestamp.messageKey,
      jsonEncode(_messageJson(invalidTimestamp)),
    );

    final snapshot = await repository.getHistorySnapshot(1, 2);

    expect(snapshot.messages.map((message) => message.text), ['readable row']);
    expect(snapshot.invalidRowKeys, unorderedEquals([
      'corrupt-row-key',
      invalidTimestamp.messageKey,
      'scalar-row-key',
      'not-${mismatched.messageKey}',
      'wrong-type-row-key',
    ]));
    expect(box.get('corrupt-row-key'), '{invalid row json');
    expect(box.get('scalar-row-key'), '42');
    expect(box.get('not-${mismatched.messageKey}'), isNotNull);
    await expectLater(
      repository.markEventMessagesMigrated(1, 2, {
        valid.messageKey,
      }, expectedSourceRevision: snapshot.sourceRevision),
      throwsStateError,
    );
  });

  test(
    'stale manifest detects legacy rows added outside repository methods',
    () async {
      final repository = LocalChatRepository();
      await repository.saveMessage(1, _legacyMessage('original row', 0));
      final snapshot = await repository.getHistorySnapshot(1, 2);
      await repository.markEventMessagesMigrated(1, 2, {
        'event-message-1',
      }, expectedSourceRevision: snapshot.sourceRevision);

      final legacyBox = await Hive.openBox<String>('chat_1_2');
      final extra = _legacyMessage('externally added row', 1);
      await legacyBox.put(extra.messageKey, jsonEncode(_messageJson(extra)));

      expect(await repository.migratedEventMessageIds(1, 2), isNull);
      expect(
        Hive.box<String>('chat_event_migration_v1').containsKey('chat_1_2'),
        isFalse,
      );
    },
  );

  test(
    'refuses to mark an incomplete legacy-row promotion as complete',
    () async {
      final repository = LocalChatRepository();
      await repository.saveMessage(1, _legacyMessage('only row', 0));

      await expectLater(
        repository.markEventMessagesMigrated(
          1,
          2,
          {'event-message-1', 'event-message-2'},
          expectedSourceRevision: (await repository.getHistorySnapshot(
            1,
            2,
          )).sourceRevision,
        ),
        throwsStateError,
      );
      expect(await repository.migratedEventMessageIds(1, 2), isNull);
    },
  );

  test(
    'upgrades a valid previous list manifest after checking row count',
    () async {
      final repository = LocalChatRepository();
      final legacy = _legacyMessage('existing row', 0);
      await repository.saveMessage(1, legacy);
      final migrationBox = await Hive.openBox<String>(
        'chat_event_migration_v1',
      );
      await migrationBox.put('chat_1_2', jsonEncode(['legacy-event-id']));

      expect(await repository.migratedEventMessageIds(1, 2), {
        'legacy-event-id',
      });
      final upgraded = jsonDecode(migrationBox.get('chat_1_2')!);
      expect(upgraded['schemaVersion'], 2);
      expect(upgraded['sourceRowKeys'], [legacy.messageKey]);
      expect(upgraded['sourceRowDigests'], isA<Map<String, dynamic>>());
    },
  );

  test('stale manifest detects in-place legacy row edits', () async {
    final repository = LocalChatRepository();
    final legacy = _legacyMessage('original row', 0);
    await repository.saveMessage(1, legacy);
    final snapshot = await repository.getHistorySnapshot(1, 2);
    await repository.markEventMessagesMigrated(1, 2, {
      'legacy-event-id',
    }, expectedSourceRevision: snapshot.sourceRevision);

    final legacyBox = await Hive.openBox<String>('chat_1_2');
    final changed = LegacyChatRecord(
      senderId: legacy.senderId,
      receiverId: legacy.receiverId,
      text: 'edited outside the new event store',
      createdAt: legacy.createdAt,
      isPending: legacy.isPending,
      isRecalled: legacy.isRecalled,
      pendingId: legacy.pendingId,
    );
    await legacyBox.put(legacy.messageKey, jsonEncode(_messageJson(changed)));

    expect(await repository.migratedEventMessageIds(1, 2), isNull);
    expect(
      Hive.box<String>('chat_event_migration_v1').containsKey('chat_1_2'),
      isFalse,
    );
  });

  test('does not mark a changed legacy snapshot as fully migrated', () async {
    final repository = LocalChatRepository();
    final legacy = _legacyMessage('message before migration', 0);
    await repository.saveMessage(1, legacy);
    final snapshot = await repository.getHistorySnapshot(1, 2);

    final legacyBox = await Hive.openBox<String>('chat_1_2');
    final edited = LegacyChatRecord(
      senderId: legacy.senderId,
      receiverId: legacy.receiverId,
      text: 'edited while migration was running',
      createdAt: legacy.createdAt,
      isPending: legacy.isPending,
      isRecalled: true,
      pendingId: legacy.pendingId,
    );
    await legacyBox.put(legacy.messageKey, jsonEncode(_messageJson(edited)));

    final marked = await repository.markEventMessagesMigrated(1, 2, {
      legacy.messageKey,
    }, expectedSourceRevision: snapshot.sourceRevision);

    expect(marked, isFalse);
    expect(await repository.migratedEventMessageIds(1, 2), isNull);
  });

  test(
    'upgrades a valid version-one key manifest with content fingerprints',
    () async {
      final repository = LocalChatRepository();
      final legacy = _legacyMessage('existing row', 0);
      await repository.saveMessage(1, legacy);
      final migrationBox = await Hive.openBox<String>(
        'chat_event_migration_v1',
      );
      await migrationBox.put(
        'chat_1_2',
        jsonEncode({
          'schemaVersion': 1,
          'messageIds': ['legacy-event-id'],
          'sourceRowKeys': [legacy.messageKey],
        }),
      );

      expect(await repository.migratedEventMessageIds(1, 2), {
        'legacy-event-id',
      });
      final upgraded = jsonDecode(migrationBox.get('chat_1_2')!);
      expect(upgraded['schemaVersion'], 2);
      expect(upgraded['sourceRowKeys'], [legacy.messageKey]);
      expect(
        upgraded['sourceRowDigests'][legacy.messageKey],
        matches(RegExp(r'^[a-f0-9]{64}$')),
      );
    },
  );

  test(
    'reads old Hive rows and writes the same row shape through the DTO',
    () async {
      final legacyBox = await Hive.openBox<String>('chat_1_2');
      const oldRow =
          '{"senderId":1,"receiverId":2,"text":"old row",'
          '"createdAt":"2026-10-28T00:00:00.000Z",'
          '"isPending":true,"isRecalled":false,"pendingId":91}';
      await legacyBox.put('2026-10-28T00:00:00.000Z_1', oldRow);
      final repository = LocalChatRepository();

      final loaded = (await repository.getHistorySnapshot(1, 2)).messages;
      expect(loaded.single.messageKey, '2026-10-28T00:00:00.000Z_1');
      expect(loaded.single.text, 'old row');
      expect(loaded.single.isPending, isTrue);
      expect(loaded.single.pendingId, 91);
      await repository.saveMessage(
        1,
        const LegacyChatRecord(
          senderId: 1,
          receiverId: 2,
          text: 'new row',
          createdAt: '2026-10-28T00:01:00.000Z',
        ),
      );
      final saved = jsonDecode(legacyBox.get('2026-10-28T00:01:00.000Z_1')!);
      expect(saved.keys.toSet(), {
        'senderId',
        'receiverId',
        'text',
        'createdAt',
        'isPending',
        'isRecalled',
        'pendingId',
      });
    },
  );
}

LegacyChatRecord _legacyMessage(String text, int minute) {
  return LegacyChatRecord(
    senderId: 1,
    receiverId: 2,
    text: text,
    createdAt: DateTime.utc(2026, 10, 22, 0, minute).toIso8601String(),
  );
}

Map<String, Object?> _messageJson(LegacyChatRecord message) => message.toJson();
