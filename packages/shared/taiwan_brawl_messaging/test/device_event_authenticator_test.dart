import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'signs local events and resolves a peer identity for verification',
    () async {
      final local = _FakeIdentity('local', 'local-secret');
      final peer = _FakeIdentity('peer', 'peer-secret');
      final authenticator = DeviceEventAuthenticator(
        localIdentity: local,
        directory: _Directory({'peer': peer}),
      );
      final unsigned = MessageEvent(
        eventId: 'event-1',
        messageId: 'message-1',
        conversationId: '1:2',
        actorId: '2',
        deviceId: 'peer',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        body: 'hello',
      );
      final peerSigned = unsigned.withSignature(
        await peer.sign(unsigned.canonicalPayload),
      );

      expect(await authenticator.verify(peerSigned), isTrue);
      expect(
        await authenticator.verify(peerSigned.withSignature('tampered')),
        isFalse,
      );
      expect(() => authenticator.sign(unsigned), throwsStateError);
    },
  );
}

class _Directory implements DeviceIdentityDirectory {
  _Directory(this.identities);

  final Map<String, DeviceIdentity> identities;

  @override
  Future<DeviceIdentity?> resolve(String deviceId) async =>
      identities[deviceId];
}

class _FakeIdentity implements DeviceIdentity {
  _FakeIdentity(this.deviceId, this.secret);

  @override
  final String deviceId;
  final String secret;

  @override
  Future<String> sign(String payload) async => '$secret:$payload';

  @override
  Future<bool> verify(
    String payload,
    String signature,
    String candidateDeviceId,
  ) async => candidateDeviceId == deviceId && signature == '$secret:$payload';
}
