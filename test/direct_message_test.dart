import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/models/direct_message.dart';

void main() {
  test(
    'maps the canonical shared projection without losing event metadata',
    () {
      final projection = MessageProjection(
        messageId: 'event-message-42',
        conversationId: '1:2',
        authorId: '1',
        createdAt: DateTime.utc(2026, 10, 28),
        revision: 3,
        body: 'current text',
        recalled: false,
        readBy: const {'2'},
        lastEventId: 'read:event-message-42:2',
      );

      final message = DirectMessage.fromProjection(projection, isPending: true);

      expect(message.id, 'event-message-42');
      expect(message.authorId, '1');
      expect(message.revision, 3);
      expect(message.text, 'current text');
      expect(message.readBy, {'2'});
      expect(message.isPending, isTrue);
      expect(() => message.readBy.add('3'), throwsUnsupportedError);
    },
  );

  test(
    'projects edited and recalled shared history into the app DTO',
    () async {
      final repository = MessageRepository();
      final commands = MessageCommandService(
        repository: repository,
        actorId: '1',
        conversationId: '1:2',
      );
      await commands.create(
        'original body',
        messageId: 'message-1',
        eventId: 'event-1',
        createdAt: DateTime.utc(2026, 10, 28),
      );
      await commands.edit('message-1', 'edited body', eventId: 'event-2');
      await commands.recall('message-1', eventId: 'event-3');

      final message = DirectMessage.fromProjection(
        repository.projectionsFor('1:2').single,
        isPending: false,
      );

      expect(message.isRecalled, isTrue);
      expect(message.text, recalledMessageText);
      expect(message.revision, 2);
    },
  );
}
