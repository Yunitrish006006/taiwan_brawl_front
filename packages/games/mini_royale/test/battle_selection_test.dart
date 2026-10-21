import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

RoyaleCard card(
  String id, {
  String type = 'melee',
  String energy = 'physical',
}) => RoyaleCard(
  id: id,
  name: id,
  nameZhHant: id,
  nameEn: id,
  nameJa: id,
  imageUrl: null,
  characterImageUrl: null,
  bgImageUrl: null,
  imageVersion: 0,
  energyCost: 2,
  energyCostType: energy,
  type: type,
  hp: 1,
  damage: 1,
  attackRange: 1,
  bodyRadius: 1,
  moveSpeed: 1,
  attackSpeed: 1,
  spawnCount: 1,
  spellRadius: 0,
  spellDamage: 0,
  targetRule: 'ground',
  effectKind: 'none',
  effectValue: 0,
);

RoyalePlayerView player({double energy = 10, double money = 10}) {
  const definition = RoyaleResourceDefinition(
    initial: 10,
    max: 10,
    regenPerSecond: 0,
  );
  const resource = RoyaleResourceState(current: 10, max: 10, regenPerSecond: 0);
  const hero = RoyaleHero(
    id: 'hero',
    name: 'Hero',
    nameZhHant: 'Hero',
    nameEn: 'Hero',
    nameJa: 'Hero',
    bonusSummary: '',
    bonusSummaryZhHant: '',
    bonusSummaryEn: '',
    bonusSummaryJa: '',
    bonusKind: 'none',
    bonusValue: 0,
    physicalHealth: definition,
    spiritHealth: definition,
    physicalEnergy: definition,
    spiritEnergy: definition,
    money: definition,
    unitDamageMultiplier: 1,
    jobMoneyMultiplier: 1,
    jobPositiveWeightMultiplier: 1,
    jobNegativeWeightMultiplier: 1,
    mentalEventWeightMultiplier: 1,
    mentalDamageMultiplier: 1,
    mentalIllnessStageFloor: 0,
  );
  return RoyalePlayerView(
    userId: 1,
    name: 'Player',
    side: 'left',
    deckId: 1,
    deckName: 'Deck',
    deckCards: const [],
    handCardIds: const [],
    queueCardIds: const [],
    hero: hero,
    botController: 'heuristic',
    ready: true,
    connected: true,
    physicalHealth: resource,
    spiritHealth: resource,
    physicalEnergy: RoyaleResourceState(
      current: energy,
      max: energy,
      regenPerSecond: 0,
    ),
    spiritEnergy: resource,
    money: RoyaleResourceState(current: money, max: money, regenPerSecond: 0),
    towerHp: 10,
    maxTowerHp: 10,
  );
}

void main() {
  test('selection enforces combo cap and standalone job-card rule', () {
    final a = card('a');
    final b = card('b');
    final c = card('c');
    final job = card('job', type: 'job');
    final first = MiniRoyaleBattleSelection.toggle([], a);
    final second = MiniRoyaleBattleSelection.toggle(first.selectedIds, b);
    final third = MiniRoyaleBattleSelection.toggle(second.selectedIds, c);

    expect(third.selectedIds, ['a', 'b', 'c']);
    expect(
      MiniRoyaleBattleSelection.toggle(third.selectedIds, card('d')).outcome,
      MiniRoyaleSelectionOutcome.maximumReached,
    );
    expect(
      MiniRoyaleBattleSelection.toggle(first.selectedIds, job).outcome,
      MiniRoyaleSelectionOutcome.jobMustBePlayedAlone,
    );
  });

  test('game-owned selection state tracks, reconciles, and clears a hand', () {
    final state = MiniRoyaleBattleSelectionState();
    final first = card('first');
    final second = card('second');

    expect(state.toggle(first).outcome, MiniRoyaleSelectionOutcome.selected);
    expect(state.toggle(second).outcome, MiniRoyaleSelectionOutcome.selected);
    expect(state.selectedIds, ['first', 'second']);
    expect(state.resolve([second, first]).map((item) => item.id), [
      'first',
      'second',
    ]);
    expect(
      state.dragPayload([first, second], second).cards.map((item) => item.id),
      ['first', 'second'],
    );

    state.reconcileWithHand([second]);
    expect(state.selectedIds, ['second']);
    state.remove('second');
    expect(state.isEmpty, isTrue);
    state.toggle(first);
    state.clear();
    expect(state.selectedIds, isEmpty);
  });

  test(
    'selection reconciles hand snapshots and resolves in selection order',
    () {
      final hand = [card('b'), card('a')];
      final ids = MiniRoyaleBattleSelection.reconcile(['a', 'gone', 'b'], hand);

      expect(ids, ['a', 'b']);
      expect(
        MiniRoyaleBattleSelection.resolve(ids, hand).map((item) => item.id),
        ['a', 'b'],
      );
    },
  );

  test(
    'drag uses selected combo only when dragged card is a selected member',
    () {
      final a = card('a');
      final b = card('b');
      final unrelated = card('other');
      final selected = ['a', 'b'];

      expect(
        MiniRoyaleBattleSelection.dragPayload(selected, [
          a,
          b,
        ], b).cards.map((item) => item.id),
        ['a', 'b'],
      );
      expect(
        MiniRoyaleBattleSelection.dragPayload(selected, [
          a,
          b,
        ], unrelated).cards,
        [unrelated],
      );
      expect(
        MiniRoyaleBattleSelection.dragPayload([], [
          card('job', type: 'job'),
        ], card('job', type: 'job')).canDeploy,
        isFalse,
      );
    },
  );

  test('cost aggregation keeps resource types separate', () {
    final costs = MiniRoyaleBattleSelection.costs([
      card('p'),
      card('s', energy: 'spirit'),
      card('m', energy: 'money'),
    ]);

    expect((costs.physical, costs.spirit, costs.money), (2, 2, 2));
  });

  test('combo rules reject standalone equipment and mixed job cards', () {
    final equipment = card('equipment', type: 'equipment', energy: 'money');
    final unit = card('unit');
    final job = card('job', type: 'job');

    expect(
      MiniRoyaleBattleSelection.validateCombo([equipment]),
      MiniRoyaleComboError.equipmentRequiresUnit,
    );
    expect(MiniRoyaleBattleSelection.validateCombo([equipment, unit]), isNull);
    expect(
      MiniRoyaleBattleSelection.validateCombo([job, unit]),
      MiniRoyaleComboError.jobMustBePlayedAlone,
    );
    expect(MiniRoyaleBattleSelection.isJobOnlyCombo([job]), isTrue);
    expect(MiniRoyaleBattleSelection.isJobOnlyCombo([job, unit]), isFalse);
  });

  test('prepared command validates play and derives player-relative lane', () {
    final result = MiniRoyaleBattleSelection.preparePlay(
      cards: [card('unit')],
      player: player(),
      dropX: 0.5,
      dropY: 0.8,
      playerSide: 'left',
    );

    expect(result.isAccepted, isTrue);
    expect(result.command!.cardIds, ['unit']);
    expect(result.command!.lanePosition, closeTo(0.2, 1e-9));
  });

  test('prepared command rejects insufficient resources and illegal zones', () {
    final insufficient = MiniRoyaleBattleSelection.preparePlay(
      cards: [card('unit')],
      player: player(energy: 0),
      dropX: 0.5,
      dropY: 0.8,
      playerSide: 'left',
    );
    final invalidPoint = MiniRoyaleBattleSelection.preparePlay(
      cards: [card('unit')],
      player: player(),
      dropX: 0.5,
      dropY: 0.2,
      playerSide: 'left',
    );

    expect(insufficient.rejection, MiniRoyalePlayRejection.insufficientEnergy);
    expect(insufficient.energyType, 'physical');
    expect(
      invalidPoint.rejection,
      MiniRoyalePlayRejection.invalidDeploymentPoint,
    );
  });
}
