import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/models/chat_models.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/chat_service.dart';
import 'package:taiwan_brawl/services/legacy_chat_store.dart';
import 'package:taiwan_brawl/services/message_chat_projection.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test(
    'keeps a failed send in the shared outbox and flushes after reconnect',
    () async {
      final core = MessagingCoreService();
      final firstTransport = _FakeTransport(failSends: true);
      final secondTransport = _FakeTransport();
      var transportIndex = 0;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final chat = ChatService(
        api,
        messagingCore: core,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) {
              final transport = transportIndex++ == 0
                  ? firstTransport
                  : secondTransport;
              return transport;
            },
      );

      await chat.connectToDm(1, 2);
      await chat.sendMessage(2, 'offline-safe');

      expect(core.repository.pendingOutbox, hasLength(1));
      expect(core.conversation('1:2').single.visibleBody, 'offline-safe');
      expect(firstTransport.sent, isEmpty);

      await chat.connectToDm(1, 2);

      expect(core.repository.pendingOutbox, isEmpty);
      expect(secondTransport.sent.single.body, 'offline-safe');

      chat.dispose();
      await core.dispose();
    },
  );

  test(
    'syncs create, edit, recall, and read through a transport-neutral pair',
    () async {
      final leftCore = MessagingCoreService();
      final rightCore = MessagingCoreService();
      final (leftTransport, rightTransport) = InMemoryMessageTransport.pair();
      final leftApi = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final rightApi = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final left = ChatService(
        leftApi,
        messagingCore: leftCore,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => leftTransport,
      );
      final right = ChatService(
        rightApi,
        messagingCore: rightCore,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => rightTransport,
      );

      await right.connectToDm(2, 1);
      await left.connectToDm(1, 2);
      await left.sendMessage(2, 'shared create');
      await Future<void>.delayed(Duration.zero);

      final received = _projectedMessage(rightCore);
      expect(received.text, 'shared create');

      await left.editMessage(_projectedMessage(leftCore), 'shared edit');
      await Future<void>.delayed(Duration.zero);
      expect(_projectedMessage(rightCore).text, 'shared edit');

      await left.recallMessage(_projectedMessage(leftCore));
      await Future<void>.delayed(Duration.zero);
      expect(_projectedMessage(rightCore).text, recalledMessageText);

      await right.markMessageRead(received);
      await Future<void>.delayed(Duration.zero);
      final eventMessageId = rightCore.repository
          .projectionsFor('1:2')
          .single
          .messageId;
      expect(
        leftCore.repository.projectionFor(eventMessageId)?.readBy,
        contains('2'),
      );

      left.dispose();
      right.dispose();
      await leftCore.dispose();
      await rightCore.dispose();
    },
  );

  test(
    'returns an empty local history when the initial network read is offline',
    () async {
      var historyCalls = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          historyCalls++;
          throw http.ClientException('offline');
        }),
        credentials: _MemoryCredentials(),
      );
      final core = MessagingCoreService();
      final chat = ChatService(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatStore(),
      );

      expect(await chat.fetchHistory(1, 2), isEmpty);
      expect(historyCalls, 1);

      chat.dispose();
      await core.dispose();
    },
  );

  test('promotes legacy local history into shared event projections', () async {
    final legacyMessage = ChatMessage(
      senderId: 1,
      receiverId: 2,
      text: 'legacy history',
      createdAt: '2026-10-20T00:00:00.000Z',
    );
    final core = MessagingCoreService();
    final api = ApiClient(
      client: MockClient((_) async {
        throw StateError('server should not be queried');
      }),
      credentials: _MemoryCredentials(),
    );
    final transport = _FakeTransport(failSends: true);
    final chat = ChatService(
      api,
      messagingCore: core,
      localRepository: _MemoryLegacyChatStore([legacyMessage]),
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => transport,
    );

    final history = await chat.fetchHistory(1, 2);

    expect(history.single.text, 'legacy history');
    expect(
      core.repository.projectionsFor('1:2').single.visibleBody,
      'legacy history',
    );
    expect(core.repository.events.single.type, MessageEventType.created);

    await chat.connectToDm(1, 2);
    await chat.editMessage(history.single, 'migrated edit');
    await chat.recallMessage(_projectedMessage(core));
    expect(
      core.repository.projectionsFor('1:2').single.visibleBody,
      recalledMessageText,
    );

    chat.dispose();
    await core.dispose();
  });

  test(
    'merges legacy rows even when shared history already has newer events',
    () async {
      final legacyMessage = ChatMessage(
        senderId: 2,
        receiverId: 1,
        text: 'older legacy history',
        createdAt: '2026-10-19T00:00:00.000Z',
      );
      final core = MessagingCoreService();
      await core
          .commands(actorId: '1', conversationId: '1:2')
          .create(
            'newer shared history',
            messageId: 'shared-newer-message',
            eventId: 'shared-newer-event',
            createdAt: DateTime.utc(2026, 10, 20),
          );
      final api = ApiClient(
        client: MockClient((_) async {
          throw StateError('server should not be queried');
        }),
        credentials: _MemoryCredentials(),
      );
      final chat = ChatService(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatStore([legacyMessage]),
      );

      final history = await chat.fetchHistory(1, 2);

      expect(
        history.map((message) => message.text),
        containsAll(<String>['older legacy history', 'newer shared history']),
      );
      expect(core.repository.projectionsFor('1:2'), hasLength(2));

      chat.dispose();
      await core.dispose();
    },
  );

  test(
    'does not use legacy HTTP when the shared transport is disconnected',
    () async {
      final core = MessagingCoreService();
      var legacyCalls = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          legacyCalls++;
          return http.Response('{}', 200);
        }),
        credentials: _MemoryCredentials(),
      );
      final chat = ChatService(
        api,
        messagingCore: core,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => _FakeTransport(),
      );

      await chat.connectToDm(1, 2);
      await chat.disconnectAsync();
      await chat.sendMessage(2, 'stay-local');

      expect(legacyCalls, 0);
      expect(core.repository.pendingOutbox, hasLength(1));
      expect(core.conversation('1:2').single.visibleBody, 'stay-local');

      chat.dispose();
      await core.dispose();
    },
  );

  test(
    'refresh returns the local projection when the network is offline',
    () async {
      final core = MessagingCoreService();
      await core
          .commands(actorId: '1', conversationId: '1:2')
          .create('already saved', messageId: 'saved-message');
      final api = ApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
        credentials: _MemoryCredentials(),
      );
      final chat = ChatService(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatStore(),
      );

      final history = await chat.syncFromServer(1, 2);

      expect(history.single.text, 'already saved');
      chat.dispose();
      await core.dispose();
    },
  );

  test('keeps a disconnected recall in the shared outbox', () async {
    final core = MessagingCoreService();
    var legacyCalls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        legacyCalls++;
        return http.Response('{}', 200);
      }),
      credentials: _MemoryCredentials(),
    );
    final chat = ChatService(
      api,
      messagingCore: core,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => _FakeTransport(),
    );

    await chat.connectToDm(1, 2);
    await chat.sendMessage(2, 'recall-later');
    final message = _projectedMessage(core);
    await chat.disconnectAsync();
    await chat.recallMessage(message);

    expect(legacyCalls, 0);
    expect(core.repository.pendingOutbox, hasLength(1));
    expect(core.conversation('1:2').single.visibleBody, recalledMessageText);

    chat.dispose();
    await core.dispose();
  });

  test('keeps create, edit, and recall events locally while offline', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport(failSends: true);
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = ChatService(
      api,
      messagingCore: core,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => transport,
    );

    await chat.connectToDm(1, 2);
    await chat.sendMessage(2, 'original');
    final firstMessage = _projectedMessage(core);

    await chat.editMessage(firstMessage, 'edited');
    final editedMessage = _projectedMessage(core);
    await chat.recallMessage(editedMessage);

    expect(core.repository.pendingOutbox, hasLength(3));
    expect(core.conversation('1:2').single.visibleBody, recalledMessageText);

    chat.dispose();
    await core.dispose();
  });

  test('serializes transport cleanup before reconnecting', () async {
    final core = MessagingCoreService();
    final first = _LifecycleTransport(waitOnDisconnect: true);
    final second = _LifecycleTransport();
    var index = 0;
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = ChatService(
      api,
      messagingCore: core,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => index++ == 0 ? first : second,
    );

    await chat.connectToDm(1, 2);
    final reconnect = chat.connectToDm(1, 2);
    await Future<void>.delayed(Duration.zero);

    expect(first.disconnectStarted, isTrue);
    expect(second.connectCalled, isFalse);

    first.releaseDisconnect();
    await reconnect;

    expect(second.connectCalled, isTrue);
    chat.dispose();
    await core.dispose();
  });

  test(
    'emits the edited or recalled message instead of the conversation tail',
    () async {
      final core = MessagingCoreService();
      final transport = _FakeTransport(failSends: true);
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final chat = ChatService(
        api,
        messagingCore: core,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => transport,
      );
      final updates = <ChatMessage>[];
      final subscription = chat.messageStream.listen(updates.add);

      await chat.connectToDm(1, 2);
      await chat.sendMessage(2, 'first');
      final first = _projectedMessages(core).first;
      await chat.sendMessage(2, 'second');
      await chat.editMessage(first, 'first edited');

      expect(updates.last.text, 'first edited');
      await chat.recallMessage(updates.last);
      expect(updates.last.text, recalledMessageText);
      expect(updates.last.isRecalled, isTrue);

      await subscription.cancel();
      chat.dispose();
      await core.dispose();
    },
  );

  test(
    'exposes validated manual P2P bundles through the shared chat service',
    () async {
      final signaling = ManualPeerSignaling();
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final chat = ChatService(
        api,
        messagingCore: core,
        manualSignaling: signaling,
      );

      expect(chat.manualP2pEnabled, isTrue);
      final bundle = chat.exportManualP2pBundle(
        sessionId: 'dm:1:2',
        senderDeviceId: 'device-1',
      );
      expect(PeerNegotiationBundle.decode(bundle).sessionId, 'dm:1:2');
      chat.importManualP2pBundle(bundle, expectedSessionId: 'dm:1:2');

      chat.dispose();
      signaling.dispose();
      await core.dispose();
    },
  );

  test('passes the event authenticator to live remote ingestion', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport();
    final authenticator = _RejectingAuthenticator();
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = ChatService(
      api,
      messagingCore: core,
      remoteAuthenticator: authenticator,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => transport,
    );

    await chat.connectToDm(1, 2);
    transport.eventsController.add(
      MessageEvent(
        eventId: 'remote-event',
        messageId: 'remote-message',
        conversationId: '1:2',
        actorId: '2',
        deviceId: 'peer-device',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.now().toUtc(),
        body: 'must-be-verified',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(authenticator.verifyCalls, 1);
    expect(core.conversation('1:2'), isEmpty);

    chat.dispose();
    await core.dispose();
  });

  test('keeps an offline read event in the shared outbox', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport(failSends: true);
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = ChatService(
      api,
      messagingCore: core,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => transport,
    );

    await chat.connectToDm(1, 2);
    transport.eventsController.add(
      MessageEvent(
        eventId: 'remote-created-event',
        messageId: 'remote-message',
        conversationId: '1:2',
        actorId: '2',
        deviceId: 'peer-device',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        body: 'incoming',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final incoming = _projectedMessage(core);
    await chat.markMessageRead(incoming);

    final projection = core.repository.projectionFor('remote-message');
    expect(projection?.readBy, contains('1'));
    expect(core.repository.pendingOutbox.single.type, MessageEventType.read);

    chat.dispose();
    await core.dispose();
  });

  test('does not use the local signer as an implicit peer verifier', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport();
    final signer = _RejectingAuthenticator();
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = ChatService(
      api,
      messagingCore: core,
      authenticator: signer,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => transport,
    );

    await chat.connectToDm(1, 2);
    transport.eventsController.add(
      MessageEvent(
        eventId: 'unverified-peer-event',
        messageId: 'unverified-peer-message',
        conversationId: '1:2',
        actorId: '2',
        deviceId: 'peer-device',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.now().toUtc(),
        body: 'accepted-until-peer-directory-exists',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(signer.verifyCalls, 0);
    expect(
      core.conversation('1:2').single.visibleBody,
      'accepted-until-peer-directory-exists',
    );

    chat.dispose();
    await core.dispose();
  });
}

ChatMessage _projectedMessage(MessagingCoreService core) {
  return _projectedMessages(core).single;
}

List<ChatMessage> _projectedMessages(MessagingCoreService core) {
  return MessageChatProjection.toMessages(
    projections: core.conversation('1:2'),
    selfId: 1,
    friendId: 2,
    pendingMessageIds: core.repository.pendingOutbox.map(
      (event) => event.messageId,
    ),
  );
}

class _FakeTransport implements MessageTransport {
  _FakeTransport({this.failSends = false});

  final bool failSends;
  final eventsController = StreamController<MessageEvent>.broadcast();
  final sent = <MessageEvent>[];

  @override
  Stream<MessageEvent> get events => eventsController.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> send(MessageEvent event) async {
    if (failSends) throw StateError('offline');
    sent.add(event);
  }

  @override
  Future<void> disconnect() async {
    await eventsController.close();
  }
}

class _LifecycleTransport implements MessageTransport {
  _LifecycleTransport({this.waitOnDisconnect = false});

  final bool waitOnDisconnect;
  final eventsController = StreamController<MessageEvent>.broadcast();
  final disconnectRelease = Completer<void>();
  bool disconnectStarted = false;
  bool connectCalled = false;

  @override
  Stream<MessageEvent> get events => eventsController.stream;

  @override
  Future<void> connect() async => connectCalled = true;

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> disconnect() async {
    disconnectStarted = true;
    if (waitOnDisconnect) await disconnectRelease.future;
    await eventsController.close();
  }

  void releaseDisconnect() {
    if (!disconnectRelease.isCompleted) disconnectRelease.complete();
  }
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

class _RejectingAuthenticator implements EventAuthenticator {
  var verifyCalls = 0;

  @override
  Future<String> sign(MessageEvent event) async => 'unused';

  @override
  Future<bool> verify(MessageEvent event) async {
    verifyCalls++;
    return false;
  }
}

class _MemoryLegacyChatStore implements LegacyChatStore {
  _MemoryLegacyChatStore([Iterable<ChatMessage> initial = const []])
    : messages = List.of(initial);

  final List<ChatMessage> messages;

  @override
  Future<void> saveMessage(int selfId, ChatMessage message) async {
    messages.add(message);
  }

  @override
  Future<void> markDelivered(
    int selfId,
    int friendId,
    String createdAt,
    int senderId,
  ) async {}

  @override
  Future<void> markRecalled(
    int selfId,
    int friendId,
    String messageKey,
  ) async {}

  @override
  Future<void> updateMessageText(
    int selfId,
    int friendId,
    String messageKey,
    String text,
  ) async {}

  @override
  Future<List<ChatMessage>> getMessages(int selfId, int friendId) async =>
      List.of(messages);

  @override
  Future<ChatMessage?> getMessage(
    int selfId,
    int friendId,
    String messageKey,
  ) async => null;

  @override
  Future<void> deleteMessage(
    int selfId,
    int friendId,
    String createdAt,
    int senderId,
  ) async {}

  @override
  Future<void> clearMessages(int selfId, int friendId) async {}

  @override
  Future<Map<String, Map<String, String>>> exportAll(
    int selfId,
    List<int> friendIds,
  ) async => {};

  @override
  Future<void> importAll(Map<String, dynamic> data) async {}

  @override
  Future<void> closeAll() async {}
}
