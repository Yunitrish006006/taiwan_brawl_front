import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/pending_notification_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('server source maps event rows through the neutral source contract', () {
    final source = ServerPendingNotificationSource(
      ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      ),
    );
    final PendingNotificationSource neutralSource = source;

    final event = neutralSource.eventFromPendingRow(
      {
        'id': 31,
        'sender_id': 9,
        'event_id': 'event-31',
        'message_id': 'message-7',
        'event_type': 'edited',
        'revision': 2,
        'created_at': '2026-10-28T09:00:00.000Z',
        'text': 'edited body',
      },
      selfId: 1,
      friendId: 9,
    );

    expect(event, isNotNull);
    expect(event!.eventId, 'event-31');
    expect(event.conversationId, '1:9');
    expect(event.type, MessageEventType.edited);
    expect(event.body, 'edited body');
    source.dispose();
  });

  test('delegates rows and acknowledges only handled notifications', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/pending')) {
        return http.Response(
          jsonEncode({
            'messages': [
              {'id': 1, 'sender_id': 9, 'text': 'hello'},
              {'id': 2, 'sender_id': 8, 'text': 'active'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200);
    });
    final source = ServerPendingNotificationSource(
      ApiClient(client: client, credentials: _MemoryCredentials()),
    );
    final handled = <Map<String, dynamic>>[];

    await source.poll(
      selfId: 1,
      activeConversationUserId: 8,
      onItem: (item) async {
        handled.add(item);
        return [item['id'] as int];
      },
    );

    expect(handled, hasLength(1));
    expect(handled.single['sender_id'], 9);
    final ack = requests.singleWhere(
      (request) => request.url.path.endsWith('/ack'),
    );
    expect(jsonDecode(ack.body), {
      'ids': [1],
    });
    source.dispose();
  });

  test(
    'registers the current device before the first pending poll and ACK',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/pending')) {
          return http.Response(
            jsonEncode({
              'messages': [
                {'id': 7, 'sender_id': 9, 'text': 'hello'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final source = ServerPendingNotificationSource(
        ApiClient(client: client, credentials: _MemoryCredentials()),
        deviceId: 'pixel-7a',
      );

      await source.poll(
        selfId: 1,
        activeConversationUserId: null,
        onItem: (item) async => [item['id'] as int],
      );

      expect(requests.first.method, 'POST');
      expect(requests.first.url.path, '/api/chat/dm/device-register');
      expect(jsonDecode(requests.first.body), {'deviceId': 'pixel-7a'});
      final pending = requests.singleWhere(
        (request) => request.url.path.endsWith('/pending'),
      );
      expect(pending.url.queryParameters['deviceId'], 'pixel-7a');
      final ack = requests.singleWhere(
        (request) => request.url.path.endsWith('/ack'),
      );
      expect(jsonDecode(ack.body), {
        'ids': [7],
        'deviceId': 'pixel-7a',
      });
      await source.poll(
        selfId: 1,
        activeConversationUserId: null,
        onItem: (_) async => [],
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/device-register')),
        hasLength(1),
      );
      await source.poll(
        selfId: 2,
        activeConversationUserId: null,
        onItem: (_) async => [],
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/device-register')),
        hasLength(2),
      );
      source.dispose();
    },
  );

  test('a revoked device is never polled or repeatedly registered', () async {
    final requests = <http.Request>[];
    final source = ServerPendingNotificationSource(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'error': 'Device was revoked'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
        credentials: _MemoryCredentials(),
      ),
      deviceId: 'revoked-device',
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      await source.poll(
        selfId: 1,
        activeConversationUserId: null,
        onItem: (_) async => throw StateError('revoked device received a row'),
      );
    }
    expect(requests.single.url.path, '/api/chat/dm/device-register');
    source.dispose();
  });

  test('does not acknowledge rows when the consumer fails', () async {
    var ackCalled = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/pending')) {
        return http.Response(
          jsonEncode({
            'messages': [
              {'id': 1, 'sender_id': 9, 'text': 'hello'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      ackCalled = true;
      return http.Response('{}', 200);
    });
    final source = ServerPendingNotificationSource(
      ApiClient(client: client, credentials: _MemoryCredentials()),
    );

    await expectLater(
      source.poll(
        selfId: 1,
        activeConversationUserId: null,
        onItem: (_) async => throw StateError('local store unavailable'),
      ),
      throwsStateError,
    );

    expect(ackCalled, isFalse);
    source.dispose();
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
