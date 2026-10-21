import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/p2p_message_session.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'keeps P2P edits and recalls locally until a transport attaches',
    () async {
      final repository = MessageRepository();
      final session = P2PMessageSession(
        selfId: 1,
        friendId: 2,
        repository: repository,
        onMessage: (_) {},
      );

      await session.send('offline');
      final messageId = repository.events.first.messageId;
      await session.edit(messageId, 'edited offline');
      await session.recall(messageId);

      expect(
        repository.projectionFor(messageId)?.visibleBody,
        recalledMessageText,
      );
      expect(repository.pendingOutbox, hasLength(3));

      final (transport, unusedPeer) = InMemoryMessageTransport.pair();
      final unusedPeerSubscription = unusedPeer.events.listen((_) {});
      await session.attach(transport);

      expect(repository.pendingOutbox, isEmpty);
      await session.dispose();
      await transport.dispose();
      await unusedPeer.dispose();
      await unusedPeerSubscription.cancel();
    },
  );

  test(
    'runs created, edit and recall over replaceable in-memory transport',
    () async {
      final leftRepository = MessageRepository();
      final rightRepository = MessageRepository();
      final (leftTransport, rightTransport) = InMemoryMessageTransport.pair();
      final leftMessages = <String>[];
      final rightMessages = <String>[];
      final left = P2PMessageSession(
        selfId: 1,
        friendId: 2,
        repository: leftRepository,
        onMessage: (message) => leftMessages.add(message.text),
      );
      final right = P2PMessageSession(
        selfId: 2,
        friendId: 1,
        repository: rightRepository,
        onMessage: (message) => rightMessages.add(message.text),
      );

      await left.attach(leftTransport);
      await right.attach(rightTransport);
      await left.send('hello');
      await Future<void>.delayed(Duration.zero);

      final messageId = leftRepository.events.first.messageId;
      await left.edit(messageId, 'edited');
      await Future<void>.delayed(Duration.zero);
      await left.recall(messageId);
      await Future<void>.delayed(Duration.zero);

      expect(
        rightRepository.projectionFor(messageId)?.visibleBody,
        recalledMessageText,
      );
      expect(rightMessages, contains('hello'));
      expect(rightMessages, contains('edited'));
      expect(rightMessages, contains(recalledMessageText));
      expect(leftMessages, contains('hello'));

      await left.dispose();
      await right.dispose();
      await leftTransport.dispose();
      await rightTransport.dispose();
    },
  );
}
