// Design arithmetic only. This is not the production game or its persistence engine.
import { fileURLToPath } from 'node:url';
import { loadDesign } from './audit-street-scrap-design.mjs';

export function canPack(rectangles, width, height) {
  const shapes = rectangles.map(([w, h]) => [w, h]).sort((a, b) => b[0] * b[1] - a[0] * a[1]);
  if (shapes.reduce((sum, [w, h]) => sum + w * h, 0) > width * height) return false;
  const grid = Array(width * height).fill(false);
  function fit(index) {
    if (index === shapes.length) return true;
    const [w, h] = shapes[index];
    for (const [rw, rh] of w === h ? [[w, h]] : [[w, h], [h, w]]) {
      for (let y = 0; y <= height - rh; y++) for (let x = 0; x <= width - rw; x++) {
        const cells = [];
        for (let dy = 0; dy < rh; dy++) for (let dx = 0; dx < rw; dx++) cells.push((y + dy) * width + x + dx);
        if (cells.some(cell => grid[cell])) continue;
        cells.forEach(cell => { grid[cell] = true; });
        if (fit(index + 1)) return true;
        cells.forEach(cell => { grid[cell] = false; });
      }
    }
    return false;
  }
  return fit(0);
}

export class DesignLedger {
  constructor(spec, recipes, phase, bottles = 0, mealBoxes = 0, initialStamina = 60) {
    this.spec = spec;
    this.recipes = recipes;
    this.phase = phase;
    this.state = { stock: {}, containers: [], stamina: initialStamina, staminaSpent: 0, recovered: 0, operations: 0, supplies: {}, peakBoardCells: 0 };
    for (let i = 0; i < bottles; i++) this.state.containers.push({ id: `bottle-${i}`, kind: 'bottle', clean: true, content: null });
    for (let i = 0; i < mealBoxes; i++) this.state.containers.push({ id: `meal-${i}`, kind: 'meal', clean: true, content: null });
    this.check(this.state);
  }
  check(state) {
    const shapes = state.containers.map(() => [1, 2]);
    for (const [id, count] of Object.entries(state.stock)) {
      const item = this.spec.items.find(item => item.id === id);
      if (!item || item.location !== 'grid' || count < 0) throw Error(`Unsupported stock ${id}`);
      for (let i = 0; i < count; i++) shapes.push(item.footprint);
    }
    if (!canPack(shapes, ...this.spec.limits.board)) throw Error('Board cannot fit all outputs');
    state.peakBoardCells = Math.max(state.peakBoardCells, shapes.reduce((sum, [w, h]) => sum + w * h, 0));
  }
  transact(action) {
    const candidate = structuredClone(this.state);
    action(candidate);
    this.check(candidate);
    this.state = candidate;
  }
  add(state, id, quantity) {
    for (let i = 0; i < quantity; i++) {
      if (id.startsWith('water.') || id.startsWith('meal.')) {
        const kind = id.startsWith('water.') ? 'bottle' : 'meal';
        const target = state.containers.find(c => c.kind === kind && c.clean && !c.content);
        if (!target) throw Error(`No clean empty ${kind}`);
        target.content = id;
      } else state.stock[id] = (state.stock[id] ?? 0) + 1;
    }
  }
  consume(state, id, quantity) {
    for (let i = 0; i < quantity; i++) {
      if (id.startsWith('water.')) {
        const source = state.containers.find(c => c.content === id);
        if (!source) throw Error(`Missing ${id}`);
        source.content = null;
        source.clean = false;
      } else {
        if (!(state.stock[id] > 0)) throw Error(`Missing ${id}`);
        state.stock[id]--;
      }
    }
  }
  supply(id) {
    const source = this.spec.supplies.find(s => s.item === id && s.phase <= this.phase);
    if (!source) throw Error(`No unlocked supply ${id}`);
    const item = this.spec.items.find(item => item.id === id);
    const pickup = item.location === 'content' ? [[1, 2]] : Array.from({ length: source.quantity }, () => item.footprint);
    if (!canPack(pickup, ...this.spec.limits.startingBackpack)) throw Error('Supply batch cannot fit backpack');
    this.transact(state => {
      if (state.stamina < source.stamina) throw Error('Not enough stamina');
      this.add(state, id, source.quantity);
      state.stamina -= source.stamina;
      state.staminaSpent += source.stamina;
      state.supplies[id] = (state.supplies[id] ?? 0) + 1;
    });
  }
  craft(suffix, group = 0, failSoup = false) {
    const recipe = this.recipes.find(r => r.id === `ss.recipe.${suffix}`);
    if (!recipe || recipe.phase > this.phase) throw Error('Recipe is locked');
    // Deliberately refuse recipe features not represented by these targeted scenarios.
    if (recipe.tools.length || !recipe.inputGroups[group] || (!recipe.outputs.length && !this.spec.recipePolicies.find(policy => policy.id === recipe.id)?.stateEffect)) throw Error('Scenario model does not support tools or state-only recipe');
    if (failSoup && suffix !== 'soup_basic') throw Error('Only the specified soup-failure branch is modeled');
    this.transact(state => {
      const effect = this.spec.recipePolicies.find(policy => policy.id === recipe.id)?.stateEffect;
      const vesselChanges = effect?.type === 'transformContainers'
        ? effect.containers
        : effect?.type === 'transformContainerContent'
        ? [{
            containerItemId: effect.containerItemId,
            requiredContentItemId: effect.fromContentItemId,
            successContentItemId: effect.toContentItemId,
            failureContentItemId: effect.fromContentItemId,
            successCleanliness: effect.successCleanliness,
            failureCleanliness: effect.failureCleanliness,
          }]
        : [];
      const selectedItems = new Set(recipe.inputGroups[group].map(input => input.item));
      const selectedVesselChanges = vesselChanges.filter(change =>
        selectedItems.has(change.containerItemId) || change.optional !== true,
      );
      const vesselUpdates = selectedVesselChanges.map(change => {
        const kind = change.containerItemId.startsWith('container.meal_box') ? 'meal' : 'bottle';
        const vessel = state.containers.find(container => container.kind === kind &&
          (container.content ?? null) === (change.requiredContentItemId ?? null) &&
          (kind !== 'meal' || container.clean));
        if (!vessel) throw Error(kind === 'meal' ? 'No clean empty meal box' : `Missing vessel content ${change.requiredContentItemId}`);
        return { vessel, change };
      });
      const retainedKinds = new Set(vesselUpdates.map(({ change }) => change.containerItemId));
      for (const input of recipe.inputGroups[group]) {
        if (retainedKinds.has(input.item)) continue;
        this.consume(state, input.item, input.quantity);
      }
      if (vesselUpdates.length) {
        for (const { vessel, change } of vesselUpdates) {
          vessel.content = (failSoup ? change.failureContentItemId : change.successContentItemId) ?? null;
          const cleanliness = failSoup ? change.failureCleanliness : change.successCleanliness;
          if (cleanliness != null) vessel.clean = cleanliness === 'clean';
        }
      }
      if (recipe.outputs.length) {
        recipe.outputs.forEach(output => this.add(state, output.item, output.quantity));
      } else if (!vesselUpdates.length && failSoup) {
        this.add(state, 'meal.failed', 1);
      }
      state.operations++;
    });
  }
  eat(baseRecovery) {
    this.transact(state => {
      const target = state.containers.find(c => c.kind === 'meal' && c.content);
      if (!target) throw Error('No meal');
      target.content = null;
      target.clean = false;
      const restored = Math.min(baseRecovery, this.spec.limits.staminaMax - state.stamina);
      state.recovered += restored;
      state.stamina += restored;
    });
  }
  washBox() {
    this.transact(state => {
      const box = state.containers.find(c => c.kind === 'meal' && !c.content && !c.clean);
      if (!box) throw Error('No dirty empty meal box');
      this.consume(state, 'water.filtered', 1);
      box.clean = true;
    });
  }
  washBottleAtPublicTap(id) {
    this.transact(state => {
      const bottle = state.containers.find(container => container.id === id);
      if (!bottle || bottle.kind !== 'bottle' || bottle.content || bottle.clean) {
        throw Error('Bottle is not an empty used vessel');
      }
      if (state.stamina < 2) throw Error('Not enough stamina');
      state.stamina -= 2;
      state.staminaSpent += 2;
      bottle.clean = true;
    });
  }
}

export function reliefAfterDays(days, initial = 1) {
  const total = initial + Math.floor(days);
  return { visible: Math.min(7, total), reserve: Math.max(0, total - 7), totalRecovery: total * 40 };
}

export function simulateThreeNodeRoute(spec, picks, initialCarry = [], phase = 0) {
  const rules = spec.scavenging;
  if (!Array.isArray(picks) || picks.length > rules.nodeCount) throw Error('Invalid route length');
  const shapes = [];
  const append = (itemId, quantity) => {
    const item = spec.items.find(candidate => candidate.id === itemId);
    if (!item || item.phase > phase || item.location !== 'grid' || !Number.isInteger(quantity) || quantity < 1) {
      throw Error(`Invalid route item ${itemId}`);
    }
    for (let index = 0; index < quantity; index++) shapes.push(item.footprint);
  };
  initialCarry.forEach(({ item, quantity }) => append(item, quantity));
  const startingCells = shapes.reduce((sum, [width, height]) => sum + width * height, 0);
  const nodeResults = [];
  for (let index = 0; index < picks.length; index++) {
    const { item, quantity } = picks[index];
    const supply = spec.supplies.find(source => source.item === item && source.phase <= phase);
    const surprise = Object.values(rules.surprisePools).some(pool => pool.includes(item));
    if (rules.investigationsPerNode === 1 &&
        (supply ? quantity !== supply.quantity : !surprise || quantity !== 1)) {
      throw Error(`Invalid node yield ${item}`);
    }
    append(item, quantity);
    nodeResults.push({ node: index + 1, item, quantity });
  }
  const [width, height] = spec.limits.startingBackpack;
  const fits = canPack(shapes, width, height);
  const totalCells = shapes.reduce((sum, [w, h]) => sum + w * h, 0);
  const pickupCells = totalCells - startingCells;
  // Exploration rewards remain in the expedition snapshot until the atomic
  // return claim. A full backpack blocks claiming, not searching or returning;
  // the whole reward batch stays in the one-trip return stash.
  return {
    nodeResults,
    visitedNodes: picks.length,
    staminaSpent: picks.length * rules.movementCost + picks.length * rules.investigationCost,
    returnCost: 0,
    startingCells,
    carriedCells: totalCells,
    pendingRewardCells: pickupCells,
    backpackCapacity: width * height,
    fits,
    claimBlocked: !fits,
    returnStashCells: fits ? 0 : pickupCells,
    canStartNextTrip: fits,
  };
}

export function runScenarios() {
  const { spec, recipes } = loadDesign();
  const wood = new DesignLedger(spec, recipes, 3, 1);
  for (let i = 0; i < 3; i++) {
    wood.supply('paper.scrap');
    if (i > 0) wood.washBottleAtPublicTap('bottle-0');
    wood.supply('water.filtered'); wood.craft('mix_pulp', 1);
    wood.supply('adhesive.residue'); wood.craft('recycle_glue');
    wood.supply('wood.chip'); wood.craft('press_rod');
  }
  wood.supply('metal.nail_bundle'); wood.craft('nail_board');
  function soup(failures = []) {
    const ledger = new DesignLedger(spec, recipes, 4, 2, 1, 30);
    ledger.supply('food.greens'); ledger.supply('water.filtered'); ledger.craft('clean_food');
    for (let i = 0; i < 2; i++) {
      ledger.supply('fuel.dry'); ledger.supply('fuel.dry');
      if (i > 0) ledger.washBottleAtPublicTap('bottle-1');
      ledger.supply('water.filtered'); ledger.craft('boil_water');
      const failed = failures.includes(i);
      ledger.craft('soup_basic', 0, failed); ledger.eat(failed ? 4 : 20);
      if (i === 0) {
        ledger.washBottleAtPublicTap('bottle-0');
        ledger.supply('water.filtered'); ledger.washBox();
      }
    }
    return ledger.state;
  }
  return {
    scope: 'Targeted design ledger: selected production recipes and all two-serving soup outcomes, reusable vessels, public-tap washing, two 3-node route shapes at canonical stamina costs, and route movement-cost sensitivity. Starting containers supplied; no tools, qualities, timers, chapter-wide logistics, event probabilities or actual game runtime.',
    plankFromScraps: wood.state,
    twoBasicSoups: soup(),
    firstSoupFailsThenRecover: soup([0]),
    soupFailurePatterns: [[], [0], [1], [0, 1]].map(failures => ({
      failedServings: failures.length,
      failurePattern: failures.map(index => index + 1),
      result: soup(failures),
    })),
    // The design fixes the rule (one cost per move or interaction), but map
    // geometry and numeric move costs are still tuning inputs. Show sensitivity
    // instead of silently treating an unapproved route length as canonical.
    routeCostSensitivity: [1, 2].flatMap(staminaPerStep =>
      [0, 2, 4, 6, 8].map(roundTripSteps => ({
        staminaPerStep,
        roundTripSteps,
        addedStaminaCost: staminaPerStep * roundTripSteps,
        twoSoupStaminaAfterRoute: Math.max(0, soup().stamina - staminaPerStep * roundTripSteps),
        affordableFromCurrentReserve: soup().stamina >= staminaPerStep * roundTripSteps,
      })),
    ),
    threeNodeRoute: {
      mixed: simulateThreeNodeRoute(spec, [
        { item: 'cloth.rag_piece', quantity: 3 },
        { item: 'wood.driftwood', quantity: 2 },
        { item: 'container.used_intact', quantity: 1 },
      ]),
    suppliesWithoutContainers: simulateThreeNodeRoute(spec, [
        { item: 'paper.scrap', quantity: 3 },
        { item: 'metal.scrap', quantity: 3 },
        { item: 'plastic.scrap', quantity: 3 },
    ], [], 1),
    },
    returningAfter14Days: { ...reliefAfterDays(14), stamina: spec.limits.staminaMax },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) console.log(JSON.stringify(runScenarios(), null, 2));
