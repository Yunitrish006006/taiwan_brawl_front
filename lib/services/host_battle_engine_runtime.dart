part of 'host_battle_engine.dart';

class _BotSpellTarget {
  const _BotSpellTarget({
    required this.score,
    required this.point,
    required this.hits,
    required this.kills,
  });

  final double score;
  final _DropPoint point;
  final int hits;
  final int kills;
}

class _BotCardScore {
  const _BotCardScore({required this.card, required this.score});

  final RoyaleCard card;
  final double score;
}

class _JobEventTemplate {
  const _JobEventTemplate({
    required this.id,
    required this.weight,
    required this.tone,
    required this.titleZhHant,
    required this.titleEn,
    required this.titleJa,
    required this.descriptionZhHant,
    required this.descriptionEn,
    required this.descriptionJa,
    required this.moneyFactor,
    this.tags = const <String>[],
    this.mentalStage = 0,
    this.physicalHealthDelta = 0,
    this.spiritHealthDelta = 0,
    this.physicalEnergyDelta = 0,
    this.spiritEnergyDelta = 0,
  });

  final String id;
  final double weight;
  final String tone;
  final List<String> tags;
  final int mentalStage;
  final String titleZhHant;
  final String titleEn;
  final String titleJa;
  final String descriptionZhHant;
  final String descriptionEn;
  final String descriptionJa;
  final double moneyFactor;
  final double physicalHealthDelta;
  final double spiritHealthDelta;
  final double physicalEnergyDelta;
  final double spiritEnergyDelta;
}

extension _HostBattleEngineRuntime on HostBattleEngine {
  int _randomBotThinkMs() {
    return battle_rules.randomBotThinkMs(_random);
  }

  double _roundMetric(double value) => double.parse(value.toStringAsFixed(1));

  double _heroBonusMultiplier(_HostPlayer player, String bonusKind) {
    return player.hero.bonusKind == bonusKind ? player.hero.bonusValue : 1;
  }

  double _playerEnergyForType(_HostPlayer player, String energyType) {
    return energyType == 'spirit' ? player.spiritEnergy : player.physicalEnergy;
  }

  double _cardEnergyCost(RoyaleCard card) => card.energyCost.toDouble();

  String _cardEnergyType(RoyaleCard card) =>
      card.usesSpiritEnergy ? 'spirit' : 'physical';

  void _syncPlayerTotals(_HostPlayer player) {
    player.physicalHealth = _clamp(
      player.physicalHealth,
      0,
      player.maxPhysicalHealth,
    );
    player.spiritHealth = _clamp(
      player.spiritHealth,
      0,
      player.maxSpiritHealth,
    );
    player.physicalEnergy = _clamp(
      player.physicalEnergy,
      0,
      player.maxPhysicalEnergy,
    );
    player.spiritEnergy = _clamp(
      player.spiritEnergy,
      0,
      player.maxSpiritEnergy,
    );
    player.money = _clamp(player.money, 0, player.maxMoney);
    player.towerHp = (player.physicalHealth + player.spiritHealth).round();
  }

  bool _spendPlayerEnergy(
    _HostPlayer player,
    double amount, {
    required bool preferSpirit,
  }) {
    final available = preferSpirit ? player.spiritEnergy : player.physicalEnergy;
    if (available + 1e-6 < amount) {
      return false;
    }
    if (preferSpirit) {
      player.spiritEnergy -= amount;
    } else {
      player.physicalEnergy -= amount;
    }
    _syncPlayerTotals(player);
    return true;
  }

  void _applyTowerDamage(
    _HostPlayer player,
    int damage, {
    required bool preferSpirit,
  }) {
    var remaining = damage.toDouble();
    if (preferSpirit) {
      final spiritDrain = math.min(player.spiritHealth, remaining);
      player.spiritHealth -= spiritDrain;
      remaining -= spiritDrain;
      final physicalDrain = math.min(player.physicalHealth, remaining);
      player.physicalHealth -= physicalDrain;
    } else {
      final physicalDrain = math.min(player.physicalHealth, remaining);
      player.physicalHealth -= physicalDrain;
      remaining -= physicalDrain;
      final spiritDrain = math.min(player.spiritHealth, remaining);
      player.spiritHealth -= spiritDrain;
    }
    _syncPlayerTotals(player);
  }

  void _adjustPlayerResources(
    _HostPlayer player, {
    double moneyDelta = 0,
    double physicalHealthDelta = 0,
    double spiritHealthDelta = 0,
    double physicalEnergyDelta = 0,
    double spiritEnergyDelta = 0,
  }) {
    player.money += moneyDelta;
    player.physicalHealth += physicalHealthDelta;
    player.spiritHealth += spiritHealthDelta;
    player.physicalEnergy += physicalEnergyDelta;
    player.spiritEnergy += spiritEnergyDelta;
    _syncPlayerTotals(player);
  }

  void _regeneratePlayerResources(_HostPlayer player, double dt) {
    player.physicalHealth = _clamp(
      player.physicalHealth + player.physicalHealthRegen * dt,
      0,
      player.maxPhysicalHealth,
    );
    player.spiritHealth = _clamp(
      player.spiritHealth + player.spiritHealthRegen * dt,
      0,
      player.maxSpiritHealth,
    );
    player.physicalEnergy = _clamp(
      player.physicalEnergy + player.physicalEnergyRegen * dt,
      0,
      player.maxPhysicalEnergy,
    );
    player.spiritEnergy = _clamp(
      player.spiritEnergy + player.spiritEnergyRegen * dt,
      0,
      player.maxSpiritEnergy,
    );
    player.money = _clamp(
      player.money + player.moneyPerSecond * dt,
      0,
      player.maxMoney,
    );
    _syncPlayerTotals(player);
  }

  List<_JobEventTemplate> _jobEventsForProfile(String profile) {
    switch (profile) {
      case 'job_delivery':
        return const [
          _JobEventTemplate(
            id: 'surge_bonus',
            weight: 1.15,
            tone: 'positive',
            titleZhHant: '尖峰加成',
            titleEn: 'Surge Bonus',
            titleJa: 'ピーク加算',
            descriptionZhHant: '剛好卡進高峰獎勵區間，這趟外送意外很賺。',
            descriptionEn:
                'You hit the surge window just right. This delivery paid unexpectedly well.',
            descriptionJa: 'ちょうどピーク加算に乗って、この配達はかなり稼げた。',
            moneyFactor: 1.45,
            physicalEnergyDelta: -0.8,
            spiritEnergyDelta: -0.3,
          ),
          _JobEventTemplate(
            id: 'empty_trip',
            weight: 1,
            tone: 'negative',
            titleZhHant: '白跑一趟',
            titleEn: 'Dead Run',
            titleJa: '空振り配達',
            descriptionZhHant: '接單又被取消，你花了力氣，卻只拿到零碎補貼。',
            descriptionEn:
                'The order got canceled mid-run. You burned energy for scraps.',
            descriptionJa: '配達中にキャンセルされ、体力だけ使って小銭しか残らなかった。',
            moneyFactor: 0.2,
            physicalEnergyDelta: -0.7,
            spiritHealthDelta: -16,
          ),
          _JobEventTemplate(
            id: 'traffic_brush',
            weight: 0.92,
            tone: 'negative',
            titleZhHant: '擦撞驚魂',
            titleEn: 'Near Crash',
            titleJa: '接触事故寸前',
            descriptionZhHant: '趕單趕到差點出事，雖然有收入，但身體明顯被消耗。',
            descriptionEn:
                'You pushed too hard chasing the order and almost crashed. Your body paid for it.',
            descriptionJa:
                '配達を急ぎすぎて事故寸前。収入はあっても体への負担が大きい。',
            moneyFactor: 0.92,
            physicalHealthDelta: -45,
            physicalEnergyDelta: -1,
          ),
          _JobEventTemplate(
            id: 'big_tip',
            weight: 0.8,
            tone: 'positive',
            titleZhHant: '客人給大賞',
            titleEn: 'Big Tip',
            titleJa: '太っ腹チップ',
            descriptionZhHant: '客人心情太好，這單的回報幾乎翻倍。',
            descriptionEn:
                'A generous customer doubled the value of the run with a huge tip.',
            descriptionJa: '太っ腹な客のおかげで、この配達はほぼ倍の価値になった。',
            moneyFactor: 1.8,
            physicalEnergyDelta: -0.9,
          ),
        ];
      case 'job_day_labor':
        return const [
          _JobEventTemplate(
            id: 'cash_job',
            weight: 1.05,
            tone: 'positive',
            titleZhHant: '現領粗工',
            titleEn: 'Cash Labor',
            titleJa: '現金日雇い',
            descriptionZhHant: '這班是現領，錢拿得快，但身體也被磨得很明顯。',
            descriptionEn:
                'This was a cash job. The pay came fast, but your body felt every second.',
            descriptionJa: '現金払いの仕事で即金は入ったが、体への負荷も大きかった。',
            moneyFactor: 1.7,
            physicalHealthDelta: -28,
            physicalEnergyDelta: -1.1,
          ),
          _JobEventTemplate(
            id: 'boss_meal',
            weight: 0.9,
            tone: 'mixed',
            titleZhHant: '老闆請便當',
            titleEn: 'Boss Bought Lunch',
            titleJa: '親方のおごり',
            descriptionZhHant: '工很硬，但中午有人請吃飯，精神稍微穩住一點。',
            descriptionEn:
                'The work was rough, but lunch on the boss softened the blow.',
            descriptionJa: '仕事はきつかったが、親方のおごりで少し気持ちが持ち直した。',
            moneyFactor: 1.15,
            physicalEnergyDelta: -0.75,
            spiritHealthDelta: 18,
          ),
          _JobEventTemplate(
            id: 'wage_docked',
            weight: 0.95,
            tone: 'negative',
            tags: ['mental'],
            mentalStage: 1,
            titleZhHant: '被莫名扣薪',
            titleEn: 'Pay Docked',
            titleJa: '謎の減給',
            descriptionZhHant: '工做完了卻被扣錢，精神壓力整個湧上來。',
            descriptionEn:
                'You finished the work, but the pay got cut anyway. The stress hit hard.',
            descriptionJa: '仕事は終えたのに賃金を削られ、ストレスが一気にのしかかった。',
            moneyFactor: 0.48,
            spiritHealthDelta: -36,
            spiritEnergyDelta: -0.6,
          ),
          _JobEventTemplate(
            id: 'veteran_rate',
            weight: 0.72,
            tone: 'positive',
            titleZhHant: '熟手價加成',
            titleEn: 'Veteran Rate',
            titleJa: '熟練手当',
            descriptionZhHant: '今天接到熟手價，賺得很多，但你也真的快散了。',
            descriptionEn:
                'You landed a veteran-rate shift. The money was great, the wear was real.',
            descriptionJa: '熟練手当の現場に入れた。収入は大きいが、消耗も激しい。',
            moneyFactor: 2.08,
            physicalHealthDelta: -40,
            physicalEnergyDelta: -1.3,
          ),
        ];
      case 'job_part_time':
      default:
        return const [
          _JobEventTemplate(
            id: 'extra_shift',
            weight: 1.2,
            tone: 'positive',
            titleZhHant: '臨時頂班',
            titleEn: 'Extra Shift',
            titleJa: '臨時シフト',
            descriptionZhHant: '有人臨時請假，你硬補進班表，多賺到一筆現金。',
            descriptionEn:
                'Someone bailed on their shift. You covered it and pocketed extra cash.',
            descriptionJa: '急な欠員が出て、代打でシフトに入り追加収入を得た。',
            moneyFactor: 1.25,
            physicalEnergyDelta: -0.4,
            spiritEnergyDelta: -0.3,
          ),
          _JobEventTemplate(
            id: 'schedule_cut',
            weight: 1,
            tone: 'negative',
            titleZhHant: '班表被砍',
            titleEn: 'Hours Cut',
            titleJa: 'シフト削減',
            descriptionZhHant: '店裡突然砍班，你白跑一趟，只拿到很少的錢。',
            descriptionEn:
                'The shop cut your hours at the last second. You barely earned anything.',
            descriptionJa: '急にシフトが削られ、ほとんど稼げなかった。',
            moneyFactor: 0.35,
            spiritHealthDelta: -18,
            spiritEnergyDelta: -0.5,
          ),
          _JobEventTemplate(
            id: 'rude_customer',
            weight: 0.95,
            tone: 'negative',
            tags: ['mental'],
            mentalStage: 1,
            titleZhHant: '奧客爆氣',
            titleEn: 'Customer Meltdown',
            titleJa: '迷惑客の暴走',
            descriptionZhHant: '你被奧客連續輸出，錢是拿到了，但精神被磨掉一層。',
            descriptionEn:
                'A nightmare customer unloaded on you. You got paid, but your mind took a hit.',
            descriptionJa: '迷惑客に絡まれ、給料は出たがメンタルを削られた。',
            moneyFactor: 0.78,
            spiritHealthDelta: -32,
            spiritEnergyDelta: -0.8,
          ),
          _JobEventTemplate(
            id: 'tips_night',
            weight: 0.85,
            tone: 'positive',
            titleZhHant: '小費爆發',
            titleEn: 'Tip Frenzy',
            titleJa: 'チップ大当たり',
            descriptionZhHant: '今晚客人心情好，額外的小費讓收入直接拉高。',
            descriptionEn:
                'Customers were generous tonight. Tips pushed your income way up.',
            descriptionJa: '客の機嫌が良く、チップで収入が一気に跳ねた。',
            moneyFactor: 1.65,
            physicalEnergyDelta: -0.5,
            spiritEnergyDelta: -0.2,
          ),
        ];
    }
  }

  _JobEventTemplate _pickWeightedJobEvent(
    _HostPlayer player,
    List<_JobEventTemplate> templates,
  ) {
    final weighted = templates.map((entry) {
      var weight = entry.weight;
      if (entry.tags.contains('mental')) {
        weight *= player.hero.mentalEventWeightMultiplier;
      }
      if (entry.tone == 'positive') {
        weight *= player.hero.jobPositiveWeightMultiplier;
      }
      if (entry.tone == 'negative') {
        weight *= player.hero.jobNegativeWeightMultiplier;
      }
      return MapEntry(entry, math.max(0.01, weight));
    }).toList();
    final totalWeight = weighted.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );
    var threshold = _random.nextDouble() * totalWeight;
    for (final entry in weighted) {
      threshold -= entry.value;
      if (threshold <= 0) {
        return entry.key;
      }
    }
    return weighted.last.key;
  }

  ({
    String titleZhHant,
    String titleEn,
    String titleJa,
    String descriptionZhHant,
    String descriptionEn,
    String descriptionJa,
  })
  _mentalStageText(int stage) {
    if (stage <= 1) {
      return (
        titleZhHant: '精神疾病 I：焦慮失眠',
        titleEn: 'Mental Illness I: Anxiety Spiral',
        titleJa: '精神疾患 I：不安と不眠',
        descriptionZhHant: '壓力累積到開始失眠與焦躁，精神恢復明顯變慢。',
        descriptionEn:
            'Pressure built into insomnia and anxiety. Your mind is recovering much slower.',
        descriptionJa: 'ストレスが不眠と焦燥に変わり、メンタルの回復が鈍っている。',
      );
    }
    final mania = _random.nextDouble() < 0.5;
    if (mania) {
      return (
        titleZhHant: '精神疾病 II：躁症發作',
        titleEn: 'Mental Illness II: Manic Break',
        titleJa: '精神疾患 II：躁状態',
        descriptionZhHant: '你被高壓與過勞推進躁症狀態，精神耗損進一步擴大。',
        descriptionEn:
            'Stress and overwork tipped you into mania, amplifying the mental crash.',
        descriptionJa: '高圧と過労で躁状態に入り、精神の消耗がさらに増した。',
      );
    }
    return (
      titleZhHant: '精神疾病 II：鬱症發作',
      titleEn: 'Mental Illness II: Depressive Crash',
      titleJa: '精神疾患 II：うつ状態',
      descriptionZhHant: '壓力把你壓進鬱症發作，精神與體力一起往下掉。',
      descriptionEn:
          'The pressure collapsed into depression, dragging both mind and body down.',
      descriptionJa: 'ストレスがうつ状態へ崩れ、心身の両方が落ち込んだ。',
    );
  }

  void _appendBattleEvent(RoyaleBattleEvent event) {
    _battleEvents
      ..add(event)
      ..removeRange(
        0,
        math.max(0, _battleEvents.length - 6),
      );
  }

  _DropPoint _normalizeDropPoint(String side, double dropX, double dropY) {
    final point = battle_rules.normalizeDropPoint(
      side,
      dropX: dropX,
      dropY: dropY,
      lanePosition: null,
    );
    return _DropPoint(
      progress: point.progress,
      lateralPosition: point.lateralPosition,
    );
  }

  void _drawReplacementCards(_HostPlayer player, List<String> cardIds) {
    for (final cardId in cardIds) {
      final handIndex = player.hand.indexOf(cardId);
      if (handIndex == -1) {
        continue;
      }
      player.hand.removeAt(handIndex);
      player.queue.add(cardId);
    }

    for (var index = 0; index < cardIds.length; index += 1) {
      if (player.queue.isEmpty) {
        break;
      }
      player.hand.add(player.queue.removeAt(0));
    }
  }

  List<_EquipmentEffect> _equipmentEffects(List<RoyaleCard> cards) {
    return cards
        .where((card) => card.type == 'equipment')
        .map(
          (card) => _EquipmentEffect(
            id: card.id,
            name: card.name,
            kind: card.effectKind,
            value: card.effectValue,
          ),
        )
        .toList();
  }

  void _resolveJobCard(_HostPlayer player, RoyaleCard card) {
    final profile = _jobEventsForProfile(card.effectKind);
    final picked = _pickWeightedJobEvent(player, profile);
    final finalStage = picked.mentalStage <= 0
        ? 0
        : math.max(
            picked.mentalStage,
            player.hero.mentalIllnessStageFloor,
          );

    var spiritHealthDelta = picked.spiritHealthDelta;
    var spiritEnergyDelta = picked.spiritEnergyDelta;
    var physicalEnergyDelta = picked.physicalEnergyDelta;
    if (picked.mentalStage > 0) {
      spiritHealthDelta *= player.hero.mentalDamageMultiplier;
      spiritEnergyDelta *= player.hero.mentalDamageMultiplier;
      if (finalStage >= 2) {
        spiritHealthDelta -= 26;
        spiritEnergyDelta -= 0.7;
        physicalEnergyDelta -= 0.25;
      }
    }

    final mentalText = finalStage > 0 ? _mentalStageText(finalStage) : null;
    final moneyDelta = _roundMetric(
      card.effectValue * picked.moneyFactor * player.hero.jobMoneyMultiplier,
    );
    final event = RoyaleBattleEvent(
      id: 'job-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}',
      kind: 'job_outcome',
      side: player.side,
      cardId: card.id,
      cardName: card.name,
      cardNameZhHant: card.nameZhHant,
      cardNameEn: card.nameEn,
      cardNameJa: card.nameJa,
      title: mentalText?.titleEn ?? picked.titleEn,
      titleZhHant: mentalText?.titleZhHant ?? picked.titleZhHant,
      titleEn: mentalText?.titleEn ?? picked.titleEn,
      titleJa: mentalText?.titleJa ?? picked.titleJa,
      description: mentalText?.descriptionEn ?? picked.descriptionEn,
      descriptionZhHant:
          mentalText?.descriptionZhHant ?? picked.descriptionZhHant,
      descriptionEn: mentalText?.descriptionEn ?? picked.descriptionEn,
      descriptionJa: mentalText?.descriptionJa ?? picked.descriptionJa,
      tone: picked.tone,
      mentalStage: finalStage,
      moneyDelta: moneyDelta,
      physicalHealthDelta: _roundMetric(picked.physicalHealthDelta),
      spiritHealthDelta: _roundMetric(spiritHealthDelta),
      physicalEnergyDelta: _roundMetric(physicalEnergyDelta),
      spiritEnergyDelta: _roundMetric(spiritEnergyDelta),
    );

    _adjustPlayerResources(
      player,
      moneyDelta: event.moneyDelta,
      physicalHealthDelta: event.physicalHealthDelta,
      spiritHealthDelta: event.spiritHealthDelta,
      physicalEnergyDelta: event.physicalEnergyDelta,
      spiritEnergyDelta: event.spiritEnergyDelta,
    );
    _appendBattleEvent(event);
  }

  _UnitStats _applyEquipmentEffects(
    RoyaleCard card,
    List<_EquipmentEffect> effects,
  ) {
    var hp = card.hp.toDouble();
    var damage = card.damage.toDouble();
    var moveSpeed = card.moveSpeed * _globalMoveSpeedMultiplier;

    for (final effect in effects) {
      if (effect.kind == 'damage_boost') {
        damage += effect.value;
      } else if (effect.kind == 'health_boost') {
        hp += effect.value;
      } else if (effect.kind == 'speed_boost') {
        moveSpeed *= 1 + effect.value;
      }
    }

    return _UnitStats(
      hp: hp.round(),
      damage: damage.round(),
      moveSpeed: moveSpeed,
    );
  }

  void _resolveSpell(String side, RoyaleCard card, _DropPoint dropPoint) {
    final enemySide = _enemySide(side);
    final enemyPlayer = _playerForSide(enemySide);
    final caster = _playerForSide(side);
    final spellDamage = (card.spellDamage *
            _heroBonusMultiplier(caster, 'spell_damage_multiplier'))
        .round();

    for (final unit in _units) {
      if (unit.side == side) {
        continue;
      }
      if (_distanceBetweenPoints(
            unit.progress,
            unit.lateralPosition,
            dropPoint.progress,
            dropPoint.lateralPosition,
          ) <=
          card.spellRadius) {
        unit.hp -= spellDamage;
      }
    }

    final towerProgress = enemySide == 'left' ? _leftTowerX : _rightTowerX;
    if (_distanceBetweenPoints(
          towerProgress.toDouble(),
          (_worldScale / 2).toDouble(),
          dropPoint.progress,
          dropPoint.lateralPosition,
        ) <=
        card.spellRadius + 50) {
      _applyTowerDamage(enemyPlayer, spellDamage, preferSpirit: true);
    }
  }

  void _spawnUnits(
    String side,
    RoyaleCard card,
    _DropPoint dropPoint,
    List<_EquipmentEffect> equipmentEffects,
  ) {
    final count = math.max(1, card.spawnCount);
    final spacing = count == 1 ? 0.0 : 30 / _fieldAspectRatio;
    final stats = _applyEquipmentEffects(card, equipmentEffects);
    final caster = _playerForSide(side);
    final boostedHp = math.max(
      1,
      (stats.hp * _heroBonusMultiplier(caster, 'unit_hp_multiplier')).round(),
    );
    final boostedDamage = math.max(
      1,
      (stats.damage * caster.hero.unitDamageMultiplier).round(),
    );
    for (var index = 0; index < count; index += 1) {
      final offset = (index - (count - 1) / 2) * spacing;
      _units.add(
        _HostUnit(
          id: 'unit-${_nextUnitId++}',
          cardId: card.id,
          name: card.name,
          nameZhHant: card.nameZhHant,
          nameEn: card.nameEn,
          nameJa: card.nameJa,
          imageUrl: card.imageUrl,
          type: card.type,
          side: side,
          progress: dropPoint.progress,
          lateralPosition: _sanitizeLateralPosition(
            dropPoint.lateralPosition + offset,
          ),
          hp: boostedHp,
          maxHp: boostedHp,
          damage: boostedDamage,
          attackRange: card.attackRange.toDouble(),
          bodyRadius: card.bodyRadius > 0
              ? card.bodyRadius.toDouble()
              : _bodyRadiusForUnitType(card.type),
          moveSpeed: stats.moveSpeed,
          attackSpeed: card.attackSpeed * _globalAttackSpeedMultiplier,
          targetRule: card.targetRule,
          cooldown: 0,
          effects: equipmentEffects.map((effect) => effect.name).toList(),
        ),
      );
    }
  }

  _TargetSelection? _selectTarget(_HostUnit unit) {
    final direction = _sideDirection(unit.side);
    final enemySide = _enemySide(unit.side);
    final towerProgress = enemySide == 'left' ? _leftTowerX : _rightTowerX;
    final towerForwardDistance = (towerProgress - unit.progress) * direction;
    final towerDistance = _distanceBetweenPoints(
      unit.progress,
      unit.lateralPosition,
      towerProgress.toDouble(),
      (_worldScale / 2).toDouble(),
    );
    final towerReach = _effectiveAttackReachToTower(unit);

    if (unit.targetRule == 'tower') {
      if (towerForwardDistance >= 0 && towerDistance <= towerReach) {
        return _TargetSelection.tower(
          targetSide: enemySide,
          distance: towerDistance,
        );
      }
      return null;
    }

    final enemyUnits =
        _units
            .where((entry) => entry.side != unit.side && entry.hp > 0)
            .map(
              (entry) => _TargetSelection.unit(
                target: entry,
                forwardDistance: (entry.progress - unit.progress) * direction,
                distance: _distanceBetweenPoints(
                  unit.progress,
                  unit.lateralPosition,
                  entry.progress,
                  entry.lateralPosition,
                ),
              ),
            )
            .where((entry) => entry.forwardDistance >= -20)
            .toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));

    final enemyUnit = enemyUnits.isEmpty ? null : enemyUnits.first;
    if (enemyUnit != null &&
        enemyUnit.distance <=
            _effectiveAttackReachToUnit(unit, enemyUnit.unitTarget!)) {
      return enemyUnit;
    }

    if (towerForwardDistance >= 0 && towerDistance <= towerReach) {
      return _TargetSelection.tower(
        targetSide: enemySide,
        distance: towerDistance,
      );
    }

    if (enemyUnit != null && enemyUnit.forwardDistance < 120) {
      return enemyUnit;
    }
    return null;
  }

  void _performAttack(_HostUnit unit, _TargetSelection target) {
    if (target.kind == 'unit') {
      target.unitTarget!.hp -= unit.damage;
      return;
    }
    final enemyPlayer = _playerForSide(target.targetSide!);
    _applyTowerDamage(enemyPlayer, unit.damage, preferSpirit: false);
  }

  double _ownTowerProgressForSide(String side) {
    return side == 'left' ? _leftTowerX.toDouble() : _rightTowerX.toDouble();
  }

  double _averageLateralPosition(Iterable<_HostUnit> units) {
    final unitList = units.toList();
    if (unitList.isEmpty) {
      return (_worldScale / 2).toDouble();
    }
    return unitList
            .map((unit) => unit.lateralPosition)
            .reduce((a, b) => a + b) /
        unitList.length;
  }

  double _distanceToOwnTower(String side, double progress) {
    return (progress - _ownTowerProgressForSide(side)).abs();
  }

  _HostUnit? _selectPriorityThreat(String side, List<_HostUnit> enemyUnits) {
    if (enemyUnits.isEmpty) {
      return null;
    }
    final sorted = enemyUnits.toList()
      ..sort((a, b) {
        final aTowerDistance = _distanceToOwnTower(side, a.progress);
        final bTowerDistance = _distanceToOwnTower(side, b.progress);
        final aScore =
            (1000 - aTowerDistance) +
            a.damage * 0.7 +
            a.maxHp * 0.08 +
            (a.targetRule == 'tower' ? 180 : 0) +
            (a.type == 'swarm' ? 70 : 0);
        final bScore =
            (1000 - bTowerDistance) +
            b.damage * 0.7 +
            b.maxHp * 0.08 +
            (b.targetRule == 'tower' ? 180 : 0) +
            (b.type == 'swarm' ? 70 : 0);
        return bScore.compareTo(aScore);
      });
    return sorted.first;
  }

  _HostUnit? _selectAlliedFront(String side, List<_HostUnit> alliedUnits) {
    if (alliedUnits.isEmpty) {
      return null;
    }
    final direction = _sideDirection(side);
    final sorted = alliedUnits.toList()
      ..sort(
        (a, b) => (b.progress * direction).compareTo(a.progress * direction),
      );
    return sorted.first;
  }

  bool _isUrgentThreat(String side, _HostUnit? threat) {
    if (threat == null) {
      return false;
    }
    return _distanceToOwnTower(side, threat.progress) < 260;
  }

  double _cardPowerScore(RoyaleCard card) {
    return card.damage * 1.25 +
        card.hp * 0.06 +
        card.attackRange * 0.18 +
        card.moveSpeed * 0.1 +
        math.max(1, card.spawnCount) * 55;
  }

  _BotSpellTarget? _evaluateSpellTarget(String side, RoyaleCard spellCard) {
    final enemyUnits = _units
        .where((unit) => unit.side != side && unit.hp > 0)
        .toList();
    if (enemyUnits.isEmpty) {
      return null;
    }

    _BotSpellTarget? bestTarget;
    for (final candidate in enemyUnits) {
      final hitUnits = enemyUnits
          .where(
            (unit) =>
                _distanceBetweenPoints(
                  unit.progress,
                  unit.lateralPosition,
                  candidate.progress,
                  candidate.lateralPosition,
                ) <=
                spellCard.spellRadius,
          )
          .toList();
      if (hitUnits.isEmpty) {
        continue;
      }

      final totalDamage = hitUnits.fold<double>(
        0,
        (sum, unit) =>
            sum + math.min(unit.hp, spellCard.spellDamage).toDouble(),
      );
      final killCount = hitUnits.where((unit) => unit.hp <= spellCard.spellDamage).length;
      final minimumThreatDistance = hitUnits
          .map((unit) => _distanceToOwnTower(side, unit.progress))
          .reduce(math.min);
      final score = totalDamage +
          hitUnits.length * 110 +
          killCount * 160 +
          (minimumThreatDistance < 260 ? 120 : 0);
      final progress =
          hitUnits.map((unit) => unit.progress).reduce((a, b) => a + b) /
          hitUnits.length;
      final lateralPosition = _averageLateralPosition(hitUnits);
      if (bestTarget == null || score > bestTarget.score) {
        bestTarget = _BotSpellTarget(
          score: score,
          point: _DropPoint(
            progress: progress,
            lateralPosition: lateralPosition,
          ),
          hits: hitUnits.length,
          kills: killCount,
        );
      }
    }

    return bestTarget;
  }

  double _scorePrimaryCard(
    String side,
    _HostPlayer player,
    RoyaleCard card,
    _HostUnit? alliedFront,
    _HostUnit? threat,
  ) {
    final urgentThreat = _isUrgentThreat(side, threat);
    final enemySide = _enemySide(side);
    final ownTowerHp = player.towerHp;
    final enemyTowerHp = _playerForSide(enemySide).towerHp;

    if (card.isJob) {
      var score = card.effectValue * 12 - _cardEnergyCost(card) * 6;
      if (player.money <= player.maxMoney * 0.25) {
        score += 180;
      } else if (player.money <= player.maxMoney * 0.5) {
        score += 90;
      } else {
        score -= 40;
      }
      if (urgentThreat) {
        score -= 70;
      }
      return score;
    }

    if (card.type == 'spell') {
      final spellTarget = _evaluateSpellTarget(side, card);
      if (spellTarget == null) {
        return -220.0;
      }
      var score = spellTarget.score - _cardEnergyCost(card) * 12.0;
      if (spellTarget.kills >= 2) {
        score += 120;
      }
      if (urgentThreat) {
        score += 80;
      }
      return score;
    }

    var score = _cardPowerScore(card) - _cardEnergyCost(card) * 32.0;
    if (card.attackRange >= 200) {
      score += 80;
    }
    if (card.targetRule == 'tower') {
      score += urgentThreat ? -140 : 180;
    }
    if (urgentThreat) {
      score += card.attackRange >= 200 ? 120 : 50;
      score += card.spawnCount >= 3 ? 110 : 0;
      score += _cardEnergyCost(card) <= 3 ? 70 : 0;
    } else {
      score += alliedFront != null && card.attackRange >= 200 ? 130 : 0;
      score += alliedFront != null && card.targetRule == 'tower' ? 60 : 0;
      score += alliedFront == null && card.type == 'tank' ? 90 : 0;
    }

    if (ownTowerHp < enemyTowerHp - 500) {
      score += card.targetRule == 'tower' ? -80 : 90;
    } else if (ownTowerHp > enemyTowerHp + 400) {
      score += card.targetRule == 'tower' ? 60 : 0;
    }

    if (player.totalEnergy >= 8 && card.type == 'tank') {
      score += 40;
    }

    return score;
  }

  double _scoreEquipmentCard(RoyaleCard primaryCard, RoyaleCard equipmentCard) {
    var score = 40.0 - _cardEnergyCost(equipmentCard) * 8.0;
    switch (equipmentCard.effectKind) {
      case 'damage_boost':
        score +=
            primaryCard.damage * 0.18 +
            math.max(1, primaryCard.spawnCount) * 40;
        break;
      case 'health_boost':
        score += primaryCard.hp * 0.07 + (primaryCard.type == 'tank' ? 80 : 0);
        break;
      case 'speed_boost':
        score += primaryCard.moveSpeed * 0.18;
        score += primaryCard.targetRule == 'tower' ? 90 : 20;
        break;
      default:
        score -= 40;
        break;
    }
    return score;
  }

  _DropPoint _buildBotDropPoint(String side, RoyaleCard primaryCard) {
    final enemyUnits = _units
        .where((unit) => unit.side != side && unit.hp > 0)
        .toList();
    final alliedUnits = _units
        .where((unit) => unit.side == side && unit.hp > 0)
        .toList();
    final threat = _selectPriorityThreat(side, enemyUnits);
    final alliedFront = _selectAlliedFront(side, alliedUnits);
    final defaultLateral = _averageLateralPosition(enemyUnits);

    if (primaryCard.type == 'spell') {
      final spellTarget = _evaluateSpellTarget(side, primaryCard);
      if (spellTarget != null) {
        return _DropPoint(
          progress: _sanitizeLanePosition(side, spellTarget.point.progress),
          lateralPosition: _sanitizeLateralPosition(
            spellTarget.point.lateralPosition,
          ),
        );
      }
    }

    var progress = primaryCard.targetRule == 'tower'
        ? (side == 'left' ? 360.0 : 640.0)
        : (side == 'left' ? 280.0 : 720.0);
    var lateralPosition = defaultLateral;

    if (_isUrgentThreat(side, threat)) {
      final defensiveOffset = primaryCard.attackRange >= 200 ? 130.0 : 70.0;
      progress = threat!.progress - _sideDirection(side) * defensiveOffset;
      lateralPosition = threat.lateralPosition;
    } else if (alliedFront != null) {
      final supportOffset = primaryCard.attackRange >= 200
          ? 110.0
          : primaryCard.targetRule == 'tower'
          ? 30.0
          : 75.0;
      progress = alliedFront.progress - _sideDirection(side) * supportOffset;
      lateralPosition = alliedFront.lateralPosition;
    } else if (threat != null) {
      progress = threat.progress - _sideDirection(side) * 90.0;
      lateralPosition = threat.lateralPosition;
    }

    return _DropPoint(
      progress: _sanitizeLanePosition(side, progress),
      lateralPosition: _sanitizeLateralPosition(lateralPosition),
    );
  }

  List<RoyaleCard> _chooseBotCombo(_HostPlayer player) {
    final handCards = player.hand
        .map((cardId) => player.cardById(cardId))
        .whereType<RoyaleCard>()
        .toList();
    final affordable = handCards
        .where(
          (card) =>
              _playerEnergyForType(player, _cardEnergyType(card)) + 1e-6 >=
              _cardEnergyCost(card),
        )
        .toList();
    if (affordable.isEmpty) {
      return const [];
    }

    final playableJobs = affordable.where((card) => card.isJob).toList();
    final playableUnits = affordable
        .where(
          (card) =>
              !card.isJob &&
              card.type != 'equipment' &&
              card.type != 'spell',
        )
        .toList();
    final playableSpells = affordable
        .where((card) => card.type == 'spell')
        .toList();
    final playableEquipment = affordable
        .where((card) => card.type == 'equipment')
        .toList();

    final enemyUnits = _units
        .where((unit) => unit.side != player.side && unit.hp > 0)
        .toList();
    final alliedUnits = _units
        .where((unit) => unit.side == player.side && unit.hp > 0)
        .toList();
    final threat = _selectPriorityThreat(player.side, enemyUnits);
    final alliedFront = _selectAlliedFront(player.side, alliedUnits);

    final scoredCards = <_BotCardScore>[];
    for (final card in [...playableJobs, ...playableUnits, ...playableSpells]) {
      scoredCards.add(
        _BotCardScore(
          card: card,
          score: _scorePrimaryCard(
            player.side,
            player,
            card,
            alliedFront,
            threat,
          ),
        ),
      );
    }
    scoredCards.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return a.card.energyCost.compareTo(b.card.energyCost);
    });
    final primaryCard = scoredCards.isEmpty ? null : scoredCards.first.card;
    if (primaryCard == null) {
      return const [];
    }

    final comboCards = <RoyaleCard>[primaryCard];
    if (!primaryCard.isJob &&
        primaryCard.type != 'spell' &&
        playableEquipment.isNotEmpty) {
      final remainingEnergy = <String, double>{
        'physical': player.physicalEnergy,
        'spirit': player.spiritEnergy,
      };
      remainingEnergy[_cardEnergyType(primaryCard)] =
          (remainingEnergy[_cardEnergyType(primaryCard)] ?? 0) -
          _cardEnergyCost(primaryCard);
      final scoredEquipment = playableEquipment
          .map(
            (card) => _BotCardScore(
              card: card,
              score: _scoreEquipmentCard(primaryCard, card),
            ),
          )
          .where((entry) => entry.score > 45)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      for (final entry in scoredEquipment) {
        if (comboCards.length >= _maxComboCards) {
          break;
        }
        if (_cardEnergyCost(entry.card) >
            (remainingEnergy[_cardEnergyType(entry.card)] ?? 0) + 1e-6) {
          continue;
        }
        comboCards.add(entry.card);
        remainingEnergy[_cardEnergyType(entry.card)] =
            (remainingEnergy[_cardEnergyType(entry.card)] ?? 0) -
            _cardEnergyCost(entry.card);
      }
    }
    return comboCards;
  }

  void _runBotTurns() {
    final botPlayer = [
      _leftPlayer,
      _rightPlayer,
    ].firstWhere((player) => player.isBot, orElse: () => _leftPlayer);
    if (!botPlayer.isBot) {
      return;
    }

    botPlayer.botThinkMs = math.max(0, botPlayer.botThinkMs - _tickMs);
    if (botPlayer.botThinkMs > 0) {
      return;
    }

    final comboCards = _chooseBotCombo(botPlayer);
    botPlayer.botThinkMs = _randomBotThinkMs();
    if (comboCards.isEmpty) {
      return;
    }

    RoyaleCard primaryCard = comboCards.first;
    for (final card in comboCards) {
      if (card.type != 'equipment') {
        primaryCard = card;
        break;
      }
    }
    final dropPoint = _buildBotDropPoint(botPlayer.side, primaryCard);
    final jitter = primaryCard.type == 'spell' ? 0.0 : 28 / _fieldAspectRatio;
    final lateralPosition = _sanitizeLateralPosition(
      dropPoint.lateralPosition + (_random.nextDouble() - 0.5) * jitter,
    );
    final dropY = botPlayer.side == 'left'
        ? _worldScale - dropPoint.progress
        : dropPoint.progress;

    final error = _playSideCombo(
      botPlayer.side,
      comboCards,
      dropX: lateralPosition,
      dropY: dropY,
    );
    if (error == null) {
      _emitSnapshot();
    }
  }

  String? _playSideCombo(
    String side,
    List<RoyaleCard> cards, {
    required double dropX,
    required double dropY,
  }) {
    final player = _playerForSide(side);
    final hasJobCard = cards.any((card) => card.isJob);
    if (hasJobCard && cards.length != 1) {
      return 'Job cards must be played alone';
    }
    final physicalCost = cards
        .where((card) => !card.usesSpiritEnergy)
        .fold<double>(0, (sum, card) => sum + _cardEnergyCost(card));
    final spiritCost = cards
        .where((card) => card.usesSpiritEnergy)
        .fold<double>(0, (sum, card) => sum + _cardEnergyCost(card));
    if (player.physicalEnergy + 1e-6 < physicalCost) {
      return 'Not enough Physical Energy';
    }
    if (player.spiritEnergy + 1e-6 < spiritCost) {
      return 'Not enough Spirit Energy';
    }

    final dropPoint = hasJobCard ? null : _normalizeDropPoint(side, dropX, dropY);
    final equipmentEffects = _equipmentEffects(cards);
    for (final card in cards) {
      _spendPlayerEnergy(
        player,
        _cardEnergyCost(card),
        preferSpirit: card.usesSpiritEnergy,
      );
    }
    _drawReplacementCards(player, cards.map((card) => card.id).toList());

    for (final card in cards) {
      if (card.type == 'spell') {
        _resolveSpell(side, card, dropPoint!);
      } else if (card.isJob) {
        _resolveJobCard(player, card);
      } else if (card.type != 'equipment') {
        _spawnUnits(side, card, dropPoint!, equipmentEffects);
      }
    }
    return null;
  }

  void _tick() {
    if (_result != null) {
      dispose();
      return;
    }

    final dt = _tickMs / 1000;
    _timeRemainingMs -= _tickMs;
    _regeneratePlayerResources(_leftPlayer, dt);
    _regeneratePlayerResources(_rightPlayer, dt);

    _runBotTurns();

    for (final unit in _units) {
      if (unit.hp <= 0) {
        continue;
      }

      unit.cooldown = math.max(0, unit.cooldown - dt);
      final target = _selectTarget(unit);
      final attackReach = target == null
          ? 0.0
          : target.kind == 'unit'
          ? _effectiveAttackReachToUnit(unit, target.unitTarget!)
          : _effectiveAttackReachToTower(unit);
      if (target != null && target.distance <= attackReach) {
        if (unit.cooldown <= 0) {
          _performAttack(unit, target);
          unit.cooldown = unit.attackSpeed;
        }
      } else {
        unit.progress = _clamp(
          unit.progress + _sideDirection(unit.side) * unit.moveSpeed * dt,
          80,
          920,
        );
        final desiredLateral = target?.kind == 'unit'
            ? target!.unitTarget!.lateralPosition
            : (_worldScale / 2).toDouble();
        final lateralDelta = desiredLateral - unit.lateralPosition;
        final lateralStep = (unit.moveSpeed * 0.45 * dt) / _fieldAspectRatio;
        unit.lateralPosition = _sanitizeLateralPosition(
          unit.lateralPosition +
              _clamp(lateralDelta, -lateralStep, lateralStep),
        );
      }
    }

    _units.removeWhere((unit) => unit.hp <= 0);

    if (_leftPlayer.towerHp <= 0 || _rightPlayer.towerHp <= 0) {
      final winnerSide = _leftPlayer.towerHp <= 0 && _rightPlayer.towerHp <= 0
          ? null
          : _leftPlayer.towerHp <= 0
          ? 'right'
          : 'left';
      _finish(winnerSide, 'tower_destroyed');
      return;
    }

    if (_timeRemainingMs <= 0) {
      String? winnerSide;
      if (_leftPlayer.towerHp != _rightPlayer.towerHp) {
        winnerSide = _leftPlayer.towerHp > _rightPlayer.towerHp
            ? 'left'
            : 'right';
      }
      _finish(winnerSide, 'time_up');
      return;
    }

    _emitSnapshot();
  }

  void _finish(String? winnerSide, String reason) {
    _result = RoyaleBattleResult(winnerSide: winnerSide, reason: reason);
    dispose();
    _emitSnapshot();
  }
}
