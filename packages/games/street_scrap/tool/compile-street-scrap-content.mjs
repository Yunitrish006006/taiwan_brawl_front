import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { audit, loadDesign } from './audit-street-scrap-design.mjs';

const gamePackage = new URL('../', import.meta.url);
const outputUrl = new URL('resources/data/street-scrap-content-v1.json', gamePackage);
const baseOutputUrl = new URL('resources/data/street-scrap-content-chapters-0-4-v1.json', gamePackage);
const chapter5OutputUrl = new URL('resources/data/street-scrap-content-chapter-5-v1.json', gamePackage);
const basePackId = 'game.street-scrap.content.chapters-0-4';
const chapter5PackId = 'game.street-scrap.content.chapter-5';
const noPenaltyRecipes = new Set([
  'ss.recipe.recycle_glass', 'ss.recipe.salvage_board',
  'ss.recipe.toolkit', 'ss.recipe.cook_kit', 'ss.recipe.fish_pack',
  'ss.recipe.float',
]);

function stableCorrectOption(recipeId, checkpointIndex, checkpoint) {
  const options = checkpoint.options;
  const correctOption = checkpoint.correctOption;
  if (!Array.isArray(options) || options.length < 2 ||
      !Number.isInteger(correctOption) || correctOption < 0 ||
      correctOption >= options.length) {
    throw new Error(`Recipe ${recipeId} checkpoint ${checkpointIndex + 1} has an invalid answer key.`);
  }
  // A stable per-recipe placement avoids a learnable "first option is always
  // right" pattern without rerolling on retries or changing the answer text.
  let hash = 2166136261;
  for (const character of `${recipeId}:${checkpointIndex}`) {
    hash = Math.imul(hash ^ character.codePointAt(0), 16777619) >>> 0;
  }
  const targetIndex = hash % options.length;
  const wrongOptions = options.filter((_, index) => index !== correctOption);
  wrongOptions.splice(targetIndex, 0, options[correctOption]);
  return { ...structuredClone(checkpoint), options: wrongOptions, correctOption: targetIndex };
}

export function compileContent({ spec, recipes }) {
  const issues = audit(spec, recipes);
  if (issues.status !== 'PASS') throw new Error(`Design input failed audit: ${issues.errors.join('; ')}`);
  const defaultFailureResolution = spec.defaultFailureResolution;
  if (!defaultFailureResolution || defaultFailureResolution.mode !== 'sameOutputsQualityLoss' ||
      !Number.isInteger(defaultFailureResolution.qualityLoss) || defaultFailureResolution.qualityLoss < 0 ||
      defaultFailureResolution.qualityLoss > 100 || defaultFailureResolution.consumeSelectedInputs !== true) {
    throw new Error('Recipe policy must define a valid default failure resolution.');
  }
  const manualCheckpointTemplates = spec.manualCheckpointTemplates;
  if (!manualCheckpointTemplates || typeof manualCheckpointTemplates !== 'object' ||
      Array.isArray(manualCheckpointTemplates)) {
    throw new Error('Recipe policy must define interaction checkpoint templates.');
  }
  const byId = new Map(spec.recipePolicies.map(policy => [policy.id, policy]));
  const compiledRecipes = recipes.map(recipe => {
    const policy = byId.get(recipe.id);
    if (!recipe.operationText.trim()) throw new Error(`Recipe ${recipe.id} must declare an operation in its design row.`);
    if (policy.outputContainerStates !== undefined) {
      const states = policy.outputContainerStates;
      if (!states || typeof states !== 'object' || Array.isArray(states) ||
          Object.entries(states).some(([itemId, state]) =>
            !recipe.outputs.some(output => output.item === itemId) ||
            !state || typeof state !== 'object' || Array.isArray(state) ||
            Object.entries(state).some(([key, value]) =>
              key !== 'cleanliness' || !['clean', 'soiled', 'utility'].includes(value)))) {
        throw new Error(`Recipe ${recipe.id} has invalid output container states.`);
      }
    }
    const failureResolution = policy.failureResolution ?? (
      !recipe.failureOutcomeText.trim() && !noPenaltyRecipes.has(recipe.id) &&
      policy.retainedInputIdentities.length === 0 && policy.qualityMode !== 'preserve-primary'
        ? defaultFailureResolution
        : undefined
    );
    const manualEligible = failureResolution !== undefined &&
      policy.retainedInputIdentities.length === 0 &&
      (recipe.outputs.length > 0 || policy.stateEffect !== undefined) &&
      policy.qualityMode !== 'preserve-primary' && !noPenaltyRecipes.has(recipe.id);
    const manualCheckpointSource = policy.manualCheckpoints ?? (
      manualEligible ? manualCheckpointTemplates[policy.interaction] : []
    );
    if (manualEligible && (!Array.isArray(manualCheckpointSource) || manualCheckpointSource.length !== 3)) {
      throw new Error(`Recipe ${recipe.id} needs three interaction checkpoints for its executable failure policy.`);
    }
    const manualCheckpoints = manualCheckpointSource.map((checkpoint, index) =>
      stableCorrectOption(recipe.id, index, checkpoint));
    const failure = recipe.failureOutcomeText.trim()
      ? {
          mode: noPenaltyRecipes.has(recipe.id) ? 'noPenalty' : 'explicitOutcome',
          outcome: recipe.failureOutcomeText,
          sourceSection: recipe.section,
        }
      : {
          mode: noPenaltyRecipes.has(recipe.id) ? 'noPenalty' : 'reducedQualityOutput',
          outcome: noPenaltyRecipes.has(recipe.id)
            ? '確認式操作不進入失誤分支。'
            : '沿用章節17.3通則：產出主物品，品質−10；按配方扣除已確認消耗的輸入與輔料。',
          sourceSection: recipe.section,
        };
    const qualityTraitEffects = [];
    const effectTargets = [
      ...recipe.outputs.map(output => output.item),
      ...(policy.stateEffect?.toItemId ? [policy.stateEffect.toItemId] : []),
      ...(policy.stateEffect?.containers ?? []).flatMap(change => [
        change.successContentItemId,
        change.failureContentItemId,
      ].filter(Boolean)),
      ...(policy.stateEffect?.type === 'transformContainerContent'
        ? [policy.stateEffect.toContentItemId]
        : []),
    ];
    if (policy.qualityMode !== 'preserve-primary') {
      for (const inputItemId of [...new Set(recipe.inputGroups.flat().map(input => input.item))]) {
        for (const rule of spec.qualityTraitRules ?? []) {
          if ((!rule.recipeIds || rule.recipeIds.includes(recipe.id)) &&
              (!rule.operationIds || rule.operationIds.includes(policy.interaction)) &&
              rule.inputPrefixes.some(prefix => inputItemId.startsWith(prefix)) &&
              effectTargets.some(itemId => rule.outputPrefixes.some(prefix => itemId.startsWith(prefix)))) {
            qualityTraitEffects.push({
              inputItemId,
              traitId: rule.traitId,
              polarity: rule.polarity,
              modifier: rule.modifier,
            });
          }
        }
      }
    }
    return {
      id: recipe.id,
      phase: recipe.phase,
      station: policy.station,
      operation: {
        id: policy.interaction,
        durationSeconds: policy.durationSeconds,
        instructions: recipe.operationText,
        manualCheckpoints: structuredClone(manualCheckpoints),
      },
      inputGroups: recipe.inputGroups,
      reusableTools: policy.stateEffect ? structuredClone(policy.reusableTools ?? []) : recipe.tools,
      outputs: policy.stateEffect?.type === 'transformContainers' ? recipe.outputs :
        policy.stateEffect ? [] : recipe.outputs,
      ...(policy.outputContainerStates
        ? { outputContainerStates: structuredClone(policy.outputContainerStates) }
        : {}),
      ...(policy.stateEffect ? { stateEffect: structuredClone(policy.stateEffect) } : {}),
      ...(policy.failureOutputs ? { failureOutputs: structuredClone(policy.failureOutputs) } : {}),
      quality: {
        primaryInputs: policy.primaryInputs,
        loss: policy.qualityLoss,
        mode: policy.qualityMode,
        masteryRevision: policy.masteryRevision,
      },
      traitResolution: structuredClone(policy.traitResolution ?? {
        inherit: [], polarity: {}, success: {}, precise: {}, failure: {},
      }),
      qualityTraitEffects,
      identity: {
        retainedInputIds: policy.retainedInputIdentities,
      },
      failure: { trigger: 'operationFailed', ...failure },
      ...(failureResolution ? { failureResolution: structuredClone(failureResolution) } : {}),
    };
  });
  const pressRod = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.press_rod');
  if (!pressRod || pressRod.failureResolution?.mode !== 'sameOutputsQualityLoss' ||
      pressRod.failureResolution.consumeSelectedInputs !== true ||
      pressRod.operation.manualCheckpoints.length !== 3) {
    throw new Error('q3.01 press-rod lesson must compile to three manual checkpoints and a consuming quality-loss branch.');
  }
  const nailedBoard = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.nail_board');
  if (!nailedBoard || nailedBoard.failureResolution?.mode !== 'sameOutputsQualityLoss' ||
      nailedBoard.failureResolution.consumeSelectedInputs !== true ||
      nailedBoard.operation.manualCheckpoints.length !== 3) {
    throw new Error('q3.02 nail-board lesson must compile to three checkpoints and a consuming quality-loss branch.');
  }
  const woodenCrate = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.wooden_crate');
  if (!woodenCrate || woodenCrate.failureResolution?.mode !== 'sameOutputsQualityLoss' ||
      woodenCrate.operation.manualCheckpoints.length !== 3) {
    throw new Error('q3.04 crate lesson must compile to three checkpoints and a quality-loss failure branch.');
  }
  const reinforcedChest = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.reinforced_chest');
  if (!reinforcedChest || reinforcedChest.outputs.length !== 0 ||
      reinforcedChest.stateEffect?.type !== 'transformObject' ||
      reinforcedChest.stateEffect.fromItemId !== 'storage.wooden_crate' ||
      reinforcedChest.stateEffect.toItemId !== 'storage.reinforced_chest' ||
      reinforcedChest.identity.retainedInputIds.join(',') !== 'storage.wooden_crate' ||
      reinforcedChest.operation.manualCheckpoints.length !== 3 ||
      reinforcedChest.quality.masteryRevision !== 2 ||
      reinforcedChest.failureResolution?.consumeSelectedInputs !== true) {
    throw new Error('q5 reinforced chest must be a three-checkpoint, identity-preserving crate upgrade with a consuming failure branch and revised mastery.');
  }
  const paperboard = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.form_paperboard');
  if (!paperboard || paperboard.reusableTools.length !== 0 ||
      paperboard.operation.manualCheckpoints.length !== 3 ||
      paperboard.failureResolution?.mode !== 'sameOutputsQualityLoss' ||
      paperboard.failureResolution.qualityLoss !== 10 ||
      paperboard.failureResolution.consumeSelectedInputs !== true) {
    throw new Error('Paperboard must use the fixed station mould and compile to a three-step, consuming manual process.');
  }
  const bagUpgrade = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.upgrade_bag');
  if (!bagUpgrade || bagUpgrade.outputs.length !== 0 ||
      bagUpgrade.stateEffect?.type !== 'upgradeBackpack' ||
      bagUpgrade.stateEffect.capacity !== 24 ||
      bagUpgrade.operation.manualCheckpoints.length !== 3) {
    throw new Error('q3.05 must be an identity-preserving backpack state effect with three manual checkpoints.');
  }
  const insulatedBox = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.insulated_box');
  if (!insulatedBox || insulatedBox.outputs.length !== 0 ||
      insulatedBox.stateEffect?.type !== 'transformObject' ||
      insulatedBox.stateEffect.fromItemId !== 'container.meal_box' ||
      insulatedBox.stateEffect.toItemId !== 'container.meal_box_insulated' ||
      insulatedBox.identity.retainedInputIds.join(',') !== 'container.meal_box' ||
      insulatedBox.operation.manualCheckpoints.length !== 3 ||
      insulatedBox.failureResolution?.qualityLoss !== 10) {
    throw new Error('q4 insulated meal-box crafting must preserve the original instance and define three checkpoints plus a consuming quality-loss branch.');
  }
  const turbidFilter = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.filter_turbid');
  if (!turbidFilter || turbidFilter.operation.manualCheckpoints.length !== 3 ||
      turbidFilter.failureResolution?.consumeSelectedInputs !== true ||
      turbidFilter.outputs.length !== 0 ||
      turbidFilter.stateEffect?.type !== 'transformContainers' ||
      turbidFilter.stateEffect.containers?.[0]?.requiredContentItemId !== 'water.turbid' ||
      turbidFilter.stateEffect.containers?.[0]?.successContentItemId !== 'water.filtered' ||
      turbidFilter.stateEffect.containers?.[0]?.failureContentItemId !== 'water.turbid' ||
      !turbidFilter.reusableTools.includes('material.filter_cloth')) {
    throw new Error('q4.01 filtration must preserve turbid water on a miss, consume selected inputs, wear a reusable filter and expose three checkpoints.');
  }
  const basicSoup = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.soup_basic');
  if (!basicSoup || basicSoup.outputs.length !== 0 ||
      basicSoup.stateEffect?.type !== 'transformContainers' ||
      basicSoup.stateEffect.containers?.length !== 3 ||
      basicSoup.operation.manualCheckpoints.length !== 3 ||
      basicSoup.failureResolution?.consumeSelectedInputs !== true) {
    throw new Error('q4.02 basic soup must atomically consume ingredients and fill the selected meal box with either a meal or a failure meal.');
  }
  const boilWater = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.boil_water');
  if (!boilWater || boilWater.stateEffect?.type !== 'transformContainers' ||
      !boilWater.stateEffect.containers?.some(container =>
        container.containerItemId === 'container.clean' &&
        container.requiredContentItemId === 'water.filtered' &&
        container.successContentItemId === 'water.boiled' &&
        container.preserveContainerContentQuality === true) ||
      boilWater.operation.manualCheckpoints.length !== 3 ||
      boilWater.failureResolution?.consumeSelectedInputs !== true) {
    throw new Error('Water boiling must preserve the selected bottle and persist three manual checkpoints with fuel consumed on failure.');
  }
  const washContainer = compiledRecipes.find(recipe => recipe.id === 'ss.recipe.wash_container');
  if (!washContainer || washContainer.outputs.length !== 0 ||
      washContainer.stateEffect?.type !== 'transformObject' ||
      washContainer.stateEffect.fromItemId !== 'container.used_intact' ||
      washContainer.stateEffect.toItemId !== 'container.clean' ||
      washContainer.stateEffect.applyOnFailure !== false ||
      washContainer.stateEffect.targetContainerState?.cleanliness !== 'clean' ||
      washContainer.failureResolution?.consumeSelectedInputs !== true) {
    throw new Error('Washing must preserve the bottle identity, clean it only on success, and consume the water on failure.');
  }
  return {
    schemaVersion: 1,
    gameId: 'game.street-scrap',
    packId: basePackId,
    packVersion: '0.1.61',
    contentScope: 'aggregate',
    rulesetVersion: 1,
    saveSchemaVersion: 1,
    status: 'compiled-design-content-not-runtime-ready',
    optionalResource: true,
    compatibility: {
      shellApiRange: '>=1.0.0 <2.0.0',
      minimumShellVersion: null,
      note: 'Bind minimum shell version to the production owner package before publishing a resource catalog.',
    },
    chapters: [0, 1, 2, 3, 4, 5],
    quality: {
      range: [0, 100],
      tiers: [
        { id: 'poor', min: 0, max: 39, label: '粗劣' },
        { id: 'ordinary', min: 40, max: 69, label: '普通' },
        { id: 'good', min: 70, max: 89, label: '良好' },
        { id: 'excellent', min: 90, max: 100, label: '優良' },
      ],
      sourceSection: 'docs/third-game-design-plan.md section 11.3',
    },
    itemDefinitions: spec.items.map(item => ({ ...item })),
    recipes: compiledRecipes,
    packing: spec.bundles.map(bundle => ({ ...bundle })),
    renewableSupplies: spec.supplies.map(source => ({ ...source })),
    tutorialSeeds: spec.seeds.map(seed => ({ ...seed })),
    scavenging: {
      ...structuredClone(spec.scavenging),
      phaseSurprisePools: Object.fromEntries(
        Array.from({ length: 6 }, (_, phase) => [
          String(phase),
          Object.fromEntries(
            Object.entries(spec.scavenging.surprisePools).map(([category, items]) => [
              category,
              items.filter(itemId => spec.items.find(item => item.id === itemId)?.phase <= phase),
            ]),
          ),
        ]),
      ),
      fixedLocations: spec.scavenging.fixedLocations.map(location => ({
        ...location,
        options: location.options.map(option => ({
          ...option,
          label: spec.items.find(item => item.id === option.item)?.name,
        })),
      })),
    },
    fishing: structuredClone(spec.fishing),
    toolRepairs: structuredClone(spec.toolRepairs),
    orders: structuredClone(spec.orders),
    reliefPolicy: structuredClone(spec.reliefPolicy),
    limits: { ...spec.limits },
    declaredTerminalUses: { ...spec.terminalUses },
    sourceMap: {
      itemDictionary: 'taiwan_brawl_front/packages/games/street_scrap/design/street-scrap-design.json',
      recipeTable: 'docs/third-game-design-plan.md sections 11.4, 12.3, 12.4, 13.1, 13.2',
      recipePolicy: 'taiwan_brawl_front/packages/games/street_scrap/design/street-scrap-recipe-policy.json',
    },
  };
}

export function validateCompiledContent(content) {
  const errors = [];
  const ids = new Set(content.itemDefinitions.map(item => item.id));
  const gridIds = new Set(content.itemDefinitions.filter(item => item.location === 'grid').map(item => item.id));
  const itemPhases = new Map(content.itemDefinitions.map(item => [item.id, item.phase]));
  if (ids.size !== content.itemDefinitions.length) errors.push('duplicateItemId');
  for (const item of content.itemDefinitions) {
    if (!Number.isInteger(item.phase) || item.phase < 0 || item.phase > 5) errors.push(`invalidItemPhase:${item.id}`);
    if (item.location === 'grid' && (!Array.isArray(item.footprint) || item.footprint.length !== 2 || item.footprint.some(n => !Number.isInteger(n) || n < 1))) errors.push(`invalidFootprint:${item.id}`);
    if (item.location !== 'grid' && item.footprint !== null) errors.push(`nonGridHasFootprint:${item.id}`);
    if (item.baseDurability !== undefined &&
        (!Number.isInteger(item.baseDurability) || item.baseDurability < 1 || item.location !== 'grid')) {
      errors.push(`invalidBaseDurability:${item.id}`);
    }
  }
  const recipeIds = new Set();
  for (const recipe of content.recipes) {
    if (recipeIds.has(recipe.id)) errors.push(`duplicateRecipe:${recipe.id}`);
    recipeIds.add(recipe.id);
    if (!['explicitOutcome', 'reducedQualityOutput', 'noPenalty'].includes(recipe.failure?.mode) || !recipe.failure?.outcome?.trim()) errors.push(`missingFailureOutcome:${recipe.id}`);
    const failureResolution = recipe.failureResolution;
    if (failureResolution !== undefined &&
        (failureResolution === null || typeof failureResolution !== 'object' || Array.isArray(failureResolution) ||
          failureResolution.mode !== 'sameOutputsQualityLoss' ||
          !Number.isInteger(failureResolution.qualityLoss) || failureResolution.qualityLoss < 0 ||
          failureResolution.qualityLoss > 100 || failureResolution.consumeSelectedInputs !== true)) {
      errors.push(`invalidFailureResolution:${recipe.id}`);
    }
    if (recipe.failure.mode === 'reducedQualityOutput' &&
        recipe.identity.retainedInputIds.length === 0 && recipe.quality.mode !== 'preserve-primary' &&
        failureResolution === undefined) errors.push(`missingDefaultFailureResolution:${recipe.id}`);
    if (!recipe.operation?.id || !recipe.operation.instructions?.trim()) errors.push(`missingOperation:${recipe.id}`);
    const traitResolution = recipe.traitResolution;
    const traitPolarity = traitResolution?.polarity;
    if (!traitResolution || !Array.isArray(traitResolution.inherit) ||
        !traitPolarity || typeof traitPolarity !== 'object' || Array.isArray(traitPolarity) ||
        Object.values(traitPolarity).some(value => !['positive', 'negative'].includes(value)) ||
        !['success', 'precise', 'failure'].every(outcome => {
          const traits = traitResolution[outcome];
          return traits && typeof traits === 'object' && !Array.isArray(traits) &&
            Object.entries(traits).every(([id, present]) => id.trim() && typeof present === 'boolean' && traitPolarity[id]);
        }) || traitResolution.inherit.some(rule =>
          !rule || typeof rule !== 'object' || Array.isArray(rule) ||
          typeof rule.inputItemId !== 'string' ||
          !recipe.quality.primaryInputs.includes(rule.inputItemId) ||
          !rule.map || typeof rule.map !== 'object' || Array.isArray(rule.map) ||
          Object.entries(rule.map).some(([from, to]) => !from.trim() || typeof to !== 'string' || !to.trim() || !traitPolarity[to]))) {
      errors.push(`invalidTraitResolution:${recipe.id}`);
    } else {
      for (const outcome of ['success', 'precise', 'failure']) {
        const traits = Object.keys(traitResolution[outcome]);
        if (['positive', 'negative'].some(polarity =>
          traits.filter(id => traitPolarity[id] === polarity).length > 1)) {
          errors.push(`traitPolarityLimitExceeded:${recipe.id}:${outcome}`);
        }
      }
    }
    const qualityTraitEffects = recipe.qualityTraitEffects;
    if (!Array.isArray(qualityTraitEffects) || qualityTraitEffects.some(effect =>
      !effect || typeof effect !== 'object' || Array.isArray(effect) ||
      typeof effect.inputItemId !== 'string' ||
      !recipe.inputGroups.some(group => group.some(input => input.item === effect.inputItemId)) ||
      typeof effect.traitId !== 'string' || !effect.traitId.trim() ||
      !['positive', 'negative'].includes(effect.polarity) ||
      !Number.isInteger(effect.modifier) || effect.modifier === 0 ||
      (effect.polarity === 'positive' ? effect.modifier < 0 : effect.modifier > 0))) {
      errors.push(`invalidQualityTraitEffects:${recipe.id}`);
    }
    if (!Number.isInteger(recipe.operation.durationSeconds) || recipe.operation.durationSeconds < 1) errors.push(`invalidDuration:${recipe.id}`);
    if (!Array.isArray(recipe.operation.manualCheckpoints) ||
        (recipe.operation.manualCheckpoints.length !== 0 && recipe.operation.manualCheckpoints.length !== 3) ||
        recipe.operation.manualCheckpoints.some(checkpoint =>
      !checkpoint || typeof checkpoint !== 'object' || Array.isArray(checkpoint) ||
      typeof checkpoint.prompt !== 'string' || !checkpoint.prompt.trim() ||
      !Array.isArray(checkpoint.options) || checkpoint.options.length < 2 ||
      checkpoint.options.some(option => typeof option !== 'string' || !option.trim()) ||
      !Number.isInteger(checkpoint.correctOption) || checkpoint.correctOption < 0 ||
      checkpoint.correctOption >= checkpoint.options.length)) errors.push(`invalidManualCheckpoints:${recipe.id}`);
    for (const input of recipe.inputGroups.flat()) if (!ids.has(input.item) || !Number.isInteger(input.quantity) || input.quantity < 1) errors.push(`invalidInput:${recipe.id}:${input.item}`);
    for (const output of recipe.outputs) if (!ids.has(output.item) || !Number.isInteger(output.quantity) || output.quantity < 1) errors.push(`invalidOutput:${recipe.id}:${output.item}`);
    if (recipe.stateEffect !== undefined) {
      const backpackEffect = recipe.stateEffect?.type === 'upgradeBackpack' &&
        recipe.stateEffect.fromItemId === 'bag.basic' &&
        recipe.stateEffect.toItemId === 'bag.reinforced' &&
        recipe.stateEffect.capacity === 24;
      const containerEffect = recipe.stateEffect?.type === 'transformContainerContent' &&
        gridIds.has(recipe.stateEffect.containerItemId) &&
        ids.has(recipe.stateEffect.fromContentItemId) && ids.has(recipe.stateEffect.toContentItemId) &&
        recipe.inputGroups.some(group => group.some(input => input.item === recipe.stateEffect.containerItemId));
      const multipleContainerEffect = recipe.stateEffect?.type === 'transformContainers' &&
        Array.isArray(recipe.stateEffect.containers) && recipe.stateEffect.containers.length > 0 &&
        recipe.stateEffect.containers.every(change => change && typeof change === 'object' &&
          (change.optional == null || typeof change.optional === 'boolean') &&
          gridIds.has(change.containerItemId) &&
          (change.requiredContentItemId == null || ids.has(change.requiredContentItemId)) &&
          (change.successContentItemId == null || ids.has(change.successContentItemId)) &&
          (change.failureContentItemId == null || ids.has(change.failureContentItemId)) &&
          recipe.inputGroups.some(group => group.some(input =>
            input.item === change.containerItemId ||
            (change.optional === true && change.requiredContentItemId &&
              input.item === change.requiredContentItemId))));
      const identityTransform = recipe.stateEffect?.type === 'transformObject' &&
        ids.has(recipe.stateEffect.fromItemId) && ids.has(recipe.stateEffect.toItemId) &&
        recipe.stateEffect.requireEmptyContainer === true &&
        (recipe.stateEffect.applyOnFailure == null || typeof recipe.stateEffect.applyOnFailure === 'boolean') &&
        (recipe.stateEffect.clearContainerState == null || typeof recipe.stateEffect.clearContainerState === 'boolean') &&
        (recipe.stateEffect.targetContainerState == null ||
          (recipe.stateEffect.targetContainerState && typeof recipe.stateEffect.targetContainerState === 'object' &&
            !Array.isArray(recipe.stateEffect.targetContainerState) &&
            Object.entries(recipe.stateEffect.targetContainerState).every(([key, value]) =>
              typeof key === 'string' && value !== undefined))) &&
        recipe.identity.retainedInputIds.length === 1 &&
        recipe.identity.retainedInputIds[0] === recipe.stateEffect.fromItemId &&
        recipe.inputGroups.some(group => group.some(input => input.item === recipe.stateEffect.fromItemId));
      const retainedPack = recipe.stateEffect?.type === 'packObjects' &&
        Array.isArray(recipe.stateEffect.retainedInputIds) &&
        recipe.stateEffect.retainedInputIds.length > 0 && ids.has(recipe.stateEffect.toItemId) &&
        recipe.identity.retainedInputIds.length === recipe.stateEffect.retainedInputIds.length &&
        recipe.identity.retainedInputIds.every((id, index) => id === recipe.stateEffect.retainedInputIds[index]) &&
        recipe.stateEffect.retainedInputIds.every(id => ids.has(id) &&
          recipe.inputGroups.some(group => group.some(input => input.item === id))) &&
        (recipe.stateEffect.requireEmptyContainerItems == null ||
          (Array.isArray(recipe.stateEffect.requireEmptyContainerItems) &&
            recipe.stateEffect.requireEmptyContainerItems.every(id => recipe.stateEffect.retainedInputIds.includes(id)))) &&
        content.packing.some(rule => rule.input === recipe.stateEffect.packingRuleId &&
          rule.output === recipe.stateEffect.toItemId &&
          JSON.stringify([...(rule.inputItems ?? Array(rule.count).fill(rule.input))].sort()) ===
            JSON.stringify([...recipe.stateEffect.retainedInputIds].sort()));
      if ((!backpackEffect && !containerEffect && !multipleContainerEffect && !identityTransform && !retainedPack) ||
          (recipe.outputs.length !== 0 && !multipleContainerEffect)) {
        errors.push(`invalidStateEffect:${recipe.id}`);
      }
    }
    if (recipe.failureOutputs !== undefined &&
        (!Array.isArray(recipe.failureOutputs) || recipe.failureOutputs.length === 0 ||
         recipe.failureOutputs.some(output => !output || typeof output !== 'object' || Array.isArray(output) || !ids.has(output.item) ||
           !Number.isInteger(output.quantity) || output.quantity < 1))) {
      errors.push(`invalidFailureOutputs:${recipe.id}`);
    }
    for (const tool of recipe.reusableTools) if (!ids.has(tool)) errors.push(`unknownTool:${recipe.id}:${tool}`);
    for (const item of [...recipe.quality.primaryInputs, ...recipe.identity.retainedInputIds]) if (!ids.has(item)) errors.push(`unknownPolicyItem:${recipe.id}:${item}`);
    if (!recipe.phase && recipe.phase !== 0 || recipe.phase < 0 || recipe.phase > 5) errors.push(`invalidPhase:${recipe.id}`);
  }
  for (const bundle of content.packing) {
    const contents = bundle.inputItems ?? Array(bundle.count).fill(bundle.input);
    if (!ids.has(bundle.input) || !ids.has(bundle.output) ||
        !Array.isArray(contents) || contents.length !== bundle.count ||
        contents.some(id => !ids.has(id)) ||
        !(bundle.count === 4 || bundle.output === 'toolpart.float' || bundle.output === 'tool.cook_kit') ||
        !bundle.manualUnpack) errors.push(`invalidPacking:${bundle.output}`);
  }
  for (const source of [...content.renewableSupplies, ...content.tutorialSeeds]) {
    if (!ids.has(source.item) || !Number.isInteger(source.phase) || source.phase < 0 || source.phase > 5) errors.push(`invalidSource:${source.item}`);
  }
  const scavenging = content.scavenging;
  const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const weights = scavenging?.surpriseWeights;
  const pools = scavenging?.surprisePools;
  const weightEntries = isRecord(weights) ? Object.entries(weights) : [];
  const poolEntries = isRecord(pools) ? Object.entries(pools) : [];
  const scrapQualities = scavenging?.scrapQualities;
  const intactQualities = scavenging?.intactQualities;
  const fixedLocations = scavenging?.fixedLocations;
  const traitPools = scavenging?.surpriseTraitPools;
  const expectedSurpriseWeights = { commonScraps: 50, intactBase: 25, containers: 15, optionalSpecial: 10 };
  const phaseSurprisePools = scavenging?.phaseSurprisePools;
  const expectedPhasePools = Object.fromEntries(Array.from({ length: 6 }, (_, phase) => [
    String(phase),
    Object.fromEntries(poolEntries.map(([category, pool]) => [
      category,
      (Array.isArray(pool) ? pool : []).filter(id => content.itemDefinitions.find(item => item.id === id)?.phase <= phase),
    ])),
  ]));
  if (!isRecord(scavenging) || scavenging.version !== 4 || scavenging.nodeCount !== 3 || scavenging.investigationsPerNode !== 1 ||
      !Number.isInteger(scavenging.movementCost) || scavenging.movementCost < 0 ||
      !Number.isInteger(scavenging.investigationCost) || scavenging.investigationCost < 1 ||
      !Number.isInteger(scavenging.fixedWrongQuantity) || scavenging.fixedWrongQuantity < 1 ||
      !Array.isArray(scrapQualities) || !scrapQualities.length ||
      !Array.isArray(intactQualities) || !intactQualities.length ||
      [...(Array.isArray(scrapQualities) ? scrapQualities : []), ...(Array.isArray(intactQualities) ? intactQualities : [])]
        .some(quality => !Number.isInteger(quality) || quality < 0 || quality > 100) ||
      !isRecord(weights) || !isRecord(pools) || weightEntries.length !== poolEntries.length ||
      JSON.stringify(phaseSurprisePools) !== JSON.stringify(expectedPhasePools) ||
      !isRecord(traitPools) || traitPools.chancePercent !== 20 ||
      !Array.isArray(traitPools.positive) || !Array.isArray(traitPools.negative) ||
      [...(traitPools.positive ?? []), ...(traitPools.negative ?? [])].some(rule =>
        !isRecord(rule) || typeof rule.prefix !== 'string' || !rule.prefix ||
        typeof rule.id !== 'string' || !rule.id ||
        (rule.minimumQuality !== undefined && (!Number.isInteger(rule.minimumQuality) || rule.minimumQuality < 0 || rule.minimumQuality > 100))) ||
      weightEntries.length !== Object.keys(expectedSurpriseWeights).length ||
      Object.entries(expectedSurpriseWeights).some(([key, weight]) => weights?.[key] !== weight) ||
      weightEntries.some(([key, weight]) => !Number.isInteger(weight) || weight < 0 || !Array.isArray(pools[key])) ||
      weightEntries.reduce((sum, [, weight]) => sum + (Number.isInteger(weight) ? weight : 0), 0) !== 100 ||
      poolEntries.some(([key, pool]) => !Object.hasOwn(weights ?? {}, key) || !Array.isArray(pool) ||
        (key !== 'optionalSpecial' && pool.length === 0) ||
        pool.some(id => (!gridIds.has(id) && !(key === 'optionalSpecial' && id === 'water.mineral')) || !Number.isInteger(content.itemDefinitions.find(item => item.id === id)?.phase))) ||
      !Array.isArray(fixedLocations) || fixedLocations.length < (scavenging?.nodeCount ?? 3)) {
    errors.push('invalidScavengingRules');
  }
  const locationIds = new Set();
  const phaseNodePairs = new Set();
  for (const location of Array.isArray(fixedLocations) ? fixedLocations : []) {
    if (!isRecord(location) || typeof location.id !== 'string' || locationIds.has(location.id) ||
        !Number.isInteger(location.nodeIndex) || location.nodeIndex < 0 || location.nodeIndex >= scavenging.nodeCount ||
        !Number.isInteger(location.phase) || location.phase < 0 || location.phase > 5 ||
        !Array.isArray(location.options) || location.options.length === 0 ||
        location.options.some(option => !isRecord(option) || !gridIds.has(option.item) || typeof option.label !== 'string' || !option.label.trim() || !Number.isInteger(option.quantity) || option.quantity < 1 || !['scrap', 'intact'].includes(option.qualityType ?? 'scrap') || content.itemDefinitions.find(item => item.id === option.item)?.phase > location.phase)) {
      errors.push(`invalidFixedScavengingLocation:${location.id}`);
    }
    if (Number.isInteger(location?.nodeIndex) && Number.isInteger(location?.phase)) {
      const pair = `${location.phase}:${location.nodeIndex}`;
      if (phaseNodePairs.has(pair)) errors.push(`duplicateFixedScavengingPhaseNode:${pair}`);
      phaseNodePairs.add(pair);
    }
    if (typeof location?.id === 'string') locationIds.add(location.id);
  }
  for (let node = 0; node < (scavenging?.nodeCount ?? 3); node++) {
    if (!phaseNodePairs.has(`0:${node}`)) errors.push(`missingPhaseZeroFixedScavengingNode:${node}`);
  }
  const fishing = content.fishing;
  if (!isRecord(fishing) || fishing.version !== 1 || fishing.castCost !== 3 ||
      fishing.signalsPerCast !== 3 || fishing.successSignals !== 2 || fishing.perfectSignals !== 3 ||
      fishing.signalHoldMilliseconds !== 2000 || fishing.basePromptWidthPercent !== 30 ||
      fishing.preciseQualityBonus !== 8 ||
      fishing.guaranteeAfterFailures !== 2 || fishing.freeNaturalBait !== true ||
      fishing.loanerRodAvailable !== true || !Array.isArray(fishing.spots) ||
      !fishing.spots.some(spot => isRecord(spot) && spot.id === 'dock_entrance' && spot.phase === 2) ||
      !fishing.spots.some(spot => isRecord(spot) && spot.id === 'raft_point' && spot.phase === 3 &&
        Array.isArray(spot.failureRewards) && JSON.stringify(spot.failureRewards) === JSON.stringify(['fish.bone', 'wood.driftwood'])) ||
      !Array.isArray(fishing.failureRewards) || fishing.failureRewards.length !== 2 ||
      fishing.failureRewards.some(id => !gridIds.has(id)) ||
      fishing.spots.some(spot => isRecord(spot) && spot.failureRewards &&
        (!Array.isArray(spot.failureRewards) || spot.failureRewards.length !== 2 || spot.failureRewards.some(id => !gridIds.has(id))))) {
    errors.push('invalidFishingRules');
  }
  const orderIds = new Set();
  const repairIds = new Set();
  for (const repair of content.toolRepairs ?? []) {
    if (!repair || typeof repair.id !== 'string' || repairIds.has(repair.id) ||
        typeof repair.tool !== 'string' ||
        !gridIds.has(repair.tool) || !Number.isInteger(repair.phase) || repair.phase < 0 || repair.phase > 5 ||
        itemPhases.get(repair.tool) > repair.phase ||
        !Number.isInteger(repair.restoreUses) || repair.restoreUses < 1 ||
        !Array.isArray(repair.materialOptions) || repair.materialOptions.length === 0 ||
        repair.materialOptions.some(option => !Array.isArray(option) || option.length === 0 ||
          option.some(item => {
            const contentId = typeof item === 'string' && item.startsWith('content:') ? item.slice('content:'.length) : item;
            const validLocation = typeof item === 'string' && item.startsWith('content:')
              ? ids.has(contentId) && !gridIds.has(contentId)
              : gridIds.has(contentId);
            return !validLocation || itemPhases.get(contentId) > repair.phase;
          }) || new Set(option).size !== option.length)) {
      errors.push(`invalidToolRepair:${repair?.id}`);
    } else {
      repairIds.add(repair.id);
    }
  }
  for (const order of content.orders ?? []) {
    if (!isRecord(order) || typeof order.id !== 'string' || orderIds.has(order.id) ||
        !Number.isInteger(order.phase) || order.phase < 0 || order.phase > 5 ||
        !Array.isArray(order.acceptedItems) ||
        order.acceptedItems.some(id => !ids.has(id)) ||
        (order.requirementGroups != null &&
          (!Array.isArray(order.requirementGroups) || order.requirementGroups.length === 0 ||
            order.requirementGroups.some(group => !Array.isArray(group) || group.length === 0 ||
              group.some(entry => !isRecord(entry) || !ids.has(entry.item) ||
                !order.acceptedItems.includes(entry.item) ||
                !Number.isInteger(entry.quantity) || entry.quantity < 1)))) ||
        (order.acceptedItems.length === 0 && order.requirementGroups == null) ||
        !Array.isArray(order.rejectedItems) || order.rejectedItems.some(id => !ids.has(id)) ||
        order.acceptedItems.some(id => order.rejectedItems.includes(id)) ||
        !isRecord(order.reward) || order.reward.currency !== 'exchangeTickets' ||
        !Number.isInteger(order.reward.quantity) || order.reward.quantity < 1 ||
        typeof order.countsTowardCycle !== 'boolean' ||
        typeof order.returnContainer !== 'boolean' ||
        (order.consumeContainer != null && typeof order.consumeContainer !== 'boolean') ||
        (order.containerItemId != null && !ids.has(order.containerItemId)) ||
        (order.returnContainer === true && order.consumeContainer === true) ||
        (order.consumeContainer === true && order.containerItemId == null) ||
        (order.containerItemId != null &&
          order.returnContainer !== true && order.consumeContainer !== true) ||
        (order.consumeContainer === true && order.quantity !== 1) ||
        (order.returnContainer === true && Array.isArray(order.requirementGroups) &&
          order.requirementGroups.some(group =>
            group.reduce((sum, entry) => sum + entry.quantity, 0) !==
              (order.quantity ?? 1))) ||
        (order.returnedContainerCleanliness != null && typeof order.returnedContainerCleanliness !== 'string') ||
        (order.requiresTutorial != null && typeof order.requiresTutorial !== 'string') ||
        (order.oncePerTutorial != null && typeof order.oncePerTutorial !== 'string') ||
        (order.completionGroupId != null &&
          (typeof order.completionGroupId !== 'string' || !order.completionGroupId.trim())) ||
        (order.requiresAcceptance != null && typeof order.requiresAcceptance !== 'boolean') ||
        (order.requiredSource != null &&
          (typeof order.requiredSource !== 'string' || !order.requiredSource.trim())) ||
        (order.requiredRecipes != null &&
          (!Array.isArray(order.requiredRecipes) || order.requiredRecipes.length === 0 ||
            order.requiredRecipes.some(recipeId => !recipeIds.has(recipeId)) ||
            new Set(order.requiredRecipes).size !== order.requiredRecipes.length)) ||
        ((order.requiredSource != null || order.requiredRecipes != null) &&
          order.requiresAcceptance !== true) ||
        (order.id === 'ss.order.meal' &&
          (order.phase !== 4 || order.returnContainer !== true ||
            order.reward.quantity !== 4 || order.requiresTutorial !== 'q4.02' ||
            order.countsTowardCycle !== false ||
            order.oncePerTutorial !== 'q4.03' ||
            !order.rejectedItems.includes('meal.failed'))) ||
        (order.id === 'ss.order.failed_meal_recycle' &&
          (order.phase !== 4 || order.returnContainer !== true ||
            order.containerItemId !== 'container.meal_box' ||
            order.quantity !== 3 || order.reward.quantity !== 1 ||
            order.countsTowardCycle !== false ||
            order.requiresTutorial !== 'q4.02' ||
            order.requirementGroups?.length !== 1 ||
            order.requirementGroups?.[0]?.length !== 1 ||
            order.requirementGroups?.[0]?.[0]?.item !== 'meal.failed' ||
            order.requirementGroups?.[0]?.[0]?.quantity !== 3)) ||
        (order.id === 'ss.order.insulated' &&
          (order.phase !== 4 || order.consumeContainer !== true ||
            order.containerItemId !== 'container.meal_box_insulated' ||
            order.returnContainer !== false || order.reward.quantity !== 8 ||
            order.countsTowardCycle !== true || order.quantity !== 1 ||
            !order.acceptedItems.includes('meal.soup_basic') ||
            !order.acceptedItems.includes('meal.soup_fish') ||
            !order.acceptedItems.includes('meal.soup_vegetable') ||
            !order.rejectedItems.includes('meal.failed')))) {
      errors.push(`invalidOrder:${order?.id}`);
    }
    if (typeof order?.id === 'string') orderIds.add(order.id);
  }
  const relief = content.reliefPolicy;
  if (!isRecord(relief) || relief.intervalSeconds !== 86400 ||
      relief.initialClaims !== 1 || relief.visibleLimit !== 7 ||
      relief.recoveryAmount !== 40 || relief.chapterTransitionSupply !== 80 ||
      relief.offlineCatchUp !== true || relief.clockPolicy !== 'utc-high-water') {
    errors.push('invalidReliefPolicy');
  }
  const tiers = content.quality.tiers;
  if (tiers[0]?.min !== 0 || tiers.at(-1)?.max !== 100 || tiers.some((tier, index) => index > 0 && tiers[index - 1].max + 1 !== tier.min)) errors.push('invalidQualityTierCoverage');
  if (content.gameId !== 'game.street-scrap' || !content.optionalResource || !content.packVersion || !content.rulesetVersion || !content.saveSchemaVersion || !Array.isArray(content.orders) || !content.reliefPolicy) errors.push('invalidManifest');
  return { status: errors.length ? 'FAIL' : 'PASS', counts: { items: content.itemDefinitions.length, recipes: content.recipes.length, packingRules: content.packing.length }, errors };
}

export function renderContent(content) { return `${JSON.stringify(content, null, 2)}\n`; }

export function splitContent(content) {
  const baseIds = new Set(content.itemDefinitions.filter(item => item.phase <= 4).map(item => item.id));
  const chapter5Ids = new Set(content.itemDefinitions.filter(item => item.phase === 5).map(item => item.id));
  const byScope = (items, predicate) => items.filter(predicate).map(item => structuredClone(item));
  const base = structuredClone(content);
  base.packId = basePackId;
  base.packVersion = '0.1.33';
  base.contentScope = 'base';
  base.chapters = [0, 1, 2, 3, 4];
  base.itemDefinitions = byScope(content.itemDefinitions, item => item.phase <= 4);
  base.recipes = byScope(content.recipes, recipe => recipe.phase <= 4);
  base.toolRepairs = byScope(content.toolRepairs, repair => repair.phase <= 4);
  base.packing = content.packing.filter(rule => baseIds.has(rule.input) && baseIds.has(rule.output));
  base.renewableSupplies = byScope(content.renewableSupplies, source => source.phase <= 4);
  base.tutorialSeeds = byScope(content.tutorialSeeds, seed => seed.phase <= 4);
  base.orders = byScope(content.orders, order => order.phase <= 4);
  base.scavenging.fixedLocations = byScope(content.scavenging.fixedLocations, location => location.phase <= 4);
  base.scavenging.surprisePools = Object.fromEntries(Object.entries(content.scavenging.surprisePools)
    .map(([key, ids]) => [key, ids.filter(id => baseIds.has(id))]));
  base.scavenging.phaseSurprisePools = Object.fromEntries(Object.entries(content.scavenging.phaseSurprisePools)
    .map(([phase, pools]) => [phase, Object.fromEntries(Object.entries(pools)
      .map(([key, ids]) => [key, ids.filter(id => baseIds.has(id))]))]));
  base.scavenging.itemLabels = Object.fromEntries(Object.entries(content.scavenging.itemLabels)
    .filter(([id]) => baseIds.has(id)));
  base.fishing.spots = byScope(content.fishing.spots, spot => spot.phase <= 4);
  base.declaredTerminalUses = Object.fromEntries(Object.entries(content.declaredTerminalUses)
    .filter(([id, usage]) => baseIds.has(id) && !/ss\.order\.(?:wall|advanced_)/.test(usage)));

  const chapter5 = structuredClone(content);
  chapter5.packId = chapter5PackId;
  chapter5.packVersion = '0.1.24';
  chapter5.contentScope = 'chapter5';
  chapter5.chapters = [5];
  chapter5.itemDefinitions = byScope(content.itemDefinitions, item => item.phase === 5);
  chapter5.recipes = byScope(content.recipes, recipe => recipe.phase === 5);
  chapter5.toolRepairs = byScope(content.toolRepairs, repair => repair.phase === 5);
  chapter5.packing = content.packing.filter(rule => chapter5Ids.has(rule.input) || chapter5Ids.has(rule.output));
  chapter5.renewableSupplies = byScope(content.renewableSupplies, source => source.phase === 5);
  chapter5.tutorialSeeds = byScope(content.tutorialSeeds, seed => seed.phase === 5);
  chapter5.orders = byScope(content.orders, order => order.phase === 5);
  chapter5.scavenging.fixedLocations = byScope(content.scavenging.fixedLocations, location => location.phase === 5);
  chapter5.scavenging.surprisePools = Object.fromEntries(Object.entries(content.scavenging.surprisePools)
    .map(([key, ids]) => [key, ids.filter(id => chapter5Ids.has(id))]));
  chapter5.scavenging.phaseSurprisePools = Object.fromEntries(Object.entries(content.scavenging.phaseSurprisePools)
    .map(([phase, pools]) => [phase, Object.fromEntries(Object.entries(pools)
      .map(([key, ids]) => [key, ids.filter(id => chapter5Ids.has(id))]))]));
  chapter5.scavenging.itemLabels = Object.fromEntries(Object.entries(content.scavenging.itemLabels)
    .filter(([id]) => chapter5Ids.has(id)));
  chapter5.fishing.spots = byScope(content.fishing.spots, spot => spot.phase === 5);
  chapter5.declaredTerminalUses = Object.fromEntries(Object.entries(content.declaredTerminalUses)
    .filter(([id, usage]) => chapter5Ids.has(id) || /ss\.order\.(?:wall|advanced_)/.test(usage)));

  const merged = mergeContentSlices(base, chapter5);
  const normalized = structuredClone(content);
  normalized.packId = basePackId;
  normalized.packVersion = '0.1.33';
  normalized.contentScope = 'aggregate';
  const canonical = value => Array.isArray(value)
    ? value.map(canonical).sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)))
    : value && typeof value === 'object'
      ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]))
      : value;
  if (JSON.stringify(canonical(merged)) !== JSON.stringify(canonical(normalized))) {
    const mismatchedKeys = Object.keys(normalized).filter(key =>
      JSON.stringify(merged[key]) !== JSON.stringify(normalized[key]));
    throw new Error(`Chapter content split does not losslessly reconstruct the canonical payload: ${mismatchedKeys.join(', ')}`);
  }
  return { base, chapter5 };
}

export function mergeContentSlices(base, chapter5) {
  const merged = structuredClone(base);
  for (const key of ['itemDefinitions', 'recipes', 'toolRepairs', 'renewableSupplies', 'tutorialSeeds', 'orders']) {
    merged[key] = [...base[key], ...chapter5[key]];
  }
  merged.packId = basePackId;
  merged.packVersion = base.packVersion;
  merged.contentScope = 'aggregate';
  merged.chapters = [0, 1, 2, 3, 4, 5];
  merged.packing = [...base.packing, ...chapter5.packing];
  merged.scavenging.fixedLocations = [...base.scavenging.fixedLocations, ...chapter5.scavenging.fixedLocations];
  merged.scavenging.surprisePools = Object.fromEntries(Object.keys(base.scavenging.surprisePools).map(category => [
    category,
    [...base.scavenging.surprisePools[category], ...chapter5.scavenging.surprisePools[category]],
  ]));
  merged.scavenging.phaseSurprisePools = Object.fromEntries(Object.keys(base.scavenging.phaseSurprisePools).map(phase => [
    phase,
    Object.fromEntries(Object.keys(base.scavenging.phaseSurprisePools[phase]).map(category => [
      category,
      [...base.scavenging.phaseSurprisePools[phase][category], ...chapter5.scavenging.phaseSurprisePools[phase][category]],
    ])),
  ]));
  merged.fishing.spots = [...base.fishing.spots, ...chapter5.fishing.spots];
  merged.declaredTerminalUses = { ...base.declaredTerminalUses, ...chapter5.declaredTerminalUses };
  return merged;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const content = compileContent(loadDesign());
  const slices = splitContent(content);
  const report = validateCompiledContent(content);
  if (report.status !== 'PASS') throw new Error(JSON.stringify(report.errors));
  const rendered = renderContent(content);
  const renderedBase = renderContent(slices.base);
  const renderedChapter5 = renderContent(slices.chapter5);
  if (process.argv.includes('--write')) {
    fs.writeFileSync(outputUrl, rendered);
    fs.writeFileSync(baseOutputUrl, renderedBase);
    fs.writeFileSync(chapter5OutputUrl, renderedChapter5);
    console.log(`Wrote ${report.counts.items} items and ${report.counts.recipes} versioned recipes.`);
  } else {
    if (!fs.existsSync(outputUrl) || fs.readFileSync(outputUrl, 'utf8') !== rendered ||
        !fs.existsSync(baseOutputUrl) || fs.readFileSync(baseOutputUrl, 'utf8') !== renderedBase ||
        !fs.existsSync(chapter5OutputUrl) || fs.readFileSync(chapter5OutputUrl, 'utf8') !== renderedChapter5) {
      console.error('Compiled content is missing or stale. Run with --write and review the diff.');
      process.exitCode = 1;
    } else console.log(`PASS: ${report.counts.items} items, ${report.counts.recipes} recipes, ${report.counts.packingRules} packing rules.`);
  }
}
