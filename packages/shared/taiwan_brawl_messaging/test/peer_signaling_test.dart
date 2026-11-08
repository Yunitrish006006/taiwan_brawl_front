import 'dart:convert';

import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('manual signaling round-trips a negotiation bundle', () async {
    final first = ManualPeerSignaling();
    final second = ManualPeerSignaling();
    final received = <Map<String, dynamic>>[];
    final subscription = second.signalStream.listen(received.add);

    first.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
    final bundle = first.exportBundle(
      sessionId: 'session-1',
      senderDeviceId: 'device-1',
    );
    final decoded = PeerNegotiationBundle.decode(bundle);
    expect(decoded.sessionId, 'session-1');
    expect(decoded.senderDeviceId, 'device-1');

    second.importBundle(bundle);
    await Future<void>.delayed(Duration.zero);
    expect(received, [
      {'type': 'offer', 'sdp': 'offer-sdp'},
    ]);

    await subscription.cancel();
    first.dispose();
    second.dispose();
  });

  test('manual signaling coalesces repeated offer and ICE payloads', () {
    final signaling = ManualPeerSignaling();
    final offer = {'type': 'offer', 'sdp': 'same-offer'};
    final candidate = {
      'type': 'ice_candidate',
      'candidate': {'candidate': 'candidate-1', 'sdpMid': '0'},
    };
    signaling.send(2, offer);
    signaling.send(2, offer);
    signaling.send(2, candidate);
    signaling.send(2, candidate);

    final bundle = PeerNegotiationBundle.decode(
      signaling.exportBundle(
        sessionId: 'session-1',
        senderDeviceId: 'device-1',
      ),
    );
    expect(bundle.signals, [offer, candidate]);
    signaling.dispose();
  });

  test('manual signaling rejects a bundle from another session or device', () {
    final signaling = ManualPeerSignaling();
    signaling.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
    final bundle = signaling.exportBundle(
      sessionId: 'session-1',
      senderDeviceId: 'device-1',
    );

    expect(
      () => signaling.importBundle(bundle, expectedSessionId: 'session-2'),
      throwsFormatException,
    );
    expect(
      () => signaling.importBundle(bundle, expectedSenderDeviceId: 'device-2'),
      throwsFormatException,
    );
    signaling.dispose();
  });

  test(
    'signed manual bundles verify before accepting negotiation signals',
    () async {
      final sender = ManualPeerSignaling();
      final receiver = ManualPeerSignaling();
      final authenticator = _CanonicalPayloadAuthenticator();
      final received = <Map<String, dynamic>>[];
      final subscription = receiver.signalStream.listen(received.add);
      sender.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
      final signed = await sender.exportSignedBundle(
        sessionId: 'session-1',
        senderDeviceId: 'device-1',
        authenticator: authenticator,
      );

      final wrapper = jsonDecode(signed) as Map<String, dynamic>;
      final alteredBundle =
          jsonDecode(wrapper['bundle'] as String) as Map<String, dynamic>;
      alteredBundle['signals'] = [
        {'type': 'offer', 'sdp': 'tampered-sdp'},
      ];
      final tampered = jsonEncode({
        ...wrapper,
        'bundle': jsonEncode(alteredBundle),
      });

      await expectLater(
        receiver.importSignedBundle(tampered, authenticator: authenticator),
        throwsFormatException,
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);

      await receiver.importSignedBundle(signed, authenticator: authenticator);
      await Future<void>.delayed(Duration.zero);
      expect(received, [
        {'type': 'offer', 'sdp': 'offer-sdp'},
      ]);

      await subscription.cancel();
      sender.dispose();
      receiver.dispose();
    },
  );

  test('failed signing keeps queued signals available for a retry', () async {
    final signaling = ManualPeerSignaling();
    signaling.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
    await expectLater(
      signaling.exportSignedBundle(
        sessionId: 'session-1',
        senderDeviceId: 'device-1',
        authenticator: _CanonicalPayloadAuthenticator(failSigning: true),
      ),
      throwsStateError,
    );

    final retry = await signaling.exportSignedBundle(
      sessionId: 'session-1',
      senderDeviceId: 'device-1',
      authenticator: _CanonicalPayloadAuthenticator(),
    );
    final wrapper = jsonDecode(retry) as Map<String, dynamic>;
    final bundle = PeerNegotiationBundle.decode(wrapper['bundle'] as String);
    expect(bundle.signals, [
      {'type': 'offer', 'sdp': 'offer-sdp'},
    ]);
    signaling.dispose();
  });

  test('rejects message-shaped payloads', () {
    expect(
      () => PeerNegotiationBundle.validateSignal({
        'type': 'message',
        'body': 'must not cross signaling',
      }),
      throwsFormatException,
    );
    final sanitized = PeerNegotiationBundle.validateSignal({
      'type': 'offer',
      'sdp': 'offer-sdp',
      'body': 'must not cross signaling',
    });
    expect(sanitized, {'type': 'offer', 'sdp': 'offer-sdp'});
    expect(
      () => PeerNegotiationBundle.validateSignal({'type': 'answer', 'sdp': 42}),
      throwsFormatException,
    );
  });
}

class _CanonicalPayloadAuthenticator implements EventAuthenticator {
  _CanonicalPayloadAuthenticator({this.failSigning = false});

  final bool failSigning;

  @override
  Future<String> sign(MessageEvent event) async {
    if (failSigning) throw StateError('test signing failure');
    return base64UrlEncode(utf8.encode(event.canonicalPayload));
  }

  @override
  Future<bool> verify(MessageEvent event) async =>
      event.signature == base64UrlEncode(utf8.encode(event.canonicalPayload));
}
