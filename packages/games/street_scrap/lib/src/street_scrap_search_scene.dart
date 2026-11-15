import 'dart:collection';
import 'dart:math';

/// The visual concealment state of a collectible in a search scene.
enum StreetScrapSearchConcealment {
  visible,
  partiallyHidden,
  partiallyBuried,
  fullyBuried,
}

extension StreetScrapSearchConcealmentJson on StreetScrapSearchConcealment {
  String get jsonName => switch (this) {
    StreetScrapSearchConcealment.visible => 'visible',
    StreetScrapSearchConcealment.partiallyHidden => 'partiallyHidden',
    StreetScrapSearchConcealment.partiallyBuried => 'partiallyBuried',
    StreetScrapSearchConcealment.fullyBuried => 'fullyBuried',
  };
}

StreetScrapSearchConcealment _concealmentFromJson(Object? value) =>
    switch (value) {
      'visible' => StreetScrapSearchConcealment.visible,
      'partiallyHidden' => StreetScrapSearchConcealment.partiallyHidden,
      'partiallyBuried' => StreetScrapSearchConcealment.partiallyBuried,
      'fullyBuried' => StreetScrapSearchConcealment.fullyBuried,
      _ => throw const FormatException('Invalid search concealment.'),
    };

/// A normalized region in the background where generated objects may appear.
/// Coordinates use 0..1 so the same scene works on phones and tablets.
class StreetScrapSearchZone {
  const StreetScrapSearchZone({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.allowedCategories,
    required this.supportsBuried,
    this.maxItems = 3,
  });

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final Set<String> allowedCategories;
  final bool supportsBuried;
  final int maxItems;

  bool accepts(String category, {required bool buried}) =>
      allowedCategories.contains(category) && (!buried || supportsBuried);

  Map<String, Object?> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'allowedCategories': allowedCategories.toList()..sort(),
    'supportsBuried': supportsBuried,
    'maxItems': maxItems,
  };
}

/// The placement-independent physical rules for a collectible.
class StreetScrapSearchItemSpec {
  const StreetScrapSearchItemSpec({
    required this.itemId,
    required this.category,
    required this.weight,
    required this.volume,
    required this.width,
    required this.height,
    required this.rarity,
    required this.allowedZoneIds,
    this.canBeBuried = false,
  });

  final String itemId;
  final String category;
  final double weight;
  final double volume;
  final double width;
  final double height;
  final int rarity;
  final Set<String> allowedZoneIds;
  final bool canBeBuried;

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'category': category,
    'weight': weight,
    'volume': volume,
    'width': width,
    'height': height,
    'rarity': rarity,
    'allowedZoneIds': allowedZoneIds.toList()..sort(),
    'canBeBuried': canBeBuried,
  };
}

/// A generated object instance. This is the state that the UI and save layer
/// consume; the generator itself does not mutate inventory or stamina.
class StreetScrapSearchPlacement {
  const StreetScrapSearchPlacement({
    required this.id,
    required this.itemId,
    required this.zoneId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.concealment,
    required this.requiresTool,
    this.rotation = 0,
    this.collected = false,
  });

  final String id;
  final String itemId;
  final String zoneId;
  final double x;
  final double y;
  final double width;
  final double height;
  final StreetScrapSearchConcealment concealment;
  final String? requiresTool;

  /// Small visual rotation in radians. This is presentation data only.
  final double rotation;
  final bool collected;

  bool get isBuried =>
      concealment == StreetScrapSearchConcealment.partiallyBuried ||
      concealment == StreetScrapSearchConcealment.fullyBuried;

  Map<String, Object?> toJson() => {
    'id': id,
    'itemId': itemId,
    'zoneId': zoneId,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'concealment': concealment.jsonName,
    'rotation': rotation,
    if (requiresTool != null) 'requiresTool': requiresTool,
    'collected': collected,
  };

  factory StreetScrapSearchPlacement.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final itemId = json['itemId'];
    final zoneId = json['zoneId'];
    if (id is! String || itemId is! String || zoneId is! String) {
      throw const FormatException('Invalid search placement identity.');
    }
    return StreetScrapSearchPlacement(
      id: id,
      itemId: itemId,
      zoneId: zoneId,
      x: _number(json['x'], 'search placement x'),
      y: _number(json['y'], 'search placement y'),
      width: _number(json['width'], 'search placement width'),
      height: _number(json['height'], 'search placement height'),
      concealment: _concealmentFromJson(json['concealment']),
      requiresTool: json['requiresTool'] as String?,
      rotation: _number(json['rotation'] ?? 0, 'search placement rotation'),
      collected: json['collected'] == true,
    );
  }
}

class StreetScrapSearchVariant {
  StreetScrapSearchVariant({
    required this.sceneId,
    required this.seed,
    required this.generatorVersion,
    required List<StreetScrapSearchPlacement> placements,
  }) : placements = List.unmodifiable(placements);

  final String sceneId;
  final int seed;
  final int generatorVersion;
  final List<StreetScrapSearchPlacement> placements;

  Map<String, Object?> toJson() => {
    'sceneId': sceneId,
    'seed': seed,
    'generatorVersion': generatorVersion,
    'placements': placements.map((placement) => placement.toJson()).toList(),
  };

  factory StreetScrapSearchVariant.fromJson(Map<String, Object?> json) {
    final raw = json['placements'];
    if (raw is! List) throw const FormatException('Invalid search placements.');
    return StreetScrapSearchVariant(
      sceneId: json['sceneId'] as String,
      seed: json['seed'] as int,
      generatorVersion: json['generatorVersion'] as int,
      placements: raw
          .map(
            (value) => StreetScrapSearchPlacement.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList(),
    );
  }
}

class StreetScrapSearchSceneDefinition {
  StreetScrapSearchSceneDefinition({
    required this.sceneId,
    required this.backgroundResourceId,
    required List<StreetScrapSearchZone> zones,
    required List<StreetScrapSearchItemSpec> items,
    this.minimumItems = 5,
    this.maximumItems = 20,
  }) : zones = List.unmodifiable(zones),
       items = List.unmodifiable(items);

  final String sceneId;
  final String backgroundResourceId;
  final List<StreetScrapSearchZone> zones;
  final List<StreetScrapSearchItemSpec> items;
  final int minimumItems;
  final int maximumItems;

  StreetScrapSearchZone zone(String id) => zones.firstWhere(
    (zone) => zone.id == id,
    orElse: () => throw StateError('Unknown search zone: $id'),
  );

  StreetScrapSearchItemSpec item(String id) => items.firstWhere(
    (item) => item.itemId == id,
    orElse: () => throw StateError('Unknown search item: $id'),
  );

  void validate() {
    if (sceneId.trim().isEmpty ||
        backgroundResourceId.trim().isEmpty ||
        zones.length < 8 ||
        items.length < 10 ||
        minimumItems < 1 ||
        maximumItems < minimumItems) {
      throw const FormatException('Invalid search scene definition.');
    }
    final zoneIds = <String>{};
    for (final zone in zones) {
      if (!zoneIds.add(zone.id) ||
          zone.id.trim().isEmpty ||
          zone.x < 0 ||
          zone.y < 0 ||
          zone.width <= 0 ||
          zone.height <= 0 ||
          zone.x + zone.width > 1 ||
          zone.y + zone.height > 1 ||
          zone.allowedCategories.isEmpty ||
          zone.maxItems < 1) {
        throw const FormatException('Invalid search zone.');
      }
    }
    final itemIds = <String>{};
    for (final item in items) {
      if (!itemIds.add(item.itemId) ||
          item.itemId.trim().isEmpty ||
          item.category.trim().isEmpty ||
          item.weight <= 0 ||
          item.volume <= 0 ||
          item.width <= 0 ||
          item.height <= 0 ||
          item.rarity < 1 ||
          item.allowedZoneIds.isEmpty ||
          item.allowedZoneIds.any((id) => !zoneIds.contains(id))) {
        throw const FormatException('Invalid search item specification.');
      }
    }
  }
}

/// Generates a reproducible search layout without changing the background.
class StreetScrapSearchVariantGenerator {
  const StreetScrapSearchVariantGenerator({this.generatorVersion = 1});

  final int generatorVersion;

  StreetScrapSearchVariant generate(
    StreetScrapSearchSceneDefinition definition, {
    required int seed,
  }) {
    definition.validate();
    final random = _SearchRandom(seed);
    final targetCount =
        definition.minimumItems +
        random.nextInt(definition.maximumItems - definition.minimumItems + 1);
    final zoneCounts = <String, int>{};
    final placements = <StreetScrapSearchPlacement>[];
    final shuffledItems = [...definition.items]..shuffle(random);

    for (var index = 0; index < targetCount; index += 1) {
      final candidates = shuffledItems
          .where(
            (item) => item.allowedZoneIds.any(
              (zoneId) =>
                  (zoneCounts[zoneId] ?? 0) < definition.zone(zoneId).maxItems,
            ),
          )
          .toList();
      if (candidates.isEmpty) break;
      final item = _weightedPick(candidates, random);
      final zones = item.allowedZoneIds
          .map(definition.zone)
          .where((zone) => (zoneCounts[zone.id] ?? 0) < zone.maxItems)
          .toList();
      zones.shuffle(random);

      StreetScrapSearchPlacement? placement;
      for (final zone in zones) {
        placement = _placeItem(item, zone, placements, random, index);
        if (placement != null) break;
      }
      if (placement == null) continue;
      placements.add(placement);
      zoneCounts[placement.zoneId] = (zoneCounts[placement.zoneId] ?? 0) + 1;
    }

    if (placements.isEmpty || placements.every((item) => item.isBuried)) {
      throw StateError('Search generator produced no visible starting item.');
    }
    return StreetScrapSearchVariant(
      sceneId: definition.sceneId,
      seed: seed,
      generatorVersion: generatorVersion,
      placements: placements,
    );
  }

  StreetScrapSearchPlacement? _placeItem(
    StreetScrapSearchItemSpec item,
    StreetScrapSearchZone zone,
    List<StreetScrapSearchPlacement> existing,
    _SearchRandom random,
    int index,
  ) {
    final concealment = _pickConcealment(item, zone, random);
    final margin = 0.01;
    final maxX = zone.x + zone.width - item.width - margin;
    final maxY = zone.y + zone.height - item.height - margin;
    if (maxX < zone.x + margin || maxY < zone.y + margin) return null;
    final anchors = _anchorsFor(zone.id);
    final shuffledAnchors = [...anchors]..shuffle(random);
    for (var attempt = 0; attempt < shuffledAnchors.length; attempt += 1) {
      final anchor = shuffledAnchors[attempt];
      final x = (anchor.x - item.width / 2).clamp(zone.x + margin, maxX);
      final y = (anchor.y - item.height / 2).clamp(zone.y + margin, maxY);
      final overlaps = existing.any(
        (other) => _rectanglesOverlap(
          x,
          y,
          item.width,
          item.height,
          other.x,
          other.y,
          other.width,
          other.height,
        ),
      );
      if (overlaps) continue;
      return StreetScrapSearchPlacement(
        id: 'search-object-${index + 1}',
        itemId: item.itemId,
        zoneId: zone.id,
        x: x,
        y: y,
        width: item.width,
        height: item.height,
        concealment: concealment,
        rotation: anchor.rotation + (random.nextDouble() - 0.5) * 0.04,
        requiresTool:
            concealment == StreetScrapSearchConcealment.visible ||
                concealment == StreetScrapSearchConcealment.partiallyHidden
            ? null
            : 'shovel',
      );
    }
    return null;
  }

  List<_SearchAnchor> _anchorsFor(String zoneId) => switch (zoneId) {
    'dock-area' => const [
      _SearchAnchor(0.12, 0.52, -0.08),
      _SearchAnchor(0.22, 0.59, 0.05),
      _SearchAnchor(0.30, 0.66, -0.04),
    ],
    'left-soil' => const [
      _SearchAnchor(0.20, 0.70, -0.06),
      _SearchAnchor(0.31, 0.75, 0.08),
      _SearchAnchor(0.42, 0.70, -0.03),
    ],
    'center-path' => const [
      _SearchAnchor(0.43, 0.64, -0.04),
      _SearchAnchor(0.53, 0.70, 0.06),
      _SearchAnchor(0.61, 0.65, -0.08),
    ],
    'lower-soil' => const [
      _SearchAnchor(0.34, 0.82, -0.05),
      _SearchAnchor(0.48, 0.80, 0.08),
      _SearchAnchor(0.61, 0.84, -0.04),
    ],
    'shelf-lower' => const [
      _SearchAnchor(0.39, 0.32, -0.02),
      _SearchAnchor(0.49, 0.32, 0.03),
      _SearchAnchor(0.55, 0.39, -0.04),
    ],
    'tarp-area' => const [
      _SearchAnchor(0.65, 0.42, -0.05),
      _SearchAnchor(0.73, 0.48, 0.07),
      _SearchAnchor(0.76, 0.55, -0.03),
    ],
    'right-crate' => const [
      _SearchAnchor(0.82, 0.49, -0.04),
      _SearchAnchor(0.90, 0.52, 0.05),
      _SearchAnchor(0.86, 0.60, -0.06),
    ],
    'right-rocks' => const [
      _SearchAnchor(0.77, 0.81, -0.08),
      _SearchAnchor(0.87, 0.84, 0.06),
      _SearchAnchor(0.94, 0.78, -0.03),
    ],
    _ => const [_SearchAnchor(0.5, 0.65, 0)],
  };

  StreetScrapSearchConcealment _pickConcealment(
    StreetScrapSearchItemSpec item,
    StreetScrapSearchZone zone,
    _SearchRandom random,
  ) {
    if (!item.canBeBuried || !zone.supportsBuried) {
      return random.nextDouble() < 0.35
          ? StreetScrapSearchConcealment.partiallyHidden
          : StreetScrapSearchConcealment.visible;
    }
    final rareBurialBias = item.rarity >= 4
        ? 0.25
        : item.rarity >= 2
        ? 0.12
        : 0;
    final burialRoll = random.nextDouble();
    if (burialRoll < 0.22 + rareBurialBias) {
      return burialRoll < 0.08 + rareBurialBias
          ? StreetScrapSearchConcealment.fullyBuried
          : StreetScrapSearchConcealment.partiallyBuried;
    }
    return burialRoll < 0.55
        ? StreetScrapSearchConcealment.partiallyHidden
        : StreetScrapSearchConcealment.visible;
  }

  StreetScrapSearchItemSpec _weightedPick(
    List<StreetScrapSearchItemSpec> items,
    _SearchRandom random,
  ) {
    final total = items.fold<int>(0, (sum, item) => sum + item.rarity);
    var roll = random.nextInt(total);
    for (final item in items) {
      roll -= item.rarity;
      if (roll < 0) return item;
    }
    return items.last;
  }
}

class _SearchAnchor {
  const _SearchAnchor(this.x, this.y, this.rotation);

  final double x;
  final double y;
  final double rotation;
}

bool _rectanglesOverlap(
  double ax,
  double ay,
  double aw,
  double ah,
  double bx,
  double by,
  double bw,
  double bh,
) => ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;

double _number(Object? value, String label) {
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Invalid $label.');
}

class _SearchRandom implements Random {
  _SearchRandom(int seed) : _state = seed & 0x7fffffff;

  int _state;

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);

  @override
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max');
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state % max;
  }
}

/// The first authored scene definition. It deliberately uses existing item
/// IDs so the generator can be connected to the current material catalog later.
final streetScrapCoastalWarehouseSearchScene = StreetScrapSearchSceneDefinition(
  sceneId: 'coastal-warehouse',
  backgroundResourceId: 'game.street-scrap.art.search-coastal-warehouse',
  zones: const [
    StreetScrapSearchZone(
      id: 'dock-area',
      x: 0.03,
      y: 0.42,
      width: 0.25,
      height: 0.25,
      allowedCategories: {'wood', 'rope', 'metal'},
      supportsBuried: true,
    ),
    StreetScrapSearchZone(
      id: 'left-soil',
      x: 0.16,
      y: 0.60,
      width: 0.25,
      height: 0.18,
      allowedCategories: {'wood', 'metal', 'cloth'},
      supportsBuried: true,
    ),
    StreetScrapSearchZone(
      id: 'center-path',
      x: 0.38,
      y: 0.55,
      width: 0.27,
      height: 0.18,
      allowedCategories: {'wood', 'rope', 'cloth'},
      supportsBuried: true,
    ),
    StreetScrapSearchZone(
      id: 'lower-soil',
      x: 0.35,
      y: 0.72,
      width: 0.26,
      height: 0.17,
      allowedCategories: {'metal', 'bottle', 'wood'},
      supportsBuried: true,
    ),
    StreetScrapSearchZone(
      id: 'shelf-lower',
      x: 0.36,
      y: 0.35,
      width: 0.22,
      height: 0.12,
      allowedCategories: {'cloth', 'bottle', 'metal'},
      supportsBuried: false,
    ),
    StreetScrapSearchZone(
      id: 'tarp-area',
      x: 0.60,
      y: 0.35,
      width: 0.18,
      height: 0.24,
      allowedCategories: {'metal', 'wood', 'bottle'},
      supportsBuried: true,
    ),
    StreetScrapSearchZone(
      id: 'right-crate',
      x: 0.78,
      y: 0.39,
      width: 0.18,
      height: 0.22,
      allowedCategories: {'fish', 'plant', 'cloth', 'food'},
      supportsBuried: false,
    ),
    StreetScrapSearchZone(
      id: 'right-rocks',
      x: 0.73,
      y: 0.70,
      width: 0.25,
      height: 0.18,
      allowedCategories: {'bottle', 'rope', 'plant', 'food'},
      supportsBuried: true,
    ),
  ],
  items: const [
    StreetScrapSearchItemSpec(
      itemId: 'wood.board',
      category: 'wood',
      weight: 3.2,
      volume: 4,
      width: 0.18,
      height: 0.055,
      rarity: 3,
      allowedZoneIds: {'dock-area', 'left-soil', 'lower-soil'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'wood.driftwood',
      category: 'wood',
      weight: 1.5,
      volume: 2,
      width: 0.13,
      height: 0.06,
      rarity: 8,
      allowedZoneIds: {'dock-area', 'center-path', 'left-soil'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'rope.coarse',
      category: 'rope',
      weight: 1.1,
      volume: 2,
      width: 0.095,
      height: 0.065,
      rarity: 7,
      allowedZoneIds: {'dock-area', 'center-path', 'right-rocks'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'cloth.rag_piece',
      category: 'cloth',
      weight: 0.3,
      volume: 1,
      width: 0.075,
      height: 0.06,
      rarity: 8,
      allowedZoneIds: {'left-soil', 'center-path', 'shelf-lower'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'metal.sheet',
      category: 'metal',
      weight: 4.8,
      volume: 5,
      width: 0.16,
      height: 0.085,
      rarity: 2,
      allowedZoneIds: {'dock-area', 'left-soil', 'tarp-area', 'lower-soil'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'metal.scrap',
      category: 'metal',
      weight: 1.2,
      volume: 1,
      width: 0.075,
      height: 0.06,
      rarity: 6,
      allowedZoneIds: {'tarp-area', 'shelf-lower', 'lower-soil'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'container.used_intact',
      category: 'bottle',
      weight: 0.6,
      volume: 2,
      width: 0.05,
      height: 0.105,
      rarity: 5,
      allowedZoneIds: {'shelf-lower', 'lower-soil', 'right-rocks'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'fish.raw',
      category: 'fish',
      weight: 1.4,
      volume: 2,
      width: 0.12,
      height: 0.05,
      rarity: 5,
      allowedZoneIds: {'right-crate'},
    ),
    StreetScrapSearchItemSpec(
      itemId: 'food.greens',
      category: 'plant',
      weight: 0.8,
      volume: 1,
      width: 0.09,
      height: 0.065,
      rarity: 5,
      allowedZoneIds: {'right-crate', 'right-rocks'},
      canBeBuried: true,
    ),
    StreetScrapSearchItemSpec(
      itemId: 'food.scrap',
      category: 'food',
      weight: 0.5,
      volume: 1,
      width: 0.075,
      height: 0.055,
      rarity: 4,
      allowedZoneIds: {'right-crate', 'right-rocks', 'tarp-area'},
      canBeBuried: true,
    ),
  ],
);

/// Returns an immutable copy for callers that expose the definition publicly.
Map<String, StreetScrapSearchZone> streetScrapSearchZonesById(
  StreetScrapSearchSceneDefinition definition,
) => UnmodifiableMapView({for (final zone in definition.zones) zone.id: zone});
