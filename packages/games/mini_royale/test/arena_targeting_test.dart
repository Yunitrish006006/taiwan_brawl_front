import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

RoyaleCard _card({
  required String type,
  int attackRange = 0,
  int bodyRadius = 0,
  int spellRadius = 0,
}) => RoyaleCard.fromJson({
  'id': 'targeting-$type',
  'name': type,
  'type': type,
  'hp': 10,
  'damage': 1,
  'attackRange': attackRange,
  'bodyRadius': bodyRadius,
  'moveSpeed': 1,
  'attackSpeed': 1,
  'spawnCount': 1,
  'spellRadius': spellRadius,
  'spellDamage': 0,
  'targetRule': 'ground',
}, apiBaseUrl: 'https://game.example');

void main() {
  test('normalizes in-bounds board points and rejects invalid geometry', () {
    expect(
      miniRoyaleNormalizeBoardPoint(
        localPoint: const Offset(50, 25),
        boardSize: const Size(200, 100),
      ),
      const Offset(0.25, 0.25),
    );
    expect(
      miniRoyaleNormalizeBoardPoint(
        localPoint: const Offset(200, 100),
        boardSize: const Size(200, 100),
      ),
      const Offset(1, 1),
    );
    expect(
      miniRoyaleNormalizeBoardPoint(
        localPoint: const Offset(201, 50),
        boardSize: const Size(200, 100),
      ),
      isNull,
    );
    expect(
      miniRoyaleNormalizeBoardPoint(
        localPoint: Offset.zero,
        boardSize: const Size(0, 100),
      ),
      isNull,
    );
  });

  test('deployment-zone legality is part of the game targeting contract', () {
    expect(miniRoyaleIsLegalDeployPoint(const Offset(0.5, 0.8)), isTrue);
    expect(miniRoyaleIsLegalDeployPoint(const Offset(0.5, 0.2)), isFalse);
  });

  test("lane positions are normalized from each player's viewpoint", () {
    expect(
      miniRoyaleLanePosition(playerSide: 'left', normalizedProgress: 0.2),
      0.8,
    );
    expect(
      miniRoyaleLanePosition(playerSide: 'right', normalizedProgress: 0.2),
      0.2,
    );
    expect(
      miniRoyaleLanePosition(playerSide: 'right', normalizedProgress: 1.4),
      1.0,
    );
    expect(
      () => miniRoyaleLanePosition(
        playerSide: 'spectator',
        normalizedProgress: 0.5,
      ),
      throwsArgumentError,
    );
  });

  test('tower positions mirror progress for the viewing side', () {
    final arena = defaultArenaConfig;
    final leftView = miniRoyaleTowerPosition(
      playerSide: 'left',
      towerSide: 'right',
      arena: arena,
    );
    final rightView = miniRoyaleTowerPosition(
      playerSide: 'right',
      towerSide: 'right',
      arena: arena,
    );

    expect(
      leftView.lateral,
      arena.rightTower.lateralPosition / arena.lateralMax,
    );
    expect(
      leftView.progress,
      1 - arena.rightTower.progress / arena.progressMax,
    );
    expect(rightView.progress, arena.rightTower.progress / arena.progressMax);
  });

  test('selected cards use the strongest applicable tower reach', () {
    final unit = _card(type: 'melee', attackRange: 120, bodyRadius: 20);
    final spell = _card(type: 'spell', spellRadius: 220);
    final equipment = _card(type: 'equipment', attackRange: 999);

    final reach = miniRoyaleSelectedTowerThreatReach([unit, spell, equipment]);
    expect(reach, greaterThan(0));
    expect(miniRoyaleSelectedTowerThreatReach([equipment]), isNull);
  });
}
