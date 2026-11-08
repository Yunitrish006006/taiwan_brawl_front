/*
 * App shell cache for offline reopening. Signed game resources and all API
 * traffic remain owned by their local stores/network clients.
 */
'use strict';

const CACHE_PREFIX = 'taiwan-brawl-app-shell-';
// Replaced with the release shell digest by tool/prepare_offline_shell.mjs.
const BUILD_VERSION = 'development';
const MANIFEST_PATH = '/offline-shell-manifest.json';
const API_PREFIX = '/api/';
const BYPASS_PREFIXES = ['/game-resources/'];
const BYPASS_PATHS = new Set([
  '/privacy',
  '/app-shell-sw.js',
  '/firebase-messaging-sw.js',
  MANIFEST_PATH,
]);

function cacheName(version) {
  return `${CACHE_PREFIX}${version}`;
}

function shellAssetUrl(asset) {
  return new URL(asset, self.registration.scope).href;
}

async function precacheShell() {
  const manifestUrl = shellAssetUrl(MANIFEST_PATH);
  const manifestResponse = await fetch(manifestUrl, { cache: 'no-store' });
  if (!manifestResponse.ok) {
    throw new Error(`Offline shell manifest unavailable: ${manifestResponse.status}`);
  }

  const manifest = await manifestResponse.clone().json();
  if (
    manifest?.schemaVersion !== 1 ||
    manifest.version !== BUILD_VERSION ||
    !Array.isArray(manifest.assets) ||
    manifest.assets.length === 0
  ) {
    throw new Error('Offline shell manifest is invalid.');
  }

  const name = cacheName(BUILD_VERSION);
  const cache = await caches.open(name);
  try {
    for (const asset of manifest.assets) {
      const url = shellAssetUrl(asset);
      if (new URL(url).origin !== self.location.origin) {
        throw new Error('Offline shell asset escaped the app origin.');
      }
      const response = await fetch(url, { cache: 'reload' });
      const contentType = response.headers.get('content-type') ?? '';
      const isIndex = new URL(url).pathname === '/index.html' ||
        new URL(url).pathname === '/';
      if (
        !response.ok ||
        (!isIndex && contentType.toLowerCase().includes('text/html'))
      ) {
        throw new Error(`Offline shell asset failed: ${new URL(url).pathname}`);
      }
      await cache.put(url, response);
    }
    await cache.put(manifestUrl, manifestResponse);
  } catch (error) {
    await caches.delete(name);
    throw error;
  }
}

async function activeShellCache() {
  return caches.open(cacheName(BUILD_VERSION));
}

self.addEventListener('install', (event) => {
  // A quota or download failure leaves the prior active worker and cache intact.
  event.waitUntil(precacheShell());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = (await caches.keys()).filter((name) =>
      name.startsWith(CACHE_PREFIX),
    );
    const current = cacheName(BUILD_VERSION);
    await Promise.all(names
      .filter((name) => name !== current)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (
    url.origin !== self.location.origin ||
    url.pathname.startsWith(API_PREFIX) ||
    BYPASS_PREFIXES.some((prefix) => url.pathname.startsWith(prefix)) ||
    BYPASS_PATHS.has(url.pathname)
  ) {
    return;
  }

  event.respondWith((async () => {
    const cache = await activeShellCache();
    const cached = cache
      ? await cache.match(request) ?? await cache.match(url.pathname)
      : null;

    try {
      const response = await fetch(request);
      if (response.ok && cache) {
        try {
          await cache.put(request, response.clone());
        } catch (_) {
          // A full cache must not make a successful online request fail.
        }
      }
      return response;
    } catch (_) {
      if (cached) return cached;
      if (request.mode === 'navigate' && cache) {
        const root = shellAssetUrl('/index.html');
        const fallback = await cache.match(root) ?? await cache.match(shellAssetUrl('/'));
        if (fallback) return fallback;
      }
      return Response.error();
    }
  })());
});
