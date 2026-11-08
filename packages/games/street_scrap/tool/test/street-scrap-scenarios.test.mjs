import test from 'node:test';
import assert from 'node:assert/strict';
import { loadDesign } from '../audit-street-scrap-design.mjs';
import { canPack, DesignLedger, runScenarios, reliefAfterDays, simulateThreeNodeRoute } from '../simulate-street-scrap-design.mjs';

const { spec, recipes } = loadDesign();

test('quantity ledger derives one plank with no leftover free raw materials', () => {
  const result = runScenarios().plankFromScraps;
  assert.equal(result.staminaSpent, 40);
  assert.equal(result.stamina, 20);
  assert.equal(result.operations, 10);
  assert.equal(result.stock['wood.board'], 1);
  assert.equal(Object.values(result.stock).reduce((a, b) => a + b, 0), 1);
  assert.equal(result.containers.length, 1);
  assert.equal(result.peakBoardCells, 10);
});

test('two soups cycle two bottles through public-tap washing and retain vessels', () => {
  const result = runScenarios().twoBasicSoups;
  assert.equal(result.supplies['water.filtered'], 4);
  assert.equal(result.supplies['fuel.dry'], 4);
  assert.equal(result.staminaSpent, 27);
  assert.equal(result.recovered, 40);
  assert.equal(result.stamina, 43);
  assert.deepEqual(result.containers.map(c => c.id), [
    'bottle-0', 'bottle-1', 'meal-0',
  ]);
  assert(result.containers.every(c => c.content === null));
  assert.equal(result.containers[0].clean, false);
  assert.equal(result.containers[1].clean, false);
  assert.equal(result.containers[2].clean, false);
  assert.equal(result.peakBoardCells, 10);
});

test('failed soup consumes its inputs but does not prevent a second successful serving', () => {
  const result = runScenarios().firstSoupFailsThenRecover;
  assert.equal(result.staminaSpent, 27);
  assert.equal(result.recovered, 24);
  assert.equal(result.stamina, 27);
  assert.equal(result.containers.length, 3);
});

test('all two-serving soup success and failure orders conserve reusable vessels', () => {
  const patterns = runScenarios().soupFailurePatterns;
  assert.deepEqual(patterns.map(pattern => pattern.failurePattern), [[], [1], [2], [1, 2]]);
  for (const { failedServings, result } of patterns) {
    assert.equal(result.staminaSpent, 27);
    assert.equal(result.supplies['water.filtered'], 4);
    assert.equal(result.supplies['fuel.dry'], 4);
    assert.equal(result.containers.length, 3);
    assert(result.containers.every(container => container.content === null));
    assert.equal(result.recovered, 40 - failedServings * 16);
    assert.equal(result.stamina, 43 - failedServings * 16);
  }
});

test('route movement cost is exposed as a sensitivity range, not a guessed canonical route', () => {
  const scenarios = runScenarios().routeCostSensitivity;
  assert.equal(scenarios.length, 10);
  assert.deepEqual(scenarios.find(s => s.staminaPerStep === 1 && s.roundTripSteps === 4), {
    staminaPerStep: 1,
    roundTripSteps: 4,
    addedStaminaCost: 4,
    twoSoupStaminaAfterRoute: 39,
    affordableFromCurrentReserve: true,
  });
  assert.equal(scenarios.find(s => s.staminaPerStep === 2 && s.roundTripSteps === 8).twoSoupStaminaAfterRoute, 27);
});

test('three-node route applies the canonical 1+2 stamina costs and packs actual pickup shapes', () => {
  const { mixed, suppliesWithoutContainers } = runScenarios().threeNodeRoute;
  assert.equal(mixed.visitedNodes, 3);
  assert.equal(mixed.staminaSpent, 9);
  assert.equal(mixed.returnCost, 0);
  assert.equal(mixed.carriedCells, 9);
  assert.equal(mixed.backpackCapacity, 16);
  assert.equal(mixed.fits, true);
  assert.equal(suppliesWithoutContainers.staminaSpent, 9);
  assert.equal(suppliesWithoutContainers.carriedCells, 9);
  assert.equal(suppliesWithoutContainers.fits, true);
});

test('route ledger refuses more nodes than the configured three-node activity', () => {
  assert.throws(() => simulateThreeNodeRoute(spec, Array(4).fill({ item: 'paper.scrap', quantity: 3 })), /Invalid route length/);
  assert.throws(() => simulateThreeNodeRoute(spec, [{ item: 'paper.scrap', quantity: 1 }]), /Invalid node yield/);
});

test('full backpack keeps the complete returned expedition reward in one-trip stash', () => {
  const result = simulateThreeNodeRoute(spec, [
    { item: 'paper.scrap', quantity: 3 },
    { item: 'cloth.rag_piece', quantity: 3 },
    { item: 'wood.chip', quantity: 3 },
  ], [{ item: 'tool.cook_kit', quantity: 2 }], 5);
  assert.equal(result.fits, false);
  assert.equal(result.claimBlocked, true);
  assert.equal(result.visitedNodes, 3);
  assert.equal(result.staminaSpent, 9);
  assert.equal(result.carriedCells, 21);
  assert.equal(result.pendingRewardCells, 9);
  assert.equal(result.returnStashCells, 9);
  assert.equal(result.canStartNextTrip, false);
});

test('public-tap bottle washing needs an empty used bottle and two stamina', () => {
  const ledger = new DesignLedger(spec, recipes, 4, 1, 0, 1);
  ledger.state.containers[0].clean = false;
  const before = structuredClone(ledger.state);
  assert.throws(() => ledger.washBottleAtPublicTap('bottle-0'), /Not enough stamina/);
  assert.deepEqual(ledger.state, before);
  ledger.state.stamina = 2;
  ledger.washBottleAtPublicTap('bottle-0');
  assert.equal(ledger.state.containers[0].clean, true);
  assert.equal(ledger.state.stamina, 0);
  assert.equal(ledger.state.staminaSpent, 2);
});

test('missing meal box rejects output and preserves the entire attempted batch', () => {
  const ledger = new DesignLedger(spec, recipes, 4, 1, 0);
  ledger.state.stock = { 'food.cleaned': 1, 'fuel.dry': 1 };
  ledger.state.containers[0].content = 'water.boiled';
  const before = structuredClone(ledger.state);
  assert.throws(() => ledger.craft('soup_basic'), /No clean empty meal/);
  assert.deepEqual(ledger.state, before);
});

test('full bottles and insufficient stamina reject supply without spending or spawning', () => {
  const ledger = new DesignLedger(spec, recipes, 4, 1);
  ledger.supply('water.filtered');
  let before = structuredClone(ledger.state);
  assert.throws(() => ledger.supply('water.filtered'), /No clean empty bottle/);
  assert.deepEqual(ledger.state, before);
  ledger.state.stamina = 0;
  before = structuredClone(ledger.state);
  assert.throws(() => ledger.supply('food.greens'), /Not enough stamina/);
  assert.deepEqual(ledger.state, before);
});

test('packing considers shape and rotation, not area alone', () => {
  assert.equal(canPack([[1, 3]], 3, 1), true);
  assert.equal(canPack([[1, 3]], 2, 2), false);
  // Same total area, but two 2x3 blocks leave only a 4x1 strip, not a 2x2 hole.
  assert.equal(canPack([[2, 3], [2, 3], [2, 2]], 4, 4), false);
  assert.equal(canPack([[2, 3], [2, 3], [1, 4]], 4, 4), true);
  assert.equal(canPack(Array.from({ length: 5 }, () => [2, 2]), 4, 4), false);
});

test('fourteen-day relief accounting retains excess claims rather than deleting them', () => {
  assert.deepEqual(reliefAfterDays(14), { visible: 7, reserve: 8, totalRecovery: 600 });
  assert.deepEqual(reliefAfterDays(0), { visible: 1, reserve: 0, totalRecovery: 40 });
});
