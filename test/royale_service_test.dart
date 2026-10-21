import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/royale_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('uses the injected room channel factory', () async {
    ApiClient.clearMobileSession();
    Uri? capturedUri;
    Map<String, dynamic>? capturedHeaders;
    final service = RoyaleService(
      ApiClient(credentials: _MemoryCredentials()),
      gameContractProvider: () => {
        'gameId': 'game.mini-royale',
        'moduleVersion': '0.1.0',
        'protocolVersion': 1,
        'rulesetId': 'mini-royale-ranked',
        'rulesetVersion': 1,
        'gameplayContentDigest': 'a' * 64,
      },
      channelFactory: (uri, {headers}) {
        capturedUri = uri;
        capturedHeaders = headers;
        throw StateError('test factory');
      },
    );

    await expectLater(
      service.connectToRoom('ROOM42'),
      throwsA(isA<StateError>()),
    );

    expect(capturedUri?.path, '/api/games/mini-royale/v1/rooms/ROOM42/ws');
    expect(
      jsonDecode(capturedUri!.queryParameters['gameContract']!)['gameplayContentDigest'],
      'a' * 64,
    );
    expect(capturedHeaders, isNull);
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
