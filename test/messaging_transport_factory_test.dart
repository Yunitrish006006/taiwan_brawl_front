import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/messaging_transport_factory.dart';

void main() {
  test('selects one deterministic caller for a peer pair', () {
    expect(MessagingTransportFactory.isCaller(selfId: 1, friendId: 2), isTrue);
    expect(MessagingTransportFactory.isCaller(selfId: 2, friendId: 1), isFalse);
    expect(MessagingTransportFactory.isCaller(selfId: 7, friendId: 7), isFalse);
  });
}
