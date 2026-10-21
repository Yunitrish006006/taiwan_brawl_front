import 'dart:convert';
import 'dart:typed_data';

import 'battle_rules.dart';

const miniRoyaleGameplayRulesResourceId = 'game.mini-royale.gameplay-rules';

/// Safe, declarative tuning values for versioned Mini Royale gameplay packs.
/// Packs contain data only; they cannot ship executable rules or scripts.
class MiniRoyaleGameplayRules {
  const MiniRoyaleGameplayRules({
    required this.rulesetId,
    required this.rulesetVersion,
    required this.matchDurationMs,
    required this.towerHitPoints,
    required this.attackSpeedMultiplier,
    required this.moveSpeedMultiplier,
  });

  static const schemaVersion = 1;
  static const allowedFields = <String>{
    'schemaVersion',
    'rulesetId',
    'rulesetVersion',
    'matchDurationMs',
    'towerHitPoints',
    'attackSpeedMultiplier',
    'moveSpeedMultiplier',
  };

  final String rulesetId;
  final int rulesetVersion;
  final int matchDurationMs;
  final int towerHitPoints;
  final double attackSpeedMultiplier;
  final double moveSpeedMultiplier;

  factory MiniRoyaleGameplayRules.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion ||
        json.keys.toSet().difference(allowedFields).isNotEmpty ||
        allowedFields.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Gameplay rules contain missing or unknown fields.',
      );
    }
    final rules = MiniRoyaleGameplayRules(
      rulesetId: json['rulesetId'] as String,
      rulesetVersion: json['rulesetVersion'] as int,
      matchDurationMs: json['matchDurationMs'] as int,
      towerHitPoints: json['towerHitPoints'] as int,
      attackSpeedMultiplier: (json['attackSpeedMultiplier'] as num).toDouble(),
      moveSpeedMultiplier: (json['moveSpeedMultiplier'] as num).toDouble(),
    );
    rules.validate();
    return rules;
  }

  void validate() {
    if (!RegExp(r'^[a-z0-9]+(?:[.-][a-z0-9]+)*$').hasMatch(rulesetId) ||
        rulesetVersion < 1 ||
        matchDurationMs < 60000 ||
        matchDurationMs > 600000 ||
        towerHitPoints < 100 ||
        towerHitPoints > 100000 ||
        !attackSpeedMultiplier.isFinite ||
        attackSpeedMultiplier < 0.1 ||
        attackSpeedMultiplier > 5 ||
        !moveSpeedMultiplier.isFinite ||
        moveSpeedMultiplier < 0.1 ||
        moveSpeedMultiplier > 5) {
      throw const FormatException(
        'Gameplay rules are outside the supported v1 bounds.',
      );
    }
  }

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'rulesetId': rulesetId,
    'rulesetVersion': rulesetVersion,
    'matchDurationMs': matchDurationMs,
    'towerHitPoints': towerHitPoints,
    'attackSpeedMultiplier': attackSpeedMultiplier,
    'moveSpeedMultiplier': moveSpeedMultiplier,
  };
}

/// Validates gameplay payload bytes before the App makes this version active.
Future<void> validateMiniRoyaleGameplayRulesPayload(Uint8List payload) async {
  final decoded = jsonDecode(utf8.decode(payload, allowMalformed: false));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Gameplay rules root must be an object.');
  }
  MiniRoyaleGameplayRules.fromJson(decoded);
}

const bundledMiniRoyaleGameplayRules = MiniRoyaleGameplayRules(
  rulesetId: 'mini-royale-ranked',
  rulesetVersion: 1,
  matchDurationMs: matchDurationMs,
  towerHitPoints: towerHp,
  attackSpeedMultiplier: globalAttackSpeedMultiplier,
  moveSpeedMultiplier: globalMoveSpeedMultiplier,
);
