import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';
import { handleSpeedCameraRequest } from '../../taiwan_brawl_back/src/api/speed_camera_api.js';
import { syncOfficialSpeedCameraData } from '../../taiwan_brawl_back/src/speed_camera/sync.js';

const entries = new Map();
const env = { SPEED_CAMERA_DATA: {
  get: async key => entries.get(key),
  put: async (key, value) => entries.set(key, value),
}};
const csv = [
  'CityName,RegionName,Address,DeptNm,BranchNm,Longitude,Latitude,direct,limit',
  ...Array.from({ length: 510 }, (_, i) => [
    '臺北市', '大安區', '測試路' + i, '警察局', '分局', 121.5, 25.025, '往東', 60,
  ].join(',')),
].join('\n');
await syncOfficialSpeedCameraData(env, async () => new Response(csv));

async function request(path) {
  const url = new URL('https://example.test/api/speed-cameras/' + path);
  const response = await handleSpeedCameraRequest(new Request(url), env, url);
  assert.equal(response.status, 200);
  return response.json();
}

const manifest = await request('manifest');
const snapshot = await request('snapshot?version=' + manifest.version);
await writeFile(process.argv[2], JSON.stringify({ manifest, snapshot }));
