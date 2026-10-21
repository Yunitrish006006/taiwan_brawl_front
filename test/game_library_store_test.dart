import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/services/game_library_controller.dart';
import 'package:taiwan_brawl/game_modules/bundled_game_catalog.dart';

void main() {
  late Directory directory;
  const boxName = 'game_library_round_trip_test';
  const record = GameResourceInstallRecord(
    moduleId: 'game.archery',
    resourceId: 'game.archery.content',
    version: '1.2.0',
    sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    status: GameResourceInstallStatus.installed,
    downloadedBytes: 128,
    totalBytes: 128,
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('game-library-hive-');
    Hive.init(directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('module choices and resource versions persist locally', () async {
    final store = HiveGameLibraryStore(boxName: boxName);
    await store.writeEnabledModuleIds({'game.archery'});
    await store.writeResourceRecord(record);
    final raw = await Hive.openBox<String>(boxName);
    expect(raw.keys, contains('resource:game.archery:game.archery.content'));

    final restored = HiveGameLibraryStore(boxName: boxName);
    expect(await restored.readEnabledModuleIds(), {'game.archery'});
    expect(
      (await restored
              .readResourceRecords())['game.archery:game.archery.content']
          ?.toJson(),
      record.toJson(),
    );

    await restored.removeResourceRecord('game.archery', 'game.archery.content');
    expect(await restored.readResourceRecords(), isEmpty);
  });

  test(
    'installed resource bytes and catalog survive a Hive close and reopen',
    () async {
      const contentBox = 'game_resource_native_content_restart_test';
      const pointerBox = 'game_resource_native_pointer_restart_test';
      final manifest = GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Native restart persistence',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: const [
          GameResourceManifest(
            resourceId: 'game.archery.rules',
            version: '1.2.0',
            kind: GameResourceKind.gameplayData,
            sha256:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            affectsGameplay: true,
          ),
        ],
      );
      final bytes = Uint8List.fromList([0, 10, 127, 128, 255]);

      await HiveGameLibraryStore(
        boxName: boxName,
      ).writeEnabledModuleIds({'game.archery'});
      await HiveGameLibraryStore(boxName: boxName).writeCachedResourceCatalog(
        CachedGameResourceCatalog(manifests: [manifest]),
      );
      final content = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      await content.writeStaged(
        'game.archery',
        'game.archery.rules',
        '1.2.0',
        bytes,
      );
      await content.activate('game.archery', 'game.archery.rules', '1.2.0');

      await Hive.close();
      Hive.init(directory.path);

      final restoredLibrary = HiveGameLibraryStore(boxName: boxName);
      final restoredContent = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      expect(await restoredLibrary.readEnabledModuleIds(), {'game.archery'});
      expect(
        (await restoredLibrary.readCachedResourceCatalog())!.manifests.single
            .toJson(),
        manifest.toJson(),
      );
      expect(
        await restoredContent.readActiveVersion(
          'game.archery',
          'game.archery.rules',
        ),
        '1.2.0',
      );
      expect(
        await restoredContent.readActive('game.archery', 'game.archery.rules'),
        bytes,
      );
    },
  );

  test(
    'cache envelope survives restart but download metadata needs verification',
    () async {
      var now = DateTime.utc(2029);
      final resource = GameResourceManifest(
        resourceId: 'game.archery.rules',
        version: '1.0.0',
        kind: GameResourceKind.gameplayData,
        sha256: 'a' * 64,
        affectsGameplay: true,
        downloadUrl: 'https://example.test/rules',
        byteLength: 12,
        signature: 'signed-payload',
        signingKeyId: 'release-1',
      );
      final manifest = GameModuleManifest(
        moduleId: 'game.archery',
        displayName: 'Archery',
        description: 'Archery resources',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: [resource],
      );
      const signedEnvelope = <String, dynamic>{
        'envelopeVersion': 1,
        'publisher': 'taiwan-brawl',
        'signingKeyId': 'release-1',
        'issuedAt': '2029-01-01T00:00:00.000Z',
        'expiresAt': '2030-01-01T00:00:00.000Z',
        'payload': {'catalogVersion': 1, 'modules': <Object>[]},
        'signature': 'unverified-test-envelope',
      };
      await HiveGameLibraryStore(boxName: boxName).writeCachedResourceCatalog(
        CachedGameResourceCatalog(
          manifests: [manifest],
          issuedAt: DateTime.utc(2029, 1, 1),
          expiresAt: DateTime.utc(2030),
          signedEnvelope: signedEnvelope,
        ),
      );

      final restored = HiveGameLibraryStore(boxName: boxName);
      expect(
        (await restored.readCachedResourceCatalog())!.manifests.single.toJson(),
        manifest.toJson(),
      );
      expect(
        (await restored.readCachedResourceCatalog())!.signedEnvelope,
        signedEnvelope,
      );
      final controller = GameLibraryController(
        catalog: bundledGameCatalog,
        store: restored,
        clock: () => now,
      );
      await controller.initialize();
      expect(controller.catalog['game.archery']!.resources, isEmpty);
      expect(controller.remoteCatalogExpiresAt, isNull);
      expect(controller.remoteCatalogIssuedAt, isNull);
      expect(controller.canInstallRemoteResources, isFalse);
      controller.replaceRemoteManifests(
        [manifest],
        issuedAt: DateTime.utc(2029, 1, 1),
        expiresAt: DateTime.utc(2030),
      );
      expect(controller.canInstallRemoteResources, isTrue);
      expect(
        () => controller.replaceRemoteManifests(
          [manifest],
          issuedAt: DateTime.utc(2028, 12, 31),
          expiresAt: DateTime.utc(2031),
        ),
        throwsFormatException,
      );
      expect(controller.remoteCatalogIssuedAt, DateTime.utc(2029, 1, 1));
      now = DateTime.utc(2031);
      expect(controller.canInstallRemoteResources, isFalse);
      controller.dispose();
    },
  );

  test('corrupt cached catalog is ignored', () async {
    final raw = await Hive.openBox<String>(boxName);
    await raw.put('resource_catalog', '{invalid');
    expect(
      await HiveGameLibraryStore(boxName: boxName).readCachedResourceCatalog(),
      isNull,
    );
  });

  test(
    'resource activation is versioned and leaves the prior pack readable',
    () async {
      final content = HiveGameResourceContentStore(
        contentBoxName: 'game_resource_bytes_round_trip_test',
        pointerBoxName: 'game_resource_pointer_round_trip_test',
      );
      final oldBytes = Uint8List.fromList([1, 2, 3]);
      final newBytes = Uint8List.fromList([4, 5, 6]);

      await content.writeStaged(
        'game.archery',
        'game.archery.content',
        '1.0.0',
        oldBytes,
      );
      await content.activate('game.archery', 'game.archery.content', '1.0.0');
      await content.writeStaged(
        'game.archery',
        'game.archery.content',
        '2.0.0',
        newBytes,
      );
      await content.writeStagedChunk(
        'game.archery',
        'game.archery.content',
        '3.0.0',
        0,
        Uint8List.fromList([7, 8]),
      );

      expect(
        await content.readActive('game.archery', 'game.archery.content'),
        oldBytes,
      );
      await content.activate('game.archery', 'game.archery.content', '2.0.0');
      expect(
        await content.readActive('game.archery', 'game.archery.content'),
        newBytes,
      );
      final resumedAfterRestart = HiveGameResourceContentStore(
        contentBoxName: 'game_resource_bytes_round_trip_test',
        pointerBoxName: 'game_resource_pointer_round_trip_test',
      );
      expect(
        await resumedAfterRestart.readStagedChunks(
          'game.archery',
          'game.archery.content',
          '3.0.0',
        ),
        [
          Uint8List.fromList([7, 8]),
        ],
      );
      await content.remove('game.archery', 'game.archery.content');
      expect(
        await content.readActive('game.archery', 'game.archery.content'),
        isNull,
      );
    },
  );

  test(
    'resource set activation switches multiple version pointers together',
    () async {
      final content = HiveGameResourceContentStore(
        contentBoxName: 'game_resource_set_content_test',
        pointerBoxName: 'game_resource_set_pointer_test',
      );
      final ids = ['game.royale.cards', 'game.royale.rules'];
      for (final id in ids) {
        await content.writeStaged(
          'game.mini-royale',
          id,
          '1.0.0',
          Uint8List.fromList([1]),
        );
      }
      await content.activateSet('game.mini-royale', {
        for (final id in ids) id: '1.0.0',
      });

      await content.writeStaged(
        'game.mini-royale',
        ids[0],
        '2.0.0',
        Uint8List.fromList([2]),
      );
      await content.writeStaged(
        'game.mini-royale',
        ids[1],
        '2.0.0',
        Uint8List.fromList([2]),
      );
      expect(await content.readActiveSet('game.mini-royale'), {
        for (final id in ids) id: '1.0.0',
      });

      await content.activateSet('game.mini-royale', {
        for (final id in ids) id: '2.0.0',
      });
      expect(await content.readActiveSet('game.mini-royale'), {
        for (final id in ids) id: '2.0.0',
      });
      for (final id in ids) {
        expect(
          await content.readActive('game.mini-royale', id),
          Uint8List.fromList([2]),
        );
      }
    },
  );

  test(
    'removing a resource set clears its pointers, versions, and staging',
    () async {
      const moduleId = 'game.mini-royale';
      final ids = ['game.mini-royale.cards', 'game.mini-royale.rules'];
      final content = HiveGameResourceContentStore(
        contentBoxName: 'game_resource_set_remove_content_test',
        pointerBoxName: 'game_resource_set_remove_pointer_test',
      );
      for (final id in ids) {
        await content.writeStaged(
          moduleId,
          id,
          '1.0.0',
          Uint8List.fromList([1]),
        );
        await content.writeStaged(
          moduleId,
          id,
          '2.0.0',
          Uint8List.fromList([2]),
        );
        await content.writeStagedChunk(
          moduleId,
          id,
          '3.0.0',
          0,
          Uint8List.fromList([3]),
        );
      }
      await content.activateSet(moduleId, {for (final id in ids) id: '2.0.0'});

      await content.removeSet(moduleId, ids);

      expect(await content.readActiveSet(moduleId), isEmpty);
      for (final id in ids) {
        expect(await content.readActive(moduleId, id), isNull);
        expect(await content.readStagedChunks(moduleId, id, '3.0.0'), isEmpty);
      }
      final stored = await Hive.openBox<Uint8List>(
        'game_resource_set_remove_content_test',
      );
      expect(stored.keys, isEmpty);
    },
  );
}
