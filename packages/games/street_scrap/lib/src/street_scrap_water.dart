import 'street_scrap_inventory.dart';
import 'street_scrap_module.dart';
import 'street_scrap_progress.dart';

const streetScrapMealContainerItemIds = {
  'container.meal_box',
  'container.meal_box_insulated',
};

int streetScrapMealRecovery(String mealItemId, int quality) {
  if (mealItemId == 'meal.failed') return 4;
  final base = switch (mealItemId) {
    'meal.soup_fish' => 36,
    'meal.soup_vegetable' => 32,
    'meal.soup_basic' => 20,
    _ => throw ArgumentError.value(mealItemId, 'mealItemId'),
  };
  final multiplier = quality < 40
      ? 0.8
      : quality < 70
      ? 1.0
      : quality < 90
      ? 1.15
      : 1.3;
  final value = (base * multiplier).floor();
  return value < 1 ? 1 : value;
}

const _streetScrapWaterIds = {
  'water.turbid',
  'water.dirty',
  'water.muddy',
  'water.filtered',
  'water.boiled',
  'water.distilled',
  'water.mineral',
};

bool _isWaterVessel(StreetScrapObject item) => const {
  'container.clean',
  'container.clean_jar',
  'container.used_intact',
}.contains(item.itemId);

Map<String, Object?> _withoutWater(Map<String, Object?> state) => {
  'cleanliness': state['cleanliness'] ?? 'utility',
  if (state['contentItemId'] != null)
    'lastContentItemId': state['contentItemId'],
  if (state['contentQuality'] != null)
    'lastContentQuality': state['contentQuality'],
};

StreetScrapInventory _readWaterInventory(
  Map<String, Object?> state,
  StreetScrapInventoryCatalog catalog,
  Map<String, StreetScrapGridSpec> grids,
) {
  final raw = state['inventory'];
  if (raw is! Map) throw StateError('inventoryMissing');
  return catalog.inventoryFromJson(
    grids: grids,
    json: Map<String, Object?>.from(raw),
  );
}

class _WaterPointSource {
  const _WaterPointSource({
    required this.itemId,
    required this.phase,
    required this.requiresBoiling,
    required this.staminaCost,
    this.traits = const {},
  });

  final String itemId;
  final int phase;
  final bool requiresBoiling;
  final int staminaCost;
  final Map<String, Object?> traits;
}

const _waterPointSources = <String, _WaterPointSource>{
  'public-refill': _WaterPointSource(
    itemId: 'water.filtered',
    phase: 0,
    requiresBoiling: false,
    staminaCost: 2,
  ),
  'shore-turbid': _WaterPointSource(
    itemId: 'water.turbid',
    phase: 4,
    requiresBoiling: false,
    staminaCost: 2,
  ),
  'shore-dirty': _WaterPointSource(
    itemId: 'water.dirty',
    phase: 4,
    requiresBoiling: true,
    staminaCost: 2,
  ),
  'shore-muddy': _WaterPointSource(
    itemId: 'water.muddy',
    phase: 4,
    requiresBoiling: false,
    staminaCost: 2,
  ),
  'new-neighborhood-mineral': _WaterPointSource(
    itemId: 'water.mineral',
    phase: 5,
    requiresBoiling: false,
    staminaCost: 3,
    traits: {'mineral_rich': true},
  ),
};

/// Fills an existing clean vessel from a fixed local source; no new container
/// is created. Cost and traits are source-specific and versioned by the game plan.
Future<StreetScrapCommandResult> fillStreetScrapVessel({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String vesselId,
  required String sourceId,
  required int maxStamina,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final source = _waterPointSources[sourceId];
    if (source == null) throw StateError('unknownWaterSource');
    if ((state['chapter'] as int? ?? 0) < source.phase) {
      throw StateError('waterSourceLocked');
    }
    if (source.phase == 5 &&
        !session.contentVersions.containsKey(streetScrapChapter5ResourceId)) {
      throw StateError('chapter5ExpansionNotInstalled');
    }
    final stamina = state['stamina'] as int? ?? maxStamina;
    if (maxStamina < 1 ||
        stamina < source.staminaCost ||
        stamina > maxStamina) {
      throw StateError('insufficientStamina');
    }
    final inventory = _readWaterInventory(state, catalog, grids);
    final vessel = inventory.objects[vesselId];
    if (vessel == null || !_isWaterVessel(vessel)) {
      throw StateError('vesselMissing');
    }
    if (vessel.containerState['contentItemId'] != null ||
        vessel.containerState['cleanliness'] != 'clean') {
      throw StateError('cleanEmptyVesselRequired');
    }
    final next = inventory.withContainerState(vesselId, {
      'contentItemId': source.itemId,
      'contentQuality': 55,
      'contentSource': sourceId,
      'contentTraits': source.traits,
      'requiresBoiling': source.requiresBoiling,
      'cleanliness': 'utility',
    });
    return StreetScrapReduction(
      state: {
        ...state,
        'stamina': stamina - source.staminaCost,
        'inventory': next.toJson(),
      },
      result: {
        'waterItemId': source.itemId,
        'sourceId': sourceId,
        'vesselId': vesselId,
        'staminaCost': source.staminaCost,
      },
    );
  },
);

/// Cleans one empty reusable bottle at the public refill point. The point
/// supplies wash water directly, so this action does not consume bottled
/// water or require a second vessel.
Future<StreetScrapCommandResult> washStreetScrapVesselAtPublicRefill({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String vesselId,
  required int maxStamina,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final source = _waterPointSources['public-refill']!;
    final chapter = state['chapter'] as int? ?? 0;
    if (chapter < source.phase) throw StateError('waterSourceLocked');
    final stamina = state['stamina'] as int? ?? maxStamina;
    if (maxStamina < 1 ||
        stamina < source.staminaCost ||
        stamina > maxStamina) {
      throw StateError('insufficientStamina');
    }
    final inventory = _readWaterInventory(state, catalog, grids);
    final vessel = inventory.objects[vesselId];
    if (vessel == null || !_isWaterVessel(vessel)) {
      throw StateError('vesselMissing');
    }
    if (!inventory.placements.containsKey(vesselId)) {
      throw StateError('vesselNotPlaced');
    }
    if (vessel.containerState['contentItemId'] != null) {
      throw StateError('vesselNotEmpty');
    }
    if (vessel.containerState['cleanliness'] == 'clean') {
      throw StateError('vesselAlreadyClean');
    }
    final cleanState = Map<String, Object?>.from(vessel.containerState)
      ..['cleanliness'] = 'clean';
    var next = inventory;
    if (vessel.itemId == 'container.used_intact') {
      next = next.transformObjectType(
        instanceId: vesselId,
        fromItemId: 'container.used_intact',
        toItemId: 'container.clean',
      );
    }
    next = next
        .withContainerState(vesselId, cleanState)
        .appendProvenanceEvent(
          instanceId: vesselId,
          event: {
            'eventId': 'public-refill-wash:$commandId',
        'kind': 'transform',
        'recipeId': 'ss.operation.public-refill-wash',
            'sourceId': 'public-refill',
            'revision': expectedRevision + 1,
        'outcome': 'success',
        'inputs': [
          {
            'instanceId': vessel.instanceId,
            'itemId': vessel.itemId,
            'source': vessel.source,
            'quality': vessel.quality,
            'traits': vessel.traits,
            if (vessel.acquiredRevision != null)
              'acquiredRevision': vessel.acquiredRevision,
            if (vessel.provenance.isNotEmpty)
              'parentEventIds': [
                for (final prior in vessel.provenance)
                  if (prior['eventId'] is String) prior['eventId'],
              ],
          },
        ],
          },
        );
    return StreetScrapReduction(
      state: {
        ...state,
        'stamina': stamina - source.staminaCost,
        'inventory': next.toJson(),
      },
      result: {
        'vesselId': vesselId,
        'sourceId': 'public-refill',
        'staminaCost': source.staminaCost,
      },
    );
  },
);

Future<StreetScrapCommandResult> transferStreetScrapWater({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String sourceVesselId,
  required String targetVesselId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if (sourceVesselId == targetVesselId) throw StateError('sameVessel');
    final inventory = _readWaterInventory(state, catalog, grids);
    final source = inventory.objects[sourceVesselId];
    final target = inventory.objects[targetVesselId];
    if (source == null || !_isWaterVessel(source)) {
      throw StateError('sourceVesselMissing');
    }
    if (target == null || !_isWaterVessel(target)) {
      throw StateError('targetVesselMissing');
    }
    final content = source.containerState['contentItemId'];
    if (content is! String || !_streetScrapWaterIds.contains(content)) {
      throw StateError('waterMissing');
    }
    if (target.containerState['contentItemId'] != null ||
        target.containerState['cleanliness'] != 'clean') {
      throw StateError('targetNotCleanAndEmpty');
    }
    final transferred = Map<String, Object?>.from(source.containerState)
      ..['cleanliness'] = 'utility';
    var next = inventory.withContainerState(
      sourceVesselId,
      _withoutWater(source.containerState),
    );
    next = next.withContainerState(targetVesselId, transferred);
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson()},
      result: {
        'waterItemId': content,
        'sourceVesselId': sourceVesselId,
        'targetVesselId': targetVesselId,
      },
    );
  },
);

Future<StreetScrapCommandResult> emptyStreetScrapWaterVessel({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String vesselId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final inventory = _readWaterInventory(state, catalog, grids);
    final vessel = inventory.objects[vesselId];
    if (vessel == null || !_isWaterVessel(vessel)) {
      throw StateError('vesselMissing');
    }
    final content = vessel.containerState['contentItemId'];
    if (content is! String || !_streetScrapWaterIds.contains(content)) {
      throw StateError('waterMissing');
    }
    final next = inventory.withContainerState(
      vesselId,
      _withoutWater(vessel.containerState),
    );
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson()},
      result: {'discardedWaterItemId': content, 'vesselId': vesselId},
    );
  },
);

Future<StreetScrapCommandResult> washStreetScrapVessel({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String targetVesselId,
  required String waterVesselId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if (targetVesselId == waterVesselId) throw StateError('sameVessel');
    final inventory = _readWaterInventory(state, catalog, grids);
    final target = inventory.objects[targetVesselId];
    final source = inventory.objects[waterVesselId];
    if (target == null || !_isWaterVessel(target)) {
      throw StateError('targetVesselMissing');
    }
    if (source == null || !_isWaterVessel(source)) {
      throw StateError('sourceVesselMissing');
    }
    if (target.containerState['contentItemId'] != null) {
      throw StateError('targetNotEmpty');
    }
    if (source.containerState['contentItemId'] != 'water.filtered' ||
        source.containerState['requiresBoiling'] == true) {
      throw StateError('filteredWaterRequired');
    }
    final next = inventory
        .withContainerState(targetVesselId, const {'cleanliness': 'clean'})
        .withContainerState(
          waterVesselId,
          _withoutWater(source.containerState),
        );
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson()},
      result: {
        'washedVesselId': targetVesselId,
        'waterVesselId': waterVesselId,
      },
    );
  },
);

/// One-time chapter-four filtration lesson supply. The source items are fixed
/// and stay local to the save; retrying a failed filter uses the same water.
Future<StreetScrapCommandResult> claimStreetScrapWaterFilterKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 4 ||
        tasks is! Map ||
        tasks['q3.04'] != true) {
      throw StateError('q4.01Locked');
    }
    if (tasks['q4.01.kitClaimed'] == true) {
      throw StateError('q4.01KitAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    const kit = [
      ('q401-water-bottle', 'container.clean', null),
      ('q401-charcoal', 'material.charcoal', null),
      ('q401-filter-cloth', 'material.filter_cloth', 20),
    ];
    if (kit.any((entry) => !catalog.footprints.containsKey(entry.$2))) {
      throw StateError('q4.01ContentUnavailable');
    }
    try {
      for (final (id, itemId, durability) in kit) {
        inventory = inventory.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: id,
            itemId: itemId,
            source: 'tutorial:q4.01-filter-kit',
            quality: 55,
            traits: const {},
            toolDurability: itemId == 'material.filter_cloth'
                ? durability
                : null,
            containerState: itemId == 'container.clean'
                ? const {
                    'contentItemId': 'water.turbid',
                    'contentQuality': 55,
                    'contentSource': 'tutorial:q4.01-filter-kit',
                    'contentTraits': <String, Object?>{},
                    'requiresBoiling': false,
                    'cleanliness': 'utility',
                  }
                : const {},
          ),
          'backpack',
        );
      }
    } on StateError catch (error) {
      if (error.message.startsWith('No fitting space for ')) {
        throw StateError('q4.01InsufficientBackpackSpace');
      }
      rethrow;
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'tutorialTasks': {
          ...Map<String, Object?>.from(tasks),
          'q4.01.kitClaimed': true,
        },
      },
      result: {'items': kit.map((entry) => entry.$1).toList(growable: false)},
    );
  },
);

/// Eats soup in-place and records recovery, task progress, and the emptied
/// (now dirty) reusable meal box in one atomic save transaction.
Future<StreetScrapCommandResult> consumeStreetScrapSoup({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String mealBoxInstanceId,
  required int maxStamina,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if (tasks is! Map || tasks['q4.02'] != true) {
      throw StateError('q4.03Locked');
    }
    if (tasks['q4.03'] == true) throw StateError('q4.03AlreadyComplete');
    if (maxStamina < 1) throw ArgumentError.value(maxStamina, 'maxStamina');
    final stamina = state['stamina'] as int? ?? maxStamina;
    if (stamina < 0 || stamina > maxStamina) {
      throw StateError('invalidStamina');
    }
    if (stamina == maxStamina) throw StateError('staminaFull');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final box = inventory.objects[mealBoxInstanceId];
    if (box == null || !streetScrapMealContainerItemIds.contains(box.itemId)) {
      throw StateError('mealBoxMissing');
    }
    final mealValue = box.containerState['contentItemId'];
    if (mealValue is! String) throw StateError('mealMissing');
    final meal = mealValue;
    if (meal != 'meal.soup_basic' &&
        meal != 'meal.soup_fish' &&
        meal != 'meal.soup_vegetable' &&
        meal != 'meal.failed') {
      throw StateError('mealMissing');
    }
    final quality = box.containerState['contentQuality'] as int? ?? box.quality;
    final recovery = streetScrapMealRecovery(
      meal,
      quality,
    ).clamp(1, maxStamina);
    final restored = (stamina + recovery).clamp(0, maxStamina);
    final nextInventory = inventory.withContainerState(mealBoxInstanceId, {
      'cleanliness': 'soiled',
      'lastContentItemId': meal,
      'lastContentQuality': quality,
    });
    return StreetScrapReduction(
      state: {
        ...state,
        'stamina': restored,
        'inventory': nextInventory.toJson(),
        'tutorialTasks': {...Map<String, Object?>.from(tasks), 'q4.03': true},
      },
      result: {
        'mealItemId': meal,
        'recovery': recovery,
        'actualRestored': restored - stamina,
        'overflow': (stamina + recovery - maxStamina).clamp(0, maxStamina),
        'mealBoxInstanceId': mealBoxInstanceId,
      },
    );
  },
);

/// Delivers one normal soup for the chapter-four meal order. The original box
/// is returned, while the meal and four exchange tickets settle atomically.
Future<StreetScrapCommandResult> deliverStreetScrapMeal({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String mealBoxInstanceId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if (tasks is! Map || tasks['q4.02'] != true) {
      throw StateError('q4.03Locked');
    }
    if (tasks['q4.03'] == true) throw StateError('q4.03AlreadyComplete');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final box = inventory.objects[mealBoxInstanceId];
    if (box == null || !streetScrapMealContainerItemIds.contains(box.itemId)) {
      throw StateError('mealBoxMissing');
    }
    final meal = box.containerState['contentItemId'];
    if (meal != 'meal.soup_basic' &&
        meal != 'meal.soup_fish' &&
        meal != 'meal.soup_vegetable') {
      throw StateError('mealNotDeliverable');
    }
    final currentTickets = state['exchangeTickets'] ?? 0;
    if (currentTickets is! int || currentTickets < 0) {
      throw StateError('invalidExchangeTicketBalance');
    }
    final nextTickets = currentTickets + 4;
    final nextInventory = inventory.withContainerState(mealBoxInstanceId, {
      'cleanliness': 'soiled',
      'lastContentItemId': meal,
      'lastContentQuality': box.containerState['contentQuality'] ?? box.quality,
    });
    return StreetScrapReduction(
      state: {
        ...state,
        'exchangeTickets': nextTickets,
        'inventory': nextInventory.toJson(),
        'tutorialTasks': {...Map<String, Object?>.from(tasks), 'q4.03': true},
      },
      result: {
        'orderId': 'ss.order.meal',
        'mealItemId': meal,
        'exchangeTickets': 4,
        'mealBoxInstanceId': mealBoxInstanceId,
      },
    );
  },
);

/// Places a successfully cooked chapter-five shared meal into a clean reusable
/// meal box. The cooked meal is consumed, while the original box identity,
/// placement, and quality are retained in the same save transaction.
Future<StreetScrapCommandResult> packStreetScrapSharedMealIntoContainer({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String mealInstanceId,
  required String containerInstanceId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if (state['chapter'] != 5) throw StateError('sharedMealPackLocked');
    if (!session.contentVersions.containsKey(streetScrapChapter5ResourceId)) {
      throw StateError('chapter5ExpansionNotInstalled');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final meal = inventory.objects[mealInstanceId];
    if (meal == null ||
        meal.itemId != 'meal.shared' ||
        meal.source != 'crafted:ss.recipe.shared_meal' ||
        !meal.provenance.any(
          (event) =>
              event['kind'] == 'craft' &&
              event['recipeId'] == 'ss.recipe.shared_meal' &&
              event['outcome'] == 'success',
        )) {
      throw StateError('sharedMealNotCooked');
    }
    if (inventory.placements[mealInstanceId]?.gridId != 'backpack') {
      throw StateError('sharedMealMustBeInBackpack');
    }
    final container = inventory.objects[containerInstanceId];
    if (container == null ||
        !streetScrapMealContainerItemIds.contains(container.itemId) ||
        inventory.placements[containerInstanceId]?.gridId != 'backpack') {
      throw StateError('mealBoxMissing');
    }
    if (container.containerState['contentItemId'] != null) {
      throw StateError('mealBoxNotEmpty');
    }
    if (container.containerState['cleanliness'] != 'clean') {
      throw StateError('mealBoxNeedsCleaning');
    }
    final mealInput = {
      'instanceId': meal.instanceId,
      'itemId': meal.itemId,
      'source': meal.source,
      'quality': meal.quality,
      'traits': meal.traits,
      'parentEventIds': [
        for (final event in meal.provenance)
          if (event['eventId'] is String) event['eventId'],
      ],
    };
    final nextInventory = inventory
        .withContainerState(containerInstanceId, {
          'contentItemId': meal.itemId,
          'contentQuality': meal.quality,
          'contentSource': meal.source,
          'contentTraits': meal.traits,
          'cleanliness': 'clean',
        })
        .appendProvenanceEvent(
          instanceId: containerInstanceId,
          relatedInputs: [meal],
          event: {
            'eventId': 'pack:$commandId',
            'kind': 'pack',
            'revision': expectedRevision + 1,
            'inputs': [mealInput],
          },
        )
        .consumeFromGrid([mealInstanceId], 'backpack');
    return StreetScrapReduction(
      state: {...state, 'inventory': nextInventory.toJson()},
      result: {
        'mealInstanceId': mealInstanceId,
        'containerInstanceId': containerInstanceId,
        'mealItemId': meal.itemId,
        'quality': meal.quality,
      },
    );
  },
);

/// Issues one complete, identity-preserving basic soup lesson set.
Future<StreetScrapCommandResult> claimStreetScrapBasicSoupKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 4 ||
        tasks is! Map ||
        tasks['q4.01'] != true) {
      throw StateError('q4.02Locked');
    }
    if (tasks['q4.02.kitClaimed'] == true || tasks['q4.02'] == true) {
      throw StateError('q4.02KitAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    const kit = [
      ('q402-food', 'food.cleaned'),
      ('q402-fuel', 'fuel.dry'),
      ('q402-water-bottle', 'container.clean'),
      ('q402-meal-box', 'container.meal_box'),
    ];

    void placeSoupKitItem(StreetScrapObject item) {
      for (final gridId in const ['backpack', 'board']) {
        if (!inventory.grids.containsKey(gridId)) continue;
        try {
          inventory = inventory.addAndPlaceFirstFit(item, gridId);
          return;
        } on StateError catch (error) {
          if (!error.message.startsWith('No fitting space for ')) rethrow;
        }
      }
      throw StateError('insufficientInventorySpace');
    }

    for (final (id, itemId) in kit) {
      placeSoupKitItem(
        catalog.createObject(
          instanceId: id,
          itemId: itemId,
          source: 'tutorial:q4.02-soup-kit',
          quality: 55,
          traits: const {},
          containerState: switch (itemId) {
            'container.clean' => const {
              'contentItemId': 'water.boiled',
              'contentQuality': 55,
              'contentSource': 'tutorial:q4.02-soup-kit',
              'contentTraits': <String, Object?>{},
              'requiresBoiling': false,
              'cleanliness': 'utility',
            },
            'container.meal_box' => const {'cleanliness': 'clean'},
            _ => const {},
          },
        ),
      );
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'tutorialTasks': {
          ...Map<String, Object?>.from(tasks),
          'q4.02.kitClaimed': true,
        },
      },
      result: {'items': kit.map((entry) => entry.$1).toList(growable: false)},
    );
  },
);
