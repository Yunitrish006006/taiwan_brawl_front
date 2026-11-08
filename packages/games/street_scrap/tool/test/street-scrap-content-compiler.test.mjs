import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { compileContent, splitContent, mergeContentSlices, validateCompiledContent } from '../compile-street-scrap-content.mjs';
import { loadDesign } from '../audit-street-scrap-design.mjs';

test('formal content snapshot carries versioned items, operations, failure outcomes, and packing rules', () => {
  const result = compileContent(loadDesign());
  assert.deepEqual(validateCompiledContent(result), { status: 'PASS', counts: { items: 111, recipes: 78, packingRules: 8 }, errors: [] });
  assert.deepEqual(
    Object.fromEntries(result.itemDefinitions
      .filter(item => item.baseDurability !== undefined)
      .map(item => [item.id, item.baseDurability])),
    {
      'tool.awl': 20,
      'tool.crowbar': 30,
      'tool.pliers': 30,
      'tool.rod_basic': 20,
      'tool.rod_repaired': 30,
      'tool.rod_advanced': 40,
    },
  );
  const float = result.recipes.find(recipe => recipe.id === 'ss.recipe.float');
  assert.equal(float.stateEffect.type, 'packObjects');
  assert.deepEqual(float.identity.retainedInputIds, ['container.clean']);
  assert.deepEqual(result.packing.find(rule => rule.output === 'toolpart.float'), {
    input: 'container.clean', output: 'toolpart.float', count: 1, manualUnpack: true,
  });
  const cookKit = result.recipes.find(recipe => recipe.id === 'ss.recipe.cook_kit');
  assert.equal(cookKit.stateEffect.type, 'packObjects');
  assert.deepEqual(cookKit.identity.retainedInputIds, ['tool.pot', 'tool.stove']);
  assert.deepEqual(result.packing.find(rule => rule.output === 'tool.cook_kit'), {
    input: 'tool.pot', inputItems: ['tool.pot', 'tool.stove'],
    output: 'tool.cook_kit', count: 2, manualUnpack: true,
  });
  const malformedPack = structuredClone(result);
  malformedPack.packing.find(rule => rule.output === 'tool.cook_kit').inputItems = [
    'tool.pot', 'tool.pot',
  ];
  assert.ok(validateCompiledContent(malformedPack).errors.includes('invalidStateEffect:ss.recipe.cook_kit'));
  for (const recipe of result.recipes) {
    assert.ok(recipe.failure.outcome.trim(), recipe.id);
    assert.ok(recipe.operation.instructions.trim(), recipe.id);
    assert.ok(recipe.operation.id, recipe.id);
  }
  assert.equal(result.optionalResource, true);
  assert.equal(result.gameId, 'game.street-scrap');
  assert.equal(result.packVersion, '0.1.61');
  const manualCheckpoints = result.recipes.flatMap(recipe =>
    recipe.operation.manualCheckpoints.map(checkpoint => ({ recipeId: recipe.id, ...checkpoint })));
  const answerPositionCounts = [0, 0, 0];
  for (const checkpoint of manualCheckpoints) answerPositionCounts[checkpoint.correctOption]++;
  assert.equal(manualCheckpoints.length, 159);
  const paperboard = result.recipes.find(recipe => recipe.id === 'ss.recipe.form_paperboard');
  assert.equal(paperboard.reusableTools.length, 0);
  assert.equal(paperboard.operation.manualCheckpoints.length, 3);
  assert.deepEqual(paperboard.failureResolution, {
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
    consumeSelectedInputs: true,
  });
  const idealAnswersPerPosition = manualCheckpoints.length / answerPositionCounts.length;
  assert.ok(answerPositionCounts.every(count =>
    Math.abs(count - idealAnswersPerPosition) <= 5),
    `correct answer positions should be balanced, got ${answerPositionCounts.join('/')}`);
  assert.deepEqual(
    result.recipes.map(recipe => recipe.operation.manualCheckpoints),
    compileContent(loadDesign()).recipes.map(recipe => recipe.operation.manualCheckpoints),
    'answer positions must remain stable across builds and retries',
  );
  assert.equal(result.scavenging.version, 4);
  assert.equal(result.scavenging.phaseSurprisePools['0'].commonScraps.includes('metal.scrap'), false);
  assert.equal(result.scavenging.phaseSurprisePools['1'].commonScraps.includes('metal.scrap'), true);
  assert.equal(result.scavenging.phaseSurprisePools['2'].optionalSpecial.includes('material.waterproof_coating'), false);
  assert.equal(result.scavenging.phaseSurprisePools['3'].optionalSpecial.includes('material.waterproof_coating'), true);
  assert.equal(result.scavenging.phaseSurprisePools['5'].optionalSpecial.includes('material.mineral_pack'), true);
  assert.equal(result.scavenging.phaseSurprisePools['5'].optionalSpecial.includes('water.mineral'), true);
  assert.ok(result.scavenging.surpriseTraitPools.negative.some(rule => rule.id === 'rusted' && rule.prefix === 'metal.'));
  assert.ok(result.scavenging.surpriseTraitPools.negative.some(rule => rule.id === 'brittle' && rule.prefix === 'plastic.'));
  const sewing = result.recipes.find(recipe => recipe.id === 'ss.recipe.sew_strip');
  const fillet = result.recipes.find(recipe => recipe.id === 'ss.recipe.fillet_fish');
  const mixPulp = result.recipes.find(recipe => recipe.id === 'ss.recipe.mix_pulp');
  assert.deepEqual(mixPulp.traitResolution.precise, { even_pulp: true });
  assert.deepEqual(mixPulp.qualityTraitEffects, [
    { inputItemId: 'paper.scrap', traitId: 'damp', polarity: 'negative', modifier: -3 },
    { inputItemId: 'water.filtered', traitId: 'clear', polarity: 'positive', modifier: 3 },
  ]);
  const filterTurbid = result.recipes.find(recipe => recipe.id === 'ss.recipe.filter_turbid');
  assert.deepEqual(
    filterTurbid.stateEffect.containers[0].contentTraitResolution,
    { precise: { clear: true } },
  );
  const formPaperboard = result.recipes.find(recipe => recipe.id === 'ss.recipe.form_paperboard');
  assert.deepEqual(formPaperboard.traitResolution.precise, { even_pulp: true });
  assert.ok(formPaperboard.qualityTraitEffects.some(effect =>
    effect.traitId === 'even_pulp' && effect.inputItemId === 'paper.pulp' && effect.modifier === 3));
  const sealPackaging = result.recipes.find(recipe => recipe.id === 'ss.recipe.seal_packaging');
  assert.ok(sealPackaging.qualityTraitEffects.some(effect =>
    effect.traitId === 'even_pulp' && effect.inputItemId === 'paper.board' && effect.modifier === 3));
  const fishFillet = result.recipes.find(recipe => recipe.id === 'ss.recipe.fillet_fish');
  assert.deepEqual(fishFillet.traitResolution.precise, { rich_ingredient: true });
  assert.deepEqual(fishFillet.traitResolution.failure, { rough_cut: true });
  const cleanFood = result.recipes.find(recipe => recipe.id === 'ss.recipe.clean_food');
  assert.equal(cleanFood.operation.manualCheckpoints.length, 3);
  assert.deepEqual(cleanFood.quality.primaryInputs, ['food.greens', 'food.edible']);
  assert.deepEqual(cleanFood.traitResolution.precise, { rich_ingredient: true });
  assert.deepEqual(cleanFood.traitResolution.failure, { rough_cut: true });
  assert.deepEqual(cleanFood.failureOutputs, [
    { item: 'food.cleaned', quantity: 1 },
    { item: 'food.scrap', quantity: 1 },
  ]);
  const fishSoup = result.recipes.find(recipe => recipe.id === 'ss.recipe.soup_fish');
  assert.deepEqual(fishSoup.qualityTraitEffects, [
    { inputItemId: 'fish.meat', traitId: 'rich_ingredient', polarity: 'positive', modifier: 3 },
    { inputItemId: 'fish.meat', traitId: 'rough_cut', polarity: 'negative', modifier: -3 },
    { inputItemId: 'container.clean', traitId: 'mineral_rich', polarity: 'positive', modifier: 3 },
    { inputItemId: 'fuel.dry', traitId: 'smoky', polarity: 'negative', modifier: -3 },
  ]);
  const sharedMeal = result.recipes.find(recipe => recipe.id === 'ss.recipe.shared_meal');
  assert.deepEqual(sharedMeal.qualityTraitEffects, [
    { inputItemId: 'food.cleaned', traitId: 'rich_ingredient', polarity: 'positive', modifier: 3 },
    { inputItemId: 'food.cleaned', traitId: 'rough_cut', polarity: 'negative', modifier: -3 },
    { inputItemId: 'fish.meat', traitId: 'rich_ingredient', polarity: 'positive', modifier: 3 },
    { inputItemId: 'fish.meat', traitId: 'rough_cut', polarity: 'negative', modifier: -3 },
    { inputItemId: 'fuel.dry', traitId: 'smoky', polarity: 'negative', modifier: -3 },
  ]);
  for (const soupId of ['ss.recipe.soup_basic', 'ss.recipe.soup_vegetable', 'ss.recipe.soup_fish']) {
    const soup = result.recipes.find(recipe => recipe.id === soupId);
    assert.ok(soup.qualityTraitEffects.some(effect =>
      effect.traitId === 'mineral_rich' && effect.polarity === 'positive' && effect.modifier === 3));
  }
  for (const recipeId of ['ss.recipe.soup_basic', 'ss.recipe.soup_vegetable', 'ss.recipe.shared_meal']) {
    const recipe = result.recipes.find(entry => entry.id === recipeId);
    assert.ok(recipe.qualityTraitEffects.some(effect =>
      effect.inputItemId === 'food.cleaned' && effect.traitId === 'rich_ingredient' && effect.modifier === 3));
    assert.ok(recipe.qualityTraitEffects.some(effect =>
      effect.inputItemId === 'food.cleaned' && effect.traitId === 'rough_cut' && effect.modifier === -3));
  }
  const dryFuel = result.recipes.find(recipe => recipe.id === 'ss.recipe.dry_fuel');
  assert.deepEqual(dryFuel.traitResolution.precise, { even_burn: true });
  assert.deepEqual(dryFuel.traitResolution.failure, { smoky: true });
  assert.deepEqual(dryFuel.failureOutputs, [
    { item: 'fuel.dry', quantity: 1 },
    { item: 'fuel.mixed', quantity: 1 },
  ]);
  assert.ok(dryFuel.qualityTraitEffects.some(effect =>
    effect.traitId === 'smoky' && effect.inputItemId === 'fuel.mixed' && effect.modifier === -3));
  const shapeBar = result.recipes.find(recipe => recipe.id === 'ss.recipe.shape_bar');
  const compactMetal = result.recipes.find(recipe => recipe.id === 'ss.recipe.compact_metal');
  assert.deepEqual(shapeBar.traitResolution.precise, { smooth_metal: true });
  assert.deepEqual(shapeBar.traitResolution.inherit, [
    { inputItemId: 'metal.sheet', map: { rusted: 'rusted' } },
  ]);
  assert.deepEqual(compactMetal.traitResolution.precise, { smooth_metal: true });
  const crowbar = result.recipes.find(recipe => recipe.id === 'ss.recipe.crowbar');
  assert.deepEqual(crowbar.qualityTraitEffects.filter(effect => effect.inputItemId === 'metal.sheet'), [
    { inputItemId: 'metal.sheet', traitId: 'smooth_metal', polarity: 'positive', modifier: 3 },
    { inputItemId: 'metal.sheet', traitId: 'rusted', polarity: 'negative', modifier: -3 },
  ]);
  const pressPlastic = result.recipes.find(recipe => recipe.id === 'ss.recipe.press_plastic');
  assert.deepEqual(pressPlastic.traitResolution.precise, { sealed: true });
  assert.deepEqual(pressPlastic.traitResolution.failure, { brittle: true });
  const sealPart = result.recipes.find(recipe => recipe.id === 'ss.recipe.seal_part');
  assert.deepEqual(sealPart.traitResolution.precise, { sealed: true });
  assert.deepEqual(sealPart.qualityTraitEffects, [
    { inputItemId: 'plastic.sheet', traitId: 'sealed', polarity: 'positive', modifier: 3 },
    { inputItemId: 'plastic.sheet', traitId: 'brittle', polarity: 'negative', modifier: -3 },
  ]);
  const tarp = result.recipes.find(recipe => recipe.id === 'ss.recipe.tarp');
  const weatherBag = result.recipes.find(recipe => recipe.id === 'ss.recipe.weather_bag');
  assert.ok(tarp.qualityTraitEffects.some(effect => effect.traitId === 'sealed' && effect.modifier === 3));
  assert.ok(weatherBag.qualityTraitEffects.some(effect => effect.traitId === 'sealed' && effect.modifier === 3));
  const mixFuel = result.recipes.find(recipe => recipe.id === 'ss.recipe.mix_fuel');
  const sawdustFuel = result.recipes.find(recipe => recipe.id === 'ss.recipe.sawdust_fuel');
  assert.deepEqual(mixFuel.traitResolution.failure, { smoky: true });
  assert.deepEqual(sawdustFuel.traitResolution.failure, { smoky: true });
  const boilWater = result.recipes.find(recipe => recipe.id === 'ss.recipe.boil_water');
  assert.ok(boilWater.qualityTraitEffects.some(effect =>
    effect.traitId === 'smoky' && effect.inputItemId === 'fuel.dry' && effect.modifier === -3));
  assert.deepEqual(sewing.failureResolution, {
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
    consumeSelectedInputs: true,
  });
  const genericFailures = result.recipes.filter(recipe =>
    recipe.failure.mode === 'reducedQualityOutput' &&
    recipe.identity.retainedInputIds.length === 0);
  assert.equal(genericFailures.filter(recipe => recipe.failureResolution).length, 29);
  for (const recipe of genericFailures.filter(recipe => recipe.failureResolution)) {
    assert.deepEqual(recipe.failureResolution, {
      mode: 'sameOutputsQualityLoss',
      qualityLoss: recipe.id === 'ss.recipe.clean_food' ? 0 : 10,
      consumeSelectedInputs: true,
    }, recipe.id);
    assert.deepEqual(recipe.identity.retainedInputIds, [], recipe.id);
    assert.notEqual(recipe.quality.mode, 'preserve-primary', recipe.id);
  }
  const manualRecipes = result.recipes.filter(recipe => recipe.failureResolution &&
    recipe.identity.retainedInputIds.length === 0 &&
    (recipe.outputs.length > 0 || recipe.stateEffect !== undefined) &&
    recipe.quality.mode !== 'preserve-primary');
  assert.equal(manualRecipes.length, 51);
  assert.ok(manualRecipes.every(recipe => recipe.operation.manualCheckpoints.length === 3));
  for (const id of [
    'ss.recipe.patch_cloth',
    'ss.recipe.braid_binding',
    'ss.recipe.braid_rope',
    'ss.recipe.mix_pulp',
    'ss.recipe.recycle_glue',
  ]) {
    const recipe = result.recipes.find(candidate => candidate.id === id);
    assert.deepEqual(recipe.failureResolution, {
      mode: 'sameOutputsQualityLoss',
      qualityLoss: 10,
      consumeSelectedInputs: true,
    }, id);
    assert.equal(recipe.operation.manualCheckpoints.length, 3, id);
  }
  assert.ok(result.recipes.filter(recipe => !recipe.failureResolution)
    .every(recipe => recipe.operation.manualCheckpoints.length === 0));
  assert.ok(genericFailures.filter(recipe => !recipe.failureResolution)
    .every(recipe => recipe.identity.retainedInputIds.length > 0 || recipe.quality.mode === 'preserve-primary'));
  assert.equal(sewing.operation.manualCheckpoints.length, 3);
  assert.equal(fillet.operation.manualCheckpoints.length, 3);
  const pressRod = result.recipes.find(recipe => recipe.id === 'ss.recipe.press_rod');
  assert.equal(pressRod.operation.manualCheckpoints.length, 3);
  assert.deepEqual(pressRod.traitResolution.inherit, [
    { inputItemId: 'wood.chip', map: { cracked: 'cracked' } },
  ]);
  assert.deepEqual(pressRod.failureResolution, {
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
    consumeSelectedInputs: true,
  });
  for (const [recipeId, inputItemId] of [
    ['ss.recipe.tool_handle', 'wood.rod'],
    ['ss.recipe.crowbar', 'toolpart.handle'],
    ['ss.recipe.basic_rod', 'wood.rod'],
    ['ss.recipe.awl_bone', 'wood.rod'],
  ]) {
    const recipe = result.recipes.find(entry => entry.id === recipeId);
    assert.ok(recipe.traitResolution.inherit.some(rule =>
      rule.inputItemId === inputItemId && rule.map.cracked === 'cracked'), recipeId);
  }
  const nailedBoard = result.recipes.find(recipe => recipe.id === 'ss.recipe.nail_board');
  assert.equal(nailedBoard.operation.manualCheckpoints.length, 3);
  assert.deepEqual(nailedBoard.failureResolution, {
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
    consumeSelectedInputs: true,
  });
  assert.deepEqual(nailedBoard.traitResolution, {
    inherit: [],
    polarity: {
      joint_reinforced: 'positive',
      joint_skewed: 'negative',
    },
    success: {},
    precise: { joint_reinforced: true },
    failure: { joint_skewed: true },
  });
  const sewingRecipe = result.recipes.find(recipe => recipe.id === 'ss.recipe.sew_strip');
  assert.deepEqual(sewingRecipe.qualityTraitEffects, [
    {
      inputItemId: 'cloth.rag_piece',
      traitId: 'intact_fibre',
      polarity: 'positive',
      modifier: 3,
    },
    {
      inputItemId: 'cloth.rag_piece',
      traitId: 'frayed',
      polarity: 'negative',
      modifier: -3,
    },
    {
      inputItemId: 'cloth.thread_spool',
      traitId: 'intact_fibre',
      polarity: 'positive',
      modifier: 3,
    },
    {
      inputItemId: 'cloth.thread_spool',
      traitId: 'frayed',
      polarity: 'negative',
      modifier: -3,
    },
  ]);
  const overstackedTraits = structuredClone(result);
  const overstackedRecipe = overstackedTraits.recipes.find(recipe => recipe.id === 'ss.recipe.nail_board');
  overstackedRecipe.traitResolution.polarity.joint_weathered = 'positive';
  overstackedRecipe.traitResolution.precise.joint_weathered = true;
  assert.ok(validateCompiledContent(overstackedTraits).errors.includes(
    'traitPolarityLimitExceeded:ss.recipe.nail_board:precise',
  ));
  const frameAssembly = result.recipes.find(recipe => recipe.id === 'ss.recipe.assemble_frame');
  assert.deepEqual(frameAssembly.traitResolution.inherit, [{
    inputItemId: 'wood.board',
    map: {
      joint_reinforced: 'joint_reinforced',
      joint_skewed: 'joint_skewed',
    },
  }]);
  const shelter = result.recipes.find(recipe => recipe.id === 'ss.recipe.shelter');
  assert.deepEqual(tarp.traitResolution.inherit, [{
    inputItemId: 'wood.frame',
    map: { joint_reinforced: 'joint_reinforced' },
  }]);
  assert.ok(shelter.traitResolution.inherit.some(rule =>
    rule.inputItemId === 'wood.frame' && rule.map.joint_reinforced === 'joint_reinforced'));
  assert.ok(shelter.traitResolution.inherit.some(rule =>
    rule.inputItemId === 'structure.tarp' && rule.map.joint_reinforced === 'joint_reinforced'));
  for (const [id, fromItemId, toItemId, clearContainerState] of [
    ['ss.recipe.upgrade_rod', 'tool.rod_basic', 'tool.rod_repaired', false],
    ['ss.recipe.pot', 'container.clean_jar', 'tool.pot', true],
  ]) {
    const transformation = result.recipes.find(recipe => recipe.id === id);
    assert.deepEqual(transformation.identity.retainedInputIds, [fromItemId]);
    assert.deepEqual(transformation.stateEffect, {
      type: 'transformObject',
      fromItemId,
      toItemId,
      requireEmptyContainer: true,
      ...(clearContainerState ? { clearContainerState: true } : {}),
    });
  }
  const washableBottle = result.recipes.find(recipe => recipe.id === 'ss.recipe.wash_container');
  assert.deepEqual(washableBottle.outputs, []);
  assert.deepEqual(washableBottle.stateEffect, {
    type: 'transformObject',
    fromItemId: 'container.used_intact',
    toItemId: 'container.clean',
    requireEmptyContainer: true,
    applyOnFailure: false,
    targetContainerState: { cleanliness: 'clean' },
  });
  assert.deepEqual(washableBottle.failureResolution, {
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 0,
    consumeSelectedInputs: true,
  });
  const woodenCrate = result.recipes.find(recipe => recipe.id === 'ss.recipe.wooden_crate');
  assert.equal(woodenCrate.operation.manualCheckpoints.length, 3);
  assert.deepEqual(woodenCrate.failureResolution, {
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
    consumeSelectedInputs: true,
  });
  const turbidFilter = result.recipes.find(recipe => recipe.id === 'ss.recipe.filter_turbid');
  assert.equal(turbidFilter.operation.manualCheckpoints.length, 3);
  assert.equal(turbidFilter.outputs.length, 0);
  assert.equal(turbidFilter.stateEffect.type, 'transformContainers');
  assert.deepEqual(turbidFilter.stateEffect.containers[0].contentTraitResolution, {
    precise: { clear: true },
  });
  const dirtyFilter = result.recipes.find(recipe => recipe.id === 'ss.recipe.filter_dirty');
  assert.equal(dirtyFilter.operation.manualCheckpoints.length, 3);
  assert.equal(dirtyFilter.outputs.length, 0);
  assert.deepEqual(dirtyFilter.inputGroups[0].map(input => input.item), ['container.clean', 'material.charcoal']);
  assert.deepEqual(dirtyFilter.stateEffect.containers[0], {
    containerItemId: 'container.clean',
    requiredContentItemId: 'water.dirty',
    successContentItemId: 'water.filtered',
    failureContentItemId: 'water.dirty',
    successCleanliness: 'utility',
    failureCleanliness: 'utility',
    successRequiresBoiling: true,
    failureRequiresBoiling: false,
    preserveContainerContentSource: true,
    preserveContainerContentTraits: true,
    contentTraitResolution: { precise: { clear: true } },
  });
  const basicSoup = result.recipes.find(recipe => recipe.id === 'ss.recipe.soup_basic');
  assert.equal(basicSoup.operation.manualCheckpoints.length, 3);
  assert.equal(basicSoup.stateEffect.type, 'transformContainers');
  assert.equal(basicSoup.stateEffect.containers.length, 3);
  assert.equal(basicSoup.inputGroups.length, 2);
  assert.equal(
    basicSoup.inputGroups[1].find(
      input => input.item === 'container.meal_box_insulated',
    ).quantity,
    1,
  );
  for (const [id, primary, meal] of [
    ['ss.recipe.soup_vegetable', 'food.cleaned', 'meal.soup_vegetable'],
    ['ss.recipe.soup_fish', 'fish.meat', 'meal.soup_fish'],
  ]) {
    const soup = result.recipes.find(recipe => recipe.id === id);
    assert.equal(soup.outputs.length, 0);
    assert.deepEqual(soup.inputGroups[0].map(input => [input.item, input.quantity]), [
      [primary, 2], ['container.clean', 1], ['fuel.dry', 1], ['container.meal_box', 1],
    ]);
    assert.equal(soup.stateEffect.type, 'transformContainers');
    assert.equal(soup.stateEffect.containers.length, 3);
    assert.equal(soup.inputGroups.length, 2);
    assert.equal(soup.stateEffect.containers[0].requiredContentItemId, 'water.boiled');
    assert.equal(soup.stateEffect.containers[0].successContentItemId, null);
    assert.equal(soup.stateEffect.containers[1].successContentItemId, meal);
    assert.equal(soup.stateEffect.containers[1].failureContentItemId, 'meal.failed');
    assert.equal(soup.operation.manualCheckpoints.length, 3);
    assert.equal(soup.failureResolution.consumeSelectedInputs, true);
  }
  const insulatedBox = result.recipes.find(recipe => recipe.id === 'ss.recipe.insulated_box');
  assert.equal(insulatedBox.outputs.length, 0);
  assert.deepEqual(insulatedBox.stateEffect, {
    type: 'transformObject',
    fromItemId: 'container.meal_box',
    toItemId: 'container.meal_box_insulated',
    requireEmptyContainer: true,
  });
  assert.deepEqual(insulatedBox.identity.retainedInputIds, ['container.meal_box']);
  assert.equal(insulatedBox.operation.manualCheckpoints.length, 3);
  assert.equal(insulatedBox.failureResolution.qualityLoss, 10);
  assert.deepEqual(fillet.failureOutputs, [
    { item: 'fish.meat', quantity: 1 },
    { item: 'fish.bone', quantity: 1 },
    { item: 'food.scrap', quantity: 1 },
  ]);
  assert.equal(result.packVersion, '0.1.61');
  assert.equal(result.scavenging.nodeCount, 3);
  assert.equal(result.scavenging.version, 4);
  assert.equal(result.scavenging.surpriseTraitPools.chancePercent, 20);
  assert.deepEqual(result.scavenging.surpriseTraitPools.positive, [
    { prefix: 'cloth.', id: 'intact_fibre', minimumQuality: 70 },
  ]);
  assert.equal(result.scavenging.investigationsPerNode, 1);
  assert.equal(result.fishing.castCost, 3);
  assert.equal(result.fishing.signalHoldMilliseconds, 2000);
  assert.equal(result.fishing.basePromptWidthPercent, 30);
  assert.equal(result.fishing.preciseQualityBonus, 8);
  assert.equal(result.fishing.freeNaturalBait, true);
  assert.equal(result.fishing.spots.find(spot => spot.id === 'dock_entrance').phase, 2);
  assert.equal(result.orders.length, 13);
  assert.deepEqual(result.orders.find(order => order.id === 'ss.order.fish').requirementGroups, [
    [{ item: 'fish.raw', quantity: 1 }],
    [{ item: 'fish.meat', quantity: 2 }],
  ]);
  assert.deepEqual(result.orders.find(order => order.id === 'ss.order.meal'), {
    id: 'ss.order.meal',
    phase: 4,
    acceptedItems: ['meal.soup_basic', 'meal.soup_fish', 'meal.soup_vegetable'],
    rejectedItems: ['meal.failed'],
    reward: { currency: 'exchangeTickets', quantity: 4 },
    countsTowardCycle: false,
    returnContainer: true,
    returnedContainerCleanliness: 'soiled',
    requiresTutorial: 'q4.02',
    oncePerTutorial: 'q4.03',
  });
  assert.deepEqual(result.orders.find(order => order.id === 'ss.order.insulated'), {
    id: 'ss.order.insulated',
    phase: 4,
    acceptedItems: ['meal.soup_basic', 'meal.soup_fish', 'meal.soup_vegetable'],
    rejectedItems: ['meal.failed'],
    quantity: 1,
    reward: { currency: 'exchangeTickets', quantity: 8 },
    countsTowardCycle: true,
    returnContainer: false,
    consumeContainer: true,
    containerItemId: 'container.meal_box_insulated',
    returnedContainerCleanliness: null,
  });
  assert.deepEqual(
    result.orders.find(order => order.id === 'ss.order.failed_meal_recycle'),
    {
      id: 'ss.order.failed_meal_recycle',
      phase: 4,
      acceptedItems: ['meal.failed'],
      requirementGroups: [[{ item: 'meal.failed', quantity: 3 }]],
      rejectedItems: [],
      quantity: 3,
      reward: { currency: 'exchangeTickets', quantity: 1 },
      countsTowardCycle: false,
      returnContainer: true,
      containerItemId: 'container.meal_box',
      returnedContainerCleanliness: 'soiled',
      requiresTutorial: 'q4.02',
    },
  );
  const advancedOrders = result.orders.filter(order => order.completionGroupId === 'q5.01');
  assert.deepEqual(advancedOrders.map(order => order.id), [
    'ss.order.advanced_search',
    'ss.order.advanced_recycle',
    'ss.order.advanced_fish',
    'ss.order.advanced_workbench',
    'ss.order.advanced_cooking',
  ]);
  assert.equal(
    advancedOrders.find(order => order.id === 'ss.order.advanced_search').requiredSource,
    'fixed:old_street_exchange',
  );
  assert.deepEqual(
    advancedOrders.find(order => order.id === 'ss.order.advanced_recycle').requiredRecipes,
    ['ss.recipe.unpick_cloth', 'ss.recipe.recycle_glue'],
  );
  assert.deepEqual(result.reliefPolicy, {
    intervalSeconds: 86400,
    initialClaims: 1,
    visibleLimit: 7,
    recoveryAmount: 40,
    chapterTransitionSupply: 80,
    offlineCatchUp: true,
    clockPolicy: 'utc-high-water',
  });
  assert.equal(Object.values(result.scavenging.surpriseWeights).reduce((sum, weight) => sum + weight, 0), 100);
  assert.deepEqual(result.scavenging.intactQualities, [55, 55, 55, 55, 55, 80, 80, 80, 80, 95]);
  const rack = result.scavenging.fixedLocations.find(location => location.id === 'metal_recycling_rack');
  assert.equal(rack.nodeIndex, 2);
  assert.equal(rack.phase, 1);
  assert.deepEqual(rack.options.map(option => [option.item, option.quantity, option.qualityType ?? 'scrap']), [
    ['metal.scrap', 3, 'scrap'],
    ['metal.shard', 3, 'scrap'],
    ['metal.wire', 2, 'scrap'],
    ['metal.nail_bundle', 1, 'scrap'],
    ['metal.sheet', 1, 'intact'],
    ['container.clean', 1, 'scrap'],
    ['wood.board', 1, 'intact'],
  ]);
  const fixedLocations = new Map(
    result.scavenging.fixedLocations.map(location => [location.id, location]),
  );
  assert.deepEqual(
    fixedLocations.get('sorting_shed').options.map(option => [option.item, option.quantity]),
    [['plastic.scrap', 3], ['adhesive.residue', 2]],
  );
  assert.deepEqual(
    fixedLocations.get('waterfront_materials').options.map(option => [option.item, option.quantity]),
    [['wood.driftwood', 2], ['cloth.thread_end', 3], ['rope.coarse', 1], ['food.scrap', 2]],
  );
  assert.deepEqual(
    fixedLocations.get('repair_district').options.map(option => [option.item, option.quantity]),
    [['material.waterproof_coating', 1], ['fuel.oilcloth', 1], ['fuel.dry', 1]],
  );
  assert.deepEqual(
    fixedLocations.get('market_exchange').options.map(option => [option.item, option.quantity]),
    [['food.greens', 2], ['food.edible', 2], ['food.scrap', 2], ['food.starch', 1], ['herb.wild', 2], ['seasoning.salt', 1]],
  );
});

test('q5 cooking keeps water inside reusable vessels and permits explicit meal outputs', () => {
  const content = compileContent(loadDesign());
  const { recipes } = content;
  const cleanFood = recipes.find(recipe => recipe.id === 'ss.recipe.clean_food');
  const mealBox = recipes.find(recipe => recipe.id === 'ss.recipe.meal_box');
  const boilWater = recipes.find(recipe => recipe.id === 'ss.recipe.boil_water');
  const sharedMeal = recipes.find(recipe => recipe.id === 'ss.recipe.shared_meal');
  assert.equal(cleanFood.outputs[0].item, 'food.cleaned');
  assert.ok(cleanFood.inputGroups.every(group =>
    group.some(input => ['container.clean', 'container.clean_jar'].includes(input.item)) &&
    !group.some(input => input.item.startsWith('water.'))));
  assert.equal(cleanFood.stateEffect.type, 'transformContainers');
  assert.ok(boilWater.inputGroups.every(group =>
    group.some(input => ['container.clean', 'container.clean_jar'].includes(input.item))));
  assert.equal(boilWater.outputs.length, 0);
  assert.ok(boilWater.stateEffect.containers.every(change =>
    change.optional === true &&
    change.preserveContainerContentSource === true &&
    change.preserveContainerContentQuality === true));
  assert.deepEqual(sharedMeal.outputs.map(output => output.item), ['meal.shared']);
  assert.ok(sharedMeal.inputGroups.every(group =>
    group.some(input => ['container.clean', 'container.clean_jar'].includes(input.item)) &&
    !group.some(input => input.item === 'water.boiled')));
  assert.equal(sharedMeal.stateEffect.type, 'transformContainers');
  assert.deepEqual(mealBox.outputContainerStates, {
    'container.meal_box': { cleanliness: 'clean' },
  });
  const supplies = new Map(content.renewableSupplies.map(supply => [supply.item, supply]));
  for (const [item, phase, quantity, stamina] of [
    ['container.clean_jar', 1, 1, 3],
    ['water.filtered', 0, 1, 2],
    ['food.greens', 4, 2, 3],
    ['fuel.dry', 3, 1, 3],
  ]) {
    assert.deepEqual(
      [supplies.get(item)?.phase, supplies.get(item)?.quantity, supplies.get(item)?.stamina],
      [phase, quantity, stamina],
      `q5 cooking renewable supply contract drifted for ${item}`,
    );
  }
  const invalidOutputEffect = structuredClone(sharedMeal);
  invalidOutputEffect.stateEffect = { type: 'transformContainerContent' };
  assert.ok(validateCompiledContent({
    ...compileContent(loadDesign()),
    recipes: compileContent(loadDesign()).recipes.map(recipe =>
      recipe.id === sharedMeal.id ? invalidOutputEffect : recipe),
  }).errors.includes(`invalidStateEffect:${sharedMeal.id}`));
});

test('q4.02 gameplay completion and filtration prerequisite cover every planned soup', async () => {
  const sourcePath = fileURLToPath(new URL(
    '../../lib/src/street_scrap_crafting.dart',
    import.meta.url,
  ));
  const source = await readFile(sourcePath, 'utf8');
  const pageSource = await readFile(new URL(
    '../../lib/src/street_scrap_inventory_page.dart',
    import.meta.url,
  ), 'utf8');
  const localizationSource = await readFile(new URL(
    '../../lib/src/street_scrap_localizations.dart',
    import.meta.url,
  ), 'utf8');
  const soupPredicate = source.match(/bool _isChapterFourSoupRecipe\(String recipeId\)[\s\S]*?\.contains\(recipeId\);/);
  assert.ok(soupPredicate, 'shared q4 soup predicate exists');
  for (const recipeId of [
    'ss.recipe.soup_basic',
    'ss.recipe.soup_vegetable',
    'ss.recipe.soup_fish',
  ]) {
    assert.ok(soupPredicate[0].includes(recipeId), `${recipeId} is in q4 soup predicate`);
  }
  assert.match(source, /if \(_isChapterFourSoupRecipe\(recipe\.id\) &&\s*\(rawTasks is! Map \|\| rawTasks\['q4\.01'\] != true\)\)/);
  assert.match(source, /if \(_isChapterFourSoupRecipe\(recipe\.id\) && succeeded\)\s*\{\s*tasks\['q4\.02'\] = true;/);
  assert.match(pageSource, /'q4\.01WaterRequired' => 'craft\.error\.waterLessonRequired'/);
  assert.equal((localizationSource.match(/'craft\.error\.waterLessonRequired':/g) ?? []).length, 2);
});

test('chapter 5 is a separate optional content slice and rejoins without losing gameplay data', () => {
  const full = compileContent(loadDesign());
  const { base, chapter5 } = splitContent(full);
  assert.equal(base.packVersion, '0.1.33');
  assert.equal(chapter5.packVersion, '0.1.24');
  assert.equal(base.packId, 'game.street-scrap.content.chapters-0-4');
  assert.equal(base.contentScope, 'base');
  assert.deepEqual(base.chapters, [0, 1, 2, 3, 4]);
  assert.deepEqual(
    base.scavenging.fixedLocations.map(({ id, phase, nodeIndex }) => [id, phase, nodeIndex]),
    [
      ['clothing_corner', 0, 0],
      ['paper_wood_pile', 0, 1],
      ['container_corner', 0, 2],
      ['metal_recycling_rack', 1, 2],
      ['sorting_shed', 1, 1],
      ['waterfront_materials', 2, 0],
      ['repair_district', 3, 1],
      ['market_exchange', 4, 0],
    ],
  );
  assert.equal(base.itemDefinitions.length, 98);
  assert.equal(base.recipes.length, 67);
  assert.ok(base.itemDefinitions.every(item => item.phase < 5));
  assert.ok(base.recipes.every(recipe => recipe.phase < 5));
  assert.equal(chapter5.packId, 'game.street-scrap.content.chapter-5');
  assert.equal(chapter5.contentScope, 'chapter5');
  assert.deepEqual(chapter5.chapters, [5]);
  assert.equal(chapter5.itemDefinitions.length, 13);
  assert.equal(chapter5.recipes.length, 11);
  const recyclingShed = chapter5.scavenging.fixedLocations.find(
    location => location.id === 'sorting_shed_chapter5',
  );
  assert.equal(recyclingShed.phase, 5);
  assert.equal(recyclingShed.nodeIndex, 1);
  assert.deepEqual(
    recyclingShed.options.map(option => [option.item, option.quantity]),
    [['plastic.scrap', 3], ['adhesive.residue', 2]],
  );
  const reinforcedChest = chapter5.recipes.find(recipe => recipe.id === 'ss.recipe.reinforced_chest');
  assert.deepEqual(reinforcedChest.inputGroups[0].map(({ item, quantity }) => [item, quantity]), [
    ['storage.wooden_crate', 1], ['wood.board', 2], ['metal.fastener', 2],
  ]);
  assert.equal(reinforcedChest.operation.manualCheckpoints.length, 3);
  assert.equal(reinforcedChest.quality.masteryRevision, 2);
  assert.deepEqual(reinforcedChest.outputs, []);
  assert.deepEqual(reinforcedChest.identity.retainedInputIds, ['storage.wooden_crate']);
  assert.deepEqual(reinforcedChest.stateEffect, {
    type: 'transformObject',
    fromItemId: 'storage.wooden_crate',
    toItemId: 'storage.reinforced_chest',
    requireEmptyContainer: true,
  });
  assert.equal(chapter5.orders.length, 5);
  const condenser = chapter5.recipes.find(recipe => recipe.id === 'ss.recipe.condenser');
  assert.deepEqual(
    condenser.inputGroups[0].map(({ item, quantity }) => [item, quantity]),
    [['metal.sheet', 2], ['plastic.seal', 2], ['container.clean_jar', 1]],
  );
  assert.deepEqual(condenser.identity.retainedInputIds, ['container.clean_jar']);
  assert.deepEqual(condenser.outputs.map(({ item, quantity }) => [item, quantity]), [
    ['tool.condenser', 1],
  ]);
  const distillation = chapter5.recipes.find(recipe => recipe.id === 'ss.recipe.distill_water');
  assert.deepEqual(
    distillation.inputGroups[0].map(({ item, quantity }) => [item, quantity]),
    [['container.clean', 1], ['fuel.dry', 2]],
  );
  assert.deepEqual(distillation.reusableTools, ['tool.condenser']);
  assert.deepEqual(distillation.stateEffect, {
    type: 'transformContainerContent',
    containerItemId: 'container.clean',
    fromContentItemId: 'water.filtered',
    toContentItemId: 'water.distilled',
    successCleanliness: 'utility',
    successRequiresBoiling: false,
    preserveContainerContentQuality: true,
  });
  assert.equal(distillation.operation.manualCheckpoints.length, 3);
  assert.equal(distillation.failureResolution.qualityLoss, 0);
  assert.equal(base.toolRepairs.some(rule => rule.tool === 'tool.rod_basic'), true);
  assert.equal(chapter5.toolRepairs.some(rule => rule.tool === 'tool.rod_advanced'), true);
  assert.equal(chapter5.toolRepairs.some(rule => rule.id === 'repair.precision.crowbar' &&
    rule.materialOptions[0].includes('content:water.distilled')), true);
  assert.equal(mergeContentSlices(base, chapter5).toolRepairs.length, full.toolRepairs.length);
  assert.equal(base.scavenging.phaseSurprisePools['1'].commonScraps.includes('metal.scrap'), true);
  assert.equal(chapter5.scavenging.phaseSurprisePools['5'].optionalSpecial.includes('material.mineral_pack'), true);
  assert.equal(chapter5.scavenging.phaseSurprisePools['5'].optionalSpecial.includes('water.mineral'), true);
  assert.equal(chapter5.scavenging.fixedLocations.find(location => location.id === 'old_street_exchange')
    .options.some(option => option.item === 'material.mineral_pack' && option.quantity === 1), true);
  assert.equal(mergeContentSlices(base, chapter5).scavenging.fixedLocations
    .find(location => location.id === 'old_street_exchange').options
    .some(option => option.item === 'material.mineral_pack' && option.quantity === 1), true);
  assert.equal(mergeContentSlices(base, chapter5).scavenging.phaseSurprisePools['5'].optionalSpecial.includes('material.mineral_pack'), true);
  assert.ok(chapter5.itemDefinitions.every(item => item.phase === 5));
  assert.ok(chapter5.recipes.every(recipe => recipe.phase === 5));
  assert.deepEqual(
    mergeContentSlices(base, chapter5).orders.map(order => order.id).sort(),
    full.orders.map(order => order.id).sort(),
  );
});

test('content validator rejects missing operation and malformed references', () => {
  const result = compileContent(loadDesign());
  result.recipes[0].failure.outcome = '';
  result.recipes[1].inputGroups[0][0].item = 'missing.item';
  assert.equal(validateCompiledContent(result).status, 'FAIL');
});

test('tool repair rules are unique, phase-sliced, and reference real grid items', () => {
  const result = compileContent(loadDesign());
  assert.equal(result.toolRepairs.length, 9);
  const invalid = structuredClone(result);
  invalid.toolRepairs[0].materialOptions[0][0] = 'missing.repair_part';
  assert.equal(validateCompiledContent(invalid).status, 'FAIL');
});

test('content validator rejects meal orders that consume the reusable box or accept failed meals', () => {
  const result = compileContent(loadDesign());
  const meal = result.orders.find(order => order.id === 'ss.order.meal');
  meal.acceptedItems.push('meal.failed');
  meal.returnContainer = false;
  assert.ok(validateCompiledContent(result).errors.includes('invalidOrder:ss.order.meal'));
});

test('failed-meal recovery order returns three original reusable meal boxes', () => {
  const result = compileContent(loadDesign());
  const order = result.orders.find(order => order.id === 'ss.order.failed_meal_recycle');
  assert.equal(validateCompiledContent(result).status, 'PASS');
  order.requirementGroups[0][0].quantity = 2;
  assert.ok(validateCompiledContent(result).errors.includes('invalidOrder:ss.order.failed_meal_recycle'));
});

test('content validator accepts completion-group references and rejects blank groups', () => {
  const result = compileContent(loadDesign());
  result.orders[0].completionGroupId = 'q5.01';
  assert.equal(validateCompiledContent(result).status, 'PASS');
  result.orders[0].completionGroupId = '  ';
  assert.ok(validateCompiledContent(result).errors.includes(`invalidOrder:${result.orders[0].id}`));
});

test('content validator rejects relief policies that discard offline excess', () => {
  const result = compileContent(loadDesign());
  result.reliefPolicy.visibleLimit = 0;
  assert.ok(validateCompiledContent(result).errors.includes('invalidReliefPolicy'));
});

test('content validator rejects unsafe structured failure resolutions', () => {
  const result = compileContent(loadDesign());
  result.recipes.find(recipe => recipe.id === 'ss.recipe.sew_strip').failureResolution.qualityLoss = -1;
  assert.ok(validateCompiledContent(result).errors.includes('invalidFailureResolution:ss.recipe.sew_strip'));
});

test('content validator requires the default failure policy where the plan permits it', () => {
  const result = compileContent(loadDesign());
  const eligible = result.recipes.find(recipe => recipe.failure.mode === 'reducedQualityOutput' &&
    recipe.identity.retainedInputIds.length === 0 && recipe.quality.mode !== 'preserve-primary');
  delete eligible.failureResolution;
  assert.ok(validateCompiledContent(result).errors.includes(`missingDefaultFailureResolution:${eligible.id}`));
});

test('every executable failure policy requires its interaction checkpoint template', () => {
  const { spec, recipes } = loadDesign();
  delete spec.manualCheckpointTemplates.heat;
  assert.throws(
    () => compileContent({ spec, recipes }),
    /ss\.recipe\.boil_water needs three interaction checkpoints/,
  );
});

test('content validator rejects malformed manual operation checkpoints', () => {
  const result = compileContent(loadDesign());
  result.recipes.find(recipe => recipe.id === 'ss.recipe.sew_strip')
    .operation.manualCheckpoints[0].correctOption = 9;
  assert.ok(validateCompiledContent(result).errors.includes('invalidManualCheckpoints:ss.recipe.sew_strip'));
});

test('content validator rejects malformed phase-0 scavenging rules without crashing', () => {
  const result = compileContent(loadDesign());
  result.scavenging.surpriseWeights.optionalSpecial = -5;
  result.scavenging.fixedLocations[0].options[0].item = 'missing.item';
  assert.equal(validateCompiledContent(result).status, 'FAIL');

  const malformed = compileContent(loadDesign());
  malformed.scavenging.surprisePools.commonScraps = null;
  assert.equal(validateCompiledContent(malformed).status, 'FAIL');
});

test('fixed scavenging nodes are unique per chapter and node, with phase-zero route coverage', () => {
  const duplicate = compileContent(loadDesign());
  duplicate.scavenging.fixedLocations.push({
    ...structuredClone(duplicate.scavenging.fixedLocations[0]),
    id: 'duplicate-node-zero',
  });
  assert.ok(validateCompiledContent(duplicate).errors.includes('duplicateFixedScavengingPhaseNode:0:0'));

  const missingBase = compileContent(loadDesign());
  missingBase.scavenging.fixedLocations = missingBase.scavenging.fixedLocations
    .filter(location => !(location.phase === 0 && location.nodeIndex === 1));
  assert.ok(validateCompiledContent(missingBase).errors.includes('missingPhaseZeroFixedScavengingNode:1'));
});

test('content validator rejects missing or altered fishing tutorial costs', () => {
  const malformed = compileContent(loadDesign());
  malformed.fishing.castCost = 0;
  assert.deepEqual(validateCompiledContent(malformed).errors, ['invalidFishingRules']);

  const malformedSignal = compileContent(loadDesign());
  malformedSignal.fishing.signalHoldMilliseconds = 100;
  assert.deepEqual(validateCompiledContent(malformedSignal).errors, ['invalidFishingRules']);
});

test('frontend q5.01 order fixture matches the canonical chapter-five resource', async () => {
  const canonical = JSON.parse(await readFile(
    new URL(
      '../../resources/data/street-scrap-content-chapter-5-v1.json',
      import.meta.url,
    ),
    'utf8',
  ));
  const frontendFixture = JSON.parse(await readFile(
    new URL(
      '../../test/fixtures/street_scrap_chapter5_q501_orders.json',
      import.meta.url,
    ),
    'utf8',
  ));
  const q501Orders = canonical.orders.filter(
    order => order.completionGroupId === 'q5.01',
  );
  assert.equal(frontendFixture.packId, canonical.packId);
  assert.equal(frontendFixture.packVersion, canonical.packVersion);
  assert.equal(q501Orders.length, 5);
  assert.deepEqual(frontendFixture.orders, q501Orders);
});
