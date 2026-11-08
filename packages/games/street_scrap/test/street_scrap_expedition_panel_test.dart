import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_expedition.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_item_sprite.dart';

class _MemoryStore implements StreetScrapProgressStore {
  final Map<String, Map<String, Object?>> snapshots = {};

  @override
  Future<Map<String, Object?>?> read(String slotKey) async =>
      snapshots[slotKey];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    if ((snapshots[slotKey]?['revision'] as int?) != expectedRevision) {
      return false;
    }
    snapshots[slotKey] = nextSnapshot;
    return true;
  }
}

void main() {
  testWidgets('fresh phase-one third node shows both investigation actions', (
    tester,
  ) async {
    final store = _MemoryStore();
    final initial = StreetScrapSession(
      profileScope: 'q1-03-third-node-actions-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await initial.load();
    const rules = StreetScrapExpeditionRules(
      nodeCount: 3,
      investigationsPerNode: 1,
      movementCost: 1,
      investigationCost: 2,
      fixedWrongQuantity: 1,
      fixedLocations: [
        StreetScrapFixedLocation(
          id: 'phase-zero-0',
          nodeIndex: 0,
          phase: 0,
          options: [
            StreetScrapFixedOption(
              itemId: 'wood.chip',
              quantity: 1,
              label: 'Wood chips',
            ),
          ],
        ),
        StreetScrapFixedLocation(
          id: 'phase-zero-1',
          nodeIndex: 1,
          phase: 0,
          options: [
            StreetScrapFixedOption(
              itemId: 'wood.chip',
              quantity: 1,
              label: 'Wood chips',
            ),
          ],
        ),
        StreetScrapFixedLocation(
          id: 'phase-zero-2',
          nodeIndex: 2,
          phase: 0,
          options: [
            StreetScrapFixedOption(
              itemId: 'wood.chip',
              quantity: 1,
              label: 'Wood chips',
            ),
          ],
        ),
        StreetScrapFixedLocation(
          id: 'metal_recycling_rack',
          nodeIndex: 2,
          phase: 1,
          label: 'Metal recycling rack',
          options: [
            StreetScrapFixedOption(
              itemId: 'metal.sheet',
              quantity: 1,
              label: 'Intact metal sheet',
            ),
            StreetScrapFixedOption(
              itemId: 'wood.board',
              quantity: 1,
              label: 'Intact wood board',
            ),
          ],
        ),
      ],
      surprisePools: {
        'commonScraps': ['wood.chip'],
        'intactBase': ['metal.sheet'],
        'containers': ['wood.chip'],
        'optionalSpecial': [],
      },
      surpriseWeights: {
        'commonScraps': 50,
        'intactBase': 25,
        'containers': 15,
        'optionalSpecial': 10,
      },
      surpriseTraitPools: {'positive': [], 'negative': []},
      surpriseTraitChancePercent: 0,
      scrapQualities: [30, 55],
      intactQualities: [55, 80, 95],
    );
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {
        'wood.chip': StreetScrapFootprint(1, 1),
        'metal.sheet': StreetScrapFootprint(1, 2),
        'wood.board': StreetScrapFootprint(1, 2),
      },
      packingRules: const {},
    );
    final expedition = StreetScrapExpedition.start(
      id: 'q1-03-third-node-actions',
      phase: 1,
      seed: 4,
      stamina: 60,
      rules: rules,
    ).move(rules);
    store.snapshots[initial.slotKey] = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 1,
      savedAt: DateTime.utc(2026, 10, 26),
      state: {
        'chapter': 1,
        'stamina': expedition.stamina,
        'backpackCapacity': 16,
        'inventory': catalog.emptyInventory(grids: grids).toJson(),
        'tutorialTasks': const {'q1.01': true, 'q1.02': true},
        'expedition': expedition.toJson(),
      },
      commandReceipts: const {},
    ).toJson();
    await initial.close();

    final session = StreetScrapSession(
      profileScope: 'q1-03-third-node-actions-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapExpeditionPanel(
                session: session,
                catalog: catalog,
                rules: rules,
                maxStamina: 60,
                onInventoryChanged: _emptyCallback,
              ),
            ),
          ),
        ),
      ),
    );

    final pageScroll = find.byType(SingleChildScrollView).first;
    await tester.drag(pageScroll, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final nextAction = find.byKey(const Key('expedition-action-next'));
    await tester.tap(nextAction);
    await tester.pumpAndSettle();

    expect(find.text('Metal recycling rack'), findsOneWidget);
    expect(find.byKey(const Key('expedition-action-fixed')), findsOneWidget);
    expect(find.byKey(const Key('expedition-action-surprise')), findsOneWidget);
    expect(find.byKey(const Key('expedition-action-return')), findsOneWidget);
    final viewport = tester.getRect(pageScroll);
    for (final key in const [
      Key('expedition-action-fixed'),
      Key('expedition-action-surprise'),
    ]) {
      final action = find.byKey(key);
      final rect = tester.getRect(action);
      expect(rect.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
    }
    expect(
      find.text('This location has already been investigated.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('a full backpack offers a direct visual organize action', (
    tester,
  ) async {
    final store = _MemoryStore();
    final initial = StreetScrapSession(
      profileScope: 'expedition-full-backpack-organize-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await initial.load();
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {
        'wood.chip': StreetScrapFootprint(1, 1),
        'cloth.rag_piece': StreetScrapFootprint(1, 1),
        'cloth.thread_end': StreetScrapFootprint(1, 1),
        'tool.needle': StreetScrapFootprint(1, 1),
      },
      packingRules: const {},
    );
    var inventory = catalog.emptyInventory(grids: grids);
    for (var index = 0; index < 16; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'full-backpack-$index',
          itemId: 'wood.chip',
          source: 'test:full-backpack',
          quality: 30,
          traits: const {},
        ),
        'backpack',
      );
    }
    store.snapshots[initial.slotKey] = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 1,
      savedAt: DateTime.utc(2026, 10, 26),
      state: {
        'chapter': 1,
        'tutorialTasks': const {'q1.01': true},
        'inventory': inventory.toJson(),
      },
      commandReceipts: const {},
    ).toJson();
    await initial.close();

    final session = StreetScrapSession(
      profileScope: 'expedition-full-backpack-organize-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    const rules = StreetScrapExpeditionRules(
      nodeCount: 3,
      investigationsPerNode: 1,
      movementCost: 1,
      investigationCost: 2,
      fixedWrongQuantity: 1,
      fixedLocations: [],
      surprisePools: {},
      surpriseWeights: {},
      surpriseTraitPools: {},
      surpriseTraitChancePercent: 0,
      scrapQualities: [],
      intactQualities: [],
    );
    var organizeOpened = false;
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapExpeditionPanel(
                session: session,
                catalog: catalog,
                rules: rules,
                maxStamina: 60,
                onInventoryChanged: () {},
                onOrganizeBackpack: () async {
                  organizeOpened = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.text('Claim sewing kit (rags, spare thread, and needle)'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Your backpack is full.'), findsOneWidget);
    final organizeButton = find.byKey(
      const Key('street-scrap-open-backpack-organizer'),
    );
    expect(organizeButton, findsOneWidget);
    expect(tester.getSemantics(organizeButton).label, 'Open backpack');
    await tester.tap(organizeButton);
    await tester.pumpAndSettle();
    expect(organizeOpened, isTrue);
    expect(session.snapshot.state['q1.02KitClaimed'], isNot(true));
    await session.close();
  });

  testWidgets('exploration primary actions use the active English locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StreetScrapSession(
      profileScope: 'expedition-localization-test',
      store: _MemoryStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    final rules = StreetScrapExpeditionRules.fromJson({
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'fixedLocations': [
        for (var index = 0; index < 3; index++)
          {
            'id': 'node-$index',
            'phase': 0,
            'options': [
              {'item': 'wood.chip', 'quantity': 1},
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
      'scrapQualities': [30, 55],
      'intactQualities': [55, 80, 95],
    });
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
      packingRules: const {},
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapExpeditionPanel(
                session: session,
                catalog: catalog,
                rules: rules,
                maxStamina: 60,
                onInventoryChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Neighborhood Scavenging'), findsOneWidget);
    expect(find.text('Stamina 60 / 60'), findsOneWidget);
    expect(find.text('Phase 0 tutorial'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Keep'), findsOneWidget);
    expect(find.text('Deliver'), findsOneWidget);
    final scene = find.byKey(const Key('street-scrap-phase-zero-scene'));
    expect(scene, findsOneWidget);
    expect(tester.getRect(scene).bottom, lessThanOrEqualTo(600));
    expect(
      tester
          .getSemantics(find.byKey(const Key('street-scrap-q0.01-visual-step')))
          .label,
      contains('Search and bring back your first item'),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('street-scrap-q0.03-visual-step')))
          .label,
      contains('Turn in 2 paper scraps or 2 rag pieces'),
    );
    expect(find.text('Go'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('street-scrap-expedition-start')))
          .label,
      contains('Enter the neighborhood (costs 1 stamina)'),
    );
    expect(
      tester
          .getRect(find.byKey(const Key('street-scrap-expedition-start')))
          .bottom,
      lessThanOrEqualTo(600),
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('fresh phase-zero tutorial grants two reusable bottles once', (
    tester,
  ) async {
    final session = StreetScrapSession(
      profileScope: 'phase-zero-starter-vessels-panel',
      store: _MemoryStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    final rules = StreetScrapExpeditionRules.fromJson({
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'fixedLocations': [
        for (var index = 0; index < 3; index++)
          {
            'id': 'node-$index',
            'phase': 0,
            'options': [
              {'item': 'wood.chip', 'quantity': 1},
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
      'scrapQualities': [30, 55],
      'intactQualities': [55, 80, 95],
    });
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {
        'wood.chip': StreetScrapFootprint(1, 1),
        'container.used_intact': StreetScrapFootprint(1, 2),
      },
      packingRules: const {},
    );
    var inventoryChanged = false;
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreetScrapExpeditionPanel(
                session: session,
                catalog: catalog,
                rules: rules,
                maxStamina: 60,
                onInventoryChanged: () => inventoryChanged = true,
              ),
            ),
          ),
        ),
      ),
    );
    final claim = find.byKey(const Key('street-scrap-claim-starter-vessels'));
    expect(claim, findsOneWidget);
    await tester.ensureVisible(claim);
    await tester.tap(claim);
    await tester.pumpAndSettle();

    final inventory = catalog.inventoryFromJson(
      grids: streetScrapGridSpecsForState(session.snapshot.state),
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(inventory.objects, hasLength(2));
    expect(
      find.byKey(const Key('street-scrap-claim-starter-vessels')),
      findsNothing,
    );
    expect(inventoryChanged, isTrue);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('chapter tutorial checklist appears as chapters unlock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryStore();
    final initial = StreetScrapSession(
      profileScope: 'expedition-chapter-checklist-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await initial.load();
    store.snapshots[initial.slotKey] = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 1,
      savedAt: DateTime.utc(2026, 10, 24),
      state: const {
        'chapter': 5,
        'tutorialTasks': {'q2.01': true, 'q3.01': true, 'q4.01': true},
      },
      commandReceipts: const {},
    ).toJson();
    await initial.close();

    final session = StreetScrapSession(
      profileScope: 'expedition-chapter-checklist-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    const rules = StreetScrapExpeditionRules(
      nodeCount: 3,
      investigationsPerNode: 1,
      movementCost: 1,
      investigationCost: 2,
      fixedWrongQuantity: 1,
      fixedLocations: [],
      surprisePools: {},
      surpriseWeights: {},
      surpriseTraitPools: {},
      surpriseTraitChancePercent: 0,
      scrapQualities: [],
      intactQualities: [],
    );
    final catalog = StreetScrapInventoryCatalog(
      footprints: {},
      packingRules: {},
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
            body: SingleChildScrollView(
              child: StreetScrapExpeditionPanel(
                session: session,
                catalog: catalog,
                rules: rules,
                maxStamina: 60,
                onInventoryChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Phase 2 | Dock fishing'), findsOneWidget);
    expect(find.text('Phase 3 | Woodworking and storage'), findsOneWidget);
    expect(find.text('Phase 4 | Water and meals'), findsOneWidget);
    expect(find.text('Phase 5 | Stable living'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('street-scrap-task-summary-phase-two')),
          )
          .label,
      contains('1/3 · Next · Finish a fishing attempt and claim the catch'),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('street-scrap-task-summary-phase-five')),
          )
          .label,
      contains(
        '0/2 · Next · Complete one advanced order for each of the five producers',
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    expect(
      find.text('Finish a fishing attempt and claim the catch'),
      findsNothing,
    );
    expect(
      find.byKey(const Key('street-scrap-task-group-phase-two')),
      findsOneWidget,
    );
    final phaseTwo = find.byKey(const Key('street-scrap-task-group-phase-two'));
    await tester.ensureVisible(phaseTwo);
    await tester.tap(phaseTwo);
    await tester.pumpAndSettle();
    expect(find.text('Cast a line with the fishing rod'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Cast a line with the fishing rod · Complete'),
      findsOneWidget,
    );
    final phaseFive = find.byKey(
      const Key('street-scrap-task-group-phase-five'),
    );
    await tester.ensureVisible(phaseFive);
    await tester.tap(phaseFive);
    await tester.pumpAndSettle();
    final phaseFiveLastTask = find.text(
      'Place the shelter and reinforced chest, then complete 5 regular cycle orders',
    );
    await tester.ensureVisible(phaseFiveLastTask);
    expect(phaseFiveLastTask, findsOneWidget);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('route panel starts, returns freely, and persists reward claim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryStore();
    final session = StreetScrapSession(
      profileScope: 'expedition-panel-test',
      store: store,
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.0',
      },
      rulesetVersion: 1,
    );
    await session.load();
    final rules = StreetScrapExpeditionRules.fromJson({
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'fixedLocations': [
        for (var index = 0; index < 3; index++)
          {
            'id': 'node-$index',
            'phase': 0,
            'options': [
              {'item': 'cloth.rag_piece', 'quantity': 3},
              {'item': 'cloth.edge', 'quantity': 3},
              {'item': 'cloth.thread', 'quantity': 3},
              {'item': 'cloth.thread_spool', 'quantity': 1},
            ],
          },
        {
          'id': 'phase-1-many-options',
          'phase': 1,
          'nodeIndex': 0,
          'options': [
            for (var index = 0; index < 7; index++)
              {'item': 'cloth.rag_piece', 'quantity': index + 1},
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
        'commonScraps': ['cloth.rag_piece'],
        'intactBase': ['cloth.rag_piece'],
        'containers': ['cloth.rag_piece'],
        'optionalSpecial': [],
      },
      'scrapQualities': [30, 55],
      'intactQualities': [55, 80, 95],
    });
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'cloth.rag_piece': StreetScrapFootprint(1, 1)},
      packingRules: const {},
    );
    var sessionChanges = 0;
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreetScrapExpeditionPanel(
              session: session,
              catalog: catalog,
              rules: rules,
              maxStamina: 60,
              onInventoryChanged: () => sessionChanges++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('street-scrap-expedition-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('street-scrap-expedition-protagonist')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-1')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-2')),
      findsOneWidget,
    );
    expect(session.snapshot.state['stamina'], 59);
    expect(sessionChanges, 1);
    final fixedAction = find.byKey(const Key('expedition-action-fixed'));
    final surpriseAction = find.byKey(const Key('expedition-action-surprise'));
    final nextAction = find.byKey(const Key('expedition-action-next'));
    final returnAction = find.byKey(const Key('expedition-action-return'));
    expect(fixedAction, findsOneWidget);
    expect(surpriseAction, findsOneWidget);
    expect(nextAction, findsOneWidget);
    expect(returnAction, findsOneWidget);
    expect(find.bySemanticsLabel('調查固定素材（2 體力）'), findsOneWidget);
    expect(find.bySemanticsLabel('免費返程'), findsOneWidget);
    await tester.tap(fixedAction);
    await tester.pumpAndSettle();
    final materialGrid = find.byKey(
      const Key('street-scrap-expedition-material-grid'),
    );
    expect(materialGrid, findsOneWidget);
    expect(
      tester.widget<GridView>(materialGrid).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(
      find.byKey(const Key('street-scrap-expedition-material-option-3')),
      findsOneWidget,
    );
    final choiceSprite = find.byKey(
      const ValueKey(
        'street-scrap-sprite:cloth.rag_piece:found:expedition:null',
      ),
    );
    expect(tester.getSize(choiceSprite).width, greaterThan(115));
    expect(tester.getSize(choiceSprite).height, greaterThan(115));
    expect(find.textContaining('品質依材料來源判定'), findsNothing);
    expect(
      tester.getRect(materialGrid).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    await tester.tap(
      find.byKey(const Key('street-scrap-expedition-material-option-0')),
    );
    await tester.pumpAndSettle();
    final activeExpedition = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
    );
    expect(session.snapshot.state['stamina'], 59);
    final clueSlot = activeExpedition.targetSilhouetteIndex;
    await tester.tap(
      find.byKey(Key('street-scrap-reveal-silhouette-$clueSlot')),
    );
    await tester.pumpAndSettle();
    expect(session.snapshot.state['stamina'], 59);
    await tester.tap(
      find.byKey(Key('street-scrap-select-silhouette-$clueSlot')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.snapshot.state['stamina'], 57);
    expect(sessionChanges, 2);
    expect(
      StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
      ).investigated,
      [0],
    );
    await tester.tap(returnAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-1')),
      findsOneWidget,
    );
    expect(
      StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
      ).returned,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.byKey(const Key('street-scrap-expedition-protagonist')),
      findsNothing,
    );
    final returned = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
    );
    final firstReward = returned.pendingRewards.single;
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    final rewardSprite = find.byKey(
      ValueKey(
        'street-scrap-sprite:${firstReward['itemId']}:${firstReward['source']}:null',
      ),
    );
    expect(rewardSprite, findsOneWidget);
    expect(tester.getSize(rewardSprite), const Size.square(112));
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpAndSettle();
    expect(sessionChanges, 3);
    await tester.tap(find.text('領取全部物品到背包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
      ).claimed,
      isTrue,
    );
    expect(session.snapshot.state['stamina'], 57);
    expect(sessionChanges, 4);
    final tutorialTasks =
        session.snapshot.state['tutorialTasks']! as Map<String, Object?>;
    expect(tutorialTasks['q0.01'], isTrue);
    expect(tutorialTasks['q0.02'], isTrue);

    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    await tester.tap(find.text('交付破布片 2 件'));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('交付後素材會被消耗'), findsOneWidget);
    final mobileDeliverySprite = find.byType(StreetScrapItemSprite).first;
    expect(tester.getSize(mobileDeliverySprite).height, 104);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('expedition-start-'), findsNothing);
    await tester.tap(find.text('確認交付').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(session.snapshot.state['chapter'], 1);
    expect(
      (session.snapshot.state['tutorialTasks']!
          as Map<String, Object?>)['q0.03'],
      isTrue,
    );
    expect(sessionChanges, 5);

    await tester.tap(find.byKey(const Key('street-scrap-expedition-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expedition-action-fixed')));
    await tester.pumpAndSettle();
    final phaseOneGrid = find.byKey(
      const Key('street-scrap-expedition-material-grid'),
    );
    expect(
      tester.widget<GridView>(phaseOneGrid).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    final phaseOneMaterialSprite = find
        .descendant(
          of: phaseOneGrid,
          matching: find.byType(StreetScrapItemSprite),
        )
        .first;
    expect(
      tester.getSize(phaseOneMaterialSprite).width,
      greaterThanOrEqualTo(88),
      reason: 'Paged fixed-material choices should keep their art prominent.',
    );
    expect(
      find.byKey(const Key('street-scrap-expedition-material-option-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-expedition-material-option-4')),
      findsNothing,
    );
    final nextMaterialPage = find.byKey(
      const Key('street-scrap-expedition-material-next-page'),
    );
    expect(nextMaterialPage, findsOneWidget);
    expect(
      tester.getRect(nextMaterialPage).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    await tester.tap(nextMaterialPage);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-expedition-material-option-6')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-expedition-material-option-3')),
      findsNothing,
    );
    expect(
      tester.getRect(phaseOneGrid).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    await tester.tap(
      find.byKey(const Key('street-scrap-expedition-material-option-6')),
    );
    await tester.pumpAndSettle();
    final phaseOneExpedition = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
    );
    final phaseOneClue = phaseOneExpedition.targetSilhouetteIndex;
    await tester.tap(
      find.byKey(Key('street-scrap-reveal-silhouette-$phaseOneClue')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('street-scrap-select-silhouette-$phaseOneClue')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final selectedPageTwoReward = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(session.snapshot.state['expedition']! as Map),
    ).pendingRewards.single;
    expect(
      selectedPageTwoReward['quantity'],
      7,
      reason: 'The tapped card must keep its absolute index after pagination.',
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets(
    'mineral-water picker uses readable duplicate-safe vessel labels',
    (tester) async {
      final store = _MemoryStore();
      final initial = StreetScrapSession(
        profileScope: 'expedition-vessel-label-test',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await initial.load();
      final grids = streetScrapGridSpecsForState(const {});
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'container.clean': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      final first = catalog.createObject(
        instanceId: 'private-vessel-instance-alpha',
        itemId: 'container.clean',
        source: 'found_native',
        quality: 55,
        traits: const {},
        containerState: const {'cleanliness': 'clean'},
      );
      final second = catalog.createObject(
        instanceId: 'private-vessel-instance-beta',
        itemId: 'container.clean',
        source: 'found_native',
        quality: 55,
        traits: const {},
        containerState: const {'cleanliness': 'clean'},
      );
      final inventory = StreetScrapInventory(
        catalog: catalog,
        grids: grids,
        objects: {first.instanceId: first, second.instanceId: second},
        placements: {
          first.instanceId: const StreetScrapPlacement(
            instanceId: 'private-vessel-instance-alpha',
            gridId: 'backpack',
            x: 0,
            y: 0,
            rotation: false,
          ),
          second.instanceId: const StreetScrapPlacement(
            instanceId: 'private-vessel-instance-beta',
            gridId: 'backpack',
            x: 1,
            y: 0,
            rotation: false,
          ),
        },
        storage: const {},
      );
      store.snapshots[initial.slotKey] = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {},
        revision: 1,
        savedAt: DateTime.utc(2026, 10, 24),
        state: {
          'chapter': 0,
          'stamina': 60,
          'backpackCapacity': 16,
          'inventory': inventory.toJson(),
          'expedition': const StreetScrapExpedition(
            id: 'returned-water-reward',
            phase: 0,
            seed: 10,
            stamina: 59,
            nodeIndex: 0,
            visited: [0],
            investigated: [0],
            pendingRewards: [
              {
                'itemId': 'water.mineral',
                'quantity': 1,
                'quality': 80,
                'source': 'fixed:node-0',
              },
            ],
            returned: true,
            claimed: false,
            drawIndex: 1,
            discardedCount: 0,
          ).toJson(),
        },
        commandReceipts: const {},
      ).toJson();
      await initial.close();

      final session = StreetScrapSession(
        profileScope: 'expedition-vessel-label-test',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      const rules = StreetScrapExpeditionRules(
        nodeCount: 3,
        investigationsPerNode: 1,
        movementCost: 1,
        investigationCost: 2,
        fixedWrongQuantity: 1,
        fixedLocations: [
          StreetScrapFixedLocation(
            id: 'node-0',
            nodeIndex: 0,
            phase: 0,
            options: [
              StreetScrapFixedOption(
                itemId: 'wood.chip',
                quantity: 1,
                label: 'Wood chips',
              ),
            ],
          ),
          StreetScrapFixedLocation(
            id: 'node-1',
            nodeIndex: 1,
            phase: 0,
            options: [
              StreetScrapFixedOption(
                itemId: 'wood.chip',
                quantity: 1,
                label: 'Wood chips',
              ),
            ],
          ),
          StreetScrapFixedLocation(
            id: 'node-2',
            nodeIndex: 2,
            phase: 0,
            options: [
              StreetScrapFixedOption(
                itemId: 'wood.chip',
                quantity: 1,
                label: 'Wood chips',
              ),
            ],
          ),
        ],
        surprisePools: {
          'commonScraps': ['wood.chip'],
          'intactBase': ['wood.chip'],
          'containers': ['wood.chip'],
          'optionalSpecial': [],
        },
        surpriseWeights: {
          'commonScraps': 50,
          'intactBase': 25,
          'containers': 15,
          'optionalSpecial': 10,
        },
        surpriseTraitPools: {'positive': [], 'negative': []},
        surpriseTraitChancePercent: 0,
        scrapQualities: [30, 55],
        intactQualities: [55, 80, 95],
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapExpeditionPanel(
                session: session,
                catalog: catalog,
                rules: rules,
                maxStamina: 60,
                onInventoryChanged: _emptyCallback,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Collect all items into backpack'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Choose an empty bottle for mineral water'),
        findsOneWidget,
      );
      expect(
        find.text('Clean container · Found (original material) · item 1'),
        findsOneWidget,
      );
      expect(
        find.text('Clean container · Found (original material) · item 2'),
        findsOneWidget,
      );
      expect(find.textContaining('private-vessel-instance'), findsNothing);
      expect(find.text('Quality 55 · clean empty bottle'), findsNWidgets(2));
      await tester.tap(find.text('Cancel collection'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['expedition'], isNotNull);
      await session.close();
    },
  );

  testWidgets('malformed expedition data shows a localized read-only fallback', (
    tester,
  ) async {
    final store = _MemoryStore();
    final initial = StreetScrapSession(
      profileScope: 'expedition-malformed-state-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await initial.load();
    store.snapshots[initial.slotKey] = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 1,
      savedAt: DateTime.utc(2026, 10, 24),
      state: const {'expedition': 'invalid'},
      commandReceipts: const {},
    ).toJson();
    await initial.close();

    final session = StreetScrapSession(
      profileScope: 'expedition-malformed-state-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    const rules = StreetScrapExpeditionRules(
      nodeCount: 3,
      investigationsPerNode: 1,
      movementCost: 1,
      investigationCost: 2,
      fixedWrongQuantity: 1,
      fixedLocations: [],
      surprisePools: {},
      surpriseWeights: {},
      surpriseTraitPools: {},
      surpriseTraitChancePercent: 0,
      scrapQualities: [],
      intactQualities: [],
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapExpeditionPanel(
              session: session,
              catalog: StreetScrapInventoryCatalog(
                footprints: {},
                packingRules: {},
              ),
              rules: rules,
              maxStamina: 60,
              onInventoryChanged: _emptyCallback,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Exploration data could not be read. Your save is unchanged. Return to game progress and use Save Recovery to inspect available backups.',
      ),
      findsOneWidget,
    );
    expect(find.text('Neighborhood Scavenging'), findsNothing);
    expect(session.snapshot.revision, 1);
    expect(session.snapshot.state['expedition'], 'invalid');
    await session.close();
  });

  testWidgets('legacy q2.03 choice migration keeps exploration usable', (
    tester,
  ) async {
    final store = _MemoryStore();
    final initial = StreetScrapSession(
      profileScope: 'expedition-legacy-fish-choice-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await initial.load();
    store.snapshots[initial.slotKey] = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {},
      revision: 7,
      savedAt: DateTime.utc(2026, 10, 24),
      state: const {
        'chapter': 3,
        'tutorialTasks': {'q2.02': true, 'q2.03': true, 'q2.03Choice': 'keep'},
      },
      commandReceipts: const {},
    ).toJson();
    await initial.close();

    final session = StreetScrapSession(
      profileScope: 'expedition-legacy-fish-choice-test',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    const rules = StreetScrapExpeditionRules(
      nodeCount: 3,
      investigationsPerNode: 1,
      movementCost: 1,
      investigationCost: 2,
      fixedWrongQuantity: 1,
      fixedLocations: [],
      surprisePools: {},
      surpriseWeights: {},
      surpriseTraitPools: {},
      surpriseTraitChancePercent: 0,
      scrapQualities: [],
      intactQualities: [],
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                StreetScrapExpeditionPanel(
                  session: session,
                  catalog: StreetScrapInventoryCatalog(
                    footprints: {},
                    packingRules: {},
                  ),
                  rules: rules,
                  maxStamina: 60,
                  onInventoryChanged: _emptyCallback,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(session.snapshot.revision, 7);
    expect(session.snapshot.state['q2.03Choice'], 'keep');
    expect(
      (session.snapshot.state['tutorialTasks']! as Map).values,
      everyElement(isA<bool>()),
    );
    expect(find.text('Neighborhood Scavenging'), findsOneWidget);
    expect(find.text('Phase 3 | Woodworking and storage'), findsOneWidget);
    expect(
      find.textContaining('Exploration data could not be read.'),
      findsNothing,
    );
    await session.close();
  });

  testWidgets(
    'tutorial recycling samples are distinguished from duplicate materials',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _MemoryStore();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'cloth.rag_piece': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      final state = <String, Object?>{
        'chapter': 1,
        'stamina': 50,
        'recyclingSamplesClaimed': true,
      };
      final inventory = StreetScrapInventory(
        catalog: catalog,
        grids: streetScrapGridSpecsForState(state),
        objects: {
          'q1-sample-cloth': StreetScrapObject(
            instanceId: 'q1-sample-cloth',
            itemId: 'cloth.rag_piece',
            source: 'tutorial:recycling-sample',
            quality: 55,
            traits: const {},
            toolDurability: null,
            footprint: const StreetScrapFootprint(1, 1),
          ),
          'rag-2': StreetScrapObject(
            instanceId: 'rag-2',
            itemId: 'cloth.rag_piece',
            source: 'found:street',
            quality: 45,
            traits: const {},
            toolDurability: null,
            footprint: const StreetScrapFootprint(1, 1),
          ),
        },
        placements: {
          'q1-sample-cloth': StreetScrapPlacement(
            instanceId: 'q1-sample-cloth',
            gridId: 'backpack',
            x: 0,
            y: 0,
            rotation: false,
          ),
          'rag-2': StreetScrapPlacement(
            instanceId: 'rag-2',
            gridId: 'backpack',
            x: 1,
            y: 0,
            rotation: false,
          ),
        },
        storage: const {},
      );
      state['inventory'] = inventory.toJson();

      final initialSession = StreetScrapSession(
        profileScope: 'expedition-duplicate-classification-test',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await initialSession.load();
      store.snapshots[initialSession.slotKey] =
          StreetScrapProgressSnapshot.create(
            rulesetVersion: 1,
            contentVersions: const {},
            revision: 1,
            savedAt: DateTime.utc(2026, 10, 25),
            state: state,
            commandReceipts: const {},
          ).toJson();
      await initialSession.close();

      final session = StreetScrapSession(
        profileScope: 'expedition-duplicate-classification-test',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      const rules = StreetScrapExpeditionRules(
        nodeCount: 3,
        investigationsPerNode: 1,
        movementCost: 1,
        investigationCost: 2,
        fixedWrongQuantity: 1,
        fixedLocations: [],
        surprisePools: {},
        surpriseWeights: {},
        surpriseTraitPools: {},
        surpriseTraitChancePercent: 0,
        scrapQualities: [],
        intactQualities: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                StreetScrapExpeditionPanel(
                  session: session,
                  catalog: catalog,
                  rules: rules,
                  maxStamina: 60,
                  onInventoryChanged: _emptyCallback,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('street-scrap-classification-q1-sample-cloth')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('street-scrap-classification-rag-2')),
        findsOneWidget,
      );
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(
        find.byKey(
          const Key('street-scrap-classification-icon-q1-sample-cloth'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('street-scrap-classification-icon-rag-2')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(
                const Key('street-scrap-classification-icon-q1-sample-cloth'),
              ),
            )
            .width,
        greaterThan(100),
      );
      expect(
        tester
            .getSize(
              find.byKey(
                const Key('street-scrap-classification-q1-sample-cloth'),
              ),
            )
            .height,
        greaterThan(140),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('street-scrap-classification-rag-2')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-classification-dialog-sample-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('street-scrap-tutorial-sample-badge-q1-sample-cloth'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('教學樣本')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );
}

void _emptyCallback() {}
