import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/local_chat_repository.dart';
import 'package:taiwan_brawl/services/p2p_chat_service.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('P2P facade exposes manual negotiation bundle exchange', () async {
    final firstSignaling = ManualPeerSignaling();
    final secondSignaling = ManualPeerSignaling();
    final first = P2PChatService(
      selfId: 1,
      friendId: 2,
      signalingService: firstSignaling,
      localRepo: LocalChatRepository(),
      onMessage: (_) {},
    );
    final second = P2PChatService(
      selfId: 2,
      friendId: 1,
      signalingService: secondSignaling,
      localRepo: LocalChatRepository(),
      onMessage: (_) {},
    );
    final received = <Map<String, dynamic>>[];
    final subscription = secondSignaling.signalStream.listen(received.add);

    firstSignaling.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
    final bundle = first.exportNegotiationBundle(
      sessionId: 'session-1',
      senderDeviceId: 'device-1',
    );
    second.importNegotiationBundle(
      bundle,
      expectedSessionId: 'session-1',
      expectedSenderDeviceId: 'device-1',
    );
    await Future<void>.delayed(Duration.zero);

    expect(received, [
      {'type': 'offer', 'sdp': 'offer-sdp'},
    ]);

    await subscription.cancel();
    await first.dispose();
    await second.dispose();
    firstSignaling.dispose();
    secondSignaling.dispose();
  });

  test('hosted signaling rejects manual bundle APIs', () async {
    final service = P2PChatService(
      selfId: 1,
      friendId: 2,
      signalingService: _HostedLikeSignaling(),
      localRepo: LocalChatRepository(),
      onMessage: (_) {},
    );

    expect(
      () => service.exportNegotiationBundle(
        sessionId: 'session',
        senderDeviceId: 'device',
      ),
      throwsStateError,
    );
    expect(
      () => service.prepareManualNegotiation(isCaller: true),
      throwsStateError,
    );
    await service.dispose();
  });

  test('manual completion requires a prepared negotiation', () async {
    final service = P2PChatService(
      selfId: 1,
      friendId: 2,
      signalingService: ManualPeerSignaling(),
      localRepo: LocalChatRepository(),
      onMessage: (_) {},
    );

    expect(service.completeManualNegotiation(), throwsStateError);
    await service.dispose();
  });

  test('legacy facade accepts an injected P2P transport builder', () async {
    var factoryCalls = 0;
    final service = P2PChatService(
      selfId: 1,
      friendId: 2,
      signalingService: ManualPeerSignaling(),
      localRepo: LocalChatRepository(),
      onMessage: (_) {},
      transportFactory:
          ({
            required int friendId,
            required PeerSignalingChannel signalingService,
            required bool isCaller,
            required Map<String, dynamic> iceConfiguration,
          }) {
            factoryCalls++;
            return P2PMessageTransport(
              friendId: friendId,
              signalingService: signalingService,
              isCaller: isCaller,
              iceConfiguration: iceConfiguration,
              peerConnectionFactory: (_) async {
                throw StateError('test peer factory unavailable');
              },
            );
          },
    );

    await expectLater(service.startAsCaller(), throwsStateError);
    expect(factoryCalls, 1);
    await service.dispose();
  });
}

class _HostedLikeSignaling implements PeerSignalingChannel {
  @override
  Stream<Map<String, dynamic>> get signalStream => const Stream.empty();

  @override
  Future<void> connect(int peerId) async {}

  @override
  void send(int peerId, Map<String, dynamic> payload) {}

  @override
  void disconnect() {}

  @override
  void dispose() {}
}
