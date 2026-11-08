import fs from 'node:fs';
import { fileURLToPath } from 'node:url';


export function parseRecipes(markdown, spec) {
  const names = new Map(spec.items.map(item => [item.name, item.id]));
  for (const [name, id] of Object.entries(spec.aliases)) names.set(name, id);
  const recipes = [];
  let section = '';
  function terms(text) {
    return text.split('+').map(part => part.trim()).filter(Boolean).map(part => {
      const match = part.match(/^(.+?)\s+(\d+)$/);
      if (!match || !names.has(match[1])) throw new Error(`Unknown recipe term: ${part}`);
      return { item: names.get(match[1]), quantity: Number(match[2]) };
    });
  }
  for (const line of markdown.split('\n')) {
    const heading = line.match(/^### (\d+\.\d+) /);
    if (heading) section = heading[1];
    if (!['11.4', '12.3', '12.4', '13.1', '13.2'].includes(section)) continue;
    const cells = line.split('|').slice(1, -1).map(cell => cell.trim());
    const match = cells[0]?.match(/^`([a-z_]+)`/);
    if (!match || !cells[1]?.includes('→')) continue;
    const id = match[1];
    const phase = Number(cells[0].match(/／(\d)/)?.[1] ?? (id === 'distill_water' ? 5 : 4));
    const [left, right] = cells[1].split('→').map(text => text.trim());
    const inputText = left.split('；')[0]
      .replace(/（.*?）/g, '')
      .replace(/裝有(?:過濾水|開水)的清潔瓶／罐/g, '清潔瓶')
      .trim();
    let inputGroups;
    if (id === 'clean_food') {
      inputGroups = [
        terms('野菜 2 + 清潔瓶 1'),
        terms('可食拾得物 2 + 清潔瓶 1'),
      ];
    } else inputGroups = [terms(inputText)];
    if (id === 'boil_water') {
      inputGroups.push(
        inputGroups[0].map(input =>
          input.item === 'container.clean'
            ? { ...input, item: 'container.clean_jar' }
            : { ...input },
        ),
      );
    }
    if (['soup_basic', 'soup_vegetable', 'soup_fish'].includes(id)) {
      const mealBox = inputGroups[0]?.find(input => input.item === 'container.meal_box');
      if (mealBox) {
        inputGroups.push(inputGroups[0].map(input =>
          input.item === 'container.meal_box'
            ? { ...input, item: 'container.meal_box_insulated' }
            : { ...input },
        ));
      }
    }
    const stateEffect = spec.recipePolicies?.find(policy => policy.id === `ss.recipe.${id}`)?.stateEffect;
    let outputs = [];
    if (id !== 'wash_filter' &&
        (!['transformContainerContent', 'transformContainers', 'packObjects'].includes(stateEffect?.type) ||
         ['clean_food', 'shared_meal', 'mix_pulp'].includes(id))) {
      let outputText = right.replace(/（.*?）/g, '').trim();
      if (id === 'upgrade_bag' || id === 'weather_bag') outputText += ' 1';
      outputs = terms(outputText);
    }
    const tools = [];
    if (['unpick_cloth', 'sew_strip', 'patch_cloth', 'upgrade_bag', 'cut_filter', 'insulate_cloth', 'insulated_box'].includes(id)) tools.push('tool.needle');
    // The papermaking mould is a fixed workbench fixture, not an inventory
    // tool that players must place on the board for every paperboard craft.
    if (['filter_turbid', 'filter_dirty', 'wash_filter'].includes(id)) tools.push('material.filter_cloth');
    if (id === 'distill_water') tools.push('tool.condenser');
    if (id === 'upgrade_bag') tools.push('bag.basic');
    if (id === 'weather_bag') tools.push('bag.reinforced');
    if (id === 'mix_pulp') inputGroups.push(terms('紙屑 3 + 過濾水 1'));
    if (id === 'awl_bone') inputGroups.push(terms('金屬條 1 + 木條 1 + 綁帶 1'));
    if (id === 'clean_food') {
      inputGroups = inputGroups.flatMap(group => [
        group,
        group.map(input =>
          input.item === 'container.clean'
            ? { ...input, item: 'container.clean_jar' }
            : { ...input },
        ),
      ]);
    }
    if (id === 'shared_meal') {
      inputGroups.push(terms('清理食材 4 + 清潔瓶 1 + 乾燥燃料 2'));
      inputGroups = inputGroups.flatMap(group => [
        group,
        group.map(input =>
          input.item === 'container.clean'
            ? { ...input, item: 'container.clean_jar' }
            : { ...input },
        ),
      ]);
    }
    recipes.push({
      id: `ss.recipe.${id}`, phase, inputGroups, outputs, tools, section,
      operationText: cells[2] ?? '', failureOutcomeText: cells[3] ?? '',
      text: cells.slice(1).join(' | '),
    });
  }
  return recipes;
}

export function reachableAt(spec, recipes, phase) {
  const available = new Set([...spec.supplies, ...spec.seeds].filter(source => source.phase <= phase).map(source => source.item));
  let changed = true;
  while (changed) {
    changed = false;
    for (const recipe of recipes) {
      if (recipe.phase > phase || !recipe.tools.every(id => available.has(id))) continue;
      if (!recipe.inputGroups.some(group => group.every(input => available.has(input.item)))) continue;
      for (const output of recipe.outputs) {
        if (!available.has(output.item)) { available.add(output.item); changed = true; }
      }
      const stateEffect = spec.recipePolicies?.find(policy => policy.id === recipe.id)?.stateEffect;
      for (const item of [
        ...(stateEffect?.containers ?? []).map(container => container.successContentItemId),
        ...(stateEffect?.type === 'transformContainerContent' ? [stateEffect.toContentItemId] : []),
        ...(stateEffect?.type === 'transformObject' ? [stateEffect.toItemId] : []),
        ...(stateEffect?.type === 'packObjects' ? [stateEffect.toItemId] : []),
      ]) {
        if (item && !available.has(item)) {
          available.add(item);
          changed = true;
        }
      }
    }
    for (const bundle of spec.bundles) {
      if (available.has(bundle.input) && !available.has(bundle.output)) { available.add(bundle.output); changed = true; }
    }
  }
  return available;
}

export function audit(spec, recipes) {
  const errors = [];
  const ids = new Set();
  for (const item of spec.items) {
    if (ids.has(item.id)) errors.push(`Duplicate item: ${item.id}`);
    ids.add(item.id);
    if (!Number.isInteger(item.phase) || item.phase < 0 || item.phase > 5) errors.push(`Invalid item phase: ${item.id}`);
    if (item.location === 'grid') {
      if (!Array.isArray(item.footprint) || item.footprint.length !== 2 || !item.footprint.every(n => Number.isInteger(n) && n > 0 && n <= 4)) errors.push(`Invalid footprint: ${item.id}`);
    } else if (!['content', 'station', 'equipment', 'mailbox'].includes(item.location) || item.footprint !== null) errors.push(`Invalid non-grid location: ${item.id}`);
  }
  for (const source of [...spec.supplies, ...spec.seeds]) {
    if (!ids.has(source.item)) errors.push(`Unknown source item: ${source.item}`);
    if (!Number.isInteger(source.phase) || source.phase < 0 || source.phase > 5) errors.push(`Invalid source phase: ${source.item}`);
  }
  const recipeIds = new Set();
  for (const recipe of recipes) {
    if (recipeIds.has(recipe.id)) errors.push(`Duplicate recipe: ${recipe.id}`);
    recipeIds.add(recipe.id);
    if (!recipe.inputGroups.length || recipe.inputGroups.some(group => !group.length)) errors.push(`Empty input group: ${recipe.id}`);
    for (const entry of [...recipe.inputGroups.flat(), ...recipe.outputs]) {
      if (!ids.has(entry.item)) errors.push(`Unknown item ${entry.item} in ${recipe.id}`);
      if (!Number.isInteger(entry.quantity) || entry.quantity <= 0) errors.push(`Invalid quantity in ${recipe.id}`);
      if (entry.item.startsWith('bundle.')) errors.push(`Bundle cannot be crafting ingredient/output: ${recipe.id}`);
    }
    for (const tool of recipe.tools) if (!ids.has(tool)) errors.push(`Unknown tool ${tool} in ${recipe.id}`);
  }
  for (const bundle of spec.bundles) if (!ids.has(bundle.input) || !ids.has(bundle.output) ||
      !Array.isArray(bundle.inputItems ?? Array(bundle.count).fill(bundle.input)) ||
      (bundle.inputItems ?? Array(bundle.count).fill(bundle.input)).length !== bundle.count ||
      (bundle.inputItems ?? Array(bundle.count).fill(bundle.input)).some(itemId => !ids.has(itemId)) ||
      (bundle.count !== 4 && bundle.output !== 'toolpart.float' && bundle.output !== 'tool.cook_kit') ||
      !bundle.manualUnpack) errors.push(`Invalid bundle ${bundle.output}`);
  const policies = spec.recipePolicies ?? [];
  const policyIds = new Set();
  for (const policy of policies) {
    if (policyIds.has(policy.id)) errors.push(`Duplicate recipe policy: ${policy.id}`);
    policyIds.add(policy.id);
    const recipe = recipes.find(recipe => recipe.id === policy.id);
    if (!recipe) { errors.push(`Orphan recipe policy: ${policy.id}`); continue; }
    const inputs = new Set(recipe.inputGroups.flat().map(input => input.item));
    if (!policy.primaryInputs.every(id => inputs.has(id))) errors.push(`Non-input primary: ${policy.id}`);
    if (!policy.primaryInputs.length && policy.id !== 'ss.recipe.wash_filter') errors.push(`Missing primary: ${policy.id}`);
    if (!policy.retainedInputIdentities.every(id => inputs.has(id))) errors.push(`Non-input retained identity: ${policy.id}`);
    if (!['tutorial', 'recycler', 'dock', 'workbench', 'kitchen'].includes(policy.station)) errors.push(`Unknown station: ${policy.id}`);
    if (!['sew','align','strike','heat','mix','cut','wash','braid','coat','filter','cook','sort','assemble'].includes(policy.interaction)) errors.push(`Unknown interaction: ${policy.id}`);
    if (!['weighted-primary','capped-at-primary','preserve-primary'].includes(policy.qualityMode) || ![0,8].includes(policy.qualityLoss)) errors.push(`Invalid quality policy: ${policy.id}`);
    if (!Number.isInteger(policy.durationSeconds) || policy.durationSeconds < 1 || policy.durationSeconds > 20 ||
        !Number.isInteger(policy.masteryRevision) || policy.masteryRevision < 1) errors.push(`Invalid operation policy: ${policy.id}`);
  }
  for (const recipe of recipes) if (!policyIds.has(recipe.id)) errors.push(`Missing recipe policy: ${recipe.id}`);
  const phases = [];
  for (let phase = 0; phase <= 5; phase++) {
    const available = reachableAt(spec, recipes, phase);
    const locked = recipes.filter(recipe => recipe.phase === phase && (!recipe.tools.every(id => available.has(id)) || !recipe.inputGroups.some(group => group.every(input => available.has(input.item)))));
    for (const recipe of locked) errors.push(`Recipe unreachable at phase ${phase}: ${recipe.id}`);
    phases.push({ phase, reachableItems: available.size, newlyUnlockedRecipes: recipes.filter(recipe => recipe.phase === phase).length });
  }
  const allAvailable = reachableAt(spec, recipes, 5);
  // Failure meals are produced only by the documented failed-cooking branch.
  for (const item of spec.items) if (!allAvailable.has(item.id) && item.id !== 'meal.failed') errors.push(`No success-path source: ${item.id}`);
  const consumers = Object.fromEntries(spec.items.map(item => [item.id, []]));
  for (const recipe of recipes) {
    const stateEffect = spec.recipePolicies?.find(policy => policy.id === recipe.id)?.stateEffect;
    const containerItems = stateEffect?.containers?.flatMap(container =>
      [container.requiredContentItemId, container.successContentItemId, container.failureContentItemId].filter(Boolean),
    ) ?? [];
    for (const id of new Set([
      ...recipe.inputGroups.flat().map(input => input.item),
      ...recipe.tools,
      ...containerItems,
    ])) consumers[id]?.push(recipe.id);
  }
  for (const [id, description] of Object.entries(spec.terminalUses ?? {})) {
    if (!ids.has(id) || typeof description !== 'string' || description.trim().length === 0) errors.push(`Invalid terminal use: ${id}`);
  }
  for (const item of spec.items) if (!consumers[item.id].length && !spec.terminalUses?.[item.id]) errors.push(`No declared use: ${item.id}`);
  return { status: errors.length ? 'FAIL' : 'PASS', scope: 'Design-table parsing, identity, footprints and qualitative success-path phase reachability; not quantity balance, failure recovery, packing, runtime or player QA.', counts: { items: spec.items.length, recipes: recipes.length, bundles: spec.bundles.length }, phases, errors, consumers };
}

export function loadDesign() {
  const gamePackage = new URL('../', import.meta.url);
  const spec = JSON.parse(fs.readFileSync(new URL('design/street-scrap-design.json', gamePackage), 'utf8'));
  const recipePolicy = JSON.parse(fs.readFileSync(new URL('design/street-scrap-recipe-policy.json', gamePackage), 'utf8'));
  spec.recipePolicies = recipePolicy.policies;
  spec.defaultFailureResolution = recipePolicy.defaultFailureResolution;
  spec.manualCheckpointTemplates = recipePolicy.manualCheckpointTemplates;
  spec.qualityTraitRules = recipePolicy.qualityTraitRules;
  const markdown = fs.readFileSync(
    new URL('docs/third-game-design-plan.md', gamePackage),
    'utf8',
  );
  return { spec, recipes: parseRecipes(markdown, spec) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { spec, recipes } = loadDesign();
  const result = audit(spec, recipes);
  console.log(JSON.stringify(process.argv.includes('--full') ? result : { ...result, consumers: undefined }, null, 2));
  process.exitCode = result.errors.length ? 1 : 0;
}
