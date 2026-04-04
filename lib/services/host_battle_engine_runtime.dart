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

extension _HostBattleEngineRuntime on HostBattleEngine {
  int _randomBotThinkMs() {
    return battle_rules.randomBotThinkMs(_random);
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
        unit.hp -= card.spellDamage;
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
      enemyPlayer.towerHp = math.max(0, enemyPlayer.towerHp - card.spellDamage);
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
          hp: stats.hp,
          maxHp: stats.hp,
          damage: stats.damage,
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
    enemyPlayer.towerHp = math.max(0, enemyPlayer.towerHp - unit.damage);
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

    if (card.type == 'spell') {
      final spellTarget = _evaluateSpellTarget(side, card);
      if (spellTarget == null) {
        return -220.0;
      }
      var score = spellTarget.score - card.elixirCost * 12.0;
      if (spellTarget.kills >= 2) {
        score += 120;
      }
      if (urgentThreat) {
        score += 80;
      }
      return score;
    }

    var score = _cardPowerScore(card) - card.elixirCost * 32.0;
    if (card.attackRange >= 200) {
      score += 80;
    }
    if (card.targetRule == 'tower') {
      score += urgentThreat ? -140 : 180;
    }
    if (urgentThreat) {
      score += card.attackRange >= 200 ? 120 : 50;
      score += card.spawnCount >= 3 ? 110 : 0;
      score += card.elixirCost <= 3 ? 70 : 0;
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

    if (player.elixir >= 8 && card.type == 'tank') {
      score += 40;
    }

    return score;
  }

  double _scoreEquipmentCard(RoyaleCard primaryCard, RoyaleCard equipmentCard) {
    var score = 40.0 - equipmentCard.elixirCost * 8.0;
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
        .where((card) => card.elixirCost <= player.elixir + 1e-6)
        .toList();
    if (affordable.isEmpty) {
      return const [];
    }

    final playableUnits = affordable
        .where((card) => card.type != 'equipment' && card.type != 'spell')
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
    for (final card in [...playableUnits, ...playableSpells]) {
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
      return a.card.elixirCost.compareTo(b.card.elixirCost);
    });
    final primaryCard = scoredCards.isEmpty ? null : scoredCards.first.card;
    if (primaryCard == null) {
      return const [];
    }

    final comboCards = <RoyaleCard>[primaryCard];
    if (primaryCard.type != 'spell' && playableEquipment.isNotEmpty) {
      var remainingElixir = player.elixir - primaryCard.elixirCost;
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
        if (entry.card.elixirCost > remainingElixir + 1e-6) {
          continue;
        }
        comboCards.add(entry.card);
        remainingElixir -= entry.card.elixirCost;
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
    final totalElixirCost = cards.fold<double>(
      0,
      (sum, card) => sum + card.elixirCost,
    );
    if (player.elixir + 1e-6 < totalElixirCost) {
      return 'Not enough elixir';
    }

    final dropPoint = _normalizeDropPoint(side, dropX, dropY);
    final equipmentEffects = _equipmentEffects(cards);
    player.elixir = _clamp(player.elixir - totalElixirCost, 0, _maxElixir);
    _drawReplacementCards(player, cards.map((card) => card.id).toList());

    for (final card in cards) {
      if (card.type == 'spell') {
        _resolveSpell(side, card, dropPoint);
      } else if (card.type != 'equipment') {
        _spawnUnits(side, card, dropPoint, equipmentEffects);
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
    _leftPlayer.elixir = _clamp(
      _leftPlayer.elixir + _elixirPerSecond * dt,
      0,
      _maxElixir,
    );
    _rightPlayer.elixir = _clamp(
      _rightPlayer.elixir + _elixirPerSecond * dt,
      0,
      _maxElixir,
    );

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
