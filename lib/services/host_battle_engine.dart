import 'dart:async';
import 'dart:math' as math;

import '../models/royale_models.dart';
import 'royale_battle_rules.dart' as battle_rules;

part 'host_battle_engine_runtime.dart';
part 'host_battle_engine_models.dart';

const int _tickMs = battle_rules.tickMs;
const int _matchDurationMs = battle_rules.matchDurationMs;
const int _worldScale = battle_rules.worldScale;
const double _maxElixir = battle_rules.maxElixir;
const double _elixirPerSecond = battle_rules.elixirPerSecond;
const int _leftTowerX = battle_rules.leftTowerX;
const int _rightTowerX = battle_rules.rightTowerX;
const int _towerHp = battle_rules.towerHp;
const int _maxComboCards = battle_rules.maxComboCards;
const double _globalMoveSpeedMultiplier =
    battle_rules.globalMoveSpeedMultiplier;
const double _globalAttackSpeedMultiplier =
    battle_rules.globalAttackSpeedMultiplier;
const double _fieldAspectRatio = battle_rules.fieldAspectRatio;

double _clamp(double value, double min, double max) =>
    battle_rules.clampBattleValue(value, min, max);

double _sideDirection(String side) => battle_rules.sideDirection(side);

double _sanitizeLanePosition(String side, double value) =>
    battle_rules.sanitizeLanePosition(side, value);

double _sanitizeLateralPosition(double value) =>
    battle_rules.sanitizeLateralPosition(value);

double _distanceBetweenPoints(
  double aProgress,
  double aLateral,
  double bProgress,
  double bLateral,
) => battle_rules.distanceBetweenPoints(
  aProgress,
  aLateral,
  bProgress,
  bLateral,
);

double _bodyRadiusForUnitType(String type) =>
    battle_rules.bodyRadiusForUnitType(type);

double _displayAttackReach(_HostUnit unit) => battle_rules.displayAttackReach(
  attackRange: unit.attackRange,
  bodyRadius: unit.bodyRadius,
);

double _effectiveAttackReachToUnit(_HostUnit unit, _HostUnit target) =>
    battle_rules.effectiveAttackReachToUnit(
      attackRange: unit.attackRange,
      bodyRadius: unit.bodyRadius,
      targetBodyRadius: target.bodyRadius,
    );

double _effectiveAttackReachToTower(_HostUnit unit) =>
    battle_rules.effectiveAttackReachToTower(
      attackRange: unit.attackRange,
      bodyRadius: unit.bodyRadius,
    );

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
    final playableCards = _resolvePlayableCards(player, cardIds);
    if (playableCards.error != null) {
      return playableCards.error;
    }
    final cards = playableCards.cards;

    final totalElixirCost = cards.fold<double>(
      0,
      (sum, card) => sum + card.elixirCost,
    );
    if (player.elixir + 1e-6 < totalElixirCost) {
      return 'Not enough elixir';
    }

    if (_isEquipmentOnlyCast(cards)) {
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

  _PlayableCardsResult _resolvePlayableCards(
    _HostPlayer player,
    List<String> cardIds,
  ) {
    final cards = <RoyaleCard>[];
    final remainingHand = List<String>.from(player.hand);

    for (final cardId in cardIds) {
      final handIndex = remainingHand.indexOf(cardId);
      if (handIndex == -1) {
        return const _PlayableCardsResult(
          error: 'One of the selected cards is not in hand',
        );
      }
      remainingHand.removeAt(handIndex);

      final card = player.cardById(cardId);
      if (card == null) {
        return const _PlayableCardsResult(error: 'Unknown card');
      }
      cards.add(card);
    }

    return _PlayableCardsResult(cards: cards);
  }

  bool _isEquipmentOnlyCast(List<RoyaleCard> cards) {
    final hasEquipment = cards.any((card) => card.type == 'equipment');
    final hasUnit = cards.any(
      (card) => card.type != 'equipment' && card.type != 'spell',
    );
    return hasEquipment && !hasUnit;
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
