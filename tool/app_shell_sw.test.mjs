import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { URL } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';

const workerSource = await readFile(
  new URL('../web/app-shell-sw.js', import.meta.url),
  'utf8',
);
const bootstrapSource = await readFile(
  new URL('../web/flutter_bootstrap.js', import.meta.url),
  'utf8',
);
const indexSource = await readFile(
  new URL('../web/index.html', import.meta.url),
  'utf8',
);

test('Flutter bootstrap leaves root service-worker control to the app shell', () => {
  assert.ok(bootstrapSource.includes('{{flutter_js}}'));
  assert.ok(bootstrapSource.includes('{{flutter_build_config}}'));
  assert.ok(bootstrapSource.includes('_flutter.loader.load();'));
  assert.ok(!bootstrapSource.includes('serviceWorkerSettings'));
  assert.match(indexSource, /navigator\.serviceWorker\.register\('app-shell-sw\.js'\)/);
});

function createWorker({ fetchImpl }) {
  const handlers = new Map();
  const cacheMap = new Map();
  const normalizeKey = (key) =>
    typeof key === 'string' ? new URL(key, 'https://app.test/').href : key.url;
  const caches = {
    async keys() {
      return [...cacheMap.keys()];
    },
    async open(name) {
      if (!cacheMap.has(name)) {
        const entries = new Map();
        cacheMap.set(name, {
          async put(key, response) {
            entries.set(normalizeKey(key), response.clone());
          },
          async match(key) {
            return entries.get(normalizeKey(key))?.clone() ?? null;
          },
        });
      }
      return cacheMap.get(name);
    },
    async delete(name) {
      return cacheMap.delete(name);
    },
  };
  const self = {
    location: new URL('https://app.test/'),
    registration: { scope: 'https://app.test/' },
    clients: { claim: async () => {} },
    addEventListener(name, callback) {
      handlers.set(name, callback);
    },
  };
  vm.runInNewContext(workerSource, {
    URL,
    Response,
    caches,
    fetch: fetchImpl,
    self,
  });
  return { handlers, cacheMap };
}

test('offline shell skips APIs and separately downloaded game resources', async () => {
  const { handlers } = createWorker({
    fetchImpl: async () => new Response('network'),
  });
  const handleFetch = handlers.get('fetch');
  for (const path of [
    '/api/games/catalog',
    '/game-resources/game.street-scrap/data/1.0.0',
    '/firebase-messaging-sw.js',
  ]) {
    let intercepted = false;
    handleFetch({
      request: {
        method: 'GET',
        mode: 'cors',
        url: new URL(path, 'https://app.test/').href,
      },
      respondWith() {
        intercepted = true;
      },
    });
    assert.equal(intercepted, false, `${path} must bypass the shell worker`);
  }
});

test('offline navigation falls back to the pinned shell after cache install', async () => {
  let networkAvailable = true;
  const manifest = {
    schemaVersion: 1,
    version: 'development',
    assets: ['/index.html', '/main.dart.js'],
  };
  const { handlers, cacheMap } = createWorker({
    fetchImpl: async (input) => {
      const url = new URL(typeof input === 'string' ? input : input.url);
      if (!networkAvailable) throw new Error('offline');
      if (url.pathname === '/offline-shell-manifest.json') {
        return Response.json(manifest);
      }
      return new Response(
        url.pathname === '/index.html' ? 'cached-shell' : 'cached-code',
        {
          headers: {
            'content-type': url.pathname === '/index.html'
              ? 'text/html'
              : 'application/javascript',
          },
        },
      );
    },
  });
  let installPromise;
  handlers.get('install')({
    waitUntil(promise) {
      installPromise = promise;
    },
  });
  await installPromise;
  assert.ok(cacheMap.has('taiwan-brawl-app-shell-development'));

  networkAvailable = false;
  let navigationResponse;
  handlers.get('fetch')({
    request: {
      method: 'GET',
      mode: 'navigate',
      url: 'https://app.test/street-scrap',
    },
    respondWith(promise) {
      navigationResponse = promise;
    },
  });
  assert.equal(await (await navigationResponse).text(), 'cached-shell');
});
