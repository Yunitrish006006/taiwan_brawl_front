import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl/services/signaling_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('manual signaling exchanges only negotiation payloads', () async {
    final first = ManualPeerSignaling();
    final second = ManualPeerSignaling();
    final received = <Map<String, dynamic>>[];
    final subscription = second.signalStream.listen(received.add);

    first.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
    second.acceptSignals(first.takeOutgoingSignals());
    await Future<void>.delayed(Duration.zero);

    expect(received, [
      {'type': 'offer', 'sdp': 'offer-sdp'},
    ]);
    expect(first.takeOutgoingSignals(), isEmpty);

    await subscription.cancel();
    first.dispose();
    second.dispose();
  });

  test('manual signaling import checks session and sender identity', () {
    final first = ManualPeerSignaling();
    first.send(2, {'type': 'offer', 'sdp': 'offer-sdp'});
    final bundle = first.exportBundle(
      sessionId: 'session-1',
      senderDeviceId: 'device-1',
    );

    expect(
      () => first.importBundle(bundle, expectedSessionId: 'other-session'),
      throwsFormatException,
    );
    expect(
      () => first.importBundle(bundle, expectedSenderDeviceId: 'other-device'),
      throwsFormatException,
    );
    first.dispose();
  });

  test(
    'uses the injected peer factory and cleans up factory failure',
    () async {
      var factoryCalls = 0;
      Map<String, dynamic>? capturedConfiguration;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final transport = P2PMessageTransport(
        friendId: 2,
        signalingService: SignalingService(api),
        iceConfiguration: const {'iceServers': <Object>[]},
        peerConnectionFactory: (configuration) async {
          factoryCalls++;
          capturedConfiguration = configuration;
          throw StateError('peer factory unavailable');
        },
      );

      await expectLater(transport.connect(), throwsStateError);
      expect(factoryCalls, 1);
      expect(capturedConfiguration, const {'iceServers': <Object>[]});
      expect(transport.isConnected, isFalse);
      await transport.dispose();
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
