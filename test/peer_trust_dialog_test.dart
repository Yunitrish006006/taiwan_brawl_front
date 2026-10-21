import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/chat_models.dart';
import 'package:taiwan_brawl/services/peer_trust_service.dart';
import 'package:taiwan_brawl/services/secure_device_identity.dart';
import 'package:taiwan_brawl/widgets/peer_trust_dialog.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  testWidgets('requires fingerprint confirmation before trusting a peer', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeerTrustDialog(trustService: trust, localIdentity: local),
        ),
      ),
    );

    expect(find.text('Your trust invitation'), findsOneWidget);
    await tester.enterText(find.byType(TextField), invitation.encode());
    await tester.pump();
    expect(find.textContaining('Fingerprint:'), findsOneWidget);
    expect(find.text('Confirm and trust'), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm and trust'));
    await tester.tap(find.text('Confirm and trust'));
    await tester.pump();
    expect(find.text('Trusted'), findsOneWidget);

    final event = ChatMessage(
      senderId: 2,
      receiverId: 1,
      text: 'trusted',
      createdAt: '2026-01-01T00:00:00.000Z',
    );
    final messageEvent = MessageEvent(
      eventId: 'dialog-event',
      messageId: event.messageKey,
      conversationId: '1:2',
      actorId: '2',
      deviceId: peer.deviceId,
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026),
      body: event.text,
    );
    expect(
      await trust
          .remoteAuthenticator(local: local)
          .verify(
            messageEvent.withSignature(
              await peer.sign(messageEvent.canonicalPayload),
            ),
          ),
      isTrue,
    );
  });
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
