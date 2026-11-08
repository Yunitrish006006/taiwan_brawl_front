import { createHash } from 'node:crypto';
import { readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';

const MAX_SHELL_BYTES = 32 * 1024 * 1024;
const WORKER_VERSION_PATTERN = /const BUILD_VERSION = '[^']+';/;
const WORKER_VERSION_TEMPLATE = "const BUILD_VERSION = 'development';";

const fixedAssets = [
  'index.html',
  'manifest.json',
  'display_context.js',
  'street_scrap_writer_lock.js',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'version.json',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
  'icons/Icon-192.png',
  'favicon.png',
];

async function addFilesRecursively(buildRoot, relativeDirectory, assets) {
  const directory = resolve(buildRoot, relativeDirectory);
  const root = resolve(buildRoot);
  if (directory !== root && !directory.startsWith(`${root}${sep}`)) {
    throw new Error(`Offline shell asset directory escaped build root: ${relativeDirectory}`);
  }
  const entries = await readdir(directory, { withFileTypes: true }).catch((error) => {
    if (error?.code === 'ENOENT') return [];
    throw error;
  });
  for (const entry of entries) {
    const path = `${relativeDirectory}/${entry.name}`;
    if (entry.isDirectory()) {
      await addFilesRecursively(buildRoot, path, assets);
    } else if (entry.isFile()) {
      assets.add(path);
    }
  }
}

export async function buildOfflineShellManifest(buildDirectory) {
  const buildRoot = resolve(buildDirectory);
  const assets = new Set(fixedAssets);
  // Package images and shaders are bundled with the app, not optional resource
  // packs. Cache them with the shell so offline routes do not render empty art.
  await addFilesRecursively(buildRoot, 'assets/packages', assets);
  await addFilesRecursively(buildRoot, 'assets/shaders', assets);
  const mainSource = await readFile(resolve(buildRoot, 'main.dart.js'), 'utf8');
  const fontManifest = JSON.parse(
    await readFile(resolve(buildRoot, 'assets/FontManifest.json'), 'utf8'),
  );
  if (!Array.isArray(fontManifest)) {
    throw new Error('Offline shell font manifest is invalid.');
  }
  for (const family of fontManifest) {
    if (!family || !Array.isArray(family.fonts)) {
      throw new Error('Offline shell font entry is invalid.');
    }
    for (const font of family.fonts) {
      const asset = typeof font?.asset === 'string'
        ? font.asset.replaceAll('\\', '/')
        : '';
      if (!asset || asset.startsWith('/') || asset.split('/').includes('..')) {
        throw new Error('Offline shell font asset path is invalid.');
      }
      assets.add(`assets/${asset}`);
    }
  }
  const workerSource = await readFile(resolve(buildRoot, 'app-shell-sw.js'), 'utf8');
  if (!WORKER_VERSION_PATTERN.test(workerSource)) {
    throw new Error('Offline shell worker has no build version marker.');
  }
  const normalizedWorkerSource = workerSource.replace(
    WORKER_VERSION_PATTERN,
    WORKER_VERSION_TEMPLATE,
  );
  for (const match of mainSource.matchAll(/main\.dart\.js_[0-9]+\.part\.js/g)) {
    assets.add(match[0]);
  }
  for (const path of assets) {
    if (path.startsWith('api/') || path.startsWith('game-resources/')) {
      throw new Error(`User-owned or optional resource entered the app shell: ${path}`);
    }
  }

  const entries = [];
  let totalBytes = 0;
  for (const path of [...assets].sort()) {
    const absolutePath = resolve(buildRoot, path);
    const info = await stat(absolutePath).catch(() => null);
    if (!info?.isFile()) {
      throw new Error(`Required offline shell asset is missing: ${path}`);
    }
    const bytes = await readFile(absolutePath);
    totalBytes += bytes.byteLength;
    entries.push({ path: path.split(sep).join('/'), bytes });
  }

  if (totalBytes > MAX_SHELL_BYTES) {
    throw new Error(
      `Offline shell is ${totalBytes} bytes; limit is ${MAX_SHELL_BYTES}.`,
    );
  }

  const digest = createHash('sha256');
  for (const entry of entries) {
    digest.update(entry.path);
    digest.update('\0');
    digest.update(entry.bytes);
  }
  digest.update('app-shell-sw.js-template\0');
  digest.update(normalizedWorkerSource);
  const version = digest.digest('hex').slice(0, 20);
  return {
    schemaVersion: 1,
    version,
    byteLength: totalBytes,
    assets: entries.map(({ path }) => `/${path}`),
  };
}

export async function writeOfflineShellManifest(buildDirectory) {
  const buildRoot = resolve(buildDirectory);
  const manifest = await buildOfflineShellManifest(buildRoot);
  const outputPath = resolve(buildRoot, 'offline-shell-manifest.json');
  const workerPath = resolve(buildRoot, 'app-shell-sw.js');
  const workerSource = await readFile(workerPath, 'utf8');
  await writeFile(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);
  await writeFile(
    workerPath,
    workerSource.replace(
      WORKER_VERSION_PATTERN,
      `const BUILD_VERSION = '${manifest.version}';`,
    ),
  );
  return { ...manifest, outputPath };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const buildDirectory = process.argv[2] ?? 'build/web';
  const manifest = await writeOfflineShellManifest(buildDirectory);
  console.log(
    `Prepared offline shell ${manifest.version}: ${manifest.assets.length} files, ${manifest.byteLength} bytes at ${manifest.outputPath}`,
  );
}
