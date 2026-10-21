import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/server_message_transport.dart';

void main() {
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
    final cursorStore = _MemoryCursorStore()..values['dm:2:9'] = '4';
    final client = MockClient((request) async {
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
      return http.Response('{}', 200);
    });
    final api = ApiClient(client: client, credentials: _MemoryCredentials());
    final transport = ServerMessageTransport(
      apiClient: api,
      selfId: 2,
      friendId: 9,
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
    expect(pendingUri?.queryParameters['afterId'], '4');
    expect(cursorStore.values['dm:2:9'], '7');
    await subscription.cancel();
    await transport.dispose();
  });
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
