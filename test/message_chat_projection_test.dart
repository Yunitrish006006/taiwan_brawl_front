import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/message_chat_projection.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('projects edit and recall into the existing chat model', () async {
    final repository = MessageRepository();
    final commands = MessageCommandService(
      repository: repository,
      actorId: '1',
      conversationId: '1:2',
    );
    final created = await commands.create(
      '原始訊息',
      messageId: 'message-1',
      eventId: 'event-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await commands.edit('message-1', '編輯後訊息', eventId: 'event-2');
    await commands.recall('message-1', eventId: 'event-3');

    final messages = MessageChatProjection.toMessages(
      projections: repository.projectionsFor('1:2'),
      selfId: 2,
      friendId: 1,
      pendingMessageIds: {created.messageId},
    );

    expect(messages, hasLength(1));
    expect(messages.single.text, recalledMessageText);
    expect(messages.single.isRecalled, isTrue);
    expect(messages.single.isPending, isTrue);
  });
}
