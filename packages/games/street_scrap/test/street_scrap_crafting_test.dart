import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

class _MemoryStore implements StreetScrapProgressStore {
  final slots = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String key) async => slots[key];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    final revision = slots[slotKey]?['revision'] as int?;
    if (revision != expectedRevision) return false;
    slots[slotKey] = nextSnapshot;
    return true;
  }
}

const _grids = {'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6)};

StreetScrapRecipe _recipe({
  StreetScrapFailureResolution? failure,
  String recipeId = 'ss.recipe.sew_strip',
  int phase = 0,
  String station = 'tutorial',
  String operationId = 'sew',
  List<StreetScrapRecipeInput>? inputs,
  List<String>? tools,
  List<StreetScrapRecipeInput>? outputs,
  List<StreetScrapRecipeInput>? failureOutputs,
  bool automatic = false,
  String primaryItem = 'cloth.rag_piece',
  Map<String, Object?> traitResolution = const {
    'inherit': [],
    'polarity': {},
    'success': {},
    'precise': {},
    'failure': {},
  },
  List<Map<String, Object?>> qualityTraitEffects = const [],
  Map<String, Object?>? stateEffect,
}) => StreetScrapRecipe(
  id: recipeId,
  phase: phase,
  station: station,
  operationId: operationId,
  durationSeconds: 10,
  instructions: '對孔縫補',
  inputGroups: [
    inputs ??
        const [
          StreetScrapRecipeInput(itemId: 'cloth.rag_piece', quantity: 2),
          StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 1),
        ],
  ],
  reusableTools: tools ?? const ['tool.needle'],
  outputs:
      outputs ??
      const [StreetScrapRecipeInput(itemId: 'cloth.repair_strip', quantity: 1)],
  failureOutputs: failureOutputs ?? const [],
  quality: StreetScrapRecipeQualityRule(
    primaryInputs: [primaryItem],
    loss: 0,
    mode: 'weighted-primary',
    masteryRevision: 1,
  ),
  retainedInputIds: const [],
  traitResolution: traitResolution,
  qualityTraitEffects: qualityTraitEffects,
  stateEffect: stateEffect,
  failureMode: 'explicitOutcome',
  failureOutcome: '成品保留；重縫另耗線團 1',
  failureResolution: failure,
  manualCheckpoints: automatic
      ? const []
      : [
          StreetScrapManualCheckpoint(
            prompt: '先從哪裡起針？',
            options: const ['錯', '對', '錯'],
            correctOption: 1,
          ),
          StreetScrapManualCheckpoint(
            prompt: '如何對接？',
            options: const ['錯', '對', '錯'],
            correctOption: 1,
          ),
          StreetScrapManualCheckpoint(
            prompt: '如何收線？',
            options: const ['錯', '對', '錯'],
            correctOption: 1,
          ),
        ],
);

StreetScrapInventoryCatalog _catalog({int outputWidth = 1}) =>
    StreetScrapInventoryCatalog(
      footprints: {
        'cloth.rag_piece': const StreetScrapFootprint(1, 1),
        'cloth.thread_spool': const StreetScrapFootprint(1, 1),
        'cloth.thread_end': const StreetScrapFootprint(1, 1),
        'cloth.edge_scrap': const StreetScrapFootprint(1, 1),
        'cloth.insulation': const StreetScrapFootprint(1, 2),
        'tool.needle': const StreetScrapFootprint(1, 1),
        'cloth.repair_strip': StreetScrapFootprint(outputWidth, outputWidth),
        'fish.raw': const StreetScrapFootprint(1, 2),
        'fish.meat': const StreetScrapFootprint(1, 1),
        'fish.bone': const StreetScrapFootprint(1, 1),
        'food.scrap': const StreetScrapFootprint(1, 1),
        'container.clean': const StreetScrapFootprint(1, 2),
        'toolpart.float': const StreetScrapFootprint(1, 2),
        'rope.coarse': const StreetScrapFootprint(1, 1),
        'tool.pot': const StreetScrapFootprint(2, 2),
        'tool.stove': const StreetScrapFootprint(2, 2),
        'tool.cook_kit': const StreetScrapFootprint(2, 3),
        'paper.packaging': const StreetScrapFootprint(1, 1),
        'fish.pack': const StreetScrapFootprint(1, 2),
        'container.used_intact': const StreetScrapFootprint(1, 2),
        'container.clean_jar': const StreetScrapFootprint(1, 2),
        'water.filtered': const StreetScrapFootprint(1, 1),
        'container.meal_box': const StreetScrapFootprint(1, 2),
        'container.meal_box_insulated': const StreetScrapFootprint(1, 2),
        'meal.soup_fish': const StreetScrapFootprint(1, 1),
        'meal.soup_basic': const StreetScrapFootprint(1, 1),
        'meal.soup_vegetable': const StreetScrapFootprint(1, 1),
        'meal.failed': const StreetScrapFootprint(1, 1),
        'tool.rod_basic': const StreetScrapFootprint(1, 3),
        'tool.rod_repaired': const StreetScrapFootprint(1, 3),
        'tool.rod_advanced': const StreetScrapFootprint(1, 3),
        'wood.rod': const StreetScrapFootprint(1, 2),
        'tool.crowbar': const StreetScrapFootprint(1, 2),
        'metal.fastener': const StreetScrapFootprint(1, 1),
        'metal.sheet': const StreetScrapFootprint(1, 1),
        'toolpart.handle': const StreetScrapFootprint(1, 1),
        'food.cleaned': const StreetScrapFootprint(1, 1),
        'food.greens': const StreetScrapFootprint(1, 1),
        'food.edible': const StreetScrapFootprint(1, 1),
        'paper.scrap': const StreetScrapFootprint(1, 1),
        'paper.pulp': const StreetScrapFootprint(1, 1),
        'paper.board': const StreetScrapFootprint(1, 2),
        'tool.paper_mould': const StreetScrapFootprint(2, 2),
        'fuel.dry': const StreetScrapFootprint(1, 1),
        'fuel.mixed': const StreetScrapFootprint(1, 1),
        'material.charcoal': const StreetScrapFootprint(1, 1),
        'material.filter_cloth': const StreetScrapFootprint(1, 1),
        'tool.condenser': const StreetScrapFootprint(2, 2),
      },
      packingRules: const {
        'container.clean': StreetScrapPackingRule(
          id: 'container.clean',
          inputItemId: 'container.clean',
          outputItemId: 'toolpart.float',
          count: 1,
          manualUnpack: true,
        ),
        'tool.pot': StreetScrapPackingRule(
          id: 'tool.pot',
          inputItemId: 'tool.pot',
          inputItemIds: ['tool.pot', 'tool.stove'],
          outputItemId: 'tool.cook_kit',
          count: 2,
          manualUnpack: true,
        ),
      },
      baseDurabilities: const {
        'tool.rod_basic': 20,
        'tool.rod_repaired': 30,
        'tool.rod_advanced': 40,
        'tool.crowbar': 30,
      },
    );

StreetScrapRecipe _distillationRecipe() => StreetScrapRecipe(
  id: 'ss.recipe.distill_water',
  phase: 5,
  station: 'kitchen',
  operationId: 'heat',
  durationSeconds: 15,
  instructions: '15 秒接管及控火',
  inputGroups: const [
    [
      StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
      StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 2),
    ],
  ],
  reusableTools: const ['tool.condenser'],
  outputs: const [],
  quality: StreetScrapRecipeQualityRule(
    primaryInputs: const ['container.clean'],
    loss: 0,
    mode: 'weighted-primary',
    masteryRevision: 1,
  ),
  retainedInputIds: const [],
  failureMode: 'explicitOutcome',
  failureOutcome: '失手保留過濾水，燃料全耗；冷凝器保留',
  failureResolution: const StreetScrapFailureResolution(
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 0,
  ),
  manualCheckpoints: [
    for (var i = 0; i < 3; i++)
      StreetScrapManualCheckpoint(
        prompt: '控火階段 ${i + 1}',
        options: const ['符合提示', '偏離提示'],
        correctOption: 0,
      ),
  ],
  stateEffect: const {
    'type': 'transformContainerContent',
    'containerItemId': 'container.clean',
    'fromContentItemId': 'water.filtered',
    'toContentItemId': 'water.distilled',
    'successCleanliness': 'utility',
    'successRequiresBoiling': false,
    'preserveContainerContentQuality': true,
  },
);

void _registerPackingTests() {
  test('float packages and returns the exact original empty bottle', () async {
    final catalog = _catalog();
    final bottle = catalog.createObject(
      instanceId: 'float-bottle-original',
      itemId: 'container.clean',
      source: 'scavenged:glass-corner',
      quality: 73,
      traits: const {'dry-seal': true},
      containerState: const {'cleanliness': 'clean'},
    );
    var inventory = catalog.emptyInventory(grids: _grids);
    inventory = inventory.addAndPlaceFirstFit(bottle, 'board');
    inventory = inventory.addAndPlaceFirstFit(
      catalog.createObject(
        instanceId: 'float-rope-consumed',
        itemId: 'rope.coarse',
        source: 'found',
        quality: 40,
        traits: const {},
      ),
      'board',
    );
    final store = _MemoryStore();
    final session = await _session(store, catalog, inventory);
    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.float',
      phase: 2,
      station: 'recycler',
      operationId: 'assemble',
      durationSeconds: 10,
      instructions: '瓶子包入浮標',
      inputGroups: const [
        [
          StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
          StreetScrapRecipeInput(itemId: 'rope.coarse', quantity: 1),
        ],
      ],
      reusableTools: const [],
      outputs: const [],
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: const ['container.clean'],
        loss: 0,
        mode: 'preserve-primary',
        masteryRevision: 1,
      ),
      retainedInputIds: const ['container.clean'],
      failureMode: 'noPenalty',
      failureOutcome: '確認式組裝',
      stateEffect: const {
        'type': 'packObjects',
        'retainedInputIds': ['container.clean'],
        'toItemId': 'toolpart.float',
        'packingRuleId': 'container.clean',
        'requireEmptyContainerItems': ['container.clean'],
      },
    );
    await session.apply(
      commandId: 'float-mastery',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 2,
          'unlockedStations': ['recycler'],
          'mastery': {'ss.recipe.float': 1},
        },
      ),
    );
    await StreetScrapCrafting.craft(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      gridId: 'board',
      inputGroupIndex: 0,
      inputInstanceIds: const ['float-bottle-original', 'float-rope-consumed'],
      toolInstanceIds: const [],
      commandId: 'craft-float',
      expectedRevision: 2,
      manual: false,
      manualPoints: 0,
      outputInstanceId: (index) => 'float-result-$index',
    );
    var saved = catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    final float = saved.objects['float-result-0']!;
    expect(float.itemId, 'toolpart.float');
    expect(saved.objects, isNot(contains('float-rope-consumed')));
    expect(float.containerContents.single.instanceId, 'float-bottle-original');
    expect(float.containerContents.single.source, 'scavenged:glass-corner');
    expect(float.containerContents.single.quality, 73);
    expect(float.containerContents.single.traits, {'dry-seal': true});
    expect(float.provenance, hasLength(1));
    expect(float.provenance.single['kind'], 'craft');
    expect(float.provenance.single['recipeId'], 'ss.recipe.float');
    expect(
      (float.provenance.single['inputs'] as List)
          .map((input) => (input as Map)['instanceId'])
          .toSet(),
      {'float-bottle-original', 'float-rope-consumed'},
    );

    saved = saved.unpack(
      containerInstanceId: 'float-result-0',
      gridId: 'board',
    );
    expect(saved.objects.keys, {'float-bottle-original'});
    expect(
      saved.objects['float-bottle-original']!.containerState['cleanliness'],
      'clean',
    );
    await session.close();
  });

  test('cook kit packages and returns the original pot and stove', () async {
    final catalog = _catalog();
    var inventory = catalog.emptyInventory(grids: _grids);
    for (final item in [
      catalog.createObject(
        instanceId: 'cook-pot-original',
        itemId: 'tool.pot',
        source: 'crafted:pot',
        quality: 81,
        traits: const {'sturdy': true},
      ),
      catalog.createObject(
        instanceId: 'cook-stove-original',
        itemId: 'tool.stove',
        source: 'found:donation',
        quality: 67,
        traits: const {'bent-leg': false},
      ),
      for (var i = 0; i < 2; i++)
        catalog.createObject(
          instanceId: 'cook-wrap-$i',
          itemId: 'paper.packaging',
          source: 'found',
          quality: 50,
          traits: const {},
        ),
    ]) {
      inventory = inventory.addAndPlaceFirstFit(item, 'board');
    }
    final session = await _session(_MemoryStore(), catalog, inventory);
    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.cook_kit',
      phase: 5,
      station: 'workbench',
      operationId: 'assemble',
      durationSeconds: 10,
      instructions: '將鍋具與爐架包在一起',
      inputGroups: const [
        [
          StreetScrapRecipeInput(itemId: 'tool.pot', quantity: 1),
          StreetScrapRecipeInput(itemId: 'tool.stove', quantity: 1),
          StreetScrapRecipeInput(itemId: 'paper.packaging', quantity: 2),
        ],
      ],
      reusableTools: const [],
      outputs: const [],
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: const ['tool.pot'],
        loss: 0,
        mode: 'preserve-primary',
        masteryRevision: 1,
      ),
      retainedInputIds: const ['tool.pot', 'tool.stove'],
      failureMode: 'noPenalty',
      failureOutcome: '確認式包裝',
      stateEffect: const {
        'type': 'packObjects',
        'retainedInputIds': ['tool.pot', 'tool.stove'],
        'toItemId': 'tool.cook_kit',
        'packingRuleId': 'tool.pot',
      },
    );
    await session.apply(
      commandId: 'cook-kit-unlock',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 5,
          'mastery': {'ss.recipe.cook_kit': 1},
        },
      ),
    );
    await StreetScrapCrafting.craft(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      gridId: 'board',
      inputGroupIndex: 0,
      inputInstanceIds: const [
        'cook-pot-original',
        'cook-stove-original',
        'cook-wrap-0',
        'cook-wrap-1',
      ],
      toolInstanceIds: const [],
      commandId: 'craft-cook-kit',
      expectedRevision: 2,
      manual: false,
      manualPoints: 0,
      outputInstanceId: (index) => 'cook-kit-result-$index',
    );
    var saved = catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    final kit = saved.objects['cook-kit-result-0']!;
    expect(kit.itemId, 'tool.cook_kit');
    expect(saved.objects.keys, isNot(contains('cook-wrap-0')));
    expect(saved.objects.keys, isNot(contains('cook-wrap-1')));
    expect(kit.containerContents.map((item) => item.instanceId).toSet(), {
      'cook-pot-original',
      'cook-stove-original',
    });
    saved = saved.unpack(containerInstanceId: kit.instanceId, gridId: 'board');
    expect(saved.objects.keys, {'cook-pot-original', 'cook-stove-original'});
    expect(saved.objects['cook-pot-original']!.source, 'crafted:pot');
    expect(saved.objects['cook-pot-original']!.quality, 81);
    expect(saved.objects['cook-pot-original']!.traits, {'sturdy': true});
    expect(saved.objects['cook-stove-original']!.source, 'found:donation');
    expect(saved.objects['cook-stove-original']!.quality, 67);
    expect(saved.objects['cook-stove-original']!.traits, {'bent-leg': false});
    expect(kit.provenance, hasLength(1));
    expect(kit.provenance.single['recipeId'], 'ss.recipe.cook_kit');
    expect(
      (kit.provenance.single['inputs'] as List)
          .map((input) => (input as Map)['instanceId'])
          .toSet(),
      {
        'cook-pot-original',
        'cook-stove-original',
        'cook-wrap-0',
        'cook-wrap-1',
      },
    );
    await session.close();
  });
}

StreetScrapInventory _inventory(
  StreetScrapInventoryCatalog catalog, {
  bool blocker = false,
  bool tutorialKit = false,
  bool fish = false,
  Map<String, Object?> ragTraits = const {},
}) {
  final objects = <String, StreetScrapObject>{
    'rag-a': catalog.createObject(
      instanceId: 'rag-a',
      itemId: 'cloth.rag_piece',
      source: 'found',
      quality: 60,
      traits: ragTraits,
    ),
    'rag-b': catalog.createObject(
      instanceId: 'rag-b',
      itemId: 'cloth.rag_piece',
      source: 'found',
      quality: 80,
      traits: const {},
    ),
    'thread': catalog.createObject(
      instanceId: 'thread',
      itemId: 'cloth.thread_spool',
      source: 'found',
      quality: 50,
      traits: const {},
    ),
    'needle': catalog.createObject(
      instanceId: 'needle',
      itemId: 'tool.needle',
      source: 'starter',
      quality: 50,
      traits: const {},
      toolDurability: 5,
    ),
    if (tutorialKit)
      'q1-kit-rag': catalog.createObject(
        instanceId: 'q1-kit-rag',
        itemId: 'cloth.rag_piece',
        source: 'tutorial:q1.02-rag',
        quality: 55,
        traits: const {},
      ),
    if (tutorialKit)
      'q1-kit-thread': catalog.createObject(
        instanceId: 'q1-kit-thread',
        itemId: 'cloth.thread_end',
        source: 'tutorial:q1.02-thread',
        quality: 55,
        traits: const {},
      ),
    if (tutorialKit)
      'q1-kit-needle': catalog.createObject(
        instanceId: 'q1-kit-needle',
        itemId: 'tool.needle',
        source: 'tutorial:q1.02-needle',
        quality: 55,
        traits: const {},
      ),
    if (fish)
      'raw-fish': catalog.createObject(
        instanceId: 'raw-fish',
        itemId: 'fish.raw',
        source: 'fishing:test-catch',
        quality: 80,
        traits: const {},
      ),
  };
  return StreetScrapInventory(
    catalog: catalog,
    grids: blocker
        ? const {'board': StreetScrapGridSpec(id: 'board', width: 2, height: 2)}
        : _grids,
    objects: objects,
    placements: {
      'rag-a': const StreetScrapPlacement(
        instanceId: 'rag-a',
        gridId: 'board',
        x: 0,
        y: 0,
        rotation: false,
      ),
      'rag-b': const StreetScrapPlacement(
        instanceId: 'rag-b',
        gridId: 'board',
        x: 1,
        y: 0,
        rotation: false,
      ),
      'thread': const StreetScrapPlacement(
        instanceId: 'thread',
        gridId: 'board',
        x: 0,
        y: 1,
        rotation: false,
      ),
      'needle': const StreetScrapPlacement(
        instanceId: 'needle',
        gridId: 'board',
        x: 1,
        y: 1,
        rotation: false,
      ),
      if (tutorialKit)
        'q1-kit-rag': const StreetScrapPlacement(
          instanceId: 'q1-kit-rag',
          gridId: 'board',
          x: 2,
          y: 0,
          rotation: false,
        ),
      if (tutorialKit)
        'q1-kit-thread': const StreetScrapPlacement(
          instanceId: 'q1-kit-thread',
          gridId: 'board',
          x: 3,
          y: 0,
          rotation: false,
        ),
      if (tutorialKit)
        'q1-kit-needle': const StreetScrapPlacement(
          instanceId: 'q1-kit-needle',
          gridId: 'board',
          x: 4,
          y: 0,
          rotation: false,
        ),
      if (fish)
        'raw-fish': const StreetScrapPlacement(
          instanceId: 'raw-fish',
          gridId: 'board',
          x: 2,
          y: 1,
          rotation: false,
        ),
    },
    storage: const {},
  );
}

Future<StreetScrapSession> _session(
  _MemoryStore store,
  StreetScrapInventoryCatalog catalog,
  StreetScrapInventory initial, {
  String? profileScope,
  String contentVersion = '0.1.0',
}) async {
  final session = StreetScrapSession(
    profileScope:
        profileScope ?? 'craft-test-${DateTime.now().microsecondsSinceEpoch}',
    store: store,
    contentVersions: {'game.street-scrap.content.chapters-0-4': contentVersion},
    rulesetVersion: 1,
  );
  await session.load();
  await session.applyInventoryCommand(
    commandId: 'seed',
    expectedRevision: 0,
    catalog: catalog,
    grids: initial.grids,
    initialInventory: initial,
    reduceInventory: (inventory) => inventory,
  );
  return session;
}

void main() {
  _registerPackingTests();
  test('manual craft pins the aggregate active content version', () {
    expect(
      streetScrapCraftContentVersion(const {
        'game.street-scrap.content.chapters-0-4': '0.1.21',
        'game.street-scrap.content.active': '0.1.21+none',
      }),
      '0.1.21+none',
    );
    expect(
      streetScrapCraftContentVersion(const {
        'game.street-scrap.content.chapters-0-4': '0.1.13',
      }),
      '0.1.13',
    );
  });
  test(
    'distillation transforms the selected bottle and retains failure water',
    () async {
      for (final succeeds in [true, false]) {
        final catalog = _catalog();
        var initial = catalog.emptyInventory(grids: _grids);
        initial = initial.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'distill-vessel-$succeeds',
            itemId: 'container.clean',
            source: 'filled:filtered-water',
            quality: 70,
            traits: const {},
            containerState: const {
              'contentItemId': 'water.filtered',
              'contentQuality': 61,
              'contentSource': 'fixed:clean-water-point',
              'cleanliness': 'utility',
              'requiresBoiling': true,
            },
          ),
          'board',
        );
        for (var i = 0; i < 2; i++) {
          initial = initial.addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'distill-fuel-$succeeds-$i',
              itemId: 'fuel.dry',
              source: 'fixed:repair-area',
              quality: 50,
              traits: const {},
            ),
            'board',
          );
        }
        initial = initial.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'distill-condenser-$succeeds',
            itemId: 'tool.condenser',
            source: 'crafted:ss.recipe.condenser',
            quality: 70,
            traits: const {},
          ),
          'board',
        );
        final session = await _session(_MemoryStore(), catalog, initial);
        await session.apply(
          commandId: 'advance-distill-${succeeds ? 'success' : 'failure'}',
          expectedRevision: session.snapshot.revision,
          reduce: (state) =>
              StreetScrapReduction(state: {...state, 'chapter': 5}),
        );
        final recipe = _distillationRecipe();
        final operationId = 'distill-${succeeds ? 'success' : 'failure'}';
        await StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: [
            'distill-vessel-$succeeds',
            'distill-fuel-$succeeds-0',
            'distill-fuel-$succeeds-1',
          ],
          toolInstanceIds: ['distill-condenser-$succeeds'],
          operationId: operationId,
          commandId: 'begin-$operationId',
          expectedRevision: session.snapshot.revision,
          contentVersion: '0.1.0',
        );
        StreetScrapCommandResult? settled;
        for (var i = 0; i < 3; i++) {
          settled = await StreetScrapCrafting.answerManualCheckpoint(
            session: session,
            inventoryCatalog: catalog,
            recipe: recipe,
            grids: _grids,
            operationId: operationId,
            optionIndex: succeeds || i == 0 ? 0 : 1,
            expectedRevision: session.snapshot.revision,
          );
        }
        expect(settled, isNotNull);
        final after = catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        final bottle = after.objects['distill-vessel-$succeeds']!;
        expect(
          bottle.containerState['contentItemId'],
          succeeds ? 'water.distilled' : 'water.filtered',
        );
        expect(bottle.containerState['contentQuality'], 61);
        expect(
          after.objects.containsKey('distill-condenser-$succeeds'),
          isTrue,
        );
        expect(after.objects.containsKey('distill-fuel-$succeeds-0'), isFalse);
        expect(after.objects.containsKey('distill-fuel-$succeeds-1'), isFalse);
        expect(session.snapshot.state['craftOperation'], isNull);
        await session.close();
      }
    },
  );
  test(
    'cracked wood provenance reaches a crafted tool and reduces durability',
    () async {
      final catalog = _catalog();
      final initial = catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'cracked-rod',
              itemId: 'wood.rod',
              source: 'surprise:intactBase',
              quality: 55,
              traits: const {'cracked': true},
            ),
            'board',
          );
      final session = await _session(_MemoryStore(), catalog, initial);
      await session.apply(
        commandId: 'unlock-cracked-wood-chain',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'mastery': {'ss.recipe.tool_handle': 1, 'ss.recipe.crowbar': 1},
          },
        ),
      );
      final handleRecipe = _recipe(
        recipeId: 'ss.recipe.tool_handle',
        station: 'workbench',
        operationId: 'assemble',
        inputs: const [StreetScrapRecipeInput(itemId: 'wood.rod', quantity: 1)],
        tools: const [],
        primaryItem: 'wood.rod',
        outputs: const [
          StreetScrapRecipeInput(itemId: 'toolpart.handle', quantity: 1),
        ],
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
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: handleRecipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['cracked-rod'],
        toolInstanceIds: const [],
        commandId: 'craft-cracked-handle',
        expectedRevision: 2,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (_) => 'cracked-handle',
      );
      final crowbarRecipe = _recipe(
        recipeId: 'ss.recipe.crowbar',
        station: 'workbench',
        operationId: 'assemble',
        inputs: const [
          StreetScrapRecipeInput(itemId: 'toolpart.handle', quantity: 1),
        ],
        tools: const [],
        primaryItem: 'toolpart.handle',
        outputs: const [
          StreetScrapRecipeInput(itemId: 'tool.crowbar', quantity: 1),
        ],
        traitResolution: const {
          'inherit': [
            {
              'inputItemId': 'toolpart.handle',
              'map': {'cracked': 'cracked'},
            },
          ],
          'polarity': {'cracked': 'negative'},
          'success': {},
          'precise': {},
          'failure': {},
        },
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: crowbarRecipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['cracked-handle'],
        toolInstanceIds: const [],
        commandId: 'craft-cracked-crowbar',
        expectedRevision: 3,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (_) => 'cracked-crowbar',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final crowbar = saved.objects['cracked-crowbar']!;
      expect(crowbar.traits['cracked'], isTrue);
      expect(crowbar.toolDurability, 27);
      await session.close();
    },
  );

  test(
    'mineral water content trait applies the declared soup quality bonus',
    () {
      final recipe = _recipe(
        qualityTraitEffects: const [
          {
            'inputItemId': 'container.clean',
            'traitId': 'mineral_rich',
            'polarity': 'positive',
            'modifier': 3,
          },
        ],
      );
      final mineralWater = StreetScrapObject(
        instanceId: 'mineral-jar',
        itemId: 'container.clean',
        source: 'test',
        quality: 70,
        traits: const {},
        toolDurability: null,
        footprint: const StreetScrapFootprint(1, 1),
        containerState: const {
          'contentItemId': 'water.mineral',
          'contentTraits': {'mineral_rich': true},
        },
      );

      final effects = StreetScrapCrafting.applicableQualityTraitEffects(
        recipe,
        [mineralWater],
      );
      expect(effects.single['traitId'], 'mineral_rich');
      expect(effects.single['modifier'], 3);
    },
  );

  test(
    'quality preview selects the same single effect per polarity as settlement',
    () {
      final catalog = _catalog();
      final recipe = _recipe(
        qualityTraitEffects: const [
          {
            'inputItemId': 'food.cleaned',
            'traitId': 'rich_ingredient',
            'polarity': 'positive',
            'modifier': 3,
          },
          {
            'inputItemId': 'fish.meat',
            'traitId': 'rich_ingredient',
            'polarity': 'positive',
            'modifier': 3,
          },
          {
            'inputItemId': 'food.cleaned',
            'traitId': 'rough_cut',
            'polarity': 'negative',
            'modifier': -3,
          },
          {
            'inputItemId': 'fish.meat',
            'traitId': 'rough_cut',
            'polarity': 'negative',
            'modifier': -3,
          },
        ],
      );
      final inputs = [
        catalog.createObject(
          instanceId: 'preview-cleaned',
          itemId: 'food.cleaned',
          source: 'test',
          quality: 60,
          traits: const {'rich_ingredient': true, 'rough_cut': true},
        ),
        catalog.createObject(
          instanceId: 'preview-fish',
          itemId: 'fish.meat',
          source: 'test',
          quality: 60,
          traits: const {'rich_ingredient': true, 'rough_cut': true},
        ),
      ];
      final preview = StreetScrapCrafting.applicableQualityTraitEffects(
        recipe,
        inputs,
      );
      expect(preview.map((effect) => effect['traitId']), [
        'rough_cut',
        'rich_ingredient',
      ]);
      expect(
        preview.fold<int>(
          0,
          (sum, effect) => sum + (effect['modifier']! as int),
        ),
        0,
      );
    },
  );

  test(
    'clean-food wash creates precise and failure traits across either input substitute',
    () async {
      const cases = <(String, List<int>, String, int, bool, bool)>[
        ('precise', [1, 1, 1], 'food.greens', 2, true, false),
        ('ordinary', [1, 1, 0], 'food.edible', 2, false, false),
        ('failed', [1, 0, 0], 'food.greens', 1, false, true),
      ];
      for (final (key, answers, primary, cleanedCount, precise, failed)
          in cases) {
        final catalog = _catalog();
        var initial = catalog.emptyInventory(grids: _grids);
        for (var index = 0; index < 2; index++) {
          initial = initial.addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: '$key-food-$index',
              itemId: primary,
              source: 'fixed:kitchen',
              quality: 60,
              traits: const {},
            ),
            'board',
          );
        }
        initial = initial.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: '$key-water',
            itemId: 'water.filtered',
            source: 'fixed:kitchen',
            quality: 55,
            traits: const {},
          ),
          'board',
        );
        final session = await _session(_MemoryStore(), catalog, initial);
        await session.apply(
          commandId: '$key-unlock-kitchen',
          expectedRevision: 1,
          reduce: (state) =>
              StreetScrapReduction(state: {...state, 'chapter': 4}),
        );
        final recipe = _recipe(
          recipeId: 'ss.recipe.clean_food',
          phase: 4,
          station: 'kitchen',
          operationId: 'wash',
          inputs: [
            StreetScrapRecipeInput(itemId: primary, quantity: 2),
            const StreetScrapRecipeInput(itemId: 'water.filtered', quantity: 1),
          ],
          tools: const [],
          primaryItem: primary,
          outputs: const [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 2),
          ],
          failureOutputs: const [
            StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 1),
            StreetScrapRecipeInput(itemId: 'food.scrap', quantity: 1),
          ],
          failure: const StreetScrapFailureResolution(
            mode: 'sameOutputsQualityLoss',
            qualityLoss: 0,
          ),
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
        );
        await StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: ['$key-food-0', '$key-food-1', '$key-water'],
          toolInstanceIds: const [],
          operationId: '$key-op',
          commandId: '$key-begin',
          expectedRevision: 2,
          contentVersion: '0.1.0',
        );
        StreetScrapCommandResult? result;
        for (final answer in answers) {
          result = await StreetScrapCrafting.answerManualCheckpoint(
            session: session,
            inventoryCatalog: catalog,
            recipe: recipe,
            grids: _grids,
            operationId: '$key-op',
            optionIndex: answer,
            expectedRevision: session.snapshot.revision,
          );
        }
        expect((result!.result! as Map)['succeeded'], !failed, reason: key);
        final saved = catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        final cleaned = saved.objects.values
            .where((item) => item.itemId == 'food.cleaned')
            .toList();
        expect(cleaned, hasLength(cleanedCount), reason: key);
        expect(
          cleaned.every((item) => item.traits.containsKey('rich_ingredient')),
          precise,
          reason: key,
        );
        expect(
          cleaned.every((item) => item.traits.containsKey('rough_cut')),
          failed,
          reason: key,
        );
        expect(
          saved.objects.values.where((item) => item.itemId == 'food.scrap'),
          hasLength(failed ? 1 : 0),
        );
        expect(session.snapshot.state['craftOperation'], isNull);
        await session.close();
      }
    },
  );

  test('even-burn changes only heat target width and never fuel amount', () {
    final catalog = _catalog();
    final fuel = catalog.createObject(
      instanceId: 'trait-fuel',
      itemId: 'fuel.dry',
      source: 'crafted:test',
      quality: 60,
      traits: const {'even_burn': true},
    );
    expect(
      streetScrapHeatTargetWidthMultiplier(_recipe(operationId: 'heat'), [
        fuel,
      ]),
      1.1,
    );
    expect(
      streetScrapHeatTargetWidthMultiplier(_recipe(operationId: 'mix'), [fuel]),
      1,
    );
  });

  test(
    'rod upgrade and pot assembly preserve the retained object identity',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      var initial = catalog.emptyInventory(grids: _grids);
      for (final item in [
        catalog.createObject(
          instanceId: 'rod-original',
          itemId: 'tool.rod_basic',
          source: 'found:chapter-kit',
          quality: 73,
          traits: const {'steady': true},
          toolDurability: 10,
        ),
        catalog.createObject(
          instanceId: 'rod-repair-strip',
          itemId: 'cloth.repair_strip',
          source: 'crafted:test',
          quality: 55,
          traits: const {},
        ),
        catalog.createObject(
          instanceId: 'rod-fastener',
          itemId: 'metal.fastener',
          source: 'found:test',
          quality: 50,
          traits: const {},
        ),
        catalog.createObject(
          instanceId: 'jar-original',
          itemId: 'container.clean_jar',
          source: 'found:street',
          quality: 62,
          traits: const {'sturdy': true},
          containerState: const {'cleanliness': 'clean'},
        ),
        catalog.createObject(
          instanceId: 'pot-sheet',
          itemId: 'metal.sheet',
          source: 'found:test',
          quality: 50,
          traits: const {},
        ),
        catalog.createObject(
          instanceId: 'pot-handle',
          itemId: 'toolpart.handle',
          source: 'crafted:test',
          quality: 50,
          traits: const {},
        ),
      ]) {
        initial = initial.addAndPlaceFirstFit(item, 'board');
      }
      final session = await _session(
        store,
        catalog,
        initial,
        contentVersion: '0.1.2',
      );
      await session.apply(
        commandId: 'unlock-retained-item-recipes',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 3,
            'tutorialTasks': {'q2.03': true},
            'mastery': {'ss.recipe.upgrade_rod': 1, 'ss.recipe.pot': 1},
          },
        ),
      );
      final recipes = [
        (
          id: 'ss.recipe.upgrade_rod',
          inputIds: ['rod-original', 'rod-repair-strip', 'rod-fastener'],
          retainedId: 'tool.rod_basic',
          from: 'tool.rod_basic',
          to: 'tool.rod_repaired',
          primary: 'tool.rod_basic',
        ),
        (
          id: 'ss.recipe.pot',
          inputIds: ['jar-original', 'pot-sheet', 'pot-handle'],
          retainedId: 'container.clean_jar',
          from: 'container.clean_jar',
          to: 'tool.pot',
          primary: 'container.clean_jar',
        ),
      ];
      var revision = 2;
      for (final entry in recipes) {
        final recipe = StreetScrapRecipe(
          id: entry.id,
          phase: 3,
          station: 'workbench',
          operationId: 'assemble',
          durationSeconds: 10,
          instructions: '保留原物件身份完成轉製',
          inputGroups: [
            [
              for (final itemId in entry.inputIds.map((id) {
                if (id == entry.inputIds.first) return entry.retainedId;
                return id == 'rod-repair-strip'
                    ? 'cloth.repair_strip'
                    : id == 'rod-fastener'
                    ? 'metal.fastener'
                    : id == 'pot-sheet'
                    ? 'metal.sheet'
                    : 'toolpart.handle';
              }))
                StreetScrapRecipeInput(itemId: itemId, quantity: 1),
            ],
          ],
          reusableTools: const [],
          outputs: const [],
          quality: StreetScrapRecipeQualityRule(
            primaryInputs: [entry.primary],
            loss: 0,
            mode: entry.id.endsWith('upgrade_rod')
                ? 'preserve-primary'
                : 'weighted-primary',
            masteryRevision: 1,
          ),
          retainedInputIds: [entry.retainedId],
          failureMode: 'reducedQualityOutput',
          failureOutcome: '保留原物件，依操作結果轉製。',
          failureResolution: const StreetScrapFailureResolution(
            mode: 'sameOutputsQualityLoss',
            qualityLoss: 10,
          ),
          stateEffect: {
            'type': 'transformObject',
            'fromItemId': entry.from,
            'toItemId': entry.to,
            'requireEmptyContainer': true,
            if (entry.id.endsWith('.pot')) 'clearContainerState': true,
          },
          manualCheckpoints: const [],
        );
        await StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: entry.inputIds,
          toolInstanceIds: const [],
          commandId: 'craft-${entry.id}',
          expectedRevision: revision++,
          manual: false,
          manualPoints: 0,
          outputInstanceId: (_) => 'unused-output',
        );
      }
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects['rod-original']!.itemId, 'tool.rod_repaired');
      expect(saved.objects['rod-original']!.source, 'found:chapter-kit');
      expect(saved.objects['rod-original']!.quality, 73);
      expect(saved.objects['rod-original']!.traits, {'steady': true});
      expect(saved.objects['rod-original']!.toolDurability, 15);
      expect(saved.objects['jar-original']!.itemId, 'tool.pot');
      expect(saved.objects['jar-original']!.source, 'found:street');
      expect(saved.objects['jar-original']!.quality, 62);
      expect(saved.objects['jar-original']!.traits, {'sturdy': true});
      expect(saved.objects['rod-original']!.provenance, hasLength(1));
      expect(
        saved.objects['rod-original']!.provenance.single['kind'],
        'transform',
      );
      expect(
        saved.objects['rod-original']!.provenance.single['recipeId'],
        'ss.recipe.upgrade_rod',
      );
      expect(
        saved.objects['rod-original']!.provenance.single['outcome'],
        'success',
      );
      expect(saved.objects['jar-original']!.containerState, isEmpty);
      expect(saved.objects.containsKey('rod-repair-strip'), isFalse);
      expect(saved.objects.containsKey('pot-sheet'), isFalse);
      expect(saved.objects.containsKey('pot-handle'), isFalse);
      await session.close();
    },
  );

  test('container wash changes the same bottle only on success', () async {
    final catalog = _catalog();
    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.wash_container',
      phase: 1,
      station: 'recycler',
      operationId: 'wash',
      durationSeconds: 10,
      instructions: '清洗完整舊瓶',
      inputGroups: const [
        [
          StreetScrapRecipeInput(itemId: 'container.used_intact', quantity: 1),
          StreetScrapRecipeInput(itemId: 'water.filtered', quantity: 1),
        ],
      ],
      reusableTools: const [],
      outputs: const [],
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: const ['container.used_intact'],
        loss: 0,
        mode: 'preserve-primary',
        masteryRevision: 1,
      ),
      retainedInputIds: const ['container.used_intact'],
      failureMode: 'explicitOutcome',
      failureOutcome: '漏洗留下原瓶，過濾水消耗。',
      failureResolution: const StreetScrapFailureResolution(
        mode: 'sameOutputsQualityLoss',
        qualityLoss: 0,
      ),
      manualCheckpoints: [
        StreetScrapManualCheckpoint(
          prompt: '確認瓶口',
          options: ['偏左', '正確', '偏右'],
          correctOption: 1,
        ),
        StreetScrapManualCheckpoint(
          prompt: '清除污垢',
          options: ['偏左', '正確', '偏右'],
          correctOption: 1,
        ),
        StreetScrapManualCheckpoint(
          prompt: '確認乾淨',
          options: ['偏左', '正確', '偏右'],
          correctOption: 1,
        ),
      ],
      stateEffect: const {
        'type': 'transformObject',
        'fromItemId': 'container.used_intact',
        'toItemId': 'container.clean',
        'requireEmptyContainer': true,
        'applyOnFailure': false,
        'targetContainerState': {'cleanliness': 'clean'},
      },
    );

    for (final succeeds in [true, false]) {
      var initial = catalog.emptyInventory(grids: _grids);
      initial = initial.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'wash-bottle-$succeeds',
          itemId: 'container.used_intact',
          source: 'found:old-street',
          quality: 64,
          traits: const {'intact': true},
          containerState: const {'cleanliness': 'soiled'},
        ),
        'board',
      );
      initial = initial.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'wash-water-$succeeds',
          itemId: 'water.filtered',
          source: 'supply:public-refill',
          quality: 58,
          traits: const {},
        ),
        'board',
      );
      final session = await _session(
        _MemoryStore(),
        catalog,
        initial,
        contentVersion: '0.1.2',
      );
      await session.apply(
        commandId: 'unlock-wash-$succeeds',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 1,
            'unlockedStations': ['recycler'],
            'mastery': {'ss.recipe.wash_container': 1},
          },
        ),
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: ['wash-bottle-$succeeds', 'wash-water-$succeeds'],
        toolInstanceIds: const [],
        commandId: 'wash-$succeeds',
        expectedRevision: 2,
        manual: !succeeds,
        manualPoints: 0,
        outputInstanceId: (_) => 'unused-washed-output',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final bottle = saved.objects['wash-bottle-$succeeds']!;
      expect(
        bottle.itemId,
        succeeds ? 'container.clean' : 'container.used_intact',
      );
      expect(bottle.source, 'found:old-street');
      expect(bottle.quality, 64);
      expect(bottle.traits, {'intact': true});
      expect(
        bottle.containerState['cleanliness'],
        succeeds ? 'clean' : 'soiled',
      );
      expect(bottle.provenance, hasLength(1));
      expect(bottle.provenance.single['recipeId'], 'ss.recipe.wash_container');
      expect(
        bottle.provenance.single['outcome'],
        succeeds ? 'success' : 'failure',
      );
      expect(saved.objects.containsKey('wash-water-$succeeds'), isFalse);
      await session.close();
    }
  });

  test('clear water trait improves pulp quality exactly once', () async {
    final catalog = _catalog();
    var initial = catalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 3; index++) {
      initial = initial.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'pulp-scrap-$index',
          itemId: 'paper.scrap',
          source: 'tutorial:paper',
          quality: 55,
          traits: const {},
        ),
        'board',
      );
    }
    initial = initial.addAndPlaceFirstFit(
      catalog.createObject(
        instanceId: 'clear-water-jar',
        itemId: 'container.clean',
        source: 'filtered:precise',
        quality: 55,
        traits: const {'clear': true},
        containerState: const {
          'contentItemId': 'water.filtered',
          'contentQuality': 55,
          'contentTraits': {'clear': true},
        },
      ),
      'board',
    );
    final session = await _session(_MemoryStore(), catalog, initial);
    await session.apply(
      commandId: 'unlock-clear-pulp',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 1,
          'unlockedStations': ['recycler'],
          'mastery': {'ss.recipe.mix_pulp': 1},
        },
      ),
    );
    final recipe = _recipe(
      recipeId: 'ss.recipe.mix_pulp',
      phase: 1,
      station: 'recycler',
      inputs: const [
        StreetScrapRecipeInput(itemId: 'paper.scrap', quantity: 3),
        StreetScrapRecipeInput(itemId: 'water.filtered', quantity: 1),
      ],
      outputs: const [
        StreetScrapRecipeInput(itemId: 'paper.pulp', quantity: 1),
      ],
      tools: const [],
      primaryItem: 'paper.scrap',
      traitResolution: const {
        'inherit': [],
        'polarity': {'even_pulp': 'positive'},
        'success': {},
        'precise': {'even_pulp': true},
        'failure': {},
      },
      automatic: false,
      qualityTraitEffects: const [
        {
          'inputItemId': 'water.filtered',
          'traitId': 'clear',
          'polarity': 'positive',
          'modifier': 3,
        },
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
          },
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
    await StreetScrapCrafting.craft(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      gridId: 'board',
      inputGroupIndex: 0,
      inputInstanceIds: const [
        'pulp-scrap-0',
        'pulp-scrap-1',
        'pulp-scrap-2',
        'clear-water-jar',
      ],
      toolInstanceIds: const [],
      commandId: 'mix-clear-pulp',
      expectedRevision: 2,
      manual: true,
      manualPoints: 3,
      outputInstanceId: (index) => 'clear-pulp-$index',
    );
    final saved = catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(saved.objects.containsKey('clear-water-jar'), isTrue);
    expect(
      saved.objects['clear-water-jar']!.containerState['contentItemId'],
      isNull,
    );
    expect(saved.objects['clear-pulp-0']!.quality, 66);
    expect(saved.objects['clear-pulp-0']!.traits, {'even_pulp': true});
    await session.close();
  });

  test(
    'even pulp improves paperboard quality on its next recipe only',
    () async {
      final catalog = _catalog();
      var initial = catalog.emptyInventory(grids: _grids);
      for (final entry in [
        ('even-pulp', {'even_pulp': true}),
        ('plain-pulp', <String, Object?>{}),
      ]) {
        initial = initial.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: entry.$1,
            itemId: 'paper.pulp',
            source: 'crafted:test',
            quality: 60,
            traits: entry.$2,
          ),
          'board',
        );
      }
      initial = initial.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'paper-mould',
          itemId: 'tool.paper_mould',
          source: 'tutorial:paper',
          quality: 55,
          traits: const {},
        ),
        'board',
      );
      final session = await _session(_MemoryStore(), catalog, initial);
      await session.apply(
        commandId: 'unlock-paperboard',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 3,
            'unlockedStations': ['workbench'],
            'mastery': {'ss.recipe.form_paperboard': 1},
          },
        ),
      );
      final recipe = _recipe(
        recipeId: 'ss.recipe.form_paperboard',
        phase: 3,
        station: 'workbench',
        inputs: const [
          StreetScrapRecipeInput(itemId: 'paper.pulp', quantity: 2),
        ],
        tools: const ['tool.paper_mould'],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'paper.board', quantity: 1),
        ],
        primaryItem: 'paper.pulp',
        automatic: true,
        qualityTraitEffects: const [
          {
            'inputItemId': 'paper.pulp',
            'traitId': 'even_pulp',
            'polarity': 'positive',
            'modifier': 3,
          },
        ],
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['even-pulp', 'plain-pulp'],
        toolInstanceIds: const ['paper-mould'],
        commandId: 'form-even-paperboard',
        expectedRevision: 2,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'paper-board-$index',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects['paper-board-0']!.quality, 63);
      expect(saved.objects['paper-board-0']!.traits, isEmpty);
      await session.close();
    },
  );

  test('q4 boil checkpoints persist across reload and settle once', () async {
    final store = _MemoryStore();
    final catalog = _catalog();
    final initial = catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'persistent-boil-bottle',
            itemId: 'container.clean',
            source: 'test-source',
            quality: 55,
            traits: const {},
            containerState: const {
              'contentItemId': 'water.filtered',
              'contentQuality': 80,
              'contentSource': 'shore-dirty-filtered',
              'contentTraits': <String, Object?>{'clear': true},
              'requiresBoiling': true,
              'cleanliness': 'utility',
            },
          ),
          'board',
        )
        .addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'persistent-boil-fuel',
            itemId: 'fuel.dry',
            source: 'test-source',
            quality: 55,
            traits: const {},
          ),
          'board',
        );
    var session = await _session(
      store,
      catalog,
      initial,
      profileScope: 'q4-boil-persist',
      contentVersion: '0.1.13',
    );
    await session.apply(
      commandId: 'unlock-boil-recipe',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(state: {...state, 'chapter': 4}),
    );
    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.boil_water',
      phase: 4,
      station: 'kitchen',
      operationId: 'heat',
      durationSeconds: 10,
      instructions: '逐段控火煮沸水瓶內過濾水',
      inputGroups: const [
        [
          StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
          StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
        ],
      ],
      reusableTools: const [],
      outputs: const [],
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: ['container.clean'],
        loss: 0,
        mode: 'weighted-primary',
        masteryRevision: 1,
      ),
      retainedInputIds: const [],
      failureMode: 'explicitOutcome',
      failureOutcome: '失手保留原水，乾燥燃料消耗。',
      failureResolution: const StreetScrapFailureResolution(
        mode: 'sameOutputsQualityLoss',
        qualityLoss: 0,
      ),
      stateEffect: const {
        'type': 'transformContainerContent',
        'containerItemId': 'container.clean',
        'fromContentItemId': 'water.filtered',
        'toContentItemId': 'water.boiled',
        'successCleanliness': 'utility',
        'successRequiresBoiling': false,
        'preserveContainerContentQuality': true,
      },
      manualCheckpoints: [
        for (var i = 0; i < 3; i++)
          StreetScrapManualCheckpoint(
            prompt: '控火步驟 ${i + 1}',
            options: const ['正確', '失手', '偏差'],
            correctOption: 0,
          ),
      ],
    );
    await StreetScrapCrafting.beginManual(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      gridId: 'board',
      inputGroupIndex: 0,
      inputInstanceIds: const [
        'persistent-boil-bottle',
        'persistent-boil-fuel',
      ],
      toolInstanceIds: const [],
      operationId: 'boil-water-persisted',
      commandId: 'begin-persisted-boil',
      expectedRevision: 2,
      contentVersion: '0.1.13',
    );
    await StreetScrapCrafting.answerManualCheckpoint(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      operationId: 'boil-water-persisted',
      optionIndex: 0,
      expectedRevision: 3,
    );
    await session.close();
    session = await _session(
      store,
      catalog,
      initial,
      profileScope: 'q4-boil-persist',
      contentVersion: '0.1.13',
    );
    expect((session.snapshot.state['craftOperation']! as Map)['answers'], [0]);
    StreetScrapCommandResult? settled;
    for (var step = 1; step < 3; step++) {
      settled = await StreetScrapCrafting.answerManualCheckpoint(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        operationId: 'boil-water-persisted',
        optionIndex: 0,
        expectedRevision: session.snapshot.revision,
      );
    }
    expect(settled, isNotNull);
    expect(session.snapshot.state['craftOperation'], isNull);
    final saved = catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(saved.objects.keys, {'persistent-boil-bottle'});
    expect(
      saved.objects['persistent-boil-bottle']!.containerState['contentItemId'],
      'water.boiled',
    );
    expect(
      saved.objects['persistent-boil-bottle']!.containerState['contentQuality'],
      80,
    );
    expect(
      saved
          .objects['persistent-boil-bottle']!
          .containerState['requiresBoiling'],
      isFalse,
    );
    expect(
      saved.objects['persistent-boil-bottle']!.containerState['contentTraits'],
      isEmpty,
    );
    await session.close();
  });

  const failure = StreetScrapFailureResolution(
    mode: 'sameOutputsQualityLoss',
    qualityLoss: 10,
  );

  test(
    'precise manual craft atomically consumes inputs, places output and unlocks only this recipe',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(
        store,
        catalog,
        _inventory(
          catalog,
          ragTraits: const {
            'source_wear': true,
            'intact_fibre': true,
            'fiber_extra': true,
            'frayed': true,
          },
        ),
      );
      final recipe = _recipe(
        failure: failure,
        traitResolution: const {
          'inherit': [
            {
              'inputItemId': 'cloth.rag_piece',
              'map': {'source_wear': 'inherited_wear'},
            },
          ],
          'polarity': {
            'inherited_wear': 'negative',
            'clean_stitch': 'positive',
            'uneven_stitch': 'negative',
          },
          'success': {},
          'precise': {'clean_stitch': true},
          'failure': {'uneven_stitch': true},
        },
        qualityTraitEffects: const [
          {
            'inputItemId': 'cloth.rag_piece',
            'traitId': 'fiber_extra',
            'polarity': 'positive',
            'modifier': 5,
          },
          {
            'inputItemId': 'cloth.rag_piece',
            'traitId': 'intact_fibre',
            'polarity': 'positive',
            'modifier': 3,
          },
          {
            'inputItemId': 'cloth.rag_piece',
            'traitId': 'frayed',
            'polarity': 'negative',
            'modifier': -3,
          },
        ],
      );
      final command = await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        commandId: 'craft-precise',
        expectedRevision: 1,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (index) => 'crafted-$index',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects.keys, containsAll(['needle', 'crafted-0']));
      expect(saved.objects.keys, isNot(contains('rag-a')));
      expect(
        saved.objects['crafted-0']!.quality,
        80,
      ); // +8 precise, +5 selected positive, -3 negative
      expect(saved.objects['crafted-0']!.traits, {
        'inherited_wear': true,
        'clean_stitch': true,
      });
      final provenance = saved.objects['crafted-0']!.provenance;
      expect(provenance, hasLength(1));
      expect(provenance.single['eventId'], 'craft:crafted-0');
      expect(provenance.single['recipeId'], 'ss.recipe.sew_strip');
      expect(provenance.single['revision'], 2);
      expect(
        (provenance.single['inputs'] as List)
            .map((input) => (input as Map)['instanceId'])
            .toSet(),
        {'rag-a', 'rag-b', 'thread'},
      );
      final restored = catalog.inventoryFromJson(
        grids: _grids,
        json: saved.toJson(),
      );
      expect(restored.objects['crafted-0']!.provenance, provenance);
      expect(session.snapshot.state['mastery'], {'ss.recipe.sew_strip': 1});
      expect(session.snapshot.state['recipeCompletionCounts'], {
        'ss.recipe.sew_strip': 1,
      });
      expect(command.revision, 2);
      final replay = await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        commandId: 'craft-precise',
        expectedRevision: 1,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (index) => 'crafted-$index',
      );
      expect(replay.wasDuplicate, isTrue);
      expect(session.snapshot.revision, 2);
      expect(session.snapshot.state['recipeCompletionCounts'], {
        'ss.recipe.sew_strip': 1,
      });
      expect(
        saved.objects.keys.where((id) => id.startsWith('crafted-')),
        hasLength(1),
      );
      await session.close();
    },
  );

  test(
    'insulated-box sewing upgrades the original instance and survives checkpoints',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      var initial = catalog.emptyInventory(grids: _grids);
      for (final item in [
        catalog.createObject(
          instanceId: 'meal-box-original',
          itemId: 'container.meal_box',
          source: 'crafted:ss.recipe.meal_box',
          quality: 65,
          traits: const {},
          containerState: const {'cleanliness': 'clean'},
        ),
        catalog.createObject(
          instanceId: 'insulation-sheet',
          itemId: 'cloth.insulation',
          source: 'found',
          quality: 55,
          traits: const {},
        ),
        catalog.createObject(
          instanceId: 'insulation-thread',
          itemId: 'cloth.thread_spool',
          source: 'found',
          quality: 55,
          traits: const {},
        ),
        catalog.createObject(
          instanceId: 'insulation-needle',
          itemId: 'tool.needle',
          source: 'starter',
          quality: 50,
          traits: const {},
        ),
      ]) {
        initial = initial.addAndPlaceFirstFit(item, 'board');
      }
      final session = await _session(
        store,
        catalog,
        initial,
        contentVersion: '0.1.26',
      );
      await session.apply(
        commandId: 'insulated-chapter-four',
        expectedRevision: 1,
        reduce: (state) =>
            StreetScrapReduction(state: {...state, 'chapter': 4}),
      );
      final recipe = StreetScrapRecipe(
        id: 'ss.recipe.insulated_box',
        phase: 4,
        station: 'workbench',
        operationId: 'sew',
        durationSeconds: 10,
        instructions: '沿餐盒外緣縫合隔熱布',
        inputGroups: const [
          [
            StreetScrapRecipeInput(itemId: 'container.meal_box', quantity: 1),
            StreetScrapRecipeInput(itemId: 'cloth.insulation', quantity: 1),
            StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 1),
          ],
        ],
        reusableTools: const ['tool.needle'],
        outputs: const [],
        quality: StreetScrapRecipeQualityRule(
          primaryInputs: const ['container.meal_box'],
          loss: 0,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const ['container.meal_box'],
        failureMode: 'reducedQualityOutput',
        failureOutcome: '隔熱布仍附著，品質依操作結果調整。',
        failureResolution: const StreetScrapFailureResolution(
          mode: 'sameOutputsQualityLoss',
          qualityLoss: 10,
        ),
        manualCheckpoints: [
          for (var step = 0; step < 3; step++)
            StreetScrapManualCheckpoint(
              prompt: '縫製步驟 ${step + 1}',
              options: const ['依提示操作', '錯誤操作'],
              correctOption: 0,
            ),
        ],
        stateEffect: const {
          'type': 'transformObject',
          'fromItemId': 'container.meal_box',
          'toItemId': 'container.meal_box_insulated',
          'requireEmptyContainer': true,
        },
      );
      const operationId = 'insulated-operation';
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const [
          'meal-box-original',
          'insulation-sheet',
          'insulation-thread',
        ],
        toolInstanceIds: const ['insulation-needle'],
        operationId: operationId,
        commandId: 'begin-insulated-operation',
        expectedRevision: 2,
        contentVersion: '0.1.26',
      );
      StreetScrapCommandResult? settled;
      for (var step = 0; step < 3; step++) {
        settled = await StreetScrapCrafting.answerManualCheckpoint(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          operationId: operationId,
          optionIndex: 0,
          expectedRevision: session.snapshot.revision,
        );
      }
      expect(settled, isNotNull);
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final upgraded = saved.objects['meal-box-original']!;
      expect(upgraded.itemId, 'container.meal_box_insulated');
      expect(upgraded.quality, 73);
      expect(saved.placements['meal-box-original']!.x, 0);
      expect(saved.objects.containsKey('insulation-sheet'), isFalse);
      expect(saved.objects.containsKey('insulation-thread'), isFalse);
      expect(saved.objects.containsKey('insulation-needle'), isTrue);
      await session.close();
    },
  );

  test(
    'manual miss uses the explicit -10 branch and does not unlock mastery',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(store, catalog, _inventory(catalog));
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        commandId: 'craft-miss',
        expectedRevision: 1,
        manual: true,
        manualPoints: 1,
        outputInstanceId: (index) => 'failed-output-$index',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects['failed-output-0']!.quality, 60); // mean 70 - 10
      expect(session.snapshot.state['mastery'], isEmpty);
      await session.close();
    },
  );

  test(
    'a generic table failure policy is executable and consumes selected inputs',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(store, catalog, _inventory(catalog));
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure, recipeId: 'ss.recipe.clean_metal'),
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        commandId: 'generic-table-miss',
        expectedRevision: 1,
        manual: true,
        manualPoints: 1,
        outputInstanceId: (index) => 'generic-miss-$index',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects.keys, contains('generic-miss-0'));
      expect(saved.objects['generic-miss-0']!.quality, 60);
      expect(saved.objects.keys, isNot(contains('rag-a')));
      expect(saved.objects.keys, isNot(contains('thread')));
      await session.close();
    },
  );

  test(
    'fish fillet failure uses its explicit meat, bone and scrap branch',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(
        store,
        catalog,
        _inventory(catalog, fish: true),
      );
      await session.apply(
        commandId: 'unlock-fish-fillet',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 2,
            'tutorialTasks': {'q2.02': true},
          },
        ),
      );
      final recipe = _recipe(
        failure: failure,
        recipeId: 'ss.recipe.fillet_fish',
        phase: 2,
        station: 'dock',
        inputs: const [StreetScrapRecipeInput(itemId: 'fish.raw', quantity: 1)],
        tools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 2),
          StreetScrapRecipeInput(itemId: 'fish.bone', quantity: 1),
        ],
        failureOutputs: const [
          StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 1),
          StreetScrapRecipeInput(itemId: 'fish.bone', quantity: 1),
          StreetScrapRecipeInput(itemId: 'food.scrap', quantity: 1),
        ],
        primaryItem: 'fish.raw',
        traitResolution: const {
          'inherit': [],
          'polarity': {'rich_ingredient': 'positive', 'rough_cut': 'negative'},
          'success': {},
          'precise': {'rich_ingredient': true},
          'failure': {'rough_cut': true},
        },
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['raw-fish'],
        toolInstanceIds: const [],
        commandId: 'fillet-missed',
        expectedRevision: 2,
        manual: true,
        manualPoints: 1,
        outputInstanceId: (index) => 'fillet-output-$index',
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects.containsKey('raw-fish'), isFalse);
      expect(
        saved.objects.values
            .singleWhere((item) => item.itemId == 'fish.meat')
            .traits,
        {'rough_cut': true},
      );
      expect(saved.objects.values.map((item) => item.itemId).toSet(), {
        'cloth.rag_piece',
        'cloth.thread_spool',
        'tool.needle',
        'fish.meat',
        'fish.bone',
        'food.scrap',
      });
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q2.03'],
        isTrue,
      );
      expect(session.snapshot.state['q2.03Choice'], 'fillet');
      expect(
        (session.snapshot.state['tutorialTasks']! as Map).values,
        everyElement(isA<bool>()),
      );
      await session.close();
    },
  );

  test(
    'q4.01 filtration miss preserves water and wears filter; success unlocks task',
    () async {
      for (final points in [1, 3]) {
        final catalog = _catalog();
        var initial = catalog.emptyInventory(grids: _grids);
        for (final entry in [
          ('bottle', 'container.clean', null),
          ('charcoal', 'material.charcoal', null),
          ('filter', 'material.filter_cloth', 20),
        ]) {
          initial = initial.addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: entry.$1,
              itemId: entry.$2,
              source: 'tutorial:q4.01-filter-kit',
              quality: 55,
              traits: const {},
              toolDurability: entry.$3,
              containerState: entry.$1 == 'bottle'
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
            'board',
          );
        }
        final session = await _session(
          _MemoryStore(),
          catalog,
          initial,
          contentVersion: '0.1.13',
        );
        await session.apply(
          commandId: 'unlock-water-$points',
          expectedRevision: 1,
          reduce: (state) => StreetScrapReduction(
            state: {
              ...state,
              'chapter': 4,
              'tutorialTasks': {'q3.04': true},
            },
          ),
        );
        final recipe = StreetScrapRecipe(
          id: 'ss.recipe.filter_turbid',
          phase: 4,
          station: 'kitchen',
          operationId: 'filter',
          durationSeconds: 10,
          instructions: '依序通過濾布與木炭層',
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
          failureOutcome: '失手保留濁水，消耗木炭並磨耗濾布一次。',
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
          manualCheckpoints: List.generate(
            3,
            (index) => StreetScrapManualCheckpoint(
              prompt: '檢查濾層 ${index + 1}',
              options: const ['依序正確', '順序錯誤', '跳過'],
              correctOption: 0,
            ),
          ),
        );
        final pulpRecipe = StreetScrapRecipe(
          id: 'ss.recipe.mix_pulp',
          phase: 1,
          station: 'recycler',
          operationId: 'mix-pulp',
          durationSeconds: 10,
          instructions: 'Mix paper with water.',
          inputGroups: const [],
          reusableTools: const [],
          outputs: const [],
          quality: StreetScrapRecipeQualityRule(
            primaryInputs: const [],
            loss: 0,
            mode: 'weighted-primary',
            masteryRevision: 1,
          ),
          retainedInputIds: const [],
          failureMode: 'explicitOutcome',
          failureOutcome: 'No output.',
        );
        final tutorialWater = initial.objects['bottle']!;
        expect(
          StreetScrapCrafting.isQuestSupplyAllowedForRecipe(
            recipe,
            tutorialWater,
          ),
          isTrue,
        );
        expect(
          StreetScrapCrafting.isQuestSupplyAllowedForRecipe(
            pulpRecipe,
            tutorialWater,
          ),
          isFalse,
        );
        final operationId = 'filter-water-$points';
        await StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['bottle', 'charcoal'],
          toolInstanceIds: const ['filter'],
          operationId: operationId,
          commandId: 'begin-filter-$points',
          expectedRevision: 2,
          contentVersion: '0.1.13',
        );
        final answers = points == 3 ? const [0, 0, 0] : const [0, 1, 1];
        StreetScrapCommandResult? settled;
        for (final answer in answers) {
          settled = await StreetScrapCrafting.answerManualCheckpoint(
            session: session,
            inventoryCatalog: catalog,
            recipe: recipe,
            grids: _grids,
            operationId: operationId,
            optionIndex: answer,
            expectedRevision: session.snapshot.revision,
          );
        }
        expect(settled, isNotNull);
        final saved = catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        expect(saved.objects['filter']!.toolDurability, 19);
        expect(saved.objects.containsKey('charcoal'), isFalse);
        expect(saved.objects.containsKey('bottle'), isTrue);
        expect(
          saved.objects['bottle']!.containerState['contentItemId'],
          points >= 2 ? 'water.filtered' : 'water.turbid',
        );
        expect(
          saved.objects['bottle']!.containerState['contentTraits'],
          points == 3 ? {'clear': true} : isEmpty,
        );
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q4.01'] ?? false,
          points >= 2,
        );
        await session.close();
      }
    },
  );

  test(
    'fish ingredient traits modify fish soup content quality without stacking',
    () async {
      for (final entry in [('rich_ingredient', 63), ('rough_cut', 57)]) {
        final catalog = _catalog();
        var initial = catalog.emptyInventory(grids: _grids);
        for (var index = 0; index < 2; index++) {
          initial = initial.addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'soup-fish-${entry.$1}-$index',
              itemId: 'fish.meat',
              source: 'fillet:test',
              quality: 60,
              traits: {entry.$1: true},
            ),
            'board',
          );
        }
        initial = initial
            .addAndPlaceFirstFit(
              catalog.createObject(
                instanceId: 'soup-water-${entry.$1}',
                itemId: 'container.clean',
                source: 'boiled:test',
                quality: 55,
                traits: const {},
                containerState: const {
                  'contentItemId': 'water.boiled',
                  'contentQuality': 60,
                  'contentTraits': <String, Object?>{},
                  'requiresBoiling': false,
                },
              ),
              'board',
            )
            .addAndPlaceFirstFit(
              catalog.createObject(
                instanceId: 'soup-fuel-${entry.$1}',
                itemId: 'fuel.dry',
                source: 'supply:test',
                quality: 55,
                traits: const {},
              ),
              'board',
            )
            .addAndPlaceFirstFit(
              catalog.createObject(
                instanceId: 'soup-box-${entry.$1}',
                itemId: 'container.meal_box',
                source: 'supply:test',
                quality: 55,
                traits: const {},
                containerState: const {'cleanliness': 'clean'},
              ),
              'board',
            );
        final session = await _session(_MemoryStore(), catalog, initial);
        await session.apply(
          commandId: 'unlock-fish-soup-${entry.$1}',
          expectedRevision: 1,
          reduce: (state) => StreetScrapReduction(
            state: {
              ...state,
              'chapter': 4,
              'tutorialTasks': {'q4.01': true},
              'mastery': {'ss.recipe.soup_fish': 1},
            },
          ),
        );
        final trait = entry.$1;
        final polarity = trait == 'rich_ingredient' ? 'positive' : 'negative';
        final recipe = StreetScrapRecipe(
          id: 'ss.recipe.soup_fish',
          phase: 4,
          station: 'kitchen',
          operationId: 'cook',
          durationSeconds: 12,
          instructions: '煮魚湯',
          inputGroups: const [
            [
              StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 2),
              StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
              StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
              StreetScrapRecipeInput(itemId: 'container.meal_box', quantity: 1),
            ],
          ],
          reusableTools: const [],
          outputs: const [],
          quality: StreetScrapRecipeQualityRule(
            primaryInputs: const ['fish.meat'],
            loss: 0,
            mode: 'weighted-primary',
            masteryRevision: 1,
          ),
          retainedInputIds: const [],
          failureMode: 'explicitOutcome',
          failureOutcome: '失敗餐留在所選餐盒。',
          failureResolution: const StreetScrapFailureResolution(
            mode: 'sameOutputsQualityLoss',
            qualityLoss: 0,
          ),
          qualityTraitEffects: [
            {
              'inputItemId': 'fish.meat',
              'traitId': trait,
              'polarity': polarity,
              'modifier': trait == 'rich_ingredient' ? 3 : -3,
            },
          ],
          stateEffect: const {
            'type': 'transformContainers',
            'containers': [
              {
                'containerItemId': 'container.clean',
                'requiredContentItemId': 'water.boiled',
                'successContentItemId': null,
                'failureContentItemId': null,
              },
              {
                'containerItemId': 'container.meal_box',
                'requiredContentItemId': null,
                'successContentItemId': 'meal.soup_fish',
                'failureContentItemId': 'meal.failed',
              },
            ],
          },
        );
        await StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: [
            'soup-fish-$trait-0',
            'soup-fish-$trait-1',
            'soup-water-$trait',
            'soup-fuel-$trait',
            'soup-box-$trait',
          ],
          toolInstanceIds: const [],
          commandId: 'cook-fish-$trait',
          expectedRevision: 2,
          manual: false,
          manualPoints: 0,
          outputInstanceId: (index) => 'unused-fish-soup-$index',
        );
        final saved = catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        expect(
          saved.objects['soup-box-$trait']!.containerState['contentQuality'],
          entry.$2,
        );
        await session.close();
      }
    },
  );

  test(
    'precise and failed fuel drying emit mutually exclusive fuel traits',
    () async {
      for (final entry in [(3, 'even_burn'), (1, 'smoky')]) {
        final catalog = _catalog();
        var initial = catalog.emptyInventory(grids: _grids);
        for (var index = 0; index < 2; index++) {
          initial = initial.addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'dry-fuel-input-${entry.$1}-$index',
              itemId: 'fuel.mixed',
              source: 'crafted:test',
              quality: 60,
              traits: const {},
            ),
            'board',
          );
        }
        final session = await _session(_MemoryStore(), catalog, initial);
        await session.apply(
          commandId: 'unlock-dry-fuel-${entry.$1}',
          expectedRevision: 1,
          reduce: (state) =>
              StreetScrapReduction(state: {...state, 'chapter': 3}),
        );
        final recipe = _recipe(
          recipeId: 'ss.recipe.dry_fuel',
          phase: 3,
          station: 'workbench',
          operationId: 'heat',
          inputs: const [
            StreetScrapRecipeInput(itemId: 'fuel.mixed', quantity: 2),
          ],
          tools: const [],
          primaryItem: 'fuel.mixed',
          outputs: const [
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 2),
          ],
          failureOutputs: const [
            StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
            StreetScrapRecipeInput(itemId: 'fuel.mixed', quantity: 1),
          ],
          failure: const StreetScrapFailureResolution(
            mode: 'sameOutputsQualityLoss',
            qualityLoss: 0,
          ),
          traitResolution: const {
            'inherit': [],
            'polarity': {'even_burn': 'positive', 'smoky': 'negative'},
            'success': {},
            'precise': {'even_burn': true},
            'failure': {'smoky': true},
          },
        );
        await StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: [
            'dry-fuel-input-${entry.$1}-0',
            'dry-fuel-input-${entry.$1}-1',
          ],
          toolInstanceIds: const [],
          commandId: 'dry-fuel-${entry.$1}',
          expectedRevision: 2,
          manual: true,
          manualPoints: entry.$1,
          outputInstanceId: (index) => 'dry-fuel-output-${entry.$1}-$index',
        );
        final saved = catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        expect(
          saved.objects.values
              .where(
                (item) =>
                    item.itemId == 'fuel.dry' || item.itemId == 'fuel.mixed',
              )
              .every((item) => item.traits[entry.$2] == true),
          isTrue,
        );
        await session.close();
      }
    },
  );

  test('dirty filter marks same bottle as requiring boiling', () async {
    final catalog = _catalog();
    var inventory = catalog.emptyInventory(grids: _grids);
    for (final entry in [
      ('dirty-bottle', 'container.clean', null),
      ('dirty-charcoal', 'material.charcoal', null),
      ('dirty-filter', 'material.filter_cloth', 20),
    ]) {
      inventory = inventory.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: entry.$1,
          itemId: entry.$2,
          source: 'shore:dirty-water',
          quality: 55,
          traits: const {},
          toolDurability: entry.$3,
          containerState: entry.$1 == 'dirty-bottle'
              ? const {
                  'contentItemId': 'water.dirty',
                  'contentQuality': 61,
                  'contentSource': 'shore:dirty-water',
                  'contentTraits': {'polluted': true},
                  'requiresBoiling': false,
                  'cleanliness': 'utility',
                }
              : const {},
        ),
        'board',
      );
    }
    final session = await _session(
      _MemoryStore(),
      catalog,
      inventory,
      contentVersion: '0.1.21',
    );
    await session.apply(
      commandId: 'dirty-filter-chapter',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(state: {...state, 'chapter': 4}),
    );
    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.filter_dirty',
      phase: 4,
      station: 'kitchen',
      operationId: 'filter',
      durationSeconds: 10,
      instructions: '隔離污染來源，依序過濾',
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
      failureOutcome: '失手保留原瓶髒水。',
      failureResolution: const StreetScrapFailureResolution(
        mode: 'sameOutputsQualityLoss',
        qualityLoss: 0,
      ),
      stateEffect: const {
        'type': 'transformContainers',
        'containers': [
          {
            'containerItemId': 'container.clean',
            'requiredContentItemId': 'water.dirty',
            'successContentItemId': 'water.filtered',
            'failureContentItemId': 'water.dirty',
            'successCleanliness': 'utility',
            'failureCleanliness': 'utility',
            'successRequiresBoiling': true,
            'failureRequiresBoiling': false,
            'preserveContainerContentSource': true,
            'preserveContainerContentTraits': true,
            'contentTraitResolution': {
              'precise': {'clear': true},
            },
          },
        ],
      },
      manualCheckpoints: List.generate(
        3,
        (index) => StreetScrapManualCheckpoint(
          prompt: '過濾 ${index + 1}',
          options: const ['正確', '失誤'],
          correctOption: 0,
        ),
      ),
    );
    await StreetScrapCrafting.beginManual(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      gridId: 'board',
      inputGroupIndex: 0,
      inputInstanceIds: const ['dirty-bottle', 'dirty-charcoal'],
      toolInstanceIds: const ['dirty-filter'],
      operationId: 'dirty-filter-operation',
      commandId: 'dirty-filter-begin',
      expectedRevision: 2,
      contentVersion: '0.1.21',
    );
    for (var index = 0; index < 3; index++) {
      await StreetScrapCrafting.answerManualCheckpoint(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        operationId: 'dirty-filter-operation',
        optionIndex: 0,
        expectedRevision: session.snapshot.revision,
      );
    }
    final saved = catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    final bottle = saved.objects['dirty-bottle']!;
    expect(bottle.containerState['contentItemId'], 'water.filtered');
    expect(bottle.containerState['requiresBoiling'], isTrue);
    expect(bottle.containerState['contentQuality'], 69);
    expect(bottle.containerState['contentSource'], 'shore:dirty-water');
    expect(bottle.containerState['contentTraits'], {
      'polluted': true,
      'clear': true,
    });
    expect(saved.objects['dirty-filter']!.toolDurability, 19);
    expect(saved.objects.containsKey('dirty-charcoal'), isFalse);
    await session.close();
  });

  test(
    'q4.02 cooks into the selected meal box and empties the same water bottle',
    () async {
      for (final points in [1, 3]) {
        for (final mealBoxItemId in [
          'container.meal_box',
          'container.meal_box_insulated',
        ]) {
          final catalog = _catalog();
          var initial = catalog.emptyInventory(grids: _grids);
          final objects = [
            catalog.createObject(
              instanceId: 'soup-food',
              itemId: 'food.cleaned',
              source: 'foraged',
              quality: 60,
              traits: const {},
            ),
            catalog.createObject(
              instanceId: 'soup-water-bottle',
              itemId: 'container.clean',
              source: 'found:bottle',
              quality: 72,
              traits: const {},
              containerState: const {
                'contentItemId': 'water.boiled',
                'contentQuality': 64,
                'contentSource': 'boiled-at-home',
                'contentTraits': <String, Object?>{},
                'requiresBoiling': false,
                'cleanliness': 'utility',
              },
            ),
            catalog.createObject(
              instanceId: 'soup-fuel',
              itemId: 'fuel.dry',
              source: 'found:fuel',
              quality: 55,
              traits: const {},
            ),
            catalog.createObject(
              instanceId: 'soup-meal-box',
              itemId: mealBoxItemId,
              source: 'found:meal-box',
              quality: 70,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
          ];
          for (final item in objects) {
            initial = initial.addAndPlaceFirstFit(item, 'board');
          }
          final session = await _session(
            _MemoryStore(),
            catalog,
            initial,
            contentVersion: '0.1.26',
          );
          await session.apply(
            commandId: 'unlock-soup-$points',
            expectedRevision: 1,
            reduce: (state) => StreetScrapReduction(
              state: {
                ...state,
                'chapter': 4,
                'tutorialTasks': {'q4.01': true},
              },
            ),
          );
          final recipe = StreetScrapRecipe(
            id: 'ss.recipe.soup_basic',
            phase: 4,
            station: 'kitchen',
            operationId: 'cook',
            durationSeconds: 12,
            instructions: '控火並把湯裝入餐盒',
            inputGroups: const [
              [
                StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 1),
                StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
                StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
                StreetScrapRecipeInput(
                  itemId: 'container.meal_box',
                  quantity: 1,
                ),
              ],
              [
                StreetScrapRecipeInput(itemId: 'food.cleaned', quantity: 1),
                StreetScrapRecipeInput(itemId: 'container.clean', quantity: 1),
                StreetScrapRecipeInput(itemId: 'fuel.dry', quantity: 1),
                StreetScrapRecipeInput(
                  itemId: 'container.meal_box_insulated',
                  quantity: 1,
                ),
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
            failureOutcome: '餐盒裝入成功餐或失敗餐，水瓶留空。',
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
                {
                  'containerItemId': 'container.meal_box_insulated',
                  'optional': true,
                  'requiredContentItemId': null,
                  'successContentItemId': 'meal.soup_basic',
                  'failureContentItemId': 'meal.failed',
                  'successCleanliness': 'clean',
                  'failureCleanliness': 'clean',
                },
              ],
            },
            manualCheckpoints: List.generate(
              3,
              (index) => StreetScrapManualCheckpoint(
                prompt: '料理檢查 ${index + 1}',
                options: const ['依提示操作', '操作偏離提示'],
                correctOption: 0,
              ),
            ),
          );
          final before = initial.placements;
          final operationId = 'soup-operation-$points';
          await StreetScrapCrafting.beginManual(
            session: session,
            inventoryCatalog: catalog,
            recipe: recipe,
            grids: _grids,
            gridId: 'board',
            inputGroupIndex: mealBoxItemId == 'container.meal_box' ? 0 : 1,
            inputInstanceIds: const [
              'soup-food',
              'soup-water-bottle',
              'soup-fuel',
              'soup-meal-box',
            ],
            toolInstanceIds: const [],
            operationId: operationId,
            commandId: 'begin-soup-$points',
            expectedRevision: 2,
            contentVersion: '0.1.26',
          );
          final answers = points == 3 ? const [0, 0, 0] : const [0, 1, 1];
          for (final answer in answers) {
            await StreetScrapCrafting.answerManualCheckpoint(
              session: session,
              inventoryCatalog: catalog,
              recipe: recipe,
              grids: _grids,
              operationId: operationId,
              optionIndex: answer,
              expectedRevision: session.snapshot.revision,
            );
          }
          final saved = catalog.inventoryFromJson(
            grids: _grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          );
          expect(saved.objects.containsKey('soup-food'), isFalse);
          expect(saved.objects.containsKey('soup-fuel'), isFalse);
          expect(
            saved.objects['soup-water-bottle']!.containerState['contentItemId'],
            isNull,
          );
          expect(
            saved.objects['soup-meal-box']!.containerState['contentItemId'],
            points >= 2 ? 'meal.soup_basic' : 'meal.failed',
          );
          expect(saved.objects['soup-meal-box']!.itemId, mealBoxItemId);
          for (final id in ['soup-water-bottle', 'soup-meal-box']) {
            expect(saved.placements[id]!.x, before[id]!.x);
            expect(saved.placements[id]!.y, before[id]!.y);
            expect(saved.placements[id]!.gridId, before[id]!.gridId);
          }
          expect(
            (session.snapshot.state['tutorialTasks']! as Map)['q4.02'] ?? false,
            points >= 2,
          );
          await session.close();
        }
      }
    },
  );

  test('q4.02 accepts every planned soup route after filtration', () async {
    const recipes = <String, (String, int, String)>{
      'ss.recipe.soup_basic': ('food.cleaned', 1, 'meal.soup_basic'),
      'ss.recipe.soup_vegetable': ('food.cleaned', 2, 'meal.soup_vegetable'),
      'ss.recipe.soup_fish': ('fish.meat', 2, 'meal.soup_fish'),
    };
    for (final entry in recipes.entries) {
      final catalog = _catalog();
      var inventory = catalog.emptyInventory(grids: _grids);
      final (ingredientId, ingredientCount, mealId) = entry.value;
      final inputIds = <String>[];
      for (var index = 0; index < ingredientCount; index++) {
        final id = 'q402-${entry.key}-ingredient-$index';
        inputIds.add(id);
        inventory = inventory.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: id,
            itemId: ingredientId,
            source: 'test:chapter-four',
            quality: 55,
            traits: const {},
          ),
          'board',
        );
      }
      final session = await _session(_MemoryStore(), catalog, inventory);
      await session.apply(
        commandId: 'unlock-${entry.key}',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'chapter': 4, 'tutorialTasks': <String, bool>{}},
        ),
      );
      final recipe = _recipe(
        recipeId: entry.key,
        phase: 4,
        station: 'kitchen',
        operationId: 'cook',
        inputs: [
          StreetScrapRecipeInput(
            itemId: ingredientId,
            quantity: ingredientCount,
          ),
        ],
        tools: const [],
        outputs: [StreetScrapRecipeInput(itemId: mealId, quantity: 1)],
        primaryItem: ingredientId,
      );
      await expectLater(
        StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: inputIds,
          toolInstanceIds: const [],
          commandId: 'blocked-${entry.key}',
          expectedRevision: 2,
          manual: true,
          manualPoints: 3,
          outputInstanceId: (index) => 'blocked-${entry.key}-$index',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'q4.01WaterRequired',
          ),
        ),
      );
      expect(session.snapshot.revision, 2);
      await session.apply(
        commandId: 'complete-filtering-${entry.key}',
        expectedRevision: 2,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {'q4.01': true},
          },
        ),
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: recipe,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: inputIds,
        toolInstanceIds: const [],
        commandId: 'cook-${entry.key}',
        expectedRevision: 3,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (index) => 'q402-${entry.key}-meal-$index',
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q4.02'],
        isTrue,
        reason: entry.key,
      );
      await session.close();
    }
  });

  test(
    'unstructured failure and insufficient result space leave inputs and revision untouched',
    () async {
      for (final noSpace in [false, true]) {
        final store = _MemoryStore();
        final catalog = _catalog(outputWidth: noSpace ? 2 : 1);
        final initial = _inventory(catalog, blocker: noSpace);
        final session = await _session(store, catalog, initial);
        if (!noSpace) {
          await expectLater(
            StreetScrapCrafting.craft(
              session: session,
              inventoryCatalog: catalog,
              recipe: _recipe(),
              grids: _grids,
              gridId: 'board',
              inputGroupIndex: 0,
              inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
              toolInstanceIds: const ['needle'],
              commandId: 'unsafe-miss',
              expectedRevision: 1,
              manual: true,
              manualPoints: 0,
              outputInstanceId: (index) => 'unsafe-$index',
            ),
            throwsA(isA<StateError>()),
          );
        } else {
          // The full 2×2 grid cannot fit the 2×2 result after the selected inputs
          // are removed because the reusable needle occupies the remaining cell.
          await expectLater(
            StreetScrapCrafting.craft(
              session: session,
              inventoryCatalog: catalog,
              recipe: _recipe(failure: failure),
              grids: initial.grids,
              gridId: 'board',
              inputGroupIndex: 0,
              inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
              toolInstanceIds: const ['needle'],
              commandId: 'no-space',
              expectedRevision: 1,
              manual: true,
              manualPoints: 2,
              outputInstanceId: (index) => 'no-space-$index',
            ),
            throwsA(isA<StateError>()),
          );
        }
        final unchanged = catalog.inventoryFromJson(
          grids: initial.grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        expect(
          unchanged.objects.keys,
          containsAll(['rag-a', 'rag-b', 'thread', 'needle']),
        );
        expect(session.snapshot.revision, 1);
        await session.close();
      }
    },
  );

  test('quick craft is gated by matching recipe mastery revision', () async {
    final store = _MemoryStore();
    final catalog = _catalog();
    final session = await _session(store, catalog, _inventory(catalog));
    await expectLater(
      StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        commandId: 'quick-before-mastery',
        expectedRevision: 1,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'quick-$index',
      ),
      throwsStateError,
    );
    expect(session.snapshot.revision, 1);
    await session.close();
  });

  test('confirmation-only fish packing needs no manual mastery', () async {
    final catalog = _catalog();
    var inventory = catalog.emptyInventory(grids: _grids);
    for (final item in [
      catalog.createObject(
        instanceId: 'pack-meat-a',
        itemId: 'fish.meat',
        source: 'crafted:fillet',
        quality: 66,
        traits: const {},
      ),
      catalog.createObject(
        instanceId: 'pack-meat-b',
        itemId: 'fish.meat',
        source: 'crafted:fillet',
        quality: 66,
        traits: const {},
      ),
      catalog.createObject(
        instanceId: 'pack-material',
        itemId: 'paper.packaging',
        source: 'crafted:packaging',
        quality: 85,
        traits: const {},
      ),
    ]) {
      inventory = inventory.addAndPlaceFirstFit(item, 'board');
    }
    final session = await _session(_MemoryStore(), catalog, inventory);
    await session.apply(
      commandId: 'unlock-fish-pack',
      expectedRevision: 1,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 5,
          'unlockedStations': ['workbench'],
        },
      ),
    );
    final recipe = StreetScrapRecipe(
      id: 'ss.recipe.fish_pack',
      phase: 3,
      station: 'workbench',
      operationId: 'assemble',
      durationSeconds: 8,
      instructions: '分裝魚肉並封包',
      inputGroups: const [
        [
          StreetScrapRecipeInput(itemId: 'fish.meat', quantity: 2),
          StreetScrapRecipeInput(itemId: 'paper.packaging', quantity: 1),
        ],
      ],
      reusableTools: const [],
      outputs: const [StreetScrapRecipeInput(itemId: 'fish.pack', quantity: 1)],
      quality: StreetScrapRecipeQualityRule(
        primaryInputs: ['fish.meat'],
        loss: 0,
        mode: 'preserve-primary',
        masteryRevision: 1,
      ),
      retainedInputIds: const [],
      failureMode: 'noPenalty',
      failureOutcome: '確認式操作不進入失誤分支。',
    );
    await StreetScrapCrafting.craft(
      session: session,
      inventoryCatalog: catalog,
      recipe: recipe,
      grids: _grids,
      gridId: 'board',
      inputGroupIndex: 0,
      inputInstanceIds: const ['pack-meat-a', 'pack-meat-b', 'pack-material'],
      toolInstanceIds: const [],
      commandId: 'craft-fish-pack',
      expectedRevision: 2,
      manual: false,
      manualPoints: 0,
      outputInstanceId: (index) => 'fish-pack-$index',
    );
    final saved = catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(saved.objects.keys, contains('fish-pack-0'));
    expect(saved.objects['fish-pack-0']!.quality, 66);
    expect(
      saved.objects.keys,
      isNot(containsAll(['pack-meat-a', 'pack-meat-b', 'pack-material'])),
    );
    await session.close();
  });

  test(
    'chapter-locked recipes reject manual and quick settlement without mutation',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(store, catalog, _inventory(catalog));
      final futureRecipe = _recipe(
        recipeId: 'ss.recipe.phase_one_sample',
        phase: 1,
        failure: failure,
      );
      await expectLater(
        StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: catalog,
          recipe: futureRecipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
          toolInstanceIds: const ['needle'],
          operationId: 'locked-operation',
          commandId: 'begin-locked-operation',
          expectedRevision: 1,
          contentVersion: '0.1.0',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'recipePhaseLocked',
          ),
        ),
      );
      for (final manual in [true, false]) {
        await expectLater(
          StreetScrapCrafting.craft(
            session: session,
            inventoryCatalog: catalog,
            recipe: futureRecipe,
            grids: _grids,
            gridId: 'board',
            inputGroupIndex: 0,
            inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
            toolInstanceIds: const ['needle'],
            commandId: 'locked-phase-$manual',
            expectedRevision: 1,
            manual: manual,
            manualPoints: manual ? 3 : 0,
            outputInstanceId: (index) => 'locked-$manual-$index',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'recipePhaseLocked',
            ),
          ),
        );
      }
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['chapter'], isNull);
      await session.close();
    },
  );

  test(
    'chapter-one recycler recipes stay locked until q1.01 unlocks the station',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(store, catalog, _inventory(catalog));
      await session.apply(
        commandId: 'advance-chapter-for-recycler',
        expectedRevision: 1,
        reduce: (state) =>
            StreetScrapReduction(state: {...state, 'chapter': 1}),
      );
      final recipe = _recipe(
        recipeId: 'ss.recipe.recycler_sample',
        phase: 1,
        station: 'recycler',
        failure: failure,
      );
      await expectLater(
        StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
          toolInstanceIds: const ['needle'],
          operationId: 'recycler-locked',
          commandId: 'recycler-begin-locked',
          expectedRevision: 2,
          contentVersion: '0.1.0',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'recipeStationLocked',
          ),
        ),
      );
      await expectLater(
        StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: recipe,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
          toolInstanceIds: const ['needle'],
          commandId: 'recycler-craft-locked',
          expectedRevision: 2,
          manual: false,
          manualPoints: 0,
          outputInstanceId: (index) => 'recycler-$index',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'recipeStationLocked',
          ),
        ),
      );
      expect(session.snapshot.revision, 2);
      await session.close();
    },
  );

  test(
    'unclassified fixed teaching samples cannot be consumed by crafting',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final base = _inventory(catalog);
      final objects = Map<String, StreetScrapObject>.of(base.objects)
        ..['rag-a'] = catalog.createObject(
          instanceId: 'rag-a',
          itemId: 'cloth.rag_piece',
          source: 'tutorial:recycling-sample',
          quality: 60,
          traits: const {},
        );
      final initial = StreetScrapInventory(
        catalog: catalog,
        grids: base.grids,
        objects: objects,
        placements: base.placements,
        storage: base.storage,
      );
      final session = await _session(store, catalog, initial);
      await expectLater(
        StreetScrapCrafting.beginManual(
          session: session,
          inventoryCatalog: catalog,
          recipe: _recipe(failure: failure),
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
          toolInstanceIds: const ['needle'],
          operationId: 'sample-consumed-early',
          commandId: 'sample-consumed-early',
          expectedRevision: 1,
          contentVersion: '0.1.0',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'recyclingSampleMustBeSorted',
          ),
        ),
      );
      expect(session.snapshot.revision, 1);
      await session.close();
    },
  );

  test(
    'q1.02 records its real dismantle, thread-join, and sewing recipe sequence',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(
        store,
        catalog,
        _inventory(catalog, tutorialKit: true),
        profileScope: 'q1-02-persisted-sewing-tutorial',
      );
      await session.apply(
        commandId: 'unlock-q1.02-test',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 1,
            'tutorialTasks': {'q1.01': true},
            'unlockedStations': ['recycler'],
            'q1.02KitClaimed': true,
          },
        ),
      );

      final unpick = _recipe(
        recipeId: 'ss.recipe.unpick_cloth',
        phase: 1,
        station: 'recycler',
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.rag_piece', quantity: 1),
        ],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.edge_scrap', quantity: 1),
          StreetScrapRecipeInput(itemId: 'cloth.thread_end', quantity: 2),
        ],
        automatic: true,
      );
      final join = _recipe(
        recipeId: 'ss.recipe.join_thread',
        phase: 1,
        station: 'recycler',
        inputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.thread_end', quantity: 3),
        ],
        tools: const [],
        outputs: const [
          StreetScrapRecipeInput(itemId: 'cloth.thread_spool', quantity: 1),
        ],
        primaryItem: 'cloth.thread_end',
        automatic: true,
      );
      await expectLater(
        StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: join,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['q1-kit-thread', 'thread', 'q1-kit-thread'],
          toolInstanceIds: const [],
          commandId: 'q1-join-too-early',
          expectedRevision: 2,
          manual: false,
          manualPoints: 0,
          outputInstanceId: (index) => 'early-join-$index',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'q1.02UnpickFirst',
          ),
        ),
      );
      expect(session.snapshot.revision, 2);
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: unpick,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a'],
        toolInstanceIds: const ['q1-kit-needle'],
        commandId: 'q1-unpick',
        expectedRevision: 2,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'unpick-output-$index',
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q1.02.unpicked'],
        isTrue,
      );
      expect(session.snapshot.state['mastery'], isEmpty);

      final sewing = _recipe(failure: failure);
      await expectLater(
        StreetScrapCrafting.craft(
          session: session,
          inventoryCatalog: catalog,
          recipe: sewing,
          grids: _grids,
          gridId: 'board',
          inputGroupIndex: 0,
          inputInstanceIds: const ['rag-b', 'q1-kit-rag', 'thread'],
          toolInstanceIds: const ['q1-kit-needle'],
          commandId: 'q1-sew-too-early',
          expectedRevision: 3,
          manual: true,
          manualPoints: 3,
          outputInstanceId: (index) => 'early-sew-$index',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'q1.02PrepareThreadFirst',
          ),
        ),
      );
      expect(session.snapshot.revision, 3);
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: join,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const [
          'unpick-output-1',
          'unpick-output-2',
          'q1-kit-thread',
        ],
        toolInstanceIds: const [],
        commandId: 'q1-join',
        expectedRevision: 3,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'join-output-$index',
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q1.02.threadReady'],
        isTrue,
      );

      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: sewing,
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-b', 'q1-kit-rag', 'join-output-0'],
        toolInstanceIds: const ['q1-kit-needle'],
        commandId: 'q1-sew',
        expectedRevision: 4,
        manual: true,
        manualPoints: 3,
        outputInstanceId: (index) => 'sew-output-$index',
      );
      expect(session.snapshot.state['tutorialTasks'], {
        'q1.01': true,
        'q1.02.unpicked': true,
        'q1.02.threadReady': true,
        'q1.02.sewn': true,
        'q1.02': true,
      });
      await session.close();

      final reopened = StreetScrapSession(
        profileScope: 'q1-02-persisted-sewing-tutorial',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
      );
      await reopened.load();
      expect(reopened.snapshot.state['tutorialTasks'], {
        'q1.01': true,
        'q1.02.unpicked': true,
        'q1.02.threadReady': true,
        'q1.02.sewn': true,
        'q1.02': true,
      });
      await reopened.close();
    },
  );

  test(
    'mastered quick craft uses base quality without the manual precision bonus',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(store, catalog, _inventory(catalog));
      await session.apply(
        commandId: 'master-sew-strip',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'mastery': {'ss.recipe.sew_strip': 1},
          },
        ),
      );
      final result = await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        commandId: 'quick-after-mastery',
        expectedRevision: 2,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'quick-output-$index',
      );
      expect((result.result as Map)['quality'], 70);
      expect(session.snapshot.state['mastery'], {'ss.recipe.sew_strip': 1});
      await session.close();
    },
  );

  test(
    'manual operation reserves inputs, resumes saved checkpoints, then settles once',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      const profile = 'resumable-sewing';
      var session = await _session(
        store,
        catalog,
        _inventory(catalog),
        profileScope: profile,
      );
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        operationId: 'sew-op-1',
        commandId: 'begin-sew-1',
        expectedRevision: 1,
        contentVersion: '0.1.0',
      );
      expect(
        (session.snapshot.state['craftOperation']! as Map)['status'],
        'inProgress',
      );
      expect(session.snapshot.state['inventory'], isA<Map>());
      expect(
        (session.snapshot.state['inventory']! as Map)['objects'],
        isA<List>(),
      );
      await expectLater(
        session.apply(
          commandId: 'bypass-craft-lock',
          expectedRevision: 2,
          reduce: (state) =>
              StreetScrapReduction(state: {...state}..remove('craftOperation')),
        ),
        throwsA(isA<StateError>()),
      );
      final first = await StreetScrapCrafting.answerManualCheckpoint(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        operationId: 'sew-op-1',
        optionIndex: 1,
        expectedRevision: 2,
      );
      expect(first, isNull);
      expect(
        ((session.snapshot.state['craftOperation']! as Map)['answers'] as List),
        [1],
      );
      await expectLater(
        StreetScrapCrafting.cancelManual(
          session: session,
          operationId: 'sew-op-1',
          expectedRevision: 3,
        ),
        throwsA(isA<StateError>()),
      );
      await session.close();

      session = StreetScrapSession(
        profileScope: profile,
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
      );
      await session.load();
      expect((session.snapshot.state['craftOperation']! as Map)['answers'], [
        1,
      ]);
      final second = await StreetScrapCrafting.answerManualCheckpoint(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        operationId: 'sew-op-1',
        optionIndex: 1,
        expectedRevision: 3,
      );
      expect(second, isNull);
      final settled = await StreetScrapCrafting.answerManualCheckpoint(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        operationId: 'sew-op-1',
        optionIndex: 1,
        expectedRevision: 4,
      );
      expect((settled!.result as Map)['succeeded'], isTrue);
      expect(session.snapshot.state.containsKey('craftOperation'), isFalse);
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        saved.objects.values
            .singleWhere((item) => item.source.startsWith('crafted:'))
            .quality,
        78,
      );
      expect(session.snapshot.revision, 7);
      await session.close();
    },
  );

  test(
    'unstarted manual operation can be cancelled without consuming or moving inputs',
    () async {
      final store = _MemoryStore();
      final catalog = _catalog();
      final session = await _session(store, catalog, _inventory(catalog));
      await StreetScrapCrafting.beginManual(
        session: session,
        inventoryCatalog: catalog,
        recipe: _recipe(failure: failure),
        grids: _grids,
        gridId: 'board',
        inputGroupIndex: 0,
        inputInstanceIds: const ['rag-a', 'rag-b', 'thread'],
        toolInstanceIds: const ['needle'],
        operationId: 'sew-cancel',
        commandId: 'begin-sew-cancel',
        expectedRevision: 1,
        contentVersion: '0.1.0',
      );
      await StreetScrapCrafting.cancelManual(
        session: session,
        operationId: 'sew-cancel',
        expectedRevision: 2,
      );
      final saved = catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        saved.objects.keys,
        containsAll(['rag-a', 'rag-b', 'thread', 'needle']),
      );
      expect(session.snapshot.state.containsKey('craftOperation'), isFalse);
      await session.close();
    },
  );
}
