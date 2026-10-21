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
      final peerSecret =
          peerCredentials.values['taiwan_brawl.device-identity.secret']!;
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
        encodedMaterial: peerSecret,
      );
      expect(await authenticator.verify(event), isTrue);
      await trust.revokePeer(peer.deviceId);
      expect(await authenticator.verify(event), isFalse);
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
