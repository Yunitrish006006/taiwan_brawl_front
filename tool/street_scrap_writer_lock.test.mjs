import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

const bridgeSource = await readFile(
  new URL('../web/street_scrap_writer_lock.js', import.meta.url),
  'utf8',
);

class FakeLockManager {
  active = new Set();

  request(name, _options, callback) {
    if (this.active.has(name)) {
      return Promise.resolve().then(() => callback(null));
    }
    this.active.add(name);
    return Promise.resolve()
      .then(() => callback({ name }))
      .finally(() => this.active.delete(name));
  }
}

function createBridge(locks) {
  const window = { navigator: locks ? { locks } : {} };
  runInNewContext(bridgeSource, { window });
  return window.taiwanBrawlStreetScrapLock;
}

test('exclusive ownership is per slot and release permits the next writer', async () => {
  const bridge = createBridge(new FakeLockManager());

  assert.equal(await bridge.acquire('slot-a', 'owner-a'), true);
  assert.equal(await bridge.acquire('slot-a', 'owner-b'), false);
  assert.equal(await bridge.acquire('slot-b', 'owner-c'), true);

  bridge.release('owner-a');
  bridge.release('owner-a');
  bridge.release('unknown-owner');
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(await bridge.acquire('slot-a', 'owner-d'), true);

  bridge.release('owner-c');
  bridge.release('owner-d');
});

test('missing Web Locks API fails closed', async () => {
  const bridge = createBridge();
  assert.equal(await bridge.acquire('slot-a', 'owner-a'), false);
});

test('synchronous and asynchronous lock errors fail closed and allow retry', async () => {
  let bridge = createBridge({ request() { throw new Error('unavailable'); } });
  assert.equal(await bridge.acquire('slot-a', 'owner-a'), false);

  bridge = createBridge({ request() { return Promise.reject(new Error('denied')); } });
  assert.equal(await bridge.acquire('slot-a', 'owner-a'), false);

  const working = createBridge(new FakeLockManager());
  assert.equal(await working.acquire('slot-a', 'owner-a'), true);
  working.release('owner-a');
});
