import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/messaging_transport_factory.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/fallback_message_transport.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl/services/server_message_transport.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'P2P defaults to primary and the server relay remains fallback',
    () async {
      final factory = MessagingTransportFactory(_apiClient());

      final transport = factory.create(selfId: 1, friendId: 2, isCaller: true);
      expect(transport, isA<FallbackMessageTransport>());
      final selected = transport as FallbackMessageTransport;
      expect(selected.primary, isA<P2PMessageTransport>());
      expect(selected.fallback, isA<ServerMessageTransport>());
      await selected.dispose();
    },
  );

  test(
    'injects the conversation-scoped durable cursor store into relay',
    () async {
      final cursorStore = _MemoryCursorStore();
      var requestedSelfId = 0;
      var requestedFriendId = 0;
      final factory = MessagingTransportFactory(
        _apiClient(),
        syncCursorStoreFactory: ({required selfId, required friendId}) {
          requestedSelfId = selfId;
          requestedFriendId = friendId;
          return cursorStore;
        },
      );

      final transport =
          factory.create(selfId: 2, friendId: 9, isCaller: false)
              as FallbackMessageTransport;
      final relay = transport.fallback as ServerMessageTransport;

      expect(requestedSelfId, 2);
      expect(requestedFriendId, 9);
      expect(relay.syncCursorStore, same(cursorStore));
      await transport.dispose();
    },
  );

  test('disabled P2P selects the server transport only', () async {
    final transport = MessagingTransportFactory(
      _apiClient(),
      p2pEnabled: false,
    ).create(selfId: 1, friendId: 2, isCaller: true);

    expect(transport, isA<ServerMessageTransport>());
    await transport.disconnect();
  });

  test('selects one deterministic caller for a peer pair', () {
    expect(MessagingTransportFactory.isCaller(selfId: 1, friendId: 2), isTrue);
    expect(MessagingTransportFactory.isCaller(selfId: 2, friendId: 1), isFalse);
    expect(MessagingTransportFactory.isCaller(selfId: 7, friendId: 7), isFalse);
  });
}

class _MemoryCursorStore implements MessageSyncCursorStore {
  @override
  Future<String?> loadSyncCursor(String scope) async => null;

  @override
  Future<void> saveSyncCursor(String scope, String cursor) async {}
}

ApiClient _apiClient() => ApiClient(
  client: MockClient((_) async => throw StateError('unexpected HTTP request')),
  configuration: const AppConfiguration(
    apiBaseUrl: 'https://example.test',
    googleWebClientId: 'test-web-client',
    googleServerClientId: 'test-server-client',
    p2pChatEnabled: true,
  ),
);
