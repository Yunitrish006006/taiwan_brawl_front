import 'package:flutter/painting.dart';

import 'battle_rules.dart' as battle_rules;
import 'royale_models.dart';

/// Battlefield point normalized to the rendered board's 0..1 bounds.
class MiniRoyaleNormalizedArenaPoint {
  const MiniRoyaleNormalizedArenaPoint({
    required this.lateral,
    required this.progress,
  });

  final double lateral;
  final double progress;
}

/// Converts a local pointer position into a board-relative 0..1 point.
/// Returns null for an invalid board size or a pointer outside the board.
Offset? miniRoyaleNormalizeBoardPoint({
  required Offset localPoint,
  required Size boardSize,
}) {
  if (!boardSize.width.isFinite ||
      !boardSize.height.isFinite ||
      boardSize.width <= 0 ||
      boardSize.height <= 0 ||
      localPoint.dx < 0 ||
      localPoint.dy < 0 ||
      localPoint.dx > boardSize.width ||
      localPoint.dy > boardSize.height) {
    return null;
  }
  return Offset(
    localPoint.dx / boardSize.width,
    localPoint.dy / boardSize.height,
  );
}

/// Applies Mini Royale's authoritative deployment-zone rule to a board point.
bool miniRoyaleIsLegalDeployPoint(Offset point) =>
    battle_rules.isLegalDeployPoint(point.dx, point.dy);

/// Converts a normalized battlefield point to the server's player-relative
/// lane coordinate. The left side views the field in reverse progress order.
double miniRoyaleLanePosition({
  required String playerSide,
  required double normalizedProgress,
}) {
  final progress = switch (playerSide) {
    'left' => 1 - normalizedProgress,
    'right' => normalizedProgress,
    _ => throw ArgumentError.value(playerSide, 'playerSide'),
  };
  return progress.clamp(0.0, 1.0).toDouble();
}

/// Maps a side's tower from game-world coordinates into its player's view.
MiniRoyaleNormalizedArenaPoint miniRoyaleTowerPosition({
  required String playerSide,
  required String towerSide,
  required battle_rules.BattleArenaConfig arena,
}) {
  final tower = arena.towerForSide(towerSide);
  final progress = playerSide == 'left'
      ? 1 - (tower.progress / arena.progressMax)
      : tower.progress / arena.progressMax;
  return MiniRoyaleNormalizedArenaPoint(
    lateral: tower.lateralPosition / arena.lateralMax,
    progress: progress.clamp(0.0, 1.0).toDouble(),
  );
}

/// Maximum tower threat reach represented by the currently selected cards.
/// Equipment cannot damage towers; spells and units use distinct hit rules.
double? miniRoyaleSelectedTowerThreatReach(Iterable<RoyaleCard> cards) {
  double? maximum;
  for (final card in cards) {
    if (card.type == 'equipment') continue;
    final reach = card.type == 'spell'
        ? battle_rules.effectiveSpellReachToTower(card.spellRadius.toDouble())
        : battle_rules.effectiveAttackReachToTower(
            attackRange: card.attackRange.toDouble(),
            bodyRadius: card.bodyRadius > 0
                ? card.bodyRadius.toDouble()
                : battle_rules.bodyRadiusForUnitType(card.type),
          );
    if (maximum == null || reach > maximum) maximum = reach;
  }
  return maximum;
}
