import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_fishing.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_orders.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_orders_panel.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_chapter5.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_audio.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_water.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_supplies.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_relief.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_item_sprite.dart';

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

final _inventoryCatalog = StreetScrapInventoryCatalog(
  footprints: const {
    'material.mud': StreetScrapFootprint(1, 1),
    'material.mineral_pack': StreetScrapFootprint(1, 1),
    'metal.bar': StreetScrapFootprint(1, 1),
    'meal.soup_basic': StreetScrapFootprint(1, 1),
    'meal.failed': StreetScrapFootprint(1, 1),
    'fish.raw': StreetScrapFootprint(1, 2),
    'fish.meat': StreetScrapFootprint(1, 1),
    'container.meal_box': StreetScrapFootprint(1, 2),
    'container.meal_box_insulated': StreetScrapFootprint(1, 2),
    'wood.board': StreetScrapFootprint(1, 2),
    'structure.shelter': StreetScrapFootprint(2, 2),
    'structure.tarp': StreetScrapFootprint(2, 2),
    'storage.reinforced_chest': StreetScrapFootprint(2, 2),
    'storage.wooden_crate': StreetScrapFootprint(2, 2),
    'wood.frame': StreetScrapFootprint(2, 2),
    'plastic.seal': StreetScrapFootprint(1, 1),
    'wood.chip': StreetScrapFootprint(1, 1),
    'wood.driftwood': StreetScrapFootprint(1, 2),
    'cloth.thread_spool': StreetScrapFootprint(1, 1),
    'cloth.repair_strip': StreetScrapFootprint(1, 1),
    'cloth.patchwork': StreetScrapFootprint(1, 2),
    'cloth.waterproof': StreetScrapFootprint(1, 2),
    'material.waterproof_coating': StreetScrapFootprint(1, 1),
    'cloth.thread_end': StreetScrapFootprint(1, 1),
    'cloth.rag_piece': StreetScrapFootprint(1, 1),
    'cloth.edge_scrap': StreetScrapFootprint(1, 1),
    'tool.needle': StreetScrapFootprint(1, 1),
    'adhesive.residue': StreetScrapFootprint(1, 1),
    'paper.pulp': StreetScrapFootprint(1, 1),
    'adhesive.recycled': StreetScrapFootprint(1, 1),
    'cloth.binding': StreetScrapFootprint(1, 1),
    'wood.rod': StreetScrapFootprint(1, 2),
    'fish.pack': StreetScrapFootprint(1, 2),
    'fish.bone': StreetScrapFootprint(1, 1),
    'paper.packaging': StreetScrapFootprint(1, 1),
    'food.scrap': StreetScrapFootprint(1, 1),
    'tool.awl': StreetScrapFootprint(1, 2),
    'meal.shared': StreetScrapFootprint(1, 1),
    'food.cleaned': StreetScrapFootprint(1, 1),
    'food.greens': StreetScrapFootprint(1, 1),
    'container.clean_jar': StreetScrapFootprint(1, 1),
    'fuel.dry': StreetScrapFootprint(1, 1),
    'metal.sheet': StreetScrapFootprint(1, 1),
    'metal.wire': StreetScrapFootprint(1, 1),
    'metal.fastener': StreetScrapFootprint(1, 1),
    'paper.scrap': StreetScrapFootprint(1, 1),
    'metal.nail_bundle': StreetScrapFootprint(1, 1),
    'plastic.scrap': StreetScrapFootprint(1, 1),
    'plastic.sheet': StreetScrapFootprint(1, 2),
  },
  packingRules: const {},
);

final _q501KitchenSupplyCatalog = StreetScrapRenewableSupplyCatalog([
  StreetScrapRenewableSupply(
    itemId: 'container.clean_jar',
    phase: 1,
    quantity: 1,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'water.filtered',
    phase: 0,
    quantity: 1,
    staminaCost: 2,
  ),
  StreetScrapRenewableSupply(
    itemId: 'paper.scrap',
    phase: 0,
    quantity: 3,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'cloth.rag_piece',
    phase: 0,
    quantity: 3,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'cloth.edge_scrap',
    phase: 0,
    quantity: 3,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'cloth.thread_spool',
    phase: 0,
    quantity: 1,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'adhesive.residue',
    phase: 1,
    quantity: 2,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'metal.nail_bundle',
    phase: 1,
    quantity: 1,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'plastic.scrap',
    phase: 1,
    quantity: 3,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'material.waterproof_coating',
    phase: 3,
    quantity: 1,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'fuel.dry',
    phase: 3,
    quantity: 1,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'food.greens',
    phase: 4,
    quantity: 2,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'metal.sheet',
    phase: 1,
    quantity: 1,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'metal.wire',
    phase: 1,
    quantity: 2,
    staminaCost: 3,
  ),
  StreetScrapRenewableSupply(
    itemId: 'material.mineral_pack',
    phase: 5,
    quantity: 1,
    staminaCost: 3,
  ),
]);

final _orderCatalog = StreetScrapOrderCatalog.fromOrders([
  StreetScrapOrder.fromJson(
    {
      'id': 'ss.order.fish',
      'phase': 2,
      'acceptedItems': ['fish.raw', 'fish.meat'],
      'requirementGroups': [
        [
          {'item': 'fish.raw', 'quantity': 1},
        ],
        [
          {'item': 'fish.meat', 'quantity': 2},
        ],
      ],
      'rejectedItems': [],
      'quantity': 1,
      'reward': {'currency': 'exchangeTickets', 'quantity': 3},
      'countsTowardCycle': true,
      'returnContainer': false,
      'returnedContainerCleanliness': null,
    },
    itemIds: const {'fish.raw', 'fish.meat'},
  ),
  StreetScrapOrder.fromJson(
    {
      'id': 'ss.order.wall',
      'phase': 5,
      'acceptedItems': ['material.mud', 'material.mineral_pack'],
      'quantity': 2,
      'reward': {'currency': 'exchangeTickets', 'quantity': 4},
      'countsTowardCycle': true,
    },
    itemIds: const {'material.mud', 'material.mineral_pack'},
  ),
  StreetScrapOrder.fromJson(
    {
      'id': 'ss.order.meal',
      'phase': 4,
      'acceptedItems': ['meal.soup_basic'],
      'rejectedItems': ['meal.failed'],
      'reward': {'currency': 'exchangeTickets', 'quantity': 4},
      'countsTowardCycle': false,
      'returnContainer': true,
      'returnedContainerCleanliness': 'soiled',
      'requiresTutorial': 'q4.02',
      'oncePerTutorial': 'q4.03',
    },
    itemIds: const {'meal.soup_basic', 'meal.failed'},
  ),
  StreetScrapOrder.fromJson(
    {
      'id': 'ss.order.failed_meal_recycle',
      'phase': 4,
      'acceptedItems': ['meal.failed'],
      'requirementGroups': [
        [
          {'item': 'meal.failed', 'quantity': 3},
        ],
      ],
      'rejectedItems': [],
      'quantity': 3,
      'reward': {'currency': 'exchangeTickets', 'quantity': 1},
      'countsTowardCycle': false,
      'returnContainer': true,
      'containerItemId': 'container.meal_box',
      'returnedContainerCleanliness': 'soiled',
      'requiresTutorial': 'q4.02',
    },
    itemIds: const {'meal.failed', 'container.meal_box'},
  ),
  StreetScrapOrder.fromJson(
    {
      'id': 'ss.order.insulated',
      'phase': 4,
      'acceptedItems': ['meal.soup_basic'],
      'rejectedItems': ['meal.failed'],
      'quantity': 1,
      'reward': {'currency': 'exchangeTickets', 'quantity': 8},
      'countsTowardCycle': true,
      'returnContainer': false,
      'consumeContainer': true,
      'containerItemId': 'container.meal_box_insulated',
    },
    itemIds: const {
      'meal.soup_basic',
      'meal.failed',
      'container.meal_box_insulated',
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
      'game.street-scrap.content.chapters-0-4': '0.1.26',
      if (chapterFive) 'game.street-scrap.content.chapter-5': '0.1.23',
    },
    rulesetVersion: 1,
  );
  await session.load();
  return session;
}

Future<StreetScrapOrderCatalog> _q501CatalogFromCanonicalFixture() async {
  const fixtureRelativePath =
      'test/fixtures/street_scrap_chapter5_q501_orders.json';
  final packageRootFixture = File(fixtureRelativePath);
  final workspaceRootFixture = File(
    'packages/games/street_scrap/$fixtureRelativePath',
  );
  final fixture = packageRootFixture.existsSync()
      ? packageRootFixture
      : workspaceRootFixture;
  if (!fixture.existsSync()) {
    throw StateError('Missing canonical q5.01 order fixture.');
  }
  final payload = jsonDecode(fixture.readAsStringSync()) as Map;
  final rawOrders = (payload['orders'] as List).whereType<Map>().toList();
  final itemIds = <String>{};
  final recipeIds = <String>{};
  for (final order in rawOrders) {
    for (final itemId in [
      ...(order['acceptedItems'] as List? ?? const []),
      ...(order['rejectedItems'] as List? ?? const []),
    ]) {
      if (itemId is String) itemIds.add(itemId);
    }
    for (final group in order['requirementGroups'] as List? ?? const []) {
      if (group is! List) continue;
      for (final requirement in group.whereType<Map>()) {
        final itemId = requirement['item'];
        if (itemId is String) itemIds.add(itemId);
      }
    }
    final containerItemId = order['containerItemId'];
    if (containerItemId is String) itemIds.add(containerItemId);
    recipeIds.addAll(
      (order['requiredRecipes'] as List? ?? const []).whereType<String>(),
    );
  }
  return StreetScrapOrderCatalog.fromOrders(
    rawOrders.map(
      (order) => StreetScrapOrder.fromJson(
        order,
        itemIds: itemIds,
        recipeIds: recipeIds,
      ),
    ),
  );
}

Future<void> _setup(
  StreetScrapSession session, {
  required int chapter,
  required StreetScrapInventory inventory,
  Map<String, Object?> tasks = const {},
}) => session.apply(
  commandId: 'setup-${session.slotKey}',
  expectedRevision: 0,
  reduce: (_) => StreetScrapReduction(
    state: {
      'chapter': chapter,
      'tutorialTasks': tasks,
      'inventory': inventory.toJson(),
      'exchangeTickets': 0,
    },
  ),
);

StreetScrapExpeditionRules _q501SearchRules() =>
    StreetScrapExpeditionRules.fromJson({
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'fixedLocations': [
        for (var node = 0; node < 3; node++)
          {
            'id': 'phase-zero-$node',
            'phase': 0,
            'nodeIndex': node,
            'options': [
              {'item': 'wood.chip', 'quantity': 1},
            ],
          },
        {
          'id': 'old_street_exchange',
          'phase': 5,
          'nodeIndex': 0,
          'options': [
            {'item': 'wood.board', 'quantity': 2},
            {'item': 'wood.chip', 'quantity': 2},
            {'item': 'wood.driftwood', 'quantity': 2},
            {'item': 'material.mineral_pack', 'quantity': 1},
          ],
        },
      ],
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
      'scrapQualities': [45, 60],
      'intactQualities': [60, 80],
    });

StreetScrapRecipe _q502Recipe({
  required String id,
  required int phase,
  required List<StreetScrapRecipeInput> inputs,
  required String outputItemId,
  required String primaryInputId,
  required bool manual,
  String? station,
  String? operationId,
  Map<String, Object?>? stateEffect,
}) => StreetScrapRecipe(
  id: id,
  phase: phase,
  station: station ?? (phase <= 1 ? 'recycler' : 'workbench'),
  operationId: operationId ?? (manual ? 'align' : 'press'),
  durationSeconds: 10,
  instructions: 'Use the listed materials and complete the operation.',
  inputGroups: [inputs],
  reusableTools: const [],
  outputs: [StreetScrapRecipeInput(itemId: outputItemId, quantity: 1)],
  quality: StreetScrapRecipeQualityRule(
    primaryInputs: [primaryInputId],
    loss: 0,
    mode: 'weighted-primary',
    masteryRevision: 1,
  ),
  retainedInputIds: const [],
  stateEffect: stateEffect,
  failureMode: 'sameOutputsQualityLoss',
  failureOutcome: 'The material remains usable at reduced quality.',
  failureResolution: const StreetScrapFailureResolution(
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
  ),
  manualCheckpoints: manual
      ? [
          for (var index = 0; index < 3; index++)
            StreetScrapManualCheckpoint(
              prompt: 'Check operation step ${index + 1}.',
              options: const ['Follow the marked guide', 'Skip the guide'],
              correctOption: 0,
            ),
        ]
      : const [],
);

Future<String> _q502Craft({
  required StreetScrapSession session,
  required StreetScrapRecipe recipe,
  required List<String> inputIds,
  required String operationId,
  required String gridId,
}) async {
  if (recipe.manualCheckpoints.isNotEmpty) {
    await StreetScrapCrafting.beginManual(
      session: session,
      inventoryCatalog: _inventoryCatalog,
      recipe: recipe,
      grids: _grids,
      gridId: gridId,
      inputGroupIndex: 0,
      inputInstanceIds: inputIds,
      toolInstanceIds: const [],
      operationId: operationId,
      commandId: 'begin-$operationId',
      expectedRevision: session.snapshot.revision,
      contentVersion: '0.1.26',
    );
    for (var index = 0; index < recipe.manualCheckpoints.length; index++) {
      await StreetScrapCrafting.answerManualCheckpoint(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: recipe,
        grids: _grids,
        operationId: operationId,
        optionIndex: recipe.manualCheckpoints[index].correctOption,
        expectedRevision: session.snapshot.revision,
      );
    }
  } else {
    await StreetScrapCrafting.craft(
      session: session,
      inventoryCatalog: _inventoryCatalog,
      recipe: recipe,
      grids: _grids,
      gridId: gridId,
      inputGroupIndex: 0,
      inputInstanceIds: inputIds,
      toolInstanceIds: const [],
      commandId: 'craft-$operationId',
      expectedRevision: session.snapshot.revision,
      manual: false,
      manualPoints: 0,
      outputInstanceId: (index) => '$operationId-output-$index',
    );
  }
  return '$operationId-output-0';
}

StreetScrapExpeditionRules _q501RecycleRules() =>
    StreetScrapExpeditionRules.fromJson({
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'fixedLocations': [
        {
          'id': 'clothing_corner',
          'phase': 0,
          'nodeIndex': 0,
          'options': [
            {'item': 'cloth.rag_piece', 'quantity': 3},
            {'item': 'cloth.edge_scrap', 'quantity': 3},
            {'item': 'cloth.thread_end', 'quantity': 3},
            {'item': 'cloth.thread_spool', 'quantity': 1},
          ],
        },
        {
          'id': 'paper_wood_pile',
          'phase': 0,
          'nodeIndex': 1,
          'options': [
            {'item': 'wood.chip', 'quantity': 3},
            {'item': 'wood.sawdust', 'quantity': 3},
            {'item': 'wood.driftwood', 'quantity': 2},
            {'item': 'paper.scrap', 'quantity': 3},
          ],
        },
        {
          'id': 'container_corner',
          'phase': 0,
          'nodeIndex': 2,
          'options': [
            {'item': 'container.used_intact', 'quantity': 1},
            {'item': 'container.broken_bottle', 'quantity': 1},
          ],
        },
        {
          'id': 'sorting_shed',
          'phase': 1,
          'nodeIndex': 1,
          'options': [
            {'item': 'plastic.scrap', 'quantity': 3},
            {'item': 'adhesive.residue', 'quantity': 2},
          ],
        },
        {
          'id': 'metal_recycling_rack',
          'phase': 1,
          'nodeIndex': 2,
          'options': [
            {'item': 'metal.scrap', 'quantity': 3},
            {'item': 'metal.shard', 'quantity': 3},
            {'item': 'metal.wire', 'quantity': 2},
            {'item': 'metal.nail_bundle', 'quantity': 1},
            {'item': 'metal.sheet', 'quantity': 1},
            {'item': 'container.clean', 'quantity': 1},
            {'item': 'wood.board', 'quantity': 1},
          ],
        },
      ],
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
      'scrapQualities': [45, 60],
      'intactQualities': [60, 80],
    });

void _setOrderTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets('material alternatives use image cards with fixed paging', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    final session = await _session('orders-image-options');
    const optionIds = [
      'cloth.rag_piece',
      'wood.chip',
      'metal.scrap',
      'paper.scrap',
      'plastic.scrap',
      'adhesive.residue',
      'glass.shard',
    ];
    final imageOrder = StreetScrapOrder.fromJson({
      'id': 'ss.order.image_options',
      'phase': 0,
      'acceptedItems': optionIds,
      'requirementGroups': [
        for (final itemId in optionIds)
          [
            {'item': itemId, 'quantity': 3},
          ],
      ],
      'rejectedItems': [],
      'quantity': 1,
      'reward': {'currency': 'exchangeTickets', 'quantity': 1},
      'countsTowardCycle': false,
    }, itemIds: optionIds.toSet());
    final orderCatalog = StreetScrapOrderCatalog.fromOrders([
      ..._orderCatalog.orders.values,
      imageOrder,
    ]);
    await _setup(
      session,
      chapter: 0,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: orderCatalog,
                onChanged: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = find.byKey(
      const Key('street-scrap-order-options-ss.order.image_options'),
    );
    expect(grid, findsOneWidget);
    expect(
      find.text('0/3'),
      findsWidgets,
      reason:
          'Requirement cards should show matching backpack stock over requested quantity.',
    );
    final firstOption = find.byKey(
      const Key('street-scrap-order-option-ss.order.image_options-0'),
    );
    expect(
      find.descendant(of: firstOption, matching: find.text('破布片')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstOption, matching: find.text('破布片 × 3')),
      findsNothing,
      reason:
          'The ratio badge already carries the quantity, so the label stays short.',
    );
    expect(
      tester.getSemantics(firstOption).getSemanticsData().label,
      contains('持有 0／需求 3'),
    );
    expect(
      tester.widget<GridView>(grid).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(
          Key('street-scrap-order-option-ss.order.image_options-$index'),
        ),
        findsOneWidget,
      );
    }
    expect(
      tester
          .getSemantics(
            find.byKey(
              const Key('street-scrap-order-option-ss.order.image_options-0'),
            ),
          )
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      find.byKey(
        const Key('street-scrap-order-option-ss.order.image_options-4'),
      ),
      findsNothing,
    );
    expect(find.text('第 1 / 2 頁'), findsOneWidget);
    await tester.tap(find.byTooltip('下一頁素材'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('street-scrap-order-option-ss.order.image_options-4'),
      ),
      findsOneWidget,
    );
    expect(find.text('第 2 / 2 頁'), findsOneWidget);

    tester.view.physicalSize = const Size(872, 874);
    await tester.pumpAndSettle();
    for (var index = 0; index < optionIds.length; index++) {
      expect(
        find.byKey(
          Key('street-scrap-order-option-ss.order.image_options-$index'),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('第 1 / 1 頁'), findsNothing);
    expect(
      tester
          .widget<StreetScrapItemSprite>(
            find.byType(StreetScrapItemSprite).first,
          )
          .size,
      108,
    );
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await session.close();
  });

  testWidgets('malformed cycle slots show localized fallback without writes', (
    tester,
  ) async {
    final session = await _session('orders-malformed-cycle-slots');
    await _setup(
      session,
      chapter: 5,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await session.apply(
      commandId: 'corrupt-cycle-slot-fixture',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'activeCycleOrderIds': 'invalid'},
      ),
    );
    final stateBeforeRender = session.snapshot.toJson();
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: _orderCatalog,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.text(
        'The cycle-order data is malformed. Delivery has been disabled.',
      ),
      findsOneWidget,
    );
    expect(session.snapshot.toJson(), stateBeforeRender);
    await session.close();
  });

  testWidgets('malformed tutorial progress shows localized read-only fallback', (
    tester,
  ) async {
    final session = await _session('orders-malformed-tutorial-fallback');
    await _setup(
      session,
      chapter: 4,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await session.apply(
      commandId: 'corrupt-tutorial-state-fixture',
      expectedRevision: 1,
      reduce: (state) =>
          StreetScrapReduction(state: {...state, 'tutorialTasks': 'invalid'}),
    );
    final revisionBeforeRender = session.snapshot.revision;
    final stateBeforeRender = session.snapshot.toJson();
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: _orderCatalog,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.text(
        'The tutorial/order-task save is invalid. The order transaction was not completed and delivery is disabled.',
      ),
      findsOneWidget,
    );
    expect(session.snapshot.revision, revisionBeforeRender);
    expect(session.snapshot.toJson(), stateBeforeRender);
    await session.close();
  });

  testWidgets('malformed completion history disables order controls read-only', (
    tester,
  ) async {
    final session = await _session('orders-malformed-completion-history');
    await _setup(
      session,
      chapter: 5,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await session.apply(
      commandId: 'corrupt-completion-history-fixture',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'completedOrderGroups': {'q5.01': 'ss.order.advanced_fish'},
        },
      ),
    );
    final stateBeforeRender = session.snapshot.toJson();
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: _orderCatalog,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The order-completion record is invalid. The transaction was not completed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Deliver order'), findsNothing);
    expect(session.snapshot.toJson(), stateBeforeRender);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('order overview follows the active English locale', (
    tester,
  ) async {
    final session = await _session('orders-english-overview');
    await _setup(
      session,
      chapter: 0,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapOrdersPanel(
              session: session,
              inventoryCatalog: _inventoryCatalog,
              orderCatalog: _orderCatalog,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Neighborhood Orders'), findsOneWidget);
    expect(find.text('No orders are available yet.'), findsOneWidget);
    expect(find.text('Cycle orders ×2'), findsOneWidget);
    expect(find.text('0 completed'), findsOneWidget);
    expect(find.text('街坊委託'), findsNothing);
    await session.close();
  });

  testWidgets('completed chapter order collapses to a compact status row', (
    tester,
  ) async {
    final session = await _session('completed-meal-order-compact');
    await _setup(
      session,
      chapter: 4,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
      tasks: const {'q4.03': true},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: _orderCatalog,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final failedMealOrder = find.byKey(
      const ValueKey('street-scrap-order-ss.order.failed_meal_recycle'),
    );
    expect(failedMealOrder, findsOneWidget);
    expect(
      find.descendant(
        of: failedMealOrder,
        matching: find.text('No matching meal container is in your backpack.'),
      ),
      findsOneWidget,
    );
    final completedOrder = find.byKey(
      const ValueKey('street-scrap-order-ss.order.meal'),
    );
    expect(
      find.descendant(of: completedOrder, matching: find.text('Completed')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: completedOrder, matching: find.text('Basic Soup')),
      findsNothing,
    );
    expect(
      find.descendant(of: completedOrder, matching: find.text('Deliver order')),
      findsNothing,
    );
    expect(tester.getSize(completedOrder).height, lessThan(130));
    await session.close();
  });

  test(
    'cycle board keeps two stable slots and free replacement persists',
    () async {
      final session = await _session('cycle-order-slots');
      await _setup(
        session,
        chapter: 5,
        inventory: _inventoryCatalog.emptyInventory(grids: _grids),
      );
      expect(
        activeStreetScrapCycleOrderIds(session.snapshot.state, _orderCatalog),
        ['ss.order.fish', 'ss.order.wall'],
      );
      expect(
        canReplaceStreetScrapCycleOrder(session.snapshot.state, _orderCatalog),
        isTrue,
      );
      final inventoryBefore = session.snapshot.state['inventory'];
      final ticketsBefore = session.snapshot.state['exchangeTickets'];
      await replaceStreetScrapCycleOrder(
        session: session,
        commandId: 'cycle-replace-wall',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.wall',
      );
      expect(session.snapshot.state['activeCycleOrderIds'], [
        'ss.order.fish',
        'ss.order.insulated',
      ]);
      expect(session.snapshot.state['inventory'], inventoryBefore);
      expect(session.snapshot.state['exchangeTickets'], ticketsBefore);
      expect(session.snapshot.state['cycleOrderRotationCursor'], 0);
      await replaceStreetScrapCycleOrder(
        session: session,
        commandId: 'cycle-replace-insulated',
        expectedRevision: 2,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.insulated',
      );
      expect(session.snapshot.state['activeCycleOrderIds'], [
        'ss.order.fish',
        'ss.order.wall',
      ]);
      expect(session.snapshot.state['cycleOrderRotationCursor'], 2);
      await session.close();
    },
  );

  test(
    'a chapter with no alternate cycle order does not invent a replacement',
    () async {
      final session = await _session('cycle-order-single-candidate');
      await _setup(
        session,
        chapter: 2,
        inventory: _inventoryCatalog.emptyInventory(grids: _grids),
      );
      expect(
        activeStreetScrapCycleOrderIds(session.snapshot.state, _orderCatalog),
        ['ss.order.fish'],
      );
      expect(
        canReplaceStreetScrapCycleOrder(session.snapshot.state, _orderCatalog),
        isFalse,
      );
      await expectLater(
        replaceStreetScrapCycleOrder(
          session: session,
          commandId: 'cycle-replace-without-alternative',
          expectedRevision: 1,
          orderCatalog: _orderCatalog,
          orderId: 'ss.order.fish',
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.revision, 1);
      await session.close();
    },
  );

  test('hidden cycle order cannot bypass the order board', () async {
    final session = await _session('cycle-order-hidden-reject');
    await _setup(
      session,
      chapter: 5,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await expectLater(
      deliverStreetScrapOrder(
        session: session,
        commandId: 'hidden-insulated-delivery',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.insulated',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceId: 'not-present',
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.revision, 1);
    expect(session.snapshot.state['exchangeTickets'], 0);
    await session.close();
  });

  test(
    'completion groups unlock their task only after every member order',
    () async {
      final groupCatalog = StreetScrapOrderCatalog.fromOrders([
        for (final entry in [
          ('ss.order.group-a', 'material.mud'),
          ('ss.order.group-b', 'material.mineral_pack'),
        ])
          StreetScrapOrder.fromJson(
            {
              'id': entry.$1,
              'phase': 5,
              'acceptedItems': [entry.$2],
              'quantity': 1,
              'reward': {'currency': 'exchangeTickets', 'quantity': 1},
              'countsTowardCycle': false,
              'returnContainer': false,
              'completionGroupId': 'q5.01',
            },
            itemIds: const {'material.mud', 'material.mineral_pack'},
          ),
      ]);
      final session = await _session('orders-completion-group');
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'group-mud',
              itemId: 'material.mud',
              source: 'test',
              quality: 50,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'group-mineral',
              itemId: 'material.mineral_pack',
              source: 'test',
              quality: 50,
              traits: const {},
            ),
            'backpack',
          );
      await _setup(session, chapter: 5, inventory: inventory);
      await deliverStreetScrapOrder(
        session: session,
        commandId: 'group-order-a',
        expectedRevision: 1,
        orderCatalog: groupCatalog,
        orderId: 'ss.order.group-a',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        itemInstanceIds: const ['group-mud'],
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.01'],
        isNull,
      );
      final stateAfterFirstOrder = session.snapshot.toJson();
      await expectLater(
        deliverStreetScrapOrder(
          session: session,
          commandId: 'group-order-a-duplicate',
          expectedRevision: 2,
          orderCatalog: groupCatalog,
          orderId: 'ss.order.group-a',
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          itemInstanceIds: const ['group-mud'],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'orderAlreadyCompleted',
          ),
        ),
      );
      expect(session.snapshot.toJson(), stateAfterFirstOrder);
      await deliverStreetScrapOrder(
        session: session,
        commandId: 'group-order-b',
        expectedRevision: 2,
        orderCatalog: groupCatalog,
        orderId: 'ss.order.group-b',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        itemInstanceIds: const ['group-mineral'],
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.01'],
        isTrue,
      );
      expect(
        ((session.snapshot.state['completedOrderGroups']! as Map)['q5.01']
                as List)
            .toSet(),
        {'ss.order.group-a', 'ss.order.group-b'},
      );
      await session.close();
    },
  );

  test(
    'q5.01 completes all five advanced producer orders in one save',
    () async {
      final canonicalQ501Catalog = await _q501CatalogFromCanonicalFixture();
      final orderCatalog = StreetScrapOrderCatalog.fromOrders([
        ..._orderCatalog.orders.values,
        ...canonicalQ501Catalog.orders.values,
      ]);
      expect(orderCatalog.completionGroups['q5.01'], hasLength(5));

      final session = await _session(
        'q501-five-producer-orders',
        chapterFive: true,
      );
      await _setup(
        session,
        chapter: 5,
        inventory: _inventoryCatalog.emptyInventory(grids: _grids),
        tasks: {
          'q1.01': true,
          'q1.03': true,
          'q3.01.kitClaimed': true,
          'q3.04.kitClaimed': true,
        },
      );
      await session.apply(
        commandId: 'q501-unlock-recycler',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'unlockedStations': [
              'tutorial',
              'recycler',
              'dock',
              'workbench',
              'kitchen',
            ],
            'unlockedFishingSpots': ['dock_entrance'],
            'mastery': {
              'ss.recipe.unpick_cloth': 1,
              'ss.recipe.join_thread': 1,
              'ss.recipe.recycle_glue': 1,
              'ss.recipe.fillet_fish': 1,
              'ss.recipe.fish_pack': 1,
              'ss.recipe.braid_binding': 1,
              'ss.recipe.shared_meal': 1,
              'ss.recipe.sew_strip': 1,
              'ss.recipe.patch_cloth': 1,
              'ss.recipe.mix_pulp': 1,
              'ss.recipe.assemble_frame': 1,
              'ss.recipe.press_plastic': 1,
              'ss.recipe.coat_cloth': 1,
              'ss.recipe.bend_fastener': 1,
              'ss.recipe.seal_part': 1,
              'ss.recipe.wooden_crate': 1,
            },
          },
        ),
      );
      const routes = [
        (
          orderId: 'ss.order.advanced_search',
          itemIds: ['wood.chip', 'wood.chip'],
          source: 'fixed:old_street_exchange',
        ),
        (
          orderId: 'ss.order.advanced_recycle',
          itemIds: ['cloth.thread_spool', 'adhesive.recycled'],
          source: 'recipe-output:q5.01-recycling-chain',
        ),
        (
          orderId: 'ss.order.advanced_fish',
          itemIds: ['fish.pack'],
          source: 'gameplay:fishing',
        ),
        (
          orderId: 'ss.order.advanced_workbench',
          itemIds: ['tool.awl'],
          source: 'recipe-output:q5.01-workbench',
        ),
      ];
      var expectedTickets = 0;
      for (final route in routes) {
        final order = orderCatalog[route.orderId]!;
        if (order.requiresAcceptance) {
          await acceptStreetScrapOrder(
            session: session,
            commandId: 'accept-${route.orderId}',
            expectedRevision: session.snapshot.revision,
            orderCatalog: orderCatalog,
            orderId: route.orderId,
          );
        }
        final before = _inventoryCatalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        if (route.orderId == 'ss.order.advanced_search') {
          final searchRules = _q501SearchRules();
          await startStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-old-street-search-start',
            expectedRevision: session.snapshot.revision,
            phase: 5,
            seed: 501,
            defaultStamina: 60,
            rules: searchRules,
          );
          await applyStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-old-street-search-node-0',
            expectedRevision: session.snapshot.revision,
            rules: searchRules,
            transition: (current) => current!
                .investigateFixed(
                  rules: searchRules,
                  optionIndex: 1,
                  selectedVisibleTarget: true,
                )
                .expedition,
          );
          await applyStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-old-street-search-return',
            expectedRevision: session.snapshot.revision,
            rules: searchRules,
            transition: (current) => current!.returnHome(),
          );
          await claimStreetScrapExpeditionRewards(
            session: session,
            commandId: 'q501-old-street-search-claim',
            expectedRevision: session.snapshot.revision,
            rules: searchRules,
            catalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
          );
          final searched = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          final foundChips = searched.objects.values
              .where(
                (item) =>
                    item.itemId == 'wood.chip' &&
                    item.source == 'fixed:old_street_exchange',
              )
              .toList(growable: false);
          expect(foundChips, hasLength(2));
          final searchExpedition = Map<String, Object?>.from(
            session.snapshot.state['expedition']! as Map,
          );
          expect(searchExpedition['investigated'], [0]);
          expect(searchExpedition['visited'], [0]);
          expect(foundChips.map((item) => item.source).toSet(), {
            'fixed:old_street_exchange',
          });
          expect(
            foundChips.every((item) => item.acquiredRevision != null),
            isTrue,
          );
        } else if (route.orderId == 'ss.order.advanced_recycle') {
          await claimStreetScrapSewingTutorialKit(
            session: session,
            commandId: 'q501-recycler-claim-sewing-kit',
            expectedRevision: session.snapshot.revision,
            catalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
          );
          final recyclingRules = _q501RecycleRules();
          await startStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-sorting-shed-start',
            expectedRevision: session.snapshot.revision,
            phase: 1,
            seed: 502,
            defaultStamina: 60,
            rules: recyclingRules,
          );
          await applyStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-sorting-shed-move',
            expectedRevision: session.snapshot.revision,
            rules: recyclingRules,
            transition: (current) => current!.move(recyclingRules),
          );
          await applyStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-sorting-shed-investigate',
            expectedRevision: session.snapshot.revision,
            rules: recyclingRules,
            transition: (current) => current!
                .investigateFixed(
                  rules: recyclingRules,
                  optionIndex: 1,
                  selectedVisibleTarget: true,
                )
                .expedition,
          );
          await applyStreetScrapExpeditionCommand(
            session: session,
            commandId: 'q501-sorting-shed-return',
            expectedRevision: session.snapshot.revision,
            rules: recyclingRules,
            transition: (current) => current!.returnHome(),
          );
          await claimStreetScrapExpeditionRewards(
            session: session,
            commandId: 'q501-sorting-shed-claim',
            expectedRevision: session.snapshot.revision,
            rules: recyclingRules,
            catalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
          );
          await claimStreetScrapRenewableSupply(
            session: session,
            commandId: 'q501-paper-scrap-supply',
            expectedRevision: session.snapshot.revision,
            supplyCatalog: _q501KitchenSupplyCatalog,
            inventoryCatalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
            itemId: 'paper.scrap',
            maxStamina: 60,
          );
          await claimStreetScrapRenewableSupply(
            session: session,
            commandId: 'q501-pulp-jar-supply',
            expectedRevision: session.snapshot.revision,
            supplyCatalog: _q501KitchenSupplyCatalog,
            inventoryCatalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
            itemId: 'container.clean_jar',
            maxStamina: 60,
          );
          await claimStreetScrapRenewableSupply(
            session: session,
            commandId: 'q501-pulp-water-supply',
            expectedRevision: session.snapshot.revision,
            supplyCatalog: _q501KitchenSupplyCatalog,
            inventoryCatalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
            itemId: 'water.filtered',
            maxStamina: 60,
            vesselInstanceId: 'supply-q501-pulp-jar-supply-0',
          );
          final gathered = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          final gatheredResidueIds = gathered.objects.values
              .where(
                (item) =>
                    item.itemId == 'adhesive.residue' &&
                    item.source == 'fixed:sorting_shed',
              )
              .map((item) => item.instanceId)
              .toList(growable: false);
          final gatheredPaperIds = gathered.objects.values
              .where(
                (item) =>
                    item.itemId == 'paper.scrap' &&
                    item.source == 'supply:renewable:paper.scrap',
              )
              .map((item) => item.instanceId)
              .toList(growable: false);
          expect(gatheredResidueIds, hasLength(2));
          expect(gatheredPaperIds, hasLength(3));
          expect(
            gatheredResidueIds.every(
              (id) => gathered.objects[id]!.acquiredRevision != null,
            ),
            isTrue,
          );

          final pulpRecipe = StreetScrapRecipe(
            id: 'ss.recipe.mix_pulp',
            phase: 1,
            station: 'recycler',
            operationId: 'mix',
            durationSeconds: 10,
            instructions: 'Mix sorted paper with filtered water.',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'paper.scrap', quantity: 3),
                StreetScrapRecipeInput(itemId: 'water.filtered', quantity: 1),
              ],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'paper.pulp', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['paper.scrap'],
              loss: 0,
              mode: 'weighted-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            stateEffect: const {
              'type': 'transformContainers',
              'containers': [
                {
                  'containerItemId': 'container.clean_jar',
                  'optional': true,
                  'requiredContentItemId': 'water.filtered',
                  'successContentItemId': null,
                  'failureContentItemId': null,
                },
              ],
            },
            failureMode: 'sameOutputsQualityLoss',
            failureOutcome: 'Paper pulp remains usable at reduced quality.',
            failureResolution: const StreetScrapFailureResolution(
              mode: 'sameOutputsQualityLoss',
              qualityLoss: 10,
            ),
            manualCheckpoints: [
              StreetScrapManualCheckpoint(
                prompt: 'Set the first mix ratio.',
                options: [
                  'Guess',
                  'Double all materials',
                  'Follow the marked range',
                ],
                correctOption: 2,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'Check the pulp consistency.',
                options: [
                  'Use the target consistency',
                  'Add unrelated material',
                  'Skip the check',
                ],
                correctOption: 0,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'When should mixing stop?',
                options: [
                  'Keep mixing forever',
                  'Ignore the target',
                  'Stop in the target band',
                ],
                correctOption: 2,
              ),
            ],
          );
          const pulpOperationId = 'q501-paper-pulp-operation';
          await StreetScrapCrafting.beginManual(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: pulpRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: [
              ...gatheredPaperIds,
              'supply-q501-pulp-jar-supply-0',
            ],
            toolInstanceIds: const [],
            operationId: pulpOperationId,
            commandId: 'q501-begin-paper-pulp',
            expectedRevision: session.snapshot.revision,
            contentVersion: '0.1.26',
          );
          for (final optionIndex in const [2, 0, 2]) {
            await StreetScrapCrafting.answerManualCheckpoint(
              session: session,
              inventoryCatalog: _inventoryCatalog,
              recipe: pulpRecipe,
              grids: _grids,
              operationId: pulpOperationId,
              optionIndex: optionIndex,
              expectedRevision: session.snapshot.revision,
            );
          }
          final gatheredPulp = _inventoryCatalog
              .inventoryFromJson(
                grids: _grids,
                json: Map<String, Object?>.from(
                  session.snapshot.state['inventory']! as Map,
                ),
              )
              .objects['$pulpOperationId-output-0']!;
          expect(gatheredPulp.itemId, 'paper.pulp');
          expect(gatheredPulp.acquiredRevision, isNotNull);

          final unpickRecipe = StreetScrapRecipe(
            id: 'ss.recipe.unpick_cloth',
            phase: 1,
            station: 'recycler',
            operationId: 'cut',
            durationSeconds: 10,
            instructions: 'Needle follows the cloth seam.',
            inputGroups: const [
              [StreetScrapRecipeInput(itemId: 'cloth.rag_piece', quantity: 1)],
            ],
            reusableTools: const ['tool.needle'],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'cloth.edge_scrap', quantity: 1),
              StreetScrapRecipeInput(itemId: 'cloth.thread_end', quantity: 2),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['cloth.rag_piece'],
              loss: 0,
              mode: 'capped-at-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            failureMode: 'explicitOutcome',
            failureOutcome: 'One cloth edge and one thread end remain.',
          );
          await StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: unpickRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: const ['q1-kit-rag'],
            toolInstanceIds: const ['q1-kit-needle'],
            commandId: 'craft-unpick-for-${route.orderId}',
            expectedRevision: session.snapshot.revision,
            manual: false,
            manualPoints: 0,
            outputInstanceId: (index) => 'q501-unpick-output-$index',
          );
          final joinThreadRecipe = StreetScrapRecipe(
            id: 'ss.recipe.join_thread',
            phase: 1,
            station: 'recycler',
            operationId: 'cut',
            durationSeconds: 10,
            instructions: 'Join the recovered thread ends.',
            inputGroups: const [
              [StreetScrapRecipeInput(itemId: 'cloth.thread_end', quantity: 3)],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['cloth.thread_end'],
              loss: 0,
              mode: 'weighted-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            failureMode: 'explicitOutcome',
            failureOutcome: 'Two thread ends remain; one is lost.',
          );
          await StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: joinThreadRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: [
              'q501-unpick-output-1',
              'q501-unpick-output-2',
              'q1-kit-thread',
            ],
            toolInstanceIds: const [],
            commandId: 'craft-thread-spool-for-${route.orderId}',
            expectedRevision: session.snapshot.revision,
            manual: false,
            manualPoints: 0,
            outputInstanceId: (_) => 'q501-recycle-thread-spool',
          );
          final glueRecipe = StreetScrapRecipe(
            id: 'ss.recipe.recycle_glue',
            phase: 1,
            station: 'recycler',
            operationId: 'mix',
            durationSeconds: 10,
            instructions: 'Mix residue and paper pulp into reclaimed glue.',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'adhesive.residue', quantity: 2),
                StreetScrapRecipeInput(itemId: 'paper.pulp', quantity: 1),
              ],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'adhesive.recycled', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['adhesive.residue'],
              loss: 0,
              mode: 'weighted-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            failureMode: 'explicitOutcome',
            failureOutcome: 'Reclaimed glue is produced at lower quality.',
          );
          await StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: glueRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: [...gatheredResidueIds, gatheredPulp.instanceId],
            toolInstanceIds: const [],
            commandId: 'craft-glue-for-${route.orderId}',
            expectedRevision: session.snapshot.revision,
            manual: false,
            manualPoints: 0,
            outputInstanceId: (_) => 'q501-recycled-glue',
          );
          final recycledProducts = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          expect(session.snapshot.state['recipeCompletionCounts'], {
            'ss.recipe.mix_pulp': 1,
            'ss.recipe.unpick_cloth': 1,
            'ss.recipe.join_thread': 1,
            'ss.recipe.recycle_glue': 1,
          });
          expect(
            recycledProducts.objects['q501-recycle-thread-spool']!.itemId,
            'cloth.thread_spool',
          );
          expect(
            recycledProducts.objects['q501-recycled-glue']!.itemId,
            'adhesive.recycled',
          );
        } else if (route.orderId == 'ss.order.advanced_fish') {
          const fishingRules = StreetScrapFishingRules(
            version: 1,
            castCost: 3,
            signalsPerCast: 3,
            successSignals: 2,
            perfectSignals: 3,
            signalHoldMilliseconds: 2000,
            basePromptWidthPercent: 30,
            preciseQualityBonus: 8,
            guaranteeAfterFailures: 2,
            freeNaturalBait: true,
            loanerRodAvailable: true,
            spots: [
              StreetScrapFishingSpot(
                id: 'dock_entrance',
                phase: 2,
                name: 'Old dock entrance',
              ),
            ],
            failureRewards: ['wood.driftwood', 'cloth.thread_end'],
          );
          await castStreetScrapLine(
            session: session,
            commandId: 'q501-advanced-fish-cast',
            expectedRevision: session.snapshot.revision,
            rules: fishingRules,
            spotId: 'dock_entrance',
            defaultStamina: 60,
          );
          for (var signal = 0; signal < fishingRules.signalsPerCast; signal++) {
            await resolveStreetScrapFishingSignal(
              session: session,
              commandId: 'q501-advanced-fish-signal-$signal',
              expectedRevision: session.snapshot.revision,
              rules: fishingRules,
              heldMilliseconds: 2000,
            );
          }
          await claimStreetScrapFishingResult(
            session: session,
            commandId: 'q501-claim-advanced-fish',
            expectedRevision: session.snapshot.revision,
            catalog: _inventoryCatalog,
            grids: _grids,
            backpackGridId: 'backpack',
          );
          var caughtInventory = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          final caughtFish = caughtInventory.objects.values.singleWhere(
            (item) => item.itemId == 'fish.raw',
          );
          expect(caughtFish.source, startsWith('fishing:'));
          caughtInventory = caughtInventory.addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'q501-fish-packaging',
              itemId: 'paper.packaging',
              source: 'scavenged:packaging-supply',
              quality: 55,
              traits: const {},
            ),
            'backpack',
          );
          await session.apply(
            commandId: 'q501-stock-fish-packaging',
            expectedRevision: session.snapshot.revision,
            reduce: (state) => StreetScrapReduction(
              state: {...state, 'inventory': caughtInventory.toJson()},
            ),
          );

          final filletRecipe = StreetScrapRecipe(
            id: 'ss.recipe.fillet_fish',
            phase: 2,
            station: 'dock',
            operationId: 'cut',
            durationSeconds: 10,
            instructions: 'Follow the fish-bone marks from start to end.',
            inputGroups: const [
              [StreetScrapRecipeInput(itemId: 'fish.raw', quantity: 1)],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 2),
              StreetScrapRecipeInput(itemId: 'fish.bone', quantity: 1),
            ],
            failureOutputs: const [
              StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 1),
              StreetScrapRecipeInput(itemId: 'fish.bone', quantity: 1),
              StreetScrapRecipeInput(itemId: 'food.scrap', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['fish.raw'],
              loss: 0,
              mode: 'capped-at-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            traitResolution: const {
              'inherit': [],
              'polarity': {
                'rich_ingredient': 'positive',
                'rough_cut': 'negative',
              },
              'success': {},
              'precise': {'rich_ingredient': true},
              'failure': {'rough_cut': true},
            },
            failureMode: 'explicitOutcome',
            failureOutcome:
                'One fish portion, one bone and food scrap remain on a miss.',
            failureResolution: const StreetScrapFailureResolution(
              mode: 'sameOutputsQualityLoss',
              qualityLoss: 10,
            ),
            manualCheckpoints: [
              StreetScrapManualCheckpoint(
                prompt: 'Where does the cut begin?',
                options: [
                  'At the marked fish-bone start',
                  'At the belly',
                  'At the tail',
                ],
                correctOption: 0,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'How does the cut move?',
                options: [
                  'Across the belly',
                  'Away from the bone',
                  'Along the bone marks',
                ],
                correctOption: 2,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'Where does the cut finish?',
                options: [
                  'Outside the head',
                  'At the start',
                  'At the marked endpoint',
                ],
                correctOption: 2,
              ),
            ],
          );
          const filletOperationId = 'q501-advanced-fish-fillet';
          await StreetScrapCrafting.beginManual(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: filletRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: [caughtFish.instanceId],
            toolInstanceIds: const [],
            operationId: filletOperationId,
            commandId: 'q501-begin-fish-fillet',
            expectedRevision: session.snapshot.revision,
            contentVersion: '0.1.26',
          );
          for (var checkpoint = 0; checkpoint < 3; checkpoint++) {
            await StreetScrapCrafting.answerManualCheckpoint(
              session: session,
              inventoryCatalog: _inventoryCatalog,
              recipe: filletRecipe,
              grids: _grids,
              operationId: filletOperationId,
              optionIndex: const [0, 2, 2][checkpoint],
              expectedRevision: session.snapshot.revision,
            );
          }
          final postFilletInventory = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          expect(
            postFilletInventory.objects.values
                .where((item) => item.itemId == 'fish.meat')
                .length,
            2,
          );
          expect(
            postFilletInventory.objects.values
                .where((item) => item.itemId == 'fish.bone')
                .length,
            1,
          );

          final fishPackRecipe = StreetScrapRecipe(
            id: 'ss.recipe.fish_pack',
            phase: 3,
            station: 'workbench',
            operationId: 'assemble',
            durationSeconds: 8,
            instructions: 'Pack two portions with one paper wrapper.',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 2),
                StreetScrapRecipeInput(itemId: 'paper.packaging', quantity: 1),
              ],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'fish.pack', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['fish.meat'],
              loss: 0,
              mode: 'preserve-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            failureMode: 'explicitOutcome',
            failureOutcome: 'Confirmed packaging has no failure branch.',
          );
          await StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: fishPackRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: const [
              'q501-advanced-fish-fillet-output-0',
              'q501-advanced-fish-fillet-output-1',
              'q501-fish-packaging',
            ],
            toolInstanceIds: const [],
            commandId: 'q501-pack-fish-for-order',
            expectedRevision: session.snapshot.revision,
            manual: false,
            manualPoints: 0,
            outputInstanceId: (_) => 'q501-advanced-fish-pack',
          );
          final packedInventory = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          expect(
            packedInventory.objects['q501-advanced-fish-pack']!.itemId,
            'fish.pack',
          );
          final fishMeatQuality = postFilletInventory.objects.values
              .where((item) => item.itemId == 'fish.meat')
              .map((item) => item.quality)
              .toList(growable: false);
          expect(
            packedInventory.objects['q501-advanced-fish-pack']!.quality,
            (fishMeatQuality.reduce((left, right) => left + right) / 2).round(),
          );
          expect(
            packedInventory.objects.containsKey(caughtFish.instanceId),
            isFalse,
          );
        } else if (route.orderId == 'ss.order.advanced_workbench') {
          var stocked = before;
          for (final (instanceId, itemId) in const [
            ('q501-workbench-chip-0', 'wood.chip'),
            ('q501-workbench-chip-1', 'wood.chip'),
            ('q501-workbench-chip-2', 'wood.chip'),
            ('q501-workbench-residue-a', 'adhesive.residue'),
            ('q501-workbench-residue-b', 'adhesive.residue'),
            ('q501-workbench-pulp', 'paper.pulp'),
            ('q501-workbench-binding-a', 'cloth.edge_scrap'),
            ('q501-workbench-binding-b', 'cloth.edge_scrap'),
          ]) {
            stocked = stocked.addAndPlaceFirstFit(
              _inventoryCatalog.createObject(
                instanceId: instanceId,
                itemId: itemId,
                source: 'scavenged:q5.01-workbench-supplies',
                quality: 58,
                traits: const {},
              ),
              'backpack',
            );
          }
          await session.apply(
            commandId: 'stock-${route.orderId}',
            expectedRevision: session.snapshot.revision,
            reduce: (state) => StreetScrapReduction(
              state: {...state, 'inventory': stocked.toJson()},
            ),
          );

          final recycledGlueRecipe = StreetScrapRecipe(
            id: 'ss.recipe.recycle_glue',
            phase: 1,
            station: 'recycler',
            operationId: 'mix',
            durationSeconds: 10,
            instructions: 'Mix residue and paper pulp into reclaimed glue.',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'adhesive.residue', quantity: 2),
                StreetScrapRecipeInput(itemId: 'paper.pulp', quantity: 1),
              ],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'adhesive.recycled', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['adhesive.residue'],
              loss: 0,
              mode: 'weighted-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            failureMode: 'explicitOutcome',
            failureOutcome: 'Reclaimed glue is produced at lower quality.',
          );
          await StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: recycledGlueRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: const [
              'q501-workbench-residue-a',
              'q501-workbench-residue-b',
              'q501-workbench-pulp',
            ],
            toolInstanceIds: const [],
            commandId: 'q501-workbench-make-glue',
            expectedRevision: session.snapshot.revision,
            manual: false,
            manualPoints: 0,
            outputInstanceId: (_) => 'q501-workbench-glue',
          );

          final rodRecipe = StreetScrapRecipe(
            id: 'ss.recipe.press_rod',
            phase: 3,
            station: 'workbench',
            operationId: 'align',
            durationSeconds: 10,
            instructions: 'Align wood chips, apply glue and clamp the rod.',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'wood.chip', quantity: 3),
                StreetScrapRecipeInput(
                  itemId: 'adhesive.recycled',
                  quantity: 1,
                ),
              ],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['wood.chip'],
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
                prompt: 'How should the wood chips be arranged?',
                options: [
                  'Cross-stack them',
                  'Use only one chip',
                  'Align three chips with the grain',
                ],
                correctOption: 2,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'Where should the adhesive go?',
                options: [
                  'Outside the clamp',
                  'Between touching surfaces',
                  'On one end only',
                ],
                correctOption: 1,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'When should the clamp be secured?',
                options: [
                  'After alignment and gluing',
                  'After removing the adhesive',
                  'On one end only',
                ],
                correctOption: 0,
              ),
            ],
          );
          const rodOperationId = 'q501-advanced-workbench-rod';
          await StreetScrapCrafting.beginManual(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: rodRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: const [
              'q501-workbench-chip-0',
              'q501-workbench-chip-1',
              'q501-workbench-chip-2',
              'q501-workbench-glue',
            ],
            toolInstanceIds: const [],
            operationId: rodOperationId,
            commandId: 'q501-workbench-begin-rod',
            expectedRevision: session.snapshot.revision,
            contentVersion: '0.1.26',
          );
          for (var checkpoint = 0; checkpoint < 3; checkpoint++) {
            await StreetScrapCrafting.answerManualCheckpoint(
              session: session,
              inventoryCatalog: _inventoryCatalog,
              recipe: rodRecipe,
              grids: _grids,
              operationId: rodOperationId,
              optionIndex: const [2, 1, 0][checkpoint],
              expectedRevision: session.snapshot.revision,
            );
          }

          final bindingRecipe = StreetScrapRecipe(
            id: 'ss.recipe.braid_binding',
            phase: 1,
            station: 'recycler',
            operationId: 'braid',
            durationSeconds: 10,
            instructions: 'Braid three cloth edges into one binding.',
            inputGroups: const [
              [StreetScrapRecipeInput(itemId: 'cloth.edge_scrap', quantity: 3)],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'cloth.binding', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['cloth.edge_scrap'],
              loss: 0,
              mode: 'weighted-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            failureMode: 'explicitOutcome',
            failureOutcome: 'The binding remains usable.',
          );
          await StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: bindingRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: const [
              'q501-unpick-output-0',
              'q501-workbench-binding-a',
              'q501-workbench-binding-b',
            ],
            toolInstanceIds: const [],
            commandId: 'q501-workbench-braid-binding',
            expectedRevision: session.snapshot.revision,
            manual: false,
            manualPoints: 0,
            outputInstanceId: (_) => 'q501-workbench-binding',
          );

          final awlRecipe = StreetScrapRecipe(
            id: 'ss.recipe.awl_bone',
            phase: 3,
            station: 'workbench',
            operationId: 'assemble',
            durationSeconds: 10,
            instructions: 'Fix the fish-bone point to the rod with a binding.',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'fish.bone', quantity: 1),
                StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 1),
                StreetScrapRecipeInput(itemId: 'cloth.binding', quantity: 1),
              ],
              [
                StreetScrapRecipeInput(itemId: 'metal.bar', quantity: 1),
                StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 1),
                StreetScrapRecipeInput(itemId: 'cloth.binding', quantity: 1),
              ],
            ],
            reusableTools: const [],
            outputs: const [
              StreetScrapRecipeInput(itemId: 'tool.awl', quantity: 1),
            ],
            quality: StreetScrapRecipeQualityRule(
              primaryInputs: const ['fish.bone', 'metal.bar', 'wood.rod'],
              loss: 0,
              mode: 'weighted-primary',
              masteryRevision: 1,
            ),
            retainedInputIds: const [],
            traitResolution: const {
              'inherit': [
                {
                  'inputItemId': 'wood.rod',
                  'map': {'cracked': 'cracked'},
                },
              ],
              'polarity': {'cracked': 'negative'},
              'success': {},
              'precise': {},
              'failure': {},
            },
            qualityTraitEffects: const [
              {
                'inputItemId': 'cloth.binding',
                'traitId': 'intact_fibre',
                'polarity': 'positive',
                'modifier': 3,
              },
              {
                'inputItemId': 'cloth.binding',
                'traitId': 'frayed',
                'polarity': 'negative',
                'modifier': -3,
              },
            ],
            failureMode: 'explicitOutcome',
            failureOutcome: 'The awl remains usable at reduced quality.',
            failureResolution: const StreetScrapFailureResolution(
              mode: 'sameOutputsQualityLoss',
              qualityLoss: 10,
            ),
            manualCheckpoints: [
              StreetScrapManualCheckpoint(
                prompt: 'What is placed first?',
                options: [
                  'Align the base to the shadow',
                  'Place the outer part',
                  'Skip alignment',
                ],
                correctOption: 0,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'How is the connector placed?',
                options: ['Anywhere', 'Discard it', 'Align it to the joint'],
                correctOption: 2,
              ),
              StreetScrapManualCheckpoint(
                prompt: 'What should be checked before submitting?',
                options: [
                  'Only the item name',
                  'All positions and fixing marks',
                  'Remove the reusable parts',
                ],
                correctOption: 1,
              ),
            ],
          );
          const awlOperationId = 'q501-advanced-workbench-awl';
          await StreetScrapCrafting.beginManual(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: awlRecipe,
            grids: _grids,
            gridId: 'backpack',
            inputGroupIndex: 0,
            inputInstanceIds: const [
              'q501-advanced-fish-fillet-output-2',
              'q501-advanced-workbench-rod-output-0',
              'q501-workbench-binding',
            ],
            toolInstanceIds: const [],
            operationId: awlOperationId,
            commandId: 'q501-workbench-begin-awl',
            expectedRevision: session.snapshot.revision,
            contentVersion: '0.1.26',
          );
          for (var checkpoint = 0; checkpoint < 3; checkpoint++) {
            await StreetScrapCrafting.answerManualCheckpoint(
              session: session,
              inventoryCatalog: _inventoryCatalog,
              recipe: awlRecipe,
              grids: _grids,
              operationId: awlOperationId,
              optionIndex: const [0, 2, 1][checkpoint],
              expectedRevision: session.snapshot.revision,
            );
          }
          final workbenchInventory = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          final craftedAwl = workbenchInventory.objects.values.singleWhere(
            (item) => item.itemId == 'tool.awl',
          );
          expect(craftedAwl.source, 'crafted:ss.recipe.awl_bone');
        } else {
          var deliveredInventory = before;
          for (var index = 0; index < route.itemIds.length; index++) {
            deliveredInventory = deliveredInventory.addAndPlaceFirstFit(
              _inventoryCatalog.createObject(
                instanceId: '${route.orderId}-$index',
                itemId: route.itemIds[index],
                source: route.source,
                quality: 55,
                traits: const {},
                acquiredRevision: order.requiredSource == null
                    ? null
                    : session.snapshot.revision + 1,
              ),
              'backpack',
            );
          }
          await session.apply(
            commandId: 'produce-${route.orderId}',
            expectedRevision: session.snapshot.revision,
            reduce: (state) => StreetScrapReduction(
              state: {...state, 'inventory': deliveredInventory.toJson()},
            ),
          );
        }
        expect(
          session.snapshot.state['chapter'],
          5,
          reason: 'Chapter before delivering ${route.orderId}',
        );
        await deliverStreetScrapOrder(
          session: session,
          commandId: 'deliver-${route.orderId}',
          expectedRevision: session.snapshot.revision,
          orderCatalog: orderCatalog,
          orderId: route.orderId,
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          itemInstanceIds: route.orderId == 'ss.order.advanced_recycle'
              ? const ['q501-recycle-thread-spool', 'q501-recycled-glue']
              : route.orderId == 'ss.order.advanced_search'
              ? _inventoryCatalog
                    .inventoryFromJson(
                      grids: _grids,
                      json: Map<String, Object?>.from(
                        session.snapshot.state['inventory']! as Map,
                      ),
                    )
                    .objects
                    .values
                    .where(
                      (item) =>
                          item.itemId == 'wood.chip' &&
                          item.source == 'fixed:old_street_exchange',
                    )
                    .take(2)
                    .map((item) => item.instanceId)
                    .toList(growable: false)
              : route.orderId == 'ss.order.advanced_fish'
              ? const ['q501-advanced-fish-pack']
              : route.orderId == 'ss.order.advanced_workbench'
              ? const ['q501-advanced-workbench-awl-output-0']
              : [
                  for (var index = 0; index < route.itemIds.length; index++)
                    '${route.orderId}-$index',
                ],
        );
        expectedTickets += order.rewardQuantity;
        expect(session.snapshot.state['exchangeTickets'], expectedTickets);
        expect(
          ((session.snapshot.state['completedOrderGroups']! as Map)['q5.01']
                  as List)
              .length,
          routes.indexOf(route) + 1,
        );
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q5.01'],
          isNull,
          reason: 'The cooking producer order still needs to be delivered.',
        );
      }

      const cookingOrderId = 'ss.order.advanced_cooking';
      final cookingOrder = orderCatalog[cookingOrderId]!;
      Future<List<String>> claimKitchenSupply(
        String suffix,
        String itemId, {
        String? vesselInstanceId,
      }) async {
        final commandId = 'q501-kitchen-supply-$suffix';
        await claimStreetScrapRenewableSupply(
          session: session,
          commandId: commandId,
          expectedRevision: session.snapshot.revision,
          supplyCatalog: _q501KitchenSupplyCatalog,
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          backpackGridId: 'backpack',
          itemId: itemId,
          vesselInstanceId: vesselInstanceId,
          maxStamina: 60,
        );
        if (itemId.startsWith('water.')) return [vesselInstanceId!];
        return [
          for (
            var index = 0;
            index < _q501KitchenSupplyCatalog[itemId]!.quantity;
            index++
          )
            'supply-$commandId-$index',
        ];
      }

      final mealBoxSheetOne = (await claimKitchenSupply(
        'meal-box-sheet-one',
        'metal.sheet',
      )).single;
      final mealBoxSheetTwo = (await claimKitchenSupply(
        'meal-box-sheet-two',
        'metal.sheet',
      )).single;
      final fastenerWire = (await claimKitchenSupply(
        'meal-box-fastener-wire',
        'metal.wire',
      )).first;
      final fastenerRecipe = StreetScrapRecipe(
        id: 'ss.recipe.bend_fastener',
        phase: 3,
        station: 'workbench',
        operationId: 'assemble',
        durationSeconds: 10,
        instructions: 'Bend the supplied metal wire into a fastener.',
        inputGroups: const [
          [StreetScrapRecipeInput(itemId: 'metal.wire', quantity: 1)],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'metal.fastener', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['metal.wire'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'sameOutputsQualityLoss',
        failureOutcome: 'The fastener remains usable at reduced quality.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'What is placed first?',
            options: [
              'Align the base',
              'Place the outside edge',
              'Skip alignment',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Where does the connector go?',
            options: ['Anywhere', 'At the marked joint', 'Discard it'],
            correctOption: 1,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'What is checked before submitting?',
            options: [
              'Only the name',
              'All positions and fixing marks',
              'Remove the parts',
            ],
            correctOption: 1,
          ),
        ],
      );
      const fastenerOperationId = 'q501-meal-box-fastener';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: fastenerRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: [fastenerWire],
        toolInstanceIds: const [],
        operationId: fastenerOperationId,
        commandId: 'begin-$fastenerOperationId',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.26',
      );
      for (final option in const [0, 1, 1]) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: fastenerRecipe,
          grids: _grids,
          operationId: fastenerOperationId,
          optionIndex: option,
          expectedRevision: session.snapshot.revision,
        );
      }
      final mealBoxRecipe = StreetScrapRecipe(
        id: 'ss.recipe.meal_box',
        phase: 4,
        station: 'workbench',
        operationId: 'assemble',
        durationSeconds: 10,
        instructions: 'Press the supplied metal sheets into a clean meal box.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'metal.sheet', quantity: 2),
            StreetScrapRecipeInput(itemId: 'metal.fastener', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'container.meal_box', quantity: 1),
        ],
        outputContainerStates: const {
          'container.meal_box': {'cleanliness': 'clean'},
        },
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['metal.sheet'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'sameOutputsQualityLoss',
        failureOutcome: 'The meal box remains usable at reduced quality.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'What is placed first?',
            options: [
              'Align the base',
              'Place the outside edge',
              'Skip alignment',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'Where does the connector go?',
            options: ['Anywhere', 'Discard it', 'At the marked joint'],
            correctOption: 2,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'What is checked before submitting?',
            options: [
              'Only the name',
              'Remove the reusable parts',
              'All positions and fixing marks',
            ],
            correctOption: 2,
          ),
        ],
      );
      const mealBoxOperationId = 'q501-assemble-meal-box';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: mealBoxRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: [
          mealBoxSheetOne,
          mealBoxSheetTwo,
          '$fastenerOperationId-output-0',
        ],
        toolInstanceIds: const [],
        operationId: mealBoxOperationId,
        commandId: 'begin-$mealBoxOperationId',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.26',
      );
      for (final option in const [0, 2, 2]) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: mealBoxRecipe,
          grids: _grids,
          operationId: mealBoxOperationId,
          optionIndex: option,
          expectedRevision: session.snapshot.revision,
        );
      }
      final kitchenStartStamina =
          session.snapshot.state['stamina'] as int? ?? 60;

      final foodJarOne = (await claimKitchenSupply(
        'food-jar-one',
        'container.clean_jar',
      )).single;
      final greensOne = await claimKitchenSupply('greens-one', 'food.greens');
      await claimKitchenSupply(
        'food-water-one',
        'water.filtered',
        vesselInstanceId: foodJarOne,
      );
      final cleanFoodRecipe = StreetScrapRecipe(
        id: 'ss.recipe.clean_food',
        phase: 4,
        station: 'kitchen',
        operationId: 'wash',
        durationSeconds: 8,
        instructions: 'Sort, rinse and inspect gathered food.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'food.greens', quantity: 2),
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
          ],
          [
            StreetScrapRecipeInput(itemId: 'food.greens', quantity: 2),
            StreetScrapRecipeInput(itemId: 'container.clean_jar', quantity: 1),
          ],
          [
            StreetScrapRecipeInput(itemId: 'food.edible', quantity: 2),
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
          ],
          [
            StreetScrapRecipeInput(itemId: 'food.edible', quantity: 2),
            StreetScrapRecipeInput(itemId: 'container.clean_jar', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 2),
        ],
        failureOutputs: const [
          StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 1),
          StreetScrapRecipeInput(itemId: 'food.scrap', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['food.greens', 'food.edible'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'reducedQualityOutput',
        failureOutcome: 'Inputs are consumed and output quality is reduced.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Remove the unusable part first.',
            options: [
              'Follow the marked area',
              'Keep spoiled parts',
              'Discard all food',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'How should the food be rinsed?',
            options: [
              'Rinse only the vessel',
              'Skip rinsing',
              'Cover the marked area evenly',
            ],
            correctOption: 2,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'What should be checked before finishing?',
            options: [
              'Confirm sorting and rinsing',
              'Treat wash water as boiled',
              'Spend extra food',
            ],
            correctOption: 0,
          ),
        ],
        stateEffect: const {
          'type': 'transformContainers',
          'containers': [
            {
              'containerItemId': 'container.clean',
              'optional': true,
              'requiredContentItemId': 'water.filtered',
              'successContentItemId': null,
              'failureContentItemId': null,
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
            },
            {
              'containerItemId': 'container.clean_jar',
              'optional': true,
              'requiredContentItemId': 'water.filtered',
              'successContentItemId': null,
              'failureContentItemId': null,
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
            },
          ],
        },
      );
      Future<List<String>> cleanFoodBatch(
        String operationId,
        List<String> greens,
        String jarId,
      ) async {
        await StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: cleanFoodRecipe,
          grids: _grids,
          gridId: 'backpack',
          inputGroupIndex: 1,
          inputInstanceIds: [...greens, jarId],
          toolInstanceIds: const [],
          operationId: operationId,
          commandId: 'begin-$operationId',
          expectedRevision: session.snapshot.revision,
          contentVersion: '0.1.26',
        );
        for (final option in const [0, 2, 0]) {
          await StreetScrapCrafting.answerManualCheckpoint(
            session: session,
            inventoryCatalog: _inventoryCatalog,
            recipe: cleanFoodRecipe,
            grids: _grids,
            operationId: operationId,
            optionIndex: option,
            expectedRevision: session.snapshot.revision,
          );
        }
        return ['$operationId-output-0', '$operationId-output-1'];
      }

      final cleanedFoodIds = <String>[
        ...await cleanFoodBatch('q501-clean-food-one', greensOne, foodJarOne),
      ];
      final foodJarTwo = (await claimKitchenSupply(
        'food-jar-two',
        'container.clean_jar',
      )).single;
      final greensTwo = await claimKitchenSupply('greens-two', 'food.greens');
      await claimKitchenSupply(
        'food-water-two',
        'water.filtered',
        vesselInstanceId: foodJarTwo,
      );
      cleanedFoodIds.addAll(
        await cleanFoodBatch('q501-clean-food-two', greensTwo, foodJarTwo),
      );

      final cookingWaterJar = (await claimKitchenSupply(
        'cooking-water-jar',
        'container.clean_jar',
      )).single;
      await claimKitchenSupply(
        'cooking-water',
        'water.filtered',
        vesselInstanceId: cookingWaterJar,
      );
      final cookingFuel = await claimKitchenSupply('boiling-fuel', 'fuel.dry');
      final boilWaterRecipe = StreetScrapRecipe(
        id: 'ss.recipe.boil_water',
        phase: 4,
        station: 'kitchen',
        operationId: 'heat',
        durationSeconds: 10,
        instructions: 'Boil the filtered water in its existing vessel.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
          ],
          [
            StreetScrapRecipeInput(itemId: 'container.clean_jar', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
          ],
        ],
        reusableTools: const [],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['container.clean', 'container.clean_jar'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome:
            'The filtered water remains in its vessel if boiling misses.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 0,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Which heat level should be set first?',
            options: ['Too low', 'Maximum heat', 'Stable heat'],
            correctOption: 2,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'How should the water temperature be maintained?',
            options: [
              'Follow the indicated zone',
              'Ignore the cue',
              'Turn off the heat',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'What confirms boiling is complete?',
            options: [
              'Only the quality number',
              'All heat steps match',
              'Ignore the boiling flag',
            ],
            correctOption: 1,
          ),
        ],
        stateEffect: const {
          'type': 'transformContainers',
          'containers': [
            {
              'containerItemId': 'container.clean',
              'optional': true,
              'requiredContentItemId': 'water.filtered',
              'successContentItemId': 'water.boiled',
              'failureContentItemId': 'water.filtered',
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
              'successRequiresBoiling': false,
              'failureRequiresBoiling': true,
              'preserveContainerContentQuality': true,
              'preserveContainerContentSource': true,
              'preserveContainerContentTraits': true,
            },
            {
              'containerItemId': 'container.clean_jar',
              'optional': true,
              'requiredContentItemId': 'water.filtered',
              'successContentItemId': 'water.boiled',
              'failureContentItemId': 'water.filtered',
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
              'successRequiresBoiling': false,
              'failureRequiresBoiling': true,
              'preserveContainerContentQuality': true,
              'preserveContainerContentSource': true,
              'preserveContainerContentTraits': true,
            },
          ],
        },
      );
      const boilOperationId = 'q501-boil-water';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: boilWaterRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 1,
        inputInstanceIds: [cookingWaterJar, cookingFuel.single],
        toolInstanceIds: const [],
        operationId: boilOperationId,
        commandId: 'begin-$boilOperationId',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.26',
      );
      for (final option in const [2, 0, 1]) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: boilWaterRecipe,
          grids: _grids,
          operationId: boilOperationId,
          optionIndex: option,
          expectedRevision: session.snapshot.revision,
        );
      }
      final boiledJar = _inventoryCatalog
          .inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          )
          .objects[cookingWaterJar]!;
      expect(boiledJar.containerState['contentItemId'], 'water.boiled');
      expect(
        boiledJar.containerState['contentSource'],
        'supply:renewable:water.filtered',
      );

      final sharedMealFuel = <String>[
        ...await claimKitchenSupply('meal-fuel-one', 'fuel.dry'),
        ...await claimKitchenSupply('meal-fuel-two', 'fuel.dry'),
      ];
      final suppliedKitchenInventory = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        suppliedKitchenInventory.objects.values
            .where(
              (item) =>
                  item.itemId == 'food.cleaned' &&
                  item.source == 'crafted:ss.recipe.clean_food',
            )
            .length,
        4,
      );
      expect(
        suppliedKitchenInventory.objects.values
            .where(
              (item) =>
                  item.itemId == 'fuel.dry' &&
                  item.source == 'supply:renewable:fuel.dry',
            )
            .length,
        2,
      );
      expect(
        suppliedKitchenInventory.objects.values
            .where((item) => item.itemId == 'container.clean_jar')
            .where(
              (item) => item.source == 'supply:renewable:container.clean_jar',
            )
            .length,
        4,
      );
      final producedMealBox =
          suppliedKitchenInventory.objects['$mealBoxOperationId-output-0']!;
      final mealBox = producedMealBox;
      expect(producedMealBox.itemId, 'container.meal_box');
      expect(producedMealBox.source, 'crafted:ss.recipe.meal_box');
      expect(producedMealBox.containerState['cleanliness'], 'clean');
      expect(session.snapshot.state['stamina'], kitchenStartStamina - 30);
      final sharedMealRecipe = StreetScrapRecipe(
        id: 'ss.recipe.shared_meal',
        phase: 5,
        station: 'kitchen',
        operationId: 'cook',
        durationSeconds: 15,
        instructions: 'Cook the shared meal with food, water and dry fuel.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 2),
            StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 1),
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 2),
          ],
          [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 2),
            StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 1),
            StreetScrapRecipeInput(itemId: 'container.clean_jar', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 2),
          ],
          [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 4),
            StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 2),
          ],
          [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 4),
            StreetScrapRecipeInput(itemId: 'container.clean_jar', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 2),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'meal.shared', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['food.cleaned', 'fish.meat'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        failureMode: 'explicitOutcome',
        failureOutcome: 'An unsuitable meal is produced at reduced quality.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Prepare the ingredients in which order?',
            options: [
              'Follow the preparation order',
              'Burn fuel first',
              'Skip inspection',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'How should the cooking heat be maintained?',
            options: [
              'Stable low heat',
              'Maximum heat throughout',
              'Turn off the heat',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'How should the meal be finished?',
            options: [
              'Check doneness and serve',
              'Keep raw food as the meal',
              'Discard the original vessel',
            ],
            correctOption: 0,
          ),
        ],
        stateEffect: const {
          'type': 'transformContainers',
          'containers': [
            {
              'containerItemId': 'container.clean',
              'optional': true,
              'requiredContentItemId': 'water.boiled',
              'successContentItemId': null,
              'failureContentItemId': null,
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
            },
            {
              'containerItemId': 'container.clean_jar',
              'optional': true,
              'requiredContentItemId': 'water.boiled',
              'successContentItemId': null,
              'failureContentItemId': null,
              'successCleanliness': 'utility',
              'failureCleanliness': 'utility',
            },
          ],
        },
      );
      const sharedMealOperationId = 'q501-shared-meal-cook';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: sharedMealRecipe,
        grids: _grids,
        gridId: 'backpack',
        inputGroupIndex: 3,
        inputInstanceIds: [
          ...cleanedFoodIds,
          cookingWaterJar,
          ...sharedMealFuel,
        ],
        toolInstanceIds: const [],
        operationId: sharedMealOperationId,
        commandId: 'begin-$sharedMealOperationId',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.26',
      );
      for (var checkpoint = 0; checkpoint < 3; checkpoint++) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: sharedMealRecipe,
          grids: _grids,
          operationId: sharedMealOperationId,
          optionIndex: 0,
          expectedRevision: session.snapshot.revision,
        );
      }
      expect(session.snapshot.state['stamina'], kitchenStartStamina - 30);
      final sharedMealOutputId = '$sharedMealOperationId-output-0';
      final cookedMeal = _inventoryCatalog
          .inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          )
          .objects[sharedMealOutputId]!;
      expect(cookedMeal.itemId, 'meal.shared');
      expect(cookedMeal.source, 'crafted:ss.recipe.shared_meal');
      final afterCooking = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final reusedWaterJar = afterCooking.objects[cookingWaterJar]!;
      expect(reusedWaterJar.itemId, 'container.clean_jar');
      expect(reusedWaterJar.containerState['contentItemId'], isNull);
      expect(reusedWaterJar.containerState['cleanliness'], 'utility');
      await packStreetScrapSharedMealIntoContainer(
        session: session,
        commandId: 'pack-$cookingOrderId',
        expectedRevision: session.snapshot.revision,
        catalog: _inventoryCatalog,
        grids: _grids,
        mealInstanceId: cookedMeal.instanceId,
        containerInstanceId: mealBox.instanceId,
      );
      final packedMealBox = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(packedMealBox.objects.containsKey(cookedMeal.instanceId), isFalse);
      expect(
        packedMealBox
            .objects[mealBox.instanceId]!
            .containerState['contentItemId'],
        'meal.shared',
      );
      expect(
        packedMealBox
            .objects[mealBox.instanceId]!
            .containerState['contentQuality'],
        cookedMeal.quality,
      );
      expect(
        packedMealBox.objects[mealBox.instanceId]!.provenance.last['kind'],
        'pack',
      );
      expect(
        session.snapshot.state['chapter'],
        5,
        reason: 'Chapter before delivering $cookingOrderId',
      );
      final cookingDelivery = await deliverStreetScrapOrder(
        session: session,
        commandId: 'deliver-$cookingOrderId',
        expectedRevision: session.snapshot.revision,
        orderCatalog: orderCatalog,
        orderId: cookingOrderId,
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceId: mealBox.instanceId,
      );
      expectedTickets += cookingOrder.rewardQuantity;
      expect(
        (cookingDelivery.result! as Map)['returnedContainerInstanceId'],
        mealBox.instanceId,
      );
      expect(session.snapshot.state['exchangeTickets'], expectedTickets);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.01'],
        isTrue,
      );
      expect(
        ((session.snapshot.state['completedOrderGroups']! as Map)['q5.01']
                as List)
            .toSet(),
        orderCatalog.completionGroups['q5.01'],
      );
      final finalInventory = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        finalInventory
            .objects[mealBox.instanceId]!
            .containerState['cleanliness'],
        'soiled',
      );

      // Continue from the actual five-producer order save through the stable
      // living goal, so q5.01 completion is verified as a real prerequisite
      // for q5.02 rather than injected by test setup. Inventory transfers below
      // are player board moves; every new item enters through an expedition or
      // the versioned renewable-supply command and every processed item uses
      // the same crafting reducer as gameplay.
      var reliefDay = 0;
      Future<void> ensureHousingStamina(int cost) async {
        while ((session.snapshot.state['stamina'] as int? ?? 60) < cost) {
          final rawProgress = session.snapshot.state['relief'];
          final progress = rawProgress is Map
              ? StreetScrapReliefProgress.fromJson(
                  Map<String, Object?>.from(rawProgress),
                )
              : StreetScrapReliefProgress.start(session.snapshot.savedAt);
          var now = session.snapshot.savedAt.add(Duration(days: reliefDay));
          if (progress.accrue(now).totalClaims == 0) {
            final nextClaimAt = progress.accrualAnchor.add(
              const Duration(days: 1),
            );
            if (now.isBefore(nextClaimAt)) now = nextClaimAt;
            reliefDay = now.difference(session.snapshot.savedAt).inDays;
          }
          await claimStreetScrapRelief(
            session: session,
            commandId: 'q5-e2e-relief-${session.snapshot.revision}',
            expectedRevision: session.snapshot.revision,
            now: now,
            maxStamina: 60,
          );
        }
      }

      Future<void> moveItemsToGrid(
        List<String> instanceIds,
        String gridId, {
        required String commandId,
      }) async {
        if (instanceIds.isEmpty) return;
        final current = _inventoryCatalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        var moved = current;
        for (final instanceId in instanceIds) {
          if (moved.placements[instanceId]?.gridId != gridId) {
            moved = moved.placeFirstFit(instanceId, gridId);
          }
        }
        await session.apply(
          commandId: commandId,
          expectedRevision: session.snapshot.revision,
          reduce: (state) => StreetScrapReduction(
            state: {...state, 'inventory': moved.toJson()},
          ),
        );
      }

      Future<List<String>> claimHousingSupply(
        String suffix,
        String itemId, {
        String? vesselInstanceId,
        String destinationGridId = 'backpack',
      }) async {
        final supply = _q501KitchenSupplyCatalog[itemId]!;
        await ensureHousingStamina(supply.staminaCost);
        var vesselId = vesselInstanceId;
        if (itemId.startsWith('water.') && vesselId == null) {
          final inventory = _inventoryCatalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          vesselId = inventory.objects.values
              .where(
                (item) =>
                    const {
                      'container.clean',
                      'container.clean_jar',
                      'container.used_intact',
                    }.contains(item.itemId) &&
                    item.containerState['cleanliness'] == 'clean' &&
                    item.containerState['contentItemId'] == null &&
                    inventory.placements[item.instanceId]?.gridId == 'backpack',
              )
              .map((item) => item.instanceId)
              .firstOrNull;
          if (vesselId == null) {
            final jars = await claimHousingSupply(
              '$suffix-clean-jar',
              'container.clean_jar',
            );
            vesselId = jars.single;
          }
        }
        // Claiming an empty vessel above also costs stamina; re-check the
        // water action after that nested supply claim.
        await ensureHousingStamina(supply.staminaCost);
        final commandId = 'q5-e2e-supply-$suffix';
        await claimStreetScrapRenewableSupply(
          session: session,
          commandId: commandId,
          expectedRevision: session.snapshot.revision,
          supplyCatalog: _q501KitchenSupplyCatalog,
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          backpackGridId: 'backpack',
          itemId: itemId,
          vesselInstanceId: vesselId,
          maxStamina: 60,
        );
        if (itemId.startsWith('water.')) return [vesselId!];
        final instanceIds = [
          for (var index = 0; index < supply.quantity; index++)
            'supply-$commandId-$index',
        ];
        if (destinationGridId != 'backpack') {
          await moveItemsToGrid(
            instanceIds,
            destinationGridId,
            commandId: 'q5-e2e-move-$suffix',
          );
        }
        return instanceIds;
      }

      final searchRules = _q501SearchRules();
      final boardInstanceIds = <String>[];
      for (var trip = 0; trip < 5; trip++) {
        await ensureHousingStamina(
          searchRules.movementCost + searchRules.investigationCost,
        );
        final commandId = 'q5-e2e-old-street-board-$trip';
        await startStreetScrapExpeditionCommand(
          session: session,
          commandId: '$commandId-start',
          expectedRevision: session.snapshot.revision,
          phase: 5,
          seed: 520 + trip,
          defaultStamina: 60,
          rules: searchRules,
        );
        await applyStreetScrapExpeditionCommand(
          session: session,
          commandId: '$commandId-search',
          expectedRevision: session.snapshot.revision,
          rules: searchRules,
          transition: (current) => current!
              .investigateFixed(
                rules: searchRules,
                optionIndex: 0,
                selectedVisibleTarget: true,
              )
              .expedition,
        );
        await applyStreetScrapExpeditionCommand(
          session: session,
          commandId: '$commandId-return',
          expectedRevision: session.snapshot.revision,
          rules: searchRules,
          transition: (current) => current!.returnHome(),
        );
        await claimStreetScrapExpeditionRewards(
          session: session,
          commandId: '$commandId-claim',
          expectedRevision: session.snapshot.revision,
          rules: searchRules,
          catalog: _inventoryCatalog,
          grids: _grids,
          backpackGridId: 'backpack',
        );
        final gatheredBoards = _inventoryCatalog
            .inventoryFromJson(
              grids: _grids,
              json: Map<String, Object?>.from(
                session.snapshot.state['inventory']! as Map,
              ),
            )
            .objects
            .values
            .where(
              (item) =>
                  item.itemId == 'wood.board' &&
                  item.source == 'fixed:old_street_exchange' &&
                  !boardInstanceIds.contains(item.instanceId),
            )
            .map((item) => item.instanceId)
            .toList(growable: false);
        expect(gatheredBoards, hasLength(2));
        boardInstanceIds.addAll(gatheredBoards);
        await moveItemsToGrid(
          gatheredBoards,
          'board',
          commandId: '$commandId-move-boards',
        );
      }
      expect(boardInstanceIds, hasLength(10));

      final sewStripRecipe = _q502Recipe(
        id: 'ss.recipe.sew_strip',
        phase: 0,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.rag_piece', quantity: 2),
          StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 1),
        ],
        outputItemId: 'cloth.repair_strip',
        primaryInputId: 'cloth.rag_piece',
        manual: false,
        station: 'tutorial',
        operationId: 'sew',
      );
      final firstRags = await claimHousingSupply(
        'sewing-rags-a',
        'cloth.rag_piece',
      );
      final firstSpool = (await claimHousingSupply(
        'sewing-spool-a',
        'cloth.thread_spool',
      )).single;
      final stripA = await _q502Craft(
        session: session,
        recipe: sewStripRecipe,
        inputIds: [firstRags[0], firstRags[1], firstSpool],
        operationId: 'q5-e2e-sew-strip-a',
        gridId: 'backpack',
      );
      final secondRags = await claimHousingSupply(
        'sewing-rags-b',
        'cloth.rag_piece',
      );
      final secondSpool = (await claimHousingSupply(
        'sewing-spool-b',
        'cloth.thread_spool',
      )).single;
      final stripB = await _q502Craft(
        session: session,
        recipe: sewStripRecipe,
        inputIds: [firstRags[2], secondRags[0], secondSpool],
        operationId: 'q5-e2e-sew-strip-b',
        gridId: 'backpack',
      );
      await moveItemsToGrid(
        secondRags.skip(1).toList(growable: false),
        'board',
        commandId: 'q5-e2e-store-spare-rags',
      );
      final patchworkRecipe = _q502Recipe(
        id: 'ss.recipe.patch_cloth',
        phase: 1,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.repair_strip', quantity: 2),
          StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 1),
        ],
        outputItemId: 'cloth.patchwork',
        primaryInputId: 'cloth.repair_strip',
        manual: false,
      );
      final patchSpool = (await claimHousingSupply(
        'patchwork-spool',
        'cloth.thread_spool',
      )).single;
      final patchwork = await _q502Craft(
        session: session,
        recipe: patchworkRecipe,
        inputIds: [stripA, stripB, patchSpool],
        operationId: 'q5-e2e-patchwork',
        gridId: 'backpack',
      );
      await moveItemsToGrid(
        [patchwork],
        'board',
        commandId: 'q5-e2e-stage-patchwork',
      );

      final bindingRecipe = _q502Recipe(
        id: 'ss.recipe.braid_binding',
        phase: 1,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.edge_scrap', quantity: 3),
        ],
        outputItemId: 'cloth.binding',
        primaryInputId: 'cloth.edge_scrap',
        manual: false,
      );
      final bindings = <String>[];
      for (var index = 0; index < 2; index++) {
        final edgeScraps = await claimHousingSupply(
          'binding-edge-$index',
          'cloth.edge_scrap',
        );
        bindings.add(
          await _q502Craft(
            session: session,
            recipe: bindingRecipe,
            inputIds: edgeScraps,
            operationId: 'q5-e2e-binding-$index',
            gridId: 'backpack',
          ),
        );
      }
      await moveItemsToGrid(
        bindings,
        'board',
        commandId: 'q5-e2e-stage-bindings',
      );

      final mixPulpRecipe = _q502Recipe(
        id: 'ss.recipe.mix_pulp',
        phase: 1,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'paper.scrap', quantity: 3),
          StreetScrapRecipeInput(itemId: 'water.filtered', quantity: 1),
        ],
        outputItemId: 'paper.pulp',
        primaryInputId: 'paper.scrap',
        manual: false,
        operationId: 'mix',
        stateEffect: const {
          'type': 'transformContainers',
          'containers': [
            {
              'containerItemId': 'container.clean_jar',
              'optional': true,
              'requiredContentItemId': 'water.filtered',
              'successContentItemId': null,
              'failureContentItemId': null,
            },
          ],
        },
      );
      final recycleGlueRecipe = _q502Recipe(
        id: 'ss.recipe.recycle_glue',
        phase: 1,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'adhesive.residue', quantity: 2),
          StreetScrapRecipeInput(itemId: 'paper.pulp', quantity: 1),
        ],
        outputItemId: 'adhesive.recycled',
        primaryInputId: 'adhesive.residue',
        manual: false,
      );
      final recycledGlueIds = <String>[];
      for (var index = 0; index < 3; index++) {
        final paper = await claimHousingSupply(
          'glue-paper-$index',
          'paper.scrap',
        );
        final waterVessel = (await claimHousingSupply(
          'glue-water-$index',
          'water.filtered',
        )).single;
        final residue = await claimHousingSupply(
          'glue-residue-$index',
          'adhesive.residue',
        );
        final pulp = await _q502Craft(
          session: session,
          recipe: mixPulpRecipe,
          inputIds: [...paper, waterVessel],
          operationId: 'q5-e2e-pulp-$index',
          gridId: 'backpack',
        );
        await moveItemsToGrid(
          [waterVessel],
          'board',
          commandId: 'q5-e2e-stage-glue-jar-$index',
        );
        recycledGlueIds.add(
          await _q502Craft(
            session: session,
            recipe: recycleGlueRecipe,
            inputIds: [...residue, pulp],
            operationId: 'q5-e2e-glue-$index',
            gridId: 'backpack',
          ),
        );
      }

      final coatingIds = <String>[];
      for (var index = 0; index < 3; index++) {
        coatingIds.add(
          (await claimHousingSupply(
            'waterproof-coating-$index',
            'material.waterproof_coating',
          )).single,
        );
      }
      final coatClothRecipe = _q502Recipe(
        id: 'ss.recipe.coat_cloth',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.patchwork', quantity: 1),
          StreetScrapRecipeInput(
            itemId: 'material.waterproof_coating',
            quantity: 1,
          ),
        ],
        outputItemId: 'cloth.waterproof',
        primaryInputId: 'cloth.patchwork',
        manual: false,
        operationId: 'coat',
      );
      await moveItemsToGrid(
        coatingIds,
        'board',
        commandId: 'q5-e2e-stage-waterproof-coatings',
      );
      final waterproofCloth = await _q502Craft(
        session: session,
        recipe: coatClothRecipe,
        inputIds: [patchwork, coatingIds[0]],
        operationId: 'q5-e2e-waterproof-cloth',
        gridId: 'board',
      );

      final pressPlasticRecipe = _q502Recipe(
        id: 'ss.recipe.press_plastic',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'plastic.scrap', quantity: 3),
          StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
        ],
        outputItemId: 'plastic.sheet',
        primaryInputId: 'plastic.scrap',
        manual: false,
        operationId: 'press',
      );
      final sealRecipe = _q502Recipe(
        id: 'ss.recipe.seal_part',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'plastic.sheet', quantity: 1),
          StreetScrapRecipeInput(
            itemId: 'material.waterproof_coating',
            quantity: 1,
          ),
        ],
        outputItemId: 'plastic.seal',
        primaryInputId: 'plastic.sheet',
        manual: true,
        operationId: 'coat',
      );
      final sealIds = <String>[];
      for (var index = 0; index < 2; index++) {
        final scraps = await claimHousingSupply(
          'plastic-scrap-$index',
          'plastic.scrap',
        );
        final fuel = (await claimHousingSupply(
          'plastic-fuel-$index',
          'fuel.dry',
        )).single;
        final sheet = await _q502Craft(
          session: session,
          recipe: pressPlasticRecipe,
          inputIds: [...scraps, fuel],
          operationId: 'q5-e2e-plastic-sheet-$index',
          gridId: 'backpack',
        );
        await moveItemsToGrid(
          [sheet],
          'board',
          commandId: 'q5-e2e-stage-plastic-sheet-$index',
        );
        sealIds.add(
          await _q502Craft(
            session: session,
            recipe: sealRecipe,
            inputIds: [sheet, coatingIds[index + 1]],
            operationId: 'q5-e2e-plastic-seal-$index',
            gridId: 'board',
          ),
        );
      }

      final nailBundleIds = <String>[];
      for (var index = 0; index < 4; index++) {
        nailBundleIds.add(
          (await claimHousingSupply(
            'nail-bundle-$index',
            'metal.nail_bundle',
          )).single,
        );
      }
      final assembleFrameRecipe = _q502Recipe(
        id: 'ss.recipe.assemble_frame',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'wood.board', quantity: 2),
          StreetScrapRecipeInput(itemId: 'metal.nail_bundle', quantity: 1),
          StreetScrapRecipeInput(itemId: 'adhesive.recycled', quantity: 1),
        ],
        outputItemId: 'wood.frame',
        primaryInputId: 'wood.board',
        manual: false,
        operationId: 'align',
      );
      await moveItemsToGrid(
        [nailBundleIds[0], recycledGlueIds[0]],
        'board',
        commandId: 'q5-e2e-stage-tarp-frame-inputs',
      );
      final tarpFrameId = await _q502Craft(
        session: session,
        recipe: assembleFrameRecipe,
        inputIds: [
          ...boardInstanceIds.take(2),
          nailBundleIds[0],
          recycledGlueIds[0],
        ],
        operationId: 'q5-e2e-frame',
        gridId: 'board',
      );
      final crateRecipe = _q502Recipe(
        id: 'ss.recipe.wooden_crate',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'wood.board', quantity: 4),
          StreetScrapRecipeInput(itemId: 'metal.nail_bundle', quantity: 2),
          StreetScrapRecipeInput(itemId: 'adhesive.recycled', quantity: 1),
        ],
        outputItemId: 'storage.wooden_crate',
        primaryInputId: 'wood.board',
        manual: true,
        operationId: 'align',
      );
      await moveItemsToGrid(
        [nailBundleIds[1], nailBundleIds[2], recycledGlueIds[1]],
        'board',
        commandId: 'q5-e2e-stage-crate-inputs',
      );
      final crateId = await _q502Craft(
        session: session,
        recipe: crateRecipe,
        inputIds: [
          ...boardInstanceIds.skip(2).take(4),
          nailBundleIds[1],
          nailBundleIds[2],
          recycledGlueIds[1],
        ],
        operationId: 'q5-e2e-crate',
        gridId: 'board',
      );

      await moveItemsToGrid(
        [nailBundleIds[3], recycledGlueIds[2]],
        'board',
        commandId: 'q5-e2e-stage-shelter-frame-inputs',
      );
      final shelterFrameId = await _q502Craft(
        session: session,
        recipe: assembleFrameRecipe,
        inputIds: [
          ...boardInstanceIds.skip(6).take(2),
          nailBundleIds[3],
          recycledGlueIds[2],
        ],
        operationId: 'q5-e2e-shelter-frame',
        gridId: 'board',
      );

      final wireIds = await claimHousingSupply('fastener-wire', 'metal.wire');
      final bendFastenerRecipe = _q502Recipe(
        id: 'ss.recipe.bend_fastener',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'metal.wire', quantity: 1),
        ],
        outputItemId: 'metal.fastener',
        primaryInputId: 'metal.wire',
        manual: false,
        operationId: 'assemble',
      );
      final fastenerIds = <String>[];
      for (var index = 0; index < wireIds.length; index++) {
        fastenerIds.add(
          await _q502Craft(
            session: session,
            recipe: bendFastenerRecipe,
            inputIds: [wireIds[index]],
            operationId: 'q5-e2e-fastener-$index',
            gridId: 'backpack',
          ),
        );
      }
      await moveItemsToGrid(
        fastenerIds,
        'board',
        commandId: 'q5-e2e-stage-fasteners',
      );

      final tarpRecipe = _q502Recipe(
        id: 'ss.recipe.tarp',
        phase: 3,
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.waterproof', quantity: 1),
          StreetScrapRecipeInput(itemId: 'cloth.binding', quantity: 2),
          StreetScrapRecipeInput(itemId: 'wood.frame', quantity: 1),
        ],
        outputItemId: 'structure.tarp',
        primaryInputId: 'cloth.waterproof',
        manual: true,
        operationId: 'align',
      );
      await moveItemsToGrid(
        [waterproofCloth],
        'board',
        commandId: 'q5-e2e-stage-tarp-fabric',
      );
      final tarpId = await _q502Craft(
        session: session,
        recipe: tarpRecipe,
        inputIds: [waterproofCloth, ...bindings, tarpFrameId],
        operationId: 'q5-e2e-tarp',
        gridId: 'board',
      );

      final shelterRecipe = StreetScrapRecipe(
        id: 'ss.recipe.shelter',
        phase: 5,
        station: 'workbench',
        operationId: 'align',
        durationSeconds: 10,
        instructions: 'Align the tarp, frame and waterproof seals.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'structure.tarp', quantity: 1),
            StreetScrapRecipeInput(itemId: 'wood.frame', quantity: 1),
            StreetScrapRecipeInput(itemId: 'plastic.seal', quantity: 2),
          ],
        ],
        reusableTools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'structure.shelter', quantity: 1),
        ],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['structure.tarp', 'wood.frame'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        traitResolution: const {
          'inherit': [
            {
              'inputItemId': 'structure.tarp',
              'map': {'joint_reinforced': 'joint_reinforced'},
            },
            {
              'inputItemId': 'wood.frame',
              'map': {'joint_reinforced': 'joint_reinforced'},
            },
          ],
          'polarity': {'joint_reinforced': 'positive'},
          'success': {},
          'precise': {},
          'failure': {},
        },
        failureMode: 'sameOutputsQualityLoss',
        failureOutcome: 'The shelter remains usable at reduced quality.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Which marks should align first?',
            options: ['Color only', 'Cross the ends', 'Both end marks'],
            correctOption: 2,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'How should the joint angle be checked?',
            options: ['Any angle', 'Within the guide tolerance', 'Skip marks'],
            correctOption: 1,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'What confirms final placement?',
            options: [
              'Joint and outline match',
              'Add extra material',
              'Remove retained parts',
            ],
            correctOption: 0,
          ),
        ],
      );
      const shelterOperationId = 'q5-e2e-shelter';
      await moveItemsToGrid(
        sealIds,
        'board',
        commandId: 'q5-e2e-stage-shelter-seals',
      );
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: shelterRecipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: [tarpId, shelterFrameId, ...sealIds],
        toolInstanceIds: const [],
        operationId: shelterOperationId,
        commandId: 'q5-e2e-begin-shelter',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.26',
      );
      for (final option in const [2, 1, 0]) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: shelterRecipe,
          grids: _grids,
          operationId: shelterOperationId,
          optionIndex: option,
          expectedRevision: session.snapshot.revision,
        );
      }

      final chestRecipe = StreetScrapRecipe(
        id: 'ss.recipe.reinforced_chest',
        phase: 5,
        station: 'workbench',
        operationId: 'align',
        durationSeconds: 10,
        instructions: 'Reinforce the wooden crate with boards and fasteners.',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'storage.wooden_crate', quantity: 1),
            StreetScrapRecipeInput(itemId: 'wood.board', quantity: 2),
            StreetScrapRecipeInput(itemId: 'metal.fastener', quantity: 2),
          ],
        ],
        reusableTools: const [],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['storage.wooden_crate'],
          loss: 0,
          mode: 'preserve-primary',
          masteryRevision: 2,
        ),
        retainedInputIds: const ['storage.wooden_crate'],
        stateEffect: const {
          'type': 'transformObject',
          'fromItemId': 'storage.wooden_crate',
          'toItemId': 'storage.reinforced_chest',
          'requireEmptyContainer': true,
        },
        failureMode: 'sameOutputsQualityLoss',
        failureOutcome: 'The reinforced chest remains usable at lower quality.',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          StreetScrapManualCheckpoint(
            prompt: 'Which parts are aligned first?',
            options: [
              'Board edges and corner marks',
              'Outside color',
              'Fasteners',
            ],
            correctOption: 0,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'How are the reinforcing boards secured?',
            options: [
              'Glue only',
              'Fasteners along the joint',
              'Overlap the lid',
            ],
            correctOption: 1,
          ),
          StreetScrapManualCheckpoint(
            prompt: 'What is checked after assembly?',
            options: [
              'Stable corners and working lid',
              'Color only',
              'Unlimited capacity',
            ],
            correctOption: 0,
          ),
        ],
      );
      const chestOperationId = 'q5-e2e-chest-upgrade';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: _inventoryCatalog,
        recipe: chestRecipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: [
          crateId,
          ...boardInstanceIds.skip(8),
          ...fastenerIds,
        ],
        toolInstanceIds: const [],
        operationId: chestOperationId,
        commandId: 'q5-e2e-begin-chest-upgrade',
        expectedRevision: session.snapshot.revision,
        contentVersion: '0.1.26',
      );
      for (final option in const [0, 1, 0]) {
        await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: _inventoryCatalog,
          recipe: chestRecipe,
          grids: _grids,
          operationId: chestOperationId,
          optionIndex: option,
          expectedRevision: session.snapshot.revision,
        );
      }
      final completedHousingInventory = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        completedHousingInventory
            .objects['$shelterOperationId-output-0']!
            .itemId,
        'structure.shelter',
      );
      expect(
        completedHousingInventory.objects[crateId]!.itemId,
        'storage.reinforced_chest',
        reason: 'The chest upgrade retains the original crate identity.',
      );
      final placement = await placeStreetScrapChapterFiveStructures(
        session: session,
        commandId: 'q5-e2e-place-housing',
        expectedRevision: session.snapshot.revision,
        catalog: _inventoryCatalog,
        grids: _grids,
        shelterInstanceId: '$shelterOperationId-output-0',
        shelterGridId: 'board',
        chestInstanceId: crateId,
        chestGridId: 'board',
      );
      expect((placement.result! as Map)['q5.02Complete'], isFalse);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.01'],
        isTrue,
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.02'],
        isNull,
      );

      final leftovers = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      await moveItemsToGrid(
        leftovers.placements.values
            .where((placement) => placement.gridId == 'backpack')
            .map((placement) => placement.instanceId)
            .toList(growable: false),
        'board',
        commandId: 'q5-e2e-clear-backpack-for-cycle-orders',
      );

      for (var orderNumber = 1; orderNumber <= 5; orderNumber++) {
        final mineralPacks = <String>[
          ...(await claimHousingSupply(
            'cycle-$orderNumber-a',
            'material.mineral_pack',
            destinationGridId: 'backpack',
          )),
          ...(await claimHousingSupply(
            'cycle-$orderNumber-b',
            'material.mineral_pack',
            destinationGridId: 'backpack',
          )),
        ];
        await deliverStreetScrapOrder(
          session: session,
          commandId: 'q5-e2e-deliver-cycle-$orderNumber',
          expectedRevision: session.snapshot.revision,
          orderCatalog: _orderCatalog,
          orderId: 'ss.order.wall',
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          itemInstanceIds: mineralPacks,
        );
        expect(session.snapshot.state['completedCycleOrders'], orderNumber);
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q5.02'],
          orderNumber == 5 ? isTrue : isNull,
          reason: 'q5.02 completes only after the fifth ordinary order.',
        );
      }
      expect(session.snapshot.state['exchangeTickets'], expectedTickets + 20);

      final reliefProgressBeforeFinish = StreetScrapReliefProgress.fromJson(
        Map<String, Object?>.from(session.snapshot.state['relief']! as Map),
      );
      final reliefFinishAt = session.snapshot.savedAt.add(
        Duration(days: reliefDay + 14),
      );
      await expectLater(
        finishStreetScrapRelief(
          session: session,
          commandId: 'q5-e2e-finish-without-warning',
          expectedRevision: session.snapshot.revision,
          now: reliefFinishAt,
        ),
        throwsStateError,
      );
      await acknowledgeStreetScrapReliefStop(
        session: session,
        commandId: 'q5-e2e-acknowledge-relief-warning',
        expectedRevision: session.snapshot.revision,
      );
      final reliefFinish = await finishStreetScrapRelief(
        session: session,
        commandId: 'q5-e2e-finish-relief',
        expectedRevision: session.snapshot.revision,
        now: reliefFinishAt,
      );
      final expectedReliefClaims = reliefProgressBeforeFinish
          .accrue(reliefFinishAt)
          .totalClaims;
      expect(
        (reliefFinish.result! as Map)['reliefClaims'],
        expectedReliefClaims,
      );
      expect(session.snapshot.state['chapterSupplyBalance'], 80);
      expect(session.snapshot.state['reliefTransitionSupplyGranted'], isTrue);
      expect(
        StreetScrapReliefProgress.fromJson(
          Map<String, Object?>.from(session.snapshot.state['relief']! as Map),
        ).ended,
        isTrue,
      );
      await session.close();
    },
  );

  test('accepted order requires fresh declared recipe activity', () async {
    final catalog = StreetScrapOrderCatalog.fromOrders([
      StreetScrapOrder.fromJson(
        {
          'id': 'ss.order.activity-test',
          'phase': 5,
          'acceptedItems': ['material.mud'],
          'quantity': 1,
          'reward': {'currency': 'exchangeTickets', 'quantity': 1},
          'countsTowardCycle': false,
          'returnContainer': false,
          'requiresAcceptance': true,
          'requiredRecipes': ['ss.recipe.unpick_cloth'],
        },
        itemIds: const {'material.mud'},
        recipeIds: const {'ss.recipe.unpick_cloth'},
      ),
    ]);
    final session = await _session('orders-fresh-recipe-activity');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'activity-mud',
            itemId: 'material.mud',
            source: 'test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        );
    await _setup(session, chapter: 5, inventory: inventory);
    await acceptStreetScrapOrder(
      session: session,
      commandId: 'accept-activity-order',
      expectedRevision: 1,
      orderCatalog: catalog,
      orderId: 'ss.order.activity-test',
    );
    await expectLater(
      deliverStreetScrapOrder(
        session: session,
        commandId: 'deliver-before-recipe',
        expectedRevision: 2,
        orderCatalog: catalog,
        orderId: 'ss.order.activity-test',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        itemInstanceIds: const ['activity-mud'],
      ),
      throwsA(isA<StateError>()),
    );
    await session.apply(
      commandId: 'record-recipe-activity',
      expectedRevision: 2,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'recipeCompletionCounts': {'ss.recipe.unpick_cloth': 1},
        },
      ),
    );
    await deliverStreetScrapOrder(
      session: session,
      commandId: 'deliver-after-recipe',
      expectedRevision: 3,
      orderCatalog: catalog,
      orderId: 'ss.order.activity-test',
      inventoryCatalog: _inventoryCatalog,
      grids: _grids,
      itemInstanceIds: const ['activity-mud'],
    );
    expect(session.snapshot.state['exchangeTickets'], 1);
    expect(session.snapshot.state['acceptedOrderContexts'], isEmpty);
    await session.close();
  });

  test('accepted scavenging order rejects old source events', () async {
    final catalog = StreetScrapOrderCatalog.fromOrders([
      StreetScrapOrder.fromJson(
        {
          'id': 'ss.order.source-test',
          'phase': 5,
          'acceptedItems': ['wood.board'],
          'quantity': 1,
          'reward': {'currency': 'exchangeTickets', 'quantity': 1},
          'countsTowardCycle': false,
          'returnContainer': false,
          'requiresAcceptance': true,
          'requiredSource': 'fixed:old_street_exchange',
        },
        itemIds: const {'wood.board'},
      ),
    ]);
    final session = await _session('orders-source-event-freshness');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'source-board',
            itemId: 'wood.board',
            source: 'fixed:old_street_exchange',
            quality: 70,
            traits: const {},
            acquiredRevision: 1,
          ),
          'backpack',
        );
    await _setup(session, chapter: 5, inventory: inventory);
    await acceptStreetScrapOrder(
      session: session,
      commandId: 'accept-source-order',
      expectedRevision: 1,
      orderCatalog: catalog,
      orderId: 'ss.order.source-test',
    );
    await expectLater(
      deliverStreetScrapOrder(
        session: session,
        commandId: 'deliver-old-source',
        expectedRevision: 2,
        orderCatalog: catalog,
        orderId: 'ss.order.source-test',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        itemInstanceIds: const ['source-board'],
      ),
      throwsA(isA<StateError>()),
    );
    await session.apply(
      commandId: 'record-new-source',
      expectedRevision: 2,
      reduce: (state) {
        final nextInventory = _inventoryCatalog
            .emptyInventory(grids: _grids)
            .addAndPlaceFirstFit(
              _inventoryCatalog.createObject(
                instanceId: 'source-board',
                itemId: 'wood.board',
                source: 'fixed:old_street_exchange',
                quality: 70,
                traits: const {},
                acquiredRevision: 3,
              ),
              'backpack',
            );
        return StreetScrapReduction(
          state: {...state, 'inventory': nextInventory.toJson()},
        );
      },
    );
    await deliverStreetScrapOrder(
      session: session,
      commandId: 'deliver-new-source',
      expectedRevision: 3,
      orderCatalog: catalog,
      orderId: 'ss.order.source-test',
      inventoryCatalog: _inventoryCatalog,
      grids: _grids,
      itemInstanceIds: const ['source-board'],
    );
    expect(session.snapshot.state['exchangeTickets'], 1);
    await session.close();
  });

  test('cycle order consumes selected items and awards exactly once', () async {
    final session = await _session('orders-wall-success');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'mud-a',
            itemId: 'material.mud',
            source: 'test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        )
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'mud-b',
            itemId: 'material.mud',
            source: 'test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        );
    await _setup(session, chapter: 5, inventory: inventory);
    final result = await deliverStreetScrapOrder(
      session: session,
      commandId: 'wall-delivery-1',
      expectedRevision: 1,
      orderCatalog: _orderCatalog,
      orderId: 'ss.order.wall',
      inventoryCatalog: _inventoryCatalog,
      grids: _grids,
      itemInstanceIds: const ['mud-a', 'mud-b'],
    );
    expect((result.result! as Map)['rewardQuantity'], 4);
    expect(session.snapshot.state['exchangeTickets'], 4);
    expect(session.snapshot.state['completedCycleOrders'], 1);
    final updated = _inventoryCatalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(updated.objects, isEmpty);

    final retry = await deliverStreetScrapOrder(
      session: session,
      commandId: 'wall-delivery-1',
      expectedRevision: 1,
      orderCatalog: _orderCatalog,
      orderId: 'ss.order.wall',
      inventoryCatalog: _inventoryCatalog,
      grids: _grids,
      itemInstanceIds: const ['mud-a', 'mud-b'],
    );
    expect(retry.wasDuplicate, isTrue);
    expect(session.snapshot.state['exchangeTickets'], 4);
    expect(session.snapshot.state['completedCycleOrders'], 1);
    await session.close();
  });

  test(
    'invalid order item or chapter leaves inventory and reward untouched',
    () async {
      final session = await _session('orders-wall-reject');
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'mineral-a',
              itemId: 'material.mineral_pack',
              source: 'test',
              quality: 50,
              traits: const {},
            ),
            'backpack',
          );
      await _setup(session, chapter: 4, inventory: inventory);
      await expectLater(
        deliverStreetScrapOrder(
          session: session,
          commandId: 'wall-delivery-locked',
          expectedRevision: 1,
          orderCatalog: _orderCatalog,
          orderId: 'ss.order.wall',
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          itemInstanceIds: const ['mineral-a', 'mineral-a'],
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['exchangeTickets'], 0);
      await session.close();
    },
  );

  test(
    'the fifth ordinary order completes q5.02 after structures are placed',
    () async {
      final session = await _session('q502-fifth-cycle-order');
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'q502-mud-a',
              itemId: 'material.mud',
              source: 'test',
              quality: 50,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'q502-mud-b',
              itemId: 'material.mud',
              source: 'test',
              quality: 50,
              traits: const {},
            ),
            'backpack',
          );
      await _setup(
        session,
        chapter: 5,
        inventory: inventory,
        tasks: {
          'q5.01': true,
          'q5.02.shelterPlaced': true,
          'q5.02.chestPlaced': true,
        },
      );
      await session.apply(
        commandId: 'q502-existing-structure-state',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'completedCycleOrders': 4,
            'homeStructures': {
              'q5.02.shelter': {'furnitureSlot': 'home-slot-2'},
            },
            'storageFurniture': {
              'chapter5.reinforced_chest': {'furnitureSlot': 'home-slot-3'},
            },
          },
        ),
      );
      await deliverStreetScrapOrder(
        session: session,
        commandId: 'q502-fifth-order',
        expectedRevision: 2,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.wall',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        itemInstanceIds: const ['q502-mud-a', 'q502-mud-b'],
      );
      expect(session.snapshot.state['completedCycleOrders'], 5);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.02'],
        isTrue,
      );
      await session.close();
    },
  );

  test(
    'chapter-five structures and five ordinary orders complete the goal in one save',
    () async {
      final session = await _session(
        'q502-complete-progression',
        chapterFive: true,
      );
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'q502-shelter',
              itemId: 'structure.shelter',
              source: 'test:chapter-five',
              quality: 54,
              traits: const {'joint_reinforced': true},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'q502-chest',
              itemId: 'storage.reinforced_chest',
              source: 'test:chapter-five',
              quality: 54,
              traits: const {},
            ),
            'backpack',
          );
      await _setup(
        session,
        chapter: 5,
        inventory: inventory,
        tasks: {'q5.01': true},
      );

      final placement = await placeStreetScrapChapterFiveStructures(
        session: session,
        commandId: 'q502-place-home-structures',
        expectedRevision: session.snapshot.revision,
        catalog: _inventoryCatalog,
        grids: _grids,
        shelterInstanceId: 'q502-shelter',
        shelterGridId: 'backpack',
        chestInstanceId: 'q502-chest',
        chestGridId: 'backpack',
      );
      expect((placement.result! as Map)['q5.02Complete'], isFalse);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q5.02'],
        isNull,
      );
      expect(
        session.snapshot.state['homeStructures']! as Map,
        contains('q5.02.shelter'),
      );
      expect(
        session.snapshot.state['storageFurniture']! as Map,
        contains('chapter5.reinforced_chest'),
      );

      for (var orderNumber = 1; orderNumber <= 5; orderNumber++) {
        final currentInventory = _inventoryCatalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        final stockedInventory = currentInventory
            .addAndPlaceFirstFit(
              _inventoryCatalog.createObject(
                instanceId: 'q502-mud-$orderNumber-a',
                itemId: 'material.mud',
                source: 'test:chapter-five-cycle-$orderNumber',
                quality: 50,
                traits: const {},
              ),
              'backpack',
            )
            .addAndPlaceFirstFit(
              _inventoryCatalog.createObject(
                instanceId: 'q502-mud-$orderNumber-b',
                itemId: 'material.mud',
                source: 'test:chapter-five-cycle-$orderNumber',
                quality: 50,
                traits: const {},
              ),
              'backpack',
            );
        await session.apply(
          commandId: 'q502-stock-cycle-$orderNumber',
          expectedRevision: session.snapshot.revision,
          reduce: (state) => StreetScrapReduction(
            state: {...state, 'inventory': stockedInventory.toJson()},
          ),
        );
        await deliverStreetScrapOrder(
          session: session,
          commandId: 'q502-complete-cycle-$orderNumber',
          expectedRevision: session.snapshot.revision,
          orderCatalog: _orderCatalog,
          orderId: 'ss.order.wall',
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          itemInstanceIds: [
            'q502-mud-$orderNumber-a',
            'q502-mud-$orderNumber-b',
          ],
        );
        expect(session.snapshot.state['completedCycleOrders'], orderNumber);
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q5.02'],
          orderNumber == 5 ? isTrue : isNull,
          reason: 'q5.02 must unlock only after ordinary order $orderNumber.',
        );
      }
      expect(session.snapshot.state['exchangeTickets'], 20);
      expect(
        ((session.snapshot.state['tutorialTasks']! as Map)['q5.02'] as bool),
        isTrue,
      );
      await session.close();
    },
  );

  test(
    'fish order accepts either one whole fish or two fish portions',
    () async {
      final session = await _session('orders-fish-alternative');
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'fish-meat-a',
              itemId: 'fish.meat',
              source: 'test',
              quality: 60,
              traits: const {},
            ),
            'backpack',
          )
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'fish-meat-b',
              itemId: 'fish.meat',
              source: 'test',
              quality: 60,
              traits: const {},
            ),
            'backpack',
          );
      await _setup(session, chapter: 2, inventory: inventory);
      await deliverStreetScrapOrder(
        session: session,
        commandId: 'fish-order-meat-path',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.fish',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        itemInstanceIds: const ['fish-meat-a', 'fish-meat-b'],
      );
      expect(session.snapshot.state['exchangeTickets'], 3);
      expect(session.snapshot.state['completedCycleOrders'], 1);
      final remaining = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(remaining.objects, isEmpty);
      await session.close();
    },
  );

  test('meal order rejects failed soup and preserves its vessel', () async {
    final session = await _session('orders-meal-reject');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'failed-meal-box',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 50,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.failed',
              'contentQuality': 20,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await _setup(
      session,
      chapter: 4,
      inventory: inventory,
      tasks: const {'q4.02': true},
    );
    await expectLater(
      deliverStreetScrapOrder(
        session: session,
        commandId: 'meal-failed-delivery',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.meal',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceId: 'failed-meal-box',
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.revision, 1);
    expect(session.snapshot.state['exchangeTickets'], 0);
    final after = _inventoryCatalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(
      after.objects['failed-meal-box']!.containerState['contentItemId'],
      'meal.failed',
    );
    await session.close();
  });

  test(
    'failed meal recovery returns three original boxes atomically',
    () async {
      final session = await _session('orders-failed-meal-recovery');
      var inventory = _inventoryCatalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 3; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'failed-meal-box-$index',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 50 + index,
            traits: const {},
            containerState: {
              'contentItemId': 'meal.failed',
              'contentQuality': 20 + index,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
      }
      await _setup(
        session,
        chapter: 4,
        inventory: inventory,
        tasks: const {'q4.02': true},
      );

      await expectLater(
        deliverStreetScrapOrder(
          session: session,
          commandId: 'failed-meal-recovery-incomplete',
          expectedRevision: 1,
          orderCatalog: _orderCatalog,
          orderId: 'ss.order.failed_meal_recycle',
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          containerInstanceIds: const [
            'failed-meal-box-0',
            'failed-meal-box-1',
          ],
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['exchangeTickets'], 0);

      final result = await deliverStreetScrapOrder(
        session: session,
        commandId: 'failed-meal-recovery-complete',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.failed_meal_recycle',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceIds: const [
          'failed-meal-box-0',
          'failed-meal-box-1',
          'failed-meal-box-2',
        ],
      );
      expect((result.result! as Map)['rewardQuantity'], 1);
      expect((result.result! as Map)['containerInstanceIds'], hasLength(3));
      expect(session.snapshot.state['exchangeTickets'], 1);
      expect(session.snapshot.state['completedCycleOrders'] ?? 0, 0);
      final after = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        after.objects.keys,
        containsAll([
          'failed-meal-box-0',
          'failed-meal-box-1',
          'failed-meal-box-2',
        ]),
      );
      for (var index = 0; index < 3; index++) {
        final returned = after.objects['failed-meal-box-$index']!;
        expect(returned.containerState['contentItemId'], isNull);
        expect(returned.containerState['lastContentItemId'], 'meal.failed');
        expect(returned.containerState['cleanliness'], 'soiled');
      }
      await session.close();
    },
  );

  test(
    'insulated order consumes the filled box and soup for eight tickets',
    () async {
      final session = await _session('orders-insulated-success');
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'filled-insulated-box',
              itemId: 'container.meal_box_insulated',
              source: 'test',
              quality: 55,
              traits: const {},
              containerState: const {
                'contentItemId': 'meal.soup_basic',
                'contentQuality': 60,
                'cleanliness': 'clean',
              },
            ),
            'backpack',
          );
      await _setup(session, chapter: 4, inventory: inventory);
      final result = await deliverStreetScrapOrder(
        session: session,
        commandId: 'insulated-delivery',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.insulated',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceId: 'filled-insulated-box',
      );
      expect((result.result! as Map)['rewardQuantity'], 8);
      expect(
        (result.result! as Map)['consumedContainerInstanceId'],
        'filled-insulated-box',
      );
      expect(session.snapshot.state['exchangeTickets'], 8);
      expect(session.snapshot.state['completedCycleOrders'], 1);
      final after = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(after.objects, isEmpty);
      await session.close();
    },
  );

  test('meal order enforces the declared q4.02 prerequisite', () async {
    final session = await _session('orders-meal-prerequisite');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'ready-meal-box',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 50,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_basic',
              'contentQuality': 50,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await _setup(session, chapter: 4, inventory: inventory);
    await expectLater(
      deliverStreetScrapOrder(
        session: session,
        commandId: 'meal-before-tutorial',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.meal',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceId: 'ready-meal-box',
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.revision, 1);
    expect(session.snapshot.state['exchangeTickets'], 0);
    await session.close();
  });

  test('container order cannot consume a vessel left on the board', () async {
    final session = await _session('orders-meal-board-reject');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'board-meal-box',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 50,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_basic',
              'contentQuality': 50,
              'cleanliness': 'clean',
            },
          ),
          'board',
        );
    await _setup(
      session,
      chapter: 4,
      inventory: inventory,
      tasks: const {'q4.02': true},
    );
    await expectLater(
      deliverStreetScrapOrder(
        session: session,
        commandId: 'meal-from-board',
        expectedRevision: 1,
        orderCatalog: _orderCatalog,
        orderId: 'ss.order.meal',
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        containerInstanceId: 'board-meal-box',
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.revision, 1);
    expect(session.snapshot.state['exchangeTickets'], 0);
    await session.close();
  });

  testWidgets('order panel selects exact materials and confirms delivery', (
    tester,
  ) async {
    _setOrderTestViewport(tester);
    final session = await _session('orders-panel-delivery');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'panel-mud-a',
            itemId: 'material.mud',
            source: 'test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        )
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'panel-mud-b',
            itemId: 'material.mud',
            source: 'test',
            quality: 50,
            traits: const {},
          ),
          'backpack',
        );
    await _setup(session, chapter: 5, inventory: inventory);
    final playedCues = <StreetScrapAudioCue>[];
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                StreetScrapOrdersPanel(
                  session: session,
                  inventoryCatalog: _inventoryCatalog,
                  orderCatalog: _orderCatalog,
                  onChanged: () {},
                  onSound: playedCues.add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('street-scrap-order-ss.order.wall'));
    expect(card, findsOneWidget);
    final itemChecks = find.descendant(
      of: card,
      matching: find.byType(CheckboxListTile),
    );
    expect(itemChecks, findsNWidgets(2));
    final itemSprites = find.descendant(
      of: itemChecks,
      matching: find.byType(StreetScrapItemSprite),
    );
    expect(itemSprites, findsNWidgets(2));
    expect(tester.getSize(itemSprites.first), const Size(48, 48));
    expect(
      find.byKey(
        const ValueKey(
          'street-scrap-order-item-choice-ss.order.wall-panel-mud-a',
        ),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(itemChecks.first);
    await tester.tap(itemChecks.first);
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(itemChecks.last);
    await tester.tap(itemChecks.last);
    await tester.pumpAndSettle();
    final deliver = find.descendant(
      of: card,
      matching: find.text('Deliver order'),
    );
    expect(deliver, findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find
                .ancestor(of: deliver, matching: find.byType(FilledButton))
                .first,
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(deliver);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();
    expect(
      find.text('Order complete. You received 4 exchange tickets.'),
      findsOneWidget,
    );
    expect(session.snapshot.state['exchangeTickets'], 4);
    expect(session.snapshot.state['completedCycleOrders'], 1);
    expect(playedCues, contains(StreetScrapAudioCue.success));
    await session.close();
  });

  testWidgets('single-item order shows a large material image', (tester) async {
    _setOrderTestViewport(tester);
    final session = await _session('orders-single-material-art');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'meal-order-box',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 60,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_basic',
              'contentQuality': 60,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await _setup(
      session,
      chapter: 4,
      inventory: inventory,
      tasks: const {'q4.02': true},
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                StreetScrapOrdersPanel(
                  session: session,
                  inventoryCatalog: _inventoryCatalog,
                  orderCatalog: _orderCatalog,
                  onChanged: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(
      const ValueKey(
        'street-scrap-order-material-ss.order.meal-meal.soup_basic',
      ),
    );
    expect(tile, findsOneWidget);
    final sprite = find.descendant(
      of: tile,
      matching: find.byKey(
        const ValueKey(
          'street-scrap-sprite:meal.soup_basic:order:requirement:null',
        ),
      ),
    );
    expect(tester.getSize(sprite), const Size(68, 68));
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('completed group order cannot be offered for a second delivery', (
    tester,
  ) async {
    final session = await _session(
      'completed-advanced-order-compact',
      chapterFive: true,
    );
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'already-delivered-fish-pack',
            itemId: 'fish.pack',
            source: 'processed',
            quality: 66,
            traits: const {},
          ),
          'backpack',
        );
    final orderCatalog = await _q501CatalogFromCanonicalFixture();
    expect(orderCatalog.completionGroups['q5.01'], hasLength(5));
    await _setup(session, chapter: 5, inventory: inventory);
    await session.apply(
      commandId: 'mark-advanced-fish-completed',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'completedOrderGroups': {
            'q5.01': [
              'ss.order.advanced_search',
              'ss.order.advanced_recycle',
              'ss.order.advanced_fish',
            ],
          },
          'exchangeTickets': 23,
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: orderCatalog,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('New neighborhood support orders 3/5'), findsOneWidget);
    final sharedMealOrder = find.byKey(
      const ValueKey('street-scrap-order-ss.order.advanced_cooking'),
    );
    expect(sharedMealOrder, findsOneWidget);
    expect(
      find.descendant(
        of: sharedMealOrder,
        matching: find.text(
          'Put the shared meal in a reusable container, then place it in your backpack.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sharedMealOrder,
        matching: find.text('No matching meal container is in your backpack.'),
      ),
      findsNothing,
    );
    final completedOrder = find.byKey(
      const ValueKey('street-scrap-order-ss.order.advanced_fish'),
    );
    expect(completedOrder, findsOneWidget);
    expect(
      find.descendant(of: completedOrder, matching: find.text('Completed')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: completedOrder, matching: find.text('Deliver order')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: completedOrder,
        matching: find.byType(CheckboxListTile),
      ),
      findsNothing,
    );
    expect(session.snapshot.state['exchangeTickets'], 23);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  test(
    'canonical q5.01 fish retry rejects the exported completed save atomically',
    () async {
      final session = await _session(
        'canonical-q501-fish-duplicate-rejected',
        chapterFive: true,
      );
      final orderCatalog = await _q501CatalogFromCanonicalFixture();
      await _setup(
        session,
        chapter: 5,
        inventory: _inventoryCatalog.emptyInventory(grids: _grids),
      );
      await session.apply(
        commandId: 'restore-exported-q501-completions',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'completedOrderGroups': {
              'q5.01': [
                'ss.order.advanced_search',
                'ss.order.advanced_recycle',
                'ss.order.advanced_fish',
              ],
            },
            'exchangeTickets': 23,
          },
        ),
      );
      final beforeRetry = session.snapshot.toJson();
      await expectLater(
        deliverStreetScrapOrder(
          session: session,
          commandId: 'retry-already-completed-canonical-fish-order',
          expectedRevision: session.snapshot.revision,
          orderCatalog: orderCatalog,
          orderId: 'ss.order.advanced_fish',
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          itemInstanceIds: const ['fish-pack-already-consumed'],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'orderAlreadyCompleted',
          ),
        ),
      );
      expect(session.snapshot.toJson(), beforeRetry);
      expect(session.snapshot.state['exchangeTickets'], 23);
      await session.close();
    },
  );

  testWidgets(
    'canonical q5.01 fish delivery persists its reward and completion',
    (tester) async {
      _setOrderTestViewport(tester);
      final store = _Store();
      final session = await _session(
        'canonical-q501-fish-delivery',
        chapterFive: true,
        store: store,
      );
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'canonical-q501-fish-pack',
              itemId: 'fish.pack',
              source: 'processed',
              quality: 66,
              traits: const {},
            ),
            'backpack',
          );
      final orderCatalog = await _q501CatalogFromCanonicalFixture();
      await _setup(session, chapter: 5, inventory: inventory);
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  StreetScrapOrdersPanel(
                    session: session,
                    inventoryCatalog: _inventoryCatalog,
                    orderCatalog: orderCatalog,
                    onChanged: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(
        const ValueKey('street-scrap-order-ss.order.advanced_fish'),
      );
      expect(card, findsOneWidget);
      expect(find.text('New neighborhood support orders 0/5'), findsOneWidget);
      final fishSelection = find.descendant(
        of: card,
        matching: find.byType(CheckboxListTile),
      );
      expect(fishSelection, findsOneWidget);
      await tester.ensureVisible(fishSelection);
      await tester.tap(fishSelection);
      await tester.pumpAndSettle();
      await tester.ensureVisible(card);
      await tester.tap(
        find.descendant(of: card, matching: find.text('Deliver order')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm delivery'));
      await tester.pumpAndSettle();

      expect(
        find.text('Order complete. You received 5 exchange tickets.'),
        findsOneWidget,
      );
      expect(find.text('New neighborhood support orders 1/5'), findsOneWidget);
      expect(session.snapshot.state['exchangeTickets'], 5);
      expect(
        ((session.snapshot.state['completedOrderGroups']! as Map)['q5.01']
                as List)
            .toSet(),
        {'ss.order.advanced_fish'},
      );
      final afterDelivery = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        afterDelivery.objects.values.any((item) => item.itemId == 'fish.pack'),
        isFalse,
      );
      await session.close();

      final reopened = await _session(
        'canonical-q501-fish-delivery',
        chapterFive: true,
        store: store,
      );
      expect(reopened.snapshot.state['exchangeTickets'], 5);
      expect(
        ((reopened.snapshot.state['completedOrderGroups']! as Map)['q5.01']
                as List)
            .toSet(),
        {'ss.order.advanced_fish'},
      );
      final reopenedInventory = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        reopenedInventory.objects.values.any(
          (item) => item.itemId == 'fish.pack',
        ),
        isFalse,
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  StreetScrapOrdersPanel(
                    session: reopened,
                    inventoryCatalog: _inventoryCatalog,
                    orderCatalog: orderCatalog,
                    onChanged: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New neighborhood support orders 1/5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('street-scrap-order-ss.order.advanced_fish'),
          ),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      await reopened.close();
    },
  );

  test('malformed completion history cannot enter an imported save', () async {
    final session = await _session(
      'malformed-completion-history-import',
      chapterFive: true,
    );
    await _setup(
      session,
      chapter: 5,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    final beforeImport = session.snapshot.toJson();
    final malformed = StreetScrapSaveTransfer.fromSnapshot(
      StreetScrapProgressSnapshot.create(
        rulesetVersion: session.snapshot.rulesetVersion,
        contentVersions: session.snapshot.contentVersions,
        revision: 196,
        savedAt: DateTime.utc(2026, 10, 27),
        state: const {
          'chapter': 5,
          'completedOrderGroups': {'q5.01': 'ss.order.advanced_fish'},
        },
        commandReceipts: const {},
      ),
    );
    await expectLater(
      session.importTransfer(
        transfer: malformed,
        validateState: validateStreetScrapOrderCompletionState,
      ),
      throwsFormatException,
    );
    expect(session.snapshot.toJson(), beforeImport);
    await session.close();
  });

  test('completion history validator preserves compatible unknown IDs', () {
    expect(
      () => validateStreetScrapOrderCompletionState({
        'completedOrderGroups': {
          'q5.01': ['ss.order.removed-in-compatible-update'],
        },
      }),
      returnsNormally,
    );
    for (final malformed in [
      'not-a-map',
      {'q5.01': 'not-a-list'},
      {'': <String>[]},
      {
        'q5.01': [''],
      },
      {
        'q5.01': ['ss.order.duplicate', 'ss.order.duplicate'],
      },
    ]) {
      expect(
        () => validateStreetScrapOrderCompletionState({
          'completedOrderGroups': malformed,
        }),
        throwsFormatException,
      );
    }
  });

  testWidgets('malformed completion history shows read-only order fallback', (
    tester,
  ) async {
    final session = await _session('orders-malformed-completion-fallback');
    await _setup(
      session,
      chapter: 5,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await session.apply(
      commandId: 'corrupt-completion-history-fixture',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'completedOrderGroups': {'q5.01': 'ss.order.advanced_fish'},
        },
      ),
    );
    final beforeRender = session.snapshot.toJson();
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: _orderCatalog,
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The order-completion record is invalid. The transaction was not completed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Deliver order'), findsNothing);
    expect(session.snapshot.toJson(), beforeRender);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('order board shows two cycle slots and replaces one for free', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = await _session('orders-panel-cycle-rotation');
    await _setup(
      session,
      chapter: 5,
      inventory: _inventoryCatalog.emptyInventory(grids: _grids),
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [
                StreetScrapOrdersPanel(
                  session: session,
                  inventoryCatalog: _inventoryCatalog,
                  orderCatalog: _orderCatalog,
                  onChanged: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cycle orders ×2'), findsOneWidget);
    expect(find.text('0 completed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('street-scrap-order-ss.order.fish')),
      findsOneWidget,
    );
    final wallCard = find.byKey(
      const ValueKey('street-scrap-order-ss.order.wall'),
    );
    expect(wallCard, findsOneWidget);
    expect(
      find.byKey(const ValueKey('street-scrap-order-ss.order.insulated')),
      findsNothing,
    );
    final replace = find.descendant(
      of: wallCard,
      matching: find.byKey(
        const ValueKey('street-scrap-replace-order-ss.order.wall'),
      ),
    );
    await tester.scrollUntilVisible(
      replace,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(replace).onPressed, isNotNull);
    expect(find.byTooltip('Replace for free'), findsNWidgets(2));
    await tester.tap(replace);
    await tester.pumpAndSettle();
    expect(session.snapshot.state['activeCycleOrderIds'], [
      'ss.order.fish',
      'ss.order.insulated',
    ]);
    expect(
      find.byKey(const ValueKey('street-scrap-order-ss.order.wall')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('street-scrap-order-ss.order.insulated')),
      findsOneWidget,
    );
    expect(session.snapshot.state['exchangeTickets'], 0);
    await session.close();
  });

  testWidgets('insulated order only offers and consumes an insulated box', (
    tester,
  ) async {
    _setOrderTestViewport(tester);
    final session = await _session('orders-panel-insulated');
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'eligible-insulated-box',
            itemId: 'container.meal_box_insulated',
            source: 'test',
            quality: 60,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_basic',
              'contentQuality': 60,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        )
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'ineligible-standard-box',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 60,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.soup_basic',
              'contentQuality': 60,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
    await _setup(session, chapter: 4, inventory: inventory);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              StreetScrapOrdersPanel(
                session: session,
                inventoryCatalog: _inventoryCatalog,
                orderCatalog: _orderCatalog,
                onChanged: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(
      const ValueKey('street-scrap-order-ss.order.insulated'),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('保溫餐盒（內含 基礎湯・品質 普通（60））・第 1 件'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('eligible-insulated-box'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('ineligible-standard-box'),
      ),
      findsNothing,
    );
    final deliver = find.descendant(of: card, matching: find.text('交付訂單'));
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(deliver);
    await tester.tap(deliver);
    await tester.pumpAndSettle();
    expect(find.textContaining('兩者都會消耗'), findsOneWidget);
    await tester.tap(find.text('確認交付'));
    await tester.pumpAndSettle();
    expect(session.snapshot.state['exchangeTickets'], 8);
    expect(session.snapshot.state['completedCycleOrders'], 1);
    final after = _inventoryCatalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(after.objects.keys.toSet(), {'ineligible-standard-box'});
    await session.close();
  });

  testWidgets(
    'failed meal recovery explicitly selects and returns three boxes',
    (tester) async {
      _setOrderTestViewport(tester);
      final session = await _session('orders-panel-failed-meal-recovery');
      var inventory = _inventoryCatalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 3; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'panel-failed-meal-box-$index',
            itemId: 'container.meal_box',
            source: 'test',
            quality: 50,
            traits: const {},
            containerState: const {
              'contentItemId': 'meal.failed',
              'contentQuality': 20,
              'cleanliness': 'clean',
            },
          ),
          'backpack',
        );
      }
      await _setup(
        session,
        chapter: 4,
        inventory: inventory,
        tasks: const {'q4.02': true},
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  StreetScrapOrdersPanel(
                    session: session,
                    inventoryCatalog: _inventoryCatalog,
                    orderCatalog: _orderCatalog,
                    onChanged: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(
        const ValueKey('street-scrap-order-ss.order.failed_meal_recycle'),
      );
      expect(card, findsOneWidget);
      final checks = find.descendant(
        of: card,
        matching: find.byType(CheckboxListTile),
      );
      expect(checks, findsNWidgets(3));
      expect(find.text('Selected 0; required 3'), findsOneWidget);
      final deliver = find.descendant(
        of: card,
        matching: find.text('Deliver order'),
      );
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(of: deliver, matching: find.byType(FilledButton))
                  .first,
            )
            .onPressed,
        isNull,
      );
      for (var index = 0; index < 3; index++) {
        final check = checks.at(index);
        await tester.ensureVisible(check);
        await tester.tap(check);
        await tester.pumpAndSettle();
      }
      expect(find.text('Selected 3; required 3'), findsOneWidget);
      await tester.ensureVisible(deliver);
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(of: deliver, matching: find.byType(FilledButton))
                  .first,
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(deliver);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('failed meals from 3 containers'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirm delivery'));
      await tester.pumpAndSettle();
      expect(session.snapshot.state['exchangeTickets'], 1);
      expect(session.snapshot.state['completedCycleOrders'] ?? 0, 0);
      final after = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(after.objects.length, 3);
      expect(
        after.objects.values.every(
          (item) =>
              item.containerState['lastContentItemId'] == 'meal.failed' &&
              item.containerState['cleanliness'] == 'soiled' &&
              item.containerState['contentItemId'] == null,
        ),
        isTrue,
      );
      await session.close();
    },
  );
}
