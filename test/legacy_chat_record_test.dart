import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';

void main() {
  test('keeps the legacy Hive JSON fields and message key stable', () {
    const record = LegacyChatRecord(
      senderId: 7,
      receiverId: 3,
      text: 'legacy body',
      createdAt: '2026-10-28T01:02:03.000Z',
      isPending: true,
      isRecalled: true,
      pendingId: 82,
    );

    expect(record.messageKey, '2026-10-28T01:02:03.000Z_7');
    expect(jsonDecode(jsonEncode(record.toJson())), {
      'senderId': 7,
      'receiverId': 3,
      'text': 'legacy body',
      'createdAt': '2026-10-28T01:02:03.000Z',
      'isPending': true,
      'isRecalled': true,
      'pendingId': 82,
    });
    expect(
      LegacyChatRecord.fromJson(record.toJson()).toJson(),
      record.toJson(),
    );
  });

  test('reads snake-case server rows and prior pending IDs', () {
    final record = LegacyChatRecord.fromJson({
      'sender_id': 7,
      'receiver_id': 3,
      'text': 'old server row',
      'created_at': '2026-10-28T01:02:03.000Z',
      'id': 82,
    });

    expect(record.senderId, 7);
    expect(record.receiverId, 3);
    expect(record.createdAt, '2026-10-28T01:02:03.000Z');
    expect(record.pendingId, 82);
  });

  test('server-row defaults match the former ChatMessage JSON adapter', () {
    final record = LegacyChatRecord.fromLegacyServerJson({
      'senderId': 7,
      'receiverId': 3,
      'text': 'pending body',
      'createdAt': '2026-10-28T01:02:03.000Z',
      'id': 82,
      'isPending': true,
      'isRecalled': true,
    });

    expect(record.pendingId, 82);
    expect(record.isPending, isFalse);
    expect(record.isRecalled, isFalse);
  });

  test('rejects nonnumeric legacy IDs instead of corrupting the row', () {
    expect(
      () => LegacyChatRecord.fromJson({'senderId': 'seven', 'receiverId': 3}),
      throwsFormatException,
    );
  });
}
