import '../utils/remote_image_url.dart';

class RoyaleCard {
  const RoyaleCard({
    required this.id,
    required this.name,
    required this.nameZhHant,
    required this.nameEn,
    required this.nameJa,
    required this.imageUrl,
    required this.characterImageUrl,
    required this.bgImageUrl,
    this.characterFrontImageUrl,
    this.characterBackImageUrl,
    this.characterLeftImageUrl,
    this.characterRightImageUrl,
    required this.imageVersion,
    required this.energyCost,
    required this.energyCostType,
    required this.type,
    required this.hp,
    required this.damage,
    required this.attackRange,
    required this.bodyRadius,
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
  final String nameZhHant;
  final String nameEn;
  final String nameJa;
  final String? imageUrl;
  final String? characterImageUrl;
  final String? bgImageUrl;
  final String? characterFrontImageUrl;
  final String? characterBackImageUrl;
  final String? characterLeftImageUrl;
  final String? characterRightImageUrl;
  final int imageVersion;
  final int energyCost;
  final String energyCostType;
  final String type;
  final int hp;
  final int damage;
  final int attackRange;
  final int bodyRadius;
  final int moveSpeed;
  final double attackSpeed;
  final int spawnCount;
  final int spellRadius;
  final int spellDamage;
  final String targetRule;
  final String effectKind;
  final double effectValue;

  bool get isEquipment => type == 'equipment';

  bool get isJob => type == 'job';

  bool get usesMoney => energyCostType == 'money';

  bool get usesSpiritEnergy => energyCostType == 'spirit';

  bool get usesPhysicalEnergy => !usesSpiritEnergy && !usesMoney;

  String? characterImageUrlFor(String direction) {
    switch (direction) {
      case 'back':
        return characterBackImageUrl;
      case 'left':
        return characterLeftImageUrl;
      case 'right':
        return characterRightImageUrl;
      case 'front':
      default:
        return characterFrontImageUrl ?? characterImageUrl;
    }
  }

  String localizedName(String locale) {
    final englishFallback = nameEn.isNotEmpty ? nameEn : name;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return nameJa.isNotEmpty ? nameJa : englishFallback;
      case 'zh-Hant':
      default:
        return nameZhHant.isNotEmpty ? nameZhHant : englishFallback;
    }
  }

  factory RoyaleCard.fromJson(Map<String, dynamic> json) {
    final characterImageUrls =
        json['characterImageUrls'] as Map<String, dynamic>? ?? const {};
    final frontImageUrl = resolveRemoteImageUrl(
      (json['characterFrontImageUrl'] as String?) ??
          (characterImageUrls['front'] as String?) ??
          (json['characterImageUrl'] as String?) ??
          (json['imageUrl'] as String?),
    );
    return RoyaleCard(
      id: json['id'] as String,
      name: json['name'] as String,
      nameZhHant:
          (json['nameZhHant'] as String?) ?? (json['name'] as String? ?? ''),
      nameEn: (json['nameEn'] as String?) ?? (json['name'] as String? ?? ''),
      nameJa: (json['nameJa'] as String?) ?? (json['name'] as String? ?? ''),
      imageUrl: resolveRemoteImageUrl(json['imageUrl'] as String?),
      characterImageUrl: frontImageUrl,
      bgImageUrl: resolveRemoteImageUrl(json['bgImageUrl'] as String?),
      characterFrontImageUrl: frontImageUrl,
      characterBackImageUrl: resolveRemoteImageUrl(
        (json['characterBackImageUrl'] as String?) ??
            (characterImageUrls['back'] as String?),
      ),
      characterLeftImageUrl: resolveRemoteImageUrl(
        (json['characterLeftImageUrl'] as String?) ??
            (characterImageUrls['left'] as String?),
      ),
      characterRightImageUrl: resolveRemoteImageUrl(
        (json['characterRightImageUrl'] as String?) ??
            (characterImageUrls['right'] as String?),
      ),
      imageVersion: (json['imageVersion'] as num?)?.toInt() ?? 0,
      energyCost:
          (json['energyCost'] as num?)?.toInt() ??
          (json['elixirCost'] as num?)?.toInt() ??
          0,
      energyCostType: (json['type'] as String?) == 'equipment'
          ? 'money'
          : (json['energyCostType'] as String?) ??
                ((json['type'] as String?) == 'spell' ? 'spirit' : 'physical'),
      type: json['type'] as String,
      hp: (json['hp'] as num).toInt(),
      damage: (json['damage'] as num).toInt(),
      attackRange: (json['attackRange'] as num).toInt(),
      bodyRadius: (json['bodyRadius'] as num?)?.toInt() ?? 0,
      moveSpeed: (json['moveSpeed'] as num).toInt(),
      attackSpeed: (json['attackSpeed'] as num).toDouble(),
      spawnCount: (json['spawnCount'] as num).toInt(),
      spellRadius: (json['spellRadius'] as num).toInt(),
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

class RoyaleResourceDefinition {
  const RoyaleResourceDefinition({
    required this.initial,
    required this.max,
    required this.regenPerSecond,
  });

  final double initial;
  final double max;
  final double regenPerSecond;

  factory RoyaleResourceDefinition.fromJson(Map<String, dynamic> json) {
    return RoyaleResourceDefinition(
      initial: (json['initial'] as num?)?.toDouble() ?? 0,
      max: (json['max'] as num?)?.toDouble() ?? 0,
      regenPerSecond: (json['regenPerSecond'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RoyaleResourceState {
  const RoyaleResourceState({
    required this.current,
    required this.max,
    required this.regenPerSecond,
  });

  final double current;
  final double max;
  final double regenPerSecond;

  factory RoyaleResourceState.fromJson({
    required Map<String, dynamic> json,
    required String currentKey,
    required String maxKey,
    required String regenKey,
  }) {
    return RoyaleResourceState(
      current: (json[currentKey] as num?)?.toDouble() ?? 0,
      max: (json[maxKey] as num?)?.toDouble() ?? 0,
      regenPerSecond: (json[regenKey] as num?)?.toDouble() ?? 0,
    );
  }
}

class RoyaleHero {
  const RoyaleHero({
    required this.id,
    required this.name,
    required this.nameZhHant,
    required this.nameEn,
    required this.nameJa,
    required this.bonusSummary,
    required this.bonusSummaryZhHant,
    required this.bonusSummaryEn,
    required this.bonusSummaryJa,
    required this.bonusKind,
    required this.bonusValue,
    required this.physicalHealth,
    required this.spiritHealth,
    required this.physicalEnergy,
    required this.spiritEnergy,
    required this.money,
    required this.unitDamageMultiplier,
    required this.jobMoneyMultiplier,
    required this.jobPositiveWeightMultiplier,
    required this.jobNegativeWeightMultiplier,
    required this.mentalEventWeightMultiplier,
    required this.mentalDamageMultiplier,
    required this.mentalIllnessStageFloor,
  });

  final String id;
  final String name;
  final String nameZhHant;
  final String nameEn;
  final String nameJa;
  final String bonusSummary;
  final String bonusSummaryZhHant;
  final String bonusSummaryEn;
  final String bonusSummaryJa;
  final String bonusKind;
  final double bonusValue;
  final RoyaleResourceDefinition physicalHealth;
  final RoyaleResourceDefinition spiritHealth;
  final RoyaleResourceDefinition physicalEnergy;
  final RoyaleResourceDefinition spiritEnergy;
  final RoyaleResourceDefinition money;
  final double unitDamageMultiplier;
  final double jobMoneyMultiplier;
  final double jobPositiveWeightMultiplier;
  final double jobNegativeWeightMultiplier;
  final double mentalEventWeightMultiplier;
  final double mentalDamageMultiplier;
  final int mentalIllnessStageFloor;

  String localizedName(String locale) {
    final englishFallback = nameEn.isNotEmpty ? nameEn : name;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return nameJa.isNotEmpty ? nameJa : englishFallback;
      case 'zh-Hant':
      default:
        return nameZhHant.isNotEmpty ? nameZhHant : englishFallback;
    }
  }

  String localizedBonusSummary(String locale) {
    final englishFallback = bonusSummaryEn.isNotEmpty
        ? bonusSummaryEn
        : bonusSummary;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return bonusSummaryJa.isNotEmpty ? bonusSummaryJa : englishFallback;
      case 'zh-Hant':
      default:
        return bonusSummaryZhHant.isNotEmpty
            ? bonusSummaryZhHant
            : englishFallback;
    }
  }

  factory RoyaleHero.fromJson(Map<String, dynamic> json) {
    return RoyaleHero(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameZhHant:
          (json['nameZhHant'] as String?) ?? (json['name'] as String? ?? ''),
      nameEn: (json['nameEn'] as String?) ?? (json['name'] as String? ?? ''),
      nameJa: (json['nameJa'] as String?) ?? (json['name'] as String? ?? ''),
      bonusSummary: json['bonusSummary'] as String? ?? '',
      bonusSummaryZhHant:
          (json['bonusSummaryZhHant'] as String?) ??
          (json['bonusSummary'] as String? ?? ''),
      bonusSummaryEn:
          (json['bonusSummaryEn'] as String?) ??
          (json['bonusSummary'] as String? ?? ''),
      bonusSummaryJa:
          (json['bonusSummaryJa'] as String?) ??
          (json['bonusSummary'] as String? ?? ''),
      bonusKind: json['bonusKind'] as String? ?? 'none',
      bonusValue: (json['bonusValue'] as num?)?.toDouble() ?? 0,
      physicalHealth: RoyaleResourceDefinition.fromJson(
        json['physicalHealth'] as Map<String, dynamic>? ?? const {},
      ),
      spiritHealth: RoyaleResourceDefinition.fromJson(
        json['spiritHealth'] as Map<String, dynamic>? ?? const {},
      ),
      physicalEnergy: RoyaleResourceDefinition.fromJson(
        json['physicalEnergy'] as Map<String, dynamic>? ?? const {},
      ),
      spiritEnergy: RoyaleResourceDefinition.fromJson(
        json['spiritEnergy'] as Map<String, dynamic>? ?? const {},
      ),
      money: RoyaleResourceDefinition.fromJson(
        json['money'] as Map<String, dynamic>? ?? const {},
      ),
      unitDamageMultiplier:
          (json['unitDamageMultiplier'] as num?)?.toDouble() ?? 1,
      jobMoneyMultiplier: (json['jobMoneyMultiplier'] as num?)?.toDouble() ?? 1,
      jobPositiveWeightMultiplier:
          (json['jobPositiveWeightMultiplier'] as num?)?.toDouble() ?? 1,
      jobNegativeWeightMultiplier:
          (json['jobNegativeWeightMultiplier'] as num?)?.toDouble() ?? 1,
      mentalEventWeightMultiplier:
          (json['mentalEventWeightMultiplier'] as num?)?.toDouble() ?? 1,
      mentalDamageMultiplier:
          (json['mentalDamageMultiplier'] as num?)?.toDouble() ?? 1,
      mentalIllnessStageFloor:
          (json['mentalIllnessStageFloor'] as num?)?.toInt() ?? 1,
    );
  }
}

class RoyaleBattleEvent {
  const RoyaleBattleEvent({
    required this.id,
    required this.kind,
    required this.side,
    required this.cardId,
    required this.cardName,
    required this.cardNameZhHant,
    required this.cardNameEn,
    required this.cardNameJa,
    required this.title,
    required this.titleZhHant,
    required this.titleEn,
    required this.titleJa,
    required this.description,
    required this.descriptionZhHant,
    required this.descriptionEn,
    required this.descriptionJa,
    required this.tone,
    required this.mentalStage,
    required this.moneyDelta,
    required this.physicalHealthDelta,
    required this.spiritHealthDelta,
    required this.physicalEnergyDelta,
    required this.spiritEnergyDelta,
  });

  final String id;
  final String kind;
  final String side;
  final String cardId;
  final String cardName;
  final String cardNameZhHant;
  final String cardNameEn;
  final String cardNameJa;
  final String title;
  final String titleZhHant;
  final String titleEn;
  final String titleJa;
  final String description;
  final String descriptionZhHant;
  final String descriptionEn;
  final String descriptionJa;
  final String tone;
  final int mentalStage;
  final double moneyDelta;
  final double physicalHealthDelta;
  final double spiritHealthDelta;
  final double physicalEnergyDelta;
  final double spiritEnergyDelta;

  String localizedTitle(String locale) {
    final englishFallback = titleEn.isNotEmpty ? titleEn : title;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return titleJa.isNotEmpty ? titleJa : englishFallback;
      case 'zh-Hant':
      default:
        return titleZhHant.isNotEmpty ? titleZhHant : englishFallback;
    }
  }

  String localizedDescription(String locale) {
    final englishFallback = descriptionEn.isNotEmpty
        ? descriptionEn
        : description;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return descriptionJa.isNotEmpty ? descriptionJa : englishFallback;
      case 'zh-Hant':
      default:
        return descriptionZhHant.isNotEmpty
            ? descriptionZhHant
            : englishFallback;
    }
  }

  String localizedCardName(String locale) {
    final englishFallback = cardNameEn.isNotEmpty ? cardNameEn : cardName;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return cardNameJa.isNotEmpty ? cardNameJa : englishFallback;
      case 'zh-Hant':
      default:
        return cardNameZhHant.isNotEmpty ? cardNameZhHant : englishFallback;
    }
  }

  factory RoyaleBattleEvent.fromJson(Map<String, dynamic> json) {
    return RoyaleBattleEvent(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'job_outcome',
      side: json['side'] as String? ?? 'left',
      cardId: json['cardId'] as String? ?? '',
      cardName: json['cardName'] as String? ?? '',
      cardNameZhHant:
          (json['cardNameZhHant'] as String?) ??
          (json['cardName'] as String? ?? ''),
      cardNameEn:
          (json['cardNameEn'] as String?) ??
          (json['cardName'] as String? ?? ''),
      cardNameJa:
          (json['cardNameJa'] as String?) ??
          (json['cardName'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      titleZhHant:
          (json['titleZhHant'] as String?) ?? (json['title'] as String? ?? ''),
      titleEn: (json['titleEn'] as String?) ?? (json['title'] as String? ?? ''),
      titleJa: (json['titleJa'] as String?) ?? (json['title'] as String? ?? ''),
      description: json['description'] as String? ?? '',
      descriptionZhHant:
          (json['descriptionZhHant'] as String?) ??
          (json['description'] as String? ?? ''),
      descriptionEn:
          (json['descriptionEn'] as String?) ??
          (json['description'] as String? ?? ''),
      descriptionJa:
          (json['descriptionJa'] as String?) ??
          (json['description'] as String? ?? ''),
      tone: json['tone'] as String? ?? 'mixed',
      mentalStage: (json['mentalStage'] as num?)?.toInt() ?? 0,
      moneyDelta: (json['moneyDelta'] as num?)?.toDouble() ?? 0,
      physicalHealthDelta:
          (json['physicalHealthDelta'] as num?)?.toDouble() ?? 0,
      spiritHealthDelta: (json['spiritHealthDelta'] as num?)?.toDouble() ?? 0,
      physicalEnergyDelta:
          (json['physicalEnergyDelta'] as num?)?.toDouble() ?? 0,
      spiritEnergyDelta: (json['spiritEnergyDelta'] as num?)?.toDouble() ?? 0,
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
    required this.deckCards,
    required this.handCardIds,
    required this.queueCardIds,
    required this.hero,
    required this.botController,
    required this.ready,
    required this.connected,
    required this.physicalHealth,
    required this.spiritHealth,
    required this.physicalEnergy,
    required this.spiritEnergy,
    required this.money,
    required this.towerHp,
    required this.maxTowerHp,
  });

  final int userId;
  final String name;
  final String side;
  final int deckId;
  final String deckName;
  final List<RoyaleCard> deckCards;
  final List<String> handCardIds;
  final List<String> queueCardIds;
  final RoyaleHero hero;
  final String botController;
  final bool ready;
  final bool connected;
  final RoyaleResourceState physicalHealth;
  final RoyaleResourceState spiritHealth;
  final RoyaleResourceState physicalEnergy;
  final RoyaleResourceState spiritEnergy;
  final RoyaleResourceState money;
  final int towerHp;
  final int maxTowerHp;

  double get totalEnergy => physicalEnergy.current + spiritEnergy.current;

  double get maxEnergy => physicalEnergy.max + spiritEnergy.max;

  double get totalMoney => money.current;

  factory RoyalePlayerView.fromJson(Map<String, dynamic> json) {
    return RoyalePlayerView(
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String,
      side: json['side'] as String,
      deckId: (json['deckId'] as num).toInt(),
      deckName: json['deckName'] as String,
      deckCards: (json['deckCards'] as List<dynamic>? ?? const [])
          .map((card) => RoyaleCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      handCardIds: (json['handCardIds'] as List<dynamic>? ?? const [])
          .map((cardId) => cardId.toString())
          .toList(),
      queueCardIds: (json['queueCardIds'] as List<dynamic>? ?? const [])
          .map((cardId) => cardId.toString())
          .toList(),
      hero: RoyaleHero.fromJson(
        json['hero'] as Map<String, dynamic>? ?? const {},
      ),
      botController: (json['botController'] as String?) ?? 'heuristic',
      ready: json['ready'] as bool? ?? false,
      connected: json['connected'] as bool? ?? false,
      physicalHealth: RoyaleResourceState.fromJson(
        json: json,
        currentKey: 'physicalHealth',
        maxKey: 'maxPhysicalHealth',
        regenKey: 'physicalHealthRegen',
      ),
      spiritHealth: RoyaleResourceState.fromJson(
        json: json,
        currentKey: 'spiritHealth',
        maxKey: 'maxSpiritHealth',
        regenKey: 'spiritHealthRegen',
      ),
      physicalEnergy: RoyaleResourceState.fromJson(
        json: json,
        currentKey: 'physicalEnergy',
        maxKey: 'maxPhysicalEnergy',
        regenKey: 'physicalEnergyRegen',
      ),
      spiritEnergy: RoyaleResourceState.fromJson(
        json: json,
        currentKey: 'spiritEnergy',
        maxKey: 'maxSpiritEnergy',
        regenKey: 'spiritEnergyRegen',
      ),
      money: RoyaleResourceState.fromJson(
        json: json,
        currentKey: 'money',
        maxKey: 'maxMoney',
        regenKey: 'moneyPerSecond',
      ),
      towerHp: (json['towerHp'] as num?)?.toInt() ?? 0,
      maxTowerHp: (json['maxTowerHp'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoyaleLlmBotAction {
  const RoyaleLlmBotAction({
    required this.id,
    required this.kind,
    required this.summary,
    required this.cardIds,
    required this.dropX,
    required this.dropY,
    required this.source,
    required this.usedFallback,
    required this.reason,
  });

  final String id;
  final String kind;
  final String summary;
  final List<String> cardIds;
  final double? dropX;
  final double? dropY;
  final String source;
  final bool usedFallback;
  final String reason;

  bool get isWait => kind == 'wait';

  factory RoyaleLlmBotAction.fromJson(Map<String, dynamic> json) {
    final action = json['action'] as Map<String, dynamic>? ?? json;
    return RoyaleLlmBotAction(
      id: action['id'] as String? ?? 'wait',
      kind: action['kind'] as String? ?? 'wait',
      summary: action['summary'] as String? ?? '',
      cardIds: (action['cardIds'] as List<dynamic>? ?? const [])
          .map((cardId) => cardId.toString())
          .toList(),
      dropX: (action['dropX'] as num?)?.toDouble(),
      dropY: (action['dropY'] as num?)?.toDouble(),
      source: json['source'] as String? ?? 'fallback',
      usedFallback: json['usedFallback'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
    );
  }
}

class RoyaleUnitView {
  const RoyaleUnitView({
    required this.id,
    required this.cardId,
    required this.name,
    required this.nameZhHant,
    required this.nameEn,
    required this.nameJa,
    required this.imageUrl,
    required this.characterImageUrl,
    required this.bgImageUrl,
    this.characterFrontImageUrl,
    this.characterBackImageUrl,
    this.characterLeftImageUrl,
    this.characterRightImageUrl,
    this.facingDirection = 'forward',
    required this.side,
    required this.type,
    required this.progress,
    required this.lateralPosition,
    required this.hp,
    required this.maxHp,
    required this.attackRange,
    required this.bodyRadius,
    required this.effects,
    required this.statusEffects,
  });

  final String id;
  final String cardId;
  final String name;
  final String nameZhHant;
  final String nameEn;
  final String nameJa;
  final String? imageUrl;
  final String? characterImageUrl;
  final String? bgImageUrl;
  final String? characterFrontImageUrl;
  final String? characterBackImageUrl;
  final String? characterLeftImageUrl;
  final String? characterRightImageUrl;
  final String facingDirection;
  final String side;
  final String type;
  final int progress;
  final int lateralPosition;
  final int hp;
  final int maxHp;
  final int attackRange;
  final int bodyRadius;
  final List<String> effects;
  final List<String> statusEffects;

  String localizedName(String locale) {
    final englishFallback = nameEn.isNotEmpty ? nameEn : name;
    switch (locale) {
      case 'en':
        return englishFallback;
      case 'ja':
        return nameJa.isNotEmpty ? nameJa : englishFallback;
      case 'zh-Hant':
      default:
        return nameZhHant.isNotEmpty ? nameZhHant : englishFallback;
    }
  }

  String? characterImageUrlFor(String direction) {
    switch (direction) {
      case 'back':
        return characterBackImageUrl;
      case 'left':
        return characterLeftImageUrl;
      case 'right':
        return characterRightImageUrl;
      case 'front':
      default:
        return characterFrontImageUrl ?? characterImageUrl;
    }
  }

  String characterImageDirectionForViewer(String viewerSide) {
    switch (facingDirection) {
      case 'front':
      case 'back':
      case 'left':
      case 'right':
        return facingDirection;
      case 'forward':
      default:
        return side == viewerSide ? 'back' : 'front';
    }
  }

  String? characterImageUrlForViewer(String viewerSide) {
    final direction = characterImageDirectionForViewer(viewerSide);
    final directionalUrl = characterImageUrlFor(direction);
    if (directionalUrl != null && directionalUrl.isNotEmpty) {
      return directionalUrl;
    }

    final fallbackDirection = side == viewerSide ? 'back' : 'front';
    final fallbackUrl = characterImageUrlFor(fallbackDirection);
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return fallbackUrl;
    }
    return characterImageUrl ?? imageUrl;
  }

  factory RoyaleUnitView.fromJson(Map<String, dynamic> json) {
    final characterImageUrls =
        json['characterImageUrls'] as Map<String, dynamic>? ?? const {};
    final frontImageUrl = resolveRemoteImageUrl(
      (json['characterFrontImageUrl'] as String?) ??
          (characterImageUrls['front'] as String?) ??
          (json['characterImageUrl'] as String?) ??
          (json['imageUrl'] as String?),
    );
    return RoyaleUnitView(
      id: json['id'] as String,
      cardId: json['cardId'] as String,
      name: json['name'] as String,
      nameZhHant:
          (json['nameZhHant'] as String?) ?? (json['name'] as String? ?? ''),
      nameEn: (json['nameEn'] as String?) ?? (json['name'] as String? ?? ''),
      nameJa: (json['nameJa'] as String?) ?? (json['name'] as String? ?? ''),
      imageUrl: resolveRemoteImageUrl(json['imageUrl'] as String?),
      characterImageUrl: frontImageUrl,
      bgImageUrl: resolveRemoteImageUrl(json['bgImageUrl'] as String?),
      characterFrontImageUrl: frontImageUrl,
      characterBackImageUrl: resolveRemoteImageUrl(
        (json['characterBackImageUrl'] as String?) ??
            (characterImageUrls['back'] as String?),
      ),
      characterLeftImageUrl: resolveRemoteImageUrl(
        (json['characterLeftImageUrl'] as String?) ??
            (characterImageUrls['left'] as String?),
      ),
      characterRightImageUrl: resolveRemoteImageUrl(
        (json['characterRightImageUrl'] as String?) ??
            (characterImageUrls['right'] as String?),
      ),
      facingDirection: (json['facingDirection'] as String?) ?? 'forward',
      side: json['side'] as String,
      type: json['type'] as String,
      progress: ((json['progress'] ?? json['x']) as num).toInt(),
      lateralPosition:
          ((json['lateralPosition'] ?? json['yOffset'] ?? 500) as num).toInt(),
      hp: (json['hp'] as num?)?.toInt() ?? 0,
      maxHp: (json['maxHp'] as num?)?.toInt() ?? 0,
      attackRange: (json['attackRange'] as num?)?.toInt() ?? 0,
      bodyRadius: (json['bodyRadius'] as num?)?.toInt() ?? 0,
      effects: (json['effects'] as List<dynamic>? ?? const [])
          .map((effect) => effect.toString())
          .toList(),
      statusEffects: (json['statusEffects'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class RoyaleFieldEffect {
  const RoyaleFieldEffect({
    required this.kind,
    required this.remainingMs,
    required this.scope,
    this.side,
  });

  final String kind;
  final int remainingMs;
  final String scope;
  final String? side;

  factory RoyaleFieldEffect.fromJson(Map<String, dynamic> json) {
    return RoyaleFieldEffect(
      kind: json['kind'] as String? ?? '',
      remainingMs: (json['remainingMs'] as num?)?.toInt() ?? 0,
      scope: json['scope'] as String? ?? 'both',
      side: json['side'] as String?,
    );
  }
}

class RoyaleFieldState {
  const RoyaleFieldState({
    required this.nextEventMs,
    required this.activeEffects,
    required this.leftShield,
    required this.rightShield,
  });

  final int nextEventMs;
  final List<RoyaleFieldEffect> activeEffects;
  final bool leftShield;
  final bool rightShield;

  factory RoyaleFieldState.fromJson(Map<String, dynamic> json) {
    final shields = json['shields'] as Map<String, dynamic>? ?? const {};
    return RoyaleFieldState(
      nextEventMs: (json['nextEventMs'] as num?)?.toInt() ?? 30000,
      activeEffects: (json['activeEffects'] as List<dynamic>? ?? const [])
          .map((e) => RoyaleFieldEffect.fromJson(e as Map<String, dynamic>))
          .toList(),
      leftShield: shields['left'] as bool? ?? false,
      rightShield: shields['right'] as bool? ?? false,
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
    required this.yourMoney,
    required this.yourHand,
    required this.nextCardId,
    required this.units,
    required this.events,
    required this.result,
    this.fieldState,
  });

  final int timeRemainingMs;
  final double yourMoney;
  final List<RoyaleCard> yourHand;
  final String? nextCardId;
  final List<RoyaleUnitView> units;
  final List<RoyaleBattleEvent> events;
  final RoyaleBattleResult? result;
  final RoyaleFieldState? fieldState;

  factory RoyaleBattleView.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'] as Map<String, dynamic>?;
    return RoyaleBattleView(
      timeRemainingMs: (json['timeRemainingMs'] as num?)?.toInt() ?? 0,
      yourMoney: (json['yourMoney'] as num?)?.toDouble() ?? 0,
      yourHand: (json['yourHand'] as List<dynamic>? ?? const [])
          .map((card) => RoyaleCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      nextCardId: json['nextCardId'] as String?,
      units: (json['units'] as List<dynamic>? ?? const [])
          .map((unit) => RoyaleUnitView.fromJson(unit as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map(
            (event) =>
                RoyaleBattleEvent.fromJson(event as Map<String, dynamic>),
          )
          .toList(),
      result: resultJson == null
          ? null
          : RoyaleBattleResult.fromJson(resultJson),
      fieldState: json['fieldState'] == null
          ? null
          : RoyaleFieldState.fromJson(
              json['fieldState'] as Map<String, dynamic>,
            ),
    );
  }
}

class RoyaleRoomSnapshot {
  const RoyaleRoomSnapshot({
    required this.code,
    required this.status,
    required this.simulationMode,
    required this.hostUserId,
    required this.viewerSide,
    required this.players,
    required this.battle,
  });

  final String code;
  final String status;
  final String simulationMode;
  final int hostUserId;
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
      simulationMode: json['simulationMode'] as String? ?? 'server',
      hostUserId: (json['hostUserId'] as num?)?.toInt() ?? 0,
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
