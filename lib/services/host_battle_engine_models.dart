part of 'host_battle_engine.dart';

class _HostPlayer {
  _HostPlayer({
    required this.userId,
    required this.name,
    required this.side,
    required this.deckId,
    required this.deckName,
    required this.hero,
    required this.isBot,
    required this.botController,
    required this.ready,
    required this.connected,
    required this.deckCards,
    required this.hand,
    required this.queue,
    required this.cardUses,
    required this.cardUseLimits,
    required this.physicalHealth,
    required this.maxPhysicalHealth,
    required this.physicalHealthRegen,
    required this.spiritHealth,
    required this.maxSpiritHealth,
    required this.spiritHealthRegen,
    required this.physicalEnergy,
    required this.maxPhysicalEnergy,
    required this.physicalEnergyRegen,
    required this.spiritEnergy,
    required this.maxSpiritEnergy,
    required this.spiritEnergyRegen,
    required this.money,
    required this.maxMoney,
    required this.moneyPerSecond,
    required this.towerHp,
    required this.maxTowerHp,
    required this.heroAttackCooldown,
    required this.heroAttackEventId,
    required this.heroAttackEvent,
    required this.botThinkMs,
  });

  final int userId;
  final String name;
  final String side;
  final int deckId;
  final String deckName;
  final RoyaleHero hero;
  final bool isBot;
  final String botController;
  bool ready;
  bool connected;
  final List<RoyaleCard> deckCards;
  final List<String> hand;
  final List<String> queue;
  final Map<String, int> cardUses;
  final Map<String, int> cardUseLimits;
  double physicalHealth;
  double maxPhysicalHealth;
  double physicalHealthRegen;
  double spiritHealth;
  double maxSpiritHealth;
  double spiritHealthRegen;
  double physicalEnergy;
  double maxPhysicalEnergy;
  double physicalEnergyRegen;
  double spiritEnergy;
  double maxSpiritEnergy;
  double spiritEnergyRegen;
  double money;
  double maxMoney;
  double moneyPerSecond;
  int towerHp;
  final int maxTowerHp;
  double heroAttackCooldown;
  int heroAttackEventId;
  Map<String, dynamic>? heroAttackEvent;
  int botThinkMs;

  double get totalEnergy => physicalEnergy + spiritEnergy;

  double get maxEnergy => maxPhysicalEnergy + maxSpiritEnergy;

  RoyaleCard? cardById(String cardId) {
    for (final card in deckCards) {
      if (card.id == cardId) {
        return card;
      }
    }
    return null;
  }

  int remainingUsesFor(RoyaleCard card) {
    final limit = cardUseLimits[card.id] ?? 8;
    final used = cardUses[card.id] ?? 0;
    return math.max(0, limit - used);
  }
}

class _HeroAttack {
  const _HeroAttack({
    required this.damage,
    required this.range,
    required this.attackSpeed,
    required this.damageType,
  });

  final int damage;
  final double range;
  final double attackSpeed;
  final String damageType;
}

class _HostUnit {
  _HostUnit({
    required this.id,
    required this.cardId,
    required this.name,
    required this.nameZhHant,
    required this.nameEn,
    required this.nameJa,
    required this.imageUrl,
    required this.characterImageUrl,
    required this.characterFrontImageUrl,
    required this.characterBackImageUrl,
    required this.characterLeftImageUrl,
    required this.characterRightImageUrl,
    required this.characterAssets,
    required this.bgImageUrl,
    required this.type,
    required this.side,
    required this.facingDirection,
    required this.animationState,
    required this.animationEvent,
    required this.animationEventId,
    required this.progress,
    required this.lateralPosition,
    required this.hp,
    required this.maxHp,
    required this.damage,
    required this.attackRange,
    required this.bodyRadius,
    required this.moveSpeed,
    required this.attackSpeed,
    required this.targetRule,
    required this.cooldown,
    required this.effects,
  });

  final String id;
  final String cardId;
  final String name;
  final String nameZhHant;
  final String nameEn;
  final String nameJa;
  final String? imageUrl;
  final String? characterImageUrl;
  final String? characterFrontImageUrl;
  final String? characterBackImageUrl;
  final String? characterLeftImageUrl;
  final String? characterRightImageUrl;
  final List<RoyaleCharacterAsset> characterAssets;
  final String? bgImageUrl;
  final String type;
  final String side;
  String facingDirection;
  String animationState;
  String? animationEvent;
  int animationEventId;
  double progress;
  double lateralPosition;
  int hp;
  final int maxHp;
  final int damage;
  final double attackRange;
  final double bodyRadius;
  final double moveSpeed;
  final double attackSpeed;
  final String targetRule;
  double cooldown;
  final List<String> effects;
  List<String> statusEffects = [];
}

class _DropPoint {
  const _DropPoint({required this.progress, required this.lateralPosition});

  final double progress;
  final double lateralPosition;
}

class _PlayableCardsResult {
  const _PlayableCardsResult({this.cards = const <RoyaleCard>[], this.error});

  final List<RoyaleCard> cards;
  final String? error;
}

class _HostFieldEffect {
  _HostFieldEffect({
    required this.kind,
    required this.remainingMs,
    required this.value,
    required this.scope,
    this.side,
  });

  final String kind;
  int remainingMs;
  double value;
  final String scope;
  final String? side;
}

class _EquipmentEffect {
  const _EquipmentEffect({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
  });

  final String id;
  final String name;
  final String kind;
  final double value;
}

class _UnitStats {
  const _UnitStats({
    required this.hp,
    required this.damage,
    required this.moveSpeed,
    this.attackSpeedMultiplier = 1,
  });

  final int hp;
  final int damage;
  final double moveSpeed;
  final double attackSpeedMultiplier;
}

class _TargetSelection {
  const _TargetSelection.unit({
    required _HostUnit target,
    required this.forwardDistance,
    required this.distance,
  }) : kind = 'unit',
       unitTarget = target,
       targetSide = null;

  const _TargetSelection.tower({
    required this.targetSide,
    required this.distance,
  }) : kind = 'tower',
       unitTarget = null,
       forwardDistance = 0;

  final String kind;
  final _HostUnit? unitTarget;
  final String? targetSide;
  final double forwardDistance;
  final double distance;
}

class _FieldEventTemplate {
  const _FieldEventTemplate({
    required this.id,
    required this.weight,
    required this.category,
    required this.titleZhHant,
    required this.titleEn,
    this.hitRunChance = 0,
    this.insurancePayoutChance = 0,
    this.caughtChance = 0,
    this.disabledChance = 0,
    this.physicalDamage = 0,
    this.spiritDamage = 0,
    this.insurancePayout = 0,
    this.caughtBonus = 0,
    this.fieldEffect,
    this.duration = 0,
    this.fieldValue = 0,
    this.immediateDamage = 0,
    this.isShield = false,
    this.spiritGain = 0,
    this.moneyGain = 0,
    this.physicalGain = 0,
    this.moneyCost = 0,
    this.recoveryChance = 0,
    this.physicalEnergyPenalty = 0,
    this.spiritEnergyPenalty = 0,
    this.isDeliverySurge = false,
  });

  final String id;
  final double weight;
  final String category;
  final String titleZhHant;
  final String titleEn;
  final double hitRunChance;
  final double insurancePayoutChance;
  final double caughtChance;
  final double disabledChance;
  final double physicalDamage;
  final double spiritDamage;
  final double insurancePayout;
  final double caughtBonus;
  final String? fieldEffect;
  final int duration;
  final double fieldValue;
  final double immediateDamage;
  final bool isShield;
  final double spiritGain;
  final double moneyGain;
  final double physicalGain;
  final double moneyCost;
  final double recoveryChance;
  final double physicalEnergyPenalty;
  final double spiritEnergyPenalty;
  final bool isDeliverySurge;
}
