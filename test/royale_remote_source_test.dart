import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/royale_remote_source.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('server Royale adapter owns room and deck endpoint encoding', () async {
    final requests = <String>[];
    final client = ApiClient(
      client: MockClient((request) async {
        final query = request.url.hasQuery ? '?${request.url.query}' : '';
        requests.add(
          '${request.method} ${request.url.path}$query ${request.body}',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{'cards': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      credentials: _MemoryCredentials(),
    );
    final source = ServerRoyaleRemoteSource(client);

    await source.fetchCards();
    await source.fetchHeroes();
    await source.fetchProgression();
    await source.fetchDeckSummaries();
    await source.saveDeck({'name': 'starter', 'slot': 1});
    await source.createRoom({'gameContract': const {}});
    await source.postRoomAction('ROOM42', 'ready', {});
    await source.fetchRoomState('ROOM42');

    expect(requests, [
      'GET /api/games/mini-royale/v1/cards ',
      'GET /api/games/mini-royale/v1/heroes ',
      'GET /api/games/mini-royale/v1/progression ',
      'GET /api/games/mini-royale/v1/decks?summary=1 ',
      'POST /api/games/mini-royale/v1/decks {"name":"starter","slot":1}',
      'POST /api/games/mini-royale/v1/rooms {"gameContract":{}}',
      'POST /api/games/mini-royale/v1/rooms/ROOM42/ready {}',
      'GET /api/games/mini-royale/v1/rooms/ROOM42/state ',
    ]);
  });

  test('maps host API failures to the package-owned service error', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'GAME_VERSION_INCOMPATIBLE',
            'detail': 'Install the required pack.',
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
      credentials: _MemoryCredentials(),
    );
    final source = ServerRoyaleRemoteSource(client);

    await expectLater(
      source.fetchRoomState('ROOM42'),
      throwsA(
        isA<MiniRoyaleServiceException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.message,
              'message',
              'GAME_VERSION_INCOMPATIBLE',
            )
            .having(
              (error) => error.responseBody?['detail'],
              'detail',
              'Install the required pack.',
            ),
      ),
    );
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
