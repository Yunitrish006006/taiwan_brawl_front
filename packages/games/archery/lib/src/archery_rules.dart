import 'dart:convert';
import 'dart:typed_data';

/// Package-owned port for reading the currently active optional rules payload.
abstract interface class ArcheryRulesContentSource {
  Future<String?> readActiveRulesJson();
}

class ArcheryScoreBand {
  const ArcheryScoreBand({required this.maxDistance, required this.score});

  final double maxDistance;
  final int score;

  factory ArcheryScoreBand.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid score band.');
    final distance = value['maxDistance'];
    final score = value['score'];
    if (distance is! num || score is! int) {
      throw const FormatException('Invalid score band values.');
    }
    return ArcheryScoreBand(maxDistance: distance.toDouble(), score: score);
  }

  Map<String, Object> toJson() => {'maxDistance': maxDistance, 'score': score};
}

/// Validated data-driven Archery gameplay tuning.
class ArcheryRules {
  const ArcheryRules({
    required this.version,
    required this.targetMovesAtScore,
    required this.targetAcceleratesAtScore,
    required this.targetSpeedMultiplier,
    required this.bowMoveBase,
    required this.bowMovePerLevel,
    required this.drawMovementMultiplier,
    required this.staminaDrainBase,
    required this.staminaDrainPerLevel,
    required this.arrowRiseBase,
    required this.arrowRisePerLevel,
    required this.arrowPowerFactor,
    required this.scoreBands,
  });

  static const builtIn = ArcheryRules(
    version: 'builtin-1',
    targetMovesAtScore: 200,
    targetAcceleratesAtScore: 500,
    targetSpeedMultiplier: 1.5,
    bowMoveBase: 0.01,
    bowMovePerLevel: 0.002,
    drawMovementMultiplier: 0.3,
    staminaDrainBase: 1,
    staminaDrainPerLevel: 0.2,
    arrowRiseBase: 0.04,
    arrowRisePerLevel: 0.01,
    arrowPowerFactor: 0.02,
    scoreBands: [
      ArcheryScoreBand(maxDistance: 0.05, score: 100),
      ArcheryScoreBand(maxDistance: 0.10, score: 60),
      ArcheryScoreBand(maxDistance: 0.18, score: 30),
    ],
  );

  final String version;
  final int targetMovesAtScore;
  final int targetAcceleratesAtScore;
  final double targetSpeedMultiplier;
  final double bowMoveBase;
  final double bowMovePerLevel;
  final double drawMovementMultiplier;
  final double staminaDrainBase;
  final double staminaDrainPerLevel;
  final double arrowRiseBase;
  final double arrowRisePerLevel;
  final double arrowPowerFactor;
  final List<ArcheryScoreBand> scoreBands;

  factory ArcheryRules.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Invalid Archery rules.');
    return ArcheryRules.fromJson(Map<String, Object?>.from(decoded));
  }

  factory ArcheryRules.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Archery rules schema.');
    }
    final version = json['version'];
    final moveAt = json['targetMovesAtScore'];
    final accelerateAt = json['targetAcceleratesAtScore'];
    final rawBands = json['scoreBands'];
    if (version is! String ||
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.+-]{0,63}$').hasMatch(version) ||
        moveAt is! int ||
        accelerateAt is! int ||
        rawBands is! List) {
      throw const FormatException('Invalid Archery rules identity or stages.');
    }
    final rules = ArcheryRules(
      version: version,
      targetMovesAtScore: moveAt,
      targetAcceleratesAtScore: accelerateAt,
      targetSpeedMultiplier: _number(json, 'targetSpeedMultiplier'),
      bowMoveBase: _number(json, 'bowMoveBase'),
      bowMovePerLevel: _number(json, 'bowMovePerLevel'),
      drawMovementMultiplier: _number(json, 'drawMovementMultiplier'),
      staminaDrainBase: _number(json, 'staminaDrainBase'),
      staminaDrainPerLevel: _number(json, 'staminaDrainPerLevel'),
      arrowRiseBase: _number(json, 'arrowRiseBase'),
      arrowRisePerLevel: _number(json, 'arrowRisePerLevel'),
      arrowPowerFactor: _number(json, 'arrowPowerFactor'),
      scoreBands: rawBands.map(ArcheryScoreBand.fromJson).toList(),
    );
    rules.validate();
    return rules;
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'version': version,
    'targetMovesAtScore': targetMovesAtScore,
    'targetAcceleratesAtScore': targetAcceleratesAtScore,
    'targetSpeedMultiplier': targetSpeedMultiplier,
    'bowMoveBase': bowMoveBase,
    'bowMovePerLevel': bowMovePerLevel,
    'drawMovementMultiplier': drawMovementMultiplier,
    'staminaDrainBase': staminaDrainBase,
    'staminaDrainPerLevel': staminaDrainPerLevel,
    'arrowRiseBase': arrowRiseBase,
    'arrowRisePerLevel': arrowRisePerLevel,
    'arrowPowerFactor': arrowPowerFactor,
    'scoreBands': scoreBands.map((band) => band.toJson()).toList(),
  };

  void validate() {
    if (targetMovesAtScore < 0 ||
        targetAcceleratesAtScore <= targetMovesAtScore ||
        targetAcceleratesAtScore > 100000000 ||
        !targetSpeedMultiplier.isFinite ||
        targetSpeedMultiplier <= 0 ||
        targetSpeedMultiplier > 10 ||
        !bowMoveBase.isFinite ||
        bowMoveBase <= 0 ||
        bowMoveBase > 0.2 ||
        !bowMovePerLevel.isFinite ||
        bowMovePerLevel < 0 ||
        bowMovePerLevel > 0.1 ||
        !drawMovementMultiplier.isFinite ||
        drawMovementMultiplier < 0 ||
        drawMovementMultiplier > 1 ||
        !staminaDrainBase.isFinite ||
        staminaDrainBase <= 0 ||
        staminaDrainBase > 100 ||
        !staminaDrainPerLevel.isFinite ||
        staminaDrainPerLevel < 0 ||
        staminaDrainPerLevel > 10 ||
        !arrowRiseBase.isFinite ||
        arrowRiseBase <= 0 ||
        arrowRiseBase > 1 ||
        !arrowRisePerLevel.isFinite ||
        arrowRisePerLevel < 0 ||
        arrowRisePerLevel > 1 ||
        !arrowPowerFactor.isFinite ||
        arrowPowerFactor < 0 ||
        arrowPowerFactor > 1 ||
        scoreBands.isEmpty ||
        scoreBands.length > 8) {
      throw const FormatException('Archery rules are outside safe bounds.');
    }
    var previousDistance = 0.0;
    var previousScore = 0x7fffffff;
    for (final band in scoreBands) {
      if (!band.maxDistance.isFinite ||
          band.maxDistance <= previousDistance ||
          band.maxDistance > 1 ||
          band.score < 0 ||
          band.score > previousScore ||
          band.score > 100000) {
        throw const FormatException('Archery score bands must be ordered.');
      }
      previousDistance = band.maxDistance;
      previousScore = band.score;
    }
  }

  double bowSpeed(int level, {required bool drawing}) =>
      (bowMoveBase + level * bowMovePerLevel) *
      (drawing ? drawMovementMultiplier : 1);

  double staminaDrain(int level) =>
      staminaDrainBase + level * staminaDrainPerLevel;

  double arrowRiseSpeed(int level, double power) =>
      arrowRiseBase + level * arrowRisePerLevel + power * arrowPowerFactor;

  int scoreForDistance(double distance) {
    for (final band in scoreBands) {
      if (distance < band.maxDistance) return band.score;
    }
    return 0;
  }
}

/// Validates a publisher-signed payload with the same schema used by gameplay
/// before the host activates it.
Future<void> validateArcheryRulesPayload(Uint8List payload) async {
  ArcheryRules.decode(utf8.decode(payload, allowMalformed: false));
}

double _number(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Invalid Archery rule: $key');
  return value.toDouble();
}
