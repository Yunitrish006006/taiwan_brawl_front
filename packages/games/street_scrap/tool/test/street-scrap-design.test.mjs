import test from 'node:test';
import assert from 'node:assert/strict';
import { audit, loadDesign, reachableAt, parseRecipes } from '../audit-street-scrap-design.mjs';

const { spec, recipes } = loadDesign();

test('Street Scrap design declares all table recipes and valid identities/footprints', () => {
  assert.equal(spec.items.length, 111);
  assert.equal(recipes.length, 78);
  assert.deepEqual(audit(spec, recipes).errors, []);
});

test('early glue can use public filtered water before muddy-water collection unlocks', () => {
  const available = reachableAt(spec, recipes, 1);
  assert(available.has('adhesive.recycled'));
  assert(!available.has('water.muddy'));
  assert(!available.has('plastic.sheet'));
});

test('dish and water contents do not claim independent grid cells', () => {
  for (const item of spec.items.filter(item => item.id.startsWith('water.') || item.id.startsWith('meal.'))) {
    assert.equal(item.footprint, null);
    assert.equal(item.location, item.id === 'meal.relief_box' ? 'mailbox' : 'content');
  }
});

test('unknown ingredients and malformed quantities fail closed during parsing', () => {
  assert.throws(() => parseRecipes('### 11.4 Recipes\n| `fake`／1 | 未知材料 1 → 紙漿 1 |', spec), /Unknown recipe term/);
  assert.throws(() => parseRecipes('### 11.4 Recipes\n| `fake`／1 | 紙屑 many → 紙漿 1 |', spec), /Unknown recipe term/);
});

test('phase audit rejects a closed dependency cycle, not merely valid names', () => {
  const altered = structuredClone(spec);
  altered.supplies = altered.supplies.filter(source => source.item !== 'adhesive.residue');
  const result = audit(altered, recipes);
  assert(result.errors.some(error => error.includes('recycle_glue')));
  assert(result.errors.some(error => error.includes('wooden_crate')));
});

test('duplicate identities, invalid grid dimensions and bundled ingredients are rejected', () => {
  const altered = structuredClone(spec);
  altered.items.push(structuredClone(altered.items[0]));
  altered.items[1].footprint = [0, 1];
  const changed = structuredClone(recipes);
  changed[0].inputGroups = [[{ item: 'bundle.cloth_scrap', quantity: 1 }]];
  const result = audit(altered, changed);
  assert(result.errors.some(error => error.includes('Duplicate item')));
  assert(result.errors.some(error => error.includes('Invalid footprint')));
  assert(result.errors.some(error => error.includes('Bundle cannot')));
});

test('phase-five soup has a non-fish alternative and reusable tools remain separate', () => {
  const meal = recipes.find(recipe => recipe.id === 'ss.recipe.shared_meal');
  assert(meal.inputGroups.some(group => group.every(input => !input.item.startsWith('fish.'))));
  const cloth = recipes.find(recipe => recipe.id === 'ss.recipe.patch_cloth');
  assert(cloth.tools.includes('tool.needle'));
  assert(cloth.inputGroups.every(group => group.every(input => input.item !== 'tool.needle')));
});

test('liquid and bag identity transitions are labeled as a limitation of this graph audit', () => {
  const result = audit(spec, recipes);
  assert.match(result.scope, /not quantity balance, failure recovery, packing, runtime or player QA/);
  assert.equal(result.phases.length, 6);
});

test('an end product without any crafting or declared gameplay use fails audit', () => {
  const altered = structuredClone(spec);
  delete altered.terminalUses['structure.raft'];
  assert(audit(altered, recipes).errors.includes('No declared use: structure.raft'));
});

test('every recipe has an explicit primary-material, operation and identity policy', () => {
  assert.equal(spec.recipePolicies.length, recipes.length);
  const altered = structuredClone(spec);
  altered.recipePolicies.pop();
  assert(audit(altered, recipes).errors.some(error => error.includes('Missing recipe policy')));
});

test('policy cannot invent primary materials or retain unrelated instances', () => {
  const altered = structuredClone(spec);
  altered.recipePolicies[0].primaryInputs = ['wood.board'];
  altered.recipePolicies[0].retainedInputIdentities = ['tool.crowbar'];
  const result = audit(altered, recipes);
  assert(result.errors.some(error => error.includes('Non-input primary')));
  assert(result.errors.some(error => error.includes('Non-input retained identity')));
});
