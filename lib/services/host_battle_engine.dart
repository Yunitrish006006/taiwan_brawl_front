import 'dart:async';
import 'dart:math' as math;

import '../models/royale_models.dart';

const int _tickMs = 100;
const int _matchDurationMs = 210000;
const int _worldScale = 1000;
const double _maxElixir = 10;
const double _elixirPerSecond = 0.8;
const int _leftTowerX = 50;
const int _rightTowerX = 950;
const int _leftDeployMax = 420;
const int _rightDeployMin = 580;
const int _towerHp = 3000;
const int _lateralMin = 120;
const int _lateralMax = 880;
const int _maxComboCards = 3;
const int _botMinThinkMs = 950;
const int _botMaxThinkMs = 1800;
const double _globalMoveSpeedMultiplier = 0.58;
const double _globalAttackSpeedMultiplier = 1.18;
const double _fieldAspectRatio = 0.62;
const int _towerBodyRadius = 30;

int _toWorldInteger(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.abs() <= 1 ? (value * _worldScale).round() : value.round();
}

double _toNormalizedWorld(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.abs() <= 1 ? value : value / _worldScale;
}

double _clamp(double value, double min, double max) {
  return math.max(min, math.min(max, value));
}

double _sideDirection(String side) {
  return side == 'left' ? 1 : -1;
}

List<double> _deployRangeForSide(String side) {
  return side == 'left'
      ? [80, _leftDeployMax.toDouble()]
      : [_rightDeployMin.toDouble(), 920];
}

double _sanitizeLanePosition(String side, double value) {
  final range = _deployRangeForSide(side);
  final min = math.min(range[0], range[1]);
  final max = math.max(range[0], range[1]);
  if (!value.isFinite) {
    return (min + max) / 2;
  }
  return _clamp(value, min, max);
}

double _sanitizeLateralPosition(double value) {
  if (!value.isFinite) {
    return (_worldScale / 2).toDouble();
  }
  return _clamp(value, _lateralMin.toDouble(), _lateralMax.toDouble());
}

double _toWorldProgress(String side, double viewY) {
  final normalizedY = _clamp(_toNormalizedWorld(viewY), 0, 1);
  final worldY = (normalizedY * _worldScale).roundToDouble();
  return side == 'left' ? _worldScale - worldY : worldY;
}

double _distanceBetweenPoints(
  double aProgress,
  double aLateral,
  double bProgress,
  double bLateral,
) {
  return math.sqrt(
    math.pow(aProgress - bProgress, 2) +
        math.pow((aLateral - bLateral) * _fieldAspectRatio, 2),
  );
}

double _bodyRadiusForUnitType(String type) {
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

double _displayAttackReach(_HostUnit unit) {
  return unit.attackRange + unit.bodyRadius;
}

double _effectiveAttackReachToUnit(_HostUnit unit, _HostUnit target) {
  return _displayAttackReach(unit) + target.bodyRadius;
}

double _effectiveAttackReachToTower(_HostUnit unit) {
  return _displayAttackReach(unit) + _towerBodyRadius;
}

class HostBattleEngine {
  HostBattleEngine({required RoyaleRoomSnapshot room, required this.onSnapshot})
    : _code = room.code,
      _viewerSide = room.viewerSide ?? 'left' {
    _leftPlayer = _buildPlayer(room, 'left');
    _rightPlayer = _buildPlayer(room, 'right');
    _emitSnapshot();
  }

  final String _code;
  final String _viewerSide;
  final void Function(RoyaleRoomSnapshot snapshot) onSnapshot;

  late _HostPlayer _leftPlayer;
  late _HostPlayer _rightPlayer;
  final List<_HostUnit> _units = <_HostUnit>[];
  int _nextUnitId = 1;
  int _timeRemainingMs = _matchDurationMs;
  RoyaleBattleResult? _result;
  Timer? _timer;
  final math.Random _random = math.Random();

  void start() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      _tick();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  RoyaleRoomSnapshot get snapshot => _snapshot();

  Map<String, dynamic> exportBattleState() {
    return {
      'timeRemainingMs': _timeRemainingMs,
      'nextUnitId': _nextUnitId,
      'result': _result == null
          ? null
          : {'winnerSide': _result!.winnerSide, 'reason': _result!.reason},
      'players': {
        'left': _exportPlayerState(_leftPlayer),
        'right': _exportPlayerState(_rightPlayer),
      },
      'units': _units
          .map(
            (unit) => {
              'id': unit.id,
              'cardId': unit.cardId,
              'name': unit.name,
              'nameZhHant': unit.nameZhHant,
              'nameEn': unit.nameEn,
              'nameJa': unit.nameJa,
              'imageUrl': unit.imageUrl,
              'type': unit.type,
              'side': unit.side,
              'progress': unit.progress.round(),
              'lateralPosition': unit.lateralPosition.round(),
              'hp': unit.hp,
              'maxHp': unit.maxHp,
              'damage': unit.damage,
              'attackRange': unit.attackRange.round(),
              'bodyRadius': unit.bodyRadius.round(),
              'moveSpeed': unit.moveSpeed.round(),
              'attackSpeed': unit.attackSpeed,
              'targetRule': unit.targetRule,
              'cooldown': unit.cooldown,
              'effects': unit.effects,
            },
          )
          .toList(),
    };
  }

  String? playCombo(
    List<RoyaleCard> cards, {
    required double dropX,
    required double dropY,
  }) {
    return _playComboForSide(
      side: _viewerSide,
      cardIds: cards.map((card) => card.id).toList(),
      dropX: dropX,
      dropY: dropY,
    );
  }

  String? applyRemoteCombo({
    required String side,
    required List<String> cardIds,
    required double dropX,
    required double dropY,
  }) {
    return _playComboForSide(
      side: side,
      cardIds: cardIds,
      dropX: dropX,
      dropY: dropY,
    );
  }

  String? _playComboForSide({
    required String side,
    required List<String> cardIds,
    required double dropX,
    required double dropY,
  }) {
    if (_result != null) {
      return null;
    }
    if (cardIds.isEmpty) {
      return 'Select at least one card';
    }
    if (cardIds.length > _maxComboCards) {
      return 'You can cast at most 3 cards';
    }

    final player = _playerForSide(side);
    final cards = <RoyaleCard>[];
    final remainingHand = List<String>.from(player.hand);
    for (final cardId in cardIds) {
      final handIndex = remainingHand.indexOf(cardId);
      if (handIndex == -1) {
        return 'One of the selected cards is not in hand';
      }
      remainingHand.removeAt(handIndex);
      final card = player.cardById(cardId);
      if (card == null) {
        return 'Unknown card';
      }
      cards.add(card);
    }

    final totalElixirCost = cards.fold<double>(
      0,
      (sum, card) => sum + card.elixirCost,
    );
    if (player.elixir + 1e-6 < totalElixirCost) {
      return 'Not enough elixir';
    }

    final hasEquipment = cards.any((card) => card.type == 'equipment');
    final hasUnit = cards.any(
      (card) => card.type != 'equipment' && card.type != 'spell',
    );
    if (hasEquipment && !hasUnit) {
      return 'Equipment cards need at least one unit in the same cast';
    }

    final dropPoint = _normalizeDropPoint(side, dropX, dropY);
    final equipmentEffects = _equipmentEffects(cards);

    player.elixir = _clamp(player.elixir - totalElixirCost, 0, _maxElixir);
    _drawReplacementCards(player, cardIds);

    for (final card in cards) {
      if (card.type == 'spell') {
        _resolveSpell(side, card, dropPoint);
      } else if (card.type != 'equipment') {
        _spawnUnits(side, card, dropPoint, equipmentEffects);
      }
    }

    _emitSnapshot();
    return null;
  }

  Map<String, dynamic> _exportPlayerState(_HostPlayer player) {
    return {
      'elixir': player.elixir,
      'hand': player.hand,
      'queue': player.queue,
      'botThinkMs': player.botThinkMs,
      'towerHp': player.towerHp,
      'maxTowerHp': player.maxTowerHp,
    };
  }

  _HostPlayer _buildPlayer(RoyaleRoomSnapshot room, String side) {
    final view = room.players.firstWhere((player) => player.side == side);
    final deckCards = view.deckCards;
    if (deckCards.isEmpty) {
      throw StateError(
        'Host simulation requires full deck data for both players',
      );
    }
    final deckCardIds = deckCards.map((card) => card.id).toList();
    final hand = deckCardIds.take(4).toList();
    final queue = deckCardIds.skip(4).toList();
    return _HostPlayer(
      userId: view.userId,
      name: view.name,
      side: side,
      deckId: view.deckId,
      deckName: view.deckName,
      isBot: view.userId == 0,
      ready: view.ready,
      connected: view.connected,
      deckCards: deckCards,
      hand: view.handCardIds.isNotEmpty
          ? List<String>.from(view.handCardIds)
          : hand,
      queue: view.queueCardIds.isNotEmpty
          ? List<String>.from(view.queueCardIds)
          : queue,
      elixir: view.elixir ?? 5,
      towerHp: view.maxTowerHp == 0 ? _towerHp : view.maxTowerHp,
      maxTowerHp: view.maxTowerHp == 0 ? _towerHp : view.maxTowerHp,
      botThinkMs: view.userId == 0 ? _randomBotThinkMs() : 0,
    );
  }

  _HostPlayer _playerForSide(String side) {
    return side == 'left' ? _leftPlayer : _rightPlayer;
  }

  String _enemySide(String side) {
    return side == 'left' ? 'right' : 'left';
  }

  int _randomBotThinkMs() {
    return _botMinThinkMs +
        _random.nextInt(_botMaxThinkMs - _botMinThinkMs + 1);
  }

  _DropPoint _normalizeDropPoint(String side, double dropX, double dropY) {
    return _DropPoint(
      progress: _sanitizeLanePosition(side, _toWorldProgress(side, dropY)),
      lateralPosition: _sanitizeLateralPosition(
        _toWorldInteger(dropX).toDouble(),
      ),
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

  void _emitSnapshot() {
    onSnapshot(_snapshot());
  }

  RoyaleRoomSnapshot _snapshot() {
    final viewerPlayer = _playerForSide(_viewerSide);
    final players = [
      RoyalePlayerView(
        userId: _leftPlayer.userId,
        name: _leftPlayer.name,
        side: _leftPlayer.side,
        deckId: _leftPlayer.deckId,
        deckName: _leftPlayer.deckName,
        deckCards: _leftPlayer.deckCards,
        elixir: _leftPlayer.elixir,
        handCardIds: _leftPlayer.hand,
        queueCardIds: _leftPlayer.queue,
        ready: _leftPlayer.ready,
        connected: _leftPlayer.connected,
        towerHp: _leftPlayer.towerHp,
        maxTowerHp: _leftPlayer.maxTowerHp,
      ),
      RoyalePlayerView(
        userId: _rightPlayer.userId,
        name: _rightPlayer.name,
        side: _rightPlayer.side,
        deckId: _rightPlayer.deckId,
        deckName: _rightPlayer.deckName,
        deckCards: _rightPlayer.deckCards,
        elixir: _rightPlayer.elixir,
        handCardIds: _rightPlayer.hand,
        queueCardIds: _rightPlayer.queue,
        ready: _rightPlayer.ready,
        connected: _rightPlayer.connected,
        towerHp: _rightPlayer.towerHp,
        maxTowerHp: _rightPlayer.maxTowerHp,
      ),
    ];

    return RoyaleRoomSnapshot(
      code: _code,
      status: _result == null ? 'battle' : 'finished',
      simulationMode: 'host',
      hostUserId: _leftPlayer.userId,
      viewerSide: _viewerSide,
      players: players,
      battle: RoyaleBattleView(
        timeRemainingMs: _timeRemainingMs,
        yourElixir: viewerPlayer.elixir,
        yourHand: viewerPlayer.hand
            .map((cardId) => viewerPlayer.cardById(cardId))
            .whereType<RoyaleCard>()
            .toList(),
        nextCardId: viewerPlayer.queue.isEmpty
            ? null
            : viewerPlayer.queue.first,
        units: _units
            .map(
              (unit) => RoyaleUnitView(
                id: unit.id,
                cardId: unit.cardId,
                name: unit.name,
                nameZhHant: unit.nameZhHant,
                nameEn: unit.nameEn,
                nameJa: unit.nameJa,
                imageUrl: unit.imageUrl,
                side: unit.side,
                type: unit.type,
                progress: unit.progress.round(),
                lateralPosition: unit.lateralPosition.round(),
                hp: unit.hp,
                maxHp: unit.maxHp,
                attackRange: _displayAttackReach(unit).round(),
                bodyRadius: unit.bodyRadius.round(),
                effects: unit.effects,
              ),
            )
            .toList(),
        result: _result,
      ),
    );
  }
}

class _HostPlayer {
  _HostPlayer({
    required this.userId,
    required this.name,
    required this.side,
    required this.deckId,
    required this.deckName,
    required this.isBot,
    required this.ready,
    required this.connected,
    required this.deckCards,
    required this.hand,
    required this.queue,
    required this.elixir,
    required this.towerHp,
    required this.maxTowerHp,
    required this.botThinkMs,
  });

  final int userId;
  final String name;
  final String side;
  final int deckId;
  final String deckName;
  final bool isBot;
  bool ready;
  bool connected;
  final List<RoyaleCard> deckCards;
  final List<String> hand;
  final List<String> queue;
  double elixir;
  int towerHp;
  final int maxTowerHp;
  int botThinkMs;

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
