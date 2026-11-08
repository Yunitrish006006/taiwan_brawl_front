import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const resourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-art-v0.1.0.png',
  import.meta.url,
);
const threadSpoolResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-art-thread-spool-v0.1.0.png',
  import.meta.url,
);
const materialAtlasResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-art-material-atlas-v0.3.0.png',
  import.meta.url,
);
const toolAtlasResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-art-tool-atlas-v0.1.0.png',
  import.meta.url,
);
const mineralPackResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-art-mineral-pack-v0.1.0.png',
  import.meta.url,
);
const woodChipBundleResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-art-wood-chip-bundle-v0.1.0.png',
  import.meta.url,
);
const fishingSceneResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/dock-fishing-background-v0.1.0.png',
  import.meta.url,
);
const protagonistResourcePath = new URL(
  '../packages/games/street_scrap/resources/art/street-scrap-protagonist-v0.1.0.json',
  import.meta.url,
);
const moduleSource = await readFile(
  new URL(
    '../packages/games/street_scrap/lib/src/street_scrap_module.dart',
    import.meta.url,
  ),
  'utf8',
);

test('Street Scrap wood-board presentation resource is transparent and version-hashed', async () => {
  const bytes = await readFile(resourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(moduleSource, new RegExp(`streetScrapArtSha256\\s*=\\s*'${sha256}'`));
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(16), 1774);
  assert.equal(bytes.readUInt32BE(20), 887);
  assert.equal(bytes[25], 6, 'PNG must include alpha for transparent padding');
  assert.ok(bytes.length < 1024 * 1024, 'prototype sprite remains below 1 MiB');
});

test('Street Scrap thread-spool presentation resource is transparent and version-hashed', async () => {
  const bytes = await readFile(threadSpoolResourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(
    moduleSource,
    new RegExp(`streetScrapThreadSpoolArtSha256\\s*=\\s*'${sha256}'`),
  );
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(16), 1254);
  assert.equal(bytes.readUInt32BE(20), 1254);
  assert.equal(bytes[25], 6, 'PNG must include alpha for transparent padding');
  assert.ok(bytes.length < 1024 * 1024, 'prototype sprite remains below 1 MiB');
});

test('Street Scrap food-expanded material atlas is a transparent 4x12 sheet and version-hashed', async () => {
  const bytes = await readFile(materialAtlasResourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(
    moduleSource,
    new RegExp(`streetScrapMaterialAtlasSha256\\s*=\\s*'${sha256}'`),
  );
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(16), 768);
  assert.equal(bytes.readUInt32BE(20), 2304);
  assert.equal(bytes[25], 3, 'atlas uses a compact indexed PNG palette');
  assert.ok(bytes.includes(Buffer.from('tRNS')), 'PNG palette carries alpha transparency');
  assert.ok(bytes.length < 2 * 1024 * 1024, 'optional atlas remains below 2 MiB');
});

test('Street Scrap tool atlas is a compact transparent 4x4 sheet and version-hashed', async () => {
  const bytes = await readFile(toolAtlasResourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(moduleSource, new RegExp(`streetScrapToolAtlasSha256\\s*=\\s*'${sha256}'`));
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(16), 768);
  assert.equal(bytes.readUInt32BE(20), 768);
  assert.equal(bytes[25], 6, 'PNG must include alpha for transparent padding');
  assert.ok(bytes.length < 1024 * 1024, 'tool atlas remains below 1 MiB');
});

test('Street Scrap mineral-pack art is a transparent optional sprite and version-hashed', async () => {
  const bytes = await readFile(mineralPackResourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(
    moduleSource,
    new RegExp('streetScrapMineralPackArtSha256\\s*=\\s*\'' + sha256 + '\''),
  );
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(16), 512);
  assert.equal(bytes.readUInt32BE(20), 512);
  assert.equal(bytes[25], 6, 'PNG must include alpha for transparent padding');
  assert.ok(bytes.length < 1024 * 1024, 'optional art remains below 1 MiB');
});

test('Street Scrap wood-chip bundle art is transparent, compact, and version-hashed', async () => {
  const bytes = await readFile(woodChipBundleResourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(
    moduleSource,
    new RegExp(`streetScrapWoodChipBundleArtSha256\\s*=\\s*'${sha256}'`),
  );
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  assert.equal(bytes.readUInt32BE(16), 512);
  assert.equal(bytes.readUInt32BE(20), 468);
  assert.equal(bytes[25], 6, 'PNG must include alpha for transparent padding');
  assert.equal(bytes.length, 237875);
});

test('mineral-pack art stays optional end-to-end and the built-in fallback remains', async () => {
  const root = new URL('../', import.meta.url);
  const [registration, routes, entryPage, sprite] = await Promise.all([
    readFile(new URL('lib/game_modules/street_scrap_game_registration.dart', root), 'utf8'),
    readFile(new URL('lib/game_modules/street_scrap_game_routes.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_progress_entry_page.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_item_sprite.dart', root), 'utf8'),
  ]);
  assert.match(registration, /streetScrapMineralPackArtResourceId[\s\S]*?kind: GameResourceKind\.presentation/);
  assert.match(registration, /streetScrapMineralPackArtSha256[\s\S]*?affectsGameplay: false[\s\S]*?required: false/);
  assert.match(registration, /validateStreetScrapArtBytes/);
  assert.match(routes, /if \(!mineralPackArtInstalled\) return null/);
  assert.match(entryPage, /validateStreetScrapArtBytes\(mineralPackArtBytes\)/);
  assert.match(entryPage, /on Object\s*\{\s*mineralPackArtBytes = null;/);
  assert.match(sprite, /itemId == 'material\.mineral_pack'[\s\S]*?mineralPackSpriteBytes != null/);
  assert.match(sprite, /CustomPaint\(\s*painter: _StreetScrapPixelPainter/);
});

test('wood-chip bundle art stays optional end-to-end and falls back offline', async () => {
  const root = new URL('../', import.meta.url);
  const [registration, routes, entryPage, sprite] = await Promise.all([
    readFile(new URL('lib/game_modules/street_scrap_game_registration.dart', root), 'utf8'),
    readFile(new URL('lib/game_modules/street_scrap_game_routes.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_progress_entry_page.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_item_sprite.dart', root), 'utf8'),
  ]);
  assert.match(registration, /streetScrapWoodChipBundleArtResourceId[\s\S]*?kind: GameResourceKind\.presentation/);
  assert.match(registration, /streetScrapWoodChipBundleArtSha256[\s\S]*?affectsGameplay: false[\s\S]*?required: false/);
  assert.match(routes, /if \(!woodChipBundleArtInstalled\) return null/);
  assert.match(entryPage, /validateStreetScrapArtBytes\(woodChipBundleArtBytes\)/);
  assert.match(entryPage, /on Object\s*\{\s*woodChipBundleArtBytes = null;/);
  assert.match(sprite, /itemId == 'bundle\.wood_chip'[\s\S]*?woodChipBundleSpriteBytes != null/);
  assert.match(sprite, /CustomPaint\(\s*painter: _StreetScrapPixelPainter/);
});

test('fishing scene art stays optional, versioned and keeps its offline fallback', async () => {
  const bytes = await readFile(fishingSceneResourcePath);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  assert.match(
    moduleSource,
    new RegExp(`streetScrapFishingSceneArtSha256\\s*=\\s*'${sha256}'`),
  );
  assert.deepEqual(
    bytes.subarray(0, 8),
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  );
  assert.equal(bytes.readUInt32BE(16), 2172);
  assert.equal(bytes.readUInt32BE(20), 724);
  assert.ok(bytes.length < 5 * 1024 * 1024);
  const root = new URL('../', import.meta.url);
  const [registration, routes, entryPage, panel] = await Promise.all([
    readFile(new URL('lib/game_modules/street_scrap_game_registration.dart', root), 'utf8'),
    readFile(new URL('lib/game_modules/street_scrap_game_routes.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_progress_entry_page.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_fishing_panel.dart', root), 'utf8'),
  ]);
  assert.match(registration, /streetScrapFishingSceneArtResourceId[\s\S]*?kind: GameResourceKind\.presentation/);
  assert.match(registration, /streetScrapFishingSceneArtSha256[\s\S]*?affectsGameplay: false[\s\S]*?required: false/);
  assert.match(routes, /if \(!fishingSceneArtInstalled\) return null/);
  assert.match(entryPage, /validateStreetScrapFishingSceneArtBytes\(fishingSceneArtBytes\)/);
  assert.match(entryPage, /on Object\s*\{\s*fishingSceneArtBytes = null;/);
  assert.match(panel, /if \(artBytes case final bytes\?\)[\s\S]*?Image\.memory/);
  assert.match(panel, /painter: _FishingSceneFallbackPainter\(\)/);
});

test('tool atlas is registered as an optional presentation pack with safe fallback', async () => {
  const root = new URL('../', import.meta.url);
  const [registration, routes, entryPage, sprite] = await Promise.all([
    readFile(new URL('lib/game_modules/street_scrap_game_registration.dart', root), 'utf8'),
    readFile(new URL('lib/game_modules/street_scrap_game_routes.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_progress_entry_page.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_item_sprite.dart', root), 'utf8'),
  ]);
  assert.match(registration, /streetScrapToolAtlasResourceId[\s\S]*?kind: GameResourceKind\.presentation/);
  assert.match(registration, /streetScrapToolAtlasSha256[\s\S]*?affectsGameplay: false[\s\S]*?required: false/);
  assert.match(registration, /streetScrapToolAtlasResourceId[\s\S]*?validateStreetScrapToolAtlasBytes/);
  assert.match(routes, /if \(!toolAtlasInstalled\) return null/);
  assert.match(entryPage, /validateStreetScrapToolAtlasBytes\(toolAtlasBytes\)/);
  assert.match(entryPage, /on Object\s*\{\s*toolAtlasBytes = null;/);
  assert.match(sprite, /toolAtlasBytes != null && _toolAtlasCell != null/);
  assert.match(sprite, /CustomPaint\(\s*painter: _StreetScrapPixelPainter/);
});

test('protagonist art is a versioned optional pack with a lightweight shell fallback', async () => {
  const payload = await readFile(protagonistResourcePath);
  const sha256 = createHash('sha256').update(payload).digest('hex');
  const decoded = JSON.parse(payload.toString('utf8'));
  assert.equal(decoded.moduleId, 'game.street-scrap');
  assert.equal(decoded.resourceId, 'game.street-scrap.art.protagonist');
  assert.equal(decoded.version, '0.1.0');
  assert.equal(decoded.schemaVersion, 1);
  assert.match(
    moduleSource,
    new RegExp(`streetScrapProtagonistArtSha256\\s*=\\s*'${sha256}'`),
  );
  assert.equal(Buffer.from(decoded.idlePngBase64, 'base64').readUInt32BE(16), 1159);
  assert.equal(Buffer.from(decoded.idlePngBase64, 'base64').readUInt32BE(20), 1358);
  assert.equal(Buffer.from(decoded.actionsPngBase64, 'base64').readUInt32BE(16), 1884);
  assert.equal(Buffer.from(decoded.actionsPngBase64, 'base64').readUInt32BE(20), 835);
  assert.ok(payload.byteLength < 3 * 1024 * 1024);

  const root = new URL('../', import.meta.url);
  const [registration, routes, entryPage, sprite, pubspec] = await Promise.all([
    readFile(new URL('lib/game_modules/street_scrap_game_registration.dart', root), 'utf8'),
    readFile(new URL('lib/game_modules/street_scrap_game_routes.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_progress_entry_page.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/lib/src/street_scrap_protagonist_sprite.dart', root), 'utf8'),
    readFile(new URL('packages/games/street_scrap/pubspec.yaml', root), 'utf8'),
  ]);
  assert.match(registration, /streetScrapProtagonistArtResourceId[\s\S]*?kind: GameResourceKind\.presentation/);
  assert.match(registration, /streetScrapProtagonistArtSha256[\s\S]*?affectsGameplay: false[\s\S]*?required: false/);
  assert.match(registration, /validateStreetScrapProtagonistArtBytes/);
  assert.match(routes, /protagonistArtInstalled/);
  assert.match(routes, /if \(!protagonistArtInstalled\) return null/);
  assert.match(entryPage, /StreetScrapProtagonistArt\.fromPayload/);
  assert.match(entryPage, /protagonistArt = null;/);
  assert.match(sprite, /Image\.memory/);
  assert.match(sprite, /CustomPaint/);
  assert.doesNotMatch(sprite, /Image\.asset/);
  assert.match(pubspec, /assets\/fallback\//);
  await assert.rejects(
    readFile(new URL('packages/games/street_scrap/assets/fallback/street_scrap_protagonist_idle_v1.png', root)),
    { code: 'ENOENT' },
  );
  await assert.rejects(
    readFile(new URL('packages/games/street_scrap/assets/fallback/street_scrap_protagonist_actions_v1.png', root)),
    { code: 'ENOENT' },
  );
});
