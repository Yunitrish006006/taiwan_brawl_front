import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/notification_remote_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'server notification adapter owns notification endpoint encoding',
    () async {
      final requests = <String>[];
      final client = ApiClient(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path} ${request.body}');
          return http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? <String, dynamic>{'config': <String, dynamic>{}}
                  : <String, dynamic>{},
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        credentials: _MemoryCredentials(),
      );
      final source = ServerNotificationRemoteSource(client);

      await source.loadConfiguration();
      await source.registerDevice({'installationId': 'installation'});
      await source.unregisterDevice({'installationId': 'installation'});

      expect(requests, [
        'GET /api/notifications/config ',
        'POST /api/notifications/register {"installationId":"installation"}',
        'POST /api/notifications/unregister {"installationId":"installation"}',
      ]);
    },
  );
}

class _MemoryCredentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}
