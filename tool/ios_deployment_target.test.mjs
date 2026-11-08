import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const projectFile = new URL('../ios/Runner.xcodeproj/project.pbxproj', import.meta.url);
const podfile = new URL('../ios/Podfile', import.meta.url);

test('iOS app and CocoaPods keep the project minimum at iOS 26', async () => {
  const [project, pods] = await Promise.all([
    readFile(projectFile, 'utf8'),
    readFile(podfile, 'utf8'),
  ]);
  const targets = [...project.matchAll(/IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);/g)]
    .map((match) => match[1].trim());

  assert.deepEqual(targets, ['26.0', '26.0', '26.0']);
  assert.match(pods, /^platform :ios, '26\.0'\s*$/m);
});
