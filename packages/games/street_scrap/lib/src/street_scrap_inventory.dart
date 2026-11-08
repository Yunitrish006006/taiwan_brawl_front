import 'dart:collection';
import 'dart:convert';

import 'street_scrap_module.dart';

/// Converts the pre-canonical scavenging save shape into object trait flags.
/// New saves always use `{traitId: true}`; this keeps offline object snapshots
/// written by older clients usable after an update.
Map<String, Object?> streetScrapNormalizeTraitMap(Map raw) {
  final traits = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is! String) {
      throw const FormatException('Invalid saved material trait ID.');
    }
    final key = entry.key! as String;
    final value = entry.value;
    if ((key == 'positive' || key == 'negative') && value is String) {
      traits[value] = true;
    } else {
      // Preserve other historical/forward-compatible metadata values; this
      // migration only rewrites the known legacy polarity wrapper.
      traits[key] = value;
    }
  }
  return traits;
}

/// A rectangular footprint from the versioned Street Scrap content catalog.
class StreetScrapFootprint {
  const StreetScrapFootprint(this.width, this.height)
    : assert(width > 0),
      assert(height > 0);

  final int width;
  final int height;

  StreetScrapFootprint rotated(bool rotation) =>
      rotation ? StreetScrapFootprint(height, width) : this;
}

class StreetScrapGridSpec {
  const StreetScrapGridSpec({
    required this.id,
    required this.width,
    required this.height,
  }) : assert(width > 0),
       assert(height > 0);

  final String id;
  final int width;
  final int height;
}

Map<String, StreetScrapGridSpec> streetScrapGridSpecsForState(
  Map<String, Object?> state,
) {
  final capacity = state['backpackCapacity'] ?? 16;
  if (capacity is! int || !{16, 24}.contains(capacity)) {
    throw const FormatException('Unsupported saved backpack capacity.');
  }
  return {
    'board': const StreetScrapGridSpec(id: 'board', width: 6, height: 6),
    'backpack': StreetScrapGridSpec(
      id: 'backpack',
      width: capacity ~/ 4,
      height: 4,
    ),
  };
}

class StreetScrapPackingRule {
  const StreetScrapPackingRule({
    required this.id,
    required this.inputItemId,
    required this.outputItemId,
    required this.count,
    required this.manualUnpack,
    List<String>? inputItemIds,
  }) : explicitInputItemIds = inputItemIds;

  final String id;
  final String inputItemId;
  final List<String>? explicitInputItemIds;
  List<String> get inputItemIds =>
      explicitInputItemIds ?? List<String>.filled(count, inputItemId);
  final String outputItemId;
  final int count;
  final bool manualUnpack;
}

class StreetScrapInventoryCatalog {
  StreetScrapInventoryCatalog({
    required Map<String, StreetScrapFootprint> footprints,
    required Map<String, StreetScrapPackingRule> packingRules,
    Map<String, int> baseDurabilities = const {},
  }) : footprints = UnmodifiableMapView(Map.of(footprints)),
       packingRules = UnmodifiableMapView(Map.of(packingRules)),
       baseDurabilities = UnmodifiableMapView(Map.of(baseDurabilities)) {
    for (final entry in this.footprints.entries) {
      if (entry.key.trim().isEmpty ||
          entry.value.width < 1 ||
          entry.value.height < 1) {
        throw const FormatException('Invalid inventory footprint catalog.');
      }
    }
    for (final entry in this.packingRules.entries) {
      final rule = entry.value;
      if (entry.key != rule.id ||
          rule.count < 1 ||
          rule.inputItemIds.length != rule.count ||
          rule.inputItemIds.any(
            (itemId) => !this.footprints.containsKey(itemId),
          ) ||
          !this.footprints.containsKey(rule.inputItemId) ||
          !this.footprints.containsKey(rule.outputItemId)) {
        throw const FormatException('Invalid inventory packing whitelist.');
      }
    }
    if (this.baseDurabilities.entries.any(
      (entry) => !this.footprints.containsKey(entry.key) || entry.value < 1,
    )) {
      throw const FormatException('Invalid base tool durability catalog.');
    }
  }

  factory StreetScrapInventoryCatalog.fromContentPayload(String source) {
    validateStreetScrapContentPayload(source);
    final payload = jsonDecode(source) as Map<String, dynamic>;
    final footprints = <String, StreetScrapFootprint>{};
    final baseDurabilities = <String, int>{};
    for (final raw in payload['itemDefinitions'] as List) {
      final definition = raw as Map;
      final itemId = definition['id'] as String;
      if (definition['baseDurability'] != null) {
        final durability = definition['baseDurability'];
        if (durability is! int || durability < 1) {
          throw FormatException('Invalid base durability for $itemId.');
        }
        baseDurabilities[itemId] = durability;
      }
      final footprint = definition['footprint'];
      if (footprint == null) continue;
      if (footprint is! List ||
          footprint.length != 2 ||
          footprint.any((dimension) => dimension is! int || dimension < 1)) {
        throw FormatException('Invalid footprint for $itemId.');
      }
      footprints[itemId] = StreetScrapFootprint(
        footprint[0] as int,
        footprint[1] as int,
      );
    }
    final rules = <String, StreetScrapPackingRule>{};
    for (final raw in payload['packing'] as List) {
      final rule = raw as Map;
      final input = rule['input'] as String;
      final output = rule['output'] as String;
      if (rules.containsKey(input) ||
          rules.values.any((existing) => existing.outputItemId == output) ||
          !footprints.containsKey(input) ||
          !footprints.containsKey(output)) {
        throw FormatException(
          'Packing rule footprint is missing for $input or $output.',
        );
      }
      rules[input] = StreetScrapPackingRule(
        id: input,
        inputItemId: input,
        outputItemId: output,
        count: rule['count'] as int,
        manualUnpack: rule['manualUnpack'] as bool,
        inputItemIds: rule['inputItems'] is List
            ? List<String>.unmodifiable(
                (rule['inputItems'] as List).cast<String>(),
              )
            : null,
      );
    }
    return StreetScrapInventoryCatalog(
      footprints: footprints,
      packingRules: rules,
      baseDurabilities: baseDurabilities,
    );
  }

  final Map<String, StreetScrapFootprint> footprints;
  final Map<String, StreetScrapPackingRule> packingRules;
  final Map<String, int> baseDurabilities;

  int? maximumDurability(
    String itemId,
    int quality,
    Map<String, Object?> traits,
  ) {
    final base = baseDurabilities[itemId];
    if (base == null) return null;
    final multiplier = quality < 40
        ? 0.85
        : quality < 70
        ? 1.0
        : quality < 90
        ? 1.1
        : 1.2;
    final traitMultiplier =
        traits['joint_skewed'] == true || traits['cracked'] == true ? 0.9 : 1.0;
    return (base * multiplier * traitMultiplier)
        .floor()
        .clamp(1, 1 << 31)
        .toInt();
  }

  int? upgradedDurability(
    StreetScrapObject item, {
    required String targetItemId,
    required int targetQuality,
  }) {
    final current = item.toolDurability;
    if (current == null) return null;
    final previousMaximum = maximumDurability(
      item.itemId,
      item.quality,
      item.traits,
    );
    final targetMaximum = maximumDurability(
      targetItemId,
      targetQuality,
      item.traits,
    );
    if (previousMaximum == null || targetMaximum == null) return current;
    if (current == 0) return 0;
    return (current.clamp(0, previousMaximum) / previousMaximum * targetMaximum)
        .floor();
  }

  StreetScrapObject createObject({
    required String instanceId,
    required String itemId,
    required String source,
    required int quality,
    required Map<String, Object?> traits,
    int? acquiredRevision,
    int? toolDurability,
    bool rotation = false,
    List<StreetScrapObject> containerContents = const [],
    Map<String, Object?> containerState = const {},
    List<Map<String, Object?>> provenance = const [],
  }) {
    final footprint = footprints[itemId];
    if (footprint == null) throw StateError('$itemId is not a grid object.');
    return StreetScrapObject(
      instanceId: instanceId,
      itemId: itemId,
      source: source,
      quality: quality,
      traits: traits,
      acquiredRevision: acquiredRevision,
      toolDurability:
          toolDurability ?? maximumDurability(itemId, quality, traits),
      footprint: footprint,
      rotation: rotation,
      containerContents: containerContents,
      containerState: containerState,
      provenance: provenance,
    );
  }

  StreetScrapInventory emptyInventory({
    required Map<String, StreetScrapGridSpec> grids,
  }) => StreetScrapInventory(
    catalog: this,
    grids: grids,
    objects: const {},
    placements: const {},
    storage: const {},
  );

  StreetScrapInventory inventoryFromJson({
    required Map<String, StreetScrapGridSpec> grids,
    required Map<String, Object?> json,
  }) => StreetScrapInventory.fromJson(catalog: this, grids: grids, json: json);
}

Map<String, Object?> _objectToJson(StreetScrapObject item) => {
  'instanceId': item.instanceId,
  'itemId': item.itemId,
  'source': item.source,
  if (item.acquiredRevision != null) 'acquiredRevision': item.acquiredRevision,
  'quality': item.quality,
  'traits': item.traits,
  if (item.provenance.isNotEmpty) 'provenance': item.provenance,
  'toolDurability': item.toolDurability,
  'rotation': item.rotation,
  'containerContents': item.containerContents.map(_objectToJson).toList(),
  'containerState': item.containerState,
};

Map<String, Object?> _provenanceInput(StreetScrapObject item) => {
  'instanceId': item.instanceId,
  'itemId': item.itemId,
  'source': item.source,
  'quality': item.quality,
  'traits': item.traits,
  if (item.acquiredRevision != null) 'acquiredRevision': item.acquiredRevision,
  if (item.provenance.isNotEmpty)
    'parentEventIds': [
      for (final event in item.provenance)
        if (event['eventId'] is String) event['eventId'],
    ],
};

bool _validProvenanceEvent(Object? raw) {
  if (raw is! Map ||
      raw['eventId'] is! String ||
      (raw['eventId'] as String).trim().isEmpty ||
      !const {'craft', 'transform', 'pack'}.contains(raw['kind']) ||
      (raw['recipeId'] != null && raw['recipeId'] is! String) ||
      (raw['revision'] != null &&
          (raw['revision'] is! int || (raw['revision'] as int) < 0)) ||
      (raw['outcome'] != null &&
          !const {'preview', 'success', 'failure'}.contains(raw['outcome'])) ||
      raw['inputs'] is! List ||
      (raw['inputs'] as List).any(
        (input) =>
            input is! Map ||
            input['instanceId'] is! String ||
            input['itemId'] is! String ||
            input['source'] is! String ||
            input['quality'] is! int ||
            input['quality'] < 0 ||
            input['quality'] > 100 ||
            input['traits'] is! Map ||
            (input['parentEventIds'] != null &&
                (input['parentEventIds'] is! List ||
                    (input['parentEventIds'] as List).any(
                      (id) => id is! String,
                    ))),
      )) {
    return false;
  }
  return true;
}

/// Item instance identity and provenance are persisted independently of its
/// current location. Packed children remain nested and are never duplicated as
/// top-level objects.
class StreetScrapObject {
  StreetScrapObject({
    required this.instanceId,
    required this.itemId,
    required this.source,
    required this.quality,
    required Map<String, Object?> traits,
    required this.toolDurability,
    this.acquiredRevision,
    required this.footprint,
    this.rotation = false,
    List<StreetScrapObject> containerContents = const [],
    Map<String, Object?> containerState = const {},
    List<Map<String, Object?>> provenance = const [],
  }) : traits = UnmodifiableMapView(
         _freezeTraits(streetScrapNormalizeTraitMap(traits)),
       ),
       containerContents = List.unmodifiable(containerContents),
       containerState = UnmodifiableMapView(_freezeTraits(containerState)),
       provenance = List.unmodifiable(
         provenance.map((entry) => _freezeTraits(entry)),
       ) {
    if (instanceId.trim().isEmpty ||
        itemId.trim().isEmpty ||
        source.trim().isEmpty) {
      throw ArgumentError('Object identity, item and source are required.');
    }
    if (quality < 0 ||
        quality > 100 ||
        (toolDurability != null && toolDurability! < 0)) {
      throw ArgumentError('Invalid quality or tool durability.');
    }
  }

  final String instanceId;
  final String itemId;
  final String source;
  final int quality;
  final Map<String, Object?> traits;
  final int? toolDurability;
  final int? acquiredRevision;
  final StreetScrapFootprint footprint;
  final bool rotation;
  final List<StreetScrapObject> containerContents;
  final Map<String, Object?> containerState;
  final List<Map<String, Object?>> provenance;

  StreetScrapObject copyWith({
    String? itemId,
    Map<String, Object?>? traits,
    StreetScrapFootprint? footprint,
    bool? rotation,
    int? quality,
    List<StreetScrapObject>? containerContents,
    Map<String, Object?>? containerState,
    int? toolDurability,
    int? acquiredRevision,
    List<Map<String, Object?>>? provenance,
  }) => StreetScrapObject(
    instanceId: instanceId,
    itemId: itemId ?? this.itemId,
    source: source,
    quality: quality ?? this.quality,
    traits: traits ?? this.traits,
    toolDurability: toolDurability ?? this.toolDurability,
    acquiredRevision: acquiredRevision ?? this.acquiredRevision,
    footprint: footprint ?? this.footprint,
    rotation: rotation ?? this.rotation,
    containerContents: containerContents ?? this.containerContents,
    containerState: containerState ?? this.containerState,
    provenance: provenance ?? this.provenance,
  );
}

class StreetScrapPlacement {
  const StreetScrapPlacement({
    required this.instanceId,
    required this.gridId,
    required this.x,
    required this.y,
    required this.rotation,
  });

  final String instanceId;
  final String gridId;
  final int x;
  final int y;
  final bool rotation;

  StreetScrapPlacement copyWith({
    String? gridId,
    int? x,
    int? y,
    bool? rotation,
  }) => StreetScrapPlacement(
    instanceId: instanceId,
    gridId: gridId ?? this.gridId,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
  );
}

/// Pure SS-03 inventory rules. Each operation returns a new index or throws;
/// callers persist the returned value in one session command/CAS.
class StreetScrapInventory {
  StreetScrapInventory({
    required this.catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required Map<String, StreetScrapObject> objects,
    required Map<String, StreetScrapPlacement> placements,
    required Map<String, List<String>> storage,
  }) : grids = UnmodifiableMapView(Map.of(grids)),
       objects = UnmodifiableMapView(Map.of(objects)),
       placements = UnmodifiableMapView(Map.of(placements)),
       storage = UnmodifiableMapView({
         for (final entry in storage.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }) {
    _validateIdentity();
    _validatePlacements();
  }

  final Map<String, StreetScrapGridSpec> grids;
  final StreetScrapInventoryCatalog catalog;
  Map<String, StreetScrapPackingRule> get packingRules => catalog.packingRules;
  final Map<String, StreetScrapObject> objects;
  final Map<String, StreetScrapPlacement> placements;
  final Map<String, List<String>> storage;

  Map<String, Object?> toJson() => {
    'objects': [for (final item in objects.values) _objectToJson(item)],
    'placements': [
      for (final placement in placements.values)
        {
          'instanceId': placement.instanceId,
          'gridId': placement.gridId,
          'x': placement.x,
          'y': placement.y,
          'rotation': placement.rotation,
        },
    ],
    'storage': storage,
  };

  /// Consumes an explicitly selected set of top-level objects from one grid.
  /// Nested container contents and stored objects cannot be consumed this way.
  StreetScrapInventory consumeFromGrid(
    List<String> instanceIds,
    String gridId,
  ) {
    if (instanceIds.isEmpty ||
        instanceIds.toSet().length != instanceIds.length) {
      throw ArgumentError('Select distinct objects to consume.');
    }
    final nextObjects = Map<String, StreetScrapObject>.of(objects);
    final nextPlacements = Map<String, StreetScrapPlacement>.of(placements);
    for (final instanceId in instanceIds) {
      final item = _requireTopLevel(instanceId);
      if (item.containerContents.isNotEmpty ||
          placements[instanceId]?.gridId != gridId) {
        throw StateError('Selected object is not consumable from $gridId.');
      }
      nextObjects.remove(instanceId);
      nextPlacements.remove(instanceId);
    }
    return _copy(objects: nextObjects, placements: nextPlacements);
  }

  /// Moves a top-level object out of a carried grid while preserving its full
  /// snapshot, including nested contents. Dedicated equipment/facility slots
  /// use this instead of consuming the packed object and its retained items.
  StreetScrapInventory detachFromGrid(String instanceId, String gridId) {
    _requireTopLevel(instanceId);
    if (placements[instanceId]?.gridId != gridId) {
      throw StateError('Selected object is not placed on $gridId.');
    }
    return _copy(
      objects: Map.of(objects)..remove(instanceId),
      placements: Map.of(placements)..remove(instanceId),
      storage: _withoutStorageId(instanceId),
    );
  }

  /// Replaces the saved durability value without changing the tool's identity,
  /// provenance, quality, traits, footprint, placement, or nested contents.
  StreetScrapInventory withToolDurability(String instanceId, int durability) {
    if (durability < 0) throw RangeError.value(durability, 'durability');
    final item = _requireTopLevel(instanceId);
    if (item.toolDurability == null || item.containerContents.isNotEmpty) {
      throw StateError('Selected object is not a repairable tool.');
    }
    return _copy(
      objects: Map.of(objects)
        ..[instanceId] = item.copyWith(toolDurability: durability),
    );
  }

  /// Replaces an object's trait map without changing its identity or placement.
  StreetScrapInventory withTraits(
    String instanceId,
    Map<String, Object?> traits,
  ) {
    final item = _requireTopLevel(instanceId);
    if (item.containerContents.isNotEmpty) {
      throw StateError('A packed solid container cannot be trait-modified.');
    }
    return _copy(
      objects: Map.of(objects)..[instanceId] = item.copyWith(traits: traits),
    );
  }

  /// Replaces liquid metadata on the same top-level vessel without moving or
  /// recreating the vessel object.
  StreetScrapInventory withContainerState(
    String instanceId,
    Map<String, Object?> containerState,
  ) {
    final item = _requireTopLevel(instanceId);
    if (item.containerContents.isNotEmpty) {
      throw StateError('A packed solid container cannot hold liquid state.');
    }
    return _copy(
      objects: Map.of(objects)
        ..[instanceId] = item.copyWith(containerState: containerState),
    );
  }

  StreetScrapInventory appendProvenanceEvent({
    required String instanceId,
    required Map<String, Object?> event,
    Iterable<StreetScrapObject> relatedInputs = const [],
  }) {
    final item = _requireTopLevel(instanceId);
    return _copy(
      objects: Map.of(objects)
        ..[instanceId] = item.copyWith(
          provenance: _mergeProvenance([item, ...relatedInputs], event),
        ),
    );
  }

  /// Upgrades an existing top-level object without changing its instance id,
  /// source, placement, or container contents.
  StreetScrapInventory transformObjectType({
    required String instanceId,
    required String fromItemId,
    required String toItemId,
    int? quality,
    bool clearContainerState = false,
    Map<String, Object?>? containerState,
    List<Map<String, Object?>>? provenance,
    int? toolDurability,
  }) {
    final item = _requireTopLevel(instanceId);
    final targetFootprint = catalog.footprints[toItemId];
    if (item.itemId != fromItemId || targetFootprint == null) {
      throw StateError('Object cannot be transformed to $toItemId.');
    }
    return _copy(
      objects: Map.of(objects)
        ..[instanceId] = item.copyWith(
          itemId: toItemId,
          footprint: targetFootprint,
          quality: quality,
          toolDurability: toolDurability ?? item.toolDurability,
          containerState:
              containerState ??
              (clearContainerState ? const <String, Object?>{} : null),
          provenance: provenance ?? item.provenance,
        ),
    );
  }

  /// Adds a newly acquired object and reserves its first fitting grid location
  /// as one immutable operation. If no placement exists, the source is intact.
  StreetScrapInventory addAndPlaceFirstFit(
    StreetScrapObject item,
    String gridId,
  ) {
    if (objects.containsKey(item.instanceId)) {
      throw StateError('Object identity already exists.');
    }
    if (!catalog.footprints.containsKey(item.itemId)) {
      throw StateError('Unknown grid item ${item.itemId}.');
    }
    return _copy(
      objects: Map.of(objects)..[item.instanceId] = item,
    ).placeFirstFit(item.instanceId, gridId);
  }

  factory StreetScrapInventory.fromJson({
    required StreetScrapInventoryCatalog catalog,
    required Map<String, StreetScrapGridSpec> grids,
    required Map<String, Object?> json,
  }) {
    final rawObjects = json['objects'];
    final rawPlacements = json['placements'];
    final rawStorage = json['storage'];
    if (rawObjects is! List || rawPlacements is! List || rawStorage is! Map) {
      throw const FormatException('Malformed Street Scrap inventory.');
    }
    StreetScrapObject readObject(Object? raw) {
      if (raw is! Map ||
          raw['instanceId'] is! String ||
          raw['itemId'] is! String ||
          raw['source'] is! String ||
          raw['quality'] is! int ||
          (raw['acquiredRevision'] != null &&
              (raw['acquiredRevision'] is! int ||
                  raw['acquiredRevision'] < 0)) ||
          raw['traits'] is! Map ||
          (raw['toolDurability'] != null && raw['toolDurability'] is! int) ||
          (raw['rotation'] != null && raw['rotation'] is! bool) ||
          (raw['containerContents'] != null &&
              raw['containerContents'] is! List) ||
          (raw['containerState'] != null && raw['containerState'] is! Map) ||
          (raw['provenance'] != null && raw['provenance'] is! List)) {
        throw const FormatException('Malformed Street Scrap object.');
      }
      final provenance = raw['provenance'] as List? ?? const [];
      if (provenance.any((event) => !_validProvenanceEvent(event))) {
        throw const FormatException('Malformed Street Scrap provenance.');
      }
      final containerState = raw['containerState'] is Map
          ? Map<String, Object?>.from(raw['containerState'] as Map)
          : const <String, Object?>{};
      if ((containerState['contentItemId'] != null &&
              containerState['contentItemId'] is! String) ||
          (containerState['contentQuality'] != null &&
              (containerState['contentQuality'] is! int ||
                  (containerState['contentQuality'] as int) < 0 ||
                  (containerState['contentQuality'] as int) > 100)) ||
          (containerState['contentSource'] != null &&
              containerState['contentSource'] is! String) ||
          (containerState['contentTraits'] != null &&
              containerState['contentTraits'] is! Map) ||
          (containerState['requiresBoiling'] != null &&
              containerState['requiresBoiling'] is! bool) ||
          (containerState['cleanliness'] != null &&
              !const {
                'clean',
                'utility',
                'soiled',
              }.contains(containerState['cleanliness']))) {
        throw const FormatException('Malformed Street Scrap vessel state.');
      }
      return catalog.createObject(
        instanceId: raw['instanceId'] as String,
        itemId: raw['itemId'] as String,
        source: raw['source'] as String,
        quality: raw['quality'] as int,
        traits: Map<String, Object?>.from(raw['traits'] as Map),
        toolDurability: raw['toolDurability'] as int?,
        acquiredRevision: raw['acquiredRevision'] as int?,
        rotation: raw['rotation'] as bool? ?? false,
        containerContents: [
          for (final child in (raw['containerContents'] as List? ?? const []))
            readObject(child),
        ],
        containerState: containerState,
        provenance: [
          for (final event in provenance)
            Map<String, Object?>.from(event as Map),
        ],
      );
    }

    final objects = <String, StreetScrapObject>{};
    for (final raw in rawObjects) {
      final item = readObject(raw);
      if (objects.containsKey(item.instanceId)) {
        throw const FormatException('Duplicate saved object.');
      }
      objects[item.instanceId] = item;
    }
    final placements = <String, StreetScrapPlacement>{};
    for (final raw in rawPlacements) {
      if (raw is! Map ||
          raw['instanceId'] is! String ||
          raw['gridId'] is! String ||
          raw['x'] is! int ||
          raw['y'] is! int ||
          raw['rotation'] is! bool) {
        throw const FormatException('Malformed Street Scrap placement.');
      }
      final placement = StreetScrapPlacement(
        instanceId: raw['instanceId'] as String,
        gridId: raw['gridId'] as String,
        x: raw['x'] as int,
        y: raw['y'] as int,
        rotation: raw['rotation'] as bool,
      );
      if (placements.containsKey(placement.instanceId)) {
        throw const FormatException('Duplicate saved placement.');
      }
      placements[placement.instanceId] = placement;
    }
    // Older saves may contain the orientation mismatch produced by
    // placeFirstFit before it synchronized the object's rotation field. A
    // saved grid placement is authoritative; normalize in memory so the next
    // successful transaction persists the repaired snapshot without moving
    // or replacing the item.
    for (final entry in placements.entries) {
      final item = objects[entry.key];
      if (item != null && item.rotation != entry.value.rotation) {
        objects[entry.key] = item.copyWith(rotation: entry.value.rotation);
      }
    }
    final storage = <String, List<String>>{};
    for (final entry in rawStorage.entries) {
      if (entry.key is! String ||
          entry.value is! List ||
          (entry.value as List).any((id) => id is! String)) {
        throw const FormatException('Malformed Street Scrap storage.');
      }
      storage[entry.key as String] = List<String>.from(entry.value as List);
    }
    return StreetScrapInventory(
      catalog: catalog,
      grids: grids,
      objects: objects,
      placements: placements,
      storage: storage,
    );
  }

  StreetScrapInventory move(String instanceId, String gridId, int x, int y) {
    final item = _requireTopLevel(instanceId);
    final old = placements[instanceId];
    final next = Map<String, StreetScrapPlacement>.of(placements);
    next[instanceId] = StreetScrapPlacement(
      instanceId: instanceId,
      gridId: gridId,
      x: x,
      y: y,
      rotation: old?.rotation ?? item.rotation,
    );
    return _copy(placements: next, storage: _withoutStorageId(instanceId));
  }

  /// Removes an item's grid placement while retaining its identity and data.
  /// Used to reverse a recent move back to the unplaced inventory state.
  StreetScrapInventory unplace(String instanceId) {
    _requireTopLevel(instanceId);
    return _copy(placements: Map.of(placements)..remove(instanceId));
  }

  StreetScrapInventory placeFirstFit(String instanceId, String gridId) {
    final item = _requireTopLevel(instanceId);
    final grid = grids[gridId];
    if (grid == null) throw StateError('Unknown grid.');
    final occupied = _occupied(gridId, excluding: {instanceId});
    final placement = _findSpace(item, grid, occupied);
    if (placement == null) {
      throw StateError('No fitting space for ${item.itemId}.');
    }
    return _copy(
      // The selected orientation is persisted both on the object and on its
      // placement. Keep them in sync when only the rotated footprint fits.
      objects: Map.of(objects)
        ..[instanceId] = item.copyWith(rotation: placement.rotation),
      placements: Map.of(placements)..[instanceId] = placement,
      storage: _withoutStorageId(instanceId),
    );
  }

  StreetScrapInventory rotate(String instanceId) {
    final item = _requireTopLevel(instanceId);
    final current = placements[instanceId];
    if (current == null) throw StateError('Object is not on a grid.');
    final nextRotation = !current.rotation;
    final next = Map<String, StreetScrapPlacement>.of(placements)
      ..[instanceId] = current.copyWith(rotation: nextRotation);
    return _copy(
      objects: Map.of(objects)
        ..[instanceId] = item.copyWith(rotation: nextRotation),
      placements: next,
    );
  }

  StreetScrapInventory store(String instanceId, String storageId) {
    _requireTopLevel(instanceId);
    if (!storage.containsKey(storageId)) throw StateError('Unknown storage.');
    final nextPlacement = Map<String, StreetScrapPlacement>.of(placements)
      ..remove(instanceId);
    final nextStorage = _withoutStorageId(instanceId)
      ..[storageId]!.add(instanceId);
    return _copy(placements: nextPlacement, storage: nextStorage);
  }

  StreetScrapInventory withdraw(
    String instanceId,
    String storageId,
    String gridId,
    int x,
    int y,
  ) {
    final stored = storage[storageId];
    if (stored == null || !stored.contains(instanceId)) {
      throw StateError('Object is not in this storage.');
    }
    final nextStorage = _mutableStorage()..[storageId]!.remove(instanceId);
    final item = objects[instanceId]!;
    final nextPlacements = Map<String, StreetScrapPlacement>.of(placements)
      ..[instanceId] = StreetScrapPlacement(
        instanceId: instanceId,
        gridId: gridId,
        x: x,
        y: y,
        rotation: item.rotation,
      );
    return _copy(placements: nextPlacements, storage: nextStorage);
  }

  StreetScrapInventory pack({
    required String ruleId,
    required List<String> inputInstanceIds,
    required String source,
    required String containerInstanceId,
    Map<String, Object?>? provenanceEvent,
    Iterable<StreetScrapObject> provenanceInputs = const [],
  }) {
    final rule = packingRules[ruleId];
    if (rule == null) throw StateError('Unknown packing rule.');
    if (rule.count < 1 ||
        rule.inputItemId.isEmpty ||
        rule.outputItemId.isEmpty) {
      throw ArgumentError('Invalid packing rule.');
    }
    if (inputInstanceIds.length != rule.count ||
        inputInstanceIds.toSet().length != inputInstanceIds.length) {
      throw StateError(
        'Packing requires exactly ${rule.count} distinct objects.',
      );
    }
    final expected = <String, int>{};
    for (final itemId in rule.inputItemIds) {
      expected.update(itemId, (count) => count + 1, ifAbsent: () => 1);
    }
    final children = <StreetScrapObject>[];
    for (final id in inputInstanceIds) {
      final item = objects[id];
      if (item == null || item.containerContents.isNotEmpty) {
        throw StateError(
          'A selected object is not valid for this packing rule.',
        );
      }
      children.add(item);
    }
    final actual = <String, int>{};
    for (final child in children) {
      actual.update(child.itemId, (count) => count + 1, ifAbsent: () => 1);
    }
    if (!_sameItemCounts(expected, actual)) {
      throw StateError('Selected objects do not match this packing rule.');
    }
    final ids = children.map((item) => item.instanceId).toSet();
    final nextObjects = Map<String, StreetScrapObject>.of(objects)
      ..removeWhere((id, _) => ids.contains(id));
    final nextPlacements = Map<String, StreetScrapPlacement>.of(placements)
      ..removeWhere((id, _) => ids.contains(id));
    final nextStorage = _mutableStorage();
    for (final contents in nextStorage.values) {
      contents.removeWhere(ids.contains);
    }
    final packed = StreetScrapObject(
      instanceId: containerInstanceId,
      itemId: rule.outputItemId,
      source: source,
      quality: children
          .map((item) => item.quality)
          .reduce((a, b) => a < b ? a : b),
      traits: const {'packed': true},
      toolDurability: null,
      footprint: catalog.footprints[rule.outputItemId]!,
      containerContents: children,
      provenance: _mergeProvenance(
        [...children, ...provenanceInputs],
        provenanceEvent ??
            {
              'eventId': 'pack:$containerInstanceId',
              'kind': 'pack',
              'inputs': children.map(_provenanceInput).toList(growable: false),
            },
      ),
    );
    if (objects.containsKey(containerInstanceId)) {
      throw StateError('Duplicate container instance id.');
    }
    nextObjects[containerInstanceId] = packed;
    return _copy(
      objects: nextObjects,
      placements: nextPlacements,
      storage: nextStorage,
    );
  }

  StreetScrapInventory unpack({
    required String containerInstanceId,
    required String gridId,
  }) {
    final container = objects[containerInstanceId];
    if (container == null || container.containerContents.isEmpty) {
      throw StateError('Container is empty or missing.');
    }
    final rule = packingRules.values
        .where((candidate) => candidate.outputItemId == container.itemId)
        .firstOrNull;
    if (rule == null) {
      throw StateError('Container does not match a packing rule.');
    }
    if (!rule.manualUnpack ||
        container.itemId != rule.outputItemId ||
        container.containerContents.length != rule.count ||
        !_sameItemCounts(
          _itemCounts(rule.inputItemIds),
          _itemCounts(container.containerContents.map((child) => child.itemId)),
        )) {
      throw StateError(
        'Container does not match an available manual unpack rule.',
      );
    }
    final grid = grids[gridId];
    if (grid == null) throw StateError('Unknown grid.');
    final nextObjects = Map<String, StreetScrapObject>.of(objects)
      ..remove(containerInstanceId);
    final nextPlacements = Map<String, StreetScrapPlacement>.of(placements)
      ..remove(containerInstanceId);
    final nextStorage = _withoutStorageId(containerInstanceId);
    final occupied = _occupied(gridId, excluding: {containerInstanceId});
    final planned = <StreetScrapPlacement>[];
    for (final child in container.containerContents) {
      final placement = _findSpace(child, grid, occupied);
      if (placement == null) {
        throw StateError('Not enough space to unpack every object.');
      }
      planned.add(placement);
      _mark(child, placement, occupied);
      nextObjects[child.instanceId] = child;
    }
    for (final placement in planned) {
      nextPlacements[placement.instanceId] = placement;
    }
    return _copy(
      objects: nextObjects,
      placements: nextPlacements,
      storage: nextStorage,
    );
  }

  StreetScrapObject _requireTopLevel(String id) {
    final item = objects[id];
    if (item == null) throw StateError('Unknown object.');
    return item;
  }

  StreetScrapInventory _copy({
    Map<String, StreetScrapObject>? objects,
    Map<String, StreetScrapPlacement>? placements,
    Map<String, List<String>>? storage,
  }) => StreetScrapInventory(
    catalog: catalog,
    grids: grids,
    objects: objects ?? this.objects,
    placements: placements ?? this.placements,
    storage: storage ?? _mutableStorage(),
  );

  Map<String, List<String>> _mutableStorage() => {
    for (final entry in storage.entries)
      entry.key: List<String>.of(entry.value),
  };

  Map<String, List<String>> _withoutStorageId(String instanceId) {
    final next = _mutableStorage();
    for (final contents in next.values) {
      contents.removeWhere((id) => id == instanceId);
    }
    return next;
  }

  void _validateIdentity() {
    for (final entry in grids.entries) {
      if (entry.key != entry.value.id || entry.key.trim().isEmpty) {
        throw const FormatException('Grid keys must match their stable IDs.');
      }
    }
    for (final entry in packingRules.entries) {
      if (entry.key != entry.value.id || entry.value.count < 1) {
        throw const FormatException(
          'Packing rule keys must match valid rule IDs.',
        );
      }
    }
    final allIds = <String>{};
    void add(StreetScrapObject item) {
      if (!allIds.add(item.instanceId)) {
        throw FormatException('Duplicate object instance ${item.instanceId}.');
      }
      for (final child in item.containerContents) {
        add(child);
      }
    }

    for (final entry in objects.entries) {
      if (entry.key != entry.value.instanceId) {
        throw FormatException(
          'Object key does not match instance ${entry.value.instanceId}.',
        );
      }
      _validateCatalogFootprint(entry.value);
      add(entry.value);
    }
    for (final entry in placements.entries) {
      if (entry.key != entry.value.instanceId ||
          !objects.containsKey(entry.key)) {
        throw FormatException(
          'Placement refers to a missing or mismatched object ${entry.key}.',
        );
      }
    }
    final owners = <String>{...placements.keys};
    for (final ids in storage.values) {
      for (final id in ids) {
        if (!objects.containsKey(id) || !owners.add(id)) {
          throw FormatException('Invalid or duplicate object owner $id.');
        }
      }
    }
  }

  void _validateCatalogFootprint(StreetScrapObject item) {
    final expected = catalog.footprints[item.itemId];
    if (expected == null ||
        expected.width != item.footprint.width ||
        expected.height != item.footprint.height) {
      throw FormatException(
        'Object ${item.instanceId} does not match the content footprint.',
      );
    }
    for (final child in item.containerContents) {
      _validateCatalogFootprint(child);
    }
  }

  void _validatePlacements() {
    final occupied = <String, Set<String>>{};
    for (final placement in placements.values) {
      final grid = grids[placement.gridId];
      final item = objects[placement.instanceId]!;
      if (grid == null || item.rotation != placement.rotation) {
        throw FormatException('Invalid placed object or rotation.');
      }
      final cells = occupied.putIfAbsent(placement.gridId, () => <String>{});
      final proposed = <String>{};
      _mark(item, placement, proposed, grid: grid);
      if (proposed.any(cells.contains)) {
        throw FormatException('Overlapping objects on ${placement.gridId}.');
      }
      cells.addAll(proposed);
    }
  }

  Set<String> _occupied(String gridId, {Set<String> excluding = const {}}) {
    final result = <String>{};
    final grid = grids[gridId]!;
    for (final placement in placements.values.where(
      (p) => p.gridId == gridId && !excluding.contains(p.instanceId),
    )) {
      _mark(objects[placement.instanceId]!, placement, result, grid: grid);
    }
    return result;
  }

  StreetScrapPlacement? _findSpace(
    StreetScrapObject item,
    StreetScrapGridSpec grid,
    Set<String> occupied,
  ) {
    for (final rotation in [item.rotation, !item.rotation]) {
      final size = item.footprint.rotated(rotation);
      for (var y = 0; y <= grid.height - size.height; y++) {
        for (var x = 0; x <= grid.width - size.width; x++) {
          final candidate = StreetScrapPlacement(
            instanceId: item.instanceId,
            gridId: grid.id,
            x: x,
            y: y,
            rotation: rotation,
          );
          final cells = <String>{};
          _mark(item, candidate, cells, grid: grid);
          if (!cells.any(occupied.contains)) return candidate;
        }
      }
    }
    return null;
  }

  void _mark(
    StreetScrapObject item,
    StreetScrapPlacement p,
    Set<String> cells, {
    StreetScrapGridSpec? grid,
  }) {
    final bounds = grid ?? grids[p.gridId];
    if (bounds == null) throw StateError('Unknown grid ${p.gridId}.');
    final size = item.footprint.rotated(p.rotation);
    if (p.x < 0 ||
        p.y < 0 ||
        p.x + size.width > bounds.width ||
        p.y + size.height > bounds.height) {
      throw FormatException(
        'Object ${item.instanceId} is outside ${bounds.id}.',
      );
    }
    for (var dy = 0; dy < size.height; dy++) {
      for (var dx = 0; dx < size.width; dx++) {
        cells.add('${p.x + dx},${p.y + dy}');
      }
    }
  }
}

List<Map<String, Object?>> _mergeProvenance(
  Iterable<StreetScrapObject> inputs,
  Map<String, Object?> event,
) {
  final events = <String, Map<String, Object?>>{};
  for (final input in inputs) {
    for (final prior in input.provenance) {
      final id = prior['eventId'];
      if (id is String) events.putIfAbsent(id, () => prior);
    }
  }
  final eventId = event['eventId'];
  if (eventId is! String ||
      eventId.trim().isEmpty ||
      !_validProvenanceEvent(event)) {
    throw ArgumentError('Invalid provenance event.');
  }
  events[eventId] = event;
  return List.unmodifiable(events.values);
}

Map<String, int> _itemCounts(Iterable<String> itemIds) {
  final counts = <String, int>{};
  for (final itemId in itemIds) {
    counts.update(itemId, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

bool _sameItemCounts(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  return a.entries.every((entry) => b[entry.key] == entry.value);
}

Map<String, Object?> _freezeTraits(Map<String, Object?> source) => {
  for (final entry in source.entries) entry.key: _freezeTrait(entry.value),
};

Object? _freezeTrait(Object? value) {
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('Trait maps require string keys.');
      }
      result[entry.key as String] = _freezeTrait(entry.value);
    }
    return UnmodifiableMapView(result);
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeTrait));
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('Traits must be JSON values.');
}
