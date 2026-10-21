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
