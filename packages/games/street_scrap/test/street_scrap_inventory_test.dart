import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';

StreetScrapObject item(
  String id, {
  String itemId = 'wood.chip',
  int quality = 73,
  String source = 'street-find',
  int? acquiredRevision,
  StreetScrapFootprint footprint = const StreetScrapFootprint(1, 1),
}) => StreetScrapObject(
  instanceId: id,
  itemId: itemId,
  source: source,
  quality: quality,
  traits: const {'durability': 2},
  acquiredRevision: acquiredRevision,
  toolDurability: null,
  footprint: footprint,
);

StreetScrapInventoryCatalog catalog() => StreetScrapInventoryCatalog(
  footprints: const {
    'wood.chip': StreetScrapFootprint(1, 1),
    'bundle.wood_chip': StreetScrapFootprint(1, 1),
    'tool.needle': StreetScrapFootprint(1, 1),
    'tool.sewing_set': StreetScrapFootprint(2, 1),
    'target.large': StreetScrapFootprint(3, 2),
  },
  packingRules: const {
    'wood.chip': StreetScrapPackingRule(
      id: 'wood.chip',
      inputItemId: 'wood.chip',
      outputItemId: 'bundle.wood_chip',
      count: 2,
      manualUnpack: true,
    ),
  },
);

void main() {
  test('legacy polarity-tagged traits normalize to canonical object flags', () {
    final migrated = StreetScrapObject(
      instanceId: 'legacy-trait-item',
      itemId: 'cloth.rag_piece',
      source: 'surprise:commonScraps',
      quality: 82,
      traits: const {'positive': 'intact_fibre', 'negative': 'frayed'},
      toolDurability: null,
      footprint: const StreetScrapFootprint(1, 1),
    );

    expect(migrated.traits, {'intact_fibre': true, 'frayed': true});
    final saveCatalog = StreetScrapInventoryCatalog(
      footprints: const {'cloth.rag_piece': StreetScrapFootprint(1, 1)},
      packingRules: const {},
    );
    const saveGrids = {
      'board': StreetScrapGridSpec(id: 'board', width: 4, height: 4),
    };
    final save = StreetScrapInventory(
      catalog: saveCatalog,
      grids: saveGrids,
      objects: {'legacy-trait-item': migrated},
      placements: const {},
      storage: const {},
    );
    final legacyJson = save.toJson();
    (legacyJson['objects'] as List).single['traits'] = const {
      'positive': 'intact_fibre',
      'negative': 'frayed',
    };
    final reopened = StreetScrapInventory.fromJson(
      catalog: saveCatalog,
      grids: saveGrids,
      json: legacyJson,
    );
    expect(reopened.objects['legacy-trait-item']!.traits, {
      'intact_fibre': true,
      'frayed': true,
    });
  });

  const grid = StreetScrapGridSpec(id: 'board', width: 4, height: 4);

  test('acquisition revision survives inventory serialization and reload', () {
    final items = catalog();
    final original = items
        .emptyInventory(grids: const {'board': grid})
        .addAndPlaceFirstFit(
          item('found-later', acquiredRevision: 12),
          'board',
        );
    final saved = original.toJson();
    final restored = items.inventoryFromJson(
      grids: const {'board': grid},
      json: saved,
    );
    expect(restored.objects['found-later']!.acquiredRevision, 12);
    expect((saved['objects']! as List).single['acquiredRevision'], 12);
  });

  test('first-fit placement synchronizes object and placement rotation', () {
    const rotatedOnlyGrid = StreetScrapGridSpec(
      id: 'rotated-only',
      width: 2,
      height: 3,
    );
    final items = catalog();
    final placed = items
        .emptyInventory(grids: const {'rotated-only': rotatedOnlyGrid})
        .addAndPlaceFirstFit(
          item(
            'rotated-output',
            itemId: 'target.large',
            footprint: const StreetScrapFootprint(3, 2),
          ),
          'rotated-only',
        );

    expect(placed.placements['rotated-output']!.rotation, isTrue);
    expect(placed.objects['rotated-output']!.rotation, isTrue);
    expect(
      items
          .inventoryFromJson(
            grids: const {'rotated-only': rotatedOnlyGrid},
            json: placed.toJson(),
          )
          .placements['rotated-output']!
          .rotation,
      isTrue,
    );
  });

  test('legacy placed-object rotation mismatch normalizes from placement', () {
    const rotatedOnlyGrid = StreetScrapGridSpec(
      id: 'rotated-only',
      width: 2,
      height: 3,
    );
    final items = catalog();
    final saved = items
        .emptyInventory(grids: const {'rotated-only': rotatedOnlyGrid})
        .addAndPlaceFirstFit(
          item(
            'legacy-rotated-output',
            itemId: 'target.large',
            footprint: const StreetScrapFootprint(3, 2),
          ),
          'rotated-only',
        )
        .toJson();
    (saved['objects']! as List).single['rotation'] = false;

    final restored = items.inventoryFromJson(
      grids: const {'rotated-only': rotatedOnlyGrid},
      json: saved,
    );
    expect(restored.objects['legacy-rotated-output']!.rotation, isTrue);
    expect(restored.placements['legacy-rotated-output']!.rotation, isTrue);
  });

  test(
    'formal content payload supplies the exact footprint and packing whitelist',
    () {
      final ids = <String>[
        'wood.chip',
        'bundle.wood_chip',
        'cloth.edge_scrap',
        'bundle.cloth_scrap',
        'cloth.thread_end',
        'bundle.thread_end',
        'metal.scrap',
        'bundle.metal_scrap',
        'plastic.scrap',
        'bundle.plastic_scrap',
        'paper.scrap',
        'bundle.paper_scrap',
        'metal.shard',
        'bundle.metal_shard',
        'plastic.sheet',
        'bundle.plastic_sheet',
        ...List.generate(95, (index) => 'test.item.$index'),
      ];
      ids[109] = 'fish.bone';
      ids[110] = 'wood.driftwood';
      final payload = {
        'schemaVersion': 1,
        'gameId': 'game.street-scrap',
        'packId': 'game.street-scrap.content.chapters-0-4',
        'rulesetVersion': 1,
        'saveSchemaVersion': 1,
        'optionalResource': true,
        'itemDefinitions': [
          for (final id in ids)
            {
              'id': id,
              'name': id,
              'phase': 0,
              'location': 'grid',
              'footprint': [1, 1],
            },
        ],
        'recipes': [
          for (var index = 0; index < 78; index++)
            {
              'id': 'recipe.$index',
              'station': 'recycler',
              'operation': {'id': 'sort', 'instructions': '手動分類'},
              'inputGroups': [
                [
                  {'item': 'wood.chip', 'quantity': 1},
                ],
              ],
              'outputs': [
                {'item': 'wood.chip', 'quantity': 1},
              ],
              'failure': {'outcome': 'wood.chip 1', 'mode': 'explicitOutcome'},
            },
        ],
        'packing': [
          for (var index = 0; index < 8; index++)
            {
              'input': ids[index * 2],
              'output': ids[index * 2 + 1],
              'count': 4,
              'manualUnpack': true,
            },
        ],
        'toolRepairs': const [],
        'renewableSupplies': const <Object>[],
        'limits': {'staminaMax': 60},
        'scavenging': {
          'version': 4,
          'nodeCount': 3,
          'investigationsPerNode': 1,
          'movementCost': 1,
          'investigationCost': 2,
          'fixedWrongQuantity': 1,
          'scrapQualities': [30, 55],
          'intactQualities': [55, 80, 95],
          'surpriseWeights': {
            'commonScraps': 50,
            'intactBase': 25,
            'containers': 15,
            'optionalSpecial': 10,
          },
          'surprisePools': {
            'commonScraps': ['wood.chip'],
            'intactBase': ['wood.chip'],
            'containers': ['wood.chip'],
            'optionalSpecial': [],
          },
          'phaseSurprisePools': {
            for (var phase = 0; phase < 6; phase++)
              '$phase': {
                'commonScraps': ['wood.chip'],
                'intactBase': ['wood.chip'],
                'containers': ['wood.chip'],
                'optionalSpecial': [],
              },
          },
          'fixedLocations': [
            for (var index = 0; index < 3; index++)
              {
                'id': 'node-$index',
                'nodeIndex': index,
                'phase': 0,
                'options': [
                  {'item': 'wood.chip', 'label': '碎木片', 'quantity': 1},
                ],
              },
          ],
        },
        'fishing': {
          'version': 1,
          'castCost': 3,
          'signalsPerCast': 3,
          'successSignals': 2,
          'perfectSignals': 3,
          'signalHoldMilliseconds': 2000,
          'basePromptWidthPercent': 30,
          'preciseQualityBonus': 8,
          'guaranteeAfterFailures': 2,
          'freeNaturalBait': true,
          'loanerRodAvailable': true,
          'spots': [
            {'id': 'dock_entrance', 'phase': 2, 'name': '舊碼頭入口'},
            {
              'id': 'raft_point',
              'phase': 3,
              'name': 'Raft Point',
              'failureRewards': ['fish.bone', 'wood.driftwood'],
            },
          ],
          'failureRewards': ['wood.chip', 'bundle.wood_chip'],
        },
      };
      final parsed = StreetScrapInventoryCatalog.fromContentPayload(
        jsonEncode(payload),
      );
      expect(parsed.footprints, hasLength(111));
      expect(parsed.packingRules, hasLength(8));
      expect(
        parsed.packingRules['wood.chip']!.outputItemId,
        'bundle.wood_chip',
      );
      expect(
        () => parsed.createObject(
          instanceId: 'non-grid',
          itemId: 'missing-item',
          source: 'test',
          quality: 50,
          traits: const {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'tool durability uses quality bands, trait wear, and a one-use floor',
    () {
      final tools = StreetScrapInventoryCatalog(
        footprints: const {
          'tool.rod_basic': StreetScrapFootprint(1, 3),
          'tool.crowbar': StreetScrapFootprint(1, 2),
          'tool.awl': StreetScrapFootprint(1, 2),
        },
        packingRules: const {},
        baseDurabilities: const {
          'tool.rod_basic': 20,
          'tool.crowbar': 30,
          'tool.awl': 1,
        },
      );
      expect(tools.maximumDurability('tool.rod_basic', 39, const {}), 17);
      expect(tools.maximumDurability('tool.rod_basic', 40, const {}), 20);
      expect(tools.maximumDurability('tool.rod_basic', 70, const {}), 22);
      expect(tools.maximumDurability('tool.rod_basic', 90, const {}), 24);
      expect(
        tools.maximumDurability('tool.crowbar', 70, const {'cracked': true}),
        29,
      );
      expect(tools.maximumDurability('tool.awl', 0, const {}), 1);
      expect(
        tools
            .createObject(
              instanceId: 'quality-scaled-tool',
              itemId: 'tool.rod_basic',
              source: 'crafted:test',
              quality: 70,
              traits: const {},
            )
            .toolDurability,
        22,
      );
    },
  );

  test(
    'rejects a rectangular object when free area exists but no fitting shape',
    () {
      final objects = <String, StreetScrapObject>{};
      final placements = <String, StreetScrapPlacement>{};
      // A 3x2 target needs six cells. A checkerboard free-space pattern leaves
      // eight free cells in the 4x4 area, but no 3x2 rectangle can fit.
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          if ((x + y).isOdd) {
            final id = 'block-$x-$y';
            objects[id] = item(id);
            placements[id] = StreetScrapPlacement(
              instanceId: id,
              gridId: 'board',
              x: x,
              y: y,
              rotation: false,
            );
          }
        }
      }
      objects['target'] = item(
        'target',
        itemId: 'target.large',
        footprint: const StreetScrapFootprint(3, 2),
      );
      final inventory = StreetScrapInventory(
        catalog: catalog(),
        grids: const {'board': grid},
        objects: objects,
        placements: placements,
        storage: const {},
      );
      expect(
        () => inventory.placeFirstFit('target', 'board'),
        throwsStateError,
      );
      expect(inventory.placements.containsKey('target'), isFalse);
    },
  );

  test(
    'unpack is atomic and preserves each child identity, source and quality',
    () {
      final children = [
        item('a', quality: 91),
        item('b', quality: 42, source: 'native-board'),
      ];
      final packed = StreetScrapObject(
        instanceId: 'bundle',
        itemId: 'bundle.wood_chip',
        source: 'packed',
        quality: 42,
        traits: const {},
        toolDurability: null,
        footprint: const StreetScrapFootprint(1, 1),
        containerContents: children,
      );
      final tightGrid = const StreetScrapGridSpec(
        id: 'tight',
        width: 2,
        height: 1,
      );
      final blocked = <String, StreetScrapObject>{
        'bundle': packed,
        'occupied': item('occupied'),
      };
      final blockedPlacements = <String, StreetScrapPlacement>{
        'bundle': const StreetScrapPlacement(
          instanceId: 'bundle',
          gridId: 'tight',
          x: 0,
          y: 0,
          rotation: false,
        ),
        'occupied': const StreetScrapPlacement(
          instanceId: 'occupied',
          gridId: 'tight',
          x: 1,
          y: 0,
          rotation: false,
        ),
      };
      final inventory = StreetScrapInventory(
        catalog: catalog(),
        grids: {'tight': tightGrid},
        objects: blocked,
        placements: blockedPlacements,
        storage: const {},
      );
      expect(
        () => inventory.unpack(containerInstanceId: 'bundle', gridId: 'tight'),
        throwsStateError,
      );
      expect(inventory.objects['bundle'], same(packed));
      expect(inventory.objects.containsKey('a'), isFalse);

      final open = StreetScrapInventory(
        catalog: catalog(),
        grids: const {'board': grid},
        objects: {'bundle': packed},
        placements: const {},
        storage: const {},
      );
      final unpacked = open.unpack(
        containerInstanceId: 'bundle',
        gridId: 'board',
      );
      expect(unpacked.placements.keys.toSet(), {'a', 'b'});
    },
  );

  test(
    'packing and unpacking conserves nested child instances and their provenance',
    () {
      final original = StreetScrapInventory(
        catalog: catalog(),
        grids: const {
          'board': grid,
          'bag': StreetScrapGridSpec(id: 'bag', width: 4, height: 4),
        },
        objects: {
          'a': item('a', quality: 88),
          'b': item('b', quality: 55, source: 'native-board'),
        },
        placements: const {},
        storage: const {},
      );
      final packed = original.pack(
        ruleId: 'wood.chip',
        source: 'packing-recipe',
        inputInstanceIds: const ['a', 'b'],
        containerInstanceId: 'bundle-1',
      );
      final bundle = packed.objects['bundle-1']!;
      expect(bundle.containerContents.map((child) => child.instanceId), [
        'a',
        'b',
      ]);
      final unpacked = packed.unpack(
        containerInstanceId: 'bundle-1',
        gridId: 'bag',
      );
      expect(unpacked.objects['a']!.source, 'street-find');
      expect(unpacked.objects['b']!.source, 'native-board');
      expect(unpacked.objects['a']!.quality, 88);
      expect(unpacked.objects['b']!.quality, 55);
      expect(unpacked.objects.containsKey('bundle-1'), isFalse);

      final reloaded = catalog().inventoryFromJson(
        grids: packed.grids,
        json: packed.toJson(),
      );
      expect(
        reloaded.objects['bundle-1']!.containerContents[1].source,
        'native-board',
      );
      expect(reloaded.objects['bundle-1']!.containerContents[1].quality, 55);
    },
  );

  test(
    'storage withdrawal validates the complete placement and keeps owner unique',
    () {
      final inventory = StreetScrapInventory(
        catalog: catalog(),
        grids: const {'board': grid},
        objects: {'stored': item('stored')},
        placements: const {},
        storage: const {
          'yard-box': ['stored'],
        },
      );
      final withdrawn = inventory.withdraw('stored', 'yard-box', 'board', 0, 0);
      expect(withdrawn.storage['yard-box'], isEmpty);
      expect(withdrawn.placements['stored']!.gridId, 'board');
      expect(
        () => inventory.withdraw('stored', 'yard-box', 'board', 4, 4),
        throwsFormatException,
      );
    },
  );

  test('tutorial delivery consumes only selected top-level backpack items', () {
    final inventory = StreetScrapInventory(
      catalog: catalog(),
      grids: const {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      },
      objects: {'rag-a': item('rag-a'), 'rag-b': item('rag-b')},
      placements: const {
        'rag-a': StreetScrapPlacement(
          instanceId: 'rag-a',
          gridId: 'backpack',
          x: 0,
          y: 0,
          rotation: false,
        ),
        'rag-b': StreetScrapPlacement(
          instanceId: 'rag-b',
          gridId: 'backpack',
          x: 1,
          y: 0,
          rotation: false,
        ),
      },
      storage: const {},
    );
    final delivered = inventory.consumeFromGrid(['rag-a', 'rag-b'], 'backpack');
    expect(delivered.objects, isEmpty);
    expect(delivered.placements, isEmpty);
    expect(
      () => inventory.consumeFromGrid(['rag-a'], 'board'),
      throwsStateError,
    );
    expect(inventory.objects, hasLength(2));
  });

  test(
    'a packed toolset child cannot also be registered as a top-level object',
    () {
      final child = item('needle-instance', itemId: 'tool.needle');
      final toolset = StreetScrapObject(
        instanceId: 'toolset-instance',
        itemId: 'tool.sewing_set',
        source: 'crafted',
        quality: 70,
        traits: const {},
        toolDurability: 4,
        footprint: const StreetScrapFootprint(2, 1),
        containerContents: [child],
      );
      expect(
        () => StreetScrapInventory(
          catalog: catalog(),
          grids: const {'board': grid},
          objects: {'toolset-instance': toolset, 'needle-instance': child},
          placements: const {},
          storage: const {},
        ),
        throwsFormatException,
      );
    },
  );
}
