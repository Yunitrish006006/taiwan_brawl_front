import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/message_chat_sync_adapter.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:user_basic_system/user_basic_system.dart' show ChatMessage;

void main() {
  test('imports legacy recalled snapshots as event history', () {
    final snapshot = MessageChatSyncAdapter.exportMessages(
      [
        ChatMessage(
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

    final events = MessageChatSyncAdapter.importEvents(snapshot, 2, 1);

    expect(events.map((event) => event.type), [
      MessageEventType.created,
      MessageEventType.recalled,
    ]);
    expect(events.first.conversationId, '1:2');
  });

  test('promotes legacy messages into deterministic shared events', () {
    final events = MessageChatSyncAdapter.eventsFromMessages(
      [
        ChatMessage(
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
}
