import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/admin_remote_source.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('server admin adapter owns management endpoint paths', () async {
    final requests = <String>[];
    final client = ApiClient(
      client: MockClient((request) async {
        requests.add(
          '${request.method} ${request.url.path}?${request.url.query} ${request.body}',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'cards': <Object>[],
            'users': <Object>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      credentials: _MemoryCredentials(),
    );
    final source = ServerAdminRemoteSource(client);

    await source.searchUsers('A B');
    await source.updateUserRole(7, 'admin');
    await source.fetchCards();
    await source.uploadCardImage('knight', {'bytesBase64': 'AA=='});
    await source.deleteCardCharacterImage('knight', 'front');
    await source.uploadCardCharacterAsset('knight', 'idle', {
      'bytesBase64': 'AA==',
    });
    await source.deleteCardCharacterAsset('knight', 'idle');
    await source.uploadCardBgImage('knight', {'bytesBase64': 'AA=='});
    await source.deleteCardBgImage('knight');
    await source.deleteCardImage('knight');
    await source.deleteCard('knight');

    expect(requests, [
      'GET /api/admin/users?query=A+B ',
      'PUT /api/admin/users/7/role? {"role":"admin"}',
      'GET /api/cards? ',
      'POST /api/admin/cards/knight/image? {"bytesBase64":"AA=="}',
      'DELETE /api/admin/cards/knight/character-images/front? ',
      'POST /api/admin/cards/knight/character-assets/idle? {"bytesBase64":"AA=="}',
      'DELETE /api/admin/cards/knight/character-assets/idle? ',
      'POST /api/admin/cards/knight/bg-image? {"bytesBase64":"AA=="}',
      'DELETE /api/admin/cards/knight/bg-image? ',
      'DELETE /api/admin/cards/knight/image? ',
      'DELETE /api/admin/cards/knight? ',
    ]);
  });
}

class _MemoryCredentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}
