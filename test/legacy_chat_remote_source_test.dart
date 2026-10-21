import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/legacy_chat_remote_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('server adapter owns legacy chat endpoint encoding', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/history')) {
        return http.Response(jsonEncode({'messages': []}), 200);
      }
      if (request.url.path.endsWith('/sync-download')) {
        return http.Response(jsonEncode({'chat_1_2': {}}), 200);
      }
      return http.Response(jsonEncode({'ok': true, 'createdAt': 'now'}), 200);
    });
    final source = ServerLegacyChatRemoteSource(
      ApiClient(client: client, credentials: _MemoryCredentials()),
    );

    expect(await source.fetchHistory(2, before: 'older than'), isEmpty);
    await source.uploadSyncData(2, {'chat_1_2': {}});
    expect(await source.downloadSyncData(2), containsPair('chat_1_2', isA<Map>()));
    expect(await source.sendMessage(2, 'hello'), containsPair('ok', true));
    await source.recallMessage(2, 'message-key');

    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'GET',
      'POST',
      'POST',
    ]);
    expect(requests.first.url.queryParameters['before'], 'older than');
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
