import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/server_message_transport.dart';
import 'package:taiwan_brawl/services/aes_gcm_conversation_encryptor.dart';

void main() {
  test('explicit relay requires a key for the current conversation', () async {
    const keyId = 'v1';
    ServerMessageTransport create(
      ConversationKeyResolver resolver,
    ) => ServerMessageTransport(
      apiClient: ApiClient(
        client: MockClient((_) async {
          fail('Checking the conversation key must not make a server request');
        }),
      ),
      selfId: 2,
      friendId: 1,
      relayEncryptionReady: true,
      conversationKeyId: keyId,
      conversationKeyResolver: resolver,
      conversationEncryptor: AesGcmConversationEncryptor(keyResolver: resolver),
    );
    final missing = create(
      InMemoryConversationKeyResolver({'1:3:$keyId': List.filled(32, 7)}),
    );
    final paired = create(
      InMemoryConversationKeyResolver({'1:2:$keyId': List.filled(32, 7)}),
    );
    addTearDown(missing.dispose);
    addTearDown(paired.dispose);

    await expectLater(missing.ensureRelayEncryptionReady(), throwsStateError);
    await paired.ensureRelayEncryptionReady();
  });

  test('ignores a pending response received after relay disconnects', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    var requests = 0;
    final transport = ServerMessageTransport(
      apiClient: ApiClient(
        client: MockClient((_) async {
          if (requests++ == 0) return http.Response('{"messages":[]}', 200);
          if (!requested.isCompleted) requested.complete();
          return response.future;
        }),
        credentials: _MemoryCredentials(),
      ),
      selfId: 1,
      friendId: 2,
    );
    final delivered = <MessageEvent>[];
    final subscription = transport.events.listen(delivered.add);
    addTearDown(subscription.cancel);
    addTearDown(transport.dispose);

    await transport.connect();
    final poll = transport.pollNow();
    await requested.future;
    await transport.disconnect();
    response.complete(
      http.Response(
        '{"messages":[{"id":1,"sender_id":2,"text":"late","created_at":"2026-11-20T09:00:00Z"}]}',
        200,
      ),
    );
    await poll;
    expect(delivered, isEmpty);
  });

  test('converts new pending event rows without losing envelope metadata', () {
    final event = ServerMessageTransport.eventFromPendingRow(
      {
        'id': 4,
        'sender_id': 9,
        'receiver_id': 2,
        'text': 'hello',
        'created_at': '2026-10-20T00:00:00.000Z',
        'type': 'message',
        'event_id': 'e1',
        'message_id': 'm1',
        'event_type': 'created',
        'revision': 0,
      },
      selfId: 2,
      friendId: 9,
    );

    expect(event?.eventId, 'e1');
    expect(event?.messageId, 'm1');
    expect(event?.conversationId, '2:9');
  });

  test('converts legacy recall rows deterministically', () {
    final event = ServerMessageTransport.eventFromPendingRow(
      {
        'id': 7,
        'sender_id': 9,
        'text': '2026-10-20T00:00:00.000Z_9',
        'created_at': '2026-10-20T00:01:00.000Z',
        'type': 'recall',
      },
      selfId: 2,
      friendId: 9,
    );

    expect(event?.type.name, 'recalled');
    expect(event?.messageId, '2026-10-20T00:00:00.000Z_9');
    expect(event?.eventId, 'legacy:7');
  });

  test('rejects an unknown event type instead of projecting it as created', () {
    final event = ServerMessageTransport.eventFromPendingRow(
      {
        'sender_id': 9,
        'created_at': '2026-10-20T00:00:00.000Z',
        'event_id': 'e1',
        'message_id': 'm1',
        'event_type': 'unknown',
      },
      selfId: 2,
      friendId: 9,
    );

    expect(event, isNull);
  });

  test('posts edit and recall events to the shared event endpoint', () async {
    final postedEvents = <Map<String, dynamic>>[];
    final keyId = 'conversation-key-1';
    final encryptor = AesGcmConversationEncryptor(
      keyResolver: InMemoryConversationKeyResolver({
        '1:2:$keyId': InMemoryConversationKeyResolver.deterministicKey(7),
      }),
    );
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'messages': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/chat/dm/2/event');
      postedEvents.add(
        Map<String, dynamic>.from(jsonDecode(request.body)['event'] as Map),
      );
      return http.Response('{}', 201);
    });
    final transport = ServerMessageTransport(
      apiClient: ApiClient(client: client, credentials: _MemoryCredentials()),
      selfId: 1,
      friendId: 2,
      relayEncryptionReady: true,
      conversationEncryptor: encryptor,
      conversationKeyId: keyId,
    );
    await transport.connect();

    for (final type in [MessageEventType.edited, MessageEventType.recalled]) {
      await transport.send(
        MessageEvent(
          eventId: 'event-${type.name}',
          messageId: 'message-1',
          conversationId: '1:2',
          actorId: '1',
          type: type,
          revision: type == MessageEventType.edited ? 1 : 2,
          createdAt: DateTime.utc(2026, 10, 21),
          body: type == MessageEventType.edited ? 'updated' : null,
        ),
      );
    }

    expect(postedEvents.map((event) => event['type']), ['edited', 'recalled']);
    expect(postedEvents.map((event) => event['messageId']), [
      'message-1',
      'message-1',
    ]);
    await transport.dispose();
  });

  test(
    'encrypted relay posts ciphertext and decrypts it during polling',
    () async {
      final keyId = 'conversation-key-1';
      final encryptor = AesGcmConversationEncryptor(
        keyResolver: InMemoryConversationKeyResolver({
          '1:2:$keyId': InMemoryConversationKeyResolver.deterministicKey(7),
        }),
      );
      Map<String, dynamic>? postedEvent;
      Map<String, dynamic>? pendingRow;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'messages': pendingRow == null ? <Object>[] : [pendingRow],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/event')) {
          postedEvent = Map<String, dynamic>.from(
            jsonDecode(request.body)['event'] as Map,
          );
          pendingRow = {
            'id': 11,
            'sender_id': 2,
            'receiver_id': 1,
            'text': jsonEncode({
              'encryptedBody': postedEvent!['encryptedBody'],
            }),
            'created_at': postedEvent!['createdAt'],
            'type': 'message',
            'event_id': postedEvent!['eventId'],
            'message_id': postedEvent!['messageId'],
            'event_type': postedEvent!['type'],
            'revision': postedEvent!['revision'],
            'signature': postedEvent!['signature'],
            'device_id': postedEvent!['deviceId'],
          };
          return http.Response('{}', 201);
        }
        return http.Response('{}', 200);
      });
      final transport = ServerMessageTransport(
        apiClient: ApiClient(client: client, credentials: _MemoryCredentials()),
        selfId: 1,
        friendId: 2,
        deviceId: 'device-1',
        relayEncryptionReady: true,
        conversationEncryptor: encryptor,
        conversationKeyId: keyId,
      );
      await transport.connect();
      final eventFuture = transport.events.first;
      await transport.send(
        MessageEvent(
          eventId: 'event-1',
          messageId: 'message-1',
          conversationId: '1:2',
          actorId: '1',
          deviceId: 'device-1',
          type: MessageEventType.created,
          revision: 0,
          createdAt: DateTime.utc(2026, 11, 12),
          body: 'secret relay message',
        ),
      );
      expect(postedEvent?['body'], isNull);
      expect(postedEvent?['encryptedBody'], isA<Map>());
      await transport.pollNow();
      expect((await eventFuture).body, 'secret relay message');
      await transport.dispose();
    },
  );

  test(
    'blocks relay event writes when end-to-end encryption is not ready',
    () async {
      var eventPostCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/api/chat/dm/device-register')) {
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/api/chat/dm/pending')) {
          return http.Response(jsonEncode({'messages': <Object>[]}), 200);
        }
        if (request.url.path.endsWith('/event')) eventPostCount++;
        return http.Response('{}', 200);
      });
      final transport = ServerMessageTransport(
        apiClient: ApiClient(client: client, credentials: _MemoryCredentials()),
        selfId: 1,
        friendId: 2,
        deviceId: 'device-1',
        relayEncryptionReady: false,
      );
      await transport.connect();
      await expectLater(
        transport.send(
          MessageEvent(
            eventId: 'event-1',
            messageId: 'message-1',
            conversationId: '1:2',
            actorId: '1',
            type: MessageEventType.created,
            revision: 0,
            createdAt: DateTime.utc(2026, 10, 28),
            body: 'secret',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('end-to-end message encryption'),
          ),
        ),
      );
      expect(eventPostCount, 0);
      await transport.dispose();
    },
  );

  test(
    'never falls back to plaintext when the conversation key is missing',
    () async {
      var eventPostCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/api/chat/dm/device-register')) {
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/api/chat/dm/pending')) {
          return http.Response(jsonEncode({'messages': <Object>[]}), 200);
        }
        if (request.url.path.endsWith('/event')) eventPostCount++;
        return http.Response('{}', 200);
      });
      final transport = ServerMessageTransport(
        apiClient: ApiClient(client: client, credentials: _MemoryCredentials()),
        selfId: 1,
        friendId: 2,
        deviceId: 'device-1',
        relayEncryptionReady: true,
        conversationEncryptor: AesGcmConversationEncryptor(
          keyResolver: InMemoryConversationKeyResolver(const {}),
        ),
        conversationKeyId: 'conversation-key-v1',
      );
      await transport.connect();

      await expectLater(
        transport.send(
          MessageEvent(
            eventId: 'event-missing-key',
            messageId: 'message-missing-key',
            conversationId: '1:2',
            actorId: '1',
            deviceId: 'device-1',
            type: MessageEventType.created,
            revision: 0,
            createdAt: DateTime.utc(2026, 11, 12),
            body: 'must not become plaintext',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(eventPostCount, 0);
      await transport.dispose();
    },
  );

  test('reconstructs edit and recall rows as events on the receiving side', () {
    for (final type in ['edited', 'recalled']) {
      final event = ServerMessageTransport.eventFromPendingRow(
        {
          'id': type == 'edited' ? 8 : 9,
          'sender_id': 1,
          'receiver_id': 2,
          'text': type == 'edited' ? 'updated' : '',
          'created_at': '2026-10-21T00:00:00.000Z',
          'type': type == 'edited' ? 'edit' : 'recall',
          'event_id': 'event-$type',
          'message_id': 'message-1',
          'event_type': type,
          'revision': type == 'edited' ? 1 : 2,
        },
        selfId: 2,
        friendId: 1,
      );

      expect(event?.type.name, type);
      expect(event?.messageId, 'message-1');
    }
  });

  test('does not overlap periodic and recovery polls', () async {
    var pendingCalls = 0;
    final release = Completer<void>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/chat/dm/pending')) {
        pendingCalls++;
        if (pendingCalls == 2) await release.future;
        return http.Response(
          jsonEncode({'messages': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200);
    });
    final api = ApiClient(client: client, credentials: _MemoryCredentials());
    final transport = ServerMessageTransport(
      apiClient: api,
      selfId: 1,
      friendId: 2,
    );

    await transport.connect();
    final first = transport.pollNow();
    await Future<void>.delayed(Duration.zero);
    final second = transport.pollNow();
    release.complete();
    await Future.wait([first, second]);

    expect(pendingCalls, 2);
    await transport.dispose();
  });

  test('uses and commits a durable friend-scoped relay cursor', () async {
    Uri? pendingUri;
    Map<String, dynamic>? registration;
    Map<String, dynamic>? ackBody;
    final cursorStore = _MemoryCursorStore()
      ..values['dm:2:device-phone:9'] = '4';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/chat/dm/device-register')) {
        registration = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        return http.Response('{}', 200);
      }
      if (request.url.path.endsWith('/api/chat/dm/pending')) {
        pendingUri = request.url;
        return http.Response(
          jsonEncode({
            'messages': [
              {
                'id': 7,
                'sender_id': 9,
                'receiver_id': 2,
                'text': 'hello',
                'created_at': '2026-10-20T00:00:00.000Z',
                'type': 'message',
                'event_id': 'e1',
                'message_id': 'm1',
                'event_type': 'created',
                'revision': 0,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/api/chat/dm/ack')) {
        ackBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      }
      return http.Response('{}', 200);
    });
    final api = ApiClient(client: client, credentials: _MemoryCredentials());
    final transport = ServerMessageTransport(
      apiClient: api,
      selfId: 2,
      friendId: 9,
      deviceId: 'device-phone',
      syncCursorStore: cursorStore,
    );
    final acknowledged = Completer<void>();
    final subscription = transport.events.listen((event) async {
      await transport.acknowledgeReceived(event, accepted: true);
      acknowledged.complete();
    });

    await transport.connect();
    await acknowledged.future;

    expect(pendingUri?.queryParameters['friendId'], '9');
    expect(pendingUri?.queryParameters['deviceId'], 'device-phone');
    expect(pendingUri?.queryParameters['afterId'], '4');
    expect(registration, {'deviceId': 'device-phone'});
    expect(ackBody?['deviceId'], 'device-phone');
    expect(cursorStore.values['dm:2:device-phone:9'], '7');
    await subscription.cancel();
    await transport.dispose();
  });

  test(
    'recreated relay transport resumes after the last durable ack',
    () async {
      final pendingUris = <Uri>[];
      final cursorStore = _MemoryCursorStore()..values['dm:2:9'] = '4';
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/api/chat/dm/pending')) {
          pendingUris.add(request.url);
          final afterId = request.url.queryParameters['afterId'];
          return http.Response(
            jsonEncode({
              'messages': afterId == '4'
                  ? [
                      {
                        'id': 7,
                        'sender_id': 9,
                        'receiver_id': 2,
                        'text': 'resume after restart',
                        'created_at': '2026-10-20T00:00:00.000Z',
                        'type': 'message',
                        'event_id': 'restart-event',
                        'message_id': 'restart-message',
                        'event_type': 'created',
                        'revision': 0,
                      },
                    ]
                  : [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final api = ApiClient(client: client, credentials: _MemoryCredentials());
      final first = ServerMessageTransport(
        apiClient: api,
        selfId: 2,
        friendId: 9,
        syncCursorStore: cursorStore,
      );
      final firstReceived = Completer<void>();
      final firstSubscription = first.events.listen((event) async {
        await first.acknowledgeReceived(event, accepted: true);
        firstReceived.complete();
      });

      await first.connect();
      await firstReceived.future;
      await firstSubscription.cancel();
      await first.dispose();

      final afterRestart = ServerMessageTransport(
        apiClient: api,
        selfId: 2,
        friendId: 9,
        syncCursorStore: cursorStore,
      );
      await afterRestart.connect();

      expect(pendingUris.map((uri) => uri.queryParameters['afterId']), [
        '4',
        '7',
      ]);
      expect(cursorStore.values['dm:2:9'], '7');
      await afterRestart.dispose();
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

class _MemoryCursorStore implements MessageSyncCursorStore {
  final values = <String, String>{};

  @override
  Future<String?> loadSyncCursor(String scope) async => values[scope];

  @override
  Future<void> saveSyncCursor(String scope, String cursor) async {
    values[scope] = cursor;
  }
}
