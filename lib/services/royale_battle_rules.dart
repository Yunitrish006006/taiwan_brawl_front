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
const int unitFormationBiasLimit = 90;
const int riverMinProgress = leftDeployMax + 35;
const int riverMaxProgress = rightDeployMin - 35;
const int bridgeMinProgress = 430;
const int bridgeMaxProgress = 570;
const int bridgeMinLateral = 380;
const int bridgeMaxLateral = 620;

const double deployZoneMinX = lateralMin / worldScale;
const double deployZoneMaxX = lateralMax / worldScale;
const double deployZoneMinY = rightDeployMin / worldScale;
const double deployZoneMaxY = maxFieldProgress / worldScale;

class BattlePointConfig {
  const BattlePointConfig({
    required this.progress,
    required this.lateralPosition,
  });

  final double progress;
  final double lateralPosition;

  factory BattlePointConfig.fromJson(
    Map<String, dynamic>? json, {
    required BattlePointConfig fallback,
  }) {
    if (json == null) {
      return fallback;
    }
    return BattlePointConfig(
      progress: (json['progress'] as num?)?.toDouble() ?? fallback.progress,
      lateralPosition:
          (json['lateralPosition'] as num?)?.toDouble() ??
          fallback.lateralPosition,
    );
  }

  Map<String, dynamic> toJson() => {
    'progress': progress,
    'lateralPosition': lateralPosition,
  };
}

class BattleProgressRange {
  const BattleProgressRange({required this.min, required this.max});

  final double min;
  final double max;

  factory BattleProgressRange.fromJson(
    Map<String, dynamic>? json, {
    required BattleProgressRange fallback,
  }) {
    if (json == null) {
      return fallback;
    }
    return BattleProgressRange(
      min: (json['min'] as num?)?.toDouble() ?? fallback.min,
      max: (json['max'] as num?)?.toDouble() ?? fallback.max,
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class BattleLateralRange {
  const BattleLateralRange({required this.min, required this.max});

  final double min;
  final double max;

  factory BattleLateralRange.fromJson(Map<String, dynamic> json) {
    return BattleLateralRange(
      min:
          (json['min'] as num?)?.toDouble() ??
          (json['lateralMin'] as num?)?.toDouble() ??
          lateralMin.toDouble(),
      max:
          (json['max'] as num?)?.toDouble() ??
          (json['lateralMax'] as num?)?.toDouble() ??
          lateralMax.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class BattleTerrainGate {
  const BattleTerrainGate({
    required this.id,
    required this.kind,
    required this.progressMin,
    required this.progressMax,
    required this.bridgeMinProgress,
    required this.bridgeMaxProgress,
    required this.passableLateralRanges,
  });

  final String id;
  final String kind;
  final double progressMin;
  final double progressMax;
  final double bridgeMinProgress;
  final double bridgeMaxProgress;
  final List<BattleLateralRange> passableLateralRanges;

  factory BattleTerrainGate.fromJson(Map<String, dynamic> json) {
    final progressMinValue =
        (json['progressMin'] as num?)?.toDouble() ??
        riverMinProgress.toDouble();
    final progressMaxValue =
        (json['progressMax'] as num?)?.toDouble() ??
        riverMaxProgress.toDouble();
    return BattleTerrainGate(
      id: json['id'] as String? ?? 'terrain_gate',
      kind: json['kind'] as String? ?? 'gate',
      progressMin: progressMinValue,
      progressMax: progressMaxValue,
      bridgeMinProgress:
          (json['bridgeMinProgress'] as num?)?.toDouble() ?? progressMinValue,
      bridgeMaxProgress:
          (json['bridgeMaxProgress'] as num?)?.toDouble() ?? progressMaxValue,
      passableLateralRanges:
          (json['passableLateralRanges'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(BattleLateralRange.fromJson)
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'progressMin': progressMin,
    'progressMax': progressMax,
    'bridgeMinProgress': bridgeMinProgress,
    'bridgeMaxProgress': bridgeMaxProgress,
    'passableLateralRanges': passableLateralRanges
        .map((range) => range.toJson())
        .toList(growable: false),
  };
}

class BattleObstacle {
  const BattleObstacle({
    required this.id,
    required this.kind,
    required this.progressMin,
    required this.progressMax,
    required this.lateralMin,
    required this.lateralMax,
  });

  final String id;
  final String kind;
  final double progressMin;
  final double progressMax;
  final double lateralMin;
  final double lateralMax;

  factory BattleObstacle.fromJson(Map<String, dynamic> json) {
    return BattleObstacle(
      id: json['id'] as String? ?? 'obstacle',
      kind: json['kind'] as String? ?? 'rect',
      progressMin: (json['progressMin'] as num?)?.toDouble() ?? 0,
      progressMax: (json['progressMax'] as num?)?.toDouble() ?? 0,
      lateralMin: (json['lateralMin'] as num?)?.toDouble() ?? 0,
      lateralMax: (json['lateralMax'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'progressMin': progressMin,
    'progressMax': progressMax,
    'lateralMin': lateralMin,
    'lateralMax': lateralMax,
  };
}

class BattleArenaConfig {
  const BattleArenaConfig({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.progressMin,
    required this.progressMax,
    required this.lateralMin,
    required this.lateralMax,
    required this.centerLateral,
    required this.fieldAspectRatio,
    required this.leftTower,
    required this.rightTower,
    required this.leftDeploy,
    required this.rightDeploy,
    required this.terrainGates,
    required this.obstacles,
  });

  final String id;
  final String name;
  final double width;
  final double height;
  final double progressMin;
  final double progressMax;
  final double lateralMin;
  final double lateralMax;
  final double centerLateral;
  final double fieldAspectRatio;
  final BattlePointConfig leftTower;
  final BattlePointConfig rightTower;
  final BattleProgressRange leftDeploy;
  final BattleProgressRange rightDeploy;
  final List<BattleTerrainGate> terrainGates;
  final List<BattleObstacle> obstacles;

  factory BattleArenaConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return defaultArenaConfig;
    }
    final towers = json['towers'] as Map<String, dynamic>? ?? const {};
    final deploy = json['deploy'] as Map<String, dynamic>? ?? const {};
    final fallbackCenter =
        (json['centerLateral'] as num?)?.toDouble() ??
        defaultArenaConfig.centerLateral;
    return BattleArenaConfig(
      id: json['id'] as String? ?? defaultArenaConfig.id,
      name: json['name'] as String? ?? defaultArenaConfig.name,
      width: (json['width'] as num?)?.toDouble() ?? worldScale.toDouble(),
      height: (json['height'] as num?)?.toDouble() ?? worldScale.toDouble(),
      progressMin:
          (json['progressMin'] as num?)?.toDouble() ??
          defaultArenaConfig.progressMin,
      progressMax:
          (json['progressMax'] as num?)?.toDouble() ??
          defaultArenaConfig.progressMax,
      lateralMin:
          (json['lateralMin'] as num?)?.toDouble() ??
          defaultArenaConfig.lateralMin,
      lateralMax:
          (json['lateralMax'] as num?)?.toDouble() ??
          defaultArenaConfig.lateralMax,
      centerLateral: fallbackCenter,
      fieldAspectRatio:
          (json['fieldAspectRatio'] as num?)?.toDouble() ??
          defaultArenaConfig.fieldAspectRatio,
      leftTower: BattlePointConfig.fromJson(
        towers['left'] as Map<String, dynamic>?,
        fallback: BattlePointConfig(
          progress: leftTowerX.toDouble(),
          lateralPosition: fallbackCenter,
        ),
      ),
      rightTower: BattlePointConfig.fromJson(
        towers['right'] as Map<String, dynamic>?,
        fallback: BattlePointConfig(
          progress: rightTowerX.toDouble(),
          lateralPosition: fallbackCenter,
        ),
      ),
      leftDeploy: BattleProgressRange.fromJson(
        deploy['left'] as Map<String, dynamic>?,
        fallback: BattleProgressRange(
          min: minFieldProgress.toDouble(),
          max: leftDeployMax.toDouble(),
        ),
      ),
      rightDeploy: BattleProgressRange.fromJson(
        deploy['right'] as Map<String, dynamic>?,
        fallback: BattleProgressRange(
          min: rightDeployMin.toDouble(),
          max: maxFieldProgress.toDouble(),
        ),
      ),
      terrainGates: (json['terrainGates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BattleTerrainGate.fromJson)
          .where((gate) => gate.passableLateralRanges.isNotEmpty)
          .toList(growable: false),
      obstacles: (json['obstacles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BattleObstacle.fromJson)
          .toList(growable: false),
    );
  }

  BattlePointConfig towerForSide(String side) =>
      side == 'left' ? leftTower : rightTower;

  BattleProgressRange deployForSide(String side) =>
      side == 'left' ? leftDeploy : rightDeploy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'width': width,
    'height': height,
    'progressMin': progressMin,
    'progressMax': progressMax,
    'lateralMin': lateralMin,
    'lateralMax': lateralMax,
    'centerLateral': centerLateral,
    'fieldAspectRatio': fieldAspectRatio,
    'towers': {'left': leftTower.toJson(), 'right': rightTower.toJson()},
    'deploy': {'left': leftDeploy.toJson(), 'right': rightDeploy.toJson()},
    'terrainGates': terrainGates
        .map((gate) => gate.toJson())
        .toList(growable: false),
    'obstacles': obstacles
        .map((obstacle) => obstacle.toJson())
        .toList(growable: false),
  };
}

const BattleArenaConfig defaultArenaConfig = BattleArenaConfig(
  id: 'classic_bridge',
  name: 'Classic Bridge',
  width: 1000.0,
  height: 1000.0,
  progressMin: 0.0,
  progressMax: 1000.0,
  lateralMin: 0.0,
  lateralMax: 1000.0,
  centerLateral: centerLateral,
  fieldAspectRatio: fieldAspectRatio,
  leftTower: BattlePointConfig(progress: 50.0, lateralPosition: centerLateral),
  rightTower: BattlePointConfig(
    progress: 950.0,
    lateralPosition: centerLateral,
  ),
  leftDeploy: BattleProgressRange(min: 0.0, max: 420.0),
  rightDeploy: BattleProgressRange(min: 580.0, max: 1000.0),
  terrainGates: [
    BattleTerrainGate(
      id: 'central_river',
      kind: 'river',
      progressMin: 455.0,
      progressMax: 545.0,
      bridgeMinProgress: 430.0,
      bridgeMaxProgress: 570.0,
      passableLateralRanges: [BattleLateralRange(min: 380.0, max: 620.0)],
    ),
  ],
  obstacles: [],
);

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

int toWorldInteger(double value, [double scale = 1000.0]) {
  if (!value.isFinite) {
    return 0;
  }
  return value.abs() <= 1 ? (value * scale).round() : value.round();
}

double toNormalizedWorld(double value, [double scale = 1000.0]) {
  if (!value.isFinite) {
    return 0;
  }
  return value.abs() <= 1 ? value : value / scale;
}

double sideDirection(String side) {
  return side == 'left' ? 1 : -1;
}

List<double> deployRangeForSide([
  String side = 'left',
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  final range = arena.deployForSide(side);
  return [range.min, range.max];
}

double sanitizeLanePosition(
  String side,
  double value, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  final range = deployRangeForSide(side, arena);
  final min = math.min(range[0], range[1]);
  final max = math.max(range[0], range[1]);
  if (!value.isFinite) {
    return (min + max) / 2;
  }
  return clampBattleValue(value, min, max);
}

double sanitizeLateralPosition(
  double value, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  if (!value.isFinite) {
    return arena.centerLateral;
  }
  return clampBattleValue(value, arena.lateralMin, arena.lateralMax);
}

bool isRiverProgress(
  double progress, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  return arena.terrainGates.any(
    (gate) =>
        gate.kind == 'river' &&
        progress > gate.progressMin &&
        progress < gate.progressMax,
  );
}

bool isBridgeLateral(
  double lateral, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  final normalizedLateral = sanitizeLateralPosition(lateral, arena);
  final ranges = arena.terrainGates
      .expand((gate) => gate.passableLateralRanges)
      .toList(growable: false);
  return ranges.isEmpty ||
      ranges.any(
        (range) =>
            normalizedLateral >= range.min && normalizedLateral <= range.max,
      );
}

bool pathIntersectsRiver(
  double startProgress,
  double endProgress, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  if (!startProgress.isFinite || !endProgress.isFinite) {
    return false;
  }
  final minProgress = math.min(startProgress, endProgress);
  final maxProgress = math.max(startProgress, endProgress);
  return arena.terrainGates.any(
    (gate) => minProgress < gate.progressMax && maxProgress > gate.progressMin,
  );
}

List<double> terrainGateLateralForProgress(
  double progress, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  var minValue = arena.lateralMin;
  var maxValue = arena.lateralMax;
  for (final gate in arena.terrainGates) {
    if (progress > gate.progressMin && progress < gate.progressMax) {
      final ranges = gate.passableLateralRanges;
      minValue = ranges.map((range) => range.min).reduce(math.min);
      maxValue = ranges.map((range) => range.max).reduce(math.max);
    }
  }
  return [minValue, maxValue];
}

double sanitizeTerrainLateralForProgress(
  double progress,
  double lateral, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  final gate = terrainGateLateralForProgress(progress, arena);
  return clampBattleValue(
    sanitizeLateralPosition(lateral, arena),
    gate[0],
    gate[1],
  );
}

double terrainNavigationLateralForMove(
  double startProgress,
  double targetProgress,
  double desiredLateral, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  final sanitizedLateral = sanitizeLateralPosition(desiredLateral, arena);
  if (!pathIntersectsRiver(startProgress, targetProgress, arena) ||
      isBridgeLateral(sanitizedLateral, arena)) {
    return sanitizedLateral;
  }

  final gate = terrainGateLateralForProgress(
    (startProgress + targetProgress) / 2,
    arena,
  );
  return clampBattleValue(sanitizedLateral, gate[0], gate[1]);
}

double terrainLimitedProgressForMove(
  double startProgress,
  double desiredProgress,
  double desiredLateral, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  if (!startProgress.isFinite || !desiredProgress.isFinite) {
    return startProgress.isFinite ? startProgress : arena.progressMin;
  }
  var limitedProgress = desiredProgress;
  for (final gate in arena.terrainGates) {
    final lateralAllowed = gate.passableLateralRanges.any(
      (range) => desiredLateral >= range.min && desiredLateral <= range.max,
    );
    if (lateralAllowed) {
      continue;
    }
    if (startProgress <= gate.progressMin &&
        desiredProgress > gate.progressMin) {
      limitedProgress = math.min(limitedProgress, gate.progressMin);
    } else if (startProgress >= gate.progressMax &&
        desiredProgress < gate.progressMax) {
      limitedProgress = math.max(limitedProgress, gate.progressMax);
    }
  }

  return limitedProgress;
}

double toWorldProgress(
  String side,
  double viewY, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  final normalizedY = clampBattleValue(
    toNormalizedWorld(viewY, arena.progressMax),
    0,
    1,
  );
  final worldY = (normalizedY * arena.progressMax).roundToDouble();
  return side == 'left' ? arena.progressMax - worldY : worldY;
}

BattleDropPoint normalizeDropPoint(
  String side, {
  required double? dropX,
  required double? dropY,
  required double? lanePosition,
  BattleArenaConfig arena = defaultArenaConfig,
}) {
  final hasExactPoint =
      dropX != null && dropY != null && dropX.isFinite && dropY.isFinite;
  if (!hasExactPoint) {
    return BattleDropPoint(
      progress: sanitizeLanePosition(
        side,
        toWorldInteger(
          lanePosition ?? double.nan,
          arena.progressMax,
        ).toDouble(),
        arena,
      ),
      lateralPosition: arena.centerLateral,
    );
  }

  return BattleDropPoint(
    progress: sanitizeLanePosition(
      side,
      toWorldProgress(side, dropY, arena),
      arena,
    ),
    lateralPosition: sanitizeLateralPosition(
      toWorldInteger(dropX, arena.lateralMax).toDouble(),
      arena,
    ),
  );
}

double distanceBetweenPoints(
  double aProgress,
  double aLateral,
  double bProgress,
  double bLateral, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  return math.sqrt(
    math.pow(aProgress - bProgress, 2) +
        math.pow((aLateral - bLateral) * arena.fieldAspectRatio, 2),
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

double lateralOffsetForWorldDistance(
  double worldDistance, [
  BattleArenaConfig arena = defaultArenaConfig,
]) {
  return worldDistance / arena.fieldAspectRatio;
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
