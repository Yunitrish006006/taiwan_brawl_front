import 'dart:math' as math;

import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';

/// Versioned rules carried by the optional Street Scrap content package.
class StreetScrapFishingRules {
  const StreetScrapFishingRules({
    required this.version,
    required this.castCost,
    required this.signalsPerCast,
    required this.successSignals,
    required this.perfectSignals,
    required this.signalHoldMilliseconds,
    required this.basePromptWidthPercent,
    required this.preciseQualityBonus,
    required this.guaranteeAfterFailures,
    required this.freeNaturalBait,
    required this.loanerRodAvailable,
    required this.spots,
    required this.failureRewards,
  });

  final int version;
  final int castCost;
  final int signalsPerCast;
  final int successSignals;
  final int perfectSignals;
  final int signalHoldMilliseconds;
  final int basePromptWidthPercent;
  final int preciseQualityBonus;
  final int guaranteeAfterFailures;
  final bool freeNaturalBait;
  final bool loanerRodAvailable;
  final List<StreetScrapFishingSpot> spots;
  final List<String> failureRewards;

  factory StreetScrapFishingRules.fromJson(Map<String, Object?> json) {
    final rawSpots = json['spots'];
    final rawRewards = json['failureRewards'];
    if (rawSpots is! List ||
        rawRewards is! List ||
        rawRewards.any((value) => value is! String)) {
      throw const FormatException('Invalid fishing spots or failure rewards.');
    }
    final rules = StreetScrapFishingRules(
      version: json['version'] as int,
      castCost: json['castCost'] as int,
      signalsPerCast: json['signalsPerCast'] as int,
      successSignals: json['successSignals'] as int,
      perfectSignals: json['perfectSignals'] as int,
      signalHoldMilliseconds: json['signalHoldMilliseconds'] as int,
      basePromptWidthPercent: json['basePromptWidthPercent'] as int,
      preciseQualityBonus: json['preciseQualityBonus'] as int,
      guaranteeAfterFailures: json['guaranteeAfterFailures'] as int,
      freeNaturalBait: json['freeNaturalBait'] as bool,
      loanerRodAvailable: json['loanerRodAvailable'] as bool,
      spots: List.unmodifiable(
        rawSpots.map((entry) {
          if (entry is! Map ||
              entry['id'] is! String ||
              entry['phase'] is! int ||
              entry['name'] is! String) {
            throw const FormatException('Malformed fishing spot.');
          }
          return StreetScrapFishingSpot(
            id: entry['id'] as String,
            phase: entry['phase'] as int,
            name: entry['name'] as String,
            failureRewards: _readFishingRewards(
              entry['failureRewards'],
              allowEmpty: true,
            ),
          );
        }),
      ),
      failureRewards: List.unmodifiable(rawRewards.cast<String>()),
    );
    rules.validate();
    return rules;
  }

  void validate() {
    final ids = spots.map((spot) => spot.id).toSet();
    final raftSpot = spots
        .where((spot) => spot.id == streetScrapRaftFishingSpotId)
        .firstOrNull;
    if (version != 1 ||
        castCost != 3 ||
        signalsPerCast != 3 ||
        successSignals != 2 ||
        perfectSignals != 3 ||
        signalHoldMilliseconds != 2000 ||
        basePromptWidthPercent != 30 ||
        preciseQualityBonus != 8 ||
        guaranteeAfterFailures != 2 ||
        !freeNaturalBait ||
        !loanerRodAvailable ||
        spots.isEmpty ||
        ids.length != spots.length ||
        !spots.any((spot) => spot.id == 'dock_entrance' && spot.phase == 2) ||
        failureRewards.length != 2 ||
        failureRewards.toSet().length != failureRewards.length ||
        spots.any(
          (spot) =>
              spot.failureRewards.toSet().length !=
                  spot.failureRewards.length ||
              spot.failureRewards.any((reward) => reward.trim().isEmpty),
        ) ||
        (raftSpot != null &&
            (raftSpot.phase != 3 ||
                raftSpot.failureRewards.toSet().length != 2 ||
                !raftSpot.failureRewards.toSet().containsAll(const {
                  'fish.bone',
                  'wood.driftwood',
                }))) ||
        spots.any(
          (spot) =>
              spot.id.isEmpty ||
              spot.name.isEmpty ||
              spot.phase < 2 ||
              spot.phase > 5,
        )) {
      throw const FormatException(
        'Street Scrap fishing rules are incompatible.',
      );
    }
  }
}

List<String> _readFishingRewards(Object? raw, {bool allowEmpty = false}) {
  if (raw == null && allowEmpty) return const [];
  if (raw is! List ||
      raw.any((value) => value is! String || value.trim().isEmpty) ||
      (!allowEmpty && raw.isEmpty)) {
    throw const FormatException('Invalid fishing failure rewards.');
  }
  return List.unmodifiable(raw.cast<String>());
}

class StreetScrapFishingSpot {
  const StreetScrapFishingSpot({
    required this.id,
    required this.phase,
    required this.name,
    this.failureRewards = const [],
  });

  final String id;
  final int phase;
  final String name;
  final List<String> failureRewards;
}

const String streetScrapRaftFishingSpotId = 'raft_point';

/// Fishing bonuses use the strongest applicable source instead of stacking.
/// The float contributes five percentage points; rod definitions can pass
/// their already-computed bonus through [rodBonusPercentagePoints].
int streetScrapFishingPromptWidthPercent({
  required int basePromptWidthPercent,
  bool floatEquipped = false,
  int rodBonusPercentagePoints = 0,
}) {
  final bonus = math.max(floatEquipped ? 5 : 0, rodBonusPercentagePoints);
  return (basePromptWidthPercent + bonus).clamp(1, 100);
}

bool _hasFishingResultOrActivity(Map<String, Object?> state) =>
    state['fishingActivity'] != null || state['fishingPendingResult'] != null;

StreetScrapObject _readFishingFloatSnapshot(
  StreetScrapInventoryCatalog catalog,
  Map<String, StreetScrapGridSpec> grids,
  Map<String, Object?> rawFloat,
) {
  final instanceId = rawFloat['instanceId'];
  if (instanceId is! String) {
    throw const FormatException('Malformed fishing float identity.');
  }
  final empty = catalog.emptyInventory(grids: grids).toJson();
  final parsed = catalog.inventoryFromJson(
    grids: grids,
    json: {
      ...empty,
      'objects': [rawFloat],
    },
  );
  final item = parsed.objects[instanceId];
  final bottle = item?.containerContents.singleOrNull;
  if (item == null ||
      item.itemId != 'toolpart.float' ||
      item.footprint.width != 1 ||
      item.footprint.height != 2 ||
      bottle == null ||
      bottle.itemId != 'container.clean' ||
      bottle.containerState['cleanliness'] != 'clean' ||
      bottle.containerState['contentItemId'] != null ||
      bottle.containerContents.isNotEmpty) {
    throw const FormatException('Malformed retained bottle in fishing float.');
  }
  return item;
}

/// Moves a complete crafted float into its one fishing equipment slot.
/// The nested bottle remains attached to the original float object.
Future<StreetScrapCommandResult> equipStreetScrapFishingFloat({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String floatInstanceId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if ((state['chapter'] as int? ?? 0) < 2) throw StateError('floatLocked');
    if (_hasFishingResultOrActivity(state)) {
      throw StateError('fishingActivityPending');
    }
    final rawEquipment = state['fishingEquipment'];
    final equipment = rawEquipment == null
        ? <String, Object?>{}
        : rawEquipment is Map
        ? Map<String, Object?>.from(rawEquipment)
        : throw const FormatException('Malformed fishing equipment.');
    if (equipment['float'] != null) throw StateError('floatAlreadyEquipped');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('fishingInventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final item = inventory.objects[floatInstanceId];
    final placement = inventory.placements[floatInstanceId];
    if (item == null ||
        placement == null ||
        (placement.gridId != 'board' && placement.gridId != 'backpack') ||
        item.itemId != 'toolpart.float' ||
        item.containerContents.length != 1) {
      throw StateError('floatUnavailable');
    }
    final rawObjects = rawInventory['objects'];
    if (rawObjects is! List) throw StateError('fishingInventoryMissing');
    final rawFloat = rawObjects
        .whereType<Map>()
        .where((raw) => raw['instanceId'] == floatInstanceId)
        .firstOrNull;
    if (rawFloat == null) throw StateError('floatUnavailable');
    final snapshot = Map<String, Object?>.from(rawFloat);
    _readFishingFloatSnapshot(catalog, grids, snapshot);
    final nextInventory = inventory.detachFromGrid(
      floatInstanceId,
      placement.gridId,
    );
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextInventory.toJson(),
        'fishingEquipment': {...equipment, 'float': snapshot},
      },
      result: {'equipped': floatInstanceId},
    );
  },
);

/// Returns the installed float to a carried grid atomically.
Future<StreetScrapCommandResult> unequipStreetScrapFishingFloat({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String targetGridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if (_hasFishingResultOrActivity(state)) {
      throw StateError('fishingActivityPending');
    }
    if (targetGridId != 'board' && targetGridId != 'backpack') {
      throw StateError('floatTargetGridInvalid');
    }
    final rawEquipment = state['fishingEquipment'];
    if (rawEquipment is! Map || rawEquipment['float'] is! Map) {
      throw StateError('floatNotEquipped');
    }
    final snapshot = Map<String, Object?>.from(rawEquipment['float'] as Map);
    final float = _readFishingFloatSnapshot(catalog, grids, snapshot);
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('fishingInventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final nextInventory = inventory.addAndPlaceFirstFit(float, targetGridId);
    final equipment = Map<String, Object?>.from(rawEquipment)..remove('float');
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextInventory.toJson(),
        'fishingEquipment': equipment,
      },
      result: {'unequipped': float.instanceId, 'gridId': targetGridId},
    );
  },
);

/// Installs the crafted raft in the dedicated dock facility slot. The raft is
/// moved out of the carried grid and stored as its full object snapshot; it
/// never consumes a yard furniture slot.
Future<StreetScrapCommandResult> placeStreetScrapRaft({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String raftInstanceId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if ((state['chapter'] as int? ?? 0) < 3) throw StateError('raftLocked');
    if (_hasFishingResultOrActivity(state)) {
      throw StateError('fishingActivityPending');
    }
    final rawFacilities = state['fishingFacilities'];
    final facilities = rawFacilities == null
        ? <String, Object?>{}
        : rawFacilities is Map
        ? Map<String, Object?>.from(rawFacilities)
        : throw const FormatException('Malformed fishing facilities.');
    if (facilities['dockRaft'] != null) throw StateError('raftAlreadyPlaced');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('fishingInventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final raft = inventory.objects[raftInstanceId];
    final placement = inventory.placements[raftInstanceId];
    if (raft == null ||
        raft.itemId != 'structure.raft' ||
        raft.footprint.width != 2 ||
        raft.footprint.height != 2 ||
        raft.containerContents.isNotEmpty ||
        placement == null ||
        (placement.gridId != 'board' && placement.gridId != 'backpack')) {
      throw StateError('raftUnavailable');
    }
    final rawObjects = rawInventory['objects'];
    if (rawObjects is! List) throw StateError('fishingInventoryMissing');
    final raftSnapshot = rawObjects
        .whereType<Map>()
        .where((raw) => raw['instanceId'] == raftInstanceId)
        .firstOrNull;
    if (raftSnapshot == null) throw StateError('raftUnavailable');
    final nextInventory = inventory.detachFromGrid(
      raftInstanceId,
      placement.gridId,
    );
    final unlocked = state['unlockedFishingSpots'];
    if (unlocked != null &&
        (unlocked is! List || unlocked.any((id) => id is! String))) {
      throw const FormatException('Malformed unlocked fishing spots.');
    }
    final nextSpots = <String>{
      if (unlocked is List) ...unlocked.cast<String>(),
      streetScrapRaftFishingSpotId,
    }.toList()..sort();
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextInventory.toJson(),
        'fishingFacilities': {
          ...facilities,
          'dockRaft': Map<String, Object?>.from(raftSnapshot),
        },
        'unlockedFishingSpots': nextSpots,
      },
      result: {'facility': 'dock', 'instanceId': raftInstanceId},
    );
  },
);

/// Recalls the raft only after proving the complete 2x2 object fits on the
/// selected carried grid. A failed first-fit leaves the facility untouched.
Future<StreetScrapCommandResult> recallStreetScrapRaft({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String targetGridId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    if (_hasFishingResultOrActivity(state)) {
      throw StateError('fishingActivityPending');
    }
    if (targetGridId != 'board' && targetGridId != 'backpack') {
      throw StateError('raftTargetGridInvalid');
    }
    final rawFacilities = state['fishingFacilities'];
    if (rawFacilities is! Map || rawFacilities['dockRaft'] is! Map) {
      throw StateError('raftNotPlaced');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('fishingInventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final rawFacility = Map<String, Object?>.from(
      rawFacilities['dockRaft'] as Map,
    );
    final raftInstanceId = rawFacility['instanceId'];
    if (raftInstanceId is! String ||
        inventory.objects.containsKey(raftInstanceId)) {
      throw const FormatException('Malformed dock raft identity.');
    }
    final emptyInventory = catalog.emptyInventory(grids: grids).toJson();
    final raftOnly = catalog.inventoryFromJson(
      grids: grids,
      json: {
        ...emptyInventory,
        'objects': [rawFacility],
      },
    );
    final raft = raftOnly.objects[raftInstanceId];
    if (raft == null ||
        raft.itemId != 'structure.raft' ||
        raft.footprint.width != 2 ||
        raft.footprint.height != 2 ||
        raft.containerContents.isNotEmpty) {
      throw const FormatException('Malformed dock raft payload.');
    }
    final nextInventory = inventory.addAndPlaceFirstFit(raft, targetGridId);
    final facilities = Map<String, Object?>.from(rawFacilities)
      ..remove('dockRaft');
    final unlocked = state['unlockedFishingSpots'];
    final nextSpots = unlocked is List
        ? unlocked
              .whereType<String>()
              .where((id) => id != streetScrapRaftFishingSpotId)
              .toList()
        : <String>[];
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextInventory.toJson(),
        'fishingFacilities': facilities,
        'unlockedFishingSpots': nextSpots,
      },
      result: {'recalled': raftInstanceId, 'gridId': targetGridId},
    );
  },
);

/// Commits the cast and its cost exactly once. Signal resolution belongs to
/// q2.02; this saved activity intentionally remains pending until then.
Future<StreetScrapCommandResult> castStreetScrapLine({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapFishingRules rules,
  required String spotId,
  required int defaultStamina,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    rules.validate();
    if ((state['chapter'] as int? ?? 0) < 2 ||
        state['tutorialTasks'] is! Map ||
        (state['tutorialTasks'] as Map)['q1.03'] != true) {
      throw StateError('fishingLocked');
    }
    final spot = rules.spots.where((entry) => entry.id == spotId).firstOrNull;
    if (spot == null || spot.phase > (state['chapter'] as int? ?? 0)) {
      throw StateError('fishingSpotLocked');
    }
    if (spot.id == streetScrapRaftFishingSpotId) {
      final rawFacilities = state['fishingFacilities'];
      final raft = rawFacilities is Map ? rawFacilities['dockRaft'] : null;
      if (raft is! Map || raft['itemId'] != 'structure.raft') {
        throw StateError('fishingSpotLocked');
      }
    }
    final unlocked = state['unlockedFishingSpots'];
    if (unlocked is! List || !unlocked.contains(spotId)) {
      throw StateError('fishingSpotLocked');
    }
    if (!rules.freeNaturalBait || !rules.loanerRodAvailable) {
      throw StateError('fishingEquipmentUnavailable');
    }
    if (state['craftOperation'] != null) throw StateError('craftInProgress');
    final rawExpedition = state['expedition'];
    if (rawExpedition is Map && rawExpedition['claimed'] != true) {
      throw StateError('expeditionMustBeResolved');
    }
    if (state['fishingActivity'] != null) {
      throw StateError('fishingActivityPending');
    }
    if (state['fishingPendingResult'] != null) {
      throw StateError('fishingResultMustBeClaimed');
    }
    final rawEquipment = state['fishingEquipment'];
    if (rawEquipment != null && rawEquipment is! Map) {
      throw const FormatException('Malformed fishing equipment.');
    }
    final rawFloat = rawEquipment is Map ? rawEquipment['float'] : null;
    final floatEquipped = rawFloat != null;
    if (floatEquipped &&
        (rawFloat is! Map ||
            rawFloat['itemId'] != 'toolpart.float' ||
            rawFloat['containerContents'] is! List ||
            (rawFloat['containerContents'] as List).length != 1 ||
            ((rawFloat['containerContents'] as List).single is! Map) ||
            ((rawFloat['containerContents'] as List).single as Map)['itemId'] !=
                'container.clean' ||
            ((rawFloat['containerContents'] as List).single
                    as Map)['containerState']
                is! Map ||
            (((rawFloat['containerContents'] as List).single
                        as Map)['containerState']
                    as Map)['cleanliness'] !=
                'clean')) {
      throw const FormatException('Malformed equipped fishing float.');
    }
    final stamina = state['stamina'] as int? ?? defaultStamina;
    if (defaultStamina < rules.castCost ||
        stamina < rules.castCost ||
        stamina > defaultStamina) {
      throw StateError('insufficientStamina');
    }
    final activity = <String, Object?>{
      'id': 'fishing-$commandId',
      'rulesVersion': rules.version,
      'spotId': spot.id,
      'bait': 'natural-free',
      'rod': 'loaner',
      'promptWidthPercent': streetScrapFishingPromptWidthPercent(
        basePromptWidthPercent: rules.basePromptWidthPercent,
        floatEquipped: floatEquipped,
      ),
      'costPaid': rules.castCost,
      'signals': <Object?>[],
      'consecutiveFailures': 0,
      'status': 'awaiting-signals',
      'guided':
          spot.id == 'dock_entrance' &&
          (state['fishingConsecutiveFailures'] as int? ?? 0) >=
              rules.guaranteeAfterFailures,
    };
    return StreetScrapReduction(
      state: {
        ...state,
        'stamina': stamina - rules.castCost,
        'fishingActivity': activity,
        'tutorialTasks': {
          ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
          'q2.01': true,
        },
      },
      result: activity,
    );
  },
);

/// Saves one of the three signal interactions. A normal cue needs a continuous
/// two-second hold; the third-attempt tutorial cue has no countdown.
Future<StreetScrapCommandResult> resolveStreetScrapFishingSignal({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapFishingRules rules,
  required int heldMilliseconds,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    rules.validate();
    final raw = state['fishingActivity'];
    if (raw is! Map ||
        raw['rulesVersion'] != rules.version ||
        raw['status'] != 'awaiting-signals') {
      throw StateError('fishingActivityMissing');
    }
    final signals = raw['signals'];
    if (signals is! List || signals.length >= rules.signalsPerCast) {
      throw StateError('fishingSignalSequenceInvalid');
    }
    if (heldMilliseconds < 0 || heldMilliseconds > 60000) {
      throw ArgumentError.value(heldMilliseconds, 'heldMilliseconds');
    }
    final guided = raw['guided'] == true;
    final success = guided || heldMilliseconds >= rules.signalHoldMilliseconds;
    final nextSignals = [
      ...signals,
      {'success': success, 'heldMilliseconds': heldMilliseconds},
    ];
    final complete = guided || nextSignals.length == rules.signalsPerCast;
    if (!complete) {
      return StreetScrapReduction(
        state: {
          ...state,
          'fishingActivity': {
            ...Map<String, Object?>.from(raw),
            'signals': nextSignals,
          },
        },
        result: {'success': success, 'complete': false},
      );
    }
    final successfulCount = nextSignals
        .where((signal) => (signal as Map)['success'] == true)
        .length;
    final caught = guided || successfulCount >= rules.successSignals;
    final consecutiveFailures =
        state['fishingConsecutiveFailures'] as int? ?? 0;
    final spot = rules.spots
        .where((entry) => entry.id == raw['spotId'])
        .firstOrNull;
    if (spot == null) throw StateError('fishingActivityMissing');
    final failureRewards = spot.failureRewards.isEmpty
        ? rules.failureRewards
        : spot.failureRewards;
    final pending = <String, Object?>{
      'activityId': raw['id'],
      'kind': caught ? 'fish' : 'shore-scrap',
      if (caught) ...{
        'itemId': 'fish.raw',
        'quality':
            50 +
            (!guided && successfulCount == rules.perfectSignals
                ? rules.preciseQualityBonus
                : 0),
      } else
        'choices': List<String>.of(failureRewards),
      'guided': guided,
      'successfulSignals': successfulCount,
    };
    return StreetScrapReduction(
      state: {
        ...state,
        'fishingActivity': null,
        'fishingPendingResult': pending,
        'fishingConsecutiveFailures': caught ? 0 : consecutiveFailures + 1,
      },
      result: {'success': success, 'complete': true, 'result': pending},
    );
  },
);

/// Transfers a completed fishing result into the backpack without duplicating
/// it if the claim command is replayed.
Future<StreetScrapCommandResult> claimStreetScrapFishingResult({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
  String? failureRewardItemId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final raw = state['fishingPendingResult'];
    if (raw is! Map) throw StateError('fishingResultMissing');
    final kind = raw['kind'];
    final itemId = kind == 'fish'
        ? raw['itemId'] as String?
        : failureRewardItemId;
    final choices = raw['choices'];
    if (itemId == null ||
        (kind != 'fish' && (choices is! List || !choices.contains(itemId)))) {
      throw StateError('fishingRewardChoiceInvalid');
    }
    final inventoryRaw = state['inventory'];
    if (inventoryRaw is! Map) throw StateError('fishingInventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(inventoryRaw),
    );
    final object = catalog.createObject(
      instanceId: 'fishing-${raw['activityId']}-reward',
      itemId: itemId,
      source: kind == 'fish'
          ? 'fishing:${raw['activityId']}'
          : 'fishing-shore:${raw['activityId']}',
      quality: kind == 'fish' ? raw['quality'] as int : 40,
      traits: const {},
    );
    final nextInventory = inventory.addAndPlaceFirstFit(object, backpackGridId);
    final tasks = Map<String, Object?>.from(state['tutorialTasks'] as Map);
    if (kind == 'fish') tasks['q2.02'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'inventory': nextInventory.toJson(),
        'tutorialTasks': tasks,
        'fishingPendingResult': null,
      },
      result: {'itemId': itemId, 'kind': kind},
    );
  },
);

/// Records the whole-fish path without consuming or lowering the fish's
/// identity, source, quality or placement.
Future<StreetScrapCommandResult> keepStreetScrapWholeFish({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapInventoryCatalog catalog,
  required Map<String, StreetScrapGridSpec> grids,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final rawTasks = state['tutorialTasks'];
    if (rawTasks is! Map || rawTasks['q2.02'] != true) {
      throw StateError('q2.02FishRequired');
    }
    if (rawTasks['q2.03'] == true) throw StateError('q2.03AlreadyComplete');
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('fishingInventoryMissing');
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final fish = inventory.objects.values
        .where(
          (item) =>
              item.itemId == 'fish.raw' && item.source.startsWith('fishing:'),
        )
        .firstOrNull;
    if (fish == null || !inventory.placements.containsKey(fish.instanceId)) {
      throw StateError('wholeFishUnavailable');
    }
    final tasks = Map<String, Object?>.from(rawTasks)..['q2.03'] = true;
    return StreetScrapReduction(
      state: {
        ...state,
        'chapter': 3,
        'tutorialTasks': tasks,
        'q2.03Choice': 'keep',
      },
      result: {'choice': 'keep', 'instanceId': fish.instanceId},
    );
  },
);
