import assert from 'node:assert/strict';
import { readdir } from 'node:fs/promises';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const contentUrl = new URL(
  '../../resources/data/street-scrap-content-v1.json',
  import.meta.url,
);
const localizationUrl = new URL(
  '../../lib/src/street_scrap_localizations.dart',
  import.meta.url,
);

const content = JSON.parse(await readFile(contentUrl, 'utf8'));
const localizationSource = await readFile(localizationUrl, 'utf8');

function readNameMap(mapName) {
  const declaration = localizationSource.split(`${mapName} = {`)[1];
  assert.ok(declaration, `missing ${mapName}`);
  const body = declaration.split('\n  };')[0];
  return readDartStringMapBody(body);
}

function readDartStringMapBody(body) {
  const unescape = (value) => value.replace(/\\(['\\])/g, '$1');
  const entries = [
    ...body.matchAll(/'((?:\\.|[^'\\])*)'\s*:\s*'((?:\\.|[^'\\])*)'\s*,?/g),
  ].map((match) => [unescape(match[1]), unescape(match[2])]);
  return new Map(entries);
}

test('Street Scrap zh-Hant and English names cover every canonical item', () => {
  const expectedIds = new Set(content.itemDefinitions.map((item) => item.id));
  const traditionalChinese = readNameMap('_itemNamesZhHant');
  const english = readNameMap('_itemNamesEn');

  for (const [locale, names] of [
    ['zh-Hant', traditionalChinese],
    ['en', english],
  ]) {
    assert.equal(names.size, expectedIds.size, `${locale} entry count`);
    assert.deepEqual(
      [...names.keys()].filter((id) => !expectedIds.has(id)),
      [],
      `${locale} contains unknown IDs`,
    );
    assert.deepEqual(
      [...expectedIds].filter((id) => !names.has(id)),
      [],
      `${locale} is missing canonical IDs`,
    );
  }

  for (const item of content.itemDefinitions) {
    assert.equal(traditionalChinese.get(item.id), item.name, item.id);
    assert.notEqual(english.get(item.id), item.id, `English name missing: ${item.id}`);
  }
});

test('English recipe presentation covers every versioned operation string', () => {
  const mappings = [
    [
      '_operationInstructionsEn',
      content.recipes.map((recipe) => recipe.operation.instructions),
    ],
    [
      '_checkpointPromptsEn',
      content.recipes.flatMap((recipe) =>
        recipe.operation.manualCheckpoints.map((checkpoint) => checkpoint.prompt),
      ),
    ],
    [
      '_recipeFailureOutcomesEn',
      content.recipes.map((recipe) => recipe.failure.outcome),
    ],
    [
      '_recipeQualityModesEn',
      content.recipes.map((recipe) => recipe.quality.mode),
    ],
  ];

  for (const [mapName, rawValues] of mappings) {
    const translations = readNameMap(mapName);
    const expected = new Set(rawValues);
    const missing = [...expected].filter((value) => !translations.has(value));
    assert.deepEqual(missing, [], `${mapName} has untranslated content values`);
    for (const value of expected) {
      assert.notEqual(
        translations.get(value),
        value,
        `${mapName} falls back to source text: ${value}`,
      );
    }
  }
});


test('localized item names are used in inventory, order, and expedition surfaces', async () => {
  const ownerRoot = new URL('../../lib/src/', import.meta.url);
  for (const file of [
    'street_scrap_inventory_page.dart',
    'street_scrap_orders_panel.dart',
    'street_scrap_expedition_panel.dart',
  ]) {
    const source = await readFile(new URL(file, ownerRoot), 'utf8');
    assert.match(source, /itemName\(/, `${file} must display localized item names`);
  }
});

test('chapter 2 through 5 expedition tutorial checklist is bilingual and wired to task flags', async () => {
  const ownerRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const panel = await readFile(
    new URL('street_scrap_expedition_panel.dart', ownerRoot),
    'utf8',
  );
  const expected = [
    'phaseTwo', 'phaseThree', 'phaseFour', 'phaseFive',
    'castLine', 'landFish', 'chooseFishUse', 'pressRod', 'nailBoard',
    'repairTool', 'storeCrate', 'upgradeBagOptional', 'filterWater',
    'cookMeal', 'useOrDeliverMeal', 'advancedOrders', 'stableLiving',
  ];
  for (const suffix of expected) {
    const key = suffix.startsWith('phase')
      ? `expedition.${suffix}`
      : `expedition.task.${suffix}`;
    for (const mapName of ['_zhHant', '_en']) {
      const body = localizationSource
        .split(`static const Map<String, String> ${mapName} = {`)[1]
        ?.split('\n  };')[0];
      assert.ok(body?.includes(`'${key}':`), `${mapName} missing ${key}`);
    }
    assert.ok(panel.includes(`strings.text('${key}')`), `panel does not use ${key}`);
  }
  for (const [chapter, tasks] of [
    [2, ['q2.01', 'q2.02', 'q2.03']],
    [3, ['q3.01', 'q3.02', 'q3.03', 'q3.04', 'q3.05']],
    [4, ['q4.01', 'q4.02', 'q4.03']],
    [5, ['q5.01', 'q5.02']],
  ]) {
    assert.ok(panel.includes(`if (chapter >= ${chapter})`), `chapter ${chapter} gate missing`);
    for (const task of tasks) {
      assert.ok(panel.includes(`'${task}'`), `${task} task row missing`);
    }
  }
});

test('malformed order progress fallback can build dynamic localized text safely', async () => {
  const source = await readFile(
    new URL(
      '../../lib/src/street_scrap_orders_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const fallback = source.match(
    /if \(tasks != null && tasks is! Map\) \{([\s\S]*?)\n    \}/,
  );
  assert.ok(fallback, 'malformed task state has an early fallback');
  assert.match(fallback[1], /return Card\(/);
  assert.doesNotMatch(fallback[1], /return const Card\(/);
  assert.match(fallback[1], /strings\.text\('orders\.error\.tutorialStateMalformed'\)/);
  assert.doesNotMatch(fallback[1], /apply\(|compareAndSwap|snapshot\.revision/);
});

test('Street Scrap source has no localized values nested under const widgets', async () => {
  const sourceDirectory = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const files = (await readdir(sourceDirectory)).filter((name) => name.endsWith('.dart'));
  for (const file of files) {
    const source = await readFile(new URL(file, sourceDirectory), 'utf8');
    const invalid = source.matchAll(
      /const\s+(?:Card|Padding|Text|ListTile|AlertDialog|Column|Row|Container|Semantics)\s*\([\s\S]{0,400}?\bstrings\.(?:text|itemName|itemQuality|fishingSpotName)\s*\(/g,
    );
    for (const match of invalid) {
      assert.fail(`${file} has dynamic localized content in a const widget: ${match[0]}`);
    }
  }
});

test('fishing panel maps every domain failure to friendly bilingual copy', async () => {
  const ownerRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const panel = await readFile(new URL('street_scrap_fishing_panel.dart', ownerRoot), 'utf8');
  const domain = await readFile(new URL('street_scrap_fishing.dart', ownerRoot), 'utf8');
  assert.doesNotMatch(panel, /_error\s*=\s*error\.toString\(\)/);
  const errorHandler = panel.split('String _friendlyError(Object error) {')[1]?.split('\n  }')[0];
  assert.ok(errorHandler, 'friendly fishing error handler exists');
  const codes = [...domain.matchAll(/throw StateError\('([^']+)'\)/g)].map((match) => match[1]);
  for (const code of codes) {
    assert.ok(errorHandler.includes(`'${code}'`), `fishing error ${code} needs a friendly mapping`);
  }
  const keys = [...errorHandler.matchAll(/'fishing\.error\.[^']+'/g)].map((match) => match[0].slice(1, -1));
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    for (const key of keys) assert.ok(body?.includes(`'${key}':`), `${mapName} missing ${key}`);
  }
});

test('fishing progress localizes known and unknown spot IDs before display', async () => {
  const ownerRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const panel = await readFile(new URL('street_scrap_fishing_panel.dart', ownerRoot), 'utf8');
  assert.match(panel, /String _spotLabel\(StreetScrapLocalizations strings, Object\? rawSpotId\)/);
  assert.match(panel, /strings\.fishingSpotName\(spotId, spot\.name\)/);
  assert.match(panel, /strings\.text\('fishing\.spot\.unknown'\)/);
  assert.match(panel, /_spotLabel\(strings, activity\['spotId'\]\)/);
  assert.doesNotMatch(panel, /arguments:\s*\{'spot':\s*'\$\{activity\['spotId'\]\}'\}/);
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body?.includes("'fishing.spot.unknown':"), `${mapName} missing unknown fishing spot label`);
    assert.ok(body?.includes("'fishing.progress':"), `${mapName} missing fishing progress label`);
  }
});

test('remaining Street Scrap operation failures never render raw exception details', async () => {
  const sourceRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const [orders, expedition, relief, woodworking] = await Promise.all(
    [
      'street_scrap_orders_panel.dart',
      'street_scrap_expedition_panel.dart',
      'street_scrap_relief_panel.dart',
      'street_scrap_woodworking_panel.dart',
    ].map((file) => readFile(new URL(file, sourceRoot), 'utf8')),
  );
  assert.doesNotMatch(orders, /arguments: \{'message': message\}/);
  assert.doesNotMatch(expedition, /arguments: \{'message': message\}/);
  assert.doesNotMatch(relief, /arguments: \{'details': '\$error'\}/);
  assert.match(woodworking, /_ => strings\.text\('game\.errorOperationFailed'\)/);
  for (const key of [
    'water.errorOperationFailed',
    'game.errorOperationFailed',
    'expedition.error.operationFailed',
    'relief.claimFailed',
    'relief.supplyFailed',
    'relief.stopFailed',
  ]) {
    assert.ok(
      [...localizationSource.matchAll(new RegExp(`'${key}':`, 'g'))].length >= 2,
      `both locale catalogs must define ${key}`,
    );
  }
});

test('progress entry loading failures use localized recovery advice without exception text', async () => {
  const sourceRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const page = await readFile(
    new URL('street_scrap_progress_entry_page.dart', sourceRoot),
    'utf8',
  );
  assert.match(page, /strings\.text\('entry\.saveLoadAdvice'\)/);
  assert.match(page, /strings\.text\('entry\.contentLoadAdvice'\)/);
  assert.doesNotMatch(page, /\$_loadError|\$_contentLoadError/);
  for (const key of [
    'entry.saveLoadAdvice',
    'entry.contentLoadAdvice',
  ]) {
    assert.equal(
      [...localizationSource.matchAll(new RegExp(`'${key}':`, 'g'))].length,
      2,
      `both locale catalogs must define ${key}`,
    );
  }
});

test('mineral-water vessel choices identify items without exposing instance IDs', async () => {
  const panel = await readFile(
    new URL(
      '../../lib/src/street_scrap_expedition_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const zh = readNameMap('_zhHant');
  const en = readNameMap('_en');
  assert.match(panel, /'expedition\.vesselOption'[\s\S]*?strings\.itemName\(vessel\.itemId\)/);
  assert.match(panel, /'expedition\.vesselOption'[\s\S]*?strings\.itemSource\(vessel\.source\)/);
  const choice = panel
    .split("'expedition.vesselOption'")[1]
    ?.split('onTap: () => Navigator.pop(context, vessel.instanceId)')[0];
  assert.ok(choice, 'vessel choice must keep its internal ID only as the selection value');
  assert.doesNotMatch(choice, /vessel\.instanceId/);
  assert.equal(zh.get('expedition.vesselOption'), '{item}・{source}・第 {number} 件');
  assert.equal(en.get('expedition.vesselOption'), '{item} · {source} · item {number}');
});

test('every literal localization key used by the Street Scrap package exists in both catalogs', async () => {
  const sourceRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const files = (await readdir(sourceRoot, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && entry.name.endsWith('.dart') &&
      entry.name !== 'street_scrap_localizations.dart')
    .map((entry) => entry.name);
  const sources = await Promise.all(
    files.map((file) => readFile(new URL(file, sourceRoot), 'utf8')),
  );
  const recyclingDomain = await readFile(
    new URL(
      '../../lib/src/street_scrap_expedition.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const usedKeys = new Set(
    sources.flatMap((source) =>
      [...source.matchAll(/\.text\(\s*'([^']+)'/g)]
        .map((match) => match[1])
        .filter((key) => !key.includes('$')),
    ),
  );
  const zhStart = localizationSource.indexOf('_zhHant = {');
  const enStart = localizationSource.indexOf('_en = {');
  const textMethodStart = localizationSource.indexOf('  String text(');
  const zhCatalog = localizationSource.slice(zhStart, enStart);
  const enCatalog = localizationSource.slice(enStart, textMethodStart);
  const missingZh = [...usedKeys].filter((key) => !zhCatalog.includes(`'${key}':`));
  const missingEn = [...usedKeys].filter((key) => !enCatalog.includes(`'${key}':`));
  assert.deepEqual(missingZh, [], `keys missing from zh-Hant: ${missingZh.join(', ')}`);
  assert.deepEqual(missingEn, [], `keys missing from English: ${missingEn.join(', ')}`);
  const categoryBlock = recyclingDomain
    .split('const streetScrapRecyclingCategories = <String, String>{')[1]
    ?.split('\n};')[0];
  assert.ok(categoryBlock, 'recycling categories must have a canonical source');
  const categories = [...categoryBlock.matchAll(/'([^']+)':/g)].map(
    (match) => match[1],
  );
  for (const category of categories) {
    const key = `expedition.recyclingCategory.${category}`;
    assert.ok(zhCatalog.includes(`'${key}':`), `keys missing from zh-Hant: ${key}`);
    assert.ok(enCatalog.includes(`'${key}':`), `keys missing from English: ${key}`);
  }
});

test('player-facing widgets do not hardcode Chinese text outside the game catalogs', async () => {
  const sourceRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const files = (await readdir(sourceRoot, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && entry.name.endsWith('.dart') &&
      entry.name !== 'street_scrap_localizations.dart')
    .map((entry) => entry.name);
  const violations = [];
  for (const file of files) {
    const source = await readFile(new URL(file, sourceRoot), 'utf8');
    const patterns = [
      ['Text', /\bText\s*\(\s*(['"])([^'"\n]*[\u3400-\u9fff][^'"\n]*)\1/g],
      ['Semantics.label', /\bSemantics\s*\([\s\S]*?\blabel\s*:\s*(['"])([^'"\n]*[\u3400-\u9fff][^'"\n]*)\1/g],
      ['Tooltip.message', /\bTooltip\s*\([\s\S]*?\bmessage\s*:\s*(['"])([^'"\n]*[\u3400-\u9fff][^'"\n]*)\1/g],
    ];
    for (const [surface, pattern] of patterns) {
      for (const match of source.matchAll(pattern)) {
        const line = source.slice(0, match.index).split('\n').length;
        violations.push(`${file}:${line} ${surface}: ${match[2]}`);
      }
    }
  }
  assert.deepEqual(violations, [],
    `player-facing Chinese literals must be localized: ${violations.join('; ')}`);
});

test('order item choices hide internal instance IDs and show localized quality labels', async () => {
  const source = await readFile(
    new URL(
      '../../lib/src/street_scrap_orders_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body?.includes("'orders.itemOption':"), `${mapName} item option label`);
    assert.ok(body?.includes("'orders.containerOption':"), `${mapName} container option label`);
  }
  assert.equal((source.match(/'orders\.itemOption'/g) ?? []).length, 1);
  assert.equal((source.match(/'orders\.containerOption'/g) ?? []).length, 2);
  assert.match(source, /'quality': strings\.itemQuality\(item\.quality\)/);
  assert.match(source, /strings\.itemName\(contentItemId\)/);
  assert.match(source, /'quality': strings\.itemQuality\(contentQuality\)/);
  assert.doesNotMatch(source, /title: Text\(\s*'\$\{strings\.itemName\(item\.itemId\)\}・\$\{item\.instanceId\}'/);
});

test('maintenance, repair, water, and chapter-five choices render localized item labels', async () => {
  const ownerRoot = new URL(
    '../../lib/src/',
    import.meta.url,
  );
  const inventoryPage = await readFile(
    new URL('street_scrap_inventory_page.dart', ownerRoot),
    'utf8',
  );
  const woodworking = await readFile(
    new URL('street_scrap_woodworking_panel.dart', ownerRoot),
    'utf8',
  );
  assert.match(inventoryPage, /'maintenance\.quality',[\s\S]{0,180}strings\.itemName\(item\.itemId\)/);
  assert.match(inventoryPage, /'maintenance\.vesselQuality',[\s\S]{0,180}strings\.itemName\(item\.itemId\)/);
  assert.match(inventoryPage, /'craft\.dialog\.materialsOnOtherGrid'/);
  assert.match(inventoryPage, /'craft\.dialog\.materialsNotOnBoard'/);
  assert.match(inventoryPage, /'street-scrap-craft-open-other-grid'/);
  assert.doesNotMatch(inventoryPage, /'craft\.dialog\.objectId'/);
  assert.match(
    woodworking,
    /title: Text\(strings\.itemName\(item\.itemId\)\),[\s\S]{0,180}subtitle: Text\(\s*strings\.itemQuality\(item\.quality\)/,
  );
  assert.match(woodworking, /'water\.vessel',[\s\S]{0,240}strings\.itemName\(item\.itemId\)/);
  assert.match(woodworking, /strings\.itemName\(\s*item\.containerState\['contentItemId'\]\s+as String\s*,?\s*\)/);
  assert.match(woodworking, /strings\.itemQuality\(item\.containerState\['contentQuality'\]\s+as int\)/);
  assert.match(woodworking, /'water\.target',[\s\S]{0,120}strings\.itemName\(item\.itemId\)/);
  assert.match(woodworking, /'woodwork\.chapter5ShelterItem',[\s\S]{0,180}strings\.itemName\(item\.itemId\)/);
  assert.match(woodworking, /'woodwork\.chapter5ChestItem',[\s\S]{0,150}strings\.itemName\(item\.itemId\)/);
  assert.match(woodworking, /text\('water\.confirmDiscardBody'\)/);
});

test('every canonical recipe checkpoint prompt is localized and used by the UI', async () => {
  const prompts = new Set(
    content.recipes.flatMap((recipe) =>
      (recipe.operation?.manualCheckpoints ?? []).map((checkpoint) => checkpoint.prompt),
    ),
  );
  const maintenanceSource = await readFile(
    new URL(
      '../../lib/src/street_scrap_maintenance.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const maintenancePrompts = new Set(
    [...maintenanceSource.matchAll(/prompts: \[([^\]]+)\]/g)].flatMap((match) =>
      [...match[1].matchAll(/'([^']+)'/g)].map((prompt) => prompt[1]),
    ),
  );
  for (const prompt of maintenancePrompts) prompts.add(prompt);
  const mapBody = localizationSource
    .split('static const Map<String, String> _checkpointPromptsEn = {')[1]
    ?.split('\n  };')[0];
  assert.ok(mapBody, 'English checkpoint prompt translations must be declared');
  const translations = readDartStringMapBody(mapBody);
  assert.equal(translations.size, prompts.size, 'translation map must match canonical prompts');
  for (const prompt of prompts) {
    assert.ok(translations.has(prompt), `English translation missing: ${prompt}`);
    assert.notEqual(translations.get(prompt), prompt, `prompt was not translated: ${prompt}`);
  }
  assert.match(localizationSource, /String checkpointPrompt\(String prompt\)/);

  const inventoryPage = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(inventoryPage, /checkpointPrompt\(checkpoint\.prompt\)/);
});

test('all canonical recipe operation summaries are translated and used at the UI boundary', async () => {
  const instructions = new Set(
    content.recipes.map((recipe) => recipe.operation.instructions),
  );
  const mapBody = localizationSource
    .split('static const Map<String, String> _operationInstructionsEn = {')[1]
    ?.split('\n  };')[0];
  assert.ok(mapBody, 'English operation-instruction translations must be declared');
  const translations = readDartStringMapBody(mapBody);
  assert.equal(translations.size, 78, 'translation map must match canonical instruction summaries');
  assert.equal(translations.size, instructions.size, 'translation map must match canonical instruction summaries');
  for (const instruction of instructions) {
    assert.ok(translations.has(instruction), `English translation missing: ${instruction}`);
    assert.notEqual(translations.get(instruction), instruction, `instruction was not translated: ${instruction}`);
  }
  assert.match(localizationSource, /String operationInstructions\(String instructions\)/);

  const inventoryPage = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(
    inventoryPage,
    /strings\.operationInstructions\(\s*recipe\.instructions\s*,?\s*\)/,
  );
});

test('recipe detail localizes station names, item quantities, alternatives, and reusable tools', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const localization = localizationSource;
  const catalogs = Object.fromEntries(
    ['_zhHant', '_en'].map((mapName) => {
      const body = localization
        .split(`static const Map<String, String> ${mapName} = {`)[1]
        ?.split('\n  };')[0];
      assert.ok(body, `missing ${mapName}`);
      return [mapName, body];
    }),
  );
  const stations = new Set(content.recipes.map((recipe) => recipe.station));
  for (const station of stations) {
    const key = `recipe.station.${station}`;
    for (const [locale, body] of Object.entries(catalogs)) {
      assert.ok(body.includes(`'${key}':`), `${locale} missing ${key}`);
    }
  }
  for (const key of [
    'recipe.itemQuantity',
    'recipe.inputSeparator',
    'recipe.alternativeSeparator',
    'recipe.itemSeparator',
  ]) {
    for (const [locale, body] of Object.entries(catalogs)) {
      assert.ok(body.includes(`'${key}':`), `${locale} missing ${key}`);
    }
  }
  assert.match(localization, /String stationName\(String stationId\)/);
  assert.match(page, /strings\.stationName\(recipe\.station\)/);
  assert.match(page, /strings\.operationInstructions\(\s*recipe\.instructions\s*,?\s*\)/);
  assert.match(page, /recipe\.alternativeSeparator/);
  assert.match(page, /recipe\.itemSeparator/);
});

test('recipe quality modes and every canonical failure outcome are localized', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const failureOutcomes = new Set(content.recipes.map((recipe) => recipe.failure.outcome));
  const qualityModes = new Set(content.recipes.map((recipe) => recipe.quality.mode));
  const failures = readNameMap('_recipeFailureOutcomesEn');
  const modes = readNameMap('_recipeQualityModesEn');

  assert.equal(failures.size, failureOutcomes.size, 'failure translation map must match canonical outcomes');
  assert.equal(modes.size, qualityModes.size, 'quality-mode translation map must match canonical modes');
  for (const outcome of failureOutcomes) {
    assert.ok(failures.has(outcome), `English failure outcome missing: ${outcome}`);
    assert.notEqual(failures.get(outcome), outcome, `failure outcome was not translated: ${outcome}`);
  }
  for (const mode of qualityModes) {
    assert.ok(modes.has(mode), `English quality mode missing: ${mode}`);
    assert.notEqual(modes.get(mode), mode, `quality mode was not translated: ${mode}`);
  }
  assert.match(localizationSource, /String recipeFailureOutcome\(String outcome\)/);
  assert.match(localizationSource, /String recipeQualityMode\(String mode\)/);
  assert.match(page, /strings\.recipeFailureOutcome\(\s*recipe\.failureOutcome\s*,?\s*\)/);
  assert.match(
    page,
    /strings\.recipeQualityMode\(\s*recipe\.quality\.mode\s*,?\s*\)/,
  );
});

test('inventory recovery, checkpoint controls, and fishing spot names use localized copy', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const fishingPanel = await readFile(
    new URL(
      '../../lib/src/street_scrap_fishing_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const requiredKeys = [
    'common.dismiss',
    'checkpoint.leftZone',
    'checkpoint.promptZone',
    'checkpoint.rightZone',
    'relief.clockSaveError',
    'fishing.spot.dockEntrance',
  ];
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body, `missing ${mapName}`);
    for (const key of requiredKeys) {
      assert.ok(body.includes(`'${key}':`), `${mapName} missing ${key}`);
    }
  }
  assert.match(page, /strings\.text\('common\.dismiss'\)/);
  assert.match(page, /strings\.text\('checkpoint\.leftZone'\)/);
  assert.match(page, /strings\.text\('checkpoint\.promptZone'\)/);
  assert.match(page, /strings\.text\('checkpoint\.rightZone'\)/);
  assert.match(page, /\.text\('relief\.clockSaveError'\)/);
  assert.doesNotMatch(page, /救助時鐘保存失敗：\$error/);
  assert.match(fishingPanel, /strings\.fishingSpotName\(spot\.id, spot\.name\)/);
});

test('the low-frequency return summary localizes every saved-progress highlight', async () => {
  const summaryUrl = new URL(
    '../../lib/src/street_scrap_return_summary.dart',
    import.meta.url,
  );
  const summary = await readFile(summaryUrl, 'utf8');
  const requiredKeys = [
    'return.title',
    'return.savedAt',
    'return.chapter',
    'return.craftPending',
    'return.expeditionReturned',
    'return.expeditionActive',
    'return.fishingPending',
    'return.fishingActive',
    'return.reliefAvailable',
    'return.reliefMalformed',
    'return.stamina',
  ];

  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body, `missing ${mapName}`);
    for (const key of requiredKeys) {
      assert.ok(body.includes(`'${key}':`), `${mapName} missing ${key}`);
    }
  }
  for (const key of requiredKeys) {
    assert.ok(summary.includes(`'${key}'`), `return summary does not consume ${key}`);
  }
  assert.match(summary, /materialLocalizations\.formatMediumDate\(savedAt\)/);
  assert.match(summary, /materialLocalizations\.formatTimeOfDay\(/);
  assert.doesNotMatch(summary, /[一-龥]/, 'visible copy should come from the locale catalogs');
  assert.doesNotMatch(summary, /session\.(?:execute|commit|save)/);
});

test('expedition reward subtitles translate canonical fixed and surprise sources', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_expedition_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const fixedLocations = content.scavenging.fixedLocations.map(
    (location) => location.id,
  );
  const surpriseCategories = Object.keys(content.scavenging.surpriseWeights);
  const requiredKeys = [
    ...fixedLocations.map((id) => `expedition.rewardSource.fixed.${id}`),
    ...surpriseCategories.map((category) => `expedition.rewardSource.surprise.${category}`),
    'expedition.rewardSource.fixedGeneric',
    'expedition.rewardSource.surpriseGeneric',
    'expedition.rewardSource.other',
  ];

  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body, `missing ${mapName}`);
    for (const key of requiredKeys) {
      assert.ok(body.includes(`'${key}':`), `${mapName} missing ${key}`);
    }
  }
  assert.match(localizationSource, /String expeditionRewardSource\(String source\)/);
  assert.match(page, /strings\.expeditionRewardSource\(/);
  assert.doesNotMatch(page, /'source': '\$\{reward\['source'\]\}'/);
});

test('trait-maintenance supply and outcome UI uses both locale catalogs', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const requiredKeys = [
    'maintenance.title.threadRepair',
    'maintenance.title.drying',
    'maintenance.title.rustRemoval',
    'maintenance.title.heatReshape',
    'maintenance.title.fuelRedrying',
    'maintenance.title.boardAlignment',
    'maintenance.errorChapter',
    'maintenance.errorMalformed',
    'maintenance.errorAux',
    'maintenance.errorAuxWater',
    'maintenance.prepare',
    'maintenance.cost',
    'maintenance.quality',
    'maintenance.vesselQuality',
    'maintenance.vesselLabel',
    'maintenance.later',
    'maintenance.start',
    'maintenance.complete',
    'maintenance.missed',
    'maintenance.waterCost',
    'maintenance.vesselNote',
  ];
  const zh = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const en = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const key of requiredKeys) {
    assert.match(zh, new RegExp(`'${key}':`), `zh-Hant missing ${key}`);
    assert.match(en, new RegExp(`'${key}':`), `English missing ${key}`);
    if (!key.startsWith('maintenance.title.')) {
      assert.match(page, new RegExp(`'${key}'`), `UI does not consume ${key}`);
    }
  }
  for (const title of [
    '補線修整',
    '乾燥處理',
    '擦拭去鏽',
    '重新熱整',
    '重新乾燥燃料',
    '重新定位木板',
  ]) {
    assert.ok(localizationSource.includes(`'${title}' =>`), `title not localized: ${title}`);
  }

  const helper = page.split('String _friendlyCraftError(Object error) {')[1]?.split('\n  Future<void> _showRecipes')[0];
  assert.ok(helper, 'craft error presentation helper must exist');
  assert.match(helper, /strings\.text\(key \?\? 'craft\.error\.generic'\)/);
  assert.doesNotMatch(helper, /arguments:|details/);
  assert.doesNotMatch(page, /'settings\.saveFailed',[\s\S]{0,100}details/);
  const localizedErrorKeys = new Set(
    [...helper.matchAll(/=>\s*'(craft\.error\.[^']+)'/g)].map((match) => match[1]),
  );
  assert.ok(localizedErrorKeys.size >= 20, 'craft and maintenance errors must be localized');
  for (const key of localizedErrorKeys) {
    assert.match(zh, new RegExp(`'${key}':`), `zh-Hant missing ${key}`);
    assert.match(en, new RegExp(`'${key}':`), `English missing ${key}`);
  }
  assert.match(page, /StreetScrapLocalizations\.of\([\s\S]*?\)\.maintenanceTitle\(maintenance\.title\)/);
});

test('recipe material selection dialog and craft feedback use both locale catalogs', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const requiredKeys = [
    'craft.dialog.title',
    'craft.dialog.instruction',
    'craft.dialog.materialPlan',
    'craft.dialog.materialQuality',
    'craft.dialog.materialsOnOtherGrid',
    'craft.dialog.materialsNotOnBoard',
    'craft.dialog.organizeOtherGrid',
    'craft.dialog.selectedCount',
    'craft.dialog.retainedTools',
    'craft.dialog.toolDurabilityUnknown',
    'craft.dialog.toolDurability',
    'craft.dialog.cancel',
    'craft.dialog.confirmComplete',
    'craft.dialog.quickCraft',
    'craft.dialog.startManual',
    'craft.dialog.manualUnavailable',
    'craft.dialog.traitEffect',
    'recipe.detailInfo',
    'craft.result.success',
    'craft.result.missed',
    'craft.error.recipeVersionUnavailable',
    'craft.error.operationIncompatible',
    'craft.error.operationMalformed',
    'craft.error.operationHasExtraSteps',
  ];
  const zh = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const en = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const key of requiredKeys) {
    assert.ok(zh.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(en.includes(`'${key}':`), `English missing ${key}`);
    assert.ok(page.includes(`'${key}'`), `craft UI does not consume ${key}`);
  }
  assert.match(page, /strings\.itemSource\(source\)/);
});

test('recipe indexes and material-use results do not expose recipe IDs', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const zh = readNameMap('_zhHant');
  const enCatalog = readNameMap('_en');
  const operationIds = new Set(content.recipes.map((recipe) => recipe.operation.id));
  for (const operationId of operationIds) {
    const key = `recipes.action.${operationId}`;
    assert.ok(zh.has(key), `zh-Hant missing ${key}`);
    assert.ok(enCatalog.has(key), `English missing ${key}`);
    assert.notEqual(enCatalog.get(key), key, `English action is untranslated: ${key}`);
  }
  for (const key of [
    'recipes.title.withOutput',
    'recipes.title.inputOnly',
    'recipes.title.actionOnly',
  ]) {
    assert.ok(zh.has(key), `zh-Hant missing ${key}`);
    assert.ok(enCatalog.has(key), `English missing ${key}`);
  }
  assert.match(page, /String _recipeDisplayName\(/);
  assert.match(page, /successContentItemId/);
  assert.match(page, /strings\.recipeDisplayName\(/);
  assert.doesNotMatch(page, /title:\s*Text\(recipe\.id\)/);
  assert.doesNotMatch(page, /\.map\(\(recipe\)\s*=>\s*recipe\.id\)/);
  assert.ok(
    (page.match(/_recipeDisplayName\(strings, recipe\)/g) ?? []).length >= 4,
    'known recipes, recipe index, and material-use lists should share localized titles',
  );
});

test('recipe prerequisite and lock explanations are localized at every inventory surface', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const requiredKeys = [
    'recipe.questPrerequisite.filletFish',
    'recipe.questPrerequisite.pressRod',
    'recipe.questPrerequisite.nailBoard',
    'recipe.questPrerequisite.woodenCrate',
    'recipe.questPrerequisite.upgradeBag',
    'recipe.questPrerequisite.joinThread',
    'recipe.questPrerequisite.sewStrip',
    'recipes.questLocked',
    'recipeIndex.questLock',
    'craft.error.questLocked',
    'craft.error.chapterProgressInvalid',
    'craft.error.stationLocked',
    'craft.error.phaseLocked',
  ];
  const zh = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const en = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const key of requiredKeys) {
    assert.ok(zh.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(en.includes(`'${key}':`), `English missing ${key}`);
    assert.ok(page.includes(`'${key}'`), `inventory UI does not consume ${key}`);
  }
  assert.match(page, /String\? _questLockReasonKey\(StreetScrapRecipe recipe\)/);
  assert.match(page, /strings\.text\(questLockReasonKey\)/);
  assert.doesNotMatch(page, /\$questLockReason後才能使用此配方/);
});

test('inventory organization, packing, storage, and movement feedback use both locale catalogs', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const requiredKeys = [
    'board.moved',
    'board.undoMove',
    'board.rotate',
    'board.clearSelection',
    'board.packCount',
    'board.unpackBundle',
    'board.pendingItems',
    'board.pendingItemsEmpty',
    'board.homeStorage',
    'board.storageItem',
    'board.instructionUnselected',
    'board.instructionSelected',
    'board.error.craftLocked',
    'board.error.noSpace',
    'board.error.invalidPlacement',
    'board.error.saveFailed',
    'board.ownerLocation',
    'board.ownerStorage',
    'board.ownerPending',
    'packing.title',
    'packing.contents',
    'packing.itemDetails',
    'packing.identity',
    'packing.cancel',
    'packing.confirm',
  ];
  const zh = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const en = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const key of requiredKeys) {
    assert.ok(zh.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(en.includes(`'${key}':`), `English missing ${key}`);
    assert.ok(page.includes(`'${key}'`), `inventory UI does not consume ${key}`);
  }
  assert.match(page, /strings\.itemSource\(item\.source\)/);
  assert.match(page, /strings\.itemQuality\(item\.quality\)/);
  assert.match(page, /strings\.itemName\(rule\.inputItemId\)/);
  assert.match(page, /strings\.itemName\(rule\.outputItemId\)/);
});

test('localization catalogs contain no duplicate keys', () => {
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body, `missing ${mapName}`);
    const keys = [...body.matchAll(/^\s*'([^']+)':/gm)].map((match) => match[1]);
    assert.equal(new Set(keys).size, keys.length, `${mapName} has duplicate keys`);
  }
});

test('crate and chapter-five storage failures use localized woodworking copy', async () => {
  const panel = await readFile(
    new URL(
      '../../lib/src/street_scrap_woodworking_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const keys = [
    'woodwork.openRecipes',
    'woodwork.errorCrateUncrafted',
    'woodwork.errorCrateUnplaced',
    'woodwork.errorChapterFiveStructuresMissing',
    'woodwork.errorNoChapterFiveStorageItem',
    'woodwork.errorChapterFiveChestEmpty',
    'woodwork.errorNoCrateStorageItem',
  ];
  const zh = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const en = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const key of keys) {
    assert.match(zh, new RegExp(`'${key}':`), `zh-Hant missing ${key}`);
    assert.match(en, new RegExp(`'${key}':`), `English missing ${key}`);
    assert.match(panel, new RegExp(`'${key}'`), `woodworking UI does not consume ${key}`);
  }
});

test('malformed expedition state is caught by the panel and leaves save untouched', async () => {
  const panel = await readFile(
    new URL(
      '../../lib/src/street_scrap_expedition_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(panel, /return _buildPanel\(context\);\s*\} on FormatException/);
  assert.match(panel, /expedition\.error\.malformedSave/);
  assert.match(localizationSource, /'expedition\.error\.malformedSave':/);
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body?.includes("'expedition.error.malformedSave':"));
  }
});

test('inventory save parsing is guarded before automatic relief initialization', async () => {
  const page = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(page, /final page = _buildPage\(context\);[\s\S]*?\} on FormatException/);
  assert.match(page, /game\.error\.malformedSave/);
  const reservationParser = page
    .split('Set<String> get _lockedCraftIds {')[1]
    ?.split('\n  }')[0];
  assert.ok(reservationParser, 'craft reservations must have a dedicated parser');
  assert.match(reservationParser, /throw const FormatException/);
  assert.doesNotMatch(reservationParser, /__invalid_craft_reservation__/);
  assert.match(
    page,
    /addPostFrameCallback\(\(_\) \{\s*if \(mounted\) unawaited\(_initializeReliefClock\(\)\);/,
  );
  assert.doesNotMatch(page.split('void initState()')[1].split('void dispose()')[0], /_initializeReliefClock/);
  for (const mapName of ['_zhHant', '_en']) {
    const body = localizationSource
      .split(`static const Map<String, String> ${mapName} = {`)[1]
      ?.split('\n  };')[0];
    assert.ok(body?.includes("'game.error.malformedSave':"));
  }
});

test('board semantics localize cell state, item source, quality, and controls', async () => {
  const inventoryPage = await readFile(
    new URL(
      '../../lib/src/street_scrap_inventory_page.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const spriteSource = await readFile(
    new URL(
      '../../lib/src/street_scrap_item_sprite.dart',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(localizationSource, /'board\.cellSemantics'/);
  assert.match(localizationSource, /'board\.objectSemantics'/);
  assert.match(localizationSource, /String itemSource\(/);
  assert.match(localizationSource, /String itemQuality\(/);
  assert.match(inventoryPage, /strings\.text\(\s*'board\.cellSemantics'/);
  assert.match(inventoryPage, /'board\.objectSemantics'/);
  assert.match(inventoryPage, /strings\.itemSource\(item\.source\)/);
  assert.match(inventoryPage, /strings\.itemQuality\(item\.quality\)/);
  assert.match(spriteSource, /strings\.itemName\(itemId\)/);
  assert.match(spriteSource, /strings\.itemSource\(source\)/);
  assert.match(spriteSource, /strings\.itemName\(contentItemId!\)/);
  assert.match(spriteSource, /board\.spriteSemanticsWithContents/);
  assert.doesNotMatch(spriteSource, /'加工來源'|'原生／拾得來源'|'內容：/);

  const traditionalChinese = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const english = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const key of [
    'board.cellSemantics',
    'board.cellHint',
    'board.objectSemantics',
    'board.objectHint',
    'board.itemSemantics',
    'board.itemSourceFound',
    'board.itemSourceCrafted',
    'board.spriteSemantics',
    'board.spriteSemanticsWithContents',
    'board.itemQuality',
    'board.qualityPoor',
    'board.qualityOrdinary',
    'board.qualityGood',
    'board.qualityExcellent',
  ]) {
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
  }
});

test('material trait names and effects are localized in both supported locales', async () => {
  const traitSource = await readFile(
    new URL(
      '../../lib/src/street_scrap_trait_presentation.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const idsBlock = traitSource.split('static const _ids = {')[1]?.split('};')[0];
  assert.ok(idsBlock, 'trait presentation must declare canonical trait IDs');
  const ids = [...idsBlock.matchAll(/'([^']+)'/g)].map((match) => match[1]);
  assert.equal(ids.length, 17, 'expected all currently defined material traits');
  assert.match(traitSource, /strings\.text\('trait\.\$id\.name'\)/);
  assert.match(traitSource, /strings\.text\('trait\.\$id\.effect'\)/);
  assert.match(traitSource, /trait\.unknownEffect/);

  const traditionalChinese = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const english = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  for (const [locale, body] of [
    ['zh-Hant', traditionalChinese],
    ['en', english],
  ]) {
    for (const key of ['trait.unknownEffect', ...ids.flatMap((id) => [
      `trait.${id}.name`,
      `trait.${id}.effect`,
    ])]) {
      assert.ok(body.includes(`'${key}':`), `${locale} missing ${key}`);
    }
  }
});

test('phase-zero and phase-one exploration tutorials use localized copy', async () => {
  const expeditionPanel = await readFile(
    new URL(
      '../../lib/src/street_scrap_expedition_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const traditionalChinese = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const english = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  const keys = [
    'expedition.task.firstItem',
    'expedition.task.keepItem',
    'expedition.task.deliverMaterials',
    'expedition.phaseOne',
    'expedition.claimSortingSamples',
    'expedition.sewingTitle',
    'expedition.claimSewingKit',
    'expedition.task.intactMaterial',
    'expedition.intactLessonHint',
    'expedition.intactLessonComplete',
    'expedition.deliveryConsumesItems',
  ];
  for (const key of keys) {
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
    assert.ok(expeditionPanel.includes(`'${key}'`), `expedition panel does not use ${key}`);
  }
  assert.match(expeditionPanel, /expedition\.recyclingCategory\.\$category/);
  assert.match(expeditionPanel, /Icons\.check_circle/);
  assert.match(expeditionPanel, /strings\.text\('expedition\.deliverPaper'\)/);
  assert.match(expeditionPanel, /strings\.text\('expedition\.deliverRags'\)/);
  assert.match(expeditionPanel, /strings\.text\('expedition\.error\.\$code'\)/);
  for (const key of [
    'expedition.error.recyclingClassificationLocked',
    'expedition.error.sewingTutorialKitLocked',
    'expedition.error.intactMaterialUnavailable',
    'expedition.error.noFittingSpace',
    'expedition.error.noCleanEmptyBottle',
    'expedition.error.insufficientStamina',
    'expedition.error.operationFailed',
  ]) {
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
  }
});

test('order results, failures, and canonical order names are localized', async () => {
  const ordersPanel = await readFile(
    new URL(
      '../../lib/src/street_scrap_orders_panel.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const traditionalChinese = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const english = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  const orderIds = [
    'ss.order.recycle',
    'ss.order.mending',
    'ss.order.fish',
    'ss.order.board',
    'ss.order.packaging',
    'ss.order.meal',
    'ss.order.failed_meal_recycle',
    'ss.order.insulated',
    'ss.order.advanced_search',
    'ss.order.advanced_recycle',
    'ss.order.advanced_fish',
    'ss.order.advanced_workbench',
    'ss.order.advanced_cooking',
  ];
  for (const orderId of orderIds) {
    const key = `orders.name.${orderId}`;
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
  }
  for (const key of [
    'orders.successDelivery',
    'orders.successReplacement',
    'orders.error.operationFailed',
    'orders.error.chapter5PrerequisiteIncomplete',
    'orders.error.chapter5ExpansionNotInstalled',
    'orders.error.orderNotAccepted',
    'orders.error.orderSourceEventRequired',
    'orders.error.orderRecipeEventRequired',
    'orders.error.orderSelectionInvalid',
    'orders.error.cycleOrderNoReplacement',
    'orders.error.tutorialStateMalformed',
    'orders.error.cycleStateMalformed',
  ]) {
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
  }
  assert.match(ordersPanel, /strings\.text\('orders\.error\.\$code'\)/);
  assert.match(ordersPanel, /_friendlyError\(error, 'orders\.operation\.delivery'\)/);
  assert.match(ordersPanel, /_orderName\(strings, order\.id\)/);
  assert.match(ordersPanel, /_orderSource\(strings, order\.requiredSource!\)/);
  assert.match(ordersPanel, /_recipeName\(strings, id\)/);
  const errorCodesBlock = ordersPanel
    .split('for (final code in [')[1]
    ?.split(']) {')[0];
  assert.ok(errorCodesBlock, 'order panel must map known domain errors');
  const errorCodes = [...errorCodesBlock.matchAll(/'([^']+)'/g)].map(
    (match) => match[1],
  );
  assert.ok(errorCodes.length >= 20, 'expected detailed order error mapping');
  for (const code of errorCodes) {
    const key = `orders.error.${code}`;
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
  }
});

test('silhouette reveal dialog localizes interaction and accessibility copy', async () => {
  const dialogSource = await readFile(
    new URL(
      '../../lib/src/street_scrap_silhouette_dialog.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const traditionalChinese = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const english = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  const keys = [
    'silhouette.title',
    'silhouette.clue',
    'silhouette.slot.left',
    'silhouette.slot.middle',
    'silhouette.slot.right',
    'silhouette.debrisLabel',
    'silhouette.debrisHint',
    'silhouette.instructions',
    'silhouette.cancel',
    'silhouette.select',
    'silhouette.target.revealed',
    'silhouette.target.covered',
    'silhouette.target.selectHint',
    'silhouette.target.revealHint',
    'silhouette.coveredObject',
    'silhouette.status.revealed',
    'silhouette.status.covered',
    'silhouette.debris.dragging',
    'silhouette.debris.move',
  ];
  for (const key of keys) {
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
    assert.ok(dialogSource.includes(`'${key}'`), `dialog does not use ${key}`);
  }
  assert.match(dialogSource, /Semantics\([\s\S]*?strings\.text\('silhouette\.debrisLabel'\)/);
  assert.ok(dialogSource.includes("'silhouette.target.revealHint'"));
});

test('manual operation checkpoints localize controls and canvas target labels', async () => {
  const dialogSource = await readFile(
    new URL(
      '../../lib/src/street_scrap_operation_checkpoint_dialog.dart',
      import.meta.url,
    ),
    'utf8',
  );
  const traditionalChinese = localizationSource
    .split('static const Map<String, String> _zhHant = {')[1]
    .split('\n  };')[0];
  const english = localizationSource
    .split('static const Map<String, String> _en = {')[1]
    .split('\n  };')[0];
  const referencedKeys = new Set(
    [...dialogSource.matchAll(/'((?:checkpoint)\.[^']+)'/g)].map(
      (match) => match[1],
    ),
  );
  assert.ok(referencedKeys.size >= 45, 'expected all operation labels and controls');
  for (const key of referencedKeys) {
    assert.ok(traditionalChinese.includes(`'${key}':`), `zh-Hant missing ${key}`);
    assert.ok(english.includes(`'${key}':`), `English missing ${key}`);
  }
  assert.match(dialogSource, /_OperationTargetPainter\([\s\S]*?zoneLabels: zoneLabels/);
  assert.match(dialogSource, /_drawLabel\(canvas, rect\.center, zoneLabels\[i\]\)/);
  assert.match(dialogSource, /pointLabels: pointLabels/);
});
