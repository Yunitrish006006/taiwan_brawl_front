import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

// Structural preflight only: it cannot replace Xcode type checking or signing.
const root = new URL('../ios/', import.meta.url);
const plist = path => JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', fileURLToPath(new URL(path, root))], { encoding: 'utf8' }));
const options = { skip: process.platform !== 'darwin' };
function graph() {
  const project = plist('Runner.xcodeproj/project.pbxproj');
  const objects = project.objects;
  const app = Object.values(objects).find(o => o.isa === 'PBXNativeTarget' && o.name === 'Runner');
  const widget = Object.values(objects).find(o => o.isa === 'PBXNativeTarget' && o.name === 'CoupleDaysWidget');
  return { project, objects, app, widget };
}
test('production widget is a dependency embedded before Flutter thinning', options, () => {
  const { objects, app, widget } = graph();
  assert.ok(widget);
  assert.equal(widget.productType, 'com.apple.product-type.app-extension');
  assert.ok(app.dependencies.some(id => objects[objects[id].target] === widget));
  const phases = app.buildPhases.map(id => objects[id]);
  const index = phases.findIndex(p => p.name === 'Embed Foundation Extensions');
  assert.ok(index >= 0);
  assert.ok(index < phases.findIndex(p => p.name === 'Thin Binary'));
  assert.equal(Number(phases[index].dstSubfolderSpec), 13);
  assert.ok(phases[index].files.some(id => objects[id].fileRef === widget.productReference));
});
test('host and extension share store code without linking Flutter into the extension', options, () => {
  const { objects, app, widget } = graph();
  const sources = target => target.buildPhases.map(id => objects[id]).filter(p => p.isa === 'PBXSourcesBuildPhase').flatMap(p => p.files.map(id => objects[objects[id].fileRef].path));
  for (const target of [app, widget]) {
    assert.ok(sources(target).includes('CoupleWidgetStore.swift'));
    assert.ok(sources(target).includes('CoupleWidgetContainer.swift'));
  }
  assert.ok(sources(app).includes('CoupleWidgetPlugin.swift'));
  assert.ok(!sources(widget).includes('CoupleWidgetPlugin.swift'));
  const config = readFileSync(new URL('CoupleDaysWidget/Widget.xcconfig', root), 'utf8');
  assert.match(config, /#include "\.\.\/Flutter\/Generated\.xcconfig"/);
  assert.doesNotMatch(config, /#include.*Pods/);
  assert.ok(widget.buildPhases.map(id => objects[id]).filter(p => p.isa === 'PBXFrameworksBuildPhase').every(p => p.files.length === 0));
});
test('all configurations use matching app-group entitlements and widget version values', options, () => {
  const { objects, app, widget } = graph();
  const paths = [[app, 'Runner/Runner.entitlements'], [widget, 'CoupleDaysWidget/CoupleDaysWidget.entitlements']];
  const groups = [];
  for (const [target, expected] of paths) {
    const configs = objects[target.buildConfigurationList].buildConfigurations.map(id => objects[id]);
    assert.deepEqual(configs.map(c => c.name).sort(), ['Debug', 'Profile', 'Release']);
    for (const config of configs) assert.equal(config.buildSettings.CODE_SIGN_ENTITLEMENTS, expected);
    groups.push(plist(expected)['com.apple.security.application-groups']);
  }
  assert.deepEqual(groups[0], ['group.com.yunitrish.taiwanbrawl.coupledays']);
  assert.deepEqual(groups[1], groups[0]);
  for (const id of objects[widget.buildConfigurationList].buildConfigurations) {
    const settings = objects[id].buildSettings;
    assert.equal(settings.APPLICATION_EXTENSION_API_ONLY, 'YES');
    assert.equal(settings.PRODUCT_BUNDLE_IDENTIFIER, 'com.yunitrish.taiwanbrawl.CoupleDaysWidget');
  }
  const appInfo = plist('Runner/Info.plist'), widgetInfo = plist('CoupleDaysWidget/Info.plist');
  for (const key of ['CFBundleVersion', 'CFBundleShortVersionString']) assert.equal(widgetInfo[key], appInfo[key]);
  assert.equal(widgetInfo.NSExtension.NSExtensionPointIdentifier, 'com.apple.widgetkit-extension');
});
test('widget URL is registered separately and preserves Google callback settings', options, () => {
  const schemes = plist('Runner/Info.plist').CFBundleURLTypes.flatMap(t => t.CFBundleURLSchemes);
  assert.ok(schemes.includes('taiwanbrawl-widget'));
  assert.ok(schemes.includes('$(GOOGLE_IOS_REVERSED_CLIENT_ID)'));
});
test('widget resources include all three language tables', options, () => {
  const { objects, widget } = graph();
  const resourceFiles = widget.buildPhases.map(id => objects[id]).filter(p => p.isa === 'PBXResourcesBuildPhase').flatMap(p => p.files.map(id => objects[objects[id].fileRef]));
  const strings = resourceFiles.find(o => o.isa === 'PBXVariantGroup' && o.name === 'Localizable.strings');
  assert.ok(strings);
  assert.deepEqual(strings.children.map(id => objects[id].name).sort(), ['en', 'ja', 'zh-Hant']);
  for (const id of strings.children) {
    const table = readFileSync(new URL('CoupleDaysWidget/' + objects[id].path, root), 'utf8');
    for (const key of ['widget.days', 'widget.unbound', 'widget.signedOut']) assert.ok(table.includes('"' + key + '"'));
  }
});
