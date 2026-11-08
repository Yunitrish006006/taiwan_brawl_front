import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/game_modules/game_module_manifest.dart';
import 'package:taiwan_brawl/game_modules/street_scrap_hive_progress_store.dart';
import 'package:taiwan_brawl/services/game_library_store.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  final libraryBox = 'game_library_web_$suffix';
  final contentBox = 'game_resource_web_content_$suffix';
  final pointerBox = 'game_resource_web_pointer_$suffix';

  if (kIsWeb) setUpAll(Hive.initFlutter);
  if (kIsWeb) tearDownAll(Hive.close);

  test(
    'Web IndexedDB persists installed Street Scrap pack state and bytes',
    () async {
      const moduleId = 'game.street-scrap';
      const resourceId = 'game.street-scrap.art.wood-board';
      const resourceVersion = '0.1.0';
      const resourceDigest =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final manifest = GameModuleManifest(
        moduleId: moduleId,
        displayName: 'Street Scrap',
        description: 'Browser storage test',
        packageVersion: '0.1.0',
        minimumShellVersion: '0.132.0',
        dataSchemaVersion: 1,
        resources: [
          GameResourceManifest(
            resourceId: resourceId,
            version: resourceVersion,
            kind: GameResourceKind.presentation,
            sha256: resourceDigest,
            affectsGameplay: false,
            required: false,
          ),
        ],
      );
      final library = HiveGameLibraryStore(boxName: libraryBox);
      await library.writeEnabledModuleIds({moduleId});
      await library.writeCachedResourceCatalog(
        CachedGameResourceCatalog(manifests: [manifest]),
      );
      await library.writeResourceRecord(
        const GameResourceInstallRecord(
          moduleId: moduleId,
          resourceId: resourceId,
          version: resourceVersion,
          sha256: resourceDigest,
          status: GameResourceInstallStatus.installed,
          payloadSchemaVersion: 1,
        ),
      );

      final bytes = Uint8List.fromList([0, 1, 2, 128, 255]);
      final content = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      await content.writeStaged(moduleId, resourceId, resourceVersion, bytes);
      await content.activate(moduleId, resourceId, resourceVersion);

      // Force a fresh IndexedDB connection instead of reading through Hive's
      // already-open boxes, which would not prove persistence across reload.
      await Hive.close();
      await Hive.initFlutter();

      final restoredLibrary = HiveGameLibraryStore(boxName: libraryBox);
      final restoredContent = HiveGameResourceContentStore(
        contentBoxName: contentBox,
        pointerBoxName: pointerBox,
      );
      expect(await restoredLibrary.readEnabledModuleIds(), {moduleId});
      expect(
        (await restoredLibrary.readCachedResourceCatalog())!.manifests.single
            .toJson(),
        manifest.toJson(),
      );
      expect(
        (await restoredLibrary.readResourceRecords())['$moduleId:$resourceId']
            ?.status,
        GameResourceInstallStatus.installed,
      );
      expect(
        await restoredContent.readActiveVersion(moduleId, resourceId),
        resourceVersion,
      );
      expect(await restoredContent.readActive(moduleId, resourceId), bytes);
    },
    skip: !kIsWeb,
  );

  test(
    'Street Scrap Hive save and two-revision recovery history survive IndexedDB reopen',
    () async {
      final store = HiveStreetScrapProgressStore(
        boxName: 'street_scrap_web_$suffix',
      );
      final slotKey = 'profile:test-web-reopen';
      final first = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.21',
        },
        revision: 1,
        savedAt: DateTime.utc(2026, 10, 23),
        state: const {
          'chapter': 4,
          'backpackCapacity': 16,
          'tutorialTasks': {'q4.01': true},
        },
        commandReceipts: const {},
      );
      expect(
        await store.compareAndSwap(
          slotKey: slotKey,
          expectedRevision: null,
          nextSnapshot: first.toJson(),
        ),
        isTrue,
      );
      final second = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.21',
          'game.street-scrap.content.chapter-5': '0.1.19',
        },
        revision: 2,
        savedAt: DateTime.utc(2026, 10, 23, 1),
        state: const {
          'chapter': 5,
          'backpackCapacity': 24,
          'tutorialTasks': {'q4.01': true, 'q5.01': true},
        },
        commandReceipts: const {},
      );
      expect(
        await store.compareAndSwap(
          slotKey: slotKey,
          expectedRevision: 1,
          nextSnapshot: second.toJson(),
        ),
        isTrue,
      );

      await Hive.close();
      await Hive.initFlutter();

      final restoredStore = HiveStreetScrapProgressStore(
        boxName: 'street_scrap_web_$suffix',
      );
      final restored = StreetScrapProgressSnapshot.fromJson(
        (await restoredStore.read(slotKey))!,
      );
      expect(restored.revision, 2);
      expect(restored.contentVersions, second.contentVersions);
      expect(restored.state['chapter'], 5);
      expect(restored.state['backpackCapacity'], 24);
      final recovery = await restoredStore.inspectRecovery(slotKey);
      expect(recovery.currentSnapshotIsDamaged, isFalse);
      expect(
        recovery.candidates.map((candidate) => candidate.snapshot.revision),
        [2, 1],
      );
    },
    skip: !kIsWeb,
  );

  test(
    'installed local Street Scrap data and gameplay save remain readable after IndexedDB reopen without publisher access',
    () async {
      const moduleId = 'game.street-scrap';
      const resourceId = 'game.street-scrap.content.chapters-0-4';
      const resourceVersion = '0.1.21';
      const profileScope = 'profile:offline-browser-reopen';
      final content = HiveGameResourceContentStore(
        contentBoxName: 'street_scrap_offline_content_$suffix',
        pointerBoxName: 'street_scrap_offline_pointer_$suffix',
      );
      final saves = HiveStreetScrapProgressStore(
        boxName: 'street_scrap_offline_saves_$suffix',
      );
      final initialSession = StreetScrapSession(
        profileScope: profileScope,
        store: saves,
        contentVersions: const {resourceId: resourceVersion},
        rulesetVersion: 1,
      );
      final payload = Uint8List.fromList([0x53, 0x53, 0x2d, 0x30, 0x34]);
      await content.writeStaged(moduleId, resourceId, resourceVersion, payload);
      await content.activate(moduleId, resourceId, resourceVersion);

      final snapshot = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {resourceId: resourceVersion},
        revision: 1,
        savedAt: DateTime.utc(2026, 10, 25),
        state: const {
          'chapter': 3,
          'stamina': 42,
          'tutorialTasks': {'q3.01': true},
        },
        commandReceipts: const {},
      );
      expect(
        await saves.compareAndSwap(
          slotKey: initialSession.slotKey,
          expectedRevision: null,
          nextSnapshot: snapshot.toJson(),
        ),
        isTrue,
      );
      await initialSession.close();

      // No catalog source or HTTP client is constructed: gameplay reads only
      // from the locally activated pack and the profile's IndexedDB save.
      await Hive.close();
      await Hive.initFlutter();

      final reopenedContent = HiveGameResourceContentStore(
        contentBoxName: 'street_scrap_offline_content_$suffix',
        pointerBoxName: 'street_scrap_offline_pointer_$suffix',
      );
      final reopenedSaves = HiveStreetScrapProgressStore(
        boxName: 'street_scrap_offline_saves_$suffix',
      );
      expect(
        await reopenedContent.readActiveVersion(moduleId, resourceId),
        resourceVersion,
      );
      expect(await reopenedContent.readActive(moduleId, resourceId), payload);

      final session = StreetScrapSession(
        profileScope: profileScope,
        store: reopenedSaves,
        contentVersions: const {resourceId: resourceVersion},
        rulesetVersion: 1,
      );
      await session.load();
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['chapter'], 3);
      expect(session.snapshot.state['stamina'], 42);
      expect(session.snapshot.state['tutorialTasks'], {'q3.01': true});
      await session.close();
    },
    skip: !kIsWeb,
  );
}
