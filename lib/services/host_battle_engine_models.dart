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
    required this.type,
    required this.side,
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
  final String type;
  final String side;
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
  });

  final int hp;
  final int damage;
  final double moveSpeed;
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
