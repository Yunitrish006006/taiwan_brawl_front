part of 'host_battle_engine.dart';

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

    RoyaleCard? primaryCard;
    if (playableUnits.isNotEmpty) {
      primaryCard = playableUnits[_random.nextInt(playableUnits.length)];
    } else if (playableSpells.isNotEmpty) {
      primaryCard = playableSpells[_random.nextInt(playableSpells.length)];
    }
    if (primaryCard == null) {
      return const [];
    }

    final comboCards = <RoyaleCard>[primaryCard];
    if (primaryCard.type != 'spell' &&
        playableEquipment.isNotEmpty &&
        _random.nextDouble() < 0.4) {
      RoyaleCard? candidate;
      for (final card in playableEquipment) {
        if (card.elixirCost + primaryCard.elixirCost <= player.elixir + 1e-6) {
          candidate = card;
          break;
        }
      }
      if (candidate != null) {
        comboCards.add(candidate);
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

    final enemyUnits = _units.where(
      (unit) => unit.side != botPlayer.side && unit.hp > 0,
    );
    final averageEnemyLateral = enemyUnits.isEmpty
        ? (_worldScale / 2).toDouble()
        : enemyUnits
                  .map((unit) => unit.lateralPosition)
                  .reduce((a, b) => a + b) /
              enemyUnits.length;
    final progress = _sanitizeLanePosition(
      botPlayer.side,
      botPlayer.side == 'left'
          ? 260 + _random.nextDouble() * 80
          : 660 + _random.nextDouble() * 80,
    );
    final lateralPosition = _sanitizeLateralPosition(
      averageEnemyLateral +
          (_random.nextDouble() - 0.5) * (140 / _fieldAspectRatio),
    );
    final dropY = botPlayer.side == 'left' ? _worldScale - progress : progress;

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
