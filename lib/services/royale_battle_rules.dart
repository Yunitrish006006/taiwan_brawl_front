import 'dart:math' as math;

const int tickMs = 66;
const int matchDurationMs = 210000;
const int worldScale = 1000;
const double centerLateral = worldScale / 2;
const int leftTowerX = 50;
const int rightTowerX = 950;
const int leftDeployMax = 420;
const int rightDeployMin = 580;
const int minFieldProgress = 0;
const int maxFieldProgress = 1000;
const int towerHp = 3000;
const int maxComboCards = 3;
const int lateralMin = 0;
const int lateralMax = 1000;
const int botMinThinkMs = 950;
const int botMaxThinkMs = 1800;
const double globalMoveSpeedMultiplier = 0.58;
const double globalAttackSpeedMultiplier = 1.18;
const double fieldAspectRatio = 0.62;
const int towerBodyRadius = 30;
const int unitCollisionGap = 6;

const double deployZoneMinX = lateralMin / worldScale;
const double deployZoneMaxX = lateralMax / worldScale;
const double deployZoneMinY = rightDeployMin / worldScale;
const double deployZoneMaxY = maxFieldProgress / worldScale;

class BattleDropPoint {
  const BattleDropPoint({
    required this.progress,
    required this.lateralPosition,
  });

  final double progress;
  final double lateralPosition;
}

double clampBattleValue(double value, double min, double max) {
  return math.max(min, math.min(max, value));
}

int toWorldInteger(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.abs() <= 1 ? (value * worldScale).round() : value.round();
}

double toNormalizedWorld(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.abs() <= 1 ? value : value / worldScale;
}

double sideDirection(String side) {
  return side == 'left' ? 1 : -1;
}

List<double> deployRangeForSide(String side) {
  return side == 'left'
      ? [minFieldProgress.toDouble(), leftDeployMax.toDouble()]
      : [rightDeployMin.toDouble(), maxFieldProgress.toDouble()];
}

double sanitizeLanePosition(String side, double value) {
  final range = deployRangeForSide(side);
  final min = math.min(range[0], range[1]);
  final max = math.max(range[0], range[1]);
  if (!value.isFinite) {
    return (min + max) / 2;
  }
  return clampBattleValue(value, min, max);
}

double sanitizeLateralPosition(double value) {
  if (!value.isFinite) {
    return centerLateral;
  }
  return clampBattleValue(value, lateralMin.toDouble(), lateralMax.toDouble());
}

double toWorldProgress(String side, double viewY) {
  final normalizedY = clampBattleValue(toNormalizedWorld(viewY), 0, 1);
  final worldY = (normalizedY * worldScale).roundToDouble();
  return side == 'left' ? worldScale - worldY : worldY;
}

BattleDropPoint normalizeDropPoint(
  String side, {
  required double? dropX,
  required double? dropY,
  required double? lanePosition,
}) {
  final hasExactPoint =
      dropX != null && dropY != null && dropX.isFinite && dropY.isFinite;
  if (!hasExactPoint) {
    return BattleDropPoint(
      progress: sanitizeLanePosition(
        side,
        toWorldInteger(lanePosition ?? double.nan).toDouble(),
      ),
      lateralPosition: centerLateral,
    );
  }

  return BattleDropPoint(
    progress: sanitizeLanePosition(side, toWorldProgress(side, dropY)),
    lateralPosition: sanitizeLateralPosition(toWorldInteger(dropX).toDouble()),
  );
}

double distanceBetweenPoints(
  double aProgress,
  double aLateral,
  double bProgress,
  double bLateral,
) {
  return math.sqrt(
    math.pow(aProgress - bProgress, 2) +
        math.pow((aLateral - bLateral) * fieldAspectRatio, 2),
  );
}

double bodyRadiusForUnitType(String type) {
  switch (type) {
    case 'tank':
      return 24;
    case 'melee':
      return 18;
    case 'swarm':
      return 14;
    case 'ranged':
      return 16;
    default:
      return 18;
  }
}

double displayAttackReach({
  required double attackRange,
  required double bodyRadius,
}) {
  return attackRange + bodyRadius;
}

double effectiveSpellReachToUnit({
  required double spellRadius,
  required double targetBodyRadius,
}) {
  return spellRadius + targetBodyRadius;
}

double effectiveSpellReachToTower(double spellRadius) {
  return spellRadius + towerBodyRadius;
}

double minimumBodyContactDistance({
  required double bodyRadius,
  required double otherBodyRadius,
  double gap = 0,
}) {
  return bodyRadius + otherBodyRadius + gap;
}

double lateralOffsetForWorldDistance(double worldDistance) {
  return worldDistance / fieldAspectRatio;
}

double effectiveAttackReachToUnit({
  required double attackRange,
  required double bodyRadius,
  required double targetBodyRadius,
}) {
  return displayAttackReach(attackRange: attackRange, bodyRadius: bodyRadius) +
      targetBodyRadius;
}

double effectiveAttackReachToTower({
  required double attackRange,
  required double bodyRadius,
}) {
  return displayAttackReach(attackRange: attackRange, bodyRadius: bodyRadius) +
      towerBodyRadius;
}

bool isLegalDeployPoint(double x, double y) {
  return x >= deployZoneMinX &&
      x <= deployZoneMaxX &&
      y >= deployZoneMinY &&
      y <= deployZoneMaxY;
}

int randomBotThinkMs([math.Random? random]) {
  final rng = random ?? math.Random();
  return botMinThinkMs + rng.nextInt(botMaxThinkMs - botMinThinkMs);
}
