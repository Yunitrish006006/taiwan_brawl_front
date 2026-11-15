import 'package:flutter_test/flutter_test.dart';

import 'package:taiwan_brawl/services/conversation_key_agreement.dart';

void main() {
  test('both paired devices derive the same conversation key', () async {
    final alice = await ConversationKeyAgreement.create(
      conversationId: '1:2',
      localDeviceId: 'device-a',
    );
    final bob = await ConversationKeyAgreement.create(
      conversationId: '1:2',
      localDeviceId: 'device-b',
    );

    final aliceKey = await alice.deriveKey(bob.offer);
    final bobKey = await bob.deriveKey(alice.offer);

    expect(aliceKey, bobKey);
    expect(aliceKey, hasLength(32));
  });

  test('rejects an offer for another conversation', () async {
    final alice = await ConversationKeyAgreement.create(
      conversationId: '1:2',
      localDeviceId: 'device-a',
    );
    final bob = await ConversationKeyAgreement.create(
      conversationId: '2:3',
      localDeviceId: 'device-b',
    );

    expect(() => alice.deriveKey(bob.offer), throwsFormatException);
  });

  test('round-trips and validates a public offer', () async {
    final alice = await ConversationKeyAgreement.create(
      conversationId: '1:2',
      localDeviceId: 'device-a',
    );
    final restored = ConversationKeyOffer.fromJson(alice.offer.toJson());

    expect(restored.conversationId, '1:2');
    expect(restored.deviceId, 'device-a');
    expect(restored.publicKey, alice.offer.publicKey);
  });
}
