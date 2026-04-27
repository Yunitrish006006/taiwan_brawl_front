import 'dart:async';
import 'dart:math' as math;

import '../models/royale_models.dart';
import 'royale_battle_rules.dart' as battle_rules;
import 'royale_service.dart';

part 'host_battle_engine_runtime.dart';
part 'host_battle_engine_models.dart';

const int _tickMs = battle_rules.tickMs;
const int _matchDurationMs = battle_rules.matchDurationMs;
const int _towerHp = battle_rules.towerHp;
const int _maxComboCards = battle_rules.maxComboCards;
const double _globalMoveSpeedMultiplier =
    battle_rules.globalMoveSpeedMultiplier;
const double _globalAttackSpeedMultiplier =
    battle_rules.globalAttackSpeedMultiplier;

double _clamp(double value, double min, double max) =>
    battle_rules.clampBattleValue(value, min, max);

double _sideDirection(String side) => battle_rules.sideDirection(side);

double _sanitizeLanePosition(
  String side,
  double value, [
  battle_rules.BattleArenaConfig arena = battle_rules.defaultArenaConfig,
]) => battle_rules.sanitizeLanePosition(side, value, arena);

double _sanitizeLateralPosition(
  double value, [
  battle_rules.BattleArenaConfig arena = battle_rules.defaultArenaConfig,
]) => battle_rules.sanitizeLateralPosition(value, arena);

double _distanceBetweenPoints(
  double aProgress,
  double aLateral,
  double bProgress,
  double bLateral, [
  battle_rules.BattleArenaConfig arena = battle_rules.defaultArenaConfig,
]) => battle_rules.distanceBetweenPoints(
  aProgress,
  aLateral,
  bProgress,
  bLateral,
  arena,
);

double _bodyRadiusForUnitType(String type) =>
    battle_rules.bodyRadiusForUnitType(type);

String _inferCardCollisionBehavior(String type) =>
    type.trim().toLowerCase() == 'swarm' ? 'reroute' : 'hold';

String _normalizeCollisionBehavior(String? value, {String fallback = 'hold'}) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized == 'reroute') {
    return 'reroute';
  }
  if (normalized == 'hold') {
    return 'hold';
  }
  return fallback == 'reroute' ? 'reroute' : 'hold';
}

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
  HostBattleEngine({
    required RoyaleRoomSnapshot room,
    required this.onSnapshot,
    this.llmService,
    this.onNotice,
  }) : _code = room.code,
       _viewerSide = room.viewerSide ?? 'left' {
    _leftPlayer = _buildPlayer(room, 'left');
    _rightPlayer = _buildPlayer(room, 'right');
    _arena = room.battle?.arena ?? battle_rules.defaultArenaConfig;
    _battleEvents.addAll(room.battle?.events ?? const []);
  }

  final String _code;
  final String _viewerSide;
  final void Function(RoyaleRoomSnapshot snapshot) onSnapshot;
  final RoyaleService? llmService;
  final void Function(String message)? onNotice;

  late _HostPlayer _leftPlayer;
  late _HostPlayer _rightPlayer;
  late battle_rules.BattleArenaConfig _arena;
  final List<_HostUnit> _units = <_HostUnit>[];
  final List<RoyaleBattleEvent> _battleEvents = <RoyaleBattleEvent>[];
  int _nextUnitId = 1;
  int _timeRemainingMs = _matchDurationMs;
  RoyaleBattleResult? _result;
  Timer? _timer;
  final math.Random _random = math.Random();
  bool _llmDecisionPending = false;
  bool _llmFallbackWarned = false;

  // Field event state
  int _fieldNextEventMs = 0;
  final List<_HostFieldEffect> _fieldEffects = <_HostFieldEffect>[];
  bool _fieldShieldLeft = false;
  bool _fieldShieldRight = false;
  int _feUid = 0;

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
      'arena': _arena.toJson(),
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
              'characterImageUrl': unit.characterImageUrl,
              'characterFrontImageUrl': unit.characterFrontImageUrl,
              'characterBackImageUrl': unit.characterBackImageUrl,
              'characterLeftImageUrl': unit.characterLeftImageUrl,
              'characterRightImageUrl': unit.characterRightImageUrl,
              'characterAssets': _serializeCharacterAssets(
                unit.characterAssets,
              ),
              'facingDirection': unit.facingDirection,
              'animationState': unit.animationState,
              'animationEvent': unit.animationEvent == null
                  ? null
                  : {
                      'animation': unit.animationEvent,
                      'id': unit.animationEventId,
                    },
              'type': unit.type,
              'side': unit.side,
              'progress': unit.progress.round(),
              'lateralPosition': unit.lateralPosition.round(),
              'hp': unit.hp,
              'maxHp': unit.maxHp,
              'damage': unit.damage,
              'attackRange': unit.attackRange.round(),
              'bodyRadius': unit.bodyRadius.round(),
              'collisionBehavior': unit.collisionBehavior,
              'moveSpeed': unit.moveSpeed.round(),
              'attackSpeed': unit.attackSpeed,
              'targetRule': unit.targetRule,
              'cooldown': unit.cooldown,
              'effects': unit.effects,
            },
          )
          .toList(),
      'events': _battleEvents
          .map(
            (event) => {
              'id': event.id,
              'kind': event.kind,
              'side': event.side,
              'cardId': event.cardId,
              'cardName': event.cardName,
              'cardNameZhHant': event.cardNameZhHant,
              'cardNameEn': event.cardNameEn,
              'cardNameJa': event.cardNameJa,
              'title': event.title,
              'titleZhHant': event.titleZhHant,
              'titleEn': event.titleEn,
              'titleJa': event.titleJa,
              'description': event.description,
              'descriptionZhHant': event.descriptionZhHant,
              'descriptionEn': event.descriptionEn,
              'descriptionJa': event.descriptionJa,
              'tone': event.tone,
              'mentalStage': event.mentalStage,
              'moneyDelta': event.moneyDelta,
              'physicalHealthDelta': event.physicalHealthDelta,
              'spiritHealthDelta': event.spiritHealthDelta,
              'physicalEnergyDelta': event.physicalEnergyDelta,
              'spiritEnergyDelta': event.spiritEnergyDelta,
            },
          )
          .toList(),
      'fieldState': {
        'nextEventMs': _fieldNextEventMs,
        'activeEffects': _fieldEffects
            .where((e) => e.remainingMs > 0)
            .map(
              (e) => {
                'kind': e.kind,
                'remainingMs': e.remainingMs,
                'scope': e.scope,
                'side': e.side,
              },
            )
            .toList(),
        'shields': {'left': _fieldShieldLeft, 'right': _fieldShieldRight},
      },
    };
  }

  Map<String, dynamic> exportLlmBotDecisionState(String side) {
    return {
      'roomCode': _code,
      'playerSide': side,
      'timeRemainingMs': _timeRemainingMs,
      'arena': _arena.toJson(),
      'players': {
        'left': _serializeDecisionPlayer(_leftPlayer),
        'right': _serializeDecisionPlayer(_rightPlayer),
      },
      'units': _units
          .map(
            (unit) => {
              'id': unit.id,
              'cardId': unit.cardId,
              'side': unit.side,
              'type': unit.type,
              'progress': unit.progress,
              'lateralPosition': unit.lateralPosition,
              'hp': unit.hp,
              'maxHp': unit.maxHp,
              'damage': unit.damage,
              'attackRange': unit.attackRange,
              'bodyRadius': unit.bodyRadius,
              'collisionBehavior': unit.collisionBehavior,
              'moveSpeed': unit.moveSpeed,
              'attackSpeed': unit.attackSpeed,
              'targetRule': unit.targetRule,
            },
          )
          .toList(),
      'events': _battleEvents
          .map(
            (event) => {
              'id': event.id,
              'kind': event.kind,
              'side': event.side,
              'title': event.title,
              'description': event.description,
              'tone': event.tone,
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
    final hasJobCard = cards.any((card) => card.isJob);
    final hasEventCard = cards.any((card) => card.isEvent);
    final selfEquipmentOnly = _isSelfEquipmentOnlyCast(cards);

    final physicalCost = cards
        .where((card) => card.usesPhysicalEnergy)
        .fold<double>(0, (sum, card) => sum + card.energyCost);
    final spiritCost = cards
        .where((card) => card.usesSpiritEnergy)
        .fold<double>(0, (sum, card) => sum + card.energyCost);
    final moneyCost = cards
        .where((card) => card.usesMoney)
        .fold<double>(0, (sum, card) => sum + card.energyCost);
    if (player.physicalEnergy + 1e-6 < physicalCost) {
      return 'Not enough Physical Energy';
    }
    if (player.spiritEnergy + 1e-6 < spiritCost) {
      return 'Not enough Spirit Energy';
    }
    if (player.money + 1e-6 < moneyCost) {
      return 'Not enough Money';
    }

    if (hasEventCard && cards.length != 1) {
      return 'Event cards must be played alone';
    }
    if (_isEquipmentOnlyCast(cards) && !selfEquipmentOnly) {
      return 'Equipment cards need at least one unit in the same cast';
    }
    if (hasJobCard && cards.length != 1) {
      return 'Job cards must be played alone';
    }

    final dropPoint = hasJobCard || hasEventCard || selfEquipmentOnly
        ? null
        : _normalizeDropPoint(side, dropX, dropY);
    final equipmentEffects = _equipmentEffects(cards);

    for (final card in cards) {
      if (card.usesMoney) {
        _spendPlayerMoney(player, card.energyCost.toDouble());
      } else {
        _spendPlayerEnergy(
          player,
          card.energyCost.toDouble(),
          preferSpirit: card.usesSpiritEnergy,
        );
      }
    }
    _recordCardUses(player, cards);
    _drawReplacementCards(player, cardIds);

    for (final card in cards) {
      if (card.type == 'spell') {
        _resolveSpell(side, card, dropPoint!);
      } else if (card.isEvent) {
        _resolveEventCard(player, card);
      } else if (card.isJob) {
        _resolveJobCard(player, card);
      } else if (card.type != 'equipment') {
        _spawnUnits(side, card, dropPoint!, equipmentEffects);
      }
    }
    if (selfEquipmentOnly) {
      _applySelfEquipmentEffects(player, cards);
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
      if (player.remainingUsesFor(card) <= 0) {
        return const _PlayableCardsResult(
          error: 'Card deployment limit reached',
        );
      }
      cards.add(card);
    }

    return _PlayableCardsResult(cards: cards);
  }

  bool _isEquipmentOnlyCast(List<RoyaleCard> cards) {
    final hasEquipment = cards.any((card) => card.type == 'equipment');
    final hasUnit = cards.any(
      (card) =>
          card.type != 'equipment' &&
          card.type != 'spell' &&
          !card.isEvent &&
          !card.isJob,
    );
    return hasEquipment && !hasUnit;
  }

  bool _canCastEquipmentOnHero(RoyaleCard card) {
    return card.type == 'equipment' &&
        (card.targetRule == 'self' || card.targetRule == 'hero');
  }

  bool _isSelfEquipmentOnlyCast(List<RoyaleCard> cards) {
    return cards.isNotEmpty &&
        cards.every((card) => card.type == 'equipment') &&
        cards.every(_canCastEquipmentOnHero);
  }

  Map<String, dynamic> _exportPlayerState(_HostPlayer player) {
    return {
      'hand': player.hand,
      'queue': player.queue,
      'cardUses': player.cardUses,
      'cardUseLimits': player.cardUseLimits,
      'botThinkMs': player.botThinkMs,
      'physicalHealth': player.physicalHealth,
      'maxPhysicalHealth': player.maxPhysicalHealth,
      'physicalHealthRegen': player.physicalHealthRegen,
      'spiritHealth': player.spiritHealth,
      'maxSpiritHealth': player.maxSpiritHealth,
      'spiritHealthRegen': player.spiritHealthRegen,
      'physicalEnergy': player.physicalEnergy,
      'maxPhysicalEnergy': player.maxPhysicalEnergy,
      'physicalEnergyRegen': player.physicalEnergyRegen,
      'spiritEnergy': player.spiritEnergy,
      'maxSpiritEnergy': player.maxSpiritEnergy,
      'spiritEnergyRegen': player.spiritEnergyRegen,
      'money': player.money,
      'maxMoney': player.maxMoney,
      'moneyPerSecond': player.moneyPerSecond,
      'heroAttackCooldown': player.heroAttackCooldown,
      'heroAttackEventId': player.heroAttackEventId,
      'heroAttackEvent': player.heroAttackEvent,
      'towerHp': player.towerHp,
      'maxTowerHp': player.maxTowerHp,
    };
  }

  Map<String, dynamic> _serializeDecisionPlayer(_HostPlayer player) {
    return {
      'userId': player.userId,
      'name': player.name,
      'side': player.side,
      'heroId': player.hero.id,
      'isBot': player.isBot,
      'botController': player.botController,
      'deckCards': player.deckCards.map(_serializeCard).toList(),
      'handCardIds': player.hand,
      'queueCardIds': player.queue,
      'cardUses': player.cardUses,
      'cardUseLimits': player.cardUseLimits,
      'physicalHealth': player.physicalHealth,
      'maxPhysicalHealth': player.maxPhysicalHealth,
      'physicalHealthRegen': player.physicalHealthRegen,
      'spiritHealth': player.spiritHealth,
      'maxSpiritHealth': player.maxSpiritHealth,
      'spiritHealthRegen': player.spiritHealthRegen,
      'physicalEnergy': player.physicalEnergy,
      'maxPhysicalEnergy': player.maxPhysicalEnergy,
      'physicalEnergyRegen': player.physicalEnergyRegen,
      'spiritEnergy': player.spiritEnergy,
      'maxSpiritEnergy': player.maxSpiritEnergy,
      'spiritEnergyRegen': player.spiritEnergyRegen,
      'money': player.money,
      'maxMoney': player.maxMoney,
      'moneyPerSecond': player.moneyPerSecond,
      'heroAttackCooldown': player.heroAttackCooldown,
      'heroAttackEventId': player.heroAttackEventId,
      'heroAttackEvent': player.heroAttackEvent,
      'towerHp': player.towerHp,
      'maxTowerHp': player.maxTowerHp,
    };
  }

  Map<String, dynamic> _serializeCard(RoyaleCard card) {
    return {
      'id': card.id,
      'name': card.name,
      'type': card.type,
      'energyCost': card.energyCost,
      'energyCostType': card.energyCostType,
      'hp': card.hp,
      'damage': card.damage,
      'attackRange': card.attackRange,
      'bodyRadius': card.bodyRadius,
      'moveSpeed': card.moveSpeed,
      'attackSpeed': card.attackSpeed,
      'spawnCount': card.spawnCount,
      'spellRadius': card.spellRadius,
      'spellDamage': card.spellDamage,
      'targetRule': card.targetRule,
      'effectKind': card.effectKind,
      'effectValue': card.effectValue,
      'collisionBehavior': card.collisionBehavior,
    };
  }

  List<Map<String, dynamic>> _serializeCharacterAssets(
    List<RoyaleCharacterAsset> assets,
  ) {
    return assets
        .map(
          (asset) => {
            'cardId': asset.cardId,
            'assetId': asset.assetId,
            'animation': asset.animation,
            'direction': asset.direction,
            'frameIndex': asset.frameIndex,
            'durationMs': asset.durationMs,
            'loop': asset.loop,
            'assetVersion': asset.assetVersion,
            'imageUrl': asset.imageUrl,
            'fileName': asset.fileName,
            'contentType': asset.contentType,
          },
        )
        .toList();
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
      hero: view.hero,
      isBot: view.userId == 0,
      botController: view.botController,
      ready: view.ready,
      connected: view.connected,
      deckCards: deckCards,
      hand: view.handCardIds.isNotEmpty
          ? List<String>.from(view.handCardIds)
          : hand,
      queue: view.queueCardIds.isNotEmpty
          ? List<String>.from(view.queueCardIds)
          : queue,
      cardUses: Map<String, int>.from(view.cardUses),
      cardUseLimits: view.cardUseLimits.isNotEmpty
          ? Map<String, int>.from(view.cardUseLimits)
          : {for (final card in deckCards) card.id: 8},
      physicalHealth: view.physicalHealth.current,
      maxPhysicalHealth: view.physicalHealth.max,
      physicalHealthRegen: view.physicalHealth.regenPerSecond,
      spiritHealth: view.spiritHealth.current,
      maxSpiritHealth: view.spiritHealth.max,
      spiritHealthRegen: view.spiritHealth.regenPerSecond,
      physicalEnergy: view.physicalEnergy.current,
      maxPhysicalEnergy: view.physicalEnergy.max,
      physicalEnergyRegen: view.physicalEnergy.regenPerSecond,
      spiritEnergy: view.spiritEnergy.current,
      maxSpiritEnergy: view.spiritEnergy.max,
      spiritEnergyRegen: view.spiritEnergy.regenPerSecond,
      money: view.money.current,
      maxMoney: view.money.max,
      moneyPerSecond: view.money.regenPerSecond,
      towerHp: view.maxTowerHp == 0 ? _towerHp : view.towerHp,
      maxTowerHp: view.maxTowerHp == 0 ? _towerHp : view.maxTowerHp,
      heroAttackCooldown: 0,
      heroAttackEventId: 0,
      heroAttackEvent: null,
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
        handCardIds: _leftPlayer.hand,
        queueCardIds: _leftPlayer.queue,
        cardUses: _leftPlayer.cardUses,
        cardUseLimits: _leftPlayer.cardUseLimits,
        hero: _leftPlayer.hero,
        botController: _leftPlayer.botController,
        ready: _leftPlayer.ready,
        connected: _leftPlayer.connected,
        physicalHealth: RoyaleResourceState(
          current: _leftPlayer.physicalHealth,
          max: _leftPlayer.maxPhysicalHealth,
          regenPerSecond: _leftPlayer.physicalHealthRegen,
        ),
        spiritHealth: RoyaleResourceState(
          current: _leftPlayer.spiritHealth,
          max: _leftPlayer.maxSpiritHealth,
          regenPerSecond: _leftPlayer.spiritHealthRegen,
        ),
        physicalEnergy: RoyaleResourceState(
          current: _leftPlayer.physicalEnergy,
          max: _leftPlayer.maxPhysicalEnergy,
          regenPerSecond: _leftPlayer.physicalEnergyRegen,
        ),
        spiritEnergy: RoyaleResourceState(
          current: _leftPlayer.spiritEnergy,
          max: _leftPlayer.maxSpiritEnergy,
          regenPerSecond: _leftPlayer.spiritEnergyRegen,
        ),
        money: RoyaleResourceState(
          current: _leftPlayer.money,
          max: _leftPlayer.maxMoney,
          regenPerSecond: _leftPlayer.moneyPerSecond,
        ),
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
        handCardIds: _rightPlayer.hand,
        queueCardIds: _rightPlayer.queue,
        cardUses: _rightPlayer.cardUses,
        cardUseLimits: _rightPlayer.cardUseLimits,
        hero: _rightPlayer.hero,
        botController: _rightPlayer.botController,
        ready: _rightPlayer.ready,
        connected: _rightPlayer.connected,
        physicalHealth: RoyaleResourceState(
          current: _rightPlayer.physicalHealth,
          max: _rightPlayer.maxPhysicalHealth,
          regenPerSecond: _rightPlayer.physicalHealthRegen,
        ),
        spiritHealth: RoyaleResourceState(
          current: _rightPlayer.spiritHealth,
          max: _rightPlayer.maxSpiritHealth,
          regenPerSecond: _rightPlayer.spiritHealthRegen,
        ),
        physicalEnergy: RoyaleResourceState(
          current: _rightPlayer.physicalEnergy,
          max: _rightPlayer.maxPhysicalEnergy,
          regenPerSecond: _rightPlayer.physicalEnergyRegen,
        ),
        spiritEnergy: RoyaleResourceState(
          current: _rightPlayer.spiritEnergy,
          max: _rightPlayer.maxSpiritEnergy,
          regenPerSecond: _rightPlayer.spiritEnergyRegen,
        ),
        money: RoyaleResourceState(
          current: _rightPlayer.money,
          max: _rightPlayer.maxMoney,
          regenPerSecond: _rightPlayer.moneyPerSecond,
        ),
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
        yourMoney: viewerPlayer.money,
        yourHand: viewerPlayer.hand
            .map((cardId) => viewerPlayer.cardById(cardId))
            .whereType<RoyaleCard>()
            .toList(),
        nextCardId: viewerPlayer.queue.isEmpty
            ? null
            : viewerPlayer.queue.first,
        yourCardUses: viewerPlayer.cardUses,
        yourCardUseLimits: viewerPlayer.cardUseLimits,
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
                characterImageUrl: unit.characterImageUrl,
                characterFrontImageUrl: unit.characterFrontImageUrl,
                characterBackImageUrl: unit.characterBackImageUrl,
                characterLeftImageUrl: unit.characterLeftImageUrl,
                characterRightImageUrl: unit.characterRightImageUrl,
                characterAssets: unit.characterAssets,
                bgImageUrl: unit.bgImageUrl,
                facingDirection: unit.facingDirection,
                animationState: unit.animationState,
                animationEvent: unit.animationEvent == null
                    ? null
                    : RoyaleAnimationEvent(
                        animation: unit.animationEvent!,
                        id: unit.animationEventId,
                      ),
                side: unit.side,
                type: unit.type,
                progress: unit.progress.round(),
                lateralPosition: unit.lateralPosition.round(),
                hp: unit.hp,
                maxHp: unit.maxHp,
                attackRange: _displayAttackReach(unit).round(),
                bodyRadius: unit.bodyRadius.round(),
                collisionBehavior: unit.collisionBehavior,
                effects: unit.effects,
                statusEffects: unit.statusEffects,
              ),
            )
            .toList(),
        events: List<RoyaleBattleEvent>.unmodifiable(_battleEvents),
        result: _result,
        arena: _arena,
        fieldState: RoyaleFieldState(
          nextEventMs: _fieldNextEventMs.clamp(0, 30000),
          activeEffects: _fieldEffects
              .where((e) => e.remainingMs > 0)
              .map(
                (e) => RoyaleFieldEffect(
                  kind: e.kind,
                  remainingMs: e.remainingMs,
                  scope: e.scope,
                  side: e.side,
                ),
              )
              .toList(),
          leftShield: _fieldShieldLeft,
          rightShield: _fieldShieldRight,
        ),
      ),
    );
  }
}
