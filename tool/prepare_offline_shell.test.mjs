import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';

import { writeOfflineShellManifest } from './prepare_offline_shell.mjs';

test('offline shell manifest pins app code and renderer but excludes optional data', async () => {
  const root = await mkdtemp(join(tmpdir(), 'street-scrap-offline-shell-'));
  try {
    const files = [
      ...[
        'index.html', 'manifest.json', 'display_context.js',
        'street_scrap_writer_lock.js', 'flutter_bootstrap.js', 'flutter.js', 'version.json',
        'assets/AssetManifest.bin', 'assets/AssetManifest.bin.json',
        'assets/FontManifest.json', 'assets/fonts/MaterialIcons-Regular.otf',
        'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
        'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm',
        'canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm',
        'icons/Icon-192.png', 'favicon.png',
      ],
      'main.dart.js',
      'main.dart.js_5.part.js',
      'main.dart.js_12.part.js',
      'app-shell-sw.js',
      'assets/assets/audio/scrap_tap.wav',
      'assets/game/street-scrap-content-v1.json',
      'assets/packages/taiwan_brawl_game_street_scrap/assets/fallback/rag_piece_v1.png',
      'assets/packages/taiwan_brawl_game_street_scrap/assets/audio/scrap_tap.wav',
      'assets/shaders/ink_sparkle.frag',
    ];
    for (const path of files) {
      const fullPath = join(root, path);
      await mkdir(join(fullPath, '..'), { recursive: true });
      const contents = path === 'main.dart.js'
        ? 'load("main.dart.js_5.part.js"); load("main.dart.js_12.part.js");'
        : path === 'assets/FontManifest.json'
          ? JSON.stringify([
              { family: 'MaterialIcons', fonts: [{ asset: 'fonts/MaterialIcons-Regular.otf' }] },
              { family: 'packages/cupertino_icons/CupertinoIcons', fonts: [{ asset: 'packages/cupertino_icons/assets/CupertinoIcons.ttf' }] },
            ])
        : path === 'app-shell-sw.js'
          ? "'use strict';\nconst BUILD_VERSION = 'development';\n"
          : path;
      await writeFile(fullPath, contents);
    }

    const manifest = await writeOfflineShellManifest(root);
    assert.equal(manifest.schemaVersion, 1);
    assert.match(manifest.version, /^[a-f0-9]{20}$/);
    assert.ok(manifest.byteLength <= 32 * 1024 * 1024);
    assert.ok(manifest.assets.includes('/main.dart.js_5.part.js'));
    assert.ok(manifest.assets.includes('/main.dart.js_12.part.js'));
    assert.ok(manifest.assets.includes('/manifest.json'));
    assert.ok(manifest.assets.includes('/display_context.js'));
    assert.ok(manifest.assets.includes('/street_scrap_writer_lock.js'));
    assert.ok(manifest.assets.includes('/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf'));
    assert.ok(manifest.assets.includes('/assets/packages/taiwan_brawl_game_street_scrap/assets/fallback/rag_piece_v1.png'));
    assert.ok(manifest.assets.includes('/assets/packages/taiwan_brawl_game_street_scrap/assets/audio/scrap_tap.wav'));
    assert.ok(manifest.assets.includes('/assets/shaders/ink_sparkle.frag'));
    assert.ok(manifest.assets.includes('/canvaskit/chromium/canvaskit.wasm'));
    assert.ok(!manifest.assets.includes('/assets/assets/audio/scrap_tap.wav'));
    assert.ok(!manifest.assets.includes('/assets/game/street-scrap-content-v1.json'));
    const generatedWorker = await readFile(join(root, 'app-shell-sw.js'), 'utf8');
    assert.ok(generatedWorker.includes(`const BUILD_VERSION = '${manifest.version}';`));
    const generatedManifest = JSON.parse(
      await readFile(join(root, 'offline-shell-manifest.json'), 'utf8'),
    );
    assert.equal(generatedManifest.version, manifest.version);

    await writeFile(
      join(root, 'app-shell-sw.js'),
      generatedWorker.replace("'use strict';", "'use strict';\n// worker logic changed"),
    );
    const changed = await writeOfflineShellManifest(root);
    assert.notEqual(changed.version, manifest.version);
    await writeFile(
      join(root, 'assets/FontManifest.json'),
      JSON.stringify([{ family: 'bad', fonts: [{ asset: '../game-resources/data.bin' }] }]),
    );
    await assert.rejects(
      writeOfflineShellManifest(root),
      /font asset path is invalid/,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
