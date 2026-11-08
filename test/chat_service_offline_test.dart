import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/models/direct_message.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';
import 'package:taiwan_brawl/models/message_history_page.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/chat_service.dart';
import 'package:taiwan_brawl/services/legacy_chat_remote_source.dart';
import 'package:taiwan_brawl/services/legacy_chat_delivery_adapter.dart';
import 'package:taiwan_brawl/services/legacy_chat_history_adapter.dart';
import 'package:taiwan_brawl/services/legacy_chat_store.dart';
import 'package:taiwan_brawl/services/legacy_chat_sync_snapshot_adapter.dart';
import 'package:taiwan_brawl/services/message_chat_sync_adapter.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl/services/remote_source_exception.dart';
import 'package:taiwan_brawl/services/server_message_transport.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('routes legacy snapshot upload through shared projections', () async {
    final core = MessagingCoreService();
    final remote = _MemoryLegacyChatRemoteSource();
    final chat = _createChat(
      ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      ),
      messagingCore: core,
      remoteSource: remote,
    );
    await core
        .commands(actorId: '1', conversationId: '1:2')
        .create('snapshot body', messageId: 'snapshot-message');

    await chat.uploadSyncData(1, 2);

    expect(remote.uploadedFriendId, 2);
    expect(
      remote.uploadedData,
      MessageChatSyncAdapter.exportProjections(
        core.conversation('1:2'),
        1,
        2,
        pendingMessageIds: core.repository.pendingOutbox
            .where((event) => event.type == MessageEventType.created)
            .map((event) => event.messageId),
      ),
    );
    await chat.disposeAsync();
    await core.dispose();
  });

  test(
    'imports snapshots into both the compatibility store and event core',
    () async {
      final core = MessagingCoreService();
      final store = _MemoryLegacyChatPorts();
      final remote = _MemoryLegacyChatRemoteSource()
        ..downloadedData = {
          'chat_1_2': {
            '2026-01-01T00:00:00.000Z_1': jsonEncode({
              'senderId': 1,
              'receiverId': 2,
              'text': 'restored snapshot',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'isPending': false,
              'isRecalled': false,
              'pendingId': null,
            }),
          },
        };
      final chat = _createChat(
        ApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          credentials: _MemoryCredentials(),
        ),
        messagingCore: core,
        localRepository: store,
        remoteSource: remote,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _FakeTransport(),
      );
      await chat.connectToDm(2, 1);

      await chat.downloadAndMergeSyncData(1);

      expect(store.importedData, remote.downloadedData);
      expect(remote.acknowledgedSnapshotIds, ['snapshot-1']);
      expect(core.conversation('1:2').single.visibleBody, 'restored snapshot');
      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'reports a conflicting snapshot event and skips raw snapshot import',
    () async {
      final core = MessagingCoreService();
      const firstMessageKey = '2026-01-01T00:00:00.000Z_1';
      const conflictingMessageKey = '2026-01-02T00:00:00.000Z_1';
      await core.acceptRemote(
        MessageEvent(
          eventId: 'sync-created:$conflictingMessageKey',
          messageId: conflictingMessageKey,
          conversationId: '1:2',
          actorId: '1',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 1, 2),
          body: 'local event body',
        ),
      );
      final store = _MemoryLegacyChatPorts();
      final remote = _MemoryLegacyChatRemoteSource()
        ..downloadedData = {
          'chat_1_2': {
            firstMessageKey: jsonEncode({
              'senderId': 1,
              'receiverId': 2,
              'text': 'earlier valid snapshot row',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'isPending': false,
              'isRecalled': false,
              'pendingId': null,
            }),
            conflictingMessageKey: jsonEncode({
              'senderId': 1,
              'receiverId': 2,
              'text': 'different snapshot body',
              'createdAt': '2026-01-02T00:00:00.000Z',
              'isPending': false,
              'isRecalled': false,
              'pendingId': null,
            }),
          },
        };
      final chat = _createChat(
        ApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          credentials: _MemoryCredentials(),
        ),
        messagingCore: core,
        localRepository: store,
        remoteSource: remote,
      );
      await chat.connectToDm(2, 1);

      await expectLater(
        chat.downloadAndMergeSyncData(1),
        throwsA(isA<StateError>()),
      );

      expect(core.repository.conflicts, hasLength(1));
      expect(store.importedData, isEmpty);
      expect(remote.acknowledgedSnapshotIds, isEmpty);
      expect(core.conversation('1:2').single.visibleBody, 'local event body');
      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'rejects a malformed snapshot before merging valid sibling rows',
    () async {
      final core = MessagingCoreService();
      final store = _MemoryLegacyChatPorts();
      final remote = _MemoryLegacyChatRemoteSource()
        ..downloadedData = {
          'chat_1_2': {
            '2026-01-01T00:00:00.000Z_1': jsonEncode({
              'senderId': 1,
              'receiverId': 2,
              'text': 'valid row before invalid row',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'isPending': false,
              'isRecalled': false,
              'pendingId': null,
            }),
            'broken-row': 42,
          },
        };
      final chat = _createChat(
        ApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          credentials: _MemoryCredentials(),
        ),
        messagingCore: core,
        localRepository: store,
        remoteSource: remote,
      );
      await chat.connectToDm(1, 2);

      await expectLater(
        chat.downloadAndMergeSyncData(2),
        throwsA(isA<FormatException>()),
      );

      expect(core.conversation('1:2'), isEmpty);
      expect(store.importedData, isEmpty);
      expect(remote.acknowledgedSnapshotIds, isEmpty);
      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'uses the legacy delivery adapter when event sending is unsupported',
    () async {
      final core = MessagingCoreService();
      final remote = _MemoryLegacyChatRemoteSource();
      final chat = _createChat(
        ApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          credentials: _MemoryCredentials(),
        ),
        messagingCore: core,
        remoteSource: remote,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _LegacyCreateFallbackTransport(),
      );
      await chat.connectToDm(1, 2);

      await chat.sendText(2, 'legacy endpoint fallback');

      expect(remote.sentTexts, ['legacy endpoint fallback']);
      expect(core.repository.pendingOutbox, isEmpty);
      expect(
        core.conversation('1:2').single.visibleBody,
        'legacy endpoint fallback',
      );
      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'production legacy adapter does not fall back to plaintext delivery',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
        credentials: _MemoryCredentials(),
      );
      final core = MessagingCoreService();
      final chat = _createChat(
        api,
        messagingCore: core,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _LegacyCreateFallbackTransport(),
      );
      await chat.connectToDm(1, 2);

      await expectLater(chat.sendText(2, 'must stay local'), throwsStateError);

      expect(
        requests.where((request) => request.url.path.endsWith('/send')),
        isEmpty,
      );
      expect(core.repository.pendingOutbox, hasLength(1));
      expect(core.conversation('1:2').single.visibleBody, 'must stay local');
      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'direct-message port reads and commands the shared projection',
    () async {
      final core = MessagingCoreService();
      final transport = _FakeTransport();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final chat = _createChat(
        api,
        messagingCore: core,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                transport,
      );
      final updates = <DirectMessage>[];
      final subscription = chat.directMessageStream.listen(updates.add);

      await chat.connectToDm(1, 2);
      await chat.sendText(2, 'projection-backed');
      var messages = await chat.loadConversation(1, 2);
      final created = messages.single;
      expect(created.text, 'projection-backed');
      expect(created.authorId, '1');
      expect(created.revision, 0);
      expect(created.isPending, isFalse);

      await chat.editProjectedMessage(created.id, 'edited from projection');
      expect(updates.last.text, 'edited from projection');
      expect(updates.last.revision, 1);

      await chat.recallProjectedMessage(created.id);
      expect(updates.last.isRecalled, isTrue);
      expect(updates.last.revision, 2);

      final incoming = await core
          .commands(actorId: '2', conversationId: '1:2')
          .create('incoming', messageId: 'incoming-event-message');
      messages = await chat.loadConversation(1, 2);
      final incomingMessage = messages.singleWhere(
        (message) => message.id == incoming.messageId,
      );
      await chat.markProjectedMessageRead(incomingMessage.id);
      expect(
        core.repository.projectionFor(incomingMessage.id)!.readBy,
        contains('1'),
      );
      expect(
        updates.any((message) => message.id == incomingMessage.id),
        isTrue,
      );

      await subscription.cancel();
      await chat.disposeAsync();
      await core.dispose();
    },
  );

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
      final chat = _createChat(
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
      await expectLater(
        chat.sendText(2, 'offline-safe'),
        throwsA(isA<StateError>()),
      );

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

  test('retries a failed send using its existing outbox event', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport(failSends: true);
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = _createChat(
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
    await expectLater(chat.sendText(2, 'one copy'), throwsStateError);
    final originalEventId = core.repository.pendingOutbox.single.eventId;

    transport.failSends = false;
    await chat.retryPendingMessage(2, 'one copy');

    expect(core.repository.pendingOutbox, isEmpty);
    expect(
      core.repository.events.where(
        (event) => event.type == MessageEventType.created,
      ),
      hasLength(1),
    );
    expect(transport.sent.single.eventId, originalEventId);

    chat.dispose();
    await core.dispose();
  });

  test(
    'retries a pending event after transport recovers without re-entry',
    () async {
      final core = MessagingCoreService();
      final transport = _FakeTransport(failSends: true);
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final chat = _createChat(
        api,
        messagingCore: core,
        outboxRetryInterval: const Duration(milliseconds: 10),
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => transport,
      );

      await chat.connectToDm(1, 2);
      await expectLater(
        chat.sendText(2, 'retry automatically'),
        throwsStateError,
      );
      transport.failSends = false;
      for (
        var attempt = 0;
        attempt < 100 && core.repository.pendingOutbox.isNotEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(core.repository.pendingOutbox, isEmpty);
      expect(transport.sent.map((event) => event.body), [
        'retry automatically',
      ]);

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
      final left = _createChat(
        leftApi,
        messagingCore: leftCore,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => leftTransport,
      );
      final right = _createChat(
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
      await left.sendText(2, 'shared create');
      await Future<void>.delayed(Duration.zero);

      final received = (await right.loadConversation(2, 1)).single;
      expect(received.text, 'shared create');

      final sentMessage = (await left.loadConversation(1, 2)).single;
      await left.editProjectedMessage(sentMessage.id, 'shared edit');
      await Future<void>.delayed(Duration.zero);
      expect(_projectedMessage(rightCore).text, 'shared edit');

      await left.recallProjectedMessage(sentMessage.id);
      await Future<void>.delayed(Duration.zero);
      expect(_projectedMessage(rightCore).text, recalledMessageText);

      await right.markProjectedMessageRead(received.id);
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
      final chat = _createChat(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatPorts(),
      );

      expect(await chat.loadConversation(1, 2), isEmpty);
      expect(historyCalls, 1);

      chat.dispose();
      await core.dispose();
    },
  );

  test(
    'promotes server history directly from frontend-owned records',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/history')) {
            return http.Response(
              jsonEncode({
                'messages': [
                  {
                    'senderId': 2,
                    'receiverId': 1,
                    'text': 'server legacy history',
                    'createdAt': '2026-10-28T00:00:00.000Z',
                  },
                ],
              }),
              200,
            );
          }
          throw StateError('unexpected request ${request.url}');
        }),
        credentials: _MemoryCredentials(),
      );
      final chat = _createChat(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatPorts(),
      );

      final history = await chat.loadConversation(1, 2);

      expect(history.single.text, 'server legacy history');
      expect(
        core.repository
            .projectionFor('2026-10-28T00:00:00.000Z_2')
            ?.visibleBody,
        'server legacy history',
      );

      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test('promotes legacy local history into shared event projections', () async {
    final legacyMessage = LegacyChatRecord(
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
    final legacyStore = _MemoryLegacyChatPorts([legacyMessage]);
    final chat = _createChat(
      api,
      messagingCore: core,
      localRepository: legacyStore,
      transportFactory:
          ({
            required int selfId,
            required int friendId,
            required bool isCaller,
          }) => transport,
    );

    final history = await chat.loadConversation(1, 2);

    expect(history.single.text, 'legacy history');
    expect(
      core.repository.projectionsFor('1:2').single.visibleBody,
      'legacy history',
    );
    expect(core.repository.events.single.type, MessageEventType.created);
    expect(legacyStore.getMessagesCallCount, 1);
    expect(await legacyStore.migratedEventMessageIds(1, 2), {
      legacyMessage.messageKey,
    });
    expect((await chat.loadConversation(1, 2)).single.text, 'legacy history');
    expect(legacyStore.getMessagesCallCount, 1);

    await chat.connectToDm(1, 2);
    await expectLater(
      chat.editProjectedMessage(history.single.id, 'migrated edit'),
      throwsStateError,
    );
    await expectLater(
      chat.recallProjectedMessage(history.single.id),
      throwsStateError,
    );
    expect(
      core.repository.projectionsFor('1:2').single.visibleBody,
      recalledMessageText,
    );

    chat.dispose();
    await core.dispose();
  });

  test(
    'promotes readable legacy rows without marking unreadable siblings complete',
    () async {
      final validMessage = LegacyChatRecord(
        senderId: 1,
        receiverId: 2,
        text: 'readable legacy message',
        createdAt: '2026-10-20T00:00:00.000Z',
      );
      final legacyStore = _MemoryLegacyChatPorts([validMessage])
        ..invalidRowKeys.add('corrupt-row-key');
      final core = MessagingCoreService();
      final chat = _createChat(
        ApiClient(
          client: MockClient((_) async {
            throw StateError('server should not be queried');
          }),
          credentials: _MemoryCredentials(),
        ),
        messagingCore: core,
        localRepository: legacyStore,
      );

      final history = await chat.loadConversation(1, 2);

      expect(history.map((message) => message.text), [
        'readable legacy message',
      ]);
      expect(
        core.repository.projectionFor(validMessage.messageKey)?.visibleBody,
        'readable legacy message',
      );
      expect(legacyStore.migratedEventMessageIds(1, 2), completion(isNull));

      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'loads requested history pages before and after local migration',
    () async {
      final localMessage = LegacyChatRecord(
        senderId: 1,
        receiverId: 2,
        text: 'already migrated local message',
        createdAt: '2026-10-21T00:00:00.000Z',
      );
      final olderRemoteMessage = LegacyChatRecord(
        senderId: 2,
        receiverId: 1,
        text: 'older paged server message',
        createdAt: '2026-10-20T00:00:00.000Z',
      );
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final nextCursor = MessageHistoryCursor(
        createdAt: olderRemoteMessage.createdAt,
        rowId: 40,
      );
      final remote = _MemoryLegacyChatRemoteSource(
        history: [olderRemoteMessage],
        hasMore: true,
        nextCursor: nextCursor,
      );
      final chat = _createChat(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatPorts([localMessage]),
        remoteSource: remote,
      );

      const cursor = MessageHistoryCursor(
        createdAt: '2026-10-21T00:00:00.000Z',
        rowId: 50,
      );
      final history = await chat.loadConversation(1, 2, before: cursor);

      expect(remote.requestedHistoryCursors, [cursor]);
      expect(
        history.map((message) => message.text),
        containsAll([
          'already migrated local message',
          'older paged server message',
        ]),
      );
      await chat.loadConversation(1, 2, before: nextCursor);
      expect(remote.requestedHistoryCursors, [cursor, nextCursor]);

      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test('replays legacy rows when a recorded projection is missing', () async {
    final legacyMessage = LegacyChatRecord(
      senderId: 1,
      receiverId: 2,
      text: 'recover after event-store loss',
      createdAt: '2026-10-21T00:00:00.000Z',
    );
    final legacyStore = _MemoryLegacyChatPorts([legacyMessage]);
    final snapshot = await legacyStore.getHistorySnapshot(1, 2);
    await legacyStore.markEventMessagesMigrated(1, 2, {
      legacyMessage.messageKey,
    }, expectedSourceRevision: snapshot.sourceRevision);
    legacyStore.getMessagesCallCount = 0;
    final core = MessagingCoreService();
    final api = ApiClient(
      client: MockClient((_) async {
        throw StateError('server should not be queried');
      }),
      credentials: _MemoryCredentials(),
    );
    final chat = _createChat(
      api,
      messagingCore: core,
      localRepository: legacyStore,
    );

    expect((await chat.loadConversation(1, 2)).single.text, legacyMessage.text);
    expect(
      core.repository.projectionFor(legacyMessage.messageKey)?.visibleBody,
      legacyMessage.text,
    );
    expect(legacyStore.getMessagesCallCount, 1);

    await chat.disposeAsync();
    await core.dispose();
  });

  test('does not mark a changed legacy payload as fully migrated', () async {
    final legacyMessage = LegacyChatRecord(
      senderId: 1,
      receiverId: 2,
      text: 'changed legacy body',
      createdAt: '2026-10-21T00:00:00.000Z',
    );
    final legacyStore = _MemoryLegacyChatPorts([legacyMessage]);
    final core = MessagingCoreService();
    await core.repository.acceptRemote(
      MessageEvent(
        eventId: 'legacy-created:${legacyMessage.messageKey}',
        messageId: legacyMessage.messageKey,
        conversationId: '1:2',
        actorId: '1',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.parse(legacyMessage.createdAt).toUtc(),
        body: 'original legacy body',
      ),
    );
    final api = ApiClient(
      client: MockClient((_) async {
        throw StateError('server should not be queried');
      }),
      credentials: _MemoryCredentials(),
    );
    final chat = _createChat(
      api,
      messagingCore: core,
      localRepository: legacyStore,
    );

    final messages = await chat.loadConversation(1, 2);

    expect(messages.single.text, 'original legacy body');
    expect(legacyStore.migratedEventMessageIds(1, 2), completion(isNull));
    expect(
      core.repository.conflicts.single.messageId,
      legacyMessage.messageKey,
    );
    expect(
      core.repository.conflicts.single.reason,
      contains('different payload'),
    );

    await chat.disposeAsync();
    await core.dispose();
  });

  test(
    'legacy history conflict does not partially project valid sibling rows',
    () async {
      final validLegacyMessage = LegacyChatRecord(
        senderId: 1,
        receiverId: 2,
        text: 'valid sibling row',
        createdAt: '2026-10-20T00:00:00.000Z',
      );
      final conflictingLegacyMessage = LegacyChatRecord(
        senderId: 1,
        receiverId: 2,
        text: 'changed legacy body',
        createdAt: '2026-10-21T00:00:00.000Z',
      );
      final legacyStore = _MemoryLegacyChatPorts([
        validLegacyMessage,
        conflictingLegacyMessage,
      ]);
      final core = MessagingCoreService();
      await core.repository.acceptRemote(
        MessageEvent(
          eventId: 'legacy-created:${conflictingLegacyMessage.messageKey}',
          messageId: conflictingLegacyMessage.messageKey,
          conversationId: '1:2',
          actorId: '1',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.parse(conflictingLegacyMessage.createdAt).toUtc(),
          body: 'original legacy body',
        ),
      );
      final chat = _createChat(
        ApiClient(
          client: MockClient((_) async {
            throw StateError('server should not be queried');
          }),
          credentials: _MemoryCredentials(),
        ),
        messagingCore: core,
        localRepository: legacyStore,
      );

      final messages = await chat.loadConversation(1, 2);

      expect(messages.map((message) => message.id), [
        conflictingLegacyMessage.messageKey,
      ]);
      expect(
        core.repository.projectionFor(validLegacyMessage.messageKey),
        isNull,
      );
      expect(legacyStore.migratedEventMessageIds(1, 2), completion(isNull));
      expect(core.repository.conflicts, hasLength(1));

      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'legacy history migration recovers a durable batch after partial commit',
    () async {
      final first = LegacyChatRecord(
        senderId: 1,
        receiverId: 2,
        text: 'first recovered row',
        createdAt: '2026-10-20T00:00:00.000Z',
      );
      final second = LegacyChatRecord(
        senderId: 1,
        receiverId: 2,
        text: 'second recovered row',
        createdAt: '2026-10-21T00:00:00.000Z',
      );
      final legacyStore = _MemoryLegacyChatPorts([first, second]);
      final eventStore = _CrashRecoveringMessageStore(
        failEventId: 'legacy-created:${second.messageKey}',
      );
      final firstCore = await MessagingCoreService.restore(eventStore);
      final firstAdapter = LegacyChatHistoryAdapter(
        messagingCore: firstCore,
        localRepository: legacyStore,
        remoteSource: _MemoryLegacyChatRemoteSource(),
      );

      await expectLater(
        firstAdapter.loadAndPromote(1, 2),
        throwsA(isA<StateError>()),
      );

      expect(eventStore.events.map((event) => event.messageId), [
        first.messageKey,
      ]);
      expect(eventStore.inboxBatches, hasLength(1));
      expect(legacyStore.migratedEventMessageIds(1, 2), completion(isNull));
      await firstCore.dispose();

      final recoveredCore = await MessagingCoreService.restore(eventStore);

      expect(
        recoveredCore
            .conversation('1:2')
            .map((projection) => projection.messageId),
        {first.messageKey, second.messageKey},
      );
      expect(eventStore.inboxBatches, isEmpty);

      final recoveredAdapter = LegacyChatHistoryAdapter(
        messagingCore: recoveredCore,
        localRepository: legacyStore,
        remoteSource: _MemoryLegacyChatRemoteSource(),
      );
      await recoveredAdapter.loadAndPromote(1, 2);

      expect(await legacyStore.migratedEventMessageIds(1, 2), {
        first.messageKey,
        second.messageKey,
      });
      expect(recoveredCore.conversation('1:2'), hasLength(2));
      await recoveredCore.dispose();
    },
  );

  test(
    'merges legacy rows even when shared history already has newer events',
    () async {
      final legacyMessage = LegacyChatRecord(
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
      final chat = _createChat(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatPorts([legacyMessage]),
      );

      final history = await chat.loadConversation(1, 2);

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
      final chat = _createChat(
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
      await chat.sendText(2, 'stay-local');

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
      final chat = _createChat(
        api,
        messagingCore: core,
        localRepository: _MemoryLegacyChatPorts(),
      );

      final history = await chat.refreshConversation(1, 2);

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
    final chat = _createChat(
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
    await chat.sendText(2, 'recall-later');
    final message = (await chat.loadConversation(1, 2)).single;
    await chat.disconnectAsync();
    await expectLater(
      chat.recallProjectedMessage(message.id),
      throwsStateError,
    );

    expect(legacyCalls, 0);
    expect(core.repository.pendingOutbox, hasLength(1));
    expect(core.conversation('1:2').single.visibleBody, recalledMessageText);

    chat.dispose();
    await core.dispose();
  });

  test(
    'legacy recall fallback derives the server key from the event projection',
    () async {
      final core = MessagingCoreService();
      final transport = _LegacyRecallFallbackTransport();
      final remote = _MemoryLegacyChatRemoteSource();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final chat = _createChat(
        api,
        messagingCore: core,
        remoteSource: remote,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                transport,
      );

      await chat.connectToDm(1, 2);
      await chat.sendText(2, 'legacy recall compatibility');
      final message = (await chat.loadConversation(1, 2)).single;
      final projection = core.repository.projectionFor(message.id)!;
      final expectedLegacyKey =
          '${projection.createdAt.toIso8601String()}_${projection.authorId}';

      await chat.recallProjectedMessage(message.id);

      expect(remote.recalledMessageKeys, [expectedLegacyKey]);
      expect(core.repository.projectionFor(message.id)?.recalled, isTrue);
      expect(
        core.repository.pendingOutbox.any(
          (event) => event.type == MessageEventType.recalled,
        ),
        isFalse,
      );

      await chat.disposeAsync();
      await core.dispose();
    },
  );

  test('keeps create, edit, and recall events locally while offline', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport(failSends: true);
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = _createChat(
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
    await expectLater(chat.sendText(2, 'original'), throwsStateError);
    final firstMessage = (await chat.loadConversation(1, 2)).single;

    await expectLater(
      chat.editProjectedMessage(firstMessage.id, 'edited'),
      throwsStateError,
    );
    await expectLater(
      chat.recallProjectedMessage(firstMessage.id),
      throwsStateError,
    );

    expect(core.repository.pendingOutbox, hasLength(3));
    expect(core.conversation('1:2').single.visibleBody, recalledMessageText);

    chat.dispose();
    await core.dispose();
  });

  test('does not mark an edited message as still sending', () async {
    final core = MessagingCoreService();
    final transport = _FakeTransport();
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final chat = _createChat(
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
    await chat.sendText(2, 'original');
    final original = (await chat.loadConversation(1, 2)).single;
    expect(original.isPending, isFalse);

    transport.failSends = true;
    await expectLater(
      chat.editProjectedMessage(original.id, 'edited offline'),
      throwsStateError,
    );

    expect(_projectedMessage(core).text, 'edited offline');
    expect(_projectedMessage(core).isPending, isFalse);
    expect(core.repository.pendingOutbox, hasLength(1));

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
    final chat = _createChat(
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
      final chat = _createChat(
        api,
        messagingCore: core,
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => transport,
      );
      final updates = <DirectMessage>[];
      final subscription = chat.directMessageStream.listen(updates.add);

      await chat.connectToDm(1, 2);
      await expectLater(chat.sendText(2, 'first'), throwsStateError);
      final first = (await chat.loadConversation(1, 2)).first;
      await expectLater(chat.sendText(2, 'second'), throwsStateError);
      await expectLater(
        chat.editProjectedMessage(first.id, 'first edited'),
        throwsStateError,
      );

      expect(updates.last.text, 'first edited');
      await expectLater(
        chat.recallProjectedMessage(first.id),
        throwsStateError,
      );
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
      final chat = _createChat(
        api,
        messagingCore: core,
        manualSignaling: signaling,
        p2pAuthenticator: _RoundTripAuthenticator(),
      );

      expect(chat.manualP2pEnabled, isTrue);
      final signed = await chat.exportBundle(
        sessionId: 'dm:1:2',
        senderDeviceId: 'device-1',
      );
      final wrapper = jsonDecode(signed) as Map<String, dynamic>;
      expect(
        PeerNegotiationBundle.decode(wrapper['bundle'] as String).sessionId,
        'dm:1:2',
      );
      await chat.importBundle(signed, expectedSessionId: 'dm:1:2');

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
    final chat = _createChat(
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
    final chat = _createChat(
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

    final incoming = core.repository.projectionsFor('1:2').single;
    await chat.markProjectedMessageRead(incoming.messageId);

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
    final chat = _createChat(
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

ChatService _createChat(
  ApiClient api, {
  required MessagingCoreService messagingCore,
  EventAuthenticator? authenticator,
  EventAuthenticator? remoteAuthenticator,
  EventAuthenticator? p2pAuthenticator,
  String? deviceId,
  DirectMessageTransportFactory? transportFactory,
  _MemoryLegacyChatPorts? localRepository,
  _MemoryLegacyChatRemoteSource? remoteSource,
  PeerSignalingChannel? manualSignaling,
  ManualP2PTransportFactory? manualTransportFactory,
  Duration outboxRetryInterval = const Duration(seconds: 5),
}) {
  final store = localRepository ?? _MemoryLegacyChatPorts();
  final LegacyChatDeliveryRemoteSource deliveryRemote =
      remoteSource ?? ServerLegacyChatRemoteSource(api);
  final LegacyChatHistoryRemoteSource historyRemote =
      remoteSource ?? ServerLegacyChatRemoteSource(api);
  final LegacyChatSnapshotRemoteSource snapshotRemote =
      remoteSource ?? ServerLegacyChatRemoteSource(api);
  return ChatService(
    messagingCore: messagingCore,
    authenticator: authenticator,
    remoteAuthenticator: remoteAuthenticator,
    p2pAuthenticator: p2pAuthenticator,
    deviceId: deviceId,
    transportFactory:
        transportFactory ??
        ({required selfId, required friendId, required isCaller}) =>
            ServerMessageTransport(
              apiClient: api,
              selfId: selfId,
              friendId: friendId,
            ),
    legacyDelivery: LegacyChatDeliveryAdapter(
      localRepository: store,
      remoteSource: deliveryRemote,
    ),
    legacyHistory: LegacyChatHistoryAdapter(
      messagingCore: messagingCore,
      localRepository: store,
      remoteSource: historyRemote,
      remoteAuthenticator: remoteAuthenticator,
    ),
    legacySyncSnapshots: LegacyChatSyncSnapshotAdapter(
      messagingCore: messagingCore,
      localRepository: store,
      remoteSource: snapshotRemote,
    ),
    manualSignaling: manualSignaling,
    manualTransportFactory: manualTransportFactory,
    outboxRetryInterval: outboxRetryInterval,
  );
}

DirectMessage _projectedMessage(MessagingCoreService core) {
  final projection = core.conversation('1:2').single;
  final isPending = core.repository.pendingOutbox.any(
    (event) =>
        event.type == MessageEventType.created &&
        event.messageId == projection.messageId,
  );
  return DirectMessage.fromProjection(projection, isPending: isPending);
}

class _FakeTransport implements MessageTransport {
  _FakeTransport({this.failSends = false});

  bool failSends;
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

class _LegacyRecallFallbackTransport extends _FakeTransport {
  @override
  Future<void> send(MessageEvent event) async {
    if (event.type == MessageEventType.recalled) {
      throw RemoteSourceException('Unsupported event', statusCode: 404);
    }
    await super.send(event);
  }
}

class _LegacyCreateFallbackTransport extends _FakeTransport {
  @override
  Future<void> send(MessageEvent event) async {
    if (event.type == MessageEventType.created) {
      throw RemoteSourceException('Unsupported event', statusCode: 404);
    }
    await super.send(event);
  }
}

class _MemoryLegacyChatRemoteSource
    implements
        LegacyChatHistoryRemoteSource,
        LegacyChatSnapshotRemoteSource,
        LegacyChatDeliveryRemoteSource {
  _MemoryLegacyChatRemoteSource({
    Iterable<LegacyChatRecord> history = const [],
    this.hasMore = false,
    this.nextCursor,
  }) : history = List.of(history);

  final List<LegacyChatRecord> history;
  final bool hasMore;
  final MessageHistoryCursor? nextCursor;
  final requestedHistoryCursors = <MessageHistoryCursor?>[];
  final recalledMessageKeys = <String>[];
  final sentTexts = <String>[];
  int? uploadedFriendId;
  Map<String, dynamic> uploadedData = {};
  Map<String, dynamic> downloadedData = {};
  String? downloadedSnapshotId = 'snapshot-1';
  final acknowledgedSnapshotIds = <String>[];

  @override
  Future<MessageHistoryPage<LegacyChatRecord>> fetchHistory(
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    requestedHistoryCursors.add(before);
    return MessageHistoryPage(
      messages: history,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> uploadSyncData(int friendId, Map<String, dynamic> data) async {
    uploadedFriendId = friendId;
    uploadedData = data;
  }

  @override
  Future<LegacyChatSnapshotDownload> downloadSyncData(int friendId) async =>
      LegacyChatSnapshotDownload(
        data: downloadedData,
        snapshotId: downloadedSnapshotId,
      );

  @override
  Future<void> acknowledgeSyncData(int friendId, String snapshotId) async {
    acknowledgedSnapshotIds.add(snapshotId);
  }

  @override
  Future<Map<String, dynamic>> sendMessage(int friendId, String text) async {
    sentTexts.add(text);
    return {'ok': true};
  }

  @override
  Future<void> recallMessage(int friendId, String messageKey) async {
    recalledMessageKeys.add(messageKey);
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

class _CrashRecoveringMessageStore
    implements MessageEventStore, MessageBatchInboxStore {
  _CrashRecoveringMessageStore({required this.failEventId});

  final String failEventId;
  final events = <MessageEvent>[];
  final pendingOutbox = <MessageEvent>[];
  final inboxBatches = <String, List<MessageEvent>>{};
  var _failedAppend = false;
  var _nextBatchId = 0;

  @override
  Future<void> acknowledgeOutbox(String eventId) async {
    pendingOutbox.removeWhere((event) => event.eventId == eventId);
  }

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    if (!_failedAppend && event.eventId == failEventId) {
      _failedAppend = true;
      throw StateError('injected event-store failure');
    }
    if (!events.any((stored) => stored.eventId == event.eventId)) {
      events.add(event);
    }
    if (pendingOutbox &&
        !this.pendingOutbox.any((stored) => stored.eventId == event.eventId)) {
      this.pendingOutbox.add(event);
    }
  }

  @override
  Future<String> appendInboxBatch(List<MessageEvent> events) async {
    final id = 'batch-${_nextBatchId++}';
    inboxBatches[id] = List.of(events);
    return id;
  }

  @override
  Future<List<MessageEvent>> loadAll() async => List.of(events);

  @override
  Future<List<MessageEventBatch>> loadInboxBatches() async => [
    for (final entry in inboxBatches.entries)
      MessageEventBatch(id: entry.key, events: entry.value),
  ];

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async =>
      List.of(pendingOutbox);

  @override
  Future<void> removeInboxBatch(String batchId) async {
    inboxBatches.remove(batchId);
  }
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

class _RoundTripAuthenticator implements EventAuthenticator {
  @override
  Future<String> sign(MessageEvent event) async =>
      base64UrlEncode(utf8.encode(event.canonicalPayload));

  @override
  Future<bool> verify(MessageEvent event) async =>
      event.signature == base64UrlEncode(utf8.encode(event.canonicalPayload));
}

class _MemoryLegacyChatPorts
    implements
        LegacyChatHistoryStore,
        LegacyPendingMessageStore,
        LegacyChatDeliveryStore,
        LegacyChatSnapshotStore {
  _MemoryLegacyChatPorts([Iterable<LegacyChatRecord> initial = const []])
    : messages = List.of(initial);

  final List<LegacyChatRecord> messages;
  final List<String> invalidRowKeys = [];
  Map<String, dynamic> importedData = {};
  final Map<String, Set<String>> _migrationManifests = {};
  int getMessagesCallCount = 0;
  int revision = 0;

  static String _conversationKey(int selfId, int friendId) {
    final low = selfId < friendId ? selfId : friendId;
    final high = selfId < friendId ? friendId : selfId;
    return 'chat_${low}_$high';
  }

  @override
  Future<void> saveMessage(int selfId, LegacyChatRecord message) async {
    messages.add(message);
    revision++;
    _migrationManifests.remove(
      _conversationKey(
        selfId,
        message.senderId == selfId ? message.receiverId : message.senderId,
      ),
    );
  }

  @override
  Future<void> markRecalled(
    int selfId,
    int friendId,
    String messageKey,
  ) async {}

  @override
  Future<LegacyChatHistorySnapshot> getHistorySnapshot(
    int selfId,
    int friendId,
  ) async => LegacyChatHistorySnapshot(
    messages: await _readMessages(),
    sourceRevision: '$revision',
    invalidRowKeys: invalidRowKeys,
  );

  Future<List<LegacyChatRecord>> _readMessages() async {
    getMessagesCallCount++;
    return List.of(messages);
  }

  @override
  Future<Set<String>?> migratedEventMessageIds(int selfId, int friendId) async {
    final manifest = _migrationManifests[_conversationKey(selfId, friendId)];
    return manifest == null ? null : Set.unmodifiable(manifest);
  }

  @override
  Future<bool> markEventMessagesMigrated(
    int selfId,
    int friendId,
    Set<String> messageIds, {
    required String expectedSourceRevision,
  }) async {
    if (expectedSourceRevision != '$revision') return false;
    _migrationManifests[_conversationKey(selfId, friendId)] = Set.of(
      messageIds,
    );
    return true;
  }

  @override
  Future<Map<String, Map<String, String>>> exportAll(
    int selfId,
    List<int> friendIds,
  ) async => {};

  @override
  Future<void> importAll(Map<String, dynamic> data) async {
    importedData = data;
  }
}
