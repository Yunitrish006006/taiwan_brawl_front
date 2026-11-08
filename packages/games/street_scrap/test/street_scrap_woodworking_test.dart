import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_woodworking.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_woodworking_panel.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_audio.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_maintenance.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_orders.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_item_sprite.dart';

class _Store implements StreetScrapProgressStore {
  Map<String, Object?>? value;
  bool failNextCompareAndSwap = false;

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => value;

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    if (failNextCompareAndSwap) {
      failNextCompareAndSwap = false;
      return false;
    }
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
    'wood.chip': StreetScrapFootprint(1, 1),
    'adhesive.recycled': StreetScrapFootprint(1, 1),
    'wood.rod': StreetScrapFootprint(1, 2),
    'metal.nail_bundle': StreetScrapFootprint(1, 1),
    'wood.board': StreetScrapFootprint(1, 2),
    'wood.frame': StreetScrapFootprint(2, 2),
    'tool.crowbar': StreetScrapFootprint(1, 2),
    'metal.shard': StreetScrapFootprint(1, 1),
    'metal.sheet': StreetScrapFootprint(1, 2),
    'plastic.scrap': StreetScrapFootprint(1, 1),
    'paper.scrap': StreetScrapFootprint(1, 1),
    'cloth.edge_scrap': StreetScrapFootprint(1, 1),
    'cloth.binding': StreetScrapFootprint(1, 1),
    'storage.wooden_crate': StreetScrapFootprint(2, 2),
    'cloth.patchwork': StreetScrapFootprint(1, 2),
    'cloth.thread_spool': StreetScrapFootprint(1, 1),
    'tool.needle': StreetScrapFootprint(1, 1),
    'container.clean': StreetScrapFootprint(1, 2),
    'container.meal_box': StreetScrapFootprint(1, 2),
    'container.meal_box_insulated': StreetScrapFootprint(1, 2),
    'meal.soup_basic': StreetScrapFootprint(1, 1),
    'meal.soup_fish': StreetScrapFootprint(1, 1),
    'meal.soup_vegetable': StreetScrapFootprint(1, 1),
    'meal.failed': StreetScrapFootprint(1, 1),
    'food.cleaned': StreetScrapFootprint(1, 1),
    'fish.meat': StreetScrapFootprint(1, 1),
    'fuel.dry': StreetScrapFootprint(1, 1),
    'material.charcoal': StreetScrapFootprint(1, 1),
    'material.filter_cloth': StreetScrapFootprint(1, 1),
  },
  packingRules: const {},
  baseDurabilities: const {'tool.crowbar': 30},
);

final _mealOrderCatalog = StreetScrapOrderCatalog.fromOrders([
  StreetScrapOrder.fromJson(
    {
      'id': 'ss.order.meal',
      'phase': 4,
      'acceptedItems': [
        'meal.soup_basic',
        'meal.soup_fish',
        'meal.soup_vegetable',
      ],
      'rejectedItems': ['meal.failed'],
      'reward': {'currency': 'exchangeTickets', 'quantity': 4},
      'countsTowardCycle': false,
      'returnContainer': true,
      'returnedContainerCleanliness': 'soiled',
      'requiresTutorial': 'q4.02',
      'oncePerTutorial': 'q4.03',
    },
    itemIds: const {
      'meal.soup_basic',
      'meal.soup_fish',
      'meal.soup_vegetable',
      'meal.failed',
    },
  ),
]);

Future<StreetScrapSession> _session(
  String key, {
  bool chapterFive = false,
  _Store? store,
}) async {
  final session = StreetScrapSession(
    profileScope: key,
    store: store ?? _Store(),
    contentVersions: {
      'game.street-scrap.content.chapters-0-4': '0.1.13',
      if (chapterFive) 'game.street-scrap.content.chapter-5': '0.1.14',
    },
    rulesetVersion: 1,
  );
  await session.load();
  await session.apply(
    commandId: 'setup-$key',
    expectedRevision: 0,
    reduce: (_) => StreetScrapReduction(
      state: {
        'chapter': 3,
        'tutorialTasks': {'q2.03': true},
        'inventory': _catalog.emptyInventory(grids: _grids).toJson(),
      },
    ),
  );
  return session;
}

Future<void> _verifyMaintenanceOutcome({
  required String key,
  required String recipeId,
  required String targetItemId,
  required String traitId,
  required String auxiliaryItemId,
  required bool succeeded,
}) async {
  final session = await _session(key);
  final targetId = '$key-target';
  final auxiliaryId = '$key-auxiliary';
  final profile = StreetScrapMaintenance.profileForRecipeId(recipeId)!;
  final inventory = _catalog
      .emptyInventory(grids: _grids)
      .addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: targetId,
          itemId: targetItemId,
          source: 'native-pickup',
          quality: 61,
          traits: {traitId: true, 'unrelated_marker': true},
        ),
        'backpack',
      )
      .addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: auxiliaryId,
          itemId: auxiliaryItemId,
          source: 'test',
          quality: 48,
          traits: const {},
        ),
        'backpack',
      );
  await session.apply(
    commandId: '$key-inventory',
    expectedRevision: 1,
    reduce: (state) => StreetScrapReduction(
      state: {...state, 'inventory': inventory.toJson()},
    ),
  );
  final operationId = '$key-operation';
  await StreetScrapMaintenance.beginTraitMaintenance(
    session: session,
    catalog: _catalog,
    grids: _grids,
    gridId: 'backpack',
    profile: profile,
    targetInstanceId: targetId,
    auxiliaryInstanceId: auxiliaryId,
    operationId: operationId,
    commandId: '$key-begin',
    expectedRevision: 2,
  );
  StreetScrapCommandResult? result;
  final answers = succeeded ? const [1, 1, 0] : const [1, 0, 0];
  for (final answer in answers) {
    result = await StreetScrapMaintenance.answerMaintenanceCheckpoint(
      session: session,
      catalog: _catalog,
      grids: _grids,
      operationId: operationId,
      optionIndex: answer,
      expectedRevision: session.snapshot.revision,
    );
  }
  expect((result!.result as Map)['succeeded'], succeeded, reason: key);
  final settled = _catalog.inventoryFromJson(
    grids: _grids,
    json: Map<String, Object?>.from(
      session.snapshot.state['inventory']! as Map,
    ),
  );
  final target = settled.objects[targetId]!;
  expect(target.itemId, targetItemId, reason: key);
  expect(target.source, 'native-pickup', reason: key);
  expect(target.quality, 61, reason: key);
  expect(target.traits.containsKey(traitId), !succeeded, reason: key);
  expect(target.traits['unrelated_marker'], isTrue, reason: key);
  expect(target.provenance.last['recipeId'], recipeId, reason: key);
  expect(settled.objects.containsKey(auxiliaryId), isFalse, reason: key);
  expect(session.snapshot.state['craftOperation'], isNull, reason: key);
  await session.close();
}

void main() {
  testWidgets('locked woodworking tab explains the unlock stage visually', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await _session('locked-woodworking-panel');
    await session.apply(
      commandId: 'rewind-locked-woodworking-panel',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 0,
          'tutorialTasks': {'q2.03': false},
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetScrapWoodworkingPanel(
            session: session,
            catalog: _catalog,
            onOpenRecipes: () {},
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-locked-woodworking')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-locked-art-woodworking')),
      findsOneWidget,
    );
    expect(find.text('木料工作台'), findsOneWidget);
    expect(find.text('尚未解鎖・需要階段 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  test(
    'water transfer preserves metadata and wash restores vessel cleanliness',
    () async {
      final session = await _session('water-transfer-wash');
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'water-a',
              itemId: 'container.clean',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {
                'contentItemId': 'water.filtered',
                'contentQuality': 70,
                'contentSource': 'test-water-point',
                'contentTraits': <String, Object?>{'muddy': true},
                'requiresBoiling': false,
                'cleanliness': 'utility',
              },
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'water-b',
              itemId: 'container.clean',
              source: 'test',
              quality: 60,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'water-state-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': inventory.toJson()},
        ),
      );
      await transferStreetScrapWater(
        session: session,
        commandId: 'water-pour',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        sourceVesselId: 'water-a',
        targetVesselId: 'water-b',
      );
      var saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects.keys.toSet(), {'water-a', 'water-b'});
      expect(saved.objects['water-b']!.containerState['contentQuality'], 70);
      expect(
        saved.objects['water-b']!.containerState['contentSource'],
        'test-water-point',
      );
      expect(
        saved.objects['water-b']!.containerState['requiresBoiling'],
        isFalse,
      );
      expect(saved.objects['water-b']!.containerState['contentTraits'], {
        'muddy': true,
      });
      await washStreetScrapVessel(
        session: session,
        commandId: 'water-wash-b',
        expectedRevision: 3,
        catalog: _catalog,
        grids: _grids,
        targetVesselId: 'water-a',
        waterVesselId: 'water-b',
      );
      saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects['water-a']!.containerState['cleanliness'], 'clean');
      expect(saved.objects['water-b']!.containerState['contentItemId'], isNull);
      expect(saved.objects.keys.toSet(), {'water-a', 'water-b'});
      await session.close();
    },
  );

  test(
    'fixed-source fill costs stamina and preserves the bottle identity',
    () async {
      final session = await _session('water-fill');
      final bottle = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'fill-bottle',
              itemId: 'container.clean',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'fill-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'stamina': 10,
            'inventory': bottle.toJson(),
          },
        ),
      );
      await fillStreetScrapVessel(
        session: session,
        commandId: 'fill-filtered',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        vesselId: 'fill-bottle',
        sourceId: 'public-refill',
        maxStamina: 60,
      );
      final saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(session.snapshot.state['stamina'], 8);
      expect(saved.objects.keys, {'fill-bottle'});
      expect(
        saved.objects['fill-bottle']!.containerState['contentItemId'],
        'water.filtered',
      );
      expect(saved.objects['fill-bottle']!.source, 'test');
      await session.close();
    },
  );
  test(
    'chapter-five mineral spring costs three stamina and fills mineral-rich water',
    () async {
      final session = await _session('mineral-spring', chapterFive: true);
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'mineral-spring-bottle',
              itemId: 'container.clean',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'mineral-spring-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 5,
            'stamina': 10,
            'tutorialTasks': {'q5.01': true},
            'inventory': inventory.toJson(),
          },
        ),
      );
      final result = await fillStreetScrapVessel(
        session: session,
        commandId: 'fill-mineral-spring',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        vesselId: 'mineral-spring-bottle',
        sourceId: 'new-neighborhood-mineral',
        maxStamina: 60,
      );
      final saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final bottle = saved.objects['mineral-spring-bottle']!;
      final outcome = Map<String, Object?>.from(result.result! as Map);
      expect(outcome['staminaCost'], 3);
      expect(session.snapshot.state['stamina'], 7);
      expect(bottle.containerState['contentItemId'], 'water.mineral');
      expect(bottle.containerState['contentTraits'], {'mineral_rich': true});
      expect(bottle.containerState['requiresBoiling'], false);
      expect(saved.objects.keys, {'mineral-spring-bottle'});
      await session.close();

      final uninstalled = await _session('mineral-spring-uninstalled');
      final emptyBottle = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'uninstalled-mineral-bottle',
              itemId: 'container.clean',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await uninstalled.apply(
        commandId: 'setup-uninstalled-mineral',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 5,
            'stamina': 10,
            'inventory': emptyBottle.toJson(),
          },
        ),
      );
      await expectLater(
        fillStreetScrapVessel(
          session: uninstalled,
          commandId: 'reject-uninstalled-mineral',
          expectedRevision: 2,
          catalog: _catalog,
          grids: _grids,
          vesselId: 'uninstalled-mineral-bottle',
          sourceId: 'new-neighborhood-mineral',
          maxStamina: 60,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'chapter5ExpansionNotInstalled',
          ),
        ),
      );
      expect(uninstalled.snapshot.state['stamina'], 10);
      await uninstalled.close();
    },
  );
  test(
    'q3.01 kit is issued once and all parts enter the backpack atomically',
    () async {
      final session = await _session('wood-press-kit');
      final result = await claimStreetScrapWoodPressKit(
        session: session,
        commandId: 'claim-kit',
        expectedRevision: 1,
        catalog: _catalog,
        grids: _grids,
      );
      expect(result.revision, 2);
      final inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(inventory.objects.values.map((item) => item.itemId).toList(), [
        'wood.chip',
        'wood.chip',
        'wood.chip',
        'adhesive.recycled',
      ]);
      expect(
        inventory.placements.values.every((p) => p.gridId == 'backpack'),
        isTrue,
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.01.kitClaimed'],
        isTrue,
      );
      final duplicate = await claimStreetScrapWoodPressKit(
        session: session,
        commandId: 'claim-kit',
        expectedRevision: 1,
        catalog: _catalog,
        grids: _grids,
      );
      expect(duplicate.wasDuplicate, isTrue);
      expect(session.snapshot.revision, 2);
      await session.close();
    },
  );

  test(
    'q3.01 kit moves together to the workboard when the backpack is full',
    () async {
      final session = await _session('wood-press-kit-full-backpack');
      var inventory = _catalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 16; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'wood-press-full-bag-$index',
            itemId: 'wood.chip',
            source: 'test:existing-item',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.chip']!,
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'seed-full-backpack-for-q301',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': inventory.toJson()},
        ),
      );

      await claimStreetScrapWoodPressKit(
        session: session,
        commandId: 'claim-q301-full-backpack',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );

      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final kit = inventory.objects.values
          .where((item) => item.source == 'tutorial:q3.01-kit')
          .toList(growable: false);
      expect(kit, hasLength(4));
      expect(
        kit
            .map((item) => inventory.placements[item.instanceId]!.gridId)
            .toSet(),
        {'board'},
      );
      expect(inventory.objects, hasLength(20));
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.01.kitClaimed'],
        isTrue,
      );
      await session.close();
    },
  );

  test('q3.01 kit stays unclaimed when both grids are full', () async {
    final session = await _session('wood-press-kit-no-space');
    var inventory = _catalog.emptyInventory(grids: _grids);
    for (final entry in const {'backpack': 16, 'board': 36}.entries) {
      for (var index = 0; index < entry.value; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'wood-press-full-${entry.key}-$index',
            itemId: 'wood.chip',
            source: 'test:existing-item',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.chip']!,
          ),
          entry.key,
        );
      }
    }
    await session.apply(
      commandId: 'seed-no-space-for-q301',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'inventory': inventory.toJson()},
      ),
    );

    await expectLater(
      claimStreetScrapWoodPressKit(
        session: session,
        commandId: 'claim-q301-no-space',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'insufficientInventorySpace',
        ),
      ),
    );
    expect(session.snapshot.revision, 2);
    expect(session.snapshot.state['tutorialTasks'], {'q2.03': true});
    final savedInventory = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(savedInventory.objects, hasLength(52));
    await session.close();
  });

  test('q3.01 kit cannot be claimed before chapter three', () async {
    final session = await _session('wood-press-locked');
    await session.apply(
      commandId: 'rewind-chapter',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(state: {...state, 'chapter': 2}),
    );
    await expectLater(
      claimStreetScrapWoodPressKit(
        session: session,
        commandId: 'claim-locked-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.revision, 2);
    await session.close();
  });

  test(
    'q3.02 kit counts existing rods and tops up to three plus one nail bundle',
    () async {
      final session = await _session('nail-board-kit');
      var inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'pressed-rod',
              itemId: 'wood.rod',
              source: 'crafted:ss.recipe.press_rod',
              quality: 55,
              traits: const {},
              toolDurability: null,
              footprint: _catalog.footprints['wood.rod']!,
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'complete-q301',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {...state['tutorialTasks'] as Map, 'q3.01': true},
            'inventory': inventory.toJson(),
          },
        ),
      );
      await claimStreetScrapNailBoardKit(
        session: session,
        commandId: 'claim-nail-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        inventory.objects.values.where((item) => item.itemId == 'wood.rod'),
        hasLength(3),
      );
      expect(
        inventory.objects.values.where(
          (item) => item.itemId == 'metal.nail_bundle',
        ),
        hasLength(1),
      );
      expect(
        inventory.objects.values.where(
          (item) => item.source == 'tutorial:q3.02-kit',
        ),
        hasLength(3),
      );
      await session.close();
    },
  );

  test(
    'q3.02 kit consolidates rods and nail bundle onto one playable grid',
    () async {
      final session = await _session('nail-board-kit-split-grid');
      var inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'existing-pressed-rod',
              itemId: 'wood.rod',
              source: 'crafted:ss.recipe.press_rod',
              quality: 37,
              traits: const {},
              toolDurability: null,
              footprint: _catalog.footprints['wood.rod']!,
            ),
            'backpack',
          );
      for (var index = 0; index < 12; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'backpack-fill-$index',
            itemId: 'wood.chip',
            source: 'test:existing-item',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.chip']!,
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'complete-q301-split-grid',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {...state['tutorialTasks'] as Map, 'q3.01': true},
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapNailBoardKit(
        session: session,
        commandId: 'claim-nail-kit-split-grid',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );

      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final recipeInputs = inventory.placements.keys
          .map((id) => inventory.objects[id]!)
          .where(
            (item) =>
                const {'wood.rod', 'metal.nail_bundle'}.contains(item.itemId),
          )
          .toList(growable: false);
      expect(recipeInputs, hasLength(4));
      expect(
        recipeInputs
            .map((item) => inventory.placements[item.instanceId]!.gridId)
            .toSet(),
        hasLength(1),
        reason: 'The complete q3.02 recipe must be selectable from one grid.',
      );
      expect(
        inventory.objects['existing-pressed-rod']!.quality,
        37,
        reason:
            'Consolidating the prior crafted rod must preserve its quality.',
      );
      expect(
        inventory.placements['existing-pressed-rod']!.gridId,
        'board',
        reason:
            'The roomy board should be preferred over a nearly full backpack.',
      );
      await session.close();
    },
  );

  test(
    'q3.02 kit falls back to the workboard when the backpack is full',
    () async {
      final session = await _session('nail-board-kit-full-backpack');
      var inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'already-pressed-rod',
              itemId: 'wood.rod',
              source: 'crafted:ss.recipe.press_rod',
              quality: 47,
              traits: const {},
              toolDurability: null,
              footprint: _catalog.footprints['wood.rod']!,
            ),
            'backpack',
          );
      for (var index = 0; index < 12; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'backpack-fill-$index',
            itemId: 'wood.chip',
            source: 'test:existing-item',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.chip']!,
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'complete-q301-with-crowded-backpack',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {...state['tutorialTasks'] as Map, 'q3.01': true},
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapNailBoardKit(
        session: session,
        commandId: 'claim-nail-kit-with-crowded-backpack',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );

      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final issued = inventory.objects.values
          .where((item) => item.source == 'tutorial:q3.02-kit')
          .toList(growable: false);
      expect(issued.where((item) => item.itemId == 'wood.rod'), hasLength(2));
      expect(
        issued.where((item) => item.itemId == 'metal.nail_bundle'),
        hasLength(1),
      );
      expect(
        issued
            .map((item) => inventory.placements[item.instanceId]!.gridId)
            .toSet(),
        contains('board'),
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.02.kitClaimed'],
        isTrue,
      );
      await session.close();
    },
  );

  test('q3.02 excludes rods stored away from the playable grids', () async {
    final session = await _session('nail-kit-excludes-stored-rods');
    var inventory = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'placed-pressed-rod',
            itemId: 'wood.rod',
            source: 'crafted:ss.recipe.press_rod',
            quality: 47,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.rod']!,
          ),
          'backpack',
        );
    for (var index = 0; index < 2; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        StreetScrapObject(
          instanceId: 'stored-rod-$index',
          itemId: 'wood.rod',
          source: 'crafted:ss.recipe.press_rod',
          quality: 50,
          traits: const {},
          toolDurability: null,
          footprint: _catalog.footprints['wood.rod']!,
        ),
        'board',
      );
    }
    final json = inventory.toJson();
    final placements =
        List<Map<String, Object?>>.from(
          (json['placements']! as List).map(
            (placement) => Map<String, Object?>.from(placement as Map),
          ),
        )..removeWhere(
          (placement) =>
              (placement['instanceId']! as String).startsWith('stored-rod-'),
        );
    json['placements'] = placements;
    json['storage'] = {
      'lesson-crate': ['stored-rod-0', 'stored-rod-1'],
    };
    inventory = _catalog.inventoryFromJson(grids: _grids, json: json);
    await session.apply(
      commandId: 'complete-q301-with-stored-rods',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {...state['tutorialTasks'] as Map, 'q3.01': true},
          'inventory': inventory.toJson(),
        },
      ),
    );

    await claimStreetScrapNailBoardKit(
      session: session,
      commandId: 'claim-nail-kit-with-stored-rods',
      expectedRevision: 2,
      catalog: _catalog,
      grids: _grids,
    );

    inventory = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    final placedRods = inventory.placements.keys
        .map((id) => inventory.objects[id]!)
        .where((item) => item.itemId == 'wood.rod');
    expect(placedRods, hasLength(3));
    expect(inventory.storage['lesson-crate'], ['stored-rod-0', 'stored-rod-1']);
    expect(
      inventory.objects.values
          .where((item) => item.source == 'tutorial:q3.02-kit')
          .where((item) => item.itemId == 'wood.rod'),
      hasLength(2),
    );
    await session.close();
  });

  test(
    'q3.02 can safely replenish a previously incomplete lesson kit',
    () async {
      final session = await _session('nail-kit-recovery');
      var inventory = _catalog.emptyInventory(grids: _grids);
      for (final id in ['recovery-rod', 'recovery-nails']) {
        final itemId = id == 'recovery-rod' ? 'wood.rod' : 'metal.nail_bundle';
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: id,
            itemId: itemId,
            source: id == 'recovery-rod'
                ? 'crafted:ss.recipe.press_rod'
                : 'tutorial:q3.02-kit',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints[itemId]!,
          ),
          'board',
        );
      }
      await session.apply(
        commandId: 'prepare-incomplete-q302-kit',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...state['tutorialTasks']! as Map,
              'q3.01': true,
              'q3.02.kitClaimed': true,
            },
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapNailBoardKit(
        session: session,
        commandId: 'recover-incomplete-q302-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );

      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        inventory.placements.keys
            .map((id) => inventory.objects[id]!)
            .where((item) => item.itemId == 'wood.rod'),
        hasLength(3),
      );
      expect(
        inventory.placements.keys
            .map((id) => inventory.objects[id]!)
            .where((item) => item.itemId == 'metal.nail_bundle'),
        hasLength(1),
      );
      expect(
        inventory.objects.values
            .where((item) => item.source == 'tutorial:q3.02-kit')
            .where((item) => item.itemId == 'metal.nail_bundle'),
        hasLength(1),
      );
      await session.close();
    },
  );

  test(
    'chapter-three press, nail, and repair chain completes in one save',
    () async {
      final session = await _session('chapter-three-sequential-flow');
      await claimStreetScrapWoodPressKit(
        session: session,
        commandId: 'flow-claim-press-kit',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );

      final pressRecipe = StreetScrapRecipe(
        id: 'ss.recipe.press_rod',
        phase: 3,
        station: 'workbench',
        operationId: 'press',
        durationSeconds: 10,
        instructions: 'Align wood chips and press with recycled adhesive.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'wood.chip', quantity: 3),
            StreetScrapRecipeInput(itemId: 'adhesive.recycled', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: ['wood.chip'],
          loss: 8,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: 'A usable lower-quality rod is still produced.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Align the grain',
            options: ['Aligned', 'Crossed'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Apply adhesive',
            options: ['At the joint', 'Across the surface'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Clamp the rod',
            options: ['Securely', 'Loosely'],
            correctOption: 0,
          ),
        ],
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: _catalog,
        recipe: pressRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: const [
          'q301-chip-0',
          'q301-chip-1',
          'q301-chip-2',
          'q301-adhesive',
        ],
        toolInstanceIds: const [],
        commandId: 'flow-press-rod',
        expectedRevision: session.snapshot.revision,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (_) => 'flow-pressed-rod',
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.01'],
        isTrue,
      );

      await claimStreetScrapNailBoardKit(
        session: session,
        commandId: 'flow-claim-nail-kit',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );
      final beforeNailing = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final rodIds = beforeNailing.objects.values
          .where((item) => item.itemId == 'wood.rod')
          .map((item) => item.instanceId)
          .toList();
      expect(rodIds, contains('flow-pressed-rod'));
      expect(rodIds, hasLength(3));
      final nailId = beforeNailing.objects.values
          .singleWhere((item) => item.itemId == 'metal.nail_bundle')
          .instanceId;
      final nailRecipe = StreetScrapRecipe(
        id: 'ss.recipe.nail_board',
        phase: 3,
        station: 'workbench',
        operationId: 'strike',
        durationSeconds: 10,
        instructions: 'Align rods and secure them with nails.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 3),
            StreetScrapRecipeInput(itemId: 'metal.nail_bundle', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'wood.board', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: ['wood.rod'],
          loss: 8,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        traitResolution: const {
          'inherit': [],
          'polarity': {
            'joint_reinforced': 'positive',
            'joint_skewed': 'negative',
          },
          'success': {},
          'precise': {'joint_reinforced': true},
          'failure': {'joint_skewed': true},
        },
        failureMode: 'explicitOutcome',
        failureOutcome: 'The board remains usable after a missed strike.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Place the first nail',
            options: ['At the joint', 'Outside the joint'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Hold the wood',
            options: ['Clamp it', 'Hold it loosely'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Inspect the seam',
            options: ['Flush and firm', 'Loose and raised'],
            correctOption: 0,
          ),
        ],
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: _catalog,
        recipe: nailRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: [...rodIds, nailId],
        toolInstanceIds: const [],
        commandId: 'flow-nail-board',
        expectedRevision: session.snapshot.revision,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (_) => 'flow-nailed-board',
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.02'],
        isTrue,
      );

      await claimStreetScrapToolRepairKit(
        session: session,
        commandId: 'flow-claim-repair-kit',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );
      final beforeRepair = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final result = await repairStreetScrapTutorialCrowbar(
        session: session,
        commandId: 'flow-repair-crowbar',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        toolInstanceId: 'q303-crowbar',
        metalShardInstanceId: 'q303-metal-shard',
        bindingInstanceId: 'q303-binding',
        gridId: 'backpack',
      );
      final afterRepair = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect((result.result! as Map)['durability'], 11);
      expect(afterRepair.objects['q303-crowbar']!.instanceId, 'q303-crowbar');
      expect(afterRepair.objects['q303-crowbar']!.toolDurability, 11);
      expect(afterRepair.objects.containsKey('q303-metal-shard'), isFalse);
      expect(afterRepair.objects.containsKey('q303-binding'), isFalse);
      expect(afterRepair.objects.containsKey('flow-nailed-board'), isTrue);
      expect(beforeRepair.objects['q303-crowbar']!.toolDurability, 1);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.03'],
        isTrue,
      );

      final foundChip = _catalog.createObject(
        instanceId: 'flow-found-chip',
        itemId: 'wood.chip',
        source: 'found:chapter-three-street',
        quality: 67,
        traits: const {'dry': true},
      );
      final inventoryBeforeCrate = afterRepair.addAndPlaceFirstFit(
        foundChip,
        'backpack',
      );
      await session.apply(
        commandId: 'flow-find-crate-storage-item',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'inventory': inventoryBeforeCrate.toJson(),
            'bagEquipment': {
              'instanceId': 'flow-original-bag',
              'itemId': 'bag.basic',
              'quality': 55,
            },
            'backpackCapacity': 16,
          },
        ),
      );
      await claimStreetScrapCrateKit(
        session: session,
        commandId: 'flow-claim-crate-kit',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );
      final beforeCrateCraft = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final boardIds = beforeCrateCraft.objects.values
          .where((item) => item.itemId == 'wood.board')
          .map((item) => item.instanceId)
          .toList();
      final nailIds = beforeCrateCraft.objects.values
          .where((item) => item.itemId == 'metal.nail_bundle')
          .map((item) => item.instanceId)
          .toList();
      final adhesiveId = beforeCrateCraft.objects.values
          .singleWhere((item) => item.itemId == 'adhesive.recycled')
          .instanceId;
      expect(boardIds, hasLength(4));
      expect(nailIds, hasLength(2));
      final crateRecipe = StreetScrapRecipe(
        id: 'ss.recipe.wooden_crate',
        phase: 3,
        station: 'workbench',
        operationId: 'assemble',
        durationSeconds: 10,
        instructions: 'Assemble boards into a storage crate.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'wood.board', quantity: 4),
            StreetScrapRecipeInput(itemId: 'metal.nail_bundle', quantity: 2),
            StreetScrapRecipeInput(itemId: 'adhesive.recycled', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'storage.wooden_crate', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: ['wood.board'],
          loss: 8,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: 'The crate remains usable after a missed checkpoint.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Place the base board',
            options: ['On the frame', 'Beside the frame'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Secure the crate wall',
            options: ['Nails and adhesive', 'Loose nails'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Inspect the finished crate',
            options: ['Stable and square', 'Loose and tilted'],
            correctOption: 0,
          ),
        ],
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: _catalog,
        recipe: crateRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: [...boardIds, ...nailIds, adhesiveId],
        toolInstanceIds: const [],
        commandId: 'flow-craft-crate',
        expectedRevision: session.snapshot.revision,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (_) => 'flow-wooden-crate',
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.04.crateCrafted'],
        isTrue,
      );
      await placeStreetScrapTutorialCrate(
        session: session,
        commandId: 'flow-place-crate',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        crateInstanceId: 'flow-wooden-crate',
        gridId: 'backpack',
      );
      await storeStreetScrapInTutorialCrate(
        session: session,
        commandId: 'flow-store-chip',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        instanceId: 'flow-found-chip',
        gridId: 'backpack',
      );
      expect(
        _catalog
            .inventoryFromJson(
              grids: _grids,
              json: Map<String, Object?>.from(
                session.snapshot.state['inventory']! as Map,
              ),
            )
            .storage[streetScrapTutorialCrateStorageId],
        ['flow-found-chip'],
      );
      await withdrawStreetScrapFromTutorialCrate(
        session: session,
        commandId: 'flow-withdraw-chip',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        instanceId: 'flow-found-chip',
        gridId: 'backpack',
      );
      final finalInventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        finalInventory.objects['flow-found-chip']!.source,
        'found:chapter-three-street',
      );
      expect(finalInventory.objects['flow-found-chip']!.quality, 67);
      expect(finalInventory.objects['flow-found-chip']!.traits, {'dry': true});
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.04'],
        isTrue,
      );
      expect(session.snapshot.state['chapter'], 4);

      final bagInputs = <(String, String)>[
        ('flow-patch-0', 'cloth.patchwork'),
        ('flow-patch-1', 'cloth.patchwork'),
        ('flow-patch-2', 'cloth.patchwork'),
        ('flow-binding-0', 'cloth.binding'),
        ('flow-binding-1', 'cloth.binding'),
        ('flow-thread-0', 'cloth.thread_spool'),
        ('flow-thread-1', 'cloth.thread_spool'),
      ];
      var readyForBagUpgrade = finalInventory;
      for (final (instanceId, itemId) in bagInputs) {
        readyForBagUpgrade = readyForBagUpgrade.addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: instanceId,
            itemId: itemId,
            source: 'found:optional-bag-repair',
            quality: 60,
            traits: const {},
          ),
          'backpack',
        );
      }
      readyForBagUpgrade = readyForBagUpgrade.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'flow-upgrade-needle',
          itemId: 'tool.needle',
          source: 'starter',
          quality: 50,
          traits: const {},
          toolDurability: 5,
        ),
        'backpack',
      );
      await session.apply(
        commandId: 'flow-prepare-optional-bag-upgrade',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': readyForBagUpgrade.toJson()},
        ),
      );
      final bagRecipe = StreetScrapRecipe(
        id: 'ss.recipe.upgrade_bag',
        phase: 3,
        station: 'workbench',
        operationId: 'sew',
        durationSeconds: 10,
        instructions: 'Reinforce the existing backpack.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'cloth.patchwork', quantity: 3),
            StreetScrapRecipeInput(itemId: 'cloth.binding', quantity: 2),
            StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 2),
          ],
        ],
        reusableTools: const ['tool.needle'],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: ['cloth.patchwork'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: 'The upgrade still succeeds without reducing capacity.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        stateEffect: const {
          'type': 'upgradeBackpack',
          'fromItemId': 'bag.basic',
          'toItemId': 'bag.reinforced',
          'capacity': 24,
        },
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Arrange patchwork',
            options: ['Reinforce load seams', 'Leave gaps'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Attach the binding',
            options: ['At stress points', 'Anywhere'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Finish the repair',
            options: ['Keep the upgraded bag', 'Discard the old bag'],
            correctOption: 0,
          ),
        ],
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: _catalog,
        recipe: bagRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: [...bagInputs.map((entry) => entry.$1)],
        toolInstanceIds: const ['flow-upgrade-needle'],
        commandId: 'flow-upgrade-backpack',
        expectedRevision: session.snapshot.revision,
        manual: true,
        manualPoints: 0,
        outputInstanceId: (_) => 'unused-upgrade-output',
      );
      final finalBagInventory = _catalog.inventoryFromJson(
        grids: streetScrapGridSpecsForState(session.snapshot.state),
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final bag = session.snapshot.state['bagEquipment']! as Map;
      expect(bag['instanceId'], 'flow-original-bag');
      expect(bag['itemId'], 'bag.reinforced');
      expect(session.snapshot.state['backpackCapacity'], 24);
      expect(
        streetScrapGridSpecsForState(session.snapshot.state)['backpack']!.width,
        6,
      );
      expect(finalBagInventory.objects.containsKey('flow-found-chip'), isTrue);
      expect(
        finalBagInventory.objects.containsKey('flow-upgrade-needle'),
        isTrue,
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.05'],
        isTrue,
      );
      await session.close();
    },
  );

  test(
    'nailing gives precision and failure traits without changing the item type',
    () async {
      for (final points in [3, 1]) {
        final session = await _session('nail-board-craft-$points');
        var inventory = _catalog.emptyInventory(grids: _grids);
        for (var index = 0; index < 3; index++) {
          final id = 'rod-$points-$index';
          inventory = inventory.addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: id,
              itemId: 'wood.rod',
              source: index == 0
                  ? 'crafted:ss.recipe.press_rod'
                  : 'tutorial:q3.02-kit',
              quality: 60,
              traits: const {},
              toolDurability: null,
              footprint: _catalog.footprints['wood.rod']!,
            ),
            'board',
          );
        }
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'nails-$points',
            itemId: 'metal.nail_bundle',
            source: 'tutorial:q3.02-kit',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['metal.nail_bundle']!,
          ),
          'board',
        );
        await session.apply(
          commandId: 'prepare-q302-$points',
          expectedRevision: 1,
          reduce: (state) => StreetScrapReduction(
            state: {
              ...state,
              'tutorialTasks': {
                ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
                'q3.01': true,
                'q3.02.kitClaimed': true,
              },
              'inventory': inventory.toJson(),
            },
          ),
        );
        final recipe = StreetScrapRecipe(
          id: 'ss.recipe.nail_board',
          phase: 3,
          station: 'workbench',
          operationId: 'strike',
          durationSeconds: 10,
          instructions: '固定錘具／敲擊定位',
          inputGroups: const [
            [
              StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 3),
              StreetScrapRecipeInput(itemId: 'metal.nail_bundle', quantity: 1),
            ],
          ],
          reusableTools: const [],
          outputs: const [
            StreetScrapRecipeInput(itemId: 'wood.board', quantity: 1),
          ],
          quality: StreetScrapRecipeQualityRule(
            primaryInputs: const ['wood.rod'],
            loss: 8,
            mode: 'weighted-primary',
            masteryRevision: 1,
          ),
          retainedInputIds: const [],
          traitResolution: const {
            'inherit': [],
            'polarity': {
              'joint_reinforced': 'positive',
              'joint_skewed': 'negative',
            },
            'success': {},
            'precise': {'joint_reinforced': true},
            'failure': {'joint_skewed': true},
          },
          failureMode: 'explicitOutcome',
          failureOutcome: '成品保留；精準得釘固加強，失手得釘固偏斜',
          failureResolution: const StreetScrapFailureResolution(
            mode: 'sameOutputsQualityLoss',
            qualityLoss: 10,
          ),
          manualCheckpoints: [
            StreetScrapManualCheckpoint(
              prompt: '第一釘點',
              options: const ['接合標記', '木板外'],
              correctOption: 0,
            ),
            StreetScrapManualCheckpoint(
              prompt: '固定木料',
              options: const ['夾具', '徒手滑動'],
              correctOption: 0,
            ),
            StreetScrapManualCheckpoint(
              prompt: '檢查接縫',
              options: const ['平整穩固', '突出鬆動'],
              correctOption: 0,
            ),
          ],
        );
        await StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: _catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: [
            for (var index = 0; index < 3; index++) 'rod-$points-$index',
            'nails-$points',
          ],
          toolInstanceIds: const [],
          commandId: 'craft-board-$points',
          expectedRevision: 2,
          manual: true,
          manualPoints: points,
          outputInstanceId: (index) => 'board-$points-$index',
        );
        final resultInventory = _catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        final board = resultInventory.objects['board-$points-0']!;
        expect(board.itemId, 'wood.board');
        expect(
          board.traits,
          points == 3
              ? const {'joint_reinforced': true}
              : const {'joint_skewed': true},
        );
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q3.02'],
          isTrue,
        );
        await session.close();
      }
    },
  );

  test(
    'q3.03 repair restores ten uses and preserves the crowbar identity',
    () async {
      final session = await _session('crowbar-repair');
      await session.apply(
        commandId: 'complete-q302-for-repair',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.02': true,
            },
          },
        ),
      );
      await claimStreetScrapToolRepairKit(
        session: session,
        commandId: 'claim-repair-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      final before = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final original = before.objects['q303-crowbar']!;
      expect(original.toolDurability, 1);
      await repairStreetScrapTutorialCrowbar(
        session: session,
        commandId: 'repair-crowbar',
        expectedRevision: 3,
        catalog: _catalog,
        grids: _grids,
        toolInstanceId: 'q303-crowbar',
        metalShardInstanceId: 'q303-metal-shard',
        bindingInstanceId: 'q303-binding',
        gridId: 'backpack',
      );
      final after = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final repaired = after.objects['q303-crowbar']!;
      expect(repaired.instanceId, original.instanceId);
      expect(repaired.itemId, original.itemId);
      expect(repaired.source, original.source);
      expect(repaired.quality, original.quality);
      expect(repaired.traits, original.traits);
      expect(repaired.toolDurability, 11);
      expect(after.objects.containsKey('q303-metal-shard'), isFalse);
      expect(after.objects.containsKey('q303-binding'), isFalse);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.03'],
        isTrue,
      );
      await session.close();
    },
  );

  test(
    'q3.03 repair kit moves together to the workboard when the backpack is full',
    () async {
      final session = await _session('tutorial-repair-full-backpack');
      var inventory = _catalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 16; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'repair-full-bag-$index',
            itemId: 'wood.chip',
            source: 'test:existing-item',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.chip']!,
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'seed-full-backpack-for-repair-kit',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.02': true,
            },
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapToolRepairKit(
        session: session,
        commandId: 'claim-repair-kit-with-full-backpack',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final kit = inventory.objects.values
          .where((item) => item.source == 'tutorial:q3.03-kit')
          .toList(growable: false);
      expect(kit, hasLength(3));
      expect(
        kit
            .map((item) => inventory.placements[item.instanceId]!.gridId)
            .toSet(),
        {'board'},
      );

      final repaired = await repairStreetScrapTutorialCrowbar(
        session: session,
        commandId: 'repair-crowbar-on-workboard',
        expectedRevision: 3,
        catalog: _catalog,
        grids: _grids,
        toolInstanceId: 'q303-crowbar',
        metalShardInstanceId: 'q303-metal-shard',
        bindingInstanceId: 'q303-binding',
        gridId: 'board',
      );
      expect((repaired.result! as Map)['durability'], 11);
      expect((session.snapshot.state['tutorialTasks']! as Map)['q3.03'], true);
      await session.close();
    },
  );

  test(
    'repeatable maintenance cannot consume q3.03 tutorial tools or supplies',
    () async {
      final session = await _session('tutorial-repair-guard');
      await session.apply(
        commandId: 'complete-q302-for-repair-guard',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.02': true,
            },
          },
        ),
      );
      await claimStreetScrapToolRepairKit(
        session: session,
        commandId: 'claim-repair-guard-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      await expectLater(
        repairStreetScrapTool(
          session: session,
          commandId: 'generic-repair-steals-lesson-kit',
          expectedRevision: 3,
          catalog: _catalog,
          grids: _grids,
          toolInstanceId: 'q303-crowbar',
          materialInstanceIds: ['q303-metal-shard', 'q303-binding'],
          rule: const StreetScrapToolRepairRule(
            id: 'repair.crowbar',
            toolItemId: 'tool.crowbar',
            phase: 3,
            restoreUses: 10,
            materialOptions: [
              ['metal.shard', 'cloth.binding'],
            ],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'tutorialRepairRequired',
          ),
        ),
      );
      final inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(inventory.objects['q303-crowbar']!.toolDurability, 1);
      expect(
        inventory.objects.keys,
        containsAll(['q303-metal-shard', 'q303-binding']),
      );
      await session.close();
    },
  );

  test(
    'q3.03 replenishes consumed lesson supplies without duplicating them',
    () async {
      final session = await _session('tutorial-repair-recovery');
      final recoveredTool = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'q303-crowbar',
              itemId: 'tool.crowbar',
              source: 'tutorial:q3.03-kit',
              quality: 55,
              traits: const {},
              toolDurability: 11,
              footprint: _catalog.footprints['tool.crowbar']!,
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'seed-repair-recovery',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {'q3.02': true, 'q3.03.kitClaimed': true},
            'inventory': recoveredTool.toJson(),
          },
        ),
      );
      final replenished = await claimStreetScrapToolRepairKit(
        session: session,
        commandId: 'restore-repair-supplies',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      expect((replenished.result! as Map)['restoredSupplies'], 2);
      await expectLater(
        claimStreetScrapToolRepairKit(
          session: session,
          commandId: 'restore-repair-supplies-again',
          expectedRevision: 3,
          catalog: _catalog,
          grids: _grids,
        ),
        throwsA(isA<StateError>()),
      );
      final result = await repairStreetScrapTutorialCrowbar(
        session: session,
        commandId: 'finish-repair-after-recovery',
        expectedRevision: 3,
        catalog: _catalog,
        grids: _grids,
        toolInstanceId: 'q303-crowbar',
        metalShardInstanceId: 'q303-metal-shard',
        bindingInstanceId: 'q303-binding',
        gridId: 'backpack',
      );
      expect((result.result! as Map)['durability'], 21);
      expect((session.snapshot.state['tutorialTasks']! as Map)['q3.03'], true);
      await session.close();
    },
  );

  test(
    'repeatable tool repair preserves identity and never exceeds quality cap',
    () async {
      final session = await _session('repeatable-tool-repair');
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'owned-crowbar',
              itemId: 'tool.crowbar',
              source: 'crafted:test',
              quality: 55,
              traits: const {'joint_reinforced': true},
              toolDurability: 25,
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'repair-shard',
              itemId: 'metal.shard',
              source: 'test',
              quality: 45,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'repair-binding',
              itemId: 'cloth.binding',
              source: 'test',
              quality: 45,
              traits: const {},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'seed-repeatable-repair',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'chapter': 3, 'inventory': inventory.toJson()},
        ),
      );
      await repairStreetScrapTool(
        session: session,
        commandId: 'repair-repeatable-crowbar',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        toolInstanceId: 'owned-crowbar',
        materialInstanceIds: ['repair-shard', 'repair-binding'],
        rule: const StreetScrapToolRepairRule(
          id: 'repair.crowbar',
          toolItemId: 'tool.crowbar',
          phase: 3,
          restoreUses: 10,
          materialOptions: [
            ['metal.shard', 'cloth.binding'],
          ],
        ),
      );
      final after = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final repaired = after.objects['owned-crowbar']!;
      expect(repaired.toolDurability, 30);
      expect(repaired.source, 'crafted:test');
      expect(repaired.quality, 55);
      expect(repaired.traits, {'joint_reinforced': true});
      expect(after.objects.containsKey('repair-shard'), isFalse);
      expect(after.objects.containsKey('repair-binding'), isFalse);
      await session.apply(
        commandId: 'restock-full-tool-test',
        expectedRevision: 3,
        reduce: (state) {
          final current = _catalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(state['inventory']! as Map),
          );
          final replenished = current
              .addAndPlaceFirstFit(
                _catalog.createObject(
                  instanceId: 'full-repair-shard',
                  itemId: 'metal.shard',
                  source: 'test',
                  quality: 45,
                  traits: const {},
                ),
                'backpack',
              )
              .addAndPlaceFirstFit(
                _catalog.createObject(
                  instanceId: 'full-repair-binding',
                  itemId: 'cloth.binding',
                  source: 'test',
                  quality: 45,
                  traits: const {},
                ),
                'backpack',
              );
          return StreetScrapReduction(
            state: {...state, 'inventory': replenished.toJson()},
          );
        },
      );
      await expectLater(
        repairStreetScrapTool(
          session: session,
          commandId: 'repair-full-crowbar',
          expectedRevision: 4,
          catalog: _catalog,
          grids: _grids,
          toolInstanceId: 'owned-crowbar',
          materialInstanceIds: ['full-repair-shard', 'full-repair-binding'],
          rule: const StreetScrapToolRepairRule(
            id: 'repair.crowbar',
            toolItemId: 'tool.crowbar',
            phase: 3,
            restoreUses: 10,
            materialOptions: [
              ['metal.shard', 'cloth.binding'],
            ],
          ),
        ),
        throwsA(isA<StateError>()),
      );
      final unchanged = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(unchanged.objects['owned-crowbar']!.toolDurability, 30);
      expect(unchanged.objects.containsKey('full-repair-shard'), isTrue);
      expect(unchanged.objects.containsKey('full-repair-binding'), isTrue);
      await session.close();
    },
  );

  testWidgets('wood press and nail-board lessons follow the English locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await _session('woodwork-lesson-localization');
    Widget panel() => MaterialApp(
      home: StreetScrapLocalizationsScope(
        locale: 'en',
        child: Scaffold(
          body: StreetScrapWoodworkingPanel(
            session: session,
            catalog: _catalog,
            onOpenRecipes: () {},
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(panel());
    expect(find.byType(StreetScrapItemSprite), findsNWidgets(3));
    expect(
      tester
          .widget<StreetScrapItemSprite>(
            find.byType(StreetScrapItemSprite).first,
          )
          .size,
      64,
      reason: 'The compact workstation uses readable, enlarged material art.',
    );
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('Wood chips'), findsOneWidget);
    expect(
      find.text(
        'Align three wood chips with the grain, apply recycled adhesive, then clamp them into a rod. A miss still produces a usable rod at lower quality.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Lesson supplies go into your backpack, or together on the workboard if it is full: 3 wood chips and 1 recycled adhesive.',
      ),
      findsNothing,
    );
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Align three wood chips with the grain, apply recycled adhesive, then clamp them into a rod. A miss still produces a usable rod at lower quality.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Lesson supplies go into your backpack, or together on the workboard if it is full: 3 wood chips and 1 recycled adhesive.',
      ),
      findsOneWidget,
    );
    expect(find.text('Claim pressing materials'), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await session.apply(
      commandId: 'advance-press-lesson-localization',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.01': true,
          },
        },
      ),
    );
    await tester.pumpWidget(panel());
    expect(find.byType(StreetScrapItemSprite), findsNWidgets(3));
    expect(
      find.text(
        'Pressing lesson complete. Rods can be nailed into boards or used to make tool handles.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Nailing lesson supplies top up to 3 usable rods and 1 nail bundle; rods on your workboard or in your backpack count toward the total.',
      ),
      findsNothing,
    );
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Pressing lesson complete. Rods can be nailed into boards or used to make tool handles.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Nailing lesson supplies top up to 3 usable rods and 1 nail bundle; rods on your workboard or in your backpack count toward the total.',
      ),
      findsOneWidget,
    );
    expect(find.text('Claim nailing materials'), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();

    await session.apply(
      commandId: 'advance-nailing-lesson-localization',
      expectedRevision: 2,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.02': true,
          },
        },
      ),
    );
    await tester.pumpWidget(panel());
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Board nailing complete. Precise work can add the Reinforced Nails trait; a miss still yields a usable board with a Bent Nails trait.',
      ),
      findsOneWidget,
    );
    expect(find.text('Claim repair materials'), findsOneWidget);
    await session.close();
  });

  testWidgets(
    'q3.03 repair lesson restores missing supplies before maintenance',
    (tester) async {
      final session = await _session('repair-lesson-ui-recovery');
      await session.apply(
        commandId: 'complete-nailing-for-repair-ui',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.02': true,
            },
          },
        ),
      );
      await claimStreetScrapToolRepairKit(
        session: session,
        commandId: 'q3.03.claim-tool-repair-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'q303-crowbar',
              itemId: 'tool.crowbar',
              source: 'tutorial:q3.03-kit',
              quality: 55,
              traits: const {},
              toolDurability: 11,
              footprint: _catalog.footprints['tool.crowbar']!,
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'simulate-consumed-repair-kit',
        expectedRevision: 3,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': inventory.toJson()},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StreetScrapLocalizationsScope(
            locale: 'en',
            child: Scaffold(
              body: StreetScrapWoodworkingPanel(
                session: session,
                catalog: _catalog,
                repairCatalog: StreetScrapToolRepairCatalog([
                  StreetScrapToolRepairRule(
                    id: 'repair.crowbar',
                    toolItemId: 'tool.crowbar',
                    phase: 3,
                    restoreUses: 10,
                    materialOptions: [
                      ['metal.shard', 'cloth.binding'],
                    ],
                  ),
                ]),
                onOpenRecipes: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Restore missing repair materials'), findsOneWidget);
      expect(find.text('Tool Maintenance'), findsNothing);
      await tester.tap(find.text('Restore missing repair materials'));
      await tester.pumpAndSettle();
      var restoredInventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        restoredInventory.objects.keys,
        containsAll(['q303-metal-shard', 'q303-binding']),
      );
      expect(find.text('Repair crowbar (+10 durability)'), findsOneWidget);
      await tester.tap(find.text('Repair crowbar (+10 durability)'));
      await tester.pumpAndSettle();
      expect((session.snapshot.state['tutorialTasks']! as Map)['q3.03'], true);
      restoredInventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(restoredInventory.objects['q303-crowbar']!.toolDurability, 21);
      await session.close();
    },
  );

  testWidgets('nail kit claim is not swallowed by a legacy command receipt', (
    tester,
  ) async {
    final session = await _session('nail-kit-legacy-receipt');
    final inventory = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'existing-pressed-rod',
            itemId: 'wood.rod',
            source: 'crafted:ss.recipe.press_rod',
            quality: 47,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints['wood.rod']!,
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'complete-press-for-nailing',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.01': true,
          },
          'inventory': inventory.toJson(),
        },
      ),
    );
    // Reproduce a pre-existing receipt with the old fixed q3.02 command ID.
    await session.apply(
      commandId: 'q3.02.claim-nail-board-kit',
      expectedRevision: 2,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'unrelatedReceiptProbe': true},
      ),
    );
    expect(
      session.snapshot.state['tutorialTasks'],
      isNot(contains('q3.02.kitClaimed')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    final claimButton = find.text('Claim nailing materials');
    expect(claimButton, findsOneWidget);
    await tester.tap(claimButton);
    await tester.pumpAndSettle();

    expect(session.snapshot.revision, 4);
    final tasks = Map<String, Object?>.from(
      session.snapshot.state['tutorialTasks']! as Map,
    );
    expect(tasks['q3.02.kitClaimed'], isTrue);
    final after = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(
      after.objects.values.where((item) => item.itemId == 'wood.rod'),
      hasLength(3),
    );
    expect(
      after.objects.values.where((item) => item.itemId == 'metal.nail_bundle'),
      hasLength(1),
    );
    expect(find.text('Claim nailing materials'), findsNothing);
    await session.close();
  });

  testWidgets('nail kit save conflict is visible and leaves progress unchanged', (
    tester,
  ) async {
    final store = _Store();
    final session = await _session('nail-kit-save-conflict', store: store);
    await session.apply(
      commandId: 'complete-press-before-save-conflict',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.01': true,
          },
        },
      ),
    );
    store.failNextCompareAndSwap = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Claim nailing materials'));
    await tester.pumpAndSettle();

    expect(session.snapshot.revision, 2);
    expect(store.failNextCompareAndSwap, isFalse);
    expect(
      (session.snapshot.state['tutorialTasks']! as Map)['q3.02.kitClaimed'],
      isNot(true),
    );
    expect(
      find.text(
        'Action did not complete: Could not confirm whether this action was saved. Reload and check your materials and progress before retrying.',
      ),
      findsOneWidget,
    );
    await session.close();
  });

  testWidgets('backpack upgrade milestone summary uses the English locale', (
    tester,
  ) async {
    final session = await _session('bag-milestone-localization');
    await session.apply(
      commandId: 'seed-crate-milestone',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.04': true,
          },
          'backpackCapacity': 16,
        },
      ),
    );
    Widget panel() => MaterialApp(
      home: StreetScrapLocalizationsScope(
        locale: 'en',
        child: Scaffold(
          body: StreetScrapWoodworkingPanel(
            session: session,
            catalog: _catalog,
            onOpenRecipes: () {},
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(panel());
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your first crate is placed and item storage works. Capacity uses grid cells; retrieve ingredients before crafting. Backpack capacity is 16 cells; repairing the bag is optional.',
      ),
      findsOneWidget,
    );
    await session.apply(
      commandId: 'upgrade-bag-milestone',
      expectedRevision: 2,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.05': true,
          },
          'backpackCapacity': 24,
        },
      ),
    );
    await tester.pumpWidget(panel());
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Wooden crate storage is working and the repaired backpack is upgraded to 24 cells. Your original bag and existing items were preserved.',
      ),
      findsOneWidget,
    );
    await session.close();
  });

  testWidgets('daily tool repair controls follow the English locale', (
    tester,
  ) async {
    final session = await _session('repair-localization');
    final inventory = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'repair-localized-crowbar',
            itemId: 'tool.crowbar',
            source: 'found:test',
            quality: 55,
            traits: const {},
            toolDurability: 10,
          ),
          'backpack',
        )
        .addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'repair-localized-shard',
            itemId: 'metal.shard',
            source: 'found:test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        )
        .addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'repair-localized-binding',
            itemId: 'cloth.binding',
            source: 'found:test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'seed-repair-localization',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'inventory': inventory.toJson(),
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.02': true,
          },
        },
      ),
    );
    final repairCatalog = StreetScrapToolRepairCatalog([
      const StreetScrapToolRepairRule(
        id: 'repair.crowbar',
        toolItemId: 'tool.crowbar',
        phase: 3,
        restoreUses: 8,
        materialOptions: [
          ['metal.shard', 'cloth.binding'],
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              repairCatalog: repairCatalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Tool Maintenance'), findsOneWidget);
    expect(
      find.text(
        'Repairs use material combinations from installed content. Each repair restores a set amount without exceeding the tool quality cap. Keep the tool and materials on the same board or in the backpack.',
      ),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const Key('street-scrap-repair-rules')),
    );
    await tester.tap(find.byKey(const Key('street-scrap-repair-rules')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Repairs use material combinations from installed content. Each repair restores a set amount without exceeding the tool quality cap. Keep the tool and materials on the same board or in the backpack.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Repair lesson supplies: a crowbar with 1 use remaining, 1 metal shard, and 1 binding strip.',
      ),
      findsOneWidget,
    );
    expect(find.text('Claim repair materials'), findsOneWidget);
    expect(find.text('Choose a tool to repair'), findsOneWidget);
    expect(find.text('Choose repair materials'), findsOneWidget);

    final toolDropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(toolDropdown);
    await tester.tap(toolDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crowbar · durability 10').last);
    await tester.pumpAndSettle();
    expect(find.text('Metal shard'), findsOneWidget);
    expect(find.text('Quality: Ordinary (50)'), findsNWidgets(2));
    expect(find.text('Binding strip'), findsOneWidget);
    expect(find.byType(StreetScrapItemSprite), findsAtLeastNWidgets(2));
    await tester.ensureVisible(find.text('Metal shard'));
    await tester.tap(find.text('Metal shard'));
    await tester.ensureVisible(find.text('Binding strip'));
    await tester.tap(find.text('Binding strip'));
    await tester.pumpAndSettle();
    expect(find.text('Repair tool (+8 durability)'), findsOneWidget);
    await session.apply(
      commandId: 'complete-repair-localization',
      expectedRevision: 2,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.03': true,
          },
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              repairCatalog: repairCatalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byType(ExpansionTile).first);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Crowbar repaired: its identity, quality, and source are preserved. One metal shard and one binding strip were consumed; durability increased by 10.',
      ),
      findsOneWidget,
    );
    await session.close();
  });

  test(
    'phase-five distilled-water maintenance consumes liquid, not its vessel',
    () async {
      final session = await _session('precision-tool-repair');
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'precision-crowbar',
              itemId: 'tool.crowbar',
              source: 'crafted:test',
              quality: 55,
              traits: const {},
              toolDurability: 4,
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'distilled-water-bottle',
              itemId: 'container.clean',
              source: 'filled:test',
              quality: 70,
              traits: const {},
              containerState: const {
                'contentItemId': 'water.distilled',
                'contentQuality': 70,
                'contentSource': 'condensed:test',
                'cleanliness': 'clean',
              },
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'precision-cloth-edge',
              itemId: 'cloth.edge_scrap',
              source: 'test',
              quality: 45,
              traits: const {},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'seed-precision-maintenance',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'chapter': 5, 'inventory': inventory.toJson()},
        ),
      );
      await repairStreetScrapTool(
        session: session,
        commandId: 'precision-maintenance',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        toolInstanceId: 'precision-crowbar',
        materialInstanceIds: ['distilled-water-bottle', 'precision-cloth-edge'],
        rule: const StreetScrapToolRepairRule(
          id: 'repair.precision.crowbar',
          toolItemId: 'tool.crowbar',
          phase: 5,
          restoreUses: 10,
          materialOptions: [
            ['content:water.distilled', 'cloth.edge_scrap'],
          ],
        ),
      );
      final after = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(after.objects['precision-crowbar']!.toolDurability, 14);
      expect(after.objects.containsKey('distilled-water-bottle'), isTrue);
      expect(
        after
            .objects['distilled-water-bottle']!
            .containerState['contentItemId'],
        isNull,
      );
      expect(
        after
            .objects['distilled-water-bottle']!
            .containerState['lastContentItemId'],
        'water.distilled',
      );
      expect(after.objects.containsKey('precision-cloth-edge'), isFalse);
      await session.close();
    },
  );

  test(
    'rust maintenance is resumable and spends auxiliaries on either outcome',
    () async {
      for (final configuration in [
        (key: 'rust-success', answers: [1, 1, 0], succeeded: true),
        (key: 'rust-failure', answers: [1, 0, 0], succeeded: false),
      ]) {
        final session = await _session(configuration.key);
        final inventory = _catalog
            .emptyInventory(grids: _grids)
            .addAndPlaceFirstFit(
              _catalog.createObject(
                instanceId: 'rusted-metal-${configuration.key}',
                itemId: 'metal.sheet',
                source: 'native-pickup',
                quality: 68,
                traits: const {'rusted': true},
              ),
              'backpack',
            )
            .addAndPlaceFirstFit(
              _catalog.createObject(
                instanceId: 'edge-${configuration.key}',
                itemId: 'cloth.edge_scrap',
                source: 'test',
                quality: 40,
                traits: const {},
              ),
              'backpack',
            )
            .addAndPlaceFirstFit(
              _catalog.createObject(
                instanceId: 'filtered-${configuration.key}',
                itemId: 'container.clean',
                source: 'test',
                quality: 60,
                traits: const {},
                containerState: const {
                  'contentItemId': 'water.filtered',
                  'contentQuality': 75,
                  'contentSource': 'filter-test',
                  'contentTraits': <String, Object?>{},
                  'requiresBoiling': false,
                  'cleanliness': 'utility',
                },
              ),
              'backpack',
            );
        await session.apply(
          commandId: 'rust-inventory-${configuration.key}',
          expectedRevision: 1,
          reduce: (state) => StreetScrapReduction(
            state: {...state, 'inventory': inventory.toJson()},
          ),
        );
        final targetId = 'rusted-metal-${configuration.key}';
        final clothId = 'edge-${configuration.key}';
        final vesselId = 'filtered-${configuration.key}';
        await StreetScrapMaintenance.beginRustRemoval(
          session: session,
          catalog: _catalog,
          grids: _grids,
          gridId: 'backpack',
          metalInstanceId: targetId,
          clothScrapInstanceId: clothId,
          filteredWaterVesselInstanceId: vesselId,
          operationId: 'rust-operation-${configuration.key}',
          commandId: 'begin-craft-rust-operation-${configuration.key}',
          expectedRevision: 2,
        );
        expect(
          (session.snapshot.state['craftOperation']!
              as Map)['lockedInstanceIds'],
          [targetId, clothId, vesselId],
        );
        final lockedRevision = session.snapshot.revision;
        await expectLater(
          session.applyInventoryCommand(
            commandId: 'try-change-locked-water-${configuration.key}',
            expectedRevision: lockedRevision,
            catalog: _catalog,
            grids: _grids,
            reduceInventory: (current) => current.withContainerState(
              vesselId,
              const {'cleanliness': 'clean'},
            ),
          ),
          throwsStateError,
        );
        expect(session.snapshot.revision, lockedRevision);
        StreetScrapCommandResult? result;
        for (var step = 0; step < configuration.answers.length; step++) {
          result = await StreetScrapMaintenance.answerRustCheckpoint(
            session: session,
            catalog: _catalog,
            grids: _grids,
            operationId: 'rust-operation-${configuration.key}',
            optionIndex: configuration.answers[step],
            expectedRevision: session.snapshot.revision,
          );
        }
        expect((result!.result as Map)['succeeded'], configuration.succeeded);
        final savedInventory = _catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        final metal = savedInventory.objects[targetId]!;
        expect(metal.instanceId, targetId);
        expect(metal.itemId, 'metal.sheet');
        expect(metal.source, 'native-pickup');
        expect(metal.quality, 68);
        expect(metal.traits.containsKey('rusted'), !configuration.succeeded);
        expect(savedInventory.objects.containsKey(clothId), isFalse);
        expect(savedInventory.objects[vesselId]!.instanceId, vesselId);
        expect(
          savedInventory.objects[vesselId]!.containerState['contentItemId'],
          isNull,
        );
        expect(
          savedInventory.objects[vesselId]!.containerState['cleanliness'],
          'clean',
        );
        expect(session.snapshot.state['craftOperation'], isNull);
        expect(metal.provenance.last['recipeId'], 'maintenance.remove_rust');
        await session.close();
      }
    },
  );

  test(
    'damp-trait maintenance dries wood and spends fuel on either outcome',
    () async {
      final profile = StreetScrapMaintenance.profileForRecipeId(
        'maintenance.remove_damp',
      )!;
      for (final configuration in [
        (key: 'damp-success', answers: [1, 1, 0], succeeded: true),
        (key: 'damp-failure', answers: [1, 0, 0], succeeded: false),
      ]) {
        final session = await _session(configuration.key);
        final targetId = 'damp-board-${configuration.key}';
        final fuelId = 'dry-fuel-${configuration.key}';
        final inventory = _catalog
            .emptyInventory(grids: _grids)
            .addAndPlaceFirstFit(
              _catalog.createObject(
                instanceId: targetId,
                itemId: 'wood.board',
                source: 'native-pickup',
                quality: 63,
                traits: const {'damp': true, 'joint_reinforced': true},
              ),
              'backpack',
            )
            .addAndPlaceFirstFit(
              _catalog.createObject(
                instanceId: fuelId,
                itemId: 'fuel.dry',
                source: 'test',
                quality: 50,
                traits: const {},
              ),
              'backpack',
            );
        await session.apply(
          commandId: 'damp-inventory-${configuration.key}',
          expectedRevision: 1,
          reduce: (state) => StreetScrapReduction(
            state: {...state, 'inventory': inventory.toJson()},
          ),
        );
        final operationId = 'damp-op-${configuration.key}';
        await StreetScrapMaintenance.beginTraitMaintenance(
          session: session,
          catalog: _catalog,
          grids: _grids,
          gridId: 'backpack',
          profile: profile,
          targetInstanceId: targetId,
          auxiliaryInstanceId: fuelId,
          operationId: operationId,
          commandId: 'begin-craft-$operationId',
          expectedRevision: 2,
        );
        StreetScrapCommandResult? result;
        for (var step = 0; step < configuration.answers.length; step++) {
          result = await StreetScrapMaintenance.answerMaintenanceCheckpoint(
            session: session,
            catalog: _catalog,
            grids: _grids,
            operationId: operationId,
            optionIndex: configuration.answers[step],
            expectedRevision: session.snapshot.revision,
          );
        }
        expect((result!.result as Map)['succeeded'], configuration.succeeded);
        final saved = _catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        final board = saved.objects[targetId]!;
        expect(board.itemId, 'wood.board');
        expect(board.quality, 63);
        expect(board.traits['joint_reinforced'], isTrue);
        expect(board.traits.containsKey('damp'), !configuration.succeeded);
        expect(saved.objects.containsKey(fuelId), isFalse);
        expect(session.snapshot.state['craftOperation'], isNull);
        await session.close();
      }
    },
  );

  test(
    'all plan-listed removable traits resolve to their canonical profiles',
    () {
      const cases = <(String, String, String)>[
        ('maintenance.remove_frayed', 'cloth.patchwork', 'frayed'),
        ('maintenance.remove_damp', 'wood.board', 'damp'),
        ('maintenance.remove_rust', 'metal.sheet', 'rusted'),
        ('maintenance.remove_brittle', 'plastic.scrap', 'brittle'),
        ('maintenance.remove_smoky', 'fuel.dry', 'smoky'),
        ('maintenance.remove_joint_skewed', 'wood.board', 'joint_skewed'),
      ];
      for (final (recipeId, itemId, traitId) in cases) {
        final profile = StreetScrapMaintenance.profileForRecipeId(recipeId);
        expect(profile, isNotNull, reason: recipeId);
        expect(profile!.traitId, traitId);
        final target = _catalog.createObject(
          instanceId: 'profile-$traitId',
          itemId: itemId,
          source: 'test',
          quality: 50,
          traits: {traitId: true},
        );
        expect(
          StreetScrapMaintenance.profilesForTarget(target),
          contains(profile),
          reason: '$recipeId accepts $itemId with $traitId',
        );
      }
    },
  );

  test(
    'frayed, brittle, smoky, and skewed-joint maintenance settle both outcomes',
    () async {
      const cases = <(String, String, String, String, String)>[
        (
          'frayed',
          'maintenance.remove_frayed',
          'cloth.patchwork',
          'frayed',
          'cloth.thread_spool',
        ),
        (
          'brittle',
          'maintenance.remove_brittle',
          'plastic.scrap',
          'brittle',
          'fuel.dry',
        ),
        (
          'smoky',
          'maintenance.remove_smoky',
          'fuel.dry',
          'smoky',
          'paper.scrap',
        ),
        (
          'skewed',
          'maintenance.remove_joint_skewed',
          'wood.board',
          'joint_skewed',
          'metal.nail_bundle',
        ),
      ];
      for (final (key, recipeId, targetItemId, traitId, auxiliaryItemId)
          in cases) {
        for (final succeeded in [true, false]) {
          await _verifyMaintenanceOutcome(
            key: '$key-${succeeded ? 'success' : 'failure'}',
            recipeId: recipeId,
            targetItemId: targetItemId,
            traitId: traitId,
            auxiliaryItemId: auxiliaryItemId,
            succeeded: succeeded,
          );
        }
      }
    },
  );

  test(
    'maintenance uses canonical costs and can cancel only before first step',
    () async {
      final session = await _session('maintenance-canonical-cancel');
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'maintenance-damp-target',
              itemId: 'wood.board',
              source: 'test',
              quality: 60,
              traits: const {'damp': true},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'maintenance-wrong-aux',
              itemId: 'paper.scrap',
              source: 'test',
              quality: 40,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'maintenance-fuel',
              itemId: 'fuel.dry',
              source: 'test',
              quality: 40,
              traits: const {},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'maintenance-canonical-inventory',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': inventory.toJson()},
        ),
      );
      final canonical = StreetScrapMaintenance.profileForRecipeId(
        'maintenance.remove_damp',
      )!;
      final spoofed = StreetScrapTraitMaintenanceProfile(
        recipeId: canonical.recipeId,
        traitId: canonical.traitId,
        acceptedItemIds: const ['wood.board'],
        auxiliaryItemId: 'paper.scrap',
        operationId: 'heat',
        title: 'test',
        prompts: const ['1', '2', '3'],
      );
      await expectLater(
        StreetScrapMaintenance.beginTraitMaintenance(
          session: session,
          catalog: _catalog,
          grids: _grids,
          gridId: 'backpack',
          profile: spoofed,
          targetInstanceId: 'maintenance-damp-target',
          auxiliaryInstanceId: 'maintenance-wrong-aux',
          operationId: 'maintenance-canonical-op',
          commandId: 'maintenance-canonical-begin-rejected',
          expectedRevision: 2,
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.revision, 2);
      await StreetScrapMaintenance.beginTraitMaintenance(
        session: session,
        catalog: _catalog,
        grids: _grids,
        gridId: 'backpack',
        profile: canonical,
        targetInstanceId: 'maintenance-damp-target',
        auxiliaryInstanceId: 'maintenance-fuel',
        operationId: 'maintenance-cancel-op',
        commandId: 'maintenance-cancel-begin',
        expectedRevision: 2,
      );
      await StreetScrapMaintenance.cancelMaintenance(
        session: session,
        operationId: 'maintenance-cancel-op',
        expectedRevision: session.snapshot.revision,
      );
      expect(session.snapshot.state['craftOperation'], isNull);
      final afterCancel = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(afterCancel.objects.keys, contains('maintenance-fuel'));
      expect(afterCancel.objects.keys, contains('maintenance-damp-target'));
      expect(afterCancel.objects.keys, contains('maintenance-wrong-aux'));
      await session.close();
    },
  );

  test(
    'q3.04 crate kit ignores stored boards and falls back to the work board',
    () async {
      final session = await _session('crate-kit-carried-space');
      var inventory = _catalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 16; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'crate-space-chip-$index',
            itemId: 'wood.chip',
            source: 'test',
            quality: 55,
            traits: const {},
          ),
          'backpack',
        );
      }
      inventory = StreetScrapInventory(
        catalog: _catalog,
        grids: _grids,
        objects: {
          ...inventory.objects,
          'stored-board': _catalog.createObject(
            instanceId: 'stored-board',
            itemId: 'wood.board',
            source: 'native-pickup',
            quality: 80,
            traits: const {},
          ),
        },
        placements: inventory.placements,
        storage: const {
          'home-tutorial-crate': ['stored-board'],
        },
      );
      await session.apply(
        commandId: 'crate-kit-carried-space-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {'q2.03': true, 'q3.03': true},
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapCrateKit(
        session: session,
        commandId: 'crate-kit-carried-space-claim',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      final saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final placedByItem = <String, int>{};
      for (final id in saved.placements.keys) {
        final item = saved.objects[id]!;
        placedByItem.update(
          item.itemId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      expect(placedByItem['wood.board'], 4);
      expect(placedByItem['metal.nail_bundle'], 2);
      expect(placedByItem['adhesive.recycled'], 1);
      expect(saved.placements['q304-wood-board-0']?.gridId, 'board');
      expect(saved.storage['home-tutorial-crate'], ['stored-board']);
      expect(saved.objects['stored-board']?.quality, 80);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.04.kitClaimed'],
        isTrue,
      );
      await session.close();
    },
  );

  test(
    'q3.04 crate kit consolidates carried recipe materials onto one grid',
    () async {
      final session = await _session('crate-kit-one-grid');
      var inventory = _catalog.emptyInventory(grids: _grids);
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'crate-kit-existing-board',
          itemId: 'wood.board',
          source: 'native-pickup',
          quality: 80,
          traits: const {},
        ),
        'board',
      );
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'crate-kit-existing-nails',
          itemId: 'metal.nail_bundle',
          source: 'native-pickup',
          quality: 72,
          traits: const {},
        ),
        'backpack',
      );
      await session.apply(
        commandId: 'crate-kit-one-grid-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {'q2.03': true, 'q3.03': true},
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapCrateKit(
        session: session,
        commandId: 'crate-kit-one-grid-claim',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      final saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final countsByGrid = <String, Map<String, int>>{};
      for (final placement in saved.placements.values) {
        final item = saved.objects[placement.instanceId]!;
        countsByGrid
            .putIfAbsent(placement.gridId, () => {})
            .update(item.itemId, (count) => count + 1, ifAbsent: () => 1);
      }
      expect(
        countsByGrid.values.any(
          (counts) =>
              (counts['wood.board'] ?? 0) >= 4 &&
              (counts['metal.nail_bundle'] ?? 0) >= 2 &&
              (counts['adhesive.recycled'] ?? 0) >= 1,
        ),
        isTrue,
        reason:
            'The crate recipe must be fully selectable from one carried grid.',
      );
      expect(saved.objects['crate-kit-existing-board']?.quality, 80);
      expect(saved.objects['crate-kit-existing-nails']?.quality, 72);
      expect(
        saved.placements['crate-kit-existing-nails']?.gridId,
        'board',
        reason: 'Existing carried recipe materials are consolidated in place.',
      );
      await session.close();
    },
  );

  test(
    'q3.04 places the crafted crate and round-trips an item without changing identity',
    () async {
      final session = await _session('crate-place-access');
      var inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            StreetScrapObject(
              instanceId: 'stored-chip',
              itemId: 'container.clean',
              source: 'found:crate-tutorial',
              quality: 67,
              traits: const {'dry': true},
              toolDurability: null,
              footprint: _catalog.footprints['container.clean']!,
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'prepare-q304',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.03': true,
            },
            'inventory': inventory.toJson(),
          },
        ),
      );
      await claimStreetScrapCrateKit(
        session: session,
        commandId: 'claim-crate-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        inventory.objects.values.where((item) => item.itemId == 'wood.board'),
        hasLength(4),
      );
      expect(
        inventory.objects.values.where(
          (item) => item.itemId == 'metal.nail_bundle',
        ),
        hasLength(2),
      );
      expect(
        inventory.objects.values.where(
          (item) => item.itemId == 'adhesive.recycled',
        ),
        hasLength(1),
      );
      inventory = inventory.addAndPlaceFirstFit(
        StreetScrapObject(
          instanceId: 'crafted-crate',
          itemId: 'storage.wooden_crate',
          source: 'crafted:ss.recipe.wooden_crate',
          quality: 52,
          traits: const {},
          toolDurability: null,
          footprint: _catalog.footprints['storage.wooden_crate']!,
        ),
        'board',
      );
      await session.apply(
        commandId: 'save-crate-craft',
        expectedRevision: 3,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'inventory': inventory.toJson(),
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.04.crateCrafted': true,
            },
          },
        ),
      );
      await placeStreetScrapTutorialCrate(
        session: session,
        commandId: 'place-crate',
        expectedRevision: 4,
        catalog: _catalog,
        grids: _grids,
        crateInstanceId: 'crafted-crate',
        gridId: 'board',
      );
      await storeStreetScrapInTutorialCrate(
        session: session,
        commandId: 'store-chip',
        expectedRevision: 5,
        catalog: _catalog,
        grids: _grids,
        instanceId: 'stored-chip',
        gridId: 'backpack',
      );
      final storedInventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(storedInventory.storage[streetScrapTutorialCrateStorageId], [
        'stored-chip',
      ]);
      await withdrawStreetScrapFromTutorialCrate(
        session: session,
        commandId: 'withdraw-chip',
        expectedRevision: 6,
        catalog: _catalog,
        grids: _grids,
        instanceId: 'stored-chip',
        gridId: 'backpack',
      );
      final restoredInventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final restored = restoredInventory.objects['stored-chip']!;
      expect(restored.itemId, 'container.clean');
      expect(restored.source, 'found:crate-tutorial');
      expect(restored.quality, 67);
      expect(restored.traits, const {'dry': true});
      expect(restoredInventory.placements['stored-chip']!.gridId, 'backpack');
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.04'],
        isTrue,
      );
      expect(session.snapshot.state['chapter'], 4);
      final furniture = session.snapshot.state['storageFurniture']! as Map;
      expect(
        (furniture[streetScrapTutorialCrateStorageId]! as Map)['capacity'],
        12,
      );
      await session.close();
    },
  );

  test(
    'q3.04 withdraws a large item to the workboard when only one backpack row is free',
    () async {
      final session = await _session('crate-withdraw-workboard-fallback');
      final frame = StreetScrapObject(
        instanceId: 'stored-frame',
        itemId: 'wood.frame',
        source: 'crafted:crate-tutorial',
        quality: 61,
        traits: const {'joint_reinforced': true},
        toolDurability: null,
        footprint: _catalog.footprints['wood.frame']!,
      );
      final inventory = StreetScrapInventory(
        catalog: _catalog,
        grids: _grids,
        objects: {
          frame.instanceId: frame,
          for (var index = 0; index < 12; index++)
            'backpack-filler-$index': StreetScrapObject(
              instanceId: 'backpack-filler-$index',
              itemId: 'wood.chip',
              source: 'found:crate-tutorial',
              quality: 55,
              traits: const {},
              toolDurability: null,
              footprint: _catalog.footprints['wood.chip']!,
            ),
        },
        placements: {
          for (var index = 0; index < 12; index++)
            'backpack-filler-$index': StreetScrapPlacement(
              instanceId: 'backpack-filler-$index',
              gridId: 'backpack',
              x: index % 4,
              y: index ~/ 4,
              rotation: false,
            ),
        },
        storage: {
          streetScrapTutorialCrateStorageId: [frame.instanceId],
        },
      );
      expect(
        () => inventory.withdraw(
          frame.instanceId,
          streetScrapTutorialCrateStorageId,
          'backpack',
          0,
          3,
        ),
        throwsFormatException,
      );
      await session.apply(
        commandId: 'prepare-crate-workboard-withdraw',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 3,
            'inventory': inventory.toJson(),
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.04.stored': true,
            },
            'storageFurniture': {
              streetScrapTutorialCrateStorageId: {
                'capacity': 12,
                'contents': [frame.instanceId],
              },
            },
          },
        ),
      );
      await withdrawStreetScrapFromTutorialCrate(
        session: session,
        commandId: 'withdraw-frame-to-board',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        instanceId: frame.instanceId,
        gridId: 'board',
      );
      final restored = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(restored.placements[frame.instanceId]!.gridId, 'board');
      expect(restored.objects[frame.instanceId]!.quality, 61);
      expect(restored.objects[frame.instanceId]!.traits, const {
        'joint_reinforced': true,
      });
      expect(session.snapshot.state['chapter'], 4);
      await session.close();
    },
  );

  testWidgets('chapter-three crate storage panel follows the English locale', (
    tester,
  ) async {
    final session = await _session('crate-storage-localization');
    await session.apply(
      commandId: 'place-crate-for-localization',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.03': true,
            'q3.04.placed': true,
          },
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Woodworking Bench'), findsOneWidget);
    expect(
      find.text(
        'The crate recipe supply tops up 4 boards, 2 nail bundles, and 1 unit of recycled adhesive after subtracting materials you already own.',
      ),
      findsOneWidget,
    );
    expect(find.text('Claim crate materials'), findsOneWidget);
    expect(
      find.text('Wooden crate placed; 0 items stored (12-cell capacity).'),
      findsOneWidget,
    );
    expect(find.text('Store one item'), findsOneWidget);
    expect(find.text('Withdraw one item'), findsOneWidget);
    await session.close();
  });

  test('q4.01 kit is one-time and provides a reusable filter cloth', () async {
    final session = await _session('water-filter-kit');
    await session.apply(
      commandId: 'complete-chapter-three',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q2.03': true, 'q3.04': true},
        },
      ),
    );
    final result = await claimStreetScrapWaterFilterKit(
      session: session,
      commandId: 'claim-filter-kit',
      expectedRevision: 2,
      catalog: _catalog,
      grids: _grids,
    );
    expect(result.revision, 3);
    final inventory = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(inventory.objects['q401-filter-cloth']!.toolDurability, 20);
    expect(
      inventory.objects['q401-water-bottle']!.containerState['contentItemId'],
      'water.turbid',
    );
    expect(inventory.objects.values.map((item) => item.itemId).toSet(), {
      'container.clean',
      'material.charcoal',
      'material.filter_cloth',
    });
    await expectLater(
      claimStreetScrapWaterFilterKit(
        session: session,
        commandId: 'claim-filter-kit-again',
        expectedRevision: 3,
        catalog: _catalog,
        grids: _grids,
      ),
      throwsA(isA<StateError>()),
    );
    await session.close();
  });

  test('q4.01 reports backpack space shortage without partial claim', () async {
    final session = await _session('water-filter-kit-no-space');
    var inventory = _catalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 13; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'space-filler-$index',
          itemId: 'paper.scrap',
          source: 'test',
          quality: 30,
          traits: const {},
        ),
        'backpack',
      );
    }
    await session.apply(
      commandId: 'fill-backpack',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q3.04': true},
          'inventory': inventory.toJson(),
        },
      ),
    );

    await expectLater(
      claimStreetScrapWaterFilterKit(
        session: session,
        commandId: 'claim-filter-kit-no-space',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'q4.01InsufficientBackpackSpace',
        ),
      ),
    );
    expect(session.snapshot.revision, 2);
    expect(
      session.snapshot.state['inventory'],
      inventory.toJson(),
      reason: 'a failed claim must not persist a partially placed kit',
    );
    await session.close();
  });

  test(
    'q4.01 reports missing content without partially claiming supplies',
    () async {
      final session = await _session('water-filter-kit-missing-content');
      await session.apply(
        commandId: 'complete-chapter-three',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'tutorialTasks': {'q3.04': true},
          },
        ),
      );
      final incompleteCatalog = StreetScrapInventoryCatalog(
        footprints: Map<String, StreetScrapFootprint>.of(_catalog.footprints)
          ..remove('material.filter_cloth'),
        packingRules: const {},
      );
      final inventoryBefore = session.snapshot.state['inventory'];

      await expectLater(
        claimStreetScrapWaterFilterKit(
          session: session,
          commandId: 'claim-filter-kit-missing-content',
          expectedRevision: 2,
          catalog: incompleteCatalog,
          grids: _grids,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'q4.01ContentUnavailable',
          ),
        ),
      );
      expect(session.snapshot.revision, 2);
      expect(session.snapshot.state['inventory'], inventoryBefore);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.01.kitClaimed'],
        isNot(true),
      );
      await session.close();
    },
  );

  test(
    'q4.02 kit gives clean food, fuel, boiled water and one empty meal box',
    () async {
      final session = await _session('basic-soup-kit');
      await session.apply(
        commandId: 'unlock-basic-soup-kit',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'tutorialTasks': {'q3.04': true, 'q4.01': true},
          },
        ),
      );
      final result = await claimStreetScrapBasicSoupKit(
        session: session,
        commandId: 'claim-basic-soup-kit',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );
      expect(result.revision, 3);
      final inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        inventory.objects.keys,
        containsAll([
          'q402-food',
          'q402-fuel',
          'q402-water-bottle',
          'q402-meal-box',
        ]),
      );
      expect(
        inventory.objects['q402-water-bottle']!.containerState['contentItemId'],
        'water.boiled',
      );
      expect(
        inventory.objects['q402-meal-box']!.containerState['cleanliness'],
        'clean',
      );
      await session.close();
    },
  );

  test(
    'q4.02 kit places overflow on the work board when the backpack is full',
    () async {
      final session = await _session('basic-soup-kit-backpack-full');
      var inventory = _catalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 16; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'soup-kit-backpack-chip-$index',
            itemId: 'wood.chip',
            source: 'test',
            quality: 55,
            traits: const {},
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'soup-kit-backpack-full-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'tutorialTasks': {'q4.01': true},
            'inventory': inventory.toJson(),
          },
        ),
      );

      await claimStreetScrapBasicSoupKit(
        session: session,
        commandId: 'soup-kit-backpack-full-claim',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
      );

      final saved = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      for (final id in const [
        'q402-food',
        'q402-fuel',
        'q402-water-bottle',
        'q402-meal-box',
      ]) {
        expect(saved.placements[id]?.gridId, 'board');
        expect(saved.objects[id]?.source, 'tutorial:q4.02-soup-kit');
      }
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.02.kitClaimed'],
        isTrue,
      );
      expect(saved.objects.keys, contains('soup-kit-backpack-chip-15'));
      await session.close();
    },
  );

  test('q4.02 kit does not partially grant when both grids are full', () async {
    final session = await _session('basic-soup-kit-no-space');
    var inventory = _catalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 16; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'soup-kit-full-backpack-$index',
          itemId: 'wood.chip',
          source: 'test',
          quality: 55,
          traits: const {},
        ),
        'backpack',
      );
    }
    for (var index = 0; index < 36; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'soup-kit-full-board-$index',
          itemId: 'wood.chip',
          source: 'test',
          quality: 55,
          traits: const {},
        ),
        'board',
      );
    }
    await session.apply(
      commandId: 'soup-kit-no-space-setup',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q2.03': true, 'q3.04': true, 'q4.01': true},
          'inventory': inventory.toJson(),
        },
      ),
    );
    final revisionBeforeClaim = session.snapshot.revision;
    final inventoryBeforeClaim = Map<String, Object?>.from(
      session.snapshot.state['inventory']! as Map,
    );

    await expectLater(
      claimStreetScrapBasicSoupKit(
        session: session,
        commandId: 'soup-kit-no-space-claim',
        expectedRevision: revisionBeforeClaim,
        catalog: _catalog,
        grids: _grids,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'insufficientInventorySpace',
        ),
      ),
    );

    expect(session.snapshot.revision, revisionBeforeClaim);
    expect(session.snapshot.state['inventory'], inventoryBeforeClaim);
    final tasks = session.snapshot.state['tutorialTasks']! as Map;
    expect(tasks['q4.02.kitClaimed'], isNull);
    await session.close();
  });

  test(
    'chapter-four water, cooking, and meal delivery flow in one save',
    () async {
      final session = await _session('chapter-four-sequential-flow');
      await session.apply(
        commandId: 'flow-enter-chapter-four',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.04': true,
            },
          },
        ),
      );
      await claimStreetScrapWaterFilterKit(
        session: session,
        commandId: 'flow-claim-filter-kit',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );
      final waterBottleBefore = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final filterPlacement =
          waterBottleBefore.placements['q401-water-bottle']!;
      final filterRecipe = StreetScrapRecipe(
        id: 'ss.recipe.filter_turbid',
        phase: 4,
        station: 'kitchen',
        operationId: 'filter',
        durationSeconds: 10,
        instructions:
            'Filter turbid water through the cloth and charcoal layers.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
            StreetScrapRecipeInput(itemId: 'material.charcoal', quantity: 1),
          ],
        ],
        reusableTools: const ['material.filter_cloth'],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: ['container.clean'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome:
            'A miss keeps the turbid water and wears the filter cloth.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        stateEffect: const {
          'type': 'transformContainerContent',
          'containerItemId': 'container.clean',
          'fromContentItemId': 'water.turbid',
          'toContentItemId': 'water.filtered',
          'contentTraitResolution': {
            'precise': {'clear': true},
          },
        },
        manualCheckpoints: [
          for (var step = 0; step < 3; step++)
            StreetScrapManualCheckpoint(
              prompt: 'Check filter layer ${step + 1}',
              options: ['Follow the layer order', 'Reverse the order'],
              correctOption: 0,
            ),
        ],
      );
      const filterOperationId = 'flow-filter-turbid-water';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _catalog,
        recipe: filterRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: const ['q401-water-bottle', 'q401-charcoal'],
        toolInstanceIds: const ['q401-filter-cloth'],
        operationId: filterOperationId,
        commandId: 'flow-begin-filtration',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.13',
      );
      for (var step = 0; step < 3; step++) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _catalog,
          recipe: filterRecipe,
          grids: _grids,
          operationId: filterOperationId,
          optionIndex: 0,
          expectedRevision: session.snapshot.revision,
        );
      }
      var afterFiltration = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.01'],
        isTrue,
      );
      expect(
        afterFiltration
            .objects['q401-water-bottle']!
            .containerState['contentItemId'],
        'water.filtered',
      );
      expect(
        afterFiltration.objects['q401-water-bottle']!.instanceId,
        'q401-water-bottle',
      );
      expect(afterFiltration.objects['q401-filter-cloth']!.toolDurability, 19);
      expect(afterFiltration.objects.containsKey('q401-charcoal'), isFalse);
      final filteredBottlePlacement =
          afterFiltration.placements['q401-water-bottle']!;
      expect(filteredBottlePlacement.gridId, filterPlacement.gridId);
      expect(filteredBottlePlacement.x, filterPlacement.x);
      expect(filteredBottlePlacement.y, filterPlacement.y);
      expect(filteredBottlePlacement.rotation, filterPlacement.rotation);

      await claimStreetScrapBasicSoupKit(
        session: session,
        commandId: 'flow-claim-soup-kit',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );
      afterFiltration = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final waterPlacement = afterFiltration.placements['q402-water-bottle']!;
      final boxPlacement = afterFiltration.placements['q402-meal-box']!;
      final soupRecipe = StreetScrapRecipe(
        id: 'ss.recipe.soup_basic',
        phase: 4,
        station: 'kitchen',
        operationId: 'cook',
        durationSeconds: 12,
        instructions: 'Control the heat and fill the selected meal box.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 1),
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
            StreetScrapRecipeInput(itemId: 'container.meal_box', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['food.cleaned'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: 'The original meal box receives soup or a failed meal.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        stateEffect: const {
          'type': 'transformContainers',
          'containers': [
            {
              'containerItemId': 'container.clean',
              'requiredContentItemId': 'water.boiled',
              'successContentItemId': null,
              'failureContentItemId': null,
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
            },
            {
              'containerItemId': 'container.meal_box',
              'optional': true,
              'requiredContentItemId': null,
              'successContentItemId': 'meal.soup_basic',
              'failureContentItemId': 'meal.failed',
              'successCleanliness': 'clean',
              'failureCleanliness': 'clean',
            },
          ],
        },
        manualCheckpoints: [
          for (var step = 0; step < 3; step++)
            StreetScrapManualCheckpoint(
              prompt: 'Control cooking step ${step + 1}',
              options: ['Follow the heat cue', 'Ignore the heat cue'],
              correctOption: 0,
            ),
        ],
      );
      const soupOperationId = 'flow-cook-basic-soup';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _catalog,
        recipe: soupRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: const [
          'q402-food',
          'q402-water-bottle',
          'q402-fuel',
          'q402-meal-box',
        ],
        toolInstanceIds: const [],
        operationId: soupOperationId,
        commandId: 'flow-begin-soup',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.13',
      );
      for (var step = 0; step < 3; step++) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _catalog,
          recipe: soupRecipe,
          grids: _grids,
          operationId: soupOperationId,
          optionIndex: 0,
          expectedRevision: session.snapshot.revision,
        );
      }
      var afterCooking = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.02'],
        isTrue,
      );
      expect(afterCooking.objects.containsKey('q402-food'), isFalse);
      expect(afterCooking.objects.containsKey('q402-fuel'), isFalse);
      expect(
        afterCooking
            .objects['q402-water-bottle']!
            .containerState['contentItemId'],
        isNull,
      );
      expect(
        afterCooking.objects['q402-meal-box']!.containerState['contentItemId'],
        'meal.soup_basic',
      );
      final cookedBottlePlacement =
          afterCooking.placements['q402-water-bottle']!;
      final cookedBoxPlacement = afterCooking.placements['q402-meal-box']!;
      expect(cookedBottlePlacement.gridId, waterPlacement.gridId);
      expect(cookedBottlePlacement.x, waterPlacement.x);
      expect(cookedBottlePlacement.y, waterPlacement.y);
      expect(cookedBottlePlacement.rotation, waterPlacement.rotation);
      expect(cookedBoxPlacement.gridId, boxPlacement.gridId);
      expect(cookedBoxPlacement.x, boxPlacement.x);
      expect(cookedBoxPlacement.y, boxPlacement.y);
      expect(cookedBoxPlacement.rotation, boxPlacement.rotation);

      final delivery = await deliverStreetScrapMeal(
        session: session,
        commandId: 'flow-deliver-soup',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        mealBoxInstanceId: 'q402-meal-box',
      );
      expect((delivery.result! as Map)['exchangeTickets'], 4);
      afterCooking = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final returnedMealBox = afterCooking.objects['q402-meal-box']!;
      expect(returnedMealBox.containerState['contentItemId'], isNull);
      expect(
        returnedMealBox.containerState['lastContentItemId'],
        'meal.soup_basic',
      );
      expect(returnedMealBox.containerState['cleanliness'], 'soiled');
      final returnedBoxPlacement = afterCooking.placements['q402-meal-box']!;
      expect(returnedBoxPlacement.gridId, boxPlacement.gridId);
      expect(returnedBoxPlacement.x, boxPlacement.x);
      expect(returnedBoxPlacement.y, boxPlacement.y);
      expect(returnedBoxPlacement.rotation, boxPlacement.rotation);
      expect(session.snapshot.state['exchangeTickets'], 4);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.03'],
        isTrue,
      );
      expect(session.snapshot.state['craftOperation'], isNull);
      await session.close();
    },
  );

  test('alternate chapter-four soups can be cooked and delivered', () async {
    const routes =
        <
          ({
            String recipeId,
            String ingredientId,
            String mealId,
            List<int> answers,
          })
        >[
          (
            recipeId: 'ss.recipe.soup_vegetable',
            ingredientId: 'food.cleaned',
            mealId: 'meal.soup_vegetable',
            answers: [2, 1, 0],
          ),
          (
            recipeId: 'ss.recipe.soup_fish',
            ingredientId: 'fish.meat',
            mealId: 'meal.soup_fish',
            answers: [0, 1, 1],
          ),
        ];

    for (final route in routes) {
      final session = await _session('alternate-soup-${route.mealId}');
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: '${route.mealId}-ingredient-0',
              itemId: route.ingredientId,
              source: 'test:chapter-four',
              quality: 58,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: '${route.mealId}-ingredient-1',
              itemId: route.ingredientId,
              source: 'test:chapter-four',
              quality: 58,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: '${route.mealId}-bottle',
              itemId: 'container.clean',
              source: 'test:chapter-four',
              quality: 58,
              traits: const {},
              containerState: const {
                'contentItemId': 'water.boiled',
                'contentQuality': 60,
                'cleanliness': 'utility',
              },
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: '${route.mealId}-fuel',
              itemId: 'fuel.dry',
              source: 'test:chapter-four',
              quality: 58,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: '${route.mealId}-box',
              itemId: 'container.meal_box',
              source: 'test:chapter-four',
              quality: 58,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'setup-${route.mealId}',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.04': true,
              'q4.01': true,
            },
            'inventory': inventory.toJson(),
          },
        ),
      );

      final ingredientCount = 2;
      final recipe = StreetScrapRecipe(
        id: route.recipeId,
        phase: 4,
        station: 'kitchen',
        operationId: 'cook',
        durationSeconds: 12,
        instructions: 'Use the canonical alternate soup route.',
        inputGroups: [
          [
            StreetScrapRecipeInput(
              itemId: route.ingredientId,
              quantity: ingredientCount,
            ),
            const StreetScrapRecipeInput(
              itemId: 'container.clean',
              quantity: 1,
            ),
            const StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
            const StreetScrapRecipeInput(
              itemId: 'container.meal_box',
              quantity: 1,
            ),
          ],
        ],
        reusableTools: const [],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: [route.ingredientId],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: 'Soup remains in the selected original meal box.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        stateEffect: {
          'type': 'transformContainers',
          'containers': [
            {
              'containerItemId': 'container.clean',
              'requiredContentItemId': 'water.boiled',
              'successContentItemId': null,
              'failureContentItemId': null,
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
            },
            {
              'containerItemId': 'container.meal_box',
              'optional': true,
              'requiredContentItemId': null,
              'successContentItemId': route.mealId,
              'failureContentItemId': 'meal.failed',
              'successCleanliness': 'clean',
              'failureCleanliness': 'clean',
            },
          ],
        },
        manualCheckpoints: [
          for (var index = 0; index < route.answers.length; index++)
            StreetScrapManualCheckpoint(
              prompt: 'Canonical cooking checkpoint ${index + 1}',
              options: ['Option 1', 'Option 2', 'Option 3'],
              correctOption: route.answers[index],
            ),
        ],
      );
      final ingredientIds = [
        '${route.mealId}-ingredient-0',
        '${route.mealId}-ingredient-1',
      ];
      final operationId = 'cook-${route.mealId}';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: [
          ...ingredientIds,
          '${route.mealId}-bottle',
          '${route.mealId}-fuel',
          '${route.mealId}-box',
        ],
        toolInstanceIds: const [],
        operationId: operationId,
        commandId: 'begin-${route.mealId}',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.13',
      );
      StreetScrapCommandResult? cookResult;
      for (final answer in route.answers) {
        cookResult = await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _catalog,
          recipe: recipe,
          grids: _grids,
          operationId: operationId,
          optionIndex: answer,
          expectedRevision: session.snapshot.revision,
        );
      }
      expect((cookResult!.result! as Map)['succeeded'], isTrue);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.02'],
        isTrue,
      );
      var cooked = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        cooked.objects['${route.mealId}-box']!.containerState['contentItemId'],
        route.mealId,
      );
      expect(
        cooked
            .objects['${route.mealId}-bottle']!
            .containerState['contentItemId'],
        isNull,
      );
      expect(cooked.objects.containsKey('${route.mealId}-fuel'), isFalse);
      expect(cooked.objects.containsKey(ingredientIds[0]), isFalse);
      expect(cooked.objects.containsKey(ingredientIds[1]), isFalse);

      final delivery = await deliverStreetScrapMeal(
        session: session,
        commandId: 'deliver-${route.mealId}',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        mealBoxInstanceId: '${route.mealId}-box',
      );
      expect((delivery.result! as Map)['exchangeTickets'], 4);
      cooked = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final returnedBox = cooked.objects['${route.mealId}-box']!;
      expect(returnedBox.containerState['lastContentItemId'], route.mealId);
      expect(returnedBox.containerState['cleanliness'], 'soiled');
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.03'],
        isTrue,
      );
      await session.close();
    }
  });

  testWidgets('chapter four exposes the filtration lesson supply in the panel', (
    tester,
  ) async {
    final session = await _session('water-filter-panel');
    await session.apply(
      commandId: 'enter-chapter-four',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q2.03': true, 'q3.04': true},
        },
      ),
    );
    final playedCues = <StreetScrapAudioCue>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
              onSound: playedCues.add,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Water Treatment Lesson'), findsOneWidget);
    expect(
      find.text(
        'Success yields filtered water. On a miss, the turbid water remains, but one charcoal and filter cloth are consumed; you can try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reusable Water Bottles'), findsOneWidget);
    await tester.tap(find.text('Claim filtration materials'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Filtration materials are in your backpack. Open Recipes and choose “Filter Turbid Water.”',
      ),
      findsOneWidget,
    );
    expect(playedCues, [StreetScrapAudioCue.tap]);
    await session.close();
  });

  testWidgets('filtration kit space error tells player what to free', (
    tester,
  ) async {
    final session = await _session('water-filter-panel-no-space');
    var inventory = _catalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 13; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'water-space-filler-$index',
          itemId: 'paper.scrap',
          source: 'test',
          quality: 30,
          traits: const {},
        ),
        'backpack',
      );
    }
    await session.apply(
      commandId: 'fill-backpack-for-water-kit',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q2.03': true, 'q3.04': true},
          'inventory': inventory.toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Water Treatment Lesson'), findsOneWidget);
    expect(find.text('Claim filtration materials'), findsOneWidget);
    await tester.tap(find.text('Claim filtration materials'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Free 4 backpack slots'), findsOneWidget);
    expect(session.snapshot.revision, 2);
    expect(session.snapshot.state['inventory'], inventory.toJson());
    await session.close();
  });

  testWidgets(
    'chapter-five fixed mineral spring appears only with its resource installed',
    (tester) async {
      final session = await _session('mineral-spring-panel', chapterFive: true);
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'panel-mineral-bottle',
              itemId: 'container.clean',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'advance-mineral-spring-panel',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 5,
            'tutorialTasks': {
              'q2.03': true,
              'q3.04': true,
              'q5.01': true,
              'q5.02.shelterPlaced': true,
              'q5.02.chestPlaced': true,
            },
            'inventory': inventory.toJson(),
          },
        ),
      );
      expect(session.snapshot.state['chapter'], 5);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.04'],
        isTrue,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StreetScrapLocalizationsScope(
            locale: 'en',
            child: Scaffold(
              body: StreetScrapWoodworkingPanel(
                session: session,
                catalog: _catalog,
                onOpenRecipes: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      final mineralSourceLabel =
          'New Neighborhood Spring (mineral water · costs 3 stamina · meal quality +3)';
      expect(find.text('Reusable Water Bottles'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Filling costs 2 stamina. Pouring preserves water quality and contamination history. Cleaning uses filtered water that does not need boiling.',
        ),
        findsOneWidget,
      );
      expect(find.text('Fill · 2'), findsOneWidget);
      expect(find.text('Keep quality'), findsOneWidget);
      expect(find.text('Wash · filtered'), findsOneWidget);
      expect(find.text('q5.02 Stable Living Goal'), findsOneWidget);
      expect(find.text('Ordinary cycle orders: 0/5'), findsOneWidget);
      expect(
        find.text(
          'The folding awning and reinforced chest are placed; awning support bonus: +0%.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'The reinforced chest stores 0 items; capacity is 20 cells. Withdraw items before crafting.',
        ),
        findsOneWidget,
      );
      expect(find.text('Store one item'), findsOneWidget);
      expect(find.text('Withdraw one item'), findsOneWidget);
      expect(
        find.byKey(const Key('street-scrap-water-vessel')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('street-scrap-water-source')),
      );
      await tester.tap(find.byKey(const Key('street-scrap-water-source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mineralSourceLabel));
      await tester.pumpAndSettle();
      expect(find.text(mineralSourceLabel), findsOneWidget);
      await session.close();

      final withoutPack = await _session('mineral-spring-panel-no-pack');
      final noPackInventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'no-pack-mineral-bottle',
              itemId: 'container.clean',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await withoutPack.apply(
        commandId: 'advance-mineral-spring-panel-no-pack',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 5,
            'tutorialTasks': {'q2.03': true, 'q3.04': true, 'q5.01': true},
            'inventory': noPackInventory.toJson(),
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: withoutPack,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('street-scrap-water-source')));
      await tester.pumpAndSettle();
      expect(find.text(mineralSourceLabel), findsNothing);
      await withoutPack.close();
    },
  );

  testWidgets('completed filtration opens the basic soup kit in the panel', (
    tester,
  ) async {
    final session = await _session('soup-kit-panel');
    var inventory = _catalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 16; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'soup-kit-panel-chip-$index',
          itemId: 'wood.chip',
          source: 'test',
          quality: 55,
          traits: const {},
        ),
        'backpack',
      );
    }
    await session.apply(
      commandId: 'enter-soup-stage',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q2.03': true, 'q3.04': true, 'q4.01': true},
          'inventory': inventory.toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Filtered'), findsOneWidget);
    expect(
      find.text(
        'q4.01 complete: you obtained filtered water and can continue to the cooking lesson.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Basic soup lesson supplies: cleaned ingredients, dry fuel, the original bottle filled with boiled water, and an empty meal box.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Claim basic soup materials'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Materials are ready. Open Recipes, choose “Basic Soup,” and control the heat manually.',
      ),
      findsOneWidget,
    );
    final claimedSoupKit = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    for (final id in const [
      'q402-food',
      'q402-fuel',
      'q402-water-bottle',
      'q402-meal-box',
    ]) {
      expect(claimedSoupKit.placements[id]?.gridId, 'board');
    }

    await session.apply(
      commandId: 'complete-soup-localization',
      expectedRevision: 3,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q4.02': true,
          },
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Cooked'), findsOneWidget);
    expect(
      find.text(
        'q4.02 complete: the meal is in the original meal box; the bottle is retained and empty.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'Self-supply: the quality-based stamina recovery is shown before eating. At full stamina, the meal is not consumed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Review and eat the meal'), findsOneWidget);
    expect(
      find.text('Deliver a normal soup order (+4 vouchers)'),
      findsOneWidget,
    );

    await session.apply(
      commandId: 'complete-meal-choice-localization',
      expectedRevision: 4,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q4.03': true,
          },
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Meal used'), findsOneWidget);
    expect(
      find.text(
        'Success yields filtered water. On a miss, the turbid water remains, but one charcoal and filter cloth are consumed; you can try again.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'q4.03 complete: you chose to eat or deliver the meal. The meal box is retained for washing.',
      ),
      findsNothing,
    );
    await session.close();
  });

  testWidgets('full soup-kit grids show the make-room message without a grant', (
    tester,
  ) async {
    final session = await _session('soup-kit-panel-no-space');
    var inventory = _catalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 16; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'soup-panel-bag-$index',
          itemId: 'wood.chip',
          source: 'test',
          quality: 55,
          traits: const {},
        ),
        'backpack',
      );
    }
    for (var index = 0; index < 36; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _catalog.createObject(
          instanceId: 'soup-panel-board-$index',
          itemId: 'wood.chip',
          source: 'test',
          quality: 55,
          traits: const {},
        ),
        'board',
      );
    }
    await session.apply(
      commandId: 'soup-kit-panel-no-space-setup',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {'q2.03': true, 'q3.04': true, 'q4.01': true},
          'inventory': inventory.toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Claim basic soup materials'));
    await tester.pumpAndSettle();

    final panelText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join('\n');
    expect(
      find.text(
        'Action did not complete: There is not enough room on the workboard or in the backpack. Make room, then claim the lesson supplies.',
      ),
      findsOneWidget,
      reason: panelText,
    );
    expect(session.snapshot.revision, 2);
    expect(
      (session.snapshot.state['tutorialTasks']! as Map)['q4.02.kitClaimed'],
      isNull,
    );
    final saved = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(saved.objects.keys, isNot(contains('q402-food')));
    await session.close();
  });

  testWidgets('meal confirmation dialogs follow the English locale', (
    tester,
  ) async {
    final session = await _session('meal-confirmation-localization');
    final inventory = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'localized-confirmation-meal-box',
            itemId: 'container.meal_box',
            source: 'tutorial:q4.02-soup-kit',
            quality: 55,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_basic',
              'contentQuality': 55,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'seed-meal-confirmation-localization',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.04': true,
            'q4.02': true,
          },
          'stamina': 55,
          'inventory': inventory.toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapWoodworkingPanel(
              session: session,
              catalog: _catalog,
              onOpenRecipes: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    final revisionBeforeDialogs = session.snapshot.revision;
    final eatButton = find.text('Review and eat the meal');
    await tester.ensureVisible(eatButton);
    await tester.tap(eatButton);
    await tester.pumpAndSettle();
    expect(find.text('Eat the meal'), findsOneWidget);
    expect(
      find.text(
        'This meal can restore 20 stamina; you will recover 5 now. 15 stamina will exceed the maximum.\n\nEating consumes the meal. The original box is kept and must be washed.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(session.snapshot.revision, revisionBeforeDialogs);

    final deliveryButton = find.text(
      'Deliver a normal soup order (+4 vouchers)',
    );
    await tester.ensureVisible(deliveryButton);
    await tester.tap(deliveryButton);
    await tester.pumpAndSettle();
    expect(find.text('Deliver meal order'), findsOneWidget);
    expect(
      find.text(
        'Deliver one normal soup for 4 vouchers. The meal is handed over; the original box is returned and must be washed. This chapter order can only be completed once.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep meal'));
    await tester.pumpAndSettle();
    expect(session.snapshot.revision, revisionBeforeDialogs);
    await session.close();
  });

  testWidgets('confirming meal actions commits and returns the same box', (
    tester,
  ) async {
    Future<StreetScrapSession> prepareMealSession(
      String key, {
      required String mealBoxId,
      required int stamina,
    }) async {
      final session = await _session(key);
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: mealBoxId,
              itemId: 'container.meal_box',
              source: 'tutorial:q4.02-soup-kit',
              quality: 55,
              traits: const {},
              containerState: const {
                'contentItemId': 'meal.soup_basic',
                'contentQuality': 55,
                'cleanliness': 'clean',
              },
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'seed-$key',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 4,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.04': true,
              'q4.02': true,
            },
            'stamina': stamina,
            'inventory': inventory.toJson(),
          },
        ),
      );
      return session;
    }

    Widget panel(StreetScrapSession session, {bool withOrderCatalog = false}) =>
        MaterialApp(
          home: StreetScrapLocalizationsScope(
            locale: 'en',
            child: Scaffold(
              body: StreetScrapWoodworkingPanel(
                session: session,
                catalog: _catalog,
                orderCatalog: withOrderCatalog ? _mealOrderCatalog : null,
                onOpenRecipes: () {},
                onChanged: () {},
              ),
            ),
          ),
        );

    final eatingSession = await prepareMealSession(
      'confirmed-eat-meal',
      mealBoxId: 'confirmed-eat-box',
      stamina: 55,
    );
    await tester.pumpWidget(panel(eatingSession));
    await tester.ensureVisible(find.text('Review and eat the meal'));
    await tester.tap(find.text('Review and eat the meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eat meal'));
    await tester.pumpAndSettle();
    expect(eatingSession.snapshot.state['stamina'], 60);
    expect(
      (eatingSession.snapshot.state['tutorialTasks']! as Map)['q4.03'],
      isTrue,
    );
    var eatingInventory = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        eatingSession.snapshot.state['inventory']! as Map,
      ),
    );
    final eatenBox = eatingInventory.objects['confirmed-eat-box']!;
    expect(eatenBox.containerState['contentItemId'], isNull);
    expect(eatenBox.containerState['cleanliness'], 'soiled');
    expect(eatingInventory.placements['confirmed-eat-box']!.gridId, 'backpack');
    await eatingSession.close();

    final deliverySession = await prepareMealSession(
      'confirmed-deliver-meal',
      mealBoxId: 'confirmed-delivery-box',
      stamina: 20,
    );
    await tester.pumpWidget(panel(deliverySession, withOrderCatalog: true));
    await tester.ensureVisible(
      find.text('Deliver a normal soup order (+4 vouchers)'),
    );
    await tester.tap(find.text('Deliver a normal soup order (+4 vouchers)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();
    expect(deliverySession.snapshot.state['exchangeTickets'], 4);
    expect(
      (deliverySession.snapshot.state['tutorialTasks']! as Map)['q4.03'],
      isTrue,
    );
    final deliveredInventory = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        deliverySession.snapshot.state['inventory']! as Map,
      ),
    );
    final returnedBox = deliveredInventory.objects['confirmed-delivery-box']!;
    expect(returnedBox.containerState['contentItemId'], isNull);
    expect(returnedBox.containerState['lastContentItemId'], 'meal.soup_basic');
    expect(returnedBox.containerState['cleanliness'], 'soiled');
    expect(
      deliveredInventory.placements['confirmed-delivery-box']!.gridId,
      'backpack',
    );
    await deliverySession.close();
  });

  testWidgets('invalid meal actions show localized errors without mutation', (
    tester,
  ) async {
    final session = await _session('meal-error-localization');
    await session.apply(
      commandId: 'seed-meal-error-stage',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 4,
          'tutorialTasks': {
            ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
            'q3.04': true,
            'q4.02': true,
          },
          'stamina': 30,
        },
      ),
    );
    Widget panel() => MaterialApp(
      home: StreetScrapLocalizationsScope(
        locale: 'en',
        child: Scaffold(
          body: StreetScrapWoodworkingPanel(
            session: session,
            catalog: _catalog,
            onOpenRecipes: () {},
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(panel());
    final revisionBeforeMissingMeal = session.snapshot.revision;
    final eatButton = find.text('Review and eat the meal');
    await tester.ensureVisible(eatButton);
    await tester.tap(eatButton);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Action did not complete: There is no meal box containing food in your backpack.',
      ),
      findsOneWidget,
    );
    expect(session.snapshot.revision, revisionBeforeMissingMeal);

    final failedMealInventory = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'failed-meal-error-box',
            itemId: 'container.meal_box',
            source: 'test:failed-soup',
            quality: 30,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.failed',
              'contentQuality': 30,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'seed-undeliverable-meal',
      expectedRevision: revisionBeforeMissingMeal,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'inventory': failedMealInventory.toJson()},
      ),
    );
    await tester.pumpWidget(panel());
    final revisionBeforeDelivery = session.snapshot.revision;
    final deliveryButton = find.text(
      'Deliver a normal soup order (+4 vouchers)',
    );
    await tester.ensureVisible(deliveryButton);
    await tester.tap(deliveryButton);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Action did not complete: There is no normal soup to deliver. Failed meals cannot fulfill this order.',
      ),
      findsOneWidget,
    );
    expect(session.snapshot.revision, revisionBeforeDelivery);
    final unchangedInventory = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(
      unchangedInventory
          .objects['failed-meal-error-box']!
          .containerState['contentItemId'],
      'meal.failed',
    );
    await session.close();
  });

  test(
    'q3.05 upgrades the same bag and expands backpack space after a miss',
    () async {
      final session = await _session('bag-upgrade');
      var inventory = _catalog.emptyInventory(grids: _grids);
      final inputIds = <String>[];
      for (final entry in [
        ('patch-0', 'cloth.patchwork'),
        ('patch-1', 'cloth.patchwork'),
        ('patch-2', 'cloth.patchwork'),
        ('binding-0', 'cloth.binding'),
        ('binding-1', 'cloth.binding'),
        ('thread-0', 'cloth.thread_spool'),
        ('thread-1', 'cloth.thread_spool'),
      ]) {
        inputIds.add(entry.$1);
        inventory = inventory.addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: entry.$1,
            itemId: entry.$2,
            source: 'found:bag-upgrade-test',
            quality: 60,
            traits: const {},
            toolDurability: null,
            footprint: _catalog.footprints[entry.$2]!,
          ),
          'backpack',
        );
      }
      inventory = inventory.addAndPlaceFirstFit(
        StreetScrapObject(
          instanceId: 'upgrade-needle',
          itemId: 'tool.needle',
          source: 'starter',
          quality: 50,
          traits: const {},
          toolDurability: 5,
          footprint: _catalog.footprints['tool.needle']!,
        ),
        'backpack',
      );
      inventory = inventory.addAndPlaceFirstFit(
        StreetScrapObject(
          instanceId: 'kept-item',
          itemId: 'wood.chip',
          source: 'found:untouched',
          quality: 72,
          traits: const {'dry': true},
          toolDurability: null,
          footprint: _catalog.footprints['wood.chip']!,
        ),
        'backpack',
      );
      await session.apply(
        commandId: 'prepare-bag-upgrade',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {
              ...Map<String, Object?>.from(state['tutorialTasks']! as Map),
              'q3.04': true,
            },
            'bagEquipment': {
              'instanceId': 'original-bag-identity',
              'itemId': 'bag.basic',
              'quality': 55,
            },
            'backpackCapacity': 16,
            'inventory': inventory.toJson(),
          },
        ),
      );
      final recipe = StreetScrapRecipe(
        id: 'ss.recipe.upgrade_bag',
        phase: 3,
        station: 'workbench',
        operationId: 'sew',
        durationSeconds: 10,
        instructions: '縫補受力接縫',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'cloth.patchwork', quantity: 3),
            StreetScrapRecipeInput(itemId: 'cloth.binding', quantity: 2),
            StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 2),
          ],
        ],
        reusableTools: const ['tool.needle'],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['cloth.patchwork'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: '失手仍完成升級，不減格',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        stateEffect: const {
          'type': 'upgradeBackpack',
          'fromItemId': 'bag.basic',
          'toItemId': 'bag.reinforced',
          'capacity': 24,
        },
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: '拼接',
            options: ['重疊接縫', '散開'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: '綁帶',
            options: ['受力點', '任意處'],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: '完成',
            options: ['保留背包擴格', '丟掉舊包'],
            correctOption: 0,
          ),
        ],
      );
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: inputIds,
        toolInstanceIds: const ['upgrade-needle'],
        operationId: 'upgrade-existing-bag',
        commandId: 'begin-bag-upgrade',
        expectedRevision: 2,
        contentVersion: '0.1.13',
      );
      for (var index = 0; index < 3; index++) {
        final result = await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _catalog,
          recipe: recipe,
          grids: _grids,
          operationId: 'upgrade-existing-bag',
          optionIndex: 1,
          expectedRevision: session.snapshot.revision,
        );
        if (index < 2) expect(result, isNull);
        if (index == 2) expect(result, isNotNull);
      }
      expect(session.snapshot.state['backpackCapacity'], 24);
      expect(
        streetScrapGridSpecsForState(session.snapshot.state)['backpack']!.width,
        6,
      );
      final bag = session.snapshot.state['bagEquipment']! as Map;
      expect(bag['instanceId'], 'original-bag-identity');
      expect(bag['itemId'], 'bag.reinforced');
      expect(session.snapshot.state['tutorialTasks']! is Map, isTrue);
      final upgraded = _catalog.inventoryFromJson(
        grids: streetScrapGridSpecsForState(session.snapshot.state),
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(upgraded.objects.containsKey('kept-item'), isTrue);
      expect(
        upgraded.placements['kept-item']!.x,
        inventory.placements['kept-item']!.x,
      );
      expect(
        upgraded.placements['kept-item']!.y,
        inventory.placements['kept-item']!.y,
      );
      expect(upgraded.objects.containsKey('upgrade-needle'), isTrue);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q3.05'],
        isTrue,
      );
      await session.close();
    },
  );

  test(
    'q4.03 consumes soup atomically and retains the dirty meal box',
    () async {
      final session = await _session('q403-eat-soup');
      var inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'same-meal-box',
              itemId: 'container.meal_box',
              source: 'tutorial:q4.02-soup-kit',
              quality: 55,
              traits: const {},
              containerState: const {
                'contentItemId': 'meal.soup_basic',
                'contentQuality': 80,
                'cleanliness': 'clean',
              },
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'q403-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'stamina': 15,
            'tutorialTasks': {'q4.02': true},
            'inventory': inventory.toJson(),
          },
        ),
      );
      final result = await consumeStreetScrapSoup(
        session: session,
        commandId: 'q403-eat',
        expectedRevision: 2,
        catalog: _catalog,
        grids: _grids,
        mealBoxInstanceId: 'same-meal-box',
        maxStamina: 60,
      );
      final resultData = Map<String, Object?>.from(result.result! as Map);
      expect(resultData['recovery'], 23);
      expect(resultData['actualRestored'], 23);
      expect(session.snapshot.state['stamina'], 38);
      inventory = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final box = inventory.objects['same-meal-box']!;
      expect(box.containerState['contentItemId'], isNull);
      expect(box.containerState['cleanliness'], 'soiled');
      expect(inventory.placements['same-meal-box']!.gridId, 'backpack');
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.03'],
        isTrue,
      );
      await session.close();
    },
  );

  test('q4.03 meal order returns the same box and pays exactly once', () async {
    final session = await _session('q403-deliver-meal');
    var inventory = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _catalog.createObject(
            instanceId: 'order-meal-box',
            itemId: 'container.meal_box_insulated',
            source: 'test:meal-order',
            quality: 55,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_vegetable',
              'contentQuality': 72,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'meal-order-setup',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'tutorialTasks': {'q4.02': true},
          'inventory': inventory.toJson(),
        },
      ),
    );
    final result = await deliverStreetScrapMeal(
      session: session,
      commandId: 'deliver-meal-once',
      expectedRevision: 2,
      catalog: _catalog,
      grids: _grids,
      mealBoxInstanceId: 'order-meal-box',
    );
    expect((result.result! as Map)['exchangeTickets'], 4);
    expect(session.snapshot.state['exchangeTickets'], 4);
    final settled = Map<String, Object?>.from(
      session.snapshot.state['inventory']! as Map,
    );
    inventory = _catalog.inventoryFromJson(grids: _grids, json: settled);
    final returnedBox = inventory.objects['order-meal-box']!;
    expect(returnedBox.containerState['contentItemId'], isNull);
    expect(
      returnedBox.containerState['lastContentItemId'],
      'meal.soup_vegetable',
    );
    expect(returnedBox.containerState['cleanliness'], 'soiled');
    expect(inventory.placements['order-meal-box']!.gridId, 'backpack');
    final beforeDuplicate = session.snapshot.toJson();
    await expectLater(
      deliverStreetScrapMeal(
        session: session,
        commandId: 'deliver-meal-twice',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        mealBoxInstanceId: 'order-meal-box',
      ),
      throwsStateError,
    );
    expect(session.snapshot.toJson(), beforeDuplicate);
    await session.close();
  });

  test(
    'q4.03 refuses to consume a meal at full stamina without mutation',
    () async {
      final session = await _session('q403-full-stamina');
      final inventory = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _catalog.createObject(
              instanceId: 'full-stamina-box',
              itemId: 'container.meal_box',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {
                'contentItemId': 'meal.soup_basic',
                'contentQuality': 55,
                'cleanliness': 'clean',
              },
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'full-setup',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'stamina': 60,
            'tutorialTasks': {'q4.02': true},
            'inventory': inventory.toJson(),
          },
        ),
      );
      await expectLater(
        consumeStreetScrapSoup(
          session: session,
          commandId: 'full-eat',
          expectedRevision: 2,
          catalog: _catalog,
          grids: _grids,
          mealBoxInstanceId: 'full-stamina-box',
          maxStamina: 60,
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.revision, 2);
      expect(session.snapshot.state['stamina'], 60);
      await session.close();
    },
  );
}
