import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/peer_trust_service.dart';
import 'package:taiwan_brawl/services/secure_device_identity.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'creates and accepts a fingerprint-confirmed trust invitation',
    () async {
      final localCredentials = _MemoryCredentials();
      final peerCredentials = _MemoryCredentials();
      final local = await SecureDeviceIdentity.restore(
        credentials: localCredentials,
      );
      final peer = await SecureDeviceIdentity.restore(
        credentials: peerCredentials,
      );
      final trust = PeerTrustService(credentials: localCredentials);
      final invitation = trust.createInvitation(peer);
      final decoded = PeerTrustInvitation.decode(invitation.encode());

      expect(decoded.deviceId, peer.deviceId);
      expect(decoded.wireVersion, 2);
      expect(decoded.algorithm, 'ed25519');
      expect(decoded.encodedMaterial, peer.publicKeyMaterial);
      final privateSeed =
          peerCredentials.values['taiwan_brawl.device-identity.ed25519.seed']!;
      expect(
        invitation.encode(),
        isNot(contains(privateSeed)),
      );
      expect(decoded.fingerprint, isNotEmpty);
      await trust.trustInvitation(
        invitation.encode(),
        confirmedFingerprint: decoded.fingerprint,
      );

      final event = MessageEvent(
        eventId: 'invitation-event',
        messageId: 'invitation-message',
        conversationId: '1:2',
        actorId: '2',
        deviceId: peer.deviceId,
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        body: 'trusted by invitation',
      );
      final signed = event.withSignature(
        await peer.sign(event.canonicalPayload),
      );

      expect(
        await trust.remoteAuthenticator(local: local).verify(signed),
        isTrue,
      );
    },
  );

  test(
    'requires matching confirmation and rejects tampered invitations',
    () async {
      final credentials = _MemoryCredentials();
      final peer = await SecureDeviceIdentity.restore(credentials: credentials);
      final trust = PeerTrustService(credentials: _MemoryCredentials());
      final invitation = trust.createInvitation(peer).encode();
      final decoded = PeerTrustInvitation.decode(invitation);

      await expectLater(
        trust.trustInvitation(invitation, confirmedFingerprint: 'wrong'),
        throwsFormatException,
      );
      final tampered = invitation.replaceFirst(
        decoded.encodedMaterial,
        '${decoded.encodedMaterial}x',
      );
      expect(() => PeerTrustInvitation.decode(tampered), throwsFormatException);
    },
  );

  test(
    'explicitly trusted peer material enables verification and revocation',
    () async {
      final localCredentials = _MemoryCredentials();
      final peerCredentials = _MemoryCredentials();
      final local = await SecureDeviceIdentity.restore(
        credentials: localCredentials,
      );
      final peer = await SecureDeviceIdentity.restore(
        credentials: peerCredentials,
      );
      final trust = PeerTrustService(credentials: localCredentials);
      final authenticator = trust.remoteAuthenticator(local: local);
      final event =
          MessageEvent(
            eventId: 'event-1',
            messageId: 'message-1',
            conversationId: '1:2',
            actorId: '2',
            deviceId: peer.deviceId,
            type: MessageEventType.created,
            revision: 0,
            createdAt: DateTime.utc(2026, 1, 1),
            body: 'trusted',
          ).withSignature(
            await peer.sign(
              MessageEvent(
                eventId: 'event-1',
                messageId: 'message-1',
                conversationId: '1:2',
                actorId: '2',
                deviceId: peer.deviceId,
                type: MessageEventType.created,
                revision: 0,
                createdAt: DateTime.utc(2026, 1, 1),
                body: 'trusted',
              ).canonicalPayload,
            ),
          );

      expect(await authenticator.verify(event), isFalse);
      await trust.trustPeer(
        deviceId: peer.deviceId,
        encodedMaterial: 'ed25519:${peer.publicKeyMaterial}',
      );
      expect(await authenticator.verify(event), isTrue);
      await trust.revokePeer(peer.deviceId);
      expect(await authenticator.verify(event), isFalse);
    },
  );

  test(
    'accepts legacy v1 shared-secret invitations only with confirmed fingerprint',
    () async {
      const deviceId = 'legacy-peer';
      final secret = base64UrlEncode(
        List<int>.generate(32, (index) => index + 1),
      );
      final fingerprint = sha256
          .convert(utf8.encode('$deviceId:$secret'))
          .toString();
      final encodedInvitation = jsonEncode({
        'version': 1,
        'deviceId': deviceId,
        'encodedMaterial': secret,
        'fingerprint': fingerprint,
      });
      final credentials = _MemoryCredentials();
      final trust = PeerTrustService(credentials: credentials);

      await trust.trustInvitation(
        encodedInvitation,
        confirmedFingerprint: fingerprint,
      );
      final legacyEvent = MessageEvent(
        eventId: 'legacy-event',
        messageId: 'legacy-message',
        conversationId: '1:2',
        actorId: '2',
        deviceId: deviceId,
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        body: 'legacy peer',
      );
      final signature = base64UrlEncode(
        Hmac(
          sha256,
          base64Url.decode(secret),
        ).convert(utf8.encode(legacyEvent.canonicalPayload)).bytes,
      );

      expect(
        await trust
            .remoteAuthenticator(
              local: await SecureDeviceIdentity.restore(
                credentials: _MemoryCredentials(),
              ),
            )
            .verify(legacyEvent.withSignature(signature)),
        isTrue,
      );
    },
  );
}

class _MemoryCredentials implements CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
