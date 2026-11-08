import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl/constants/locale_catalog.dart';
import 'package:taiwan_brawl/services/locale_provider.dart';
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
    final identities = await tester.runAsync(
      () async => (
        await SecureDeviceIdentity.restore(credentials: localCredentials),
        await SecureDeviceIdentity.restore(credentials: peerCredentials),
      ),
    );
    expect(identities, isNotNull);
    final local = identities!.$1;
    final peer = identities.$2;
    final trust = PeerTrustService(credentials: localCredentials);
    final invitation = trust.createInvitation(peer);
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: translationForLocale,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: locale,
        child: MaterialApp(
          home: Scaffold(
            body: PeerTrustDialog(trustService: trust, localIdentity: local),
          ),
        ),
      ),
    );

    expect(find.text('Your Ed25519 public-key invitation'), findsOneWidget);
    expect(find.text('Contains no private signing key.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('peer-trust-invitation')),
      invitation.encode(),
    );
    await tester.pump();
    expect(find.textContaining('Fingerprint:'), findsOneWidget);
    expect(find.text('Ed25519 public key'), findsOneWidget);
    expect(find.text('Confirm and trust'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm and trust');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    final confirmationField = find.byKey(
      const ValueKey('peer-fingerprint-confirmation'),
    );
    await tester.enterText(confirmationField, 'not-the-fingerprint');
    await tester.pump();
    expect(
      find.text('This fingerprint does not match the invitation.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    final fingerprint = PeerTrustInvitation.decode(
      invitation.encode(),
    ).fingerprint;
    await tester.enterText(confirmationField, fingerprint);
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(find.text('Trusted'), findsOneWidget);

    final messageEvent = MessageEvent(
      eventId: 'dialog-event',
      messageId: '2026-01-01T00:00:00.000Z_2',
      conversationId: '1:2',
      actorId: '2',
      deviceId: peer.deviceId,
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026),
      body: 'trusted',
    );
    final verified = await tester.runAsync(() async {
      final signature = await peer.sign(messageEvent.canonicalPayload);
      return trust
          .remoteAuthenticator(local: local)
          .verify(messageEvent.withSignature(signature));
    });
    expect(verified, isTrue);
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
