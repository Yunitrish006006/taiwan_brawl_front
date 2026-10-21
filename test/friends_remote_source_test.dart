import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/friends_remote_source.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'server friends adapter owns search and relationship endpoint encoding',
    () async {
      final requests = <String>[];
      final client = ApiClient(
        client: MockClient((request) async {
          requests.add(
            '${request.method} ${request.url.path}?${request.url.query} ${request.body}',
          );
          return http.Response(
            jsonEncode(<String, dynamic>{'results': <Object>[]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        credentials: _MemoryCredentials(),
      );
      final source = ServerFriendsRemoteSource(client);

      await source.searchByName('A B');
      await source.sendFriendRequest(7);
      await source.sendRoomInvite(
        gameId: 'game.mini-royale',
        roomCode: 'ROOM42',
        inviteeUserId: 8,
      );
      await source.acceptRoomInvite(9);

      expect(requests, [
        'GET /api/friends/search?query=A+B ',
        'POST /api/friends/requests? {"targetUserId":7}',
        'POST /api/games/mini-royale/v1/rooms/ROOM42/invite? {"inviteeUserId":8}',
        'POST /api/room-invites/9/accept? {}',
      ]);
    },
  );

  test('room invite route is derived from the owning game ID', () async {
    final paths = <String>[];
    final client = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      credentials: _MemoryCredentials(),
    );
    final source = ServerFriendsRemoteSource(client);

    await source.sendRoomInvite(
      gameId: 'game.archery',
      roomCode: 'ROOM42',
      inviteeUserId: 8,
    );

    expect(paths, ['/api/games/archery/v1/rooms/ROOM42/invite']);
  });

  test(
    'malformed game identity is rejected before an invite request',
    () async {
      final client = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        credentials: _MemoryCredentials(),
      );
      final source = ServerFriendsRemoteSource(client);

      await expectLater(
        source.sendRoomInvite(
          gameId: '../rooms',
          roomCode: 'ROOM42',
          inviteeUserId: 8,
        ),
        throwsArgumentError,
      );
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
