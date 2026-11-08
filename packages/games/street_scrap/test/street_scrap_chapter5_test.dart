import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_chapter5.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

class _Store implements StreetScrapProgressStore {
  Map<String, Object?>? value;

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => value;

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    if ((value?['revision'] as int?) != expectedRevision) return false;
    value = nextSnapshot;
    return true;
  }
}

const _grids = {
  'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
  'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
};

final _catalog = StreetScrapInventoryCatalog(
  footprints: const {
    'structure.shelter': StreetScrapFootprint(2, 2),
    'storage.reinforced_chest': StreetScrapFootprint(2, 2),
    'wood.chip': StreetScrapFootprint(1, 1),
  },
  packingRules: const {},
);

void main() {
  test('q5.02 requires both placed structures and five ordinary orders', () {
    final state = <String, Object?>{
      'chapter': 5,
      'completedCycleOrders': 4,
      'tutorialTasks': {
        'q5.01': true,
        'q5.02.shelterPlaced': true,
        'q5.02.chestPlaced': true,
      },
      'homeStructures': {
        'q5.02.shelter': {'furnitureSlot': 'home-slot-2'},
      },
      'storageFurniture': {
        streetScrapChapter5ChestStorageId: {'furnitureSlot': 'home-slot-3'},
      },
    };
    expect(streetScrapChapterFiveGoalReady(state), isFalse);
    state['completedCycleOrders'] = 5;
    expect(streetScrapChapterFiveGoalReady(state), isTrue);
    updateStreetScrapChapterFiveGoal(state);
    expect((state['tutorialTasks']! as Map)['q5.02'], isTrue);
  });

  test('placement atomically moves both structures into home furniture', () async {
    final store = _Store();
    final session = StreetScrapSession(
      profileScope: 'chapter-five-placement',
      store: store,
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.0',
        'game.street-scrap.content.chapter-5': '0.1.1',
      },
      rulesetVersion: 1,
    );
    await session.load();
    var inventory = _catalog.emptyInventory(grids: _grids);
    inventory = inventory.addAndPlaceFirstFit(
      _catalog.createObject(
        instanceId: 'shelter-1',
        itemId: 'structure.shelter',
        source: 'crafted:test',
        quality: 70,
        traits: const {'joint_reinforced': true},
      ),
      'board',
    );
    inventory = inventory.addAndPlaceFirstFit(
      _catalog.createObject(
        instanceId: 'chest-1',
        itemId: 'storage.reinforced_chest',
        source: 'crafted:test',
        quality: 70,
        traits: const {},
      ),
      'backpack',
    );
    inventory = inventory.addAndPlaceFirstFit(
      _catalog.createObject(
        instanceId: 'stored-chip',
        itemId: 'wood.chip',
        source: 'found:native-board',
        quality: 68,
        traits: const {'dry': true},
      ),
      'backpack',
    );
    await session.apply(
      commandId: 'setup',
      expectedRevision: 0,
      reduce: (_) => StreetScrapReduction(
        state: {
          'chapter': 5,
          'completedCycleOrders': 4,
          'tutorialTasks': {'q5.01': true},
          'inventory': inventory.toJson(),
          'storageFurniture': {
            'tutorial.crate': {'furnitureSlot': 'home-slot-1'},
          },
        },
      ),
    );
    await placeStreetScrapChapterFiveStructures(
      session: session,
      commandId: 'place-structures',
      expectedRevision: 1,
      catalog: _catalog,
      grids: _grids,
      shelterInstanceId: 'shelter-1',
      shelterGridId: 'board',
      chestInstanceId: 'chest-1',
      chestGridId: 'backpack',
    );
    final afterPlacement = session.snapshot.state;
    expect(afterPlacement['tutorialTasks'], {
      'q5.01': true,
      'q5.02.shelterPlaced': true,
      'q5.02.chestPlaced': true,
    });
    expect(
      (afterPlacement['tutorialTasks']! as Map)['q5.02'],
      isNot(true),
      reason: 'Four ordinary orders are not enough to complete q5.02.',
    );
    expect(
      (afterPlacement['homeStructures']! as Map)['q5.02.shelter'],
      isA<Map>(),
    );
    expect(
      ((afterPlacement['homeStructures']! as Map)['q5.02.shelter']! as Map)
          ['supportBonusPercent'],
      10,
    );
    expect(
      (afterPlacement['storageFurniture']! as Map)
          [streetScrapChapter5ChestStorageId]['capacity'],
      20,
    );
    final restored = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(afterPlacement['inventory']! as Map),
    );
    expect(restored.objects.containsKey('shelter-1'), isFalse);
    expect(restored.objects.containsKey('chest-1'), isFalse);
    await storeStreetScrapInChapterFiveChest(
      session: session,
      commandId: 'store-material',
      expectedRevision: 2,
      catalog: _catalog,
      grids: _grids,
      instanceId: 'stored-chip',
      gridId: 'backpack',
    );
    final afterStore = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(
      afterStore.storage[streetScrapChapter5ChestStorageId],
      ['stored-chip'],
    );
    await withdrawStreetScrapFromChapterFiveChest(
      session: session,
      commandId: 'withdraw-material',
      expectedRevision: 3,
      catalog: _catalog,
      grids: _grids,
      instanceId: 'stored-chip',
      gridId: 'backpack',
    );
    final withdrawn = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(withdrawn.objects['stored-chip']!.source, 'found:native-board');
    expect(withdrawn.objects['stored-chip']!.quality, 68);
    expect(withdrawn.objects['stored-chip']!.traits, {'dry': true});
    await session.close();
  });
}
