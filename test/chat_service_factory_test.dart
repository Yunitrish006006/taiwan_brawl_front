import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/chat_service.dart';
import 'package:taiwan_brawl/services/chat_service_factory.dart';
import 'package:taiwan_brawl/pages/social/editable_dm_page.dart';
import 'package:taiwan_brawl/models/direct_message.dart';
import 'package:taiwan_brawl/models/message_history_page.dart';
import 'package:taiwan_brawl/services/direct_message_session.dart';
import 'package:taiwan_brawl/services/fallback_message_transport.dart';
import 'package:taiwan_brawl/services/hive_messaging_store.dart';
import 'package:taiwan_brawl/models/legacy_chat_record.dart';
import 'package:taiwan_brawl/services/legacy_chat_remote_source.dart';
import 'package:taiwan_brawl/services/legacy_chat_store.dart';
import 'package:taiwan_brawl/services/local_chat_repository.dart';
import 'package:taiwan_brawl/services/messaging_core_service.dart';
import 'package:taiwan_brawl/services/p2p_message_transport.dart';
import 'package:taiwan_brawl/services/server_message_transport.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('factory-composed DM acknowledges only after durable ingest', () async {
    final event = MessageEvent(
      eventId: 'incoming-1',
      messageId: 'message-1',
      conversationId: '1:2',
      actorId: '2',
      type: MessageEventType.created,
      revision: 0,
      createdAt: DateTime.utc(2026, 10, 28),
      body: 'durable hello',
    );
    final store = _ObservedMessageEventStore()..gateNextAppend = true;
    final core = MessagingCoreService(
      repository: MessageRepository(store: store),
      storageStatus: const MessagingStorageStatus.durable(),
    );
    final transport = _ReceiptEventTransport(event);
    final legacy = _MemoryLegacyChatAdapters();
    final service = ChatServiceFactory(
      messagingCore: core,
      legacyDeliveryStore: legacy,
      legacyHistoryStore: legacy,
      legacySnapshotStore: legacy,
      legacyDeliveryRemoteSource: legacy,
      legacyHistoryRemoteSource: legacy,
      legacySnapshotRemoteSource: legacy,
      transportFactory:
          ({required selfId, required friendId, required isCaller}) =>
              transport,
    ).create();

    try {
      final connecting = service.connectToDm(1, 2);
      await store.appendStarted.future;
      expect(transport.acknowledgements, isEmpty);
      store.releaseAppend.complete();
      await connecting;

      expect(transport.acknowledgements, [true]);
      expect(store.events.map((value) => value.eventId), ['incoming-1']);
      expect(core.repository.projectionsFor('1:2'), hasLength(1));

      transport.emit(event);
      await transport.secondAcknowledgement.future;
      expect(transport.acknowledgements, [true, true]);
      expect(core.repository.projectionsFor('1:2'), hasLength(1));
    } finally {
      await service.disposeAsync();
      await core.dispose();
    }
  });

  test(
    'factory-composed DM leaves relay event pending when durable write fails',
    () async {
      final event = MessageEvent(
        eventId: 'incoming-retry',
        messageId: 'message-retry',
        conversationId: '1:2',
        actorId: '2',
        type: MessageEventType.created,
        revision: 0,
        createdAt: DateTime.utc(2026, 10, 28),
        body: 'retry after disk error',
      );
      final store = _ObservedMessageEventStore()..failNextAppend = true;
      final core = MessagingCoreService(
        repository: MessageRepository(store: store),
        storageStatus: const MessagingStorageStatus.durable(),
      );
      final transport = _ReceiptEventTransport(event);
      final legacy = _MemoryLegacyChatAdapters();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: legacy,
        legacyHistoryStore: legacy,
        legacySnapshotStore: legacy,
        legacyDeliveryRemoteSource: legacy,
        legacyHistoryRemoteSource: legacy,
        legacySnapshotRemoteSource: legacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                transport,
      ).create();

      try {
        await service.connectToDm(1, 2);
        expect(transport.acknowledgements, isEmpty);
        expect(store.events, isEmpty);

        transport.emit(event);
        await transport.firstAcknowledgement.future;
        expect(transport.acknowledgements, [true]);
        expect(store.events.map((value) => value.eventId), ['incoming-retry']);
        expect(core.repository.projectionsFor('1:2'), hasLength(1));
      } finally {
        await service.disposeAsync();
        await core.dispose();
      }
    },
  );

  test(
    'factory-composed server relay persists before ack and deduplicates polls',
    () async {
      final store = _ObservedMessageEventStore();
      final core = MessagingCoreService(
        repository: MessageRepository(store: store),
        storageStatus: const MessagingStorageStatus.durable(),
      );
      final acknowledgements = <int>[];
      final ackSawPersistedEvent = <bool>[];
      final pendingQueries = <Uri>[];
      final firstAck = Completer<void>();
      final secondAck = Completer<void>();
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/chat/dm/pending') {
            pendingQueries.add(request.url);
            return http.Response(
              jsonEncode({
                'messages': [
                  {
                    'id': 17,
                    'sender_id': 2,
                    'receiver_id': 1,
                    'text': 'relayed once',
                    'created_at': '2026-10-28T00:00:00.000Z',
                    'type': 'message',
                    'event_id': 'relay-event',
                    'message_id': 'relay-message',
                    'event_type': 'created',
                    'revision': 0,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/chat/dm/ack') {
            final ids = (jsonDecode(request.body)['ids'] as List).cast<int>();
            acknowledgements.addAll(ids);
            ackSawPersistedEvent.add(
              store.events.any((event) => event.eventId == 'relay-event'),
            );
            if (acknowledgements.length == 1) firstAck.complete();
            if (acknowledgements.length == 2) secondAck.complete();
            return http.Response('{}', 200);
          }
          throw StateError('Unexpected relay request: ${request.url}');
        }),
        credentials: _MemoryCredentials(),
      );
      ServerMessageTransport? relayTransport;
      final legacy = _MemoryLegacyChatAdapters();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: legacy,
        legacyHistoryStore: legacy,
        legacySnapshotStore: legacy,
        legacyDeliveryRemoteSource: legacy,
        legacyHistoryRemoteSource: legacy,
        legacySnapshotRemoteSource: legacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) {
              relayTransport = ServerMessageTransport(
                apiClient: api,
                selfId: selfId,
                friendId: friendId,
                pollInterval: const Duration(minutes: 1),
              );
              return relayTransport!;
            },
      ).create();

      try {
        await service.connectToDm(1, 2);
        await firstAck.future.timeout(const Duration(seconds: 1));
        expect(acknowledgements, [17]);
        expect(ackSawPersistedEvent, [true]);
        expect(core.repository.projectionsFor('1:2'), hasLength(1));

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await relayTransport!.pollNow();
        await secondAck.future.timeout(const Duration(seconds: 1));
        expect(pendingQueries, hasLength(2));
        expect(pendingQueries.last.queryParameters['afterId'], '17');
        expect(acknowledgements, [17, 17]);
        expect(ackSawPersistedEvent, [true, true]);
        expect(core.repository.projectionsFor('1:2'), hasLength(1));
      } finally {
        await service.disposeAsync();
        await relayTransport?.dispose();
        await core.dispose();
      }
    },
  );

  test(
    'two factory-composed relay peers converge through message lifecycle',
    () async {
      final backend = _FakeRelayBackend();
      final leftStore = _ObservedMessageEventStore();
      final rightStore = _ObservedMessageEventStore();
      final leftCore = MessagingCoreService(
        repository: MessageRepository(store: leftStore),
        storageStatus: const MessagingStorageStatus.durable(),
      );
      final rightCore = MessagingCoreService(
        repository: MessageRepository(store: rightStore),
        storageStatus: const MessagingStorageStatus.durable(),
      );
      final leftLegacy = _MemoryLegacyChatAdapters();
      final rightLegacy = _MemoryLegacyChatAdapters();
      ServerMessageTransport? leftTransport;
      ServerMessageTransport? rightTransport;
      final left = ChatServiceFactory(
        messagingCore: leftCore,
        legacyDeliveryStore: leftLegacy,
        legacyHistoryStore: leftLegacy,
        legacySnapshotStore: leftLegacy,
        legacyDeliveryRemoteSource: leftLegacy,
        legacyHistoryRemoteSource: leftLegacy,
        legacySnapshotRemoteSource: leftLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) {
              leftTransport = backend.transportFor(selfId, friendId);
              return leftTransport!;
            },
      ).create();
      final right = ChatServiceFactory(
        messagingCore: rightCore,
        legacyDeliveryStore: rightLegacy,
        legacyHistoryStore: rightLegacy,
        legacySnapshotStore: rightLegacy,
        legacyDeliveryRemoteSource: rightLegacy,
        legacyHistoryRemoteSource: rightLegacy,
        legacySnapshotRemoteSource: rightLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) {
              rightTransport = backend.transportFor(selfId, friendId);
              return rightTransport!;
            },
      ).create();

      try {
        await left.connectToDm(1, 2);
        await right.connectToDm(2, 1);

        final rightCreated = rightCore.changes.firstWhere(
          (projection) => projection.visibleBody == 'relay lifecycle message',
        );
        await left.sendText(2, 'relay lifecycle message');
        await rightTransport!.pollNow();
        final createdAtRight = await rightCreated.timeout(
          const Duration(seconds: 1),
        );
        final messageId = leftCore.repository
            .projectionsFor('1:2')
            .single
            .messageId;
        expect(createdAtRight.messageId, messageId);

        final leftRead = leftCore.changes.firstWhere(
          (projection) =>
              projection.messageId == messageId &&
              projection.readBy.contains('2'),
        );
        await right.markProjectedMessageRead(messageId);
        await leftTransport!.pollNow();
        await leftRead.timeout(const Duration(seconds: 1));

        final rightEdited = rightCore.changes.firstWhere(
          (projection) =>
              projection.messageId == messageId &&
              projection.visibleBody == 'relay lifecycle edited',
        );
        await left.editProjectedMessage(messageId, 'relay lifecycle edited');
        await rightTransport!.pollNow();
        await rightEdited.timeout(const Duration(seconds: 1));

        final rightRecalled = rightCore.changes.firstWhere(
          (projection) =>
              projection.messageId == messageId && projection.recalled,
        );
        await left.recallProjectedMessage(messageId);
        await rightTransport!.pollNow();
        await rightRecalled.timeout(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final leftFinal = leftCore.repository.projectionFor(messageId);
        final rightFinal = rightCore.repository.projectionFor(messageId);
        expect(leftFinal?.visibleBody, recalledMessageText);
        expect(rightFinal?.visibleBody, recalledMessageText);
        expect(leftFinal?.readBy, contains('2'));
        expect(rightFinal?.readBy, contains('2'));
        expect(
          leftStore.events.map((event) => event.eventId).toSet(),
          hasLength(4),
        );
        expect(
          rightStore.events.map((event) => event.eventId).toSet(),
          hasLength(4),
        );
        expect(backend.pendingRows.values.expand((rows) => rows), isEmpty);
      } finally {
        await left.disposeAsync();
        await right.disposeAsync();
        await leftTransport?.dispose();
        await rightTransport?.dispose();
        await leftCore.dispose();
        await rightCore.dispose();
      }
    },
  );

  test(
    'ChatService waits for consent and drains its local outbox after relay choice',
    () async {
      final core = MessagingCoreService();
      final relay = _RecordingTransport(_NoopTransport());
      final legacy = _MemoryLegacyChatAdapters();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: legacy,
        legacyHistoryStore: legacy,
        legacySnapshotStore: legacy,
        legacyDeliveryRemoteSource: legacy,
        legacyHistoryRemoteSource: legacy,
        legacySnapshotRemoteSource: legacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                FallbackMessageTransport(
                  primary: _ConnectFailingTransport(),
                  fallback: relay,
                ),
      ).create();

      try {
        await expectLater(
          service.connectToDm(1, 2),
          throwsA(isA<RelayFallbackChoiceRequired>()),
        );
        expect(service.relayFallbackChoiceRequired, isTrue);
        expect(relay.sent, isEmpty);

        await service.sendText(2, 'keep this until consent');
        expect(core.repository.pendingOutbox, hasLength(1));
        expect(relay.sent, isEmpty);

        await service.useRelayFallback();
        expect(relay.sent, hasLength(1));
        expect(relay.sent.single.body, 'keep this until consent');
        expect(core.repository.pendingOutbox, isEmpty);
        expect(service.relayFallbackChoiceRequired, isFalse);
      } finally {
        await service.disposeAsync();
        await core.dispose();
      }
    },
  );

  test(
    'ChatService retry restores P2P and drains outbox without relay',
    () async {
      final core = MessagingCoreService();
      final primary = _RecoversAfterFirstConnectFailureTransport();
      final relay = _RecordingTransport(_NoopTransport());
      final legacy = _MemoryLegacyChatAdapters();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: legacy,
        legacyHistoryStore: legacy,
        legacySnapshotStore: legacy,
        legacyDeliveryRemoteSource: legacy,
        legacyHistoryRemoteSource: legacy,
        legacySnapshotRemoteSource: legacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                FallbackMessageTransport(primary: primary, fallback: relay),
      ).create();

      try {
        await expectLater(
          service.connectToDm(1, 2),
          throwsA(isA<RelayFallbackChoiceRequired>()),
        );
        await service.sendText(2, 'wait for P2P recovery');
        final pendingEvent = core.repository.pendingOutbox.single;

        expect(await service.retryP2PConnection(), isTrue);
        expect(primary.sent.map((event) => event.eventId), [
          pendingEvent.eventId,
        ]);
        expect(relay.connectCalls, 0);
        expect(relay.sent, isEmpty);
        expect(core.repository.pendingOutbox, isEmpty);
        expect(service.p2pActive, isTrue);
      } finally {
        await service.disposeAsync();
        await core.dispose();
      }
    },
  );

  test(
    'P2P send failure keeps one event for consented reconnect retry',
    () async {
      final leftCore = MessagingCoreService();
      final rightCore = MessagingCoreService();
      final (leftPeer, rightTransport) = InMemoryMessageTransport.pair();
      final failingPrimary = _FailFirstSendTransport(leftPeer);
      final relay = _RecordingTransport(_NoopTransport());
      late FallbackMessageTransport leftTransport;
      final leftLegacy = _MemoryLegacyChatAdapters();
      final rightLegacy = _MemoryLegacyChatAdapters();
      final left = ChatServiceFactory(
        messagingCore: leftCore,
        legacyDeliveryStore: leftLegacy,
        legacyHistoryStore: leftLegacy,
        legacySnapshotStore: leftLegacy,
        legacyDeliveryRemoteSource: leftLegacy,
        legacyHistoryRemoteSource: leftLegacy,
        legacySnapshotRemoteSource: leftLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                leftTransport = FallbackMessageTransport(
                  primary: failingPrimary,
                  fallback: relay,
                ),
      ).create();
      final right = ChatServiceFactory(
        messagingCore: rightCore,
        legacyDeliveryStore: rightLegacy,
        legacyHistoryStore: rightLegacy,
        legacySnapshotStore: rightLegacy,
        legacyDeliveryRemoteSource: rightLegacy,
        legacyHistoryRemoteSource: rightLegacy,
        legacySnapshotRemoteSource: rightLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                rightTransport,
      ).create();

      try {
        await left.connectToDm(1, 2);
        await right.connectToDm(2, 1);
        await expectLater(
          left.sendText(2, 'recover the original event'),
          throwsA(isA<RelayFallbackChoiceRequired>()),
        );

        final pending = leftCore.repository.pendingOutbox.single;
        expect(left.relayFallbackChoiceRequired, isTrue);
        expect(leftTransport.p2pActive, isFalse);
        expect(leftTransport.relayActive, isFalse);
        expect(rightCore.repository.projectionsFor('1:2'), isEmpty);
        expect(relay.connectCalls, 0);

        final received = right.directMessageStream.first;
        expect(await left.retryP2PConnection(), isTrue);
        final delivered = await received;

        expect(delivered.text, 'recover the original event');
        expect(delivered.id, pending.messageId);
        expect(failingPrimary.sent, hasLength(2));
        expect(failingPrimary.sent.map((event) => event.eventId).toSet(), {
          pending.eventId,
        });
        expect(rightCore.repository.projectionsFor('1:2'), hasLength(1));
        expect(leftCore.repository.pendingOutbox, isEmpty);
        expect(relay.connectCalls, 0);
        expect(relay.sent, isEmpty);
      } finally {
        await left.disposeAsync();
        await right.disposeAsync();
        await leftCore.dispose();
        await rightCore.dispose();
      }
    },
  );

  test('reopening a DM starts a fresh session on P2P first', () async {
    final core = MessagingCoreService();
    final legacy = _MemoryLegacyChatAdapters();
    final firstRelay = _RecordingTransport(_NoopTransport());
    final secondRelay = _RecordingTransport(_NoopTransport());
    final nextPrimary = _ConnectCountingTransport();
    var sessionCount = 0;
    final service = ChatServiceFactory(
      messagingCore: core,
      legacyDeliveryStore: legacy,
      legacyHistoryStore: legacy,
      legacySnapshotStore: legacy,
      legacyDeliveryRemoteSource: legacy,
      legacyHistoryRemoteSource: legacy,
      legacySnapshotRemoteSource: legacy,
      transportFactory:
          ({required selfId, required friendId, required isCaller}) {
            sessionCount++;
            return FallbackMessageTransport(
              primary: sessionCount == 1
                  ? _ConnectFailingTransport()
                  : nextPrimary,
              fallback: sessionCount == 1 ? firstRelay : secondRelay,
            );
          },
    ).create();

    try {
      await expectLater(
        service.connectToDm(1, 2),
        throwsA(isA<RelayFallbackChoiceRequired>()),
      );
      await service.useRelayFallback();
      expect(firstRelay.sent, isEmpty);

      await service.connectToDm(1, 2);
      expect(nextPrimary.connectCalls, 1);
      expect(secondRelay.sent, isEmpty);
      expect(service.relayFallbackChoiceRequired, isFalse);
    } finally {
      await service.disposeAsync();
      await core.dispose();
    }
  });

  testWidgets(
    'factory-composed DM widget sends one event while a later draft waits',
    (tester) async {
      final leftCore = MessagingCoreService();
      final rightCore = MessagingCoreService();
      final (leftTransport, rightTransport) = InMemoryMessageTransport.pair();
      final leftLegacy = _MemoryLegacyChatAdapters();
      final rightLegacy = _MemoryLegacyChatAdapters();
      final leftService = ChatServiceFactory(
        messagingCore: leftCore,
        legacyDeliveryStore: leftLegacy,
        legacyHistoryStore: leftLegacy,
        legacySnapshotStore: leftLegacy,
        legacyDeliveryRemoteSource: leftLegacy,
        legacyHistoryRemoteSource: leftLegacy,
        legacySnapshotRemoteSource: leftLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                leftTransport,
      ).create();
      final left = _GatedDirectMessageSession(leftService);
      final right = ChatServiceFactory(
        messagingCore: rightCore,
        legacyDeliveryStore: rightLegacy,
        legacyHistoryStore: rightLegacy,
        legacySnapshotStore: rightLegacy,
        legacyDeliveryRemoteSource: rightLegacy,
        legacyHistoryRemoteSource: rightLegacy,
        legacySnapshotRemoteSource: rightLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                rightTransport,
      ).create();

      try {
        await right.connectToDm(2, 1);
        await tester.pumpWidget(
          MaterialApp(
            home: EditableDmPage(
              service: left,
              friendId: 2,
              friendName: 'Friend',
              currentUserId: 1,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(left.connected.isCompleted, isTrue);

        await tester.enterText(find.byType(TextField), 'first message');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();
        expect(left.firstSendStarted.isCompleted, isTrue);

        await tester.enterText(find.byType(TextField), 'keep as next draft');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();

        expect(left.sendCalls, 1);
        expect(find.text('keep as next draft'), findsOneWidget);

        left.release.complete();
        await tester.pump();
        await left.firstSendCompleted.future;
        await tester.pump();

        expect(leftCore.repository.projectionsFor('1:2'), hasLength(1));
        expect(rightCore.repository.projectionsFor('1:2'), hasLength(1));
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('first message'), findsOneWidget);
        expect(find.text('keep as next draft'), findsOneWidget);
        expect(left.sendCalls, 1);

        final messageId = leftCore.repository
            .projectionsFor('1:2')
            .single
            .messageId;
        await right.markProjectedMessageRead(messageId);
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          leftCore.repository.projectionFor(messageId)?.readBy,
          contains('2'),
        );

        await tester.longPress(find.text('first message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'edited message');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          rightCore.repository.projectionFor(messageId)?.visibleBody,
          'edited message',
        );

        await tester.longPress(find.text('edited message'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.undo));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 20));
        final senderFinal = leftCore.repository.projectionFor(messageId);
        final receiverFinal = rightCore.repository.projectionFor(messageId);
        expect(senderFinal?.recalled, isTrue);
        expect(receiverFinal?.recalled, isTrue);
        expect(senderFinal?.visibleBody, recalledMessageText);
        expect(receiverFinal?.visibleBody, recalledMessageText);
        expect(find.textContaining('recalled'), findsOneWidget);
      } finally {
        if (!left.release.isCompleted) {
          left.release.complete();
        }
        leftService.dispose();
        right.dispose();
        leftCore.dispose();
        rightCore.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'factory-composed DM widget retries the failed outbox event only once',
    (tester) async {
      final leftCore = MessagingCoreService();
      final rightCore = MessagingCoreService();
      final (leftPeer, rightTransport) = InMemoryMessageTransport.pair();
      final failingTransport = _FailFirstSendTransport(leftPeer);
      final leftLegacy = _MemoryLegacyChatAdapters();
      final rightLegacy = _MemoryLegacyChatAdapters();
      final left = ChatServiceFactory(
        messagingCore: leftCore,
        legacyDeliveryStore: leftLegacy,
        legacyHistoryStore: leftLegacy,
        legacySnapshotStore: leftLegacy,
        legacyDeliveryRemoteSource: leftLegacy,
        legacyHistoryRemoteSource: leftLegacy,
        legacySnapshotRemoteSource: leftLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                failingTransport,
      ).create();
      final right = ChatServiceFactory(
        messagingCore: rightCore,
        legacyDeliveryStore: rightLegacy,
        legacyHistoryStore: rightLegacy,
        legacySnapshotStore: rightLegacy,
        legacyDeliveryRemoteSource: rightLegacy,
        legacyHistoryRemoteSource: rightLegacy,
        legacySnapshotRemoteSource: rightLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                rightTransport,
      ).create();

      try {
        await right.connectToDm(2, 1);
        await tester.pumpWidget(
          MaterialApp(
            home: EditableDmPage(
              service: left,
              retryService: left,
              friendId: 2,
              friendName: 'Friend',
              currentUserId: 1,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        await tester.enterText(find.byType(TextField), 'retry this message');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(find.text('retry this message'), findsNWidgets(2));
        expect(find.textContaining('Message send failed'), findsOneWidget);
        expect(leftCore.repository.pendingOutbox, hasLength(1));
        final pendingId = leftCore.repository.pendingOutbox.single.messageId;
        expect(failingTransport.sent, hasLength(1));

        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(leftCore.repository.pendingOutbox, isEmpty);
        expect(leftCore.repository.projectionsFor('1:2'), hasLength(1));
        expect(rightCore.repository.projectionsFor('1:2'), hasLength(1));
        expect(
          failingTransport.sent.map((event) => event.messageId),
          everyElement(pendingId),
        );
        expect(failingTransport.sent, hasLength(2));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(find.text('retry this message'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        left.dispose();
        right.dispose();
        leftCore.dispose();
        rightCore.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'factory-composed DM history paging keeps the visible message anchored',
    (tester) async {
      final baseTime = DateTime.utc(2026, 10, 1);
      LegacyChatRecord historyRecord(int index) => LegacyChatRecord(
        senderId: 2,
        receiverId: 1,
        text: 'history $index',
        createdAt: baseTime.add(Duration(minutes: index)).toIso8601String(),
        pendingId: index + 1,
      );
      final olderRows = [for (var i = 0; i < 40; i++) historyRecord(i)];
      final recentRows = [for (var i = 40; i < 80; i++) historyRecord(i)];
      final cursor = MessageHistoryCursor(
        createdAt: recentRows.first.createdAt,
        rowId: recentRows.first.pendingId!,
      );
      final olderPageGate = Completer<void>();
      final historySource = _MemoryLegacyChatAdapters(
        historyPageGate: olderPageGate,
        historyPages: [
          MessageHistoryPage(
            messages: recentRows,
            hasMore: true,
            nextCursor: cursor,
          ),
          MessageHistoryPage(
            messages: olderRows,
            hasMore: false,
            nextCursor: null,
          ),
        ],
      );
      final core = MessagingCoreService();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: historySource,
        legacyHistoryStore: historySource,
        legacySnapshotStore: historySource,
        legacyDeliveryRemoteSource: historySource,
        legacyHistoryRemoteSource: historySource,
        legacySnapshotRemoteSource: historySource,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _NoopTransport(),
      ).create();
      final trackedService = _GatedDirectMessageSession(service);

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: EditableDmPage(
              service: trackedService,
              friendId: 2,
              friendName: 'Friend',
              currentUserId: 1,
            ),
          ),
        );
        await trackedService.historyLoaded.future;
        await tester.pump();
        await tester.pumpAndSettle();
        expect(historySource.requestedHistoryCursors, [null]);
        expect(core.repository.projectionsFor('1:2'), hasLength(40));

        final listFinder = find.byType(ListView);
        final listController = tester.widget<ListView>(listFinder).controller!;
        listController.jumpTo(160);
        await tester.pump();
        expect(listController.position.pixels, closeTo(160, 1));
        final anchor = find.text('history 45');
        final anchorBeforeLoad = tester.getTopLeft(anchor).dy;

        await tester.drag(listFinder, const Offset(0, 100));
        await tester.pump();
        expect(historySource.requestedHistoryCursors, [null, cursor]);
        final anchorAtLoad = tester.getTopLeft(anchor).dy;

        olderPageGate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(core.repository.projectionsFor('1:2'), hasLength(80));
        final anchorAfterLoad = tester.getTopLeft(anchor).dy;
        expect((anchorAfterLoad - anchorAtLoad).abs(), lessThan(3));
        expect(anchorAtLoad, greaterThan(anchorBeforeLoad));

        listController.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('history 0'), findsOneWidget);
        expect(historySource.requestedHistoryCursors, [null, cursor]);
      } finally {
        if (!olderPageGate.isCompleted) olderPageGate.complete();
        service.dispose();
        core.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  test(
    'factory-composed DM services converge on one create, edit, read, and recall',
    () async {
      final hiveDirectory = await Directory.systemTemp.createTemp(
        'chat-factory-integration-',
      );
      Hive.init(hiveDirectory.path);
      addTearDown(() async {
        await Hive.close();
        await hiveDirectory.delete(recursive: true);
      });
      final leftCore = MessagingCoreService();
      final rightCore = MessagingCoreService();
      final (leftTransport, rightTransport) = InMemoryMessageTransport.pair();

      final left = _createComposedChatService(
        leftCore,
        ({required selfId, required friendId, required isCaller}) =>
            selfId == 1 ? leftTransport : rightTransport,
      );
      final right = _createComposedChatService(
        rightCore,
        ({required selfId, required friendId, required isCaller}) =>
            selfId == 1 ? leftTransport : rightTransport,
      );
      await right.connectToDm(2, 1);
      await left.connectToDm(1, 2);

      await left.sendText(2, 'factory composed message');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final leftAfterCreate = await left.loadConversation(1, 2);
      final rightAfterCreate = await right.loadConversation(2, 1);
      expect(leftAfterCreate, hasLength(1));
      expect(rightAfterCreate, hasLength(1));

      final messageId = leftAfterCreate.single.id;
      await right.markProjectedMessageRead(rightAfterCreate.single.id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await left.editProjectedMessage(messageId, 'factory composed edit');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        (await right.loadConversation(2, 1)).single.text,
        'factory composed edit',
      );

      await left.recallProjectedMessage(messageId);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((await left.loadConversation(1, 2)), hasLength(1));
      expect((await right.loadConversation(2, 1)), hasLength(1));
      expect(
        (await right.loadConversation(2, 1)).single.text,
        recalledMessageText,
      );
      expect(
        rightCore.repository.projectionFor(messageId)?.readBy,
        contains('2'),
      );

      await left.disposeAsync();
      await right.disposeAsync();
      await leftCore.dispose();
      await rightCore.dispose();
    },
    skip: kIsWeb ? 'Hive filesystem integration runs on VM only' : false,
  );

  test(
    'restores the encrypted outbox and delivers it once after composition restart',
    () async {
      const boxName = 'factory_outbox_restart_test';
      final hiveDirectory = await Directory.systemTemp.createTemp(
        'chat-factory-restart-',
      );
      Hive.init(hiveDirectory.path);
      addTearDown(() async {
        await Hive.close();
        await hiveDirectory.delete(recursive: true);
      });
      final key = List<int>.filled(32, 19);
      final firstCore = await MessagingCoreService.restore(
        HiveMessageEventStore(encryptionKey: key, boxName: boxName),
      );
      final offline = _FailingTransport();
      final firstService = _createComposedChatService(
        firstCore,
        ({required selfId, required friendId, required isCaller}) => offline,
      );

      await firstService.connectToDm(1, 2);
      await expectLater(
        firstService.sendText(2, 'survives restart'),
        throwsStateError,
      );
      final pendingEvent = firstCore.repository.pendingOutbox.single;
      await firstService.disposeAsync();
      await firstCore.dispose();

      await Hive.close();
      Hive.init(hiveDirectory.path);
      final restoredSenderCore = await MessagingCoreService.restore(
        HiveMessageEventStore(encryptionKey: key, boxName: boxName),
      );
      final receiverCore = MessagingCoreService();
      var pair = InMemoryMessageTransport.pair();
      var recordingSender = _RecordingTransport(pair.$1);
      final receiver = _createComposedChatService(
        receiverCore,
        ({required selfId, required friendId, required isCaller}) => pair.$2,
      );
      var sender = _createComposedChatService(
        restoredSenderCore,
        ({required selfId, required friendId, required isCaller}) =>
            recordingSender,
      );

      await receiver.connectToDm(2, 1);
      final receivedProjection = receiverCore.repository.changes
          .firstWhere(
            (projection) => projection.messageId == pendingEvent.messageId,
          )
          .timeout(const Duration(seconds: 2));
      await sender.connectToDm(1, 2);
      await receivedProjection;
      expect(recordingSender.sent, hasLength(1));
      expect(restoredSenderCore.repository.pendingOutbox, isEmpty);
      expect(await receiver.loadConversation(2, 1), hasLength(1));

      await sender.disposeAsync();
      pair = InMemoryMessageTransport.pair();
      recordingSender = _RecordingTransport(pair.$1);
      sender = _createComposedChatService(
        restoredSenderCore,
        ({required selfId, required friendId, required isCaller}) =>
            recordingSender,
      );
      await sender.connectToDm(1, 2);
      expect(recordingSender.sent, isEmpty);
      expect(await receiver.loadConversation(2, 1), hasLength(1));

      await sender.disposeAsync();
      await receiver.disposeAsync();
      await restoredSenderCore.dispose();
      await receiverCore.dispose();
      await Hive.deleteBoxFromDisk(boxName);
    },
    skip: kIsWeb ? 'Hive filesystem integration runs on VM only' : false,
  );

  test(
    'restores an encrypted outbox and drains it once after explicit relay consent',
    () async {
      const boxName = 'factory_relay_outbox_restart_test';
      final hiveDirectory = await Directory.systemTemp.createTemp(
        'chat-relay-restart-',
      );
      Hive.init(hiveDirectory.path);
      final key = List<int>.filled(32, 23);
      final firstStore = HiveMessageEventStore(
        encryptionKey: key,
        boxName: boxName,
      );
      final firstCore = await MessagingCoreService.restore(firstStore);
      final firstLegacy = _MemoryLegacyChatAdapters();
      final firstService = ChatServiceFactory(
        messagingCore: firstCore,
        legacyDeliveryStore: firstLegacy,
        legacyHistoryStore: firstLegacy,
        legacySnapshotStore: firstLegacy,
        legacyDeliveryRemoteSource: firstLegacy,
        legacyHistoryRemoteSource: firstLegacy,
        legacySnapshotRemoteSource: firstLegacy,
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _FailingTransport(),
      ).create();

      try {
        await firstService.connectToDm(1, 2);
        await expectLater(
          firstService.sendText(2, 'relay after restart'),
          throwsStateError,
        );
        final pending = firstCore.repository.pendingOutbox.single;
        await firstService.disposeAsync();
        await firstCore.dispose();

        await Hive.close();
        Hive.init(hiveDirectory.path);
        final restoredStore = HiveMessageEventStore(
          encryptionKey: key,
          boxName: boxName,
        );
        final restoredCore = await MessagingCoreService.restore(restoredStore);
        final legacy = _MemoryLegacyChatAdapters();
        final postedEvents = <Map<String, dynamic>>[];
        final api = ApiClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/api/chat/dm/pending')) {
              return http.Response(
                jsonEncode({'messages': []}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.endsWith('/api/chat/dm/2/event')) {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              postedEvents.add(body['event'] as Map<String, dynamic>);
              return http.Response('{}', 200);
            }
            throw StateError('Unexpected relay request: ${request.url}');
          }),
          credentials: _MemoryCredentials(),
        );
        final restoredService = ChatServiceFactory(
          messagingCore: restoredCore,
          legacyDeliveryStore: legacy,
          legacyHistoryStore: legacy,
          legacySnapshotStore: legacy,
          legacyDeliveryRemoteSource: legacy,
          legacyHistoryRemoteSource: legacy,
          legacySnapshotRemoteSource: legacy,
          transportFactory:
              ({required selfId, required friendId, required isCaller}) =>
                  FallbackMessageTransport(
                    primary: _ConnectFailingTransport(),
                    fallback: ServerMessageTransport(
                      apiClient: api,
                      selfId: selfId,
                      friendId: friendId,
                      relayEncryptionReady: true,
                      syncCursorStore: restoredStore,
                    ),
                  ),
        ).create();

        try {
          expect(restoredCore.repository.pendingOutbox, hasLength(1));
          expect(
            restoredCore.repository.pendingOutbox.single.eventId,
            pending.eventId,
          );
          await expectLater(
            restoredService.connectToDm(1, 2),
            throwsA(isA<RelayFallbackChoiceRequired>()),
          );
          expect(postedEvents, isEmpty);

          await restoredService.useRelayFallback();
          expect(postedEvents, hasLength(1));
          expect(postedEvents.single['eventId'], pending.eventId);
          expect(restoredCore.repository.pendingOutbox, isEmpty);

          await restoredService.useRelayFallback();
          expect(postedEvents, hasLength(1));
        } finally {
          await restoredService.disposeAsync();
          await restoredCore.dispose();
        }
      } finally {
        await firstService.disposeAsync();
        await firstCore.dispose();
        await Hive.close();
        await Hive.deleteBoxFromDisk(boxName);
        await hiveDirectory.delete(recursive: true);
      }
    },
    skip: kIsWeb ? 'Hive filesystem integration runs on VM only' : false,
  );

  test(
    'composition factory supplies manual signaling to ChatService',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final localRepository = LocalChatRepository();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: localRepository,
        legacyHistoryStore: localRepository,
        legacySnapshotStore: localRepository,
        legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _NoopTransport(),
        manualSignalingFactory: ManualPeerSignaling.new,
      ).create();

      expect(service.manualP2pEnabled, isTrue);
      await service.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'creates isolated manual signaling channels for each DM session',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final localRepository = LocalChatRepository();
      final channels = <ManualPeerSignaling>[];
      final factory = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: localRepository,
        legacyHistoryStore: localRepository,
        legacySnapshotStore: localRepository,
        legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _NoopTransport(),
        p2pAuthenticator: _TestAuthenticator(),
        manualSignalingFactory: () {
          final signaling = ManualPeerSignaling();
          channels.add(signaling);
          return signaling;
        },
      );

      final firstSession = factory.create();
      final secondSession = factory.create();
      channels[0].send(2, {'type': 'offer', 'sdp': 'peer-two-offer'});
      channels[1].send(3, {'type': 'offer', 'sdp': 'peer-three-offer'});

      final firstBundle = await firstSession.exportBundle(
        sessionId: 'dm:1:2',
        senderDeviceId: 'device-one',
      );
      final secondBundle = await secondSession.exportBundle(
        sessionId: 'dm:1:3',
        senderDeviceId: 'device-one',
      );
      final firstSignals = PeerNegotiationBundle.decode(
        (jsonDecode(firstBundle) as Map<String, dynamic>)['bundle'] as String,
      ).signals;
      final secondSignals = PeerNegotiationBundle.decode(
        (jsonDecode(secondBundle) as Map<String, dynamic>)['bundle'] as String,
      ).signals;

      expect(channels, hasLength(2));
      expect(identical(channels[0], channels[1]), isFalse);
      expect(firstSignals, [
        {'type': 'offer', 'sdp': 'peer-two-offer'},
      ]);
      expect(secondSignals, [
        {'type': 'offer', 'sdp': 'peer-three-offer'},
      ]);

      await firstSession.disposeAsync();
      await secondSession.disposeAsync();
      for (final channel in channels) {
        channel.dispose();
      }
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
      final localRepository = LocalChatRepository();
      final transport = _NoopTransport();
      var factoryCalls = 0;
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: localRepository,
        legacyHistoryStore: localRepository,
        legacySnapshotStore: localRepository,
        legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
        transportFactory:
            ({
              required int selfId,
              required int friendId,
              required bool isCaller,
            }) => transport,
        manualSignalingFactory: ManualPeerSignaling.new,
        p2pAuthenticator: _TestAuthenticator(),
        manualTransportFactory:
            ({
              required int friendId,
              required PeerSignalingChannel signalingService,
              required bool isCaller,
            }) {
              factoryCalls++;
              return P2PMessageTransport(
                friendId: friendId,
                signalingService: signalingService,
                isCaller: isCaller,
                peerConnectionFactory: (_) async {
                  throw StateError('test peer factory unavailable');
                },
              );
            },
      ).create();

      await service.connectToDm(1, 2);
      await expectLater(service.prepare(isCaller: true), throwsStateError);
      expect(factoryCalls, 1);

      await service.disposeAsync();
      await core.dispose();
    },
  );

  test(
    'manual P2P refuses to start without an explicit peer verifier',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final localRepository = LocalChatRepository();
      var factoryCalls = 0;
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: localRepository,
        legacyHistoryStore: localRepository,
        legacySnapshotStore: localRepository,
        legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _NoopTransport(),
        manualSignalingFactory: ManualPeerSignaling.new,
        manualTransportFactory:
            ({
              required int friendId,
              required PeerSignalingChannel signalingService,
              required bool isCaller,
            }) {
              factoryCalls++;
              throw StateError('transport must not be created');
            },
      ).create();

      await service.connectToDm(1, 2);
      await expectLater(
        service.prepare(isCaller: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('explicitly trusted peer'),
          ),
        ),
      );
      expect(factoryCalls, 0);

      await service.disposeAsync();
      await core.dispose();
    },
  );

  test('serializes P2P preparation with session disconnect', () async {
    final core = MessagingCoreService();
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final localRepository = LocalChatRepository();
    final transport = _GatedNegotiatingTransport();
    final service = ChatServiceFactory(
      messagingCore: core,
      legacyDeliveryStore: localRepository,
      legacyHistoryStore: localRepository,
      legacySnapshotStore: localRepository,
      legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
      legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
      legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
      transportFactory:
          ({required selfId, required friendId, required isCaller}) =>
              _NoopTransport(),
      p2pAuthenticator: _TestAuthenticator(),
      manualSignalingFactory: ManualPeerSignaling.new,
      manualTransportFactory:
          ({
            required int friendId,
            required PeerSignalingChannel signalingService,
            required bool isCaller,
          }) => transport,
    ).create();

    await service.connectToDm(1, 2);
    final preparing = service.prepare(isCaller: true);
    await transport.prepareStarted.future;
    final disconnecting = service.disconnectAsync();
    await Future<void>.delayed(Duration.zero);

    expect(transport.disconnectCalls, 0);
    transport.finishPrepare.complete();
    await preparing;
    await disconnecting;
    expect(transport.disconnectCalls, 1);

    await service.disposeAsync();
    await core.dispose();
  });

  test('reuses prepared P2P transport until the session disconnects', () async {
    final core = MessagingCoreService();
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      credentials: _MemoryCredentials(),
    );
    final localRepository = LocalChatRepository();
    final transports = <_CountingNegotiatingTransport>[];
    final service = ChatServiceFactory(
      messagingCore: core,
      legacyDeliveryStore: localRepository,
      legacyHistoryStore: localRepository,
      legacySnapshotStore: localRepository,
      legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
      legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
      legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
      transportFactory:
          ({required selfId, required friendId, required isCaller}) =>
              _NoopTransport(),
      p2pAuthenticator: _TestAuthenticator(),
      manualSignalingFactory: ManualPeerSignaling.new,
      manualTransportFactory:
          ({
            required int friendId,
            required PeerSignalingChannel signalingService,
            required bool isCaller,
          }) {
            final transport = _CountingNegotiatingTransport();
            transports.add(transport);
            return transport;
          },
    ).create();

    await service.connectToDm(1, 2);
    await service.prepare(isCaller: true);
    await service.prepare(isCaller: true);
    expect(transports, hasLength(1));
    expect(transports.single.prepareCalls, 1);

    await service.disconnectAsync();
    await service.prepare(isCaller: true);
    expect(transports, hasLength(2));
    expect(transports.last.prepareCalls, 1);

    await service.disposeAsync();
    await core.dispose();
  });

  test(
    'session disposal is idempotent and prevents later lifecycle work',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final localRepository = LocalChatRepository();
      var transportFactoryCalls = 0;
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: localRepository,
        legacyHistoryStore: localRepository,
        legacySnapshotStore: localRepository,
        legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
        transportFactory:
            ({required selfId, required friendId, required isCaller}) {
              transportFactoryCalls++;
              return _NoopTransport();
            },
        manualSignalingFactory: ManualPeerSignaling.new,
      ).create();

      final firstDisposal = service.disposeAsync();
      expect(identical(service.disposeAsync(), firstDisposal), isTrue);
      await firstDisposal;

      await expectLater(
        service.connectToDm(1, 2),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The DM session is disposed',
          ),
        ),
      );
      await expectLater(
        service.prepare(isCaller: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The DM session is disposed',
          ),
        ),
      );
      expect(transportFactoryCalls, 0);
      await core.dispose();
    },
  );

  test(
    'manual P2P fails closed when no transport adapter is configured',
    () async {
      final core = MessagingCoreService();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final localRepository = LocalChatRepository();
      final service = ChatServiceFactory(
        messagingCore: core,
        legacyDeliveryStore: localRepository,
        legacyHistoryStore: localRepository,
        legacySnapshotStore: localRepository,
        legacyDeliveryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacyHistoryRemoteSource: ServerLegacyChatRemoteSource(api),
        legacySnapshotRemoteSource: ServerLegacyChatRemoteSource(api),
        transportFactory:
            ({required selfId, required friendId, required isCaller}) =>
                _NoopTransport(),
        manualSignalingFactory: ManualPeerSignaling.new,
        p2pAuthenticator: _TestAuthenticator(),
      ).create();

      await service.connectToDm(1, 2);
      await expectLater(
        service.prepare(isCaller: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Manual P2P transport is not configured',
          ),
        ),
      );

      await service.disposeAsync();
      await core.dispose();
    },
  );
}

class _GatedDirectMessageSession implements DirectMessageSession {
  _GatedDirectMessageSession(this.delegate);

  final DirectMessageSession delegate;
  final Completer<void> connected = Completer<void>();
  final Completer<void> historyLoaded = Completer<void>();
  final Completer<void> firstSendStarted = Completer<void>();
  final Completer<void> firstSendCompleted = Completer<void>();
  final Completer<void> release = Completer<void>();
  int sendCalls = 0;

  @override
  Stream<DirectMessage> get directMessageStream => delegate.directMessageStream;

  @override
  Future<List<DirectMessage>> loadConversation(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) => delegate.loadConversation(selfId, friendId, before: before);

  @override
  Future<MessageHistoryPage<DirectMessage>> loadConversationPage(
    int selfId,
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    final page = await delegate.loadConversationPage(
      selfId,
      friendId,
      before: before,
    );
    if (!historyLoaded.isCompleted) historyLoaded.complete();
    return page;
  }

  @override
  Future<List<DirectMessage>> refreshConversation(int selfId, int friendId) =>
      delegate.refreshConversation(selfId, friendId);

  @override
  Future<void> sendText(int friendId, String text) async {
    sendCalls++;
    final isFirstSend = sendCalls == 1;
    if (isFirstSend) {
      firstSendStarted.complete();
      await release.future;
    }
    await delegate.sendText(friendId, text);
    if (isFirstSend) firstSendCompleted.complete();
  }

  @override
  Future<void> editProjectedMessage(String messageId, String text) =>
      delegate.editProjectedMessage(messageId, text);

  @override
  Future<void> recallProjectedMessage(String messageId) =>
      delegate.recallProjectedMessage(messageId);

  @override
  Future<void> markProjectedMessageRead(String messageId) =>
      delegate.markProjectedMessageRead(messageId);

  @override
  Future<void> connectToDm(
    int selfId,
    int friendId, {
    bool isCaller = true,
  }) async {
    await delegate.connectToDm(selfId, friendId, isCaller: isCaller);
    if (!connected.isCompleted) connected.complete();
  }

  @override
  void disconnect() => delegate.disconnect();

  @override
  void dispose() => delegate.dispose();
}

class _MemoryLegacyChatAdapters
    implements
        LegacyChatDeliveryStore,
        LegacyChatHistoryStore,
        LegacyChatSnapshotStore,
        LegacyChatDeliveryRemoteSource,
        LegacyChatHistoryRemoteSource,
        LegacyChatSnapshotRemoteSource {
  _MemoryLegacyChatAdapters({
    this.historyPages = const [],
    this.historyPageGate,
  });

  final List<MessageHistoryPage<LegacyChatRecord>> historyPages;
  final Completer<void>? historyPageGate;
  final requestedHistoryCursors = <MessageHistoryCursor?>[];

  @override
  Future<void> saveMessage(int selfId, LegacyChatRecord message) async {}

  @override
  Future<LegacyChatHistorySnapshot> getHistorySnapshot(
    int selfId,
    int friendId,
  ) async =>
      const LegacyChatHistorySnapshot(messages: [], sourceRevision: 'empty');

  @override
  Future<Set<String>?> migratedEventMessageIds(
    int selfId,
    int friendId,
  ) async => const {};

  @override
  Future<bool> markEventMessagesMigrated(
    int selfId,
    int friendId,
    Set<String> messageIds, {
    required String expectedSourceRevision,
  }) async => true;

  @override
  Future<Map<String, Map<String, String>>> exportAll(
    int selfId,
    List<int> friendIds,
  ) async => {};

  @override
  Future<void> importAll(Map<String, dynamic> data) async {}

  @override
  Future<MessageHistoryPage<LegacyChatRecord>> fetchHistory(
    int friendId, {
    MessageHistoryCursor? before,
  }) async {
    requestedHistoryCursors.add(before);
    if (before != null) await historyPageGate?.future;
    if (historyPages.isEmpty) {
      return MessageHistoryPage(
        messages: const [],
        hasMore: false,
        nextCursor: null,
      );
    }
    final pageIndex = before == null
        ? 0
        : historyPages.indexWhere((page) => page.nextCursor == before) + 1;
    if (pageIndex < 0 || pageIndex >= historyPages.length) {
      throw StateError('Unexpected history cursor: $before');
    }
    return historyPages[pageIndex];
  }

  @override
  Future<LegacyChatSnapshotDownload> downloadSyncData(int friendId) async =>
      const LegacyChatSnapshotDownload(data: {});

  @override
  Future<void> acknowledgeSyncData(int friendId, String snapshotId) async {}

  @override
  Future<void> uploadSyncData(int friendId, Map<String, dynamic> data) async {}

  @override
  Future<Map<String, dynamic>> sendMessage(int friendId, String text) async => {
    'ok': true,
  };

  @override
  Future<void> recallMessage(int friendId, String messageKey) async {}
}

class _FailFirstSendTransport implements MessageTransport {
  _FailFirstSendTransport(this.delegate);

  final MessageTransport delegate;
  final sent = <MessageEvent>[];
  int connectCalls = 0;
  bool _shouldFail = true;

  @override
  Stream<MessageEvent> get events => delegate.events;

  @override
  Future<void> connect() {
    connectCalls++;
    return delegate.connect();
  }

  @override
  Future<void> send(MessageEvent event) async {
    sent.add(event);
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('temporary transport failure');
    }
    await delegate.send(event);
  }

  @override
  Future<void> disconnect() => delegate.disconnect();
}

class _ObservedMessageEventStore implements MessageEventStore {
  final events = <MessageEvent>[];
  final pending = <MessageEvent>[];
  final appendStarted = Completer<void>();
  final releaseAppend = Completer<void>();
  bool gateNextAppend = false;
  bool failNextAppend = false;

  @override
  Future<List<MessageEvent>> loadAll() async => List.unmodifiable(events);

  @override
  Future<List<MessageEvent>> loadPendingOutbox() async =>
      List.unmodifiable(pending);

  @override
  Future<void> append(MessageEvent event, {required bool pendingOutbox}) async {
    if (gateNextAppend) {
      gateNextAppend = false;
      appendStarted.complete();
      await releaseAppend.future;
    }
    if (failNextAppend) {
      failNextAppend = false;
      throw StateError('simulated durable storage failure');
    }
    if (!events.any((candidate) => candidate.eventId == event.eventId)) {
      events.add(event);
    }
    if (pendingOutbox &&
        !pending.any((candidate) => candidate.eventId == event.eventId)) {
      pending.add(event);
    }
  }

  @override
  Future<void> acknowledgeOutbox(String eventId) async {
    pending.removeWhere((event) => event.eventId == eventId);
  }
}

class _ReceiptEventTransport implements MessageReceiptTransport {
  _ReceiptEventTransport(this.initialEvent);

  final MessageEvent initialEvent;
  final _events = StreamController<MessageEvent>.broadcast();
  final acknowledgements = <bool>[];
  final firstAcknowledgement = Completer<void>();
  final secondAcknowledgement = Completer<void>();

  @override
  Stream<MessageEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    _events.add(initialEvent);
  }

  @override
  Future<void> send(MessageEvent event) async {}

  @override
  Future<void> acknowledgeReceived(
    MessageEvent event, {
    required bool accepted,
  }) async {
    acknowledgements.add(accepted);
    if (acknowledgements.length == 1 && !firstAcknowledgement.isCompleted) {
      firstAcknowledgement.complete();
    }
    if (acknowledgements.length == 2 && !secondAcknowledgement.isCompleted) {
      secondAcknowledgement.complete();
    }
  }

  void emit(MessageEvent event) => _events.add(event);

  @override
  Future<void> disconnect() async {}
}

class _FakeRelayBackend {
  final pendingRows = <int, List<Map<String, dynamic>>>{};
  var _nextPendingId = 1;

  ServerMessageTransport transportFor(
    int selfId,
    int friendId,
  ) => ServerMessageTransport(
    relayEncryptionReady: true,
    apiClient: ApiClient(
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/chat/dm/pending') {
          final senderId = int.parse(request.url.queryParameters['friendId']!);
          return http.Response(
            jsonEncode({
              'messages': (pendingRows[selfId] ?? [])
                  .where((row) => row['sender_id'] == senderId)
                  .toList(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/event')) {
          final receiverId = int.parse(
            request.url.path.split('/').elementAt(4),
          );
          final event = Map<String, dynamic>.from(
            jsonDecode(request.body)['event'] as Map,
          );
          pendingRows.putIfAbsent(receiverId, () => []).add({
            'id': _nextPendingId++,
            'sender_id': int.parse(event['actorId'] as String),
            'receiver_id': receiverId,
            'text': event['body'] ?? '',
            'created_at': event['createdAt'],
            'type': 'message',
            'event_id': event['eventId'],
            'message_id': event['messageId'],
            'event_type': event['type'],
            'revision': event['revision'],
            'signature': event['signature'],
            'device_id': event['deviceId'],
          });
          return http.Response('{}', 201);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/chat/dm/ack') {
          final ids = (jsonDecode(request.body)['ids'] as List).cast<int>();
          pendingRows[selfId]?.removeWhere((row) => ids.contains(row['id']));
          return http.Response('{}', 200);
        }
        throw StateError('Unexpected fake relay request: ${request.url}');
      }),
      credentials: _MemoryCredentials(),
    ),
    selfId: selfId,
    friendId: friendId,
    pollInterval: const Duration(minutes: 1),
  );
}

ChatService _createComposedChatService(
  MessagingCoreService core,
  DirectMessageTransportFactory transportFactory,
) {
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{}', 200)),
    credentials: _MemoryCredentials(),
  );
  final legacyStore = LocalChatRepository();
  final legacyRemote = ServerLegacyChatRemoteSource(api);
  return ChatServiceFactory(
    messagingCore: core,
    legacyDeliveryStore: legacyStore,
    legacyHistoryStore: legacyStore,
    legacySnapshotStore: legacyStore,
    legacyDeliveryRemoteSource: legacyRemote,
    legacyHistoryRemoteSource: legacyRemote,
    legacySnapshotRemoteSource: legacyRemote,
    transportFactory: transportFactory,
  ).create();
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

class _ConnectFailingTransport extends _NoopTransport {
  @override
  Future<void> connect() async {
    throw StateError('P2P unavailable');
  }
}

class _RecoversAfterFirstConnectFailureTransport extends _NoopTransport {
  int connectCalls = 0;
  final sent = <MessageEvent>[];

  @override
  Future<void> connect() async {
    connectCalls++;
    if (connectCalls == 1) throw StateError('temporary P2P outage');
  }

  @override
  Future<void> send(MessageEvent event) async {
    sent.add(event);
  }
}

class _ConnectCountingTransport extends _NoopTransport {
  int connectCalls = 0;

  @override
  Future<void> connect() async {
    connectCalls++;
  }
}

class _FailingTransport extends _NoopTransport {
  @override
  Future<void> send(MessageEvent event) async {
    throw StateError('offline');
  }
}

class _RecordingTransport implements MessageTransport {
  _RecordingTransport(this.delegate);

  final MessageTransport delegate;
  final sent = <MessageEvent>[];
  int connectCalls = 0;

  @override
  Stream<MessageEvent> get events => delegate.events;

  @override
  Future<void> connect() {
    connectCalls++;
    return delegate.connect();
  }

  @override
  Future<void> disconnect() => delegate.disconnect();

  @override
  Future<void> send(MessageEvent event) {
    sent.add(event);
    return delegate.send(event);
  }
}

class _GatedNegotiatingTransport implements NegotiatingMessageTransport {
  final prepareStarted = Completer<void>();
  final finishPrepare = Completer<void>();
  int disconnectCalls = 0;

  @override
  Stream<MessageEvent> get events => const Stream<MessageEvent>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Future<void> prepare() {
    prepareStarted.complete();
    return finishPrepare.future;
  }

  @override
  Future<void> send(MessageEvent event) async {}
}

class _CountingNegotiatingTransport implements NegotiatingMessageTransport {
  int prepareCalls = 0;

  @override
  Stream<MessageEvent> get events => const Stream<MessageEvent>.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> prepare() async {
    prepareCalls++;
  }

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

class _TestAuthenticator implements EventAuthenticator {
  @override
  Future<String> sign(MessageEvent event) async => 'test-signature';

  @override
  Future<bool> verify(MessageEvent event) async =>
      event.signature == 'test-signature';
}
