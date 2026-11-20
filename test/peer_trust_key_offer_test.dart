import 'package:flutter_test/flutter_test.dart';

import 'package:taiwan_brawl/services/peer_trust_service.dart';
import 'package:taiwan_brawl/services/secure_device_identity.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'verifies a signed conversation key offer from a trusted device',
    () async {
      final localCredentials = _MemoryCredentials();
      final peerCredentials = _MemoryCredentials();
      final peer = await SecureDeviceIdentity.restore(
        credentials: peerCredentials,
        keyPrefix: 'peer.',
      );
      final trust = PeerTrustService(credentials: localCredentials);
      await trust.trustPeer(
        deviceId: peer.deviceId,
        encodedMaterial: 'ed25519:${peer.publicKeyMaterial}',
      );
      final payload = 'conversation-key-offer-payload';
      final signature = await peer.sign(payload);

      expect(
        await trust.verifySignedKeyOffer(
          deviceId: peer.deviceId,
          payload: payload,
          signature: signature,
        ),
        isTrue,
      );
      expect(
        await trust.verifySignedKeyOffer(
          deviceId: peer.deviceId,
          payload: '$payload-tampered',
          signature: signature,
        ),
        isFalse,
      );
    },
  );
}

class _MemoryCredentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
