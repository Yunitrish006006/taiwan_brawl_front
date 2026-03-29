class RoyaleCard {
  const RoyaleCard({
    required this.id,
    required this.name,
    required this.elixirCost,
    required this.type,
    required this.hp,
    required this.damage,
    required this.attackRange,
    required this.moveSpeed,
    required this.attackSpeed,
    required this.spawnCount,
    required this.spellRadius,
    required this.spellDamage,
    required this.targetRule,
    required this.effectKind,
    required this.effectValue,
  });

  final String id;
  final String name;
  final int elixirCost;
  final String type;
  final int hp;
  final int damage;
  final double attackRange;
  final double moveSpeed;
  final double attackSpeed;
  final int spawnCount;
  final double spellRadius;
  final int spellDamage;
  final String targetRule;
  final String effectKind;
  final double effectValue;

  bool get isEquipment => type == 'equipment';

  factory RoyaleCard.fromJson(Map<String, dynamic> json) {
    return RoyaleCard(
      id: json['id'] as String,
      name: json['name'] as String,
      elixirCost: (json['elixirCost'] as num).toInt(),
      type: json['type'] as String,
      hp: (json['hp'] as num).toInt(),
      damage: (json['damage'] as num).toInt(),
      attackRange: (json['attackRange'] as num).toDouble(),
      moveSpeed: (json['moveSpeed'] as num).toDouble(),
      attackSpeed: (json['attackSpeed'] as num).toDouble(),
      spawnCount: (json['spawnCount'] as num).toInt(),
      spellRadius: (json['spellRadius'] as num).toDouble(),
      spellDamage: (json['spellDamage'] as num).toInt(),
      targetRule: json['targetRule'] as String,
      effectKind: (json['effectKind'] as String?) ?? 'none',
      effectValue: (json['effectValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RoyaleDeck {
  const RoyaleDeck({
    required this.id,
    required this.name,
    required this.slot,
    required this.updatedAt,
    required this.cards,
  });

  final int id;
  final String name;
  final int slot;
  final String updatedAt;
  final List<RoyaleCard> cards;

  factory RoyaleDeck.fromJson(Map<String, dynamic> json) {
    return RoyaleDeck(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      slot: (json['slot'] as num).toInt(),
      updatedAt: (json['updatedAt'] as String?) ?? '',
      cards: (json['cards'] as List<dynamic>)
          .map((card) => RoyaleCard.fromJson(card as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoyalePlayerView {
  const RoyalePlayerView({
    required this.userId,
    required this.name,
    required this.side,
    required this.deckId,
    required this.deckName,
    required this.ready,
    required this.connected,
    required this.towerHp,
    required this.maxTowerHp,
  });

  final int userId;
  final String name;
  final String side;
  final int deckId;
  final String deckName;
  final bool ready;
  final bool connected;
  final int towerHp;
  final int maxTowerHp;

  factory RoyalePlayerView.fromJson(Map<String, dynamic> json) {
    return RoyalePlayerView(
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String,
      side: json['side'] as String,
      deckId: (json['deckId'] as num).toInt(),
      deckName: json['deckName'] as String,
      ready: json['ready'] as bool? ?? false,
      connected: json['connected'] as bool? ?? false,
      towerHp: (json['towerHp'] as num?)?.toInt() ?? 0,
      maxTowerHp: (json['maxTowerHp'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoyaleUnitView {
  const RoyaleUnitView({
    required this.id,
    required this.cardId,
    required this.name,
    required this.side,
    required this.type,
    required this.progress,
    required this.lateralPosition,
    required this.hp,
    required this.maxHp,
    required this.effects,
  });

  final String id;
  final String cardId;
  final String name;
  final String side;
  final String type;
  final double progress;
  final double lateralPosition;
  final int hp;
  final int maxHp;
  final List<String> effects;

  factory RoyaleUnitView.fromJson(Map<String, dynamic> json) {
    return RoyaleUnitView(
      id: json['id'] as String,
      cardId: json['cardId'] as String,
      name: json['name'] as String,
      side: json['side'] as String,
      type: json['type'] as String,
      progress: ((json['progress'] ?? json['x']) as num).toDouble(),
      lateralPosition:
          ((json['lateralPosition'] ?? json['yOffset'] ?? 0.5) as num)
              .toDouble(),
      hp: (json['hp'] as num?)?.toInt() ?? 0,
      maxHp: (json['maxHp'] as num?)?.toInt() ?? 0,
      effects: (json['effects'] as List<dynamic>? ?? const [])
          .map((effect) => effect.toString())
          .toList(),
    );
  }
}

class RoyaleBattleResult {
  const RoyaleBattleResult({required this.winnerSide, required this.reason});

  final String? winnerSide;
  final String reason;

  factory RoyaleBattleResult.fromJson(Map<String, dynamic> json) {
    return RoyaleBattleResult(
      winnerSide: json['winnerSide'] as String?,
      reason: json['reason'] as String? ?? 'unknown',
    );
  }
}

class RoyaleBattleView {
  const RoyaleBattleView({
    required this.timeRemainingMs,
    required this.yourElixir,
    required this.yourHand,
    required this.nextCardId,
    required this.units,
    required this.result,
  });

  final int timeRemainingMs;
  final double yourElixir;
  final List<RoyaleCard> yourHand;
  final String? nextCardId;
  final List<RoyaleUnitView> units;
  final RoyaleBattleResult? result;

  factory RoyaleBattleView.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'] as Map<String, dynamic>?;
    return RoyaleBattleView(
      timeRemainingMs: (json['timeRemainingMs'] as num?)?.toInt() ?? 0,
      yourElixir: (json['yourElixir'] as num?)?.toDouble() ?? 0,
      yourHand: (json['yourHand'] as List<dynamic>? ?? const [])
          .map((card) => RoyaleCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      nextCardId: json['nextCardId'] as String?,
      units: (json['units'] as List<dynamic>? ?? const [])
          .map((unit) => RoyaleUnitView.fromJson(unit as Map<String, dynamic>))
          .toList(),
      result: resultJson == null
          ? null
          : RoyaleBattleResult.fromJson(resultJson),
    );
  }
}

class RoyaleRoomSnapshot {
  const RoyaleRoomSnapshot({
    required this.code,
    required this.status,
    required this.viewerSide,
    required this.players,
    required this.battle,
  });

  final String code;
  final String status;
  final String? viewerSide;
  final List<RoyalePlayerView> players;
  final RoyaleBattleView? battle;

  RoyalePlayerView? get me {
    if (viewerSide == null) {
      return null;
    }
    for (final player in players) {
      if (player.side == viewerSide) {
        return player;
      }
    }
    return null;
  }

  RoyalePlayerView? get opponent {
    if (viewerSide == null) {
      return null;
    }
    for (final player in players) {
      if (player.side != viewerSide) {
        return player;
      }
    }
    return null;
  }

  factory RoyaleRoomSnapshot.fromJson(Map<String, dynamic> json) {
    final battleJson = json['battle'] as Map<String, dynamic>?;
    return RoyaleRoomSnapshot(
      code: json['code'] as String,
      status: json['status'] as String,
      viewerSide: json['viewerSide'] as String?,
      players: (json['players'] as List<dynamic>? ?? const [])
          .map(
            (player) =>
                RoyalePlayerView.fromJson(player as Map<String, dynamic>),
          )
          .toList(),
      battle: battleJson == null ? null : RoyaleBattleView.fromJson(battleJson),
    );
  }
}
