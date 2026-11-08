import 'dart:convert';

import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';

const streetScrapWoodPressGrids = {
  'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
  'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
};

class StreetScrapToolRepairRule {
  const StreetScrapToolRepairRule({
    required this.id,
    required this.toolItemId,
    required this.phase,
    required this.restoreUses,
    required this.materialOptions,
  });

  final String id;
  final String toolItemId;
  final int phase;
  final int restoreUses;
  final List<List<String>> materialOptions;
}

class StreetScrapToolRepairCatalog {
  StreetScrapToolRepairCatalog(Iterable<StreetScrapToolRepairRule> source)
    : rules = Map.unmodifiable({for (final rule in source) rule.id: rule}) {
    if (rules.length != source.length || rules.isEmpty) {
      throw const FormatException(
        'Tool repair rules are missing or duplicated.',
      );
    }
  }

  final Map<String, StreetScrapToolRepairRule> rules;

  List<StreetScrapToolRepairRule> forTool(String itemId, int chapter) => rules
      .values
      .where((rule) => rule.toolItemId == itemId && rule.phase <= chapter)
      .toList(growable: false);

  factory StreetScrapToolRepairCatalog.fromContentPayload(String source) {
    final payload = jsonDecode(source);
    if (payload is! Map ||
        payload['toolRepairs'] is! List ||
        payload['itemDefinitions'] is! List) {
      throw const FormatException('Tool repair rules are absent from content.');
    }
    final itemDefinitions = <String, Map>{};
    for (final raw in payload['itemDefinitions'] as List) {
      if (raw is Map && raw['id'] is String) {
        itemDefinitions[raw['id'] as String] = raw;
      }
    }
    final parsed = <StreetScrapToolRepairRule>[];
    final ids = <String>{};
    for (final raw in payload['toolRepairs'] as List) {
      if (raw is! Map ||
          raw['id'] is! String ||
          raw['tool'] is! String ||
          raw['phase'] is! int ||
          raw['phase'] < 0 ||
          raw['phase'] > 5 ||
          raw['restoreUses'] is! int ||
          (raw['restoreUses'] as int) < 1 ||
          raw['materialOptions'] is! List ||
          !ids.add(raw['id'] as String)) {
        throw const FormatException('A tool repair rule is malformed.');
      }
      final tool = itemDefinitions[raw['tool'] as String];
      if (tool == null ||
          tool['baseDurability'] is! int ||
          tool['location'] != 'grid' ||
          (tool['phase'] is int && tool['phase'] > raw['phase'])) {
        throw const FormatException(
          'A repair rule references a non-durable tool.',
        );
      }
      final options = <List<String>>[];
      for (final rawOption in raw['materialOptions'] as List) {
        if (rawOption is! List ||
            rawOption.isEmpty ||
            rawOption.any(
              (id) =>
                  id is! String ||
                  (id.startsWith('content:')
                      ? itemDefinitions[id.substring('content:'.length)] ==
                                null ||
                            itemDefinitions[id.substring(
                                  'content:'.length,
                                )]!['location'] ==
                                'grid'
                      : itemDefinitions[id] == null ||
                            itemDefinitions[id]!['location'] != 'grid'),
            )) {
          throw const FormatException(
            'A repair rule references an invalid material.',
          );
        }
        final option = rawOption.cast<String>()..sort();
        if (option.toSet().length != option.length) {
          throw const FormatException(
            'A repair option contains duplicate materials.',
          );
        }
        options.add(List.unmodifiable(option));
      }
      parsed.add(
        StreetScrapToolRepairRule(
          id: raw['id'] as String,
          toolItemId: raw['tool'] as String,
          phase: raw['phase'] as int,
          restoreUses: raw['restoreUses'] as int,
          materialOptions: List.unmodifiable(options),
        ),
      );
    }
    return StreetScrapToolRepairCatalog(parsed);
  }
}

/// Issues the q3.01 tutorial materials as one local-save transaction.
/// Capacity failure leaves both the save and the one-time entitlement intact.
Future<StreetScrapCommandResult> claimStreetScrapWoodPressKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  Map<String, StreetScrapGridSpec> grids = streetScrapWoodPressGrids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final chapter = state['chapter'];
    final tasks = state['tutorialTasks'];
    if (chapter is! int ||
        chapter < 3 ||
        tasks is! Map ||
        tasks['q2.03'] != true) {
      throw StateError('q3.01Locked');
    }
    if (tasks['q3.01.kitClaimed'] == true) {
      throw StateError('q3.01KitAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final issuedIds = [
      for (var index = 0; index < 3; index++) 'q301-chip-$index',
      'q301-adhesive',
    ];
    StreetScrapInventory? suppliedInventory;
    for (final gridId in ['backpack', 'board']) {
      if (!grids.containsKey(gridId)) continue;
      var candidate = inventory;
      try {
        for (var index = 0; index < 3; index++) {
          candidate = candidate.addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'q301-chip-$index',
              itemId: 'wood.chip',
              source: 'tutorial:q3.01-kit',
              quality: 55,
              traits: const {},
              toolDurability: null,
              footprint: catalog.footprints['wood.chip']!,
            ),
            gridId,
          );
        }
        candidate = candidate.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'q301-adhesive',
            itemId: 'adhesive.recycled',
            source: 'tutorial:q3.01-kit',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: catalog.footprints['adhesive.recycled']!,
          ),
          gridId,
        );
        suppliedInventory = candidate;
        break;
      } on StateError catch (error) {
        if (!error.message.startsWith('No fitting space for ')) rethrow;
      }
    }
    if (suppliedInventory == null) {
      throw StateError('insufficientInventorySpace');
    }
    inventory = suppliedInventory;
    final nextTasks = Map<String, Object?>.from(tasks)
      ..['q3.01.kitClaimed'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'tutorialTasks': nextTasks,
      },
      result: {'items': issuedIds},
    );
  },
);

/// Completes the fixed chapter-three supply to three rods plus one nail
/// bundle, counting rods already held (including the q3.01 crafted rod).
Future<StreetScrapCommandResult> claimStreetScrapNailBoardKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  Map<String, StreetScrapGridSpec> grids = streetScrapWoodPressGrids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 3 ||
        tasks is! Map ||
        tasks['q3.01'] != true) {
      throw StateError('q3.02Locked');
    }
    if (tasks['q3.02'] == true) {
      throw StateError('q3.02AlreadyComplete');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    // Storage contents are not usable until withdrawn onto a grid. Count only
    // placed rods so the lesson always supplies enough selectable inputs.
    const targetCounts = {'wood.rod': 3, 'metal.nail_bundle': 1};
    var consolidatedInventory = inventory;
    var issuedIds = <String>[];
    var bestRelocationCount = 1 << 30;
    var bestIssueCount = 1 << 30;
    // Craft selection reads one carried grid at a time. Consolidate the
    // complete q3.02 recipe onto one grid so a nearly full backpack cannot
    // strand the nail bundle on the work board (or vice versa). Existing rods
    // retain their identity, source, quality, and traits when relocated.
    for (final gridId in const ['board', 'backpack']) {
      if (!inventory.grids.containsKey(gridId)) continue;
      var candidateInventory = inventory;
      final candidateIssued = <String>[];
      final usedIds = <String>{...inventory.objects.keys};
      String uniqueId(String base) {
        var suffix = 0;
        var candidate = base;
        while (usedIds.contains(candidate)) {
          suffix++;
          candidate = '$base-$suffix';
        }
        usedIds.add(candidate);
        return candidate;
      }

      try {
        final movableRecipeItems =
            candidateInventory.placements.keys.where((instanceId) {
              final item = candidateInventory.objects[instanceId]!;
              return targetCounts.containsKey(item.itemId) &&
                  candidateInventory.placements[instanceId]!.gridId != gridId;
            }).toList()..sort((left, right) {
              final leftItem = candidateInventory.objects[left]!;
              final rightItem = candidateInventory.objects[right]!;
              final leftArea =
                  leftItem.footprint.width * leftItem.footprint.height;
              final rightArea =
                  rightItem.footprint.width * rightItem.footprint.height;
              return rightArea.compareTo(leftArea);
            });
        for (final instanceId in movableRecipeItems) {
          candidateInventory = candidateInventory.placeFirstFit(
            instanceId,
            gridId,
          );
        }

        final countsOnGrid = <String, int>{};
        for (final placement in candidateInventory.placements.values) {
          if (placement.gridId != gridId) continue;
          final item = candidateInventory.objects[placement.instanceId]!;
          if (!targetCounts.containsKey(item.itemId)) continue;
          countsOnGrid.update(
            item.itemId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        for (final entry in targetCounts.entries) {
          final missing = (entry.value - (countsOnGrid[entry.key] ?? 0)).clamp(
            0,
            entry.value,
          );
          for (var index = 0; index < missing; index++) {
            final id = uniqueId(
              'q302-${entry.key.replaceAll('.', '-')}-${candidateIssued.length}',
            );
            candidateInventory = candidateInventory.addAndPlaceFirstFit(
              StreetScrapObject(
                instanceId: id,
                itemId: entry.key,
                source: 'tutorial:q3.02-kit',
                quality: 55,
                traits: const {},
                toolDurability: null,
                footprint: catalog.footprints[entry.key]!,
              ),
              gridId,
            );
            candidateIssued.add(id);
          }
        }
        final relocationCount = movableRecipeItems.length;
        if (relocationCount < bestRelocationCount ||
            (relocationCount == bestRelocationCount &&
                candidateIssued.length < bestIssueCount)) {
          consolidatedInventory = candidateInventory;
          issuedIds = candidateIssued;
          bestRelocationCount = relocationCount;
          bestIssueCount = candidateIssued.length;
        }
      } on StateError catch (error) {
        if (!error.message.startsWith('No fitting space for ')) rethrow;
      }
    }
    if (bestRelocationCount == 1 << 30) {
      throw StateError('insufficientInventorySpace');
    }
    inventory = consolidatedInventory;
    final nextTasks = Map<String, Object?>.from(tasks)
      ..['q3.02.kitClaimed'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'tutorialTasks': nextTasks,
      },
      result: {'items': issuedIds},
    );
  },
);

Future<StreetScrapCommandResult> claimStreetScrapToolRepairKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  Map<String, StreetScrapGridSpec> grids = streetScrapWoodPressGrids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 3 ||
        tasks is! Map ||
        tasks['q3.02'] != true) {
      throw StateError('q3.03Locked');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    if (tasks['q3.03.kitClaimed'] == true) {
      if (tasks['q3.03'] == true) throw StateError('q3.03KitAlreadyClaimed');
      const supplies = [
        ('q303-metal-shard', 'metal.shard'),
        ('q303-binding', 'cloth.binding'),
      ];
      if (supplies.every(
        (supply) => inventory.objects.containsKey(supply.$1),
      )) {
        throw StateError('q3.03KitAlreadyClaimed');
      }
      final crowbarGrid = inventory.placements['q303-crowbar']?.gridId;
      final candidateGrids = <String>{
        ...?(crowbarGrid == null ? null : [crowbarGrid]),
        'backpack',
        'board',
      }.where(grids.containsKey);
      StreetScrapInventory? restoredInventory;
      var restored = 0;
      for (final gridId in candidateGrids) {
        var candidate = inventory;
        var candidateRestored = 0;
        try {
          for (final supply in supplies) {
            if (candidate.objects.containsKey(supply.$1)) continue;
            candidate = candidate.addAndPlaceFirstFit(
              StreetScrapObject(
                instanceId: supply.$1,
                itemId: supply.$2,
                source: 'tutorial:q3.03-kit',
                quality: 55,
                traits: const {},
                toolDurability: null,
                footprint: catalog.footprints[supply.$2]!,
              ),
              gridId,
            );
            candidateRestored++;
          }
          if (candidateRestored > 0) {
            restoredInventory = candidate;
            restored = candidateRestored;
            break;
          }
        } on StateError catch (error) {
          if (!error.message.startsWith('No fitting space for ')) rethrow;
        }
      }
      if (restoredInventory == null) {
        throw StateError('insufficientInventorySpace');
      }
      inventory = restoredInventory;
      return StreetScrapReduction(
        state: {...state, 'inventory': inventory.toJson()},
        result: {'restoredSupplies': restored},
      );
    }
    const toolId = 'q303-crowbar';
    const supplies = [
      ('q303-metal-shard', 'metal.shard'),
      ('q303-binding', 'cloth.binding'),
    ];
    StreetScrapInventory? suppliedInventory;
    for (final gridId in const ['backpack', 'board']) {
      if (!grids.containsKey(gridId)) continue;
      var candidate = inventory;
      try {
        candidate = candidate.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: toolId,
            itemId: 'tool.crowbar',
            source: 'tutorial:q3.03-kit',
            quality: 55,
            traits: const {},
            toolDurability: 1,
            footprint: catalog.footprints['tool.crowbar']!,
          ),
          gridId,
        );
        for (final supply in supplies) {
          candidate = candidate.addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: supply.$1,
              itemId: supply.$2,
              source: 'tutorial:q3.03-kit',
              quality: 55,
              traits: const {},
              toolDurability: null,
              footprint: catalog.footprints[supply.$2]!,
            ),
            gridId,
          );
        }
        suppliedInventory = candidate;
        break;
      } on StateError catch (error) {
        if (!error.message.startsWith('No fitting space for ')) rethrow;
      }
    }
    if (suppliedInventory == null) {
      throw StateError('insufficientInventorySpace');
    }
    inventory = suppliedInventory;
    final nextTasks = Map<String, Object?>.from(tasks)
      ..['q3.03.kitClaimed'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'tutorialTasks': nextTasks,
      },
      result: {'toolInstanceId': toolId},
    );
  },
);

/// Repairs the same crowbar instance by ten uses, capped at its base maximum.
Future<StreetScrapCommandResult> repairStreetScrapTutorialCrowbar({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String toolInstanceId,
  required String metalShardInstanceId,
  required String bindingInstanceId,
  required String gridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if (tasks is! Map || tasks['q3.03.kitClaimed'] != true) {
      throw StateError('q3.03RepairKitRequired');
    }
    if (tasks['q3.03'] == true) throw StateError('q3.03AlreadyComplete');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final tool = inventory.objects[toolInstanceId];
    final shard = inventory.objects[metalShardInstanceId];
    final binding = inventory.objects[bindingInstanceId];
    if (tool == null ||
        tool.itemId != 'tool.crowbar' ||
        tool.source != 'tutorial:q3.03-kit' ||
        inventory.placements[toolInstanceId]?.gridId != gridId ||
        tool.toolDurability == null ||
        tool.toolDurability! <= 0 ||
        tool.toolDurability! >= 30 ||
        shard?.itemId != 'metal.shard' ||
        shard?.source != 'tutorial:q3.03-kit' ||
        binding?.itemId != 'cloth.binding' ||
        binding?.source != 'tutorial:q3.03-kit') {
      throw StateError('q3.03RepairMaterialsInvalid');
    }
    var next = inventory.consumeFromGrid([
      metalShardInstanceId,
      bindingInstanceId,
    ], gridId);
    final durability = (tool.toolDurability! + 10).clamp(0, 30).toInt();
    next = next.withToolDurability(toolInstanceId, durability);
    final nextTasks = Map<String, Object?>.from(tasks)..['q3.03'] = true;
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson(), 'tutorialTasks': nextTasks},
      result: {
        'toolInstanceId': toolInstanceId,
        'previousDurability': tool.toolDurability,
        'durability': durability,
        'restored': durability - tool.toolDurability!,
      },
    );
  },
);

/// Repeatable, non-tutorial maintenance. Repair materials are selected from
/// the same carried grid as the tool; durability is capped by its quality and
/// traits, so maintenance never improves or resets the tool.
Future<StreetScrapCommandResult> repairStreetScrapTool({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String toolInstanceId,
  required List<String> materialInstanceIds,
  required StreetScrapToolRepairRule rule,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if ((state['chapter'] as int? ?? 0) < rule.phase) {
      throw StateError('repairLocked');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final tool = inventory.objects[toolInstanceId];
    final materials = materialInstanceIds
        .map((id) => inventory.objects[id])
        .toList(growable: false);
    final tutorialTasks = state['tutorialTasks'];
    final tutorialRepairPending =
        tutorialTasks is Map &&
        tutorialTasks['q3.03.kitClaimed'] == true &&
        tutorialTasks['q3.03'] != true;
    if (tutorialRepairPending &&
        (tool?.source == 'tutorial:q3.03-kit' ||
            materials.whereType<StreetScrapObject>().any(
              (item) => item.source == 'tutorial:q3.03-kit',
            ))) {
      throw StateError('tutorialRepairRequired');
    }
    if (tool == null ||
        materials.isEmpty ||
        materials.any((item) => item == null) ||
        tool.toolDurability == null) {
      throw StateError('repairMaterialsInvalid');
    }
    final toolGrid = inventory.placements[toolInstanceId]?.gridId;
    if (toolGrid == null ||
        toolGrid.startsWith('chapter5.') ||
        materialInstanceIds.any(
          (id) => inventory.placements[id]?.gridId != toolGrid,
        ) ||
        materialInstanceIds.toSet().length != materialInstanceIds.length) {
      throw StateError('repairMaterialsInvalid');
    }
    final selectedTokens = materials
        .cast<StreetScrapObject>()
        .map(_repairMaterialToken)
        .toList(growable: false);
    final accepted =
        rule.toolItemId == tool.itemId &&
        rule.materialOptions.any(
          (option) => _sameRepairMaterials(option, selectedTokens),
        );
    final maximum = catalog.maximumDurability(
      tool.itemId,
      tool.quality,
      tool.traits,
    );
    if (!accepted ||
        maximum == null ||
        tool.toolDurability! <= 0 ||
        tool.toolDurability! >= maximum) {
      throw StateError('repairMaterialsInvalid');
    }
    var next = inventory;
    final ordinaryMaterials = <String>[];
    for (final item in materials.cast<StreetScrapObject>()) {
      final token = _repairMaterialToken(item);
      if (token.startsWith('content:')) {
        final waterId = token.substring('content:'.length);
        if (!_isRepairWaterVessel(item) ||
            item.containerState['cleanliness'] != 'clean' ||
            item.containerState['contentItemId'] != waterId ||
            item.containerState['requiresBoiling'] == true) {
          throw StateError('repairMaterialsInvalid');
        }
        next = next.withContainerState(item.instanceId, {
          'cleanliness': item.containerState['cleanliness'],
          'lastContentItemId': waterId,
          if (item.containerState['contentQuality'] != null)
            'lastContentQuality': item.containerState['contentQuality'],
        });
      } else {
        ordinaryMaterials.add(item.instanceId);
      }
    }
    if (ordinaryMaterials.isNotEmpty) {
      next = next.consumeFromGrid(ordinaryMaterials, toolGrid);
    }
    next = next.withToolDurability(
      toolInstanceId,
      (tool.toolDurability! + rule.restoreUses).clamp(0, maximum).toInt(),
    );
    final durability = next.objects[toolInstanceId]!.toolDurability!;
    return StreetScrapReduction(
      state: {...state, 'inventory': next.toJson()},
      result: {
        'toolInstanceId': toolInstanceId,
        'previousDurability': tool.toolDurability,
        'durability': durability,
        'restored': durability - tool.toolDurability!,
      },
    );
  },
);

bool _sameRepairMaterials(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  final sortedLeft = [...left]..sort();
  final sortedRight = [...right]..sort();
  for (var index = 0; index < sortedLeft.length; index++) {
    if (sortedLeft[index] != sortedRight[index]) return false;
  }
  return true;
}

const _repairWaterVesselItemIds = {
  'container.clean',
  'container.clean_jar',
  'container.used_intact',
};

bool _isRepairWaterVessel(StreetScrapObject item) =>
    _repairWaterVesselItemIds.contains(item.itemId);

String _repairMaterialToken(StreetScrapObject item) {
  final contentId = item.containerState['contentItemId'];
  if (_isRepairWaterVessel(item) && contentId is String) {
    return 'content:$contentId';
  }
  return item.itemId;
}

Future<StreetScrapCommandResult> claimStreetScrapCrateKit({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  Map<String, StreetScrapGridSpec> grids = streetScrapWoodPressGrids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if ((state['chapter'] as int? ?? 0) < 3 ||
        tasks is! Map ||
        tasks['q3.03'] != true) {
      throw StateError('q3.04Locked');
    }
    if (tasks['q3.04.kitClaimed'] == true) {
      throw StateError('q3.04KitAlreadyClaimed');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final targetCounts = {
      'wood.board': 4,
      'metal.nail_bundle': 2,
      'adhesive.recycled': 1,
    };
    // Stored materials remain unavailable until the player withdraws them to
    // a carried grid, matching the recipe-selection contract.
    var consolidatedInventory = inventory;
    var issued = <String>[];
    var bestRelocationCount = 1 << 30;
    var bestIssueCount = 1 << 30;
    // The crate recipe can only select ingredients from one grid. First try
    // to consolidate carried ingredients on the work board (the station grid),
    // preserving each existing item's identity, source, and quality. If that
    // grid cannot fit the full recipe, try the backpack as a whole; never spill
    // the tail of a kit onto the other grid.
    for (final gridId in const ['board', 'backpack']) {
      if (!inventory.grids.containsKey(gridId)) continue;
      var candidateInventory = inventory;
      final candidateIssued = <String>[];
      final usedIds = <String>{...inventory.objects.keys};
      String uniqueId(String base) {
        var suffix = 0;
        var candidate = base;
        while (usedIds.contains(candidate)) {
          suffix++;
          candidate = '$base-$suffix';
        }
        usedIds.add(candidate);
        return candidate;
      }

      try {
        final movableRecipeItems =
            candidateInventory.placements.keys.where((instanceId) {
              final item = candidateInventory.objects[instanceId]!;
              return targetCounts.containsKey(item.itemId) &&
                  candidateInventory.placements[instanceId]!.gridId != gridId;
            }).toList()..sort((left, right) {
              final leftItem = candidateInventory.objects[left]!;
              final rightItem = candidateInventory.objects[right]!;
              final leftArea =
                  leftItem.footprint.width * leftItem.footprint.height;
              final rightArea =
                  rightItem.footprint.width * rightItem.footprint.height;
              return rightArea.compareTo(leftArea);
            });
        for (final instanceId in movableRecipeItems) {
          candidateInventory = candidateInventory.placeFirstFit(
            instanceId,
            gridId,
          );
        }

        final countsOnGrid = <String, int>{};
        for (final placement in candidateInventory.placements.values) {
          if (placement.gridId != gridId) continue;
          final item = candidateInventory.objects[placement.instanceId]!;
          countsOnGrid.update(
            item.itemId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        for (final entry in targetCounts.entries) {
          final missing = (entry.value - (countsOnGrid[entry.key] ?? 0)).clamp(
            0,
            entry.value,
          );
          for (var index = 0; index < missing; index++) {
            final id = uniqueId(
              'q304-${entry.key.replaceAll('.', '-')}-${candidateIssued.length}',
            );
            candidateInventory = candidateInventory.addAndPlaceFirstFit(
              StreetScrapObject(
                instanceId: id,
                itemId: entry.key,
                source: 'tutorial:q3.04-kit',
                quality: 55,
                traits: const {},
                toolDurability: null,
                footprint: catalog.footprints[entry.key]!,
              ),
              gridId,
            );
            candidateIssued.add(id);
          }
        }
        final relocationCount = movableRecipeItems.length;
        if (relocationCount < bestRelocationCount ||
            (relocationCount == bestRelocationCount &&
                candidateIssued.length < bestIssueCount)) {
          consolidatedInventory = candidateInventory;
          issued = candidateIssued;
          bestRelocationCount = relocationCount;
          bestIssueCount = candidateIssued.length;
        }
      } on StateError catch (error) {
        if (!error.message.startsWith('No fitting space for ')) rethrow;
      }
    }
    if (bestRelocationCount == 1 << 30) {
      throw StateError('insufficientInventorySpace');
    }
    inventory = consolidatedInventory;
    final nextTasks = Map<String, Object?>.from(tasks)
      ..['q3.04.kitClaimed'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': inventory.toJson(),
        'tutorialTasks': nextTasks,
      },
      result: {'items': issued},
    );
  },
);

const streetScrapTutorialCrateStorageId = 'home-tutorial-crate';

Future<StreetScrapCommandResult> placeStreetScrapTutorialCrate({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String crateInstanceId,
  required String gridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final tasks = state['tutorialTasks'];
    if (tasks is! Map || tasks['q3.04.crateCrafted'] != true) {
      throw StateError('q3.04CrateRequired');
    }
    if (tasks['q3.04.placed'] == true) throw StateError('q3.04AlreadyPlaced');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final crate = inventory.objects[crateInstanceId];
    if (crate == null ||
        crate.itemId != 'storage.wooden_crate' ||
        crate.source != 'crafted:ss.recipe.wooden_crate' ||
        inventory.placements[crateInstanceId]?.gridId != gridId) {
      throw StateError('q3.04InvalidCrate');
    }
    final remaining = inventory.consumeFromGrid([crateInstanceId], gridId);
    final nextStorage = StreetScrapInventory(
      catalog: catalog,
      grids: grids,
      objects: remaining.objects,
      placements: remaining.placements,
      storage: {...remaining.storage, streetScrapTutorialCrateStorageId: []},
    );
    final rawFurniture = state['storageFurniture'];
    if (rawFurniture != null && rawFurniture is! Map) {
      throw const FormatException('Malformed storage furniture save.');
    }
    final furniture = <String, Object?>{
      if (rawFurniture is Map) ...Map<String, Object?>.from(rawFurniture),
      streetScrapTutorialCrateStorageId: {
        'instanceId': crate.instanceId,
        'itemId': crate.itemId,
        'source': crate.source,
        'quality': crate.quality,
        'traits': crate.traits,
        'toolDurability': crate.toolDurability,
        'footprint': [crate.footprint.width, crate.footprint.height],
        'rotation': crate.rotation,
        'plotId': 'home',
        'furnitureSlot': 'home-slot-1',
        'capacity': 12,
        'contents': <String>[],
      },
    };
    final nextTasks = Map<String, Object?>.from(tasks)..['q3.04.placed'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextStorage.toJson(),
        'storageFurniture': furniture,
        'tutorialTasks': nextTasks,
      },
      result: {'storageId': streetScrapTutorialCrateStorageId},
    );
  },
);

Future<StreetScrapCommandResult> storeStreetScrapInTutorialCrate({
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
    final tasks = state['tutorialTasks'];
    if (tasks is! Map || tasks['q3.04.placed'] != true) {
      throw StateError('q3.04CrateNotPlaced');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final item = inventory.objects[instanceId];
    if (item == null ||
        item.containerContents.isNotEmpty ||
        item.itemId == 'storage.wooden_crate' ||
        inventory.placements[instanceId]?.gridId != gridId) {
      throw StateError('q3.04StorageItemInvalid');
    }
    final storedIds =
        inventory.storage[streetScrapTutorialCrateStorageId] ?? const [];
    final occupied = storedIds.fold<int>(0, (sum, id) {
      final stored = inventory.objects[id]!;
      final footprint = stored.footprint.rotated(stored.rotation);
      return sum + footprint.width * footprint.height;
    });
    final footprint = item.footprint.rotated(item.rotation);
    final itemCells = footprint.width * footprint.height;
    if (occupied + itemCells > 12) throw StateError('storageCapacityExceeded');
    final next = inventory.store(instanceId, streetScrapTutorialCrateStorageId);
    final nextTasks = Map<String, Object?>.from(tasks)..['q3.04.stored'] = true;
    final rawFurniture = state['storageFurniture'];
    if (rawFurniture is! Map ||
        rawFurniture[streetScrapTutorialCrateStorageId] is! Map) {
      throw const FormatException('Missing tutorial crate state.');
    }
    final furniture = Map<String, Object?>.from(rawFurniture);
    final crate = Map<String, Object?>.from(
      rawFurniture[streetScrapTutorialCrateStorageId] as Map,
    )..['contents'] = next.storage[streetScrapTutorialCrateStorageId];
    furniture[streetScrapTutorialCrateStorageId] = crate;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': next.toJson(),
        'storageFurniture': furniture,
        'tutorialTasks': nextTasks,
      },
      result: {
        'instanceId': instanceId,
        'storageId': streetScrapTutorialCrateStorageId,
      },
    );
  },
);

Future<StreetScrapCommandResult> withdrawStreetScrapFromTutorialCrate({
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
    final tasks = state['tutorialTasks'];
    if (tasks is! Map || tasks['q3.04.stored'] != true) {
      throw StateError('q3.04StoreItemFirst');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    var inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    if (!(inventory.storage[streetScrapTutorialCrateStorageId] ?? const [])
        .contains(instanceId)) {
      throw StateError('q3.04StoredItemMissing');
    }
    final grid = grids[gridId];
    if (grid == null) throw StateError('Unknown grid.');
    StreetScrapInventory? withdrawn;
    for (var y = 0; y < grid.height && withdrawn == null; y++) {
      for (var x = 0; x < grid.width && withdrawn == null; x++) {
        try {
          withdrawn = inventory.withdraw(
            instanceId,
            streetScrapTutorialCrateStorageId,
            gridId,
            x,
            y,
          );
        } on StateError {
          // Try the next cell; no candidate has modified the immutable index.
        } on FormatException {
          // An occupied or out-of-bounds candidate is a placement miss, not
          // corruption of the current inventory. Continue the first-fit scan.
        }
      }
    }
    if (withdrawn == null) throw StateError('inventorySpaceInsufficient');
    inventory = withdrawn;
    final nextTasks = Map<String, Object?>.from(tasks)..['q3.04'] = true;
    final rawFurniture = state['storageFurniture'];
    if (rawFurniture is! Map ||
        rawFurniture[streetScrapTutorialCrateStorageId] is! Map) {
      throw const FormatException('Missing tutorial crate state.');
    }
    final furniture = Map<String, Object?>.from(rawFurniture);
    final crate = Map<String, Object?>.from(
      furniture[streetScrapTutorialCrateStorageId] as Map,
    )..['contents'] = inventory.storage[streetScrapTutorialCrateStorageId];
    furniture[streetScrapTutorialCrateStorageId] = crate;
    return StreetScrapReduction(
      state: {
        ...state,
        'chapter': 4,
        'inventory': inventory.toJson(),
        'storageFurniture': furniture,
        'tutorialTasks': nextTasks,
      },
      result: {'instanceId': instanceId, 'gridId': gridId},
    );
  },
);
