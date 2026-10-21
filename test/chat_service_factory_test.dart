import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/chat_service_factory.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'composition factory supplies manual signaling to ChatService',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final service = ChatServiceFactory(
        apiClient: api,
        messagingCore: core,
        manualSignaling: ManualPeerSignaling(),
      ).create();

      expect(service.manualP2pEnabled, isTrue);
      await service.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'composition factory injects the manual P2P transport builder',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final transport = _NoopTransport();
      var factoryCalls = 0;
      final service = ChatServiceFactory(
        apiClient: api,
        messagingCore: core,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => transport,
        manualSignaling: ManualPeerSignaling(),
        manualTransportFactory:
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
      ).create();

      await service.connectToDm(1, 2);
      await expectLater(
        service.prepareManualP2p(isCaller: true),
        throwsStateError,
      );
      expect(factoryCalls, 1);

      await service.disposeAsync();
      await core.dispose();
    },
  );
}

class _NoopTransport implements MessageTransport {
  @override
  Stream<MessageEvent> get events => const Stream<MessageEvent>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(MessageEvent event) async {}
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
