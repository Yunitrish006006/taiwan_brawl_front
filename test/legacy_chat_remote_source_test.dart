import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/models/message_history_page.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/legacy_chat_remote_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('server adapter owns legacy chat endpoint encoding', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/history')) {
        return http.Response(
          jsonEncode({
            'messages': [
              {
                'sender_id': 9,
                'receiver_id': 2,
                'text': 'wire history',
                'created_at': '2026-10-28T00:00:00.000Z',
                'id': 71,
                'isPending': true,
                'isRecalled': true,
              },
            ],
            'hasMore': true,
            'nextCursor': {'createdAt': '2026-10-28T00:00:00.000Z', 'id': 71},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/sync-download-v2')) {
        return http.Response(
          jsonEncode({'chat_1_2': {}}),
          200,
          headers: {'x-chat-snapshot-id': 'snapshot-123'},
        );
      }
      return http.Response(jsonEncode({'ok': true, 'createdAt': 'now'}), 200);
    });
    final source = ServerLegacyChatRemoteSource(
      ApiClient(client: client, credentials: _MemoryCredentials()),
      allowPlaintextCompatibilityWrites: true,
    );

    const cursor = MessageHistoryCursor(
      createdAt: '2026-10-28T00:00:00.000Z',
      rowId: 72,
    );
    final history = await source.fetchHistory(2, before: cursor);
    expect(history.messages, hasLength(1));
    expect(history.messages.single.senderId, 9);
    expect(history.messages.single.receiverId, 2);
    expect(history.messages.single.text, 'wire history');
    expect(history.messages.single.pendingId, 71);
    expect(history.messages.single.isPending, isFalse);
    expect(history.messages.single.isRecalled, isFalse);
    expect(history.hasMore, isTrue);
    expect(
      history.nextCursor,
      const MessageHistoryCursor(
        createdAt: '2026-10-28T00:00:00.000Z',
        rowId: 71,
      ),
    );
    await source.uploadSyncData(2, {'chat_1_2': {}});
    final snapshot = await source.downloadSyncData(2);
    expect(snapshot.data, containsPair('chat_1_2', isA<Map>()));
    expect(snapshot.snapshotId, 'snapshot-123');
    await source.acknowledgeSyncData(2, 'snapshot-123');
    expect(await source.sendMessage(2, 'hello'), containsPair('ok', true));
    await source.recallMessage(2, 'message-key');

    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'GET',
      'POST',
      'POST',
      'POST',
    ]);
    expect(requests.first.url.queryParameters['before'], cursor.createdAt);
    expect(requests.first.url.queryParameters['beforeId'], '72');
    expect(requests.first.url.path, '/api/chat/dm/2/history');
    expect(requests[2].url.path, '/api/chat/dm/2/sync-download-v2');
    expect(requests[3].url.path, '/api/chat/dm/2/sync-ack');
  });

  test('plaintext legacy writes fail closed by default', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });
    final source = ServerLegacyChatRemoteSource(
      ApiClient(client: client, credentials: _MemoryCredentials()),
    );

    await expectLater(source.sendMessage(2, 'secret'), throwsStateError);
    await expectLater(source.recallMessage(2, 'message-1'), throwsStateError);
    await expectLater(
      source.uploadSyncData(2, {'chat_1_2': {'message': 'secret'}}),
      throwsStateError,
    );

    expect(requests, isEmpty);
  });

  test('falls back to the one-shot sync endpoint on older servers', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/sync-download-v2')) {
        return http.Response('{}', 404);
      }
      return http.Response(jsonEncode({'chat_1_2': {}}), 200);
    });
    final source = ServerLegacyChatRemoteSource(
      ApiClient(client: client, credentials: _MemoryCredentials()),
    );

    final snapshot = await source.downloadSyncData(2);

    expect(snapshot.data, containsPair('chat_1_2', isA<Map>()));
    expect(snapshot.snapshotId, isNull);
    expect(requests.map((request) => request.url.path), [
      '/api/chat/dm/2/sync-download-v2',
      '/api/chat/dm/2/sync-download',
    ]);
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
