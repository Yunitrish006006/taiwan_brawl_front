import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class _MemoryRemotePort implements MiniRoyaleRemotePort {
  Map<String, dynamic>? capturedJoinBody;

  @override
  Future<Map<String, dynamic>> postRoomAction(
    String roomCode,
    String action,
    Map<String, dynamic> body,
  ) async {
    expect(roomCode, 'ROOM42');
    expect(action, 'join');
    capturedJoinBody = body;
    return {
      'room': {'code': roomCode, 'status': 'lobby', 'players': []},
    };
  }

  @override
  Future<MiniRoyaleRoomConnection> connectToRoom(
    String roomCode,
    Map<String, Object> gameContract,
  ) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('module manifest version stays aligned with the package release', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final packageVersion = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(packageVersion, isNotNull);
    expect(miniRoyaleManifest.packageVersion, packageVersion);
    expect(miniRoyaleGameContract['moduleVersion'], packageVersion);
  });

  test('Mini Royale owns a stable module and multiplayer contract', () {
    expect(miniRoyaleModuleId, 'game.mini-royale');
    expect(miniRoyaleManifest.compatibleProtocolRange, '>=1 <2');
    expect(miniRoyaleGameContract['compatibleProtocolRange'], '>=1 <2');
    expect(miniRoyaleManifest.rulesetId, 'mini-royale-ranked');
    expect(miniRoyaleManifest.toJson()['multiplayer'], {
      'protocolVersion': 1,
      'compatibleProtocolRange': '>=1 <2',
      'rulesetId': 'mini-royale-ranked',
      'rulesetVersion': 1,
      'gameplayContentDigest': 'builtin-royale-rules-v1',
    });
    expect(miniRoyalePackageVersion, '0.1.0');
    expect(miniRoyaleGameContract['moduleVersion'], miniRoyalePackageVersion);
    expect(miniRoyaleGameContract['rulesetId'], miniRoyaleManifest.rulesetId);
    expect(miniRoyaleManifest.toJson()['moduleId'], miniRoyaleModuleId);
    expect(miniRoyaleManifest.toJson()['manifestVersion'], 1);
    expect(miniRoyaleManifest.toJson()['kind'], 'game');
    expect(miniRoyaleManifest.toJson()['publisher'], 'taiwan-brawl');
    expect(miniRoyaleManifest.toJson()['hostApiRange'], '>=1.0.0 <2.0.0');
    expect(miniRoyaleManifest.toJson()['dependencies'], isEmpty);
    expect(miniRoyaleManifest.dataSchemaVersion, 1);
    expect(miniRoyaleManifest.platforms, miniRoyaleSupportedPlatforms);
    expect(isCompatibleMiniRoyaleContract(miniRoyaleGameContract), isTrue);
    expect(
      isCompatibleMiniRoyaleContract({
        ...miniRoyaleGameContract,
        'gameplayContentDigest': 'stale-content',
      }),
      isFalse,
    );
    expect(
      isCompatibleMiniRoyaleContract({
        ...miniRoyaleGameContract,
        'protocolVersion': 0,
      }),
      isFalse,
    );
    final futureProtocol = {
      ...miniRoyaleGameContract,
      'moduleVersion': '0.2.0',
      'protocolVersion': 2,
      'compatibleProtocolRange': '>=1 <3',
    };
    final olderCompatibleClient = {
      ...miniRoyaleGameContract,
      'compatibleProtocolRange': '>=1 <3',
    };
    expect(
      isCompatibleMiniRoyaleContract(olderCompatibleClient, futureProtocol),
      isTrue,
    );
    expect(
      isCompatibleMiniRoyaleContract({
        ...olderCompatibleClient,
        'compatibleProtocolRange': '>=1 <2',
      }, futureProtocol),
      isFalse,
    );
  });

  test(
    'game-owned service submits its compatibility contract before joining',
    () async {
      final remote = _MemoryRemotePort();
      final service = MiniRoyaleService(
        remotePort: remote,
        apiBaseUrl: 'https://example.test',
      );
      await service.joinRoom(roomCode: 'ROOM42', deckId: 8);
      expect(remote.capturedJoinBody?['gameContract'], miniRoyaleGameContract);
    },
  );

  test('game-owned service submits the active content digest', () async {
    final remote = _MemoryRemotePort();
    final contract = {
      ...miniRoyaleGameContract,
      'gameplayContentDigest': 'installed-pack-set-digest',
    };
    final service = MiniRoyaleService(
      remotePort: remote,
      apiBaseUrl: 'https://example.test',
      gameContractProvider: () => contract,
    );

    await service.joinRoom(roomCode: 'ROOM42', deckId: 8);

    expect(remote.capturedJoinBody?['gameContract'], contract);
  });
}
