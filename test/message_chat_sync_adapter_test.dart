import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';
import 'package:taiwan_brawl/services/legacy_chat_event_mapper.dart';
import 'package:taiwan_brawl/services/message_chat_sync_adapter.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'exports shared projections without changing the legacy snapshot shape',
    () {
      final created = MessageEvent(
        eventId: 'created-event',
        messageId: 'event-message-id',
        conversationId: '1:2',
        actorId: '1',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        body: '原始訊息',
      );
      final recalled = MessageProjection.fromCreated(created).apply(
        MessageEvent(
          eventId: 'recalled-event',
          messageId: created.messageId,
          conversationId: created.conversationId,
          actorId: '1',
          type: MessageEventType.recalled,
          revision: 1,
          createdAt: created.createdAt,
        ),
      );
      final read = recalled.apply(
        MessageEvent(
          eventId: 'read-event',
          messageId: created.messageId,
          conversationId: created.conversationId,
          actorId: '2',
          type: MessageEventType.read,
          revision: 2,
          createdAt: created.createdAt,
        ),
      );
      expect(
        MessageChatSyncAdapter.exportProjections(
          [read],
          2,
          1,
          pendingMessageIds: const ['event-message-id'],
        ),
        {
          'chat_1_2': {
            '2026-01-01T00:00:00.000Z_1': jsonEncode({
              'senderId': 1,
              'receiverId': 2,
              'text': '訊息已收回',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'isPending': true,
              'isRecalled': true,
              'pendingId': 1767225600000,
            }),
          },
        },
      );
    },
  );

  test('imports legacy recalled snapshots as event history', () {
    final snapshot = {
      'chat_1_2': {
        '2026-01-01T00:00:00.000Z_1': jsonEncode({
          'senderId': 1,
          'receiverId': 2,
          'text': '舊訊息',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'isPending': false,
          'isRecalled': true,
          'pendingId': null,
        }),
      },
    };

    final events = LegacyChatEventMapper.fromSnapshot(snapshot, 2, 1);

    expect(events.map((event) => event.type), [
      MessageEventType.created,
      MessageEventType.recalled,
    ]);
    expect(events.first.conversationId, '1:2');
  });

  test('validates every snapshot row and its Hive identity before mapping', () {
    const messageKey = '2026-01-01T00:00:00.000Z_1';
    final validRecord = jsonEncode({
      'senderId': 1,
      'receiverId': 2,
      'text': 'valid',
      'createdAt': '2026-01-01T00:00:00.000Z',
    });
    expect(
      LegacyChatEventMapper.validateSnapshot({
        'chat_1_2': {messageKey: validRecord},
      }),
      isA<Map<String, dynamic>>(),
    );

    final invalidSnapshots = <Map<String, dynamic>>[
      {
        'chat_1_2': {messageKey: '{broken'},
      },
      {
        'chat_1_2': {'different-key': validRecord},
      },
      {
        'chat_1_2': {
          'invalid-time_1': jsonEncode({
            'senderId': 1,
            'receiverId': 2,
            'text': 'bad timestamp',
            'createdAt': 'invalid-time',
          }),
        },
      },
      {
        'chat_1_2': {
          messageKey: jsonEncode({
            'senderId': 1,
            'receiverId': 3,
            'text': 'wrong conversation',
            'createdAt': '2026-01-01T00:00:00.000Z',
          }),
        },
      },
      {
        'chat_1_2': {messageKey: 42},
      },
    ];

    for (final snapshot in invalidSnapshots) {
      expect(
        () => LegacyChatEventMapper.validateSnapshot(snapshot),
        throwsFormatException,
      );
    }
  });

  test('promotes legacy messages into deterministic shared events', () {
    final events = LegacyChatEventMapper.fromRecords(
      [
        LegacyChatRecord(
          senderId: 1,
          receiverId: 2,
          text: '舊訊息',
          createdAt: '2026-01-01T00:00:00.000Z',
          isRecalled: true,
        ),
      ],
      2,
      1,
    );

    expect(events.map((event) => event.eventId), [
      'legacy-created:2026-01-01T00:00:00.000Z_1',
      'legacy-recalled:2026-01-01T00:00:00.000Z_1',
    ]);
    expect(events.last.revision, 1);
  });

  test('skips legacy rows without a usable event timestamp', () {
    final events = LegacyChatEventMapper.fromRecords(
      [
        const LegacyChatRecord(
          senderId: 1,
          receiverId: 2,
          text: '時間無效的舊訊息',
          createdAt: 'not-a-timestamp',
        ),
      ],
      2,
      1,
    );

    expect(events, isEmpty);
  });
}
