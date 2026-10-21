import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/pending_notification_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
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
    final ack = requests.singleWhere((request) => request.url.path.endsWith('/ack'));
    expect(jsonDecode(ack.body), {'ids': [1]});
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
