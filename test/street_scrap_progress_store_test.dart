import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/game_modules/street_scrap_hive_progress_store.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

void main() {
  late Directory directory;
  const boxName = 'street_scrap_progress_store_test';
  const slot = 'game.street-scrap/profile-digest/slot-1';
  var testIndex = 0;
  String uniqueSlot() => '$slot-${testIndex++}';

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('street-scrap-save-');
    Hive.init(directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  StreetScrapProgressSnapshot save(int revision) =>
      StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {'content': '0.1.0'},
        revision: revision,
        savedAt: DateTime.utc(2026, 10, 22, 0, 0, revision),
        state: {'value': revision},
        commandReceipts: const {},
      );

  test(
    'one-key save history keeps current and two valid previous snapshots',
    () async {
      final slotKey = uniqueSlot();
      final store = HiveStreetScrapProgressStore(boxName: boxName);
      for (var revision = 1; revision <= 4; revision++) {
        expect(
          await store.compareAndSwap(
            slotKey: slotKey,
            expectedRevision: revision == 1 ? null : revision - 1,
            nextSnapshot: save(revision).toJson(),
          ),
          isTrue,
        );
      }

      expect(
        (await store.inspectRecovery(
          slotKey,
        )).candidates.map((candidate) => candidate.snapshot.revision),
        [4, 3, 2],
      );
      expect((await store.read(slotKey))!['revision'], 4);
    },
  );

  test('completed sewing tutorial flags survive Hive session reopen', () async {
    final store = HiveStreetScrapProgressStore(boxName: boxName);
    final profile = 'q1-02-hive-reopen-${testIndex++}';
    final versions = const {'game.street-scrap.content.chapters-0-4': '0.1.0'};
    final tasks = const {
      'q1.01': true,
      'q1.02.unpicked': true,
      'q1.02.threadReady': true,
      'q1.02.sewn': true,
      'q1.02': true,
    };
    final first = StreetScrapSession(
      profileScope: profile,
      store: store,
      contentVersions: versions,
      rulesetVersion: 1,
    );
    await first.load();
    await first.apply(
      commandId: 'finish-q1-02',
      expectedRevision: 0,
      reduce: (state) =>
          StreetScrapReduction(state: {...state, 'tutorialTasks': tasks}),
    );
    await first.close();

    final reopened = StreetScrapSession(
      profileScope: profile,
      store: store,
      contentVersions: versions,
      rulesetVersion: 1,
    );
    await reopened.load();
    expect(reopened.snapshot.state['tutorialTasks'], tasks);
    await reopened.close();
  });

  test('q1.02 unpicking commits its inventory and task through Hive', () async {
    final store = HiveStreetScrapProgressStore(boxName: boxName);
    final profile = 'q1-02-hive-craft-${testIndex++}';
    const versions = {'game.street-scrap.content.chapters-0-4': '0.1.0'};
    const grids = {
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: {
        'cloth.rag_piece': const StreetScrapFootprint(1, 1),
        'cloth.edge_scrap': const StreetScrapFootprint(1, 1),
        'cloth.thread_end': const StreetScrapFootprint(1, 1),
        'tool.needle': const StreetScrapFootprint(1, 1),
      },
      packingRules: const {},
    );
    var inventory = catalog.emptyInventory(grids: grids);
    inventory = inventory.addAndPlaceFirstFit(
      catalog.createObject(
        instanceId: 'lesson-rag',
        itemId: 'cloth.rag_piece',
        source: 'tutorial:q1.02-rag',
        quality: 55,
        traits: const {},
      ),
      'backpack',
    );
    inventory = inventory.addAndPlaceFirstFit(
      catalog.createObject(
        instanceId: 'lesson-needle',
        itemId: 'tool.needle',
        source: 'tutorial:q1.02-needle',
        quality: 55,
        traits: const {},
      ),
      'backpack',
    );
    final session = StreetScrapSession(
      profileScope: profile,
      store: store,
      contentVersions: versions,
      rulesetVersion: 1,
    );
    await session.load();
    await session.applyInventoryCommand(
      commandId: 'seed-q1-02-hive',
      expectedRevision: 0,
      catalog: catalog,
      grids: grids,
      initialInventory: inventory,
      reduceInventory: (current) => current,
    );
    await session.apply(
      commandId: 'unlock-q1-02-hive',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 1,
          'tutorialTasks': const {'q1.01': true},
          'unlockedStations': const ['recycler'],
          'q1.02KitClaimed': true,
        },
      ),
    );

    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.unpick_cloth',
      phase: 1,
      station: 'recycler',
      operationId: 'unpick',
      durationSeconds: 10,
      instructions: '沿縫線拆線',
      inputGroups: const [
        [StreetScrapRecipeInput(itemId: 'cloth.rag_piece', quantity: 1)],
      ],
      reusableTools: const ['tool.needle'],
      outputs: const [
        StreetScrapRecipeInput(itemId: 'cloth.edge_scrap', quantity: 1),
        StreetScrapRecipeInput(itemId: 'cloth.thread_end', quantity: 2),
      ],
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: ['cloth.rag_piece'],
        loss: 10,
        mode: 'weighted-primary',
        masteryRevision: 1,
      ),
      retainedInputIds: const [],
      traitResolution: const {
        'inherit': [],
        'polarity': {},
        'success': {},
        'precise': {},
        'failure': {},
      },
      failureMode: 'explicitOutcome',
      failureOutcome: '材料已拆解',
      manualCheckpoints: const [],
    );
    await StreetScrapCrafting.craft(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: grids,
      gridId: 'backpack',
      inputGroupIndex: 0,
      inputInstanceIds: const ['lesson-rag'],
      toolInstanceIds: const ['lesson-needle'],
      commandId: 'q1-02-unpick-hive',
      expectedRevision: 2,
      manual: false,
      manualPoints: 0,
      outputInstanceId: (index) => 'q1-02-hive-output-$index',
    );
    expect(
      (session.snapshot.state['tutorialTasks']! as Map)['q1.02.unpicked'],
      isTrue,
    );
    await session.close();

    final reopened = StreetScrapSession(
      profileScope: profile,
      store: store,
      contentVersions: versions,
      rulesetVersion: 1,
    );
    await reopened.load();
    expect(
      (reopened.snapshot.state['tutorialTasks']! as Map)['q1.02.unpicked'],
      isTrue,
    );
    final savedInventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(
        reopened.snapshot.state['inventory']! as Map,
      ),
    );
    expect(
      savedInventory.objects.keys,
      containsAll([
        'lesson-needle',
        'q1-02-hive-output-0',
        'q1-02-hive-output-1',
        'q1-02-hive-output-2',
      ]),
    );
    await reopened.close();
  });

  test(
    'corrupt latest remains untouched and valid backups are exposed for recovery',
    () async {
      final store = HiveStreetScrapProgressStore(boxName: boxName);
      final session = StreetScrapSession(
        profileScope: 'recovery-player-${testIndex++}',
        store: store,
        contentVersions: const {'content': '0.1.0'},
        rulesetVersion: 1,
      );
      final slotKey = session.slotKey;
      for (var revision = 1; revision <= 4; revision++) {
        await store.compareAndSwap(
          slotKey: slotKey,
          expectedRevision: revision == 1 ? null : revision - 1,
          nextSnapshot: save(revision).toJson(),
        );
      }
      final box = await Hive.openBox<String>(boxName);
      final key = 'save:$slotKey';
      final history = (jsonDecode(box.get(key)!) as List)
          .cast<Map>()
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      history.first['state'] = {'value': -999};
      await box.put(key, jsonEncode(history));

      await expectLater(session.load(), throwsFormatException);
      final report = await session.inspectRecovery();
      expect(report.currentSnapshotIsDamaged, isTrue);
      expect(
        report.candidates.map((candidate) => candidate.snapshot.revision),
        [3, 2],
      );
      expect((jsonDecode(box.get(key)!) as List).length, 3);

      await session.restoreBackup(
        backupRevision: 3,
        expectedStorageToken: report.storageToken,
      );
      expect(session.snapshot.revision, 4);
      expect(session.snapshot.state['value'], 3);
      expect((await store.read(slotKey))!['revision'], 4);
    },
  );

  test('stale CAS does not overwrite the current save', () async {
    final slotKey = uniqueSlot();
    final store = HiveStreetScrapProgressStore(boxName: boxName);
    for (var revision = 1; revision <= 4; revision++) {
      await store.compareAndSwap(
        slotKey: slotKey,
        expectedRevision: revision == 1 ? null : revision - 1,
        nextSnapshot: save(revision).toJson(),
      );
    }
    expect(
      await store.compareAndSwap(
        slotKey: slotKey,
        expectedRevision: 2,
        nextSnapshot: save(3).toJson(),
      ),
      isFalse,
    );
    expect(
      (await store.inspectRecovery(slotKey)).candidates.first.snapshot.revision,
      4,
    );
  });

  test(
    'import through Hive creates a new revision and retains the old save',
    () async {
      final store = HiveStreetScrapProgressStore(boxName: boxName);
      final profile = 'transfer-hive-${testIndex++}';
      const versions = {'game.street-scrap.content.chapters-0-4': '0.1.0'};
      final session = StreetScrapSession(
        profileScope: profile,
        store: store,
        contentVersions: versions,
        rulesetVersion: 1,
      );
      await session.load();
      await session.apply(
        commandId: 'before-import',
        expectedRevision: 0,
        reduce: (_) =>
            const StreetScrapReduction(state: {'chapter': 1, 'stamina': 24}),
      );
      final incoming = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: versions,
        revision: 18,
        savedAt: DateTime.utc(2026, 10, 25),
        state: const {'chapter': 3, 'stamina': 41},
        commandReceipts: const {
          'source-device-command': {'revision': 18, 'result': 'claimed'},
        },
      );

      await session.importTransfer(
        transfer: StreetScrapSaveTransfer.fromSnapshot(incoming),
        validateState: (state) => expect(state['chapter'], 3),
      );

      expect(session.snapshot.revision, 2);
      expect(session.snapshot.state, incoming.state);
      expect(session.snapshot.commandReceipts, isEmpty);
      final recovery = await session.inspectRecovery();
      expect(
        recovery.candidates.map((candidate) => candidate.snapshot.revision),
        [2, 1],
      );
      expect(recovery.candidates.last.snapshot.state, {
        'chapter': 1,
        'stamina': 24,
      });
      await session.close();
    },
  );

  test('native host writer lease is exclusive per profile slot', () async {
    final store = HiveStreetScrapProgressStore(boxName: boxName);
    final first = await store.acquireWriterLease('slot:native-exclusive');
    final second = await store.acquireWriterLease('slot:native-exclusive');
    expect(first, isNotNull);
    expect(second, isNull);

    await first!.release();
    final third = await store.acquireWriterLease('slot:native-exclusive');
    expect(third, isNotNull);
    await third!.release();
  });
}
