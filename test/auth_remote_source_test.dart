import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'server auth adapter owns session and profile endpoint encoding',
    () async {
      final requests = <String>[];
      final client = ApiClient(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path} ${request.body}');
          return http.Response(
            jsonEncode(<String, dynamic>{}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        credentials: _MemoryCredentials(),
      );
      final source = ServerAuthRemoteSource(client);

      await source.verifyGoogleToken('token');
      await source.updateProfile({'name': 'Alice'});
      await source.updateLocale('zh-TW');
      await source.logout();

      expect(requests, [
        'POST /api/google-login {"id_token":"token"}',
        'PUT /api/users/me {"name":"Alice"}',
        'PUT /api/users/locale {"locale":"zh-TW"}',
        'POST /api/logout {}',
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
