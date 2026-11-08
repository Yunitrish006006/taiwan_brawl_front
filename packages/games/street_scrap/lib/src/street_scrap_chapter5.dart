import 'street_scrap_inventory.dart';
import 'street_scrap_module.dart';
import 'street_scrap_progress.dart';

const streetScrapChapter5ChestStorageId = 'chapter5.reinforced_chest';

bool streetScrapChapterFiveGoalReady(Map<String, Object?> state) {
  final tasks = state['tutorialTasks'];
  final completedOrders = state['completedCycleOrders'] ?? 0;
  final rawStructures = state['homeStructures'];
  final rawFurniture = state['storageFurniture'];
  return state['chapter'] == 5 &&
      tasks is Map &&
      tasks['q5.01'] == true &&
      tasks['q5.02.shelterPlaced'] == true &&
      tasks['q5.02.chestPlaced'] == true &&
      completedOrders is int &&
      completedOrders >= 5 &&
      rawStructures is Map &&
      rawStructures['q5.02.shelter'] is Map &&
      rawFurniture is Map &&
      rawFurniture[streetScrapChapter5ChestStorageId] is Map;
}

void updateStreetScrapChapterFiveGoal(Map<String, Object?> state) {
  if (!streetScrapChapterFiveGoalReady(state)) return;
  final tasks = Map<String, Object?>.from(
    state['tutorialTasks']! as Map,
  )..['q5.02'] = true;
  state['tutorialTasks'] = tasks;
}

Future<StreetScrapCommandResult> placeStreetScrapChapterFiveStructures({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String shelterInstanceId,
  required String shelterGridId,
  required String chestInstanceId,
  required String chestGridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if (state['chapter'] != 5 || tasks is! Map || tasks['q5.01'] != true) {
      throw StateError('q5.02PlacementLocked');
    }
    if (!session.contentVersions.containsKey(streetScrapChapter5ResourceId)) {
      throw StateError('chapter5ExpansionNotInstalled');
    }
    if (shelterInstanceId == chestInstanceId) {
      throw StateError('q5.02DistinctStructuresRequired');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final shelter = inventory.objects[shelterInstanceId];
    final chest = inventory.objects[chestInstanceId];
    if (shelter == null ||
        shelter.itemId != 'structure.shelter' ||
        inventory.placements[shelterInstanceId]?.gridId != shelterGridId ||
        chest == null ||
        chest.itemId != 'storage.reinforced_chest' ||
        inventory.placements[chestInstanceId]?.gridId != chestGridId) {
      throw StateError('q5.02StructuresUnavailable');
    }
    inventory = inventory.consumeFromGrid([shelterInstanceId], shelterGridId);
    inventory = inventory.consumeFromGrid([chestInstanceId], chestGridId);
    inventory = StreetScrapInventory(
      catalog: catalog,
      grids: grids,
      objects: inventory.objects,
      placements: inventory.placements,
      storage: {
        ...inventory.storage,
        streetScrapChapter5ChestStorageId: <String>[],
      },
    );

    final rawStructures = state['homeStructures'] ?? const <String, Object?>{};
    final rawFurniture = state['storageFurniture'] ?? const <String, Object?>{};
    if (rawStructures is! Map || rawFurniture is! Map) {
      throw const FormatException('Malformed home structure state.');
    }
    final structures = Map<String, Object?>.from(rawStructures);
    final furniture = Map<String, Object?>.from(rawFurniture);
    if (structures.containsKey('q5.02.shelter') ||
        furniture.containsKey(streetScrapChapter5ChestStorageId)) {
      throw StateError('q5.02StructuresAlreadyPlaced');
    }
    final occupiedSlots = <String>{
      for (final value in [...structures.values, ...furniture.values])
        if (value is Map && value['furnitureSlot'] is String)
          value['furnitureSlot'] as String,
    };
    final availableSlots = [
      for (var index = 1; index <= 6; index++) 'home-slot-$index',
    ].where((slot) => !occupiedSlots.contains(slot)).toList();
    if (availableSlots.length < 2) throw StateError('homeFurnitureSlotsFull');
    structures['q5.02.shelter'] = {
      'instanceId': shelter.instanceId,
      'itemId': shelter.itemId,
      'source': shelter.source,
      'quality': shelter.quality,
      'traits': shelter.traits,
      'supportBonusPercent': shelter.traits['joint_reinforced'] == true ? 10 : 0,
      'furnitureSlot': availableSlots[0],
      'footprint': [shelter.footprint.width, shelter.footprint.height],
      'rotation': shelter.rotation,
      'plotId': 'home',
    };
    furniture[streetScrapChapter5ChestStorageId] = {
      'instanceId': chest.instanceId,
      'itemId': chest.itemId,
      'source': chest.source,
      'quality': chest.quality,
      'traits': chest.traits,
      'furnitureSlot': availableSlots[1],
      'footprint': [chest.footprint.width, chest.footprint.height],
      'rotation': chest.rotation,
      'plotId': 'home',
      'capacity': 20,
      'contents': <String>[],
    };
    final nextTasks = Map<String, Object?>.from(tasks)
      ..['q5.02.shelterPlaced'] = true
      ..['q5.02.chestPlaced'] = true;
    final nextState = <String, Object?>{
      ...state,
      'inventory': inventory.toJson(),
      'homeStructures': structures,
      'storageFurniture': furniture,
      'tutorialTasks': nextTasks,
    };
    updateStreetScrapChapterFiveGoal(nextState);
    return StreetScrapReduction(
      state: nextState,
      result: {
        'shelterInstanceId': shelterInstanceId,
        'chestInstanceId': chestInstanceId,
        'furnitureSlots': availableSlots.take(2).toList(),
        'q5.02Complete': (nextState['tutorialTasks'] as Map)['q5.02'] == true,
      },
    );
  },
);

Future<StreetScrapCommandResult> storeStreetScrapInChapterFiveChest({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String instanceId,
  required String gridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final rawFurniture = state['storageFurniture'];
    final rawInventory = state['inventory'];
    if (state['chapter'] != 5 ||
        !session.contentVersions.containsKey(streetScrapChapter5ResourceId) ||
        rawFurniture is! Map ||
        rawInventory is! Map) {
      throw StateError('chapter5ChestUnavailable');
    }
    final rawChest = rawFurniture[streetScrapChapter5ChestStorageId];
    if (rawChest is! Map ||
        rawChest['capacity'] != 20 ||
        rawChest['itemId'] != 'storage.reinforced_chest' ||
        rawChest['furnitureSlot'] is! String) {
      throw StateError('chapter5ChestUnavailable');
    }
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final item = inventory.objects[instanceId];
    if (item == null ||
        item.containerContents.isNotEmpty ||
        item.itemId == 'storage.reinforced_chest' ||
        inventory.placements[instanceId]?.gridId != gridId) {
      throw StateError('chapter5ChestItemInvalid');
    }
    final storedIds =
        inventory.storage[streetScrapChapter5ChestStorageId] ?? const <String>[];
    final occupied = storedIds.fold<int>(0, (sum, storedId) {
      final stored = inventory.objects[storedId];
      if (stored == null) throw StateError('chapter5ChestContentsMalformed');
      final size = stored.footprint.rotated(stored.rotation);
      return sum + size.width * size.height;
    });
    final size = item.footprint.rotated(item.rotation);
    final itemCells = size.width * size.height;
    if (occupied + itemCells > 20) throw StateError('storageCapacityExceeded');
    inventory = inventory.store(instanceId, streetScrapChapter5ChestStorageId);
    final furniture = Map<String, Object?>.from(rawFurniture);
    furniture[streetScrapChapter5ChestStorageId] = {
      ...Map<String, Object?>.from(rawChest),
      'contents': inventory.storage[streetScrapChapter5ChestStorageId],
    };
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'storageFurniture': furniture,
      },
      result: {'instanceId': instanceId},
    );
  },
);

Future<StreetScrapCommandResult> withdrawStreetScrapFromChapterFiveChest({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String instanceId,
  required String gridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final rawFurniture = state['storageFurniture'];
    final rawInventory = state['inventory'];
    if (state['chapter'] != 5 ||
        !session.contentVersions.containsKey(streetScrapChapter5ResourceId) ||
        rawFurniture is! Map ||
        rawInventory is! Map) {
      throw StateError('chapter5ChestUnavailable');
    }
    final rawChest = rawFurniture[streetScrapChapter5ChestStorageId];
    if (rawChest is! Map ||
        rawChest['capacity'] != 20 ||
        rawChest['itemId'] != 'storage.reinforced_chest' ||
        rawChest['furnitureSlot'] is! String) {
      throw StateError('chapter5ChestUnavailable');
    }
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    if (!(inventory.storage[streetScrapChapter5ChestStorageId] ?? const [])
        .contains(instanceId)) {
      throw StateError('chapter5ChestItemMissing');
    }
    final grid = grids[gridId];
    if (grid == null) throw StateError('Unknown grid.');
    StreetScrapInventory? withdrawn;
    for (var y = 0; y < grid.height && withdrawn == null; y++) {
      for (var x = 0; x < grid.width && withdrawn == null; x++) {
        try {
          withdrawn = inventory.withdraw(
            instanceId,
            streetScrapChapter5ChestStorageId,
            gridId,
            x,
            y,
          );
        } on StateError {
          // Each failed placement is a no-op on the immutable inventory.
        }
      }
    }
    if (withdrawn == null) throw StateError('inventorySpaceInsufficient');
    inventory = withdrawn;
    final furniture = Map<String, Object?>.from(rawFurniture);
    furniture[streetScrapChapter5ChestStorageId] = {
      ...Map<String, Object?>.from(rawChest),
      'contents': inventory.storage[streetScrapChapter5ChestStorageId],
    };
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'storageFurniture': furniture,
      },
      result: {'instanceId': instanceId, 'gridId': gridId},
    );
  },
);
