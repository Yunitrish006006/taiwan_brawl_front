import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/config/app_configuration.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/game_modules/archery_rules_resource_source.dart';
import 'package:taiwan_brawl/game_modules/game_resource_migrations.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_catalog_source.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl/services/game_resource_installer.dart';
import 'package:taiwan_brawl/services/game_resource_library_service.dart';
import 'package:taiwan_brawl/game_modules/mini_royale/arena_presentation_source.dart';
import 'package:taiwan_brawl_game_archery/archery_game_module.dart'
    show archeryRulesResourceId;
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart'
    show ArcheryRules;
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    show miniRoyaleArenaPresentationResourceId;
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

class _MemoryLibraryStore implements GameLibraryStore {
  final Map<String, GameResourceInstallRecord> records = {};

  @override
  Future<Set<String>> readEnabledModuleIds() async => {};

  @override
  Future<void> writeEnabledModuleIds(Set<String> moduleIds) async {}

  @override
  Future<Map<String, GameResourceInstallRecord>> readResourceRecords() async =>
      Map.of(records);

  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    records['${record.moduleId}:${record.resourceId}'] = record;
  }

  @override
  Future<void> removeResourceRecord(String moduleId, String resourceId) async {
    records.remove('$moduleId:$resourceId');
  }
}

class _MemoryContentStore implements GameResourceContentStore {
  bool failRemoval = false;
  int activationCount = 0;
  final Map<String, Map<String, String>> activeSets = {};
  final Map<String, Uint8List> activeBytesByResource = {};
  final Map<String, Uint8List> staged = {};
  final Map<String, Uint8List> cachedPayloads = {};
  final Map<String, Map<int, Uint8List>> stagedChunks = {};

  String _key(String moduleId, String resourceId, String version) =>
      '$moduleId:$resourceId:$version';

  String _activeKey(String moduleId, String resourceId) =>
      '$moduleId:$resourceId';

  Uint8List? get activeBytes =>
      activeBytesByResource[_activeKey('game.archery', 'game.archery.content')];
  set activeBytes(Uint8List? bytes) {
    const moduleId = 'game.archery';
    const resourceId = 'game.archery.content';
    final activeKey = _activeKey(moduleId, resourceId);
    if (bytes == null) {
      activeBytesByResource.remove(activeKey);
      return;
    }
    activeBytesByResource[activeKey] = bytes;
    final version = activeSets[moduleId]?[resourceId];
    if (version != null) {
      cachedPayloads[_key(moduleId, resourceId, version)] = bytes;
    }
  }

  String? get activeVersion =>
      activeSets['game.archery']?['game.archery.content'];
  set activeVersion(String? version) {
    if (version == null) {
      activeSets['game.archery']?.remove('game.archery.content');
    } else {
      (activeSets['game.archery'] ??= {})['game.archery.content'] = version;
    }
  }

  @override
  Future<void> writeStaged(
    String moduleId,
    String resourceId,
    String version,
    Uint8List bytes,
  ) async => staged[_key(moduleId, resourceId, version)] = bytes;

  @override
  Future<void> activate(
    String moduleId,
    String resourceId,
    String version,
  ) async {
    final versions = await readActiveSet(moduleId);
    versions[resourceId] = version;
    await activateSet(moduleId, versions);
  }

  @override
  Future<void> activateSet(
    String moduleId,
    Map<String, String> versions,
  ) async {
    final nextBytes = <String, Uint8List>{};
    for (final entry in versions.entries) {
      final bytes = staged[_key(moduleId, entry.key, entry.value)];
      if (bytes != null) {
        cachedPayloads[_key(moduleId, entry.key, entry.value)] = bytes;
        nextBytes[_activeKey(moduleId, entry.key)] = bytes;
      } else if (cachedPayloads[_key(moduleId, entry.key, entry.value)] !=
          null) {
        nextBytes[_activeKey(moduleId, entry.key)] =
            cachedPayloads[_key(moduleId, entry.key, entry.value)]!;
      } else {
        throw StateError('No staged payload for ${entry.key}@${entry.value}.');
      }
    }
    // Swap the whole map at once, matching the production pointer-set commit.
    activationCount++;
    activeSets[moduleId] = Map.of(versions);
    activeBytesByResource
      ..removeWhere(
        (key, _) =>
            key.startsWith('$moduleId:') &&
            !versions.keys.any(
              (resourceId) => key == _activeKey(moduleId, resourceId),
            ),
      )
      ..addAll(nextBytes);
    for (final entry in versions.entries) {
      staged.remove(_key(moduleId, entry.key, entry.value));
      stagedChunks.remove(_key(moduleId, entry.key, entry.value));
    }
  }

  @override
  Future<Uint8List?> readActive(String moduleId, String resourceId) async =>
      activeBytesByResource[_activeKey(moduleId, resourceId)];

  @override
  Future<List<Uint8List>> readStagedChunks(
    String moduleId,
    String resourceId,
    String version,
  ) async =>
      (stagedChunks[_key(moduleId, resourceId, version)]?.entries.toList()
            ?..sort((a, b) => a.key.compareTo(b.key)))
          ?.map((entry) => entry.value)
          .toList() ??
      [];

  @override
  Future<void> writeStagedChunk(
    String moduleId,
    String resourceId,
    String version,
    int index,
    Uint8List bytes,
  ) async {
    (stagedChunks[_key(moduleId, resourceId, version)] ??= {})[index] = bytes;
  }

  @override
  Future<String?> readActiveVersion(String moduleId, String resourceId) async =>
      (await readActiveSet(moduleId))[resourceId];

  @override
  Future<Map<String, String>> readActiveSet(String moduleId) async =>
      Map.of(activeSets[moduleId] ?? {});

  @override
  Future<void> restoreActiveVersion(
    String moduleId,
    String resourceId,
    String? version,
  ) async {
    final versions = await readActiveSet(moduleId);
    if (version == null) {
      versions.remove(resourceId);
      activeBytesByResource.remove(_activeKey(moduleId, resourceId));
    } else {
      versions[resourceId] = version;
      activeBytesByResource[_activeKey(
        moduleId,
        resourceId,
      )] = Uint8List.fromList(
        utf8.encode(version == '1.0.0' ? 'old-data' : 'new-data'),
      );
    }
    await restoreActiveSet(moduleId, versions);
  }

  @override
  Future<void> restoreActiveSet(
    String moduleId,
    Map<String, String> versions,
  ) async {
    activeSets[moduleId] = Map.of(versions);
    activeBytesByResource.removeWhere((key, _) => key.startsWith('$moduleId:'));
    for (final entry in versions.entries) {
      final bytes = cachedPayloads[_key(moduleId, entry.key, entry.value)];
      if (bytes == null) throw StateError('Missing cached test payload.');
      activeBytesByResource[_activeKey(moduleId, entry.key)] = bytes;
    }
  }

  @override
  Future<void> discardStaged(
    String moduleId,
    String resourceId,
    String version,
  ) async {
    staged.remove(_key(moduleId, resourceId, version));
    stagedChunks.remove(_key(moduleId, resourceId, version));
  }

  @override
  Future<void> remove(String moduleId, String resourceId) async {
    await removeSet(moduleId, [resourceId]);
  }

  @override
  Future<void> removeSet(String moduleId, List<String> resourceIds) async {
    if (failRemoval) throw StateError('simulated content-store failure');
    activeSets[moduleId]?.removeWhere((id, _) => resourceIds.contains(id));
    activeBytesByResource.removeWhere(
      (key, _) => resourceIds.any((id) => key == _activeKey(moduleId, id)),
    );
  }
}

class _SignatureVerifier implements GameResourceSignatureVerifier {
  _SignatureVerifier(this.valid);

  final bool valid;

  @override
  Future<bool> verify({
    required String keyId,
    required String signature,
    required String moduleId,
    required String resourceId,
    required String version,
    required String sha256,
    required Uint8List payload,
  }) async => valid && keyId == 'test-key' && signature == 'test-signature';
}

class _MemoryCredentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

const _payload = 'gameplay-data-v1';
final _bytes = Uint8List.fromList(utf8.encode(_payload));
final _digest = sha256.convert(_bytes).toString();

GameResourceManifest _resource({
  String? digest,
  String version = '1.0.0',
  String resourceId = 'game.archery.content',
  Uint8List? payload,
  List<GameModuleDependency> dependencies = const [],
  String signature = 'test-signature',
  String? activationGroup,
  int? payloadSchemaVersion,
}) => GameResourceManifest(
  resourceId: resourceId,
  version: version,
  kind: GameResourceKind.gameplayData,
  sha256: digest ?? sha256.convert(payload ?? _bytes).toString(),
  affectsGameplay: true,
  payloadSchemaVersion: payloadSchemaVersion,
  dependencies: dependencies,
  activationGroup: activationGroup,
  downloadUrl:
      'https://assets.example.test/${resourceId.replaceAll('.', '/')}/$version.json',
  byteLength: (payload ?? _bytes).length,
  signature: signature,
  signingKeyId: 'test-key',
);

Future<GameLibraryController> _controller(
  GameResourceManifest resource,
  _MemoryLibraryStore store, {
  List<GameResourceManifest> additionalResources = const [],
  Map<String, int> supportedResourceSchemas = const {},
}) async {
  final controller = GameLibraryController(
    catalog: GameModuleCatalog([
      GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Test module',
        packageVersion: '1.0.0',
        minimumShellVersion: '1.0.0',
        dataSchemaVersion: 1,
        supportedResourceSchemas: supportedResourceSchemas,
        resources: [resource, ...additionalResources],
      ),
    ]),
    store: store,
  );
  await controller.initialize();
  return controller;
}

GameResourceInstaller _installer({
  required GameLibraryController controller,
  required GameResourceContentStore content,
  required bool signatureIsValid,
  Uint8List? payload,
  http.Client? client,
}) => GameResourceInstaller(
  controller: controller,
  contentStore: content,
  signatureVerifier: _SignatureVerifier(signatureIsValid),
  client:
      client ??
      MockClient((_) async => http.Response.bytes(payload ?? _bytes, 200)),
);

({GameResourceLibraryService service, GameResourceInstaller installer})
_resourceLibrary({
  required GameLibraryController controller,
  required GameResourceContentStore content,
  Uint8List? payload,
  Map<String, GameResourceMigration>? resourceMigrations,
  http.Client? client,
}) {
  final installer = _installer(
    controller: controller,
    content: content,
    signatureIsValid: true,
    payload: payload,
    client: client,
  );
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{}', 200)),
    credentials: _MemoryCredentials(),
    configuration: const AppConfiguration(
      apiBaseUrl: 'https://example.test',
      googleWebClientId: '',
      googleServerClientId: '',
      p2pChatEnabled: false,
      previewMode: true,
      peerVerificationEnabled: false,
    ),
  );
  return (
    service: GameResourceLibraryService(
      controller: controller,
      catalogSource: GameResourceCatalogSource(api),
      installer: installer,
      contentStore: content,
      resourceMigrations: resourceMigrations ?? gameResourceMigrations,
    ),
    installer: installer,
  );
}

void main() {
  test(
    'Hive persists resource install, failed-update rollback, update and removal',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'game-resource-lifecycle-',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      final suffix = DateTime.now().microsecondsSinceEpoch;
      const moduleId = 'game.archery';
      const resourceId = 'game.archery.content';
      final firstPayload = Uint8List.fromList(utf8.encode('rules-v1'));
      final secondPayload = Uint8List.fromList(utf8.encode('rules-v2'));
      final firstResource = _resource(
        resourceId: resourceId,
        version: '1.0.0',
        payload: firstPayload,
      );
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([
          GameModuleManifest(
            moduleId: moduleId,
            displayName: 'Archery',
            description: 'Hive-backed lifecycle test.',
            packageVersion: '0.1.0',
            minimumShellVersion: '0.132.0',
            dataSchemaVersion: 1,
            resources: [firstResource],
          ),
        ]),
        store: HiveGameLibraryStore(boxName: 'library_$suffix'),
      );
      final content = HiveGameResourceContentStore(
        contentBoxName: 'content_$suffix',
        pointerBoxName: 'pointers_$suffix',
      );
      await controller.initialize();
      await controller.setModuleEnabled(moduleId, true);
      await _resourceLibrary(
        controller: controller,
        content: content,
        payload: firstPayload,
      ).service.install(moduleId, resourceId);

      final secondResource = _resource(
        resourceId: resourceId,
        version: '2.0.0',
        payload: secondPayload,
      );
      final secondManifest = GameModuleManifest(
        moduleId: moduleId,
        displayName: 'Archery',
        description: 'Hive-backed lifecycle test.',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: [secondResource],
      );
      controller.mergeRemoteManifests([secondManifest]);
      await expectLater(
        _resourceLibrary(
          controller: controller,
          content: content,
          payload: secondPayload,
          resourceMigrations: {
            '$moduleId:$resourceId': (_) async =>
                throw StateError('fixture migration failure'),
          },
        ).service.install(moduleId, resourceId),
        throwsStateError,
      );
      expect(await content.readActiveVersion(moduleId, resourceId), '1.0.0');
      expect(await content.readActive(moduleId, resourceId), firstPayload);

      await _resourceLibrary(
        controller: controller,
        content: content,
        payload: secondPayload,
      ).service.install(moduleId, resourceId);
      expect(await content.readActiveVersion(moduleId, resourceId), '2.0.0');
      await Hive.close();
      Hive.init(directory.path);

      final restoredStore = HiveGameLibraryStore(boxName: 'library_$suffix');
      final restoredContent = HiveGameResourceContentStore(
        contentBoxName: 'content_$suffix',
        pointerBoxName: 'pointers_$suffix',
      );
      final restoredController = GameLibraryController(
        catalog: GameModuleCatalog([secondManifest]),
        store: restoredStore,
      );
      await restoredController.initialize();
      expect(restoredController.enabledModuleIds, {moduleId});
      expect(
        restoredController.resourceRecord(moduleId, resourceId)?.version,
        '2.0.0',
      );
      expect(
        await restoredContent.readActiveVersion(moduleId, resourceId),
        '2.0.0',
      );
      expect(
        await restoredContent.readActive(moduleId, resourceId),
        secondPayload,
      );
      await _resourceLibrary(
        controller: restoredController,
        content: restoredContent,
        payload: secondPayload,
      ).service.remove(moduleId, resourceId);
      expect(
        await restoredContent.readActiveVersion(moduleId, resourceId),
        isNull,
      );
      expect(restoredController.resourceRecord(moduleId, resourceId), isNull);
      expect(restoredController.isModuleEnabled(moduleId), isTrue);
      restoredController.dispose();
      controller.dispose();
    },
    skip: kIsWeb
        ? 'Uses dart:io temporary directories; Web persistence is covered separately.'
        : false,
  );

  test(
    'a peer game can be selected, install and update its own pack, then remove it',
    () async {
      const moduleId = 'game.fixture';
      const resourceId = 'game.fixture.rules';
      final firstPayload = Uint8List.fromList(utf8.encode('fixture-rules-v1'));
      final secondPayload = Uint8List.fromList(utf8.encode('fixture-rules-v2'));
      final firstResource = _resource(
        resourceId: resourceId,
        version: '1.0.0',
        payload: firstPayload,
      );
      final controller = GameLibraryController(
        catalog: GameModuleCatalog([
          GameModuleManifest(
            moduleId: moduleId,
            displayName: 'Fixture Game',
            description: 'Synthetic peer module acceptance fixture.',
            packageVersion: '1.0.0',
            minimumShellVersion: '1.0.0',
            dataSchemaVersion: 1,
            resources: [firstResource],
          ),
          GameModuleManifest(
            moduleId: 'game.archery',
            displayName: 'Archery',
            description: 'Unrelated peer module.',
            packageVersion: '1.0.0',
            minimumShellVersion: '1.0.0',
            dataSchemaVersion: 1,
            resources: const [],
          ),
        ]),
        store: _MemoryLibraryStore(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      await controller.setModuleEnabled(moduleId, true);

      final content = _MemoryContentStore();
      final firstService = _resourceLibrary(
        controller: controller,
        content: content,
        payload: firstPayload,
      ).service;
      await firstService.install(moduleId, resourceId);

      expect(await content.readActiveVersion(moduleId, resourceId), '1.0.0');
      expect(await content.readActive(moduleId, resourceId), firstPayload);
      expect(
        controller.resourceRecord(moduleId, resourceId)?.status,
        GameResourceInstallStatus.installed,
      );
      expect(controller.isModuleEnabled(moduleId), isTrue);
      expect(controller.resourceRecord('game.archery', resourceId), isNull);
      expect(await content.readActiveSet('game.archery'), isEmpty);

      final secondResource = _resource(
        resourceId: resourceId,
        version: '2.0.0',
        payload: secondPayload,
      );
      controller.mergeRemoteManifests([
        GameModuleManifest(
          moduleId: moduleId,
          displayName: 'Fixture Game',
          description: 'Synthetic peer module acceptance fixture.',
          packageVersion: '1.0.0',
          minimumShellVersion: '1.0.0',
          dataSchemaVersion: 1,
          resources: [secondResource],
        ),
      ]);
      expect(
        controller.isResourceUpdateAvailable(
          moduleId,
          controller.catalog[moduleId]!.resources.single,
        ),
        isTrue,
      );

      final updateService = _resourceLibrary(
        controller: controller,
        content: content,
        payload: secondPayload,
      ).service;
      await updateService.install(moduleId, resourceId);
      expect(await content.readActiveVersion(moduleId, resourceId), '2.0.0');
      expect(await content.readActive(moduleId, resourceId), secondPayload);
      expect(
        controller.resourceRecord(moduleId, resourceId)?.sha256,
        sha256.convert(secondPayload).toString(),
      );

      await updateService.remove(moduleId, resourceId);
      expect(await content.readActiveVersion(moduleId, resourceId), isNull);
      expect(await content.readActive(moduleId, resourceId), isNull);
      expect(controller.resourceRecord(moduleId, resourceId), isNull);
      expect(controller.isModuleEnabled(moduleId), isTrue);
      expect(await content.readActiveSet('game.archery'), isEmpty);
    },
  );

  test(
    'Mini Royale presentation adapter reads only active resource bytes',
    () async {
      final content = _MemoryContentStore();
      final source = GameResourceMiniRoyaleArenaPresentationSource(
        contentStore: content,
      );
      const moduleId = 'game.mini-royale';
      const payload =
          '{"schemaVersion":1,"fieldColors":["#FF000001","#FF000002","#FF000003","#FF000004"]}';

      expect(await source.readActivePresentationJson(), isNull);
      content.activeBytesByResource['$moduleId:$miniRoyaleArenaPresentationResourceId'] =
          Uint8List.fromList(utf8.encode(payload));
      expect(await source.readActivePresentationJson(), payload);

      content.activeBytesByResource.remove(
        '$moduleId:$miniRoyaleArenaPresentationResourceId',
      );
      expect(await source.readActivePresentationJson(), isNull);
    },
  );

  test(
    'activated Archery rules are read by the game adapter then disappear on removal',
    () async {
      final rulesJson = jsonEncode({
        ...ArcheryRules.builtIn.toJson(),
        'version': 'season-7',
        'targetMovesAtScore': 350,
      });
      final payload = Uint8List.fromList(utf8.encode(rulesJson));
      final content = _MemoryContentStore();
      final resource = _resource(
        resourceId: archeryRulesResourceId,
        version: '7.0.0',
        payload: payload,
      );
      final controller = await _controller(resource, _MemoryLibraryStore());
      final service = _resourceLibrary(
        controller: controller,
        content: content,
        payload: payload,
      ).service;
      final source = GameResourceArcheryRulesSource(contentStore: content);

      await service.install('game.archery', archeryRulesResourceId);
      expect(
        ArcheryRules.decode((await source.readActiveRulesJson())!).version,
        'season-7',
      );
      expect(
        controller
            .resourceRecord('game.archery', archeryRulesResourceId)
            ?.status,
        GameResourceInstallStatus.installed,
      );

      await service.remove('game.archery', archeryRulesResourceId);
      expect(await source.readActiveRulesJson(), isNull);
      expect(
        controller.resourceRecord('game.archery', archeryRulesResourceId),
        isNull,
      );
    },
  );

  test(
    'malformed signed Archery rules cannot replace the active version',
    () async {
      const moduleId = 'game.archery';
      final previousPayload = Uint8List.fromList(
        utf8.encode(jsonEncode(ArcheryRules.builtIn.toJson())),
      );
      final invalidPayload = Uint8List.fromList(
        utf8.encode('{"schemaVersion":2,"unsafeScript":"run()"}'),
      );
      final resource = _resource(
        resourceId: archeryRulesResourceId,
        version: '7.0.0',
        payload: invalidPayload,
        payloadSchemaVersion: 1,
      );
      final controller = await _controller(resource, _MemoryLibraryStore());
      final content = _MemoryContentStore();
      await content.writeStaged(
        moduleId,
        archeryRulesResourceId,
        '6.0.0',
        previousPayload,
      );
      await content.activate(moduleId, archeryRulesResourceId, '6.0.0');
      final service = _resourceLibrary(
        controller: controller,
        content: content,
        payload: invalidPayload,
      ).service;

      await expectLater(
        service.install(moduleId, archeryRulesResourceId),
        throwsFormatException,
      );

      expect(
        await content.readActiveVersion(moduleId, archeryRulesResourceId),
        '6.0.0',
      );
      expect(
        await content.readActive(moduleId, archeryRulesResourceId),
        previousPayload,
      );
    },
  );

  test(
    'owner-supported schemas fail closed without a package validator',
    () async {
      final resource = _resource(
        resourceId: archeryRulesResourceId,
        payloadSchemaVersion: 1,
      );
      final controller = await _controller(
        resource,
        _MemoryLibraryStore(),
        supportedResourceSchemas: {archeryRulesResourceId: 1},
      );
      final content = _MemoryContentStore();
      final service = _resourceLibrary(
        controller: controller,
        content: content,
        resourceMigrations: const {},
      ).service;

      await expectLater(
        service.install('game.archery', archeryRulesResourceId),
        throwsStateError,
      );
      expect(content.activationCount, 0);
    },
  );

  test('related resources become active in one set commit', () async {
    final store = _MemoryLibraryStore();
    final base = _resource();
    final dependent = _resource(
      resourceId: 'game.archery.extended',
      dependencies: const [
        GameModuleDependency(
          kind: GameDependencyKind.resource,
          id: 'game.archery.content',
          versionRange: '>=1.0.0 <2.0.0',
        ),
      ],
    );
    final controller = await _controller(
      base,
      store,
      additionalResources: [dependent],
    );
    final content = _MemoryContentStore();
    final installer = _installer(
      controller: controller,
      content: content,
      signatureIsValid: true,
    );

    await installer.installSet('game.archery', [
      base.resourceId,
      dependent.resourceId,
    ]);

    expect(content.activationCount, 1);
    expect(await content.readActiveSet('game.archery'), {
      base.resourceId: base.version,
      dependent.resourceId: dependent.version,
    });
    expect(
      controller.resourceRecord('game.archery', base.resourceId)?.status,
      GameResourceInstallStatus.installed,
    );
    expect(
      controller.resourceRecord('game.archery', dependent.resourceId)?.status,
      GameResourceInstallStatus.installed,
    );
    installer.dispose();
  });

  test(
    'installs a dependent pack using an older active version within range',
    () async {
      final store = _MemoryLibraryStore();
      final base = _resource(version: '2.0.0');
      final dependent = _resource(
        resourceId: 'game.archery.extended',
        dependencies: const [
          GameModuleDependency(
            kind: GameDependencyKind.resource,
            id: 'game.archery.content',
            versionRange: '>=1.0.0 <2.0.0',
          ),
        ],
      );
      final controller = await _controller(
        base,
        store,
        additionalResources: [dependent],
      );
      await controller.recordResourceState(
        GameResourceInstallRecord(
          moduleId: 'game.archery',
          resourceId: 'game.archery.content',
          version: '1.5.0',
          sha256: _digest,
          status: GameResourceInstallStatus.installed,
        ),
      );
      final content = _MemoryContentStore();
      await content.writeStaged(
        'game.archery',
        base.resourceId,
        '1.5.0',
        _bytes,
      );
      await content.activate('game.archery', base.resourceId, '1.5.0');
      final library = _resourceLibrary(
        controller: controller,
        content: content,
      );

      await library.service.install('game.archery', dependent.resourceId);

      expect(
        await content.readActiveVersion('game.archery', base.resourceId),
        '1.5.0',
      );
      expect(
        await content.readActiveVersion('game.archery', dependent.resourceId),
        dependent.version,
      );
      library.installer.dispose();
    },
  );

  test(
    'library single-resource actions install and remove the whole activation group',
    () async {
      final first = _resource(activationGroup: 'royale.core');
      final second = _resource(
        resourceId: 'game.archery.assets',
        activationGroup: 'royale.core',
      );
      final controller = await _controller(
        first,
        _MemoryLibraryStore(),
        additionalResources: [second],
      );
      final content = _MemoryContentStore();
      final library = _resourceLibrary(
        controller: controller,
        content: content,
      );

      await library.service.install('game.archery', first.resourceId);
      expect(content.activationCount, 1);
      expect(await content.readActiveSet('game.archery'), {
        first.resourceId: first.version,
        second.resourceId: second.version,
      });
      await library.service.remove('game.archery', first.resourceId);
      expect(await content.readActiveSet('game.archery'), isEmpty);
      expect(
        controller.resourceRecord('game.archery', second.resourceId),
        isNull,
      );
      library.installer.dispose();
    },
  );

  test(
    'a failed member of a resource set leaves the prior active set intact',
    () async {
      final store = _MemoryLibraryStore();
      final base = _resource(version: '2.0.0');
      final invalid = _resource(
        version: '2.0.0',
        resourceId: 'game.archery.extended',
        signature: 'invalid-signature',
      );
      final controller = await _controller(
        base,
        store,
        additionalResources: [invalid],
      );
      final content = _MemoryContentStore();
      await content.writeStaged(
        'game.archery',
        base.resourceId,
        '1.0.0',
        Uint8List.fromList(utf8.encode('old-data')),
      );
      await content.writeStaged(
        'game.archery',
        invalid.resourceId,
        '1.0.0',
        Uint8List.fromList(utf8.encode('old-data')),
      );
      await content.activateSet('game.archery', {
        base.resourceId: '1.0.0',
        invalid.resourceId: '1.0.0',
      });
      content.activationCount = 0;
      final installer = _installer(
        controller: controller,
        content: content,
        signatureIsValid: true,
      );

      await expectLater(
        installer.installSet('game.archery', [
          base.resourceId,
          invalid.resourceId,
        ]),
        throwsFormatException,
      );

      expect(content.activationCount, 0);
      expect(await content.readActiveSet('game.archery'), {
        base.resourceId: '1.0.0',
        invalid.resourceId: '1.0.0',
      });
      expect(
        await content.readActive('game.archery', base.resourceId),
        Uint8List.fromList(utf8.encode('old-data')),
      );
      installer.dispose();
    },
  );

  test(
    'resource pack cannot install before required verified dependencies',
    () async {
      final store = _MemoryLibraryStore();
      final base = _resource();
      final dependent = _resource(
        resourceId: 'game.archery.extended',
        dependencies: const [
          GameModuleDependency(
            kind: GameDependencyKind.resource,
            id: 'game.archery.content',
            versionRange: '>=1.0.0 <2.0.0',
          ),
        ],
      );
      final controller = await _controller(
        base,
        store,
        additionalResources: [dependent],
      );
      final content = _MemoryContentStore();
      final installer = _installer(
        controller: controller,
        content: content,
        signatureIsValid: true,
      );

      await expectLater(
        installer.install('game.archery', dependent.resourceId),
        throwsStateError,
      );
      expect(
        controller.resourceRecord('game.archery', dependent.resourceId),
        isNull,
      );
      installer.dispose();
    },
  );

  test(
    'rejects an in-range dependency whose active bytes do not match its record',
    () async {
      final base = _resource(version: '2.0.0');
      final dependent = _resource(
        resourceId: 'game.archery.extended',
        dependencies: const [
          GameModuleDependency(
            kind: GameDependencyKind.resource,
            id: 'game.archery.content',
            versionRange: '>=1.0.0 <2.0.0',
          ),
        ],
      );
      final controller = await _controller(
        base,
        _MemoryLibraryStore(),
        additionalResources: [dependent],
      );
      await controller.recordResourceState(
        GameResourceInstallRecord(
          moduleId: 'game.archery',
          resourceId: 'game.archery.content',
          version: '1.5.0',
          sha256: _digest,
          status: GameResourceInstallStatus.installed,
        ),
      );
      final content = _MemoryContentStore();
      await content.writeStaged(
        'game.archery',
        base.resourceId,
        '1.5.0',
        _bytes,
      );
      await content.activate('game.archery', base.resourceId, '1.5.0');
      content.activeBytes = Uint8List.fromList(utf8.encode('tampered'));
      final library = _resourceLibrary(
        controller: controller,
        content: content,
      );

      await expectLater(
        library.service.install('game.archery', dependent.resourceId),
        throwsStateError,
      );
      expect(
        controller.resourceRecord('game.archery', dependent.resourceId),
        isNull,
      );
      library.installer.dispose();
    },
  );

  test('required installed packs prevent removing their dependency', () async {
    final store = _MemoryLibraryStore();
    final base = _resource();
    final dependent = _resource(
      resourceId: 'game.archery.extended',
      dependencies: const [
        GameModuleDependency(
          kind: GameDependencyKind.resource,
          id: 'game.archery.content',
          versionRange: '>=1.0.0 <2.0.0',
        ),
      ],
    );
    final controller = await _controller(
      base,
      store,
      additionalResources: [dependent],
    );
    for (final status in [
      GameResourceInstallStatus.queued,
      GameResourceInstallStatus.downloading,
      GameResourceInstallStatus.verifying,
      GameResourceInstallStatus.migrating,
      GameResourceInstallStatus.installed,
    ]) {
      await controller.recordResourceState(
        GameResourceInstallRecord(
          moduleId: 'game.archery',
          resourceId: dependent.resourceId,
          version: dependent.version,
          sha256: dependent.sha256,
          status: status,
        ),
      );
    }
    final content = _MemoryContentStore();
    final library = _resourceLibrary(controller: controller, content: content);

    await expectLater(
      library.service.remove('game.archery', base.resourceId),
      throwsStateError,
    );
    expect(controller.resourceRecord('game.archery', base.resourceId), isNull);
    library.installer.dispose();
  });

  test('concurrent install then remove leaves the resource removed', () async {
    final controller = await _controller(_resource(), _MemoryLibraryStore());
    final content = _MemoryContentStore();
    final response = Completer<http.Response>();
    final requestStarted = Completer<void>();
    final library = _resourceLibrary(
      controller: controller,
      content: content,
      client: MockClient((_) {
        requestStarted.complete();
        return response.future;
      }),
    );

    final install = library.service.install(
      'game.archery',
      'game.archery.content',
    );
    await requestStarted.future;
    var removeCompleted = false;
    final remove = library.service
        .remove('game.archery', 'game.archery.content')
        .then((_) => removeCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(removeCompleted, isFalse);

    response.complete(http.Response.bytes(_bytes, 200));
    await Future.wait([install, remove]);

    expect(content.activeVersion, isNull);
    expect(content.activeBytes, isNull);
    expect(
      controller.resourceRecord('game.archery', 'game.archery.content'),
      isNull,
    );
    library.installer.dispose();
  });

  test(
    'failed resource removal stays non-compatible and can be retried',
    () async {
      final store = _MemoryLibraryStore();
      final controller = await _controller(_resource(), store);
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
      await record(GameResourceInstallStatus.downloading);
      await record(GameResourceInstallStatus.verifying);
      await record(GameResourceInstallStatus.migrating);
      await record(GameResourceInstallStatus.installed);

      final content = _MemoryContentStore()
        ..activeVersion = '1.0.0'
        ..activeBytes = Uint8List.fromList(_bytes)
        ..failRemoval = true;
      final library = _resourceLibrary(
        controller: controller,
        content: content,
      );

      await expectLater(
        library.service.remove('game.archery', 'game.archery.content'),
        throwsStateError,
      );
      expect(
        controller
            .resourceRecord('game.archery', 'game.archery.content')
            ?.status,
        GameResourceInstallStatus.removing,
      );
      expect(content.activeVersion, '1.0.0');

      content.failRemoval = false;
      await library.service.remove('game.archery', 'game.archery.content');
      expect(content.activeVersion, isNull);
      expect(
        controller.resourceRecord('game.archery', 'game.archery.content'),
        isNull,
      );
      library.installer.dispose();
    },
  );

  test('downloads, verifies, and activates a resource pack', () async {
    final controller = await _controller(
      _resource(payloadSchemaVersion: 3),
      _MemoryLibraryStore(),
    );
    final content = _MemoryContentStore();
    final installer = _installer(
      controller: controller,
      content: content,
      signatureIsValid: true,
    );

    await installer.install('game.archery', 'game.archery.content');

    expect(content.activeVersion, '1.0.0');
    expect(content.activeBytes, _bytes);
    expect(
      controller.resourceRecord('game.archery', 'game.archery.content')?.status,
      GameResourceInstallStatus.installed,
    );
    expect(
      controller
          .resourceRecord('game.archery', 'game.archery.content')
          ?.payloadSchemaVersion,
      3,
    );
    installer.dispose();
  });

  test(
    'rejects oversized resource responses before retaining extra bytes',
    () async {
      final controller = await _controller(_resource(), _MemoryLibraryStore());
      final content = _MemoryContentStore();
      final installer = GameResourceInstaller(
        controller: controller,
        contentStore: content,
        signatureVerifier: _SignatureVerifier(true),
        client: MockClient(
          (_) async => http.Response.bytes([..._bytes, 0xff], 200),
        ),
      );

      await expectLater(
        installer.install('game.archery', 'game.archery.content'),
        throwsFormatException,
      );

      expect(content.activeBytes, isNull);
      expect(
        await content.readStagedChunks(
          'game.archery',
          'game.archery.content',
          '1.0.0',
        ),
        isEmpty,
      );
      expect(
        controller
            .resourceRecord('game.archery', 'game.archery.content')
            ?.status,
        GameResourceInstallStatus.failed,
      );
      installer.dispose();
    },
  );

  test('resumes an interrupted download with an HTTP byte range', () async {
    final controller = await _controller(_resource(), _MemoryLibraryStore());
    final content = _MemoryContentStore();
    final firstInstaller = GameResourceInstaller(
      controller: controller,
      contentStore: content,
      signatureVerifier: _SignatureVerifier(true),
      client: MockClient(
        (_) async => http.Response.bytes(_bytes.sublist(0, 8), 200),
      ),
    );

    await expectLater(
      firstInstaller.install('game.archery', 'game.archery.content'),
      throwsFormatException,
    );
    expect(content.activeBytes, isNull);
    expect(
      (await content.readStagedChunks(
        'game.archery',
        'game.archery.content',
        '1.0.0',
      )).fold<int>(0, (sum, chunk) => sum + chunk.length),
      8,
    );
    firstInstaller.dispose();

    var rangeHeader = '';
    final resumedInstaller = GameResourceInstaller(
      controller: controller,
      contentStore: content,
      signatureVerifier: _SignatureVerifier(true),
      client: MockClient((request) async {
        rangeHeader = request.headers['range'] ?? '';
        return http.Response.bytes(
          _bytes.sublist(8),
          206,
          headers: {'content-range': 'bytes 8-15/${_bytes.length}'},
        );
      }),
    );

    await resumedInstaller.install('game.archery', 'game.archery.content');

    expect(rangeHeader, 'bytes=8-');
    expect(content.activeBytes, _bytes);
    expect(content.activeVersion, '1.0.0');
    resumedInstaller.dispose();
  });

  test(
    'rejects a resumed response with an inconsistent Content-Range end',
    () async {
      final controller = await _controller(_resource(), _MemoryLibraryStore());
      final content = _MemoryContentStore();
      final interruptedInstaller = GameResourceInstaller(
        controller: controller,
        contentStore: content,
        signatureVerifier: _SignatureVerifier(true),
        client: MockClient(
          (_) async => http.Response.bytes(_bytes.sublist(0, 8), 200),
        ),
      );
      await expectLater(
        interruptedInstaller.install('game.archery', 'game.archery.content'),
        throwsFormatException,
      );
      interruptedInstaller.dispose();

      final resumedInstaller = GameResourceInstaller(
        controller: controller,
        contentStore: content,
        signatureVerifier: _SignatureVerifier(true),
        client: MockClient(
          (_) async => http.Response.bytes(
            _bytes.sublist(8),
            206,
            headers: {'content-range': 'bytes 8-14/${_bytes.length}'},
          ),
        ),
      );

      await expectLater(
        resumedInstaller.install('game.archery', 'game.archery.content'),
        throwsFormatException,
      );
      expect(content.activeBytes, isNull);
      expect(
        (await content.readStagedChunks(
          'game.archery',
          'game.archery.content',
          '1.0.0',
        )).fold<int>(0, (sum, chunk) => sum + chunk.length),
        8,
      );
      resumedInstaller.dispose();
    },
  );

  test(
    'rejects a bad publisher signature and never activates the pack',
    () async {
      final controller = await _controller(_resource(), _MemoryLibraryStore());
      final content = _MemoryContentStore();
      final installer = _installer(
        controller: controller,
        content: content,
        signatureIsValid: false,
      );

      await expectLater(
        installer.install('game.archery', 'game.archery.content'),
        throwsFormatException,
      );

      expect(content.activeBytes, isNull);
      expect(content.staged, isEmpty);
      expect(
        controller
            .resourceRecord('game.archery', 'game.archery.content')
            ?.status,
        GameResourceInstallStatus.failed,
      );
      installer.dispose();
    },
  );

  test('rejects a digest mismatch before activation', () async {
    final controller = await _controller(
      _resource(
        digest:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      _MemoryLibraryStore(),
    );
    final content = _MemoryContentStore();
    final installer = _installer(
      controller: controller,
      content: content,
      signatureIsValid: true,
    );

    await expectLater(
      installer.install('game.archery', 'game.archery.content'),
      throwsFormatException,
    );

    expect(content.activeBytes, isNull);
    expect(content.staged, isEmpty);
    expect(
      controller.resourceRecord('game.archery', 'game.archery.content')?.status,
      GameResourceInstallStatus.failed,
    );
    installer.dispose();
  });

  test('failed migration preserves the previous active version', () async {
    final controller = await _controller(
      _resource(version: '2.0.0'),
      _MemoryLibraryStore(),
    );
    final content = _MemoryContentStore()
      ..activeVersion = '1.0.0'
      ..activeBytes = Uint8List.fromList(utf8.encode('old-data'));
    final oldBytes = content.activeBytes;
    final installer = _installer(
      controller: controller,
      content: content,
      signatureIsValid: true,
    );

    await expectLater(
      installer.install(
        'game.archery',
        'game.archery.content',
        migrate: (_) async => throw StateError('migration failed'),
      ),
      throwsStateError,
    );

    expect(content.activeVersion, '1.0.0');
    expect(content.activeBytes, oldBytes);
    expect(content.staged, isEmpty);
    installer.dispose();
  });

  test(
    'failed installed-state persistence rolls back the active pointer',
    () async {
      final store = _FailInstalledRecordStore();
      final controller = await _controller(_resource(version: '2.0.0'), store);
      final content = _MemoryContentStore()
        ..activeVersion = '1.0.0'
        ..activeBytes = Uint8List.fromList(utf8.encode('old-data'));
      final installer = _installer(
        controller: controller,
        content: content,
        signatureIsValid: true,
      );

      await expectLater(
        installer.install('game.archery', 'game.archery.content'),
        throwsStateError,
      );

      expect(content.activeVersion, '1.0.0');
      expect(utf8.decode(content.activeBytes!), 'old-data');
      expect(
        controller
            .resourceRecord('game.archery', 'game.archery.content')
            ?.status,
        GameResourceInstallStatus.failed,
      );
      installer.dispose();
    },
  );
}

class _FailInstalledRecordStore extends _MemoryLibraryStore {
  bool _failedOnce = false;

  @override
  Future<void> writeResourceRecord(GameResourceInstallRecord record) async {
    if (record.status == GameResourceInstallStatus.installed && !_failedOnce) {
      _failedOnce = true;
      throw StateError('simulated registry persistence failure');
    }
    await super.writeResourceRecord(record);
  }
}
