import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/conversation_key_exchange_coordinator.dart';

void main() {
  test('two coordinators establish the same key and key id', () async {
    final leftControls = StreamController<Map<String, Object?>>();
    final rightControls = StreamController<Map<String, Object?>>();
    final leftKeys = <String, List<int>>{};
    final rightKeys = <String, List<int>>{};
    late ConversationKeyExchangeCoordinator left;
    late ConversationKeyExchangeCoordinator right;

    left = ConversationKeyExchangeCoordinator(
      conversationId: '1:2',
      localDeviceId: 'device-a',
      expectedRemoteDeviceId: 'device-b',
      sendControl: (message) async => rightControls.add(message),
      onEstablished: ({required keyId, required key}) async =>
          leftKeys[keyId] = key,
      verifyRemoteOffer: (_) async => true,
    );
    right = ConversationKeyExchangeCoordinator(
      conversationId: '1:2',
      localDeviceId: 'device-b',
      expectedRemoteDeviceId: 'device-a',
      sendControl: (message) async => leftControls.add(message),
      onEstablished: ({required keyId, required key}) async =>
          rightKeys[keyId] = key,
      verifyRemoteOffer: (_) async => true,
    );
    final leftSubscription = leftControls.stream.listen(left.handleControl);
    final rightSubscription = rightControls.stream.listen(right.handleControl);

    await Future.wait([left.start(), right.start()]);
    await Future<void>.delayed(Duration.zero);

    expect(left.established, isTrue);
    expect(right.established, isTrue);
    expect(leftKeys.keys, rightKeys.keys);
    expect(leftKeys.values.single, rightKeys.values.single);
    expect(leftKeys.values.single, hasLength(32));

    await leftSubscription.cancel();
    await rightSubscription.cancel();
    await leftControls.close();
    await rightControls.close();
  });

  test('rejects an unexpected peer device', () async {
    final coordinator = ConversationKeyExchangeCoordinator(
      conversationId: '1:2',
      localDeviceId: 'device-a',
      expectedRemoteDeviceId: 'device-b',
      sendControl: (_) async {},
      onEstablished: ({required keyId, required key}) async {},
      verifyRemoteOffer: (_) async => true,
    );
    final other = ConversationKeyExchangeCoordinator(
      conversationId: '1:2',
      localDeviceId: 'device-c',
      sendControl: (_) async {},
      onEstablished: ({required keyId, required key}) async {},
      verifyRemoteOffer: (_) async => true,
    );
    await other.start();
    final message = await _captureOffer(other);

    expect(() => coordinator.handleControl(message), throwsFormatException);
  });
}

Future<Map<String, Object?>> _captureOffer(
  ConversationKeyExchangeCoordinator coordinator,
) async {
  Map<String, Object?>? message;
  final sender = ConversationKeyExchangeCoordinator(
    conversationId: coordinator.conversationId,
    localDeviceId: 'capture-device',
    sendControl: (value) async => message = value,
    onEstablished: ({required keyId, required key}) async {},
    verifyRemoteOffer: (_) async => true,
  );
  await sender.start();
  return message!;
}
