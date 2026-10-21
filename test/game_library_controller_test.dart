import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_archery/archery_game_module.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';
import 'package:taiwan_brawl/game_modules/game_resource_migrations.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

GameModuleManifest _manifest({
  List<GameResourceManifest> resources = const [],
}) => GameModuleManifest(
  moduleId: 'game.archery',
  displayName: 'Archery',
  description: 'Archery game',
  packageVersion: '1.0.0',
  minimumShellVersion: '1.0.0',
  dataSchemaVersion: 1,
  resources: resources,
);

class _MemoryGameLibraryStore implements GameLibraryStore {
  Set<String> enabled = {};
  final Map<String, GameResourceInstallRecord> resources = {};

  @override
  Future<Set<String>> readEnabledModuleIds() async => Set.of(enabled);

  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {
    enabled = Set.of(moduleIds);
  }

  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      Map.of(resources);

  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    resources['${record.moduleId}:${record.resourceId}'] = record;
  }

  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    resources.remove('$moduleId:$resourceId');
  }
}

void main() {
  test('catalog metadata and expiry publish as one controller state', () {
    final controller = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
    );
    addTearDown(controller.dispose);
    controller.replaceRemoteManifests(
      bundledGameCatalog.manifests,
      expiresAt: DateTime.utc(2000),
    );
    final observedInstallability = <bool>[];
    controller.addListener(() {
      observedInstallability.add(controller.canInstallRemoteResources);
    });

    controller.replaceRemoteManifests(
      bundledGameCatalog.manifests,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    expect(observedInstallability, [isTrue]);
  });

  test('bundled peer games use their package-owned module versions', () {
    final archery = bundledGameCatalog['game.archery']!;
    final miniRoyale = bundledGameCatalog['game.mini-royale']!;

    expect(archery.packageVersion, archeryGameManifest.packageVersion);
    expect(miniRoyale.packageVersion, miniRoyaleManifest.packageVersion);
    expect(
      miniRoyale.multiplayer?.protocolVersion,
      miniRoyaleManifest.protocolVersion,
    );
    expect(miniRoyale.multiplayer?.rulesetId, miniRoyaleManifest.rulesetId);
    expect(
      miniRoyale.multiplayer?.gameplayContentDigest,
      miniRoyaleManifest.gameplayContentDigest,
    );
  });

  test('every bundled payload schema has its package validator wired', () {
    for (final module in bundledGameCatalog.manifests) {
      for (final resourceId in module.supportedResourceSchemas.keys) {
        expect(
          gameResourceMigrations,
          contains('${module.moduleId}:$resourceId'),
        );
      }
    }
  });

  test('catalog rejects duplicate module IDs', () {
    expect(
      () => GameModuleCatalog([_manifest(), _manifest()]),
      throwsFormatException,
    );
  });

  test('module dependencies are versioned, typed, and unique', () {
    final manifest = GameModuleManifest(
      moduleId: 'game.archery',
      displayName: 'Archery',
      description: 'Archery game',
      packageVersion: '1.0.0',
      minimumShellVersion: '1.0.0',
      dataSchemaVersion: 1,
      dependencies: const [
        GameModuleDependency(
          kind: GameDependencyKind.module,
          id: 'game.social',
          versionRange: '>=1.0.0 <2.0.0',
        ),
      ],
      resources: [],
    );
    final restored = GameModuleManifest.fromJson(manifest.toJson());
    expect(restored.dependencies.single.id, 'game.social');
    expect(restored.dependencies.single.acceptsVersion('1.3.0'), isTrue);
    expect(
      restored.dependencies.single.acceptsVersion('1.3.0+build.7'),
      isTrue,
    );
    expect(
      restored.dependencies.single.acceptsVersion('1.3.0-alpha.10'),
      isTrue,
    );
    expect(restored.dependencies.single.acceptsVersion('1.0.0-alpha'), isFalse);
    expect(restored.dependencies.single.acceptsVersion('1.3.0-01'), isFalse);
    expect(restored.dependencies.single.acceptsVersion('2.0.0'), isFalse);
    expect(restored.hostApiRange, '>=1.0.0 <2.0.0');
    expect(restored.supportsHostApiVersion(gameHostApiVersion), isTrue);
    expect(restored.publisher, 'taiwan-brawl');
    expect(restored.manifestVersion, 1);
    expect(
      () => GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Archery game',
        packageVersion: '1.0.0',
        minimumShellVersion: '1.0.0',
        dataSchemaVersion: 1,
        hostApiRange: '>=2.0.0 <1.0.0',
        dependencies: const [
          GameModuleDependency(
            kind: GameDependencyKind.module,
            id: 'game.social',
            versionRange: '>=2.0.0 <1.0.0',
          ),
        ],
        resources: [],
      ),
      throwsFormatException,
    );
    expect(
      () => GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Archery game',
        packageVersion: '1.0.0',
        minimumShellVersion: '1.0.0',
        dataSchemaVersion: 1,
        dependencies: const [
          GameModuleDependency(
            kind: GameDependencyKind.module,
            id: 'game.archery',
            versionRange: '>=1.0.0 <2.0.0',
          ),
        ],
        resources: [],
      ),
      throwsFormatException,
    );
  });

  test(
    'SemVer range bounds preserve arbitrarily large numeric identifiers',
    () {
      const dependency = GameModuleDependency(
        kind: GameDependencyKind.module,
        id: 'game.chat',
        versionRange: '>=9007199254740992.0.0 <9007199254740993.0.0',
      );
      dependency.validate('game.consumer');
      expect(dependency.acceptsVersion('9007199254740992.0.0'), isTrue);
      expect(dependency.acceptsVersion('9007199254740993.0.0'), isFalse);
    },
  );

  test(
    'module activation respects required but not optional dependencies',
    () async {
      final store = _MemoryGameLibraryStore();
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([
          GameModuleManifest(
            moduleId: 'game.archery',
            displayName: 'Archery',
            description: 'Archery game',
            packageVersion: '1.0.0',
            minimumShellVersion: '1.0.0',
            dataSchemaVersion: 1,
            dependencies: const [
              GameModuleDependency(
                kind: GameDependencyKind.module,
                id: 'game.mini-royale',
                versionRange: '>=0.1.0 <1.0.0',
              ),
              GameModuleDependency(
                kind: GameDependencyKind.module,
                id: 'game.social',
                versionRange: '>=1.0.0 <2.0.0',
                optional: true,
              ),
            ],
            resources: [],
          ),
          GameModuleManifest(
            moduleId: 'game.mini-royale',
            displayName: 'Mini Royale',
            description: 'Strategy game',
            packageVersion: '0.2.0',
            minimumShellVersion: '1.0.0',
            dataSchemaVersion: 1,
            resources: [],
          ),
        ]),
        store: store,
      );
      await controller.initialize();
      await expectLater(
        controller.setModuleEnabled('game.archery', true),
        throwsStateError,
      );
      await controller.setModuleEnabled('game.mini-royale', true);
      await controller.setModuleEnabled('game.archery', true);
      await expectLater(
        controller.setModuleEnabled('game.mini-royale', false),
        throwsStateError,
      );
    },
  );

  test('module activation honors resource dependency version ranges', () async {
    Future<GameLibraryController> controllerWithInstalledVersion(
      String installedVersion,
    ) async {
      final store = _MemoryGameLibraryStore();
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([
          _manifest(
            resources: [
              GameResourceManifest(
                resourceId: 'game.archery.rules',
                version: '2.0.0',
                kind: GameResourceKind.gameplayData,
                sha256: _digest,
                affectsGameplay: true,
              ),
            ],
          ),
          GameModuleManifest(
            moduleId: 'game.consumer',
            displayName: 'Consumer',
            description: 'Uses compatible Archery rules',
            packageVersion: '1.0.0',
            minimumShellVersion: '1.0.0',
            dataSchemaVersion: 1,
            dependencies: const [
              GameModuleDependency(
                kind: GameDependencyKind.resource,
                id: 'game.archery.rules',
                versionRange: '>=1.0.0 <2.0.0',
              ),
            ],
            resources: [],
          ),
        ]),
        store: store,
      );
      await controller.initialize();
      await controller.recordResourceState(
        GameResourceInstallRecord(
          moduleId: 'game.archery',
          resourceId: 'game.archery.rules',
          version: installedVersion,
          sha256: _digest,
          status: GameResourceInstallStatus.installed,
        ),
      );
      return controller;
    }

    final compatible = await controllerWithInstalledVersion('1.5.0');
    await compatible.setModuleEnabled('game.consumer', true);
    expect(compatible.isModuleEnabled('game.consumer'), isTrue);

    final incompatible = await controllerWithInstalledVersion('2.0.0');
    await expectLater(
      incompatible.setModuleEnabled('game.consumer', true),
      throwsStateError,
    );
  });

  test('module activation rejects an incompatible host API range', () async {
    final controller = GameLibraryController(
      catalog: GameModuleCatalog([
        GameModuleManifest(
          moduleId: 'game.archery',
          displayName: 'Archery',
          description: 'Archery game',
          packageVersion: '1.0.0',
          minimumShellVersion: '1.0.0',
          hostApiRange: '>=2.0.0 <3.0.0',
          dataSchemaVersion: 1,
          resources: [],
        ),
      ]),
      store: _MemoryGameLibraryStore(),
    );
    await controller.initialize();
    await expectLater(
      controller.setModuleEnabled('game.archery', true),
      throwsStateError,
    );
  });

  test(
    'module activation and resources honor declared target platforms',
    () async {
      final manifest = GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Archery game',
        packageVersion: '1.0.0',
        minimumShellVersion: '1.0.0',
        dataSchemaVersion: 1,
        platforms: const [GamePlatform.ios],
        resources: const [
          GameResourceManifest(
            resourceId: 'game.archery.ios-assets',
            version: '1.0.0',
            kind: GameResourceKind.presentation,
            sha256: _digest,
            affectsGameplay: false,
            platforms: [GamePlatform.ios],
          ),
        ],
      );
      final serializedManifest = manifest.toJson();
      final restoredManifest = GameModuleManifest.fromJson(serializedManifest);
      expect(restoredManifest.platforms, [GamePlatform.ios]);
      expect(restoredManifest.resources.single.platforms, [GamePlatform.ios]);
      expect(
        () => GameModuleManifest(
          moduleId: 'game.archery',
          displayName: 'Archery',
          description: 'Archery game',
          packageVersion: '1.0.0',
          minimumShellVersion: '1.0.0',
          dataSchemaVersion: 1,
          platforms: const [GamePlatform.ios],
          resources: const [
            GameResourceManifest(
              resourceId: 'game.archery.android-assets',
              version: '1.0.0',
              kind: GameResourceKind.presentation,
              sha256: _digest,
              affectsGameplay: false,
              platforms: [GamePlatform.android],
            ),
          ],
        ),
        throwsFormatException,
      );

      final controller = GameLibraryController(
        catalog: GameModuleCatalog([manifest]),
        store: _MemoryGameLibraryStore(),
      );
      await controller.initialize();
      if (currentGamePlatform != GamePlatform.ios) {
        await expectLater(
          controller.setModuleEnabled('game.archery', true),
          throwsStateError,
        );
      }
    },
  );

  test('remote catalog can update resources but not bundled game identity', () {
    final controller = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
    );
    final bundledArchery = bundledGameCatalog['game.archery']!;
    final bundledContract = bundledGameCatalog['game.mini-royale']!.multiplayer;

    controller.mergeRemoteManifests([
      GameModuleManifest(
        moduleId: 'game.mini-royale',
        displayName: 'Spoofed game name',
        description: 'Updated resource metadata',
        packageVersion: '99.0.0',
        minimumShellVersion: '99.0.0',
        publisher: 'spoofed-publisher',
        hostApiRange: '>=99.0.0 <100.0.0',
        dependencies: const [
          GameModuleDependency(
            kind: GameDependencyKind.module,
            id: 'game.spoofed',
            versionRange: '>=99.0.0 <100.0.0',
          ),
        ],
        dataSchemaVersion: 99,
        resources: const [],
      ),
      GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Spoofed Archery',
        description: 'Spoofed description',
        packageVersion: '99.0.0',
        minimumShellVersion: '99.0.0',
        dataSchemaVersion: 99,
        resources: const [],
      ),
    ]);

    final mergedArchery = controller.catalog['game.archery']!;
    expect(mergedArchery.displayName, bundledArchery.displayName);
    expect(mergedArchery.description, bundledArchery.description);
    expect(mergedArchery.manifestVersion, bundledArchery.manifestVersion);
    expect(mergedArchery.publisher, bundledArchery.publisher);
    expect(mergedArchery.hostApiRange, bundledArchery.hostApiRange);
    expect(mergedArchery.dependencies, bundledArchery.dependencies);
    expect(mergedArchery.packageVersion, bundledArchery.packageVersion);
    expect(
      mergedArchery.minimumShellVersion,
      bundledArchery.minimumShellVersion,
    );
    expect(mergedArchery.dataSchemaVersion, bundledArchery.dataSchemaVersion);
    final mergedRoyale = controller.catalog['game.mini-royale']!;
    expect(mergedRoyale.packageVersion, '0.1.0');
    expect(mergedRoyale.dataSchemaVersion, 1);
    expect(mergedRoyale.multiplayer, bundledContract);
  });

  test('remote resource schemas must be implemented by the owning package', () {
    final controller = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
    );
    GameModuleManifest remoteResource(int schemaVersion) => GameModuleManifest(
      moduleId: 'game.mini-royale',
      displayName: 'Remote name is ignored',
      description: 'Remote description is ignored',
      packageVersion: '9.9.9',
      minimumShellVersion: '1.0.0',
      dataSchemaVersion: 99,
      resources: [
        GameResourceManifest(
          resourceId: 'game.mini-royale.gameplay-rules',
          version: '1.0.0',
          kind: GameResourceKind.gameplayData,
          sha256: _digest,
          affectsGameplay: true,
          payloadSchemaVersion: schemaVersion,
        ),
      ],
    );

    expect(
      () => controller.mergeRemoteManifests([remoteResource(2)]),
      throwsFormatException,
    );
    expect(controller.catalog['game.mini-royale']!.resources, isEmpty);

    controller.mergeRemoteManifests([remoteResource(1)]);
    expect(
      controller
          .catalog['game.mini-royale']!
          .resources
          .single
          .payloadSchemaVersion,
      1,
    );
    expect(
      controller
          .catalog['game.mini-royale']!
          .supportedResourceSchemas['game.mini-royale.gameplay-rules'],
      1,
    );
  });

  test('bundled Archery owner schema allows its declared rules pack', () {
    final controller = GameLibraryController(
      catalog: bundledGameCatalog,
      store: _MemoryGameLibraryStore(),
    );
    final remote = GameModuleManifest(
      moduleId: archeryGameModuleId,
      displayName: 'Remote name is ignored',
      description: 'Remote description is ignored',
      packageVersion: '9.9.9',
      minimumShellVersion: '1.0.0',
      dataSchemaVersion: 99,
      resources: [
        GameResourceManifest(
          resourceId: archeryRulesResourceId,
          version: '1.0.0',
          kind: GameResourceKind.gameplayData,
          sha256: _digest,
          affectsGameplay: true,
          payloadSchemaVersion: 1,
        ),
      ],
    );

    controller.mergeRemoteManifests([remote]);

    final installedContract = controller.catalog[archeryGameModuleId]!;
    expect(
      installedContract.supportedResourceSchemas[archeryRulesResourceId],
      1,
    );
    expect(installedContract.resources.single.payloadSchemaVersion, 1);
  });

  test('multiplayer manifests validate the protocol and content contract', () {
    const valid = GameMultiplayerManifest(
      protocolVersion: 1,
      compatibleProtocolRange: '>=1 <2',
      rulesetId: 'mini-royale-ranked',
      rulesetVersion: 1,
      gameplayContentDigest: 'builtin-royale-rules-v1',
    );
    valid.validate();
    final parsed = GameModuleManifest.fromJson({
      'moduleId': 'game.mini-royale',
      'displayName': 'Mini Royale',
      'description': 'Multiplayer game',
      'packageVersion': '0.1.0',
      'minimumShellVersion': '0.132.0',
      'dataSchemaVersion': 1,
      'resources': <Object>[],
      'multiplayer': valid.toJson(),
    });
    expect(parsed.multiplayer?.rulesetId, 'mini-royale-ranked');
    expect(parsed.multiplayer?.compatibleProtocolRange, '>=1 <2');
    expect(
      () => const GameMultiplayerManifest(
        protocolVersion: 1,
        compatibleProtocolRange: '>=2 <3',
        rulesetId: 'mini-royale-ranked',
        rulesetVersion: 1,
        gameplayContentDigest: 'bad-digest',
      ).validate(),
      throwsFormatException,
    );
  });

  test('manifest enforces game-owned versioned resource IDs and digests', () {
    expect(
      () => _manifest(
        resources: const [
          GameResourceManifest(
            resourceId: 'game.other.content',
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256: _digest,
            affectsGameplay: true,
          ),
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => _manifest(
        resources: const [
          GameResourceManifest(
            resourceId: 'game.archery.content',
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256: _digest,
            affectsGameplay: true,
            dependencies: [
              GameModuleDependency(
                kind: GameDependencyKind.resource,
                id: 'game.archery.content',
                versionRange: '>=1.0.0 <2.0.0',
              ),
            ],
          ),
        ],
      ),
      throwsFormatException,
    );
  });

  test('module selections survive controller recreation', () async {
    final store = _MemoryGameLibraryStore();
    final catalog = GameModuleCatalog([_manifest()]);
    final first = GameLibraryController(catalog: catalog, store: store);
    await first.initialize();
    await first.setModuleEnabled('game.archery', true);

    final restored = GameLibraryController(catalog: catalog, store: store);
    await restored.initialize();
    expect(restored.isModuleEnabled('game.archery'), isTrue);
    expect(restored.isModuleEnabled('game.mini-royale'), isFalse);
  });

  test('detects an available resource update by version or digest', () async {
    const oldResource = GameResourceManifest(
      resourceId: 'game.archery.rules',
      version: '1.0.0',
      kind: GameResourceKind.gameplayData,
      sha256: _digest,
      affectsGameplay: true,
    );
    final newerResource = GameResourceManifest(
      resourceId: oldResource.resourceId,
      version: '2.0.0',
      kind: oldResource.kind,
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      affectsGameplay: true,
    );
    final store = _MemoryGameLibraryStore()
      ..resources['game.archery:${oldResource.resourceId}'] =
          const GameResourceInstallRecord(
            moduleId: 'game.archery',
            resourceId: 'game.archery.rules',
            version: '1.0.0',
            sha256: _digest,
            status: GameResourceInstallStatus.installed,
          );
    final controller = GameLibraryController(
      catalog: GameModuleCatalog([
        _manifest(resources: [oldResource]),
      ]),
      store: store,
    );
    await controller.initialize();

    expect(
      controller.isResourceUpdateAvailable('game.archery', oldResource),
      isFalse,
    );
    controller.mergeRemoteManifests([
      _manifest(resources: [newerResource]),
    ]);
    expect(
      controller.isResourceUpdateAvailable('game.archery', newerResource),
      isTrue,
    );
  });

  test(
    'withdrawn installed resources remain removable but cannot be fetched again',
    () async {
      const withdrawn = GameResourceManifest(
        resourceId: 'game.archery.rules',
        version: '1.0.0',
        kind: GameResourceKind.gameplayData,
        sha256: _digest,
        affectsGameplay: true,
        downloadUrl: 'https://assets.example.test/archery/rules/1.0.0',
        byteLength: 32,
        signature: 'signed-resource',
        signingKeyId: 'release-key',
      );
      final store = _MemoryGameLibraryStore()
        ..resources['game.archery:${withdrawn.resourceId}'] =
            const GameResourceInstallRecord(
              moduleId: 'game.archery',
              resourceId: 'game.archery.rules',
              version: '1.0.0',
              sha256: _digest,
              status: GameResourceInstallStatus.installed,
            );
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([
          _manifest(resources: [withdrawn]),
        ]),
        store: store,
      );
      await controller.initialize();

      controller.mergeRemoteManifests([_manifest()]);

      final retained = controller.catalog['game.archery']!.resources.single;
      expect(retained.resourceId, withdrawn.resourceId);
      expect(retained.downloadUrl, isNull);
      expect(retained.signature, isNull);
      expect(
        controller.resourceRecord('game.archery', withdrawn.resourceId)?.status,
        GameResourceInstallStatus.installed,
      );
      expect(
        controller.isResourceUpdateAvailable('game.archery', retained),
        isFalse,
      );
    },
  );

  test(
    'resource lifecycle rejects skipping integrity and migration stages',
    () async {
      final manifest = _manifest(
        resources: const [
          GameResourceManifest(
            resourceId: 'game.archery.content',
            version: '1.0.0',
            kind: GameResourceKind.gameplayData,
            sha256: _digest,
            affectsGameplay: true,
          ),
        ],
      );
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([manifest]),
        store: _MemoryGameLibraryStore(),
      );
      await controller.initialize();

      Future<void> record(GameResourceInstallStatus status) =>
          controller.recordResourceState(
            GameResourceInstallRecord(
              moduleId: 'game.archery',
              resourceId: 'game.archery.content',
              version: '1.0.0',
              sha256: _digest,
              status: status,
            ),
          );

      await record(GameResourceInstallStatus.queued);
      await expectLater(
        record(GameResourceInstallStatus.installed),
        throwsStateError,
      );
      await record(GameResourceInstallStatus.downloading);
      await record(GameResourceInstallStatus.verifying);
      await record(GameResourceInstallStatus.migrating);
      await record(GameResourceInstallStatus.installed);
      expect(
        controller
            .resourceRecord('game.archery', 'game.archery.content')
            ?.status,
        GameResourceInstallStatus.installed,
      );
      await record(GameResourceInstallStatus.removing);
      await record(GameResourceInstallStatus.removing);
      await expectLater(
        record(GameResourceInstallStatus.installed),
        throwsStateError,
      );
    },
  );
}
