import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_item_sprite.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory_page.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_trait_presentation.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_supplies.dart';

class _MemoryProgressStore implements StreetScrapProgressStore {
  final Map<String, Map<String, Object?>> values = {};

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => values[slotKey];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    final actual = values[slotKey]?['revision'] as int?;
    if (actual != expectedRevision) return false;
    values[slotKey] = nextSnapshot;
    return true;
  }
}

void main() {
  testWidgets(
    'full-backpack sewing kit flow opens the bag, frees three cells, and claims atomically',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const grids = {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
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
      final store = _MemoryProgressStore();
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
            instanceId: 'organize-e2e-$index',
            itemId: 'wood.chip',
            source: 'test:organize-e2e',
            quality: 55,
            traits: const {},
          ),
          'backpack',
        );
      }
      final session = StreetScrapSession(
        profileScope: 'inventory-full-backpack-organize-e2e',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      await session.apply(
        commandId: 'seed-full-backpack-organize-e2e',
        expectedRevision: session.snapshot.revision,
        reduce: (_) => StreetScrapReduction(
          state: {
            'chapter': 1,
            'tutorialTasks': const {'q1.01': true},
            'inventory': inventory.toJson(),
          },
        ),
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: catalog,
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                  const [],
                  expectedCount: 0,
                ),
                expeditionRules: rules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street-scrap-nav-expedition')));
      await tester.pumpAndSettle();

      final claimKit = find.text(
        'Claim sewing kit (rags, spare thread, and needle)',
      );
      await tester.ensureVisible(claimKit);
      await tester.tap(claimKit);
      await tester.pumpAndSettle();
      expect(find.textContaining('Your backpack is full.'), findsOneWidget);
      expect(
        (session.snapshot.state['inventory']! as Map)['objects'],
        hasLength(16),
        reason: 'The failed claim must not partially add its kit.',
      );

      await tester.tap(
        find.byKey(const Key('street-scrap-open-backpack-organizer')),
      );
      await tester.pumpAndSettle();
      final backpackToggle = find.byKey(
        const Key('street-scrap-workspace-select-backpack'),
      );
      expect(tester.widget<IconButton>(backpackToggle).isSelected, isTrue);

      for (var index = 0; index < 3; index++) {
        await tester.tap(
          find.byKey(ValueKey('street-scrap-object-organize-e2e-$index')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('street-scrap-workspace-select-board')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('street-scrap-cell-board-$index-0')));
        await tester.pumpAndSettle();
        await tester.tap(backpackToggle);
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byKey(const Key('street-scrap-close-material-workspace')),
      );
      await tester.pumpAndSettle();
      await tester.tap(claimKit);
      await tester.pumpAndSettle();

      expect(session.snapshot.state['q1.02KitClaimed'], isTrue);
      final saved = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        saved.placements.values.where((p) => p.gridId == 'board'),
        hasLength(3),
      );
      expect(
        saved.placements.values.where((p) => p.gridId == 'backpack'),
        hasLength(16),
      );
      expect(saved.objects, hasLength(19));
      await session.close();
    },
  );

  test(
    'trait presentation explains known effects and preserves unknown IDs',
    () {
      final traits = StreetScrapTraitPresentation.forTraits(const {
        'smoky': true,
        'future_trait_v2': true,
        'even_burn': true,
        'disabled': false,
      });

      expect(traits.map((entry) => entry.key), [
        'even_burn',
        'future_trait_v2',
        'smoky',
      ]);
      expect(traits.first.value.effect, contains('10%'));
      expect(traits[1].value.name, 'future_trait_v2');
      expect(traits.last.value.effect, contains('品質 −3'));
      final english = StreetScrapTraitPresentation.forId(
        'even_burn',
        localizations: const StreetScrapLocalizations('en'),
      );
      expect(english.name, 'Even-burning');
      expect(english.effect, 'Next heat-control success zone width +10%');
      final unknown = StreetScrapTraitPresentation.forId(
        'future_trait_v3',
        localizations: const StreetScrapLocalizations('en'),
      );
      expect(unknown.name, 'future_trait_v3');
      expect(
        unknown.effect,
        'Effect is defined by the installed content version',
      );
    },
  );

  final expeditionRules = StreetScrapExpeditionRules.fromJson({
    'nodeCount': 3,
    'investigationsPerNode': 1,
    'movementCost': 1,
    'investigationCost': 2,
    'fixedWrongQuantity': 1,
    'fixedLocations': [
      for (var i = 0; i < 3; i++)
        {
          'id': 'node-$i',
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

  testWidgets(
    'phone workspace shows large loose materials without withdrawing stored items',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = StreetScrapSession(
        profileScope: 'workspace-storage-boundary',
        store: _MemoryProgressStore(),
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {
          'wood.chip': StreetScrapFootprint(1, 1),
          'wood.board': StreetScrapFootprint(2, 2),
        },
        packingRules: const {},
      );
      final initial = StreetScrapInventory(
        catalog: catalog,
        grids: const {
          'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
          'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
        },
        objects: {
          for (final id in [
            'stored',
            'loose',
            'loose-2',
            'loose-3',
            'large-board',
          ])
            id: catalog.createObject(
              instanceId: id,
              itemId: id == 'large-board' ? 'wood.board' : 'wood.chip',
              source: 'street-find',
              quality: 55,
              traits: const {},
            ),
        },
        placements: const {
          'large-board': StreetScrapPlacement(
            instanceId: 'large-board',
            gridId: 'board',
            x: 3,
            y: 3,
            rotation: false,
          ),
        },
        storage: const {
          'home-tutorial-crate': ['stored'],
        },
      );
      await session.applyInventoryCommand(
        commandId: 'seed-workspace-storage',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: initial.grids,
        initialInventory: initial,
        reduceInventory: (inventory) => inventory,
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: catalog,
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                  [],
                  expectedCount: 0,
                ),
                expeditionRules: expeditionRules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('street-scrap-tray-stored')), findsNothing);
      expect(find.byKey(const Key('street-scrap-tray-loose')), findsOneWidget);
      expect(
        find.byKey(const Key('street-scrap-tray-loose-2')),
        findsNothing,
        reason: 'The phone shelf gives one material the full visual card.',
      );
      expect(
        find.byKey(const Key('street-scrap-tray-loose-3')),
        findsNothing,
        reason: 'Additional materials stay off the first no-scroll shelf page.',
      );
      final materialArt = find.byKey(
        const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
      );
      expect(tester.getSize(materialArt.first).width, greaterThan(200));
      await tester.tap(
        find.byKey(const Key('street-scrap-material-page-next')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-tray-loose-2')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-material-page-next')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-tray-loose-3')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-material-page-back')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('street-scrap-material-page-back')),
      );
      await tester.pumpAndSettle();
      final mainBoardEndCell = find
          .byKey(const Key('street-scrap-cell-board-5-5'))
          .first;
      expect(tester.getRect(mainBoardEndCell).bottom, lessThanOrEqualTo(600));
      expect(
        tester
            .getRect(find.byKey(const Key('street-scrap-section-navigation')))
            .bottom,
        lessThanOrEqualTo(600),
      );
      expect(
        find.byKey(const Key('street-scrap-inventory-scroll')),
        findsNothing,
        reason:
            'The materials home screen must stay usable without vertical scrolling.',
      );
      final floatingWorkspaceButton = find.byKey(
        const Key('street-scrap-open-material-workspace'),
      );
      expect(floatingWorkspaceButton, findsOneWidget);
      expect(tester.getRect(floatingWorkspaceButton).bottom, lessThan(600));
      await tester.tap(floatingWorkspaceButton);
      await tester.pumpAndSettle();
      final finalBoardCell = find
          .byKey(const Key('street-scrap-cell-board-5-5'))
          .last;
      expect(finalBoardCell, findsOneWidget);
      final boardBounds = tester.getRect(finalBoardCell);
      expect(boardBounds.top, greaterThanOrEqualTo(0));
      expect(boardBounds.bottom, lessThanOrEqualTo(600));
      final boardSprite = find
          .byKey(
            const ValueKey('street-scrap-sprite:wood.board:street-find:null'),
          )
          .last;
      expect(boardSprite, findsOneWidget);
      expect(
        tester.getSize(boardSprite).width,
        greaterThan(boardBounds.width),
        reason: 'A 2x2 material should use its full visual footprint.',
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-workspace-select-backpack')),
      );
      await tester.pumpAndSettle();
      final lastBackpackCell = find
          .byKey(const Key('street-scrap-cell-backpack-3-3'))
          .last;
      expect(tester.getRect(lastBackpackCell).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(lastBackpackCell).bottom, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const Key('street-scrap-workspace-select-board')),
      );
      await tester.pumpAndSettle();
      final firstMaterialTile = find.byKey(
        const Key('street-scrap-workspace-item-loose'),
      );
      expect(firstMaterialTile, findsOneWidget);
      expect(
        find.byKey(const Key('street-scrap-workspace-item-loose-2')),
        findsNothing,
        reason: 'Phone workspace cards show one large material at a time.',
      );
      final looseSprite = find.byKey(
        const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
      );
      expect(
        tester.getSize(looseSprite.last).width,
        greaterThan(200),
        reason: 'Phone material cards should keep the pixel art prominent.',
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-workspace-page-next')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-workspace-item-loose-2')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-workspace-page-next')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-workspace-item-loose-3')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-workspace-page-previous')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('street-scrap-workspace-page-previous')),
      );
      await tester.pumpAndSettle();
      await tester.tap(firstMaterialTile);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('street-scrap-cell-board-0-0')).last,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-item-loose')).last,
        findsOneWidget,
      );
      expect(find.byKey(const Key('street-scrap-tray-loose')), findsNothing);
      final inventory = session.snapshot.state['inventory'] as Map;
      expect((inventory['storage'] as Map)['home-tutorial-crate'], ['stored']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tablet-width material workspace uses a full-size non-scrolling board',
    (tester) async {
      tester.view.physicalSize = const Size(872, 872);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = StreetScrapSession(
        profileScope: 'workspace-tablet-full-width',
        store: _MemoryProgressStore(),
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      const grids = {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final initial = catalog
          .emptyInventory(grids: grids)
          .addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'tablet-chip',
              itemId: 'wood.chip',
              source: 'street-find',
              quality: 55,
              traits: const {},
            ),
            'board',
          );
      await session.applyInventoryCommand(
        commandId: 'seed-tablet-workspace',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        initialInventory: initial,
        reduceInventory: (inventory) => inventory,
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: catalog,
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                  const [],
                  expectedCount: 0,
                ),
                expeditionRules: expeditionRules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byKey(
        const Key('street-scrap-open-material-workspace'),
      );
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      final finalCell = find
          .byKey(const Key('street-scrap-cell-board-5-5'))
          .last;
      final boardGrid = tester.widget<GridView>(find.byType(GridView).last);
      expect(boardGrid.physics, isA<NeverScrollableScrollPhysics>());
      expect(
        tester.getSize(finalCell).width,
        greaterThan(70),
        reason:
            'The board remains visible while the material shelf keeps large art.',
      );
      expect(tester.getRect(finalCell).bottom, lessThanOrEqualTo(872));
      final sprite = find
          .byKey(
            const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
          )
          .last;
      expect(
        tester.getSize(sprite).width,
        greaterThan(70),
        reason: 'Materials should remain clear on the board.',
      );
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets('wide material workspace keeps large art and grid in view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StreetScrapSession(
      profileScope: 'workspace-wide-layout',
      store: _MemoryProgressStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
      packingRules: const {},
    );
    final grids = const {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final initial = catalog
        .emptyInventory(grids: grids)
        .addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'wide-chip',
            itemId: 'wood.chip',
            source: 'street-find',
            quality: 55,
            traits: const {},
          ),
          'board',
        );
    await session.applyInventoryCommand(
      commandId: 'seed-wide-workspace',
      expectedRevision: session.snapshot.revision,
      catalog: catalog,
      grids: grids,
      initialInventory: initial,
      reduceInventory: (inventory) => inventory,
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                const [],
                expectedCount: 0,
              ),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final materialOverviewCard = find.byKey(
      const Key('street-scrap-wide-overview-wide-chip'),
    );
    expect(
      materialOverviewCard,
      findsOneWidget,
      reason:
          'The wide materials view should use its side area for a visual overview, not leave it blank.',
    );
    final materialOverviewSprite = find.byKey(
      const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
    );
    expect(
      tester.getSize(materialOverviewSprite.last).width,
      greaterThan(140),
      reason: 'Material art should remain large in the visual overview.',
    );
    final overviewShelf = tester.widget<GridView>(
      find.byKey(const Key('street-scrap-wide-material-shelf')),
    );
    expect(overviewShelf.physics, isA<NeverScrollableScrollPhysics>());
    final entry = find.byKey(const Key('street-scrap-open-material-workspace'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-workspace-select-board')),
      findsOneWidget,
      reason: 'The material workspace opens directly on its visual board.',
    );
    final item = find.byKey(const Key('street-scrap-item-wide-chip')).last;
    await tester.tap(item);
    await tester.pumpAndSettle();
    const englishStrings = StreetScrapLocalizations('en');
    expect(
      find.byTooltip(englishStrings.itemSource('street-find')),
      findsWidgets,
    );
    expect(find.byTooltip(englishStrings.itemQuality(55)), findsWidgets);
    final sprites = find.byKey(
      const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
    );
    expect(
      sprites,
      findsNWidgets(6),
      reason:
          'The placed material remains in the image gallery alongside its selected-item controls.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-overview-wide-chip')),
      findsOneWidget,
    );
    expect(
      tester.getSize(sprites.last).width,
      greaterThan(200),
      reason:
          'The side gallery should keep each material image large and glanceable.',
    );
    final finalCell = find.byKey(const Key('street-scrap-cell-board-5-5')).last;
    expect(tester.getRect(finalCell).bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
    final backpackToggle = find.byKey(
      const Key('street-scrap-workspace-select-backpack'),
    );
    expect(backpackToggle, findsOneWidget);
    await tester.tap(backpackToggle);
    await tester.pumpAndSettle();
    final finalBackpackCell = find
        .byKey(const Key('street-scrap-cell-backpack-3-3'))
        .last;
    expect(tester.getRect(finalBackpackCell).bottom, lessThanOrEqualTo(800));
    await tester.tap(
      find.byKey(const Key('street-scrap-workspace-select-board')),
    );
    await tester.pumpAndSettle();
    await session.close();
  });

  testWidgets('wide empty workbench opens on a full-bleed street scene', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(872, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StreetScrapSession(
      profileScope: 'wide-empty-street-scene',
      store: _MemoryProgressStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: StreetScrapInventoryCatalog(
                footprints: const {},
                packingRules: const {},
              ),
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                const [],
                expectedCount: 0,
              ),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scene = find.byKey(const Key('street-scrap-empty-material-explore'));
    expect(scene, findsOneWidget);
    expect(tester.getSize(scene).width, greaterThan(820));
    expect(tester.getSize(scene).height, greaterThan(500));
    final protagonist = find.byKey(
      const Key('street-scrap-empty-scene-protagonist'),
    );
    expect(protagonist, findsOneWidget);
    expect(tester.getSize(protagonist).height, greaterThan(200));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: protagonist, matching: find.byType(CustomPaint)),
      findsOneWidget,
      reason: 'The optional protagonist pack is not installed in this fixture.',
    );
    expect(
      find.descendant(of: protagonist, matching: find.byType(Image)),
      findsNothing,
      reason: 'The shell keeps only the lightweight pixel fallback.',
    );
    expect(
      find.descendant(
        of: scene,
        matching: find.byIcon(Icons.travel_explore_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('street-scrap-cell-board-0-0')), findsNothing);
    expect(
      find.byKey(const Key('street-scrap-inventory-scroll')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-2')),
      findsOneWidget,
      reason: 'The empty street scene cycles to the crouching pose.',
    );
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-3')),
      findsOneWidget,
      reason: 'The idle cycle includes the sorting pose.',
    );
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-0')),
      findsOneWidget,
      reason: 'The ambient poses return to idle before repeating.',
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-0')),
      findsOneWidget,
      reason: 'Reduced motion keeps the character on a static idle pose.',
    );
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    await tester.tap(scene);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-1')),
      findsOneWidget,
      reason: 'The character walks in response to the explore action.',
    );
    expect(
      find.descendant(of: protagonist, matching: find.byType(CustomPaint)),
      findsOneWidget,
      reason: 'The walking pose updates while the optional pack is absent.',
    );
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const Key('street-scrap-section-navigation')),
          )
          .selectedIndex,
      1,
    );
    expect(scene, findsNothing);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets(
    'phone empty workbench stays compact and keeps the board visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = StreetScrapSession(
        profileScope: 'phone-empty-street-workbench',
        store: _MemoryProgressStore(),
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'zh-Hant',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: StreetScrapInventoryCatalog(
                  footprints: const {},
                  packingRules: const {},
                ),
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                  const [],
                  expectedCount: 0,
                ),
                expeditionRules: expeditionRules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final compactEntry = find.byKey(
        const Key('street-scrap-empty-material-explore'),
      );
      expect(compactEntry, findsOneWidget);
      expect(tester.getSize(compactEntry).height, lessThan(80));
      final lastCell = find.byKey(const Key('street-scrap-cell-board-5-5'));
      expect(lastCell, findsOneWidget);
      expect(tester.getRect(lastCell).bottom, lessThanOrEqualTo(844));
      expect(
        find.byKey(const Key('street-scrap-inventory-scroll')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets(
    'tablet material canvas enlarges art without vertical scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(872, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = StreetScrapSession(
        profileScope: 'workspace-tablet-material-layout',
        store: _MemoryProgressStore(),
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      const grids = {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final initial = catalog
          .emptyInventory(grids: grids)
          .addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'tablet-chip',
              itemId: 'wood.chip',
              source: 'street-find',
              quality: 55,
              traits: const {},
            ),
            'board',
          );
      await session.applyInventoryCommand(
        commandId: 'seed-tablet-material-layout',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        initialInventory: initial,
        reduceInventory: (inventory) => inventory,
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'en',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: catalog,
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                  const [],
                  expectedCount: 0,
                ),
                expeditionRules: expeditionRules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-wide-overview-tablet-chip')),
        findsOneWidget,
      );
      final sprite = find.byKey(
        const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
      );
      expect(tester.getSize(sprite.last).width, greaterThan(200));
      final shelf = tester.widget<GridView>(
        find.byKey(const Key('street-scrap-wide-material-shelf')),
      );
      expect(shelf.physics, isA<NeverScrollableScrollPhysics>());
      expect(
        tester
            .getRect(find.byKey(const Key('street-scrap-cell-board-5-5')).last)
            .bottom,
        lessThanOrEqualTo(874),
      );
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets('wide primary board gives materials a large paged side shelf', (
    tester,
  ) async {
    // Match the actual embedded preview width: the material gallery should
    // activate its fourth column before a full desktop-sized viewport.
    tester.view.physicalSize = const Size(1056, 894);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StreetScrapSession(
      profileScope: 'primary-wide-material-shelf',
      store: _MemoryProgressStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
      packingRules: const {},
    );
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final objects = {
      for (var index = 0; index < 9; index++)
        'shelf-$index': catalog.createObject(
          instanceId: 'shelf-$index',
          itemId: 'wood.chip',
          source: 'street-find',
          quality: 55 + index,
          traits: const {},
        ),
    };
    final initial = StreetScrapInventory(
      catalog: catalog,
      grids: grids,
      objects: objects,
      placements: const {},
      storage: const {},
    );
    await session.applyInventoryCommand(
      commandId: 'seed-primary-wide-shelf',
      expectedRevision: session.snapshot.revision,
      catalog: catalog,
      grids: grids,
      initialInventory: initial,
      reduceInventory: (inventory) => inventory,
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              initiallyShowMaterialGallery: true,
              session: session,
              catalog: catalog,
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                const [],
                expectedCount: 0,
              ),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semanticsHandle = tester.ensureSemantics();
    expect(
      find.byKey(const Key('street-scrap-cell-board-0-0')),
      findsNothing,
      reason: 'Game entry opens the full-screen material gallery first.',
    );
    expect(
      find.byKey(const Key('street-scrap-section-navigation')),
      findsOneWidget,
      reason: 'The main game destinations stay reachable in gallery mode.',
    );
    expect(
      find.byKey(const Key('street-scrap-keyboard-grid-focus')),
      findsNothing,
      reason: 'Grid-only keyboard controls are hidden while viewing materials.',
    );
    expect(
      find.byKey(const Key('street-scrap-open-material-workspace')),
      findsNothing,
      reason: 'Gallery mode itself replaces the duplicate workspace shortcut.',
    );
    expect(
      find.byKey(const Key('street-scrap-open-recipes')),
      findsOneWidget,
      reason: 'Recipe lookup remains available beside material artwork.',
    );
    await tester.tap(
      find.byKey(const Key('street-scrap-toggle-material-focus')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-keyboard-grid-focus')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-open-material-workspace')),
      findsOneWidget,
      reason: 'Board controls return when the gallery is closed.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-material-shelf')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-0')),
      findsOneWidget,
    );
    final firstShelfTile = find.byKey(
      const Key('street-scrap-wide-shelf-shelf-0'),
    );
    expect(
      tester.getSize(firstShelfTile).width,
      greaterThan(190),
      reason: 'Material cards should use generous, image-first sizing.',
    );
    final firstShelfSprite = find.byKey(
      const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
    );
    expect(
      tester.getSize(firstShelfSprite.last).width,
      greaterThan(150),
      reason: 'The material image should dominate the card, not its label.',
    );
    expect(
      find.text(const StreetScrapLocalizations('en').itemName('wood.chip')),
      findsWidgets,
      reason: 'Large material cards still need a short visible name label.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-3')),
      findsOneWidget,
      reason: 'The visible page should use its available height efficiently.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-4')),
      findsNothing,
      reason: 'The material shelf is paged instead of vertically scrolling.',
    );
    final shelf = tester.widget<GridView>(
      find.byKey(const Key('street-scrap-wide-material-shelf')),
    );
    expect(shelf.physics, isA<NeverScrollableScrollPhysics>());
    expect(
      find.byKey(const Key('street-scrap-wide-page-next')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-tray-shelf-0')),
      findsNothing,
      reason: 'Wide layouts use the side shelf instead of a second bottom row.',
    );
    final finalBoardCell = find.byKey(const Key('street-scrap-cell-board-5-5'));
    expect(tester.getRect(finalBoardCell).bottom, lessThanOrEqualTo(880));
    await tester.tap(find.byKey(const Key('street-scrap-wide-page-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-4')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('street-scrap-wide-page-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-8')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('street-scrap-toggle-material-focus')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-material-name-shelf-0')),
      findsOneWidget,
      reason:
          'The large image-first gallery keeps a short name overlay so materials remain recognizable.',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('street-scrap-category-wood')))
          .label,
      'Wood',
      reason: 'Icon-only category filters expose their localized label.',
    );
    final allCategorySemantics = tester.getSemantics(
      find.byKey(const Key('street-scrap-category-all')),
    );
    final allCategoryData = allCategorySemantics.getSemanticsData();
    expect(allCategoryData.flagsCollection.isButton, isTrue);
    expect(allCategoryData.flagsCollection.isSelected, Tristate.isTrue);
    expect(allCategoryData.actions & SemanticsAction.tap.index, isNonZero);
    expect(
      find.bySemanticsLabel(RegExp(r'Wood chips.*Found.*Quality.*55')),
      findsWidgets,
      reason:
          'Material art cards expose full item, source and quality information to screen readers.',
    );
    expect(
      tester.getSize(firstShelfSprite.last).width,
      greaterThan(140),
      reason:
          'The no-scroll catalog should keep every visible material image generous.',
    );
    final focusShelf = tester.widget<GridView>(
      find.byKey(const Key('street-scrap-wide-material-shelf')),
    );
    expect(
      (focusShelf.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
      reason: 'Wide material galleries prioritize large art over item density.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-1')),
      findsOneWidget,
      reason: 'The first row should use large image-first material cards.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-2')),
      findsNothing,
      reason:
          'Focus mode keeps a single row of extra-large materials per page.',
    );
    expect(
      focusShelf.physics,
      isA<NeverScrollableScrollPhysics>(),
      reason:
          'Large material focus mode remains paged without vertical scrolling.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-page-next')),
      findsOneWidget,
      reason: 'More materials remain reachable through fixed page controls.',
    );
    expect(
      find.byKey(const Key('street-scrap-section-navigation')),
      findsOneWidget,
      reason: 'The navigation remains visible after returning to the gallery.',
    );
    await tester.tap(find.byKey(const Key('street-scrap-category-wood')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-0')),
      findsOneWidget,
      reason: 'The icon category filter keeps matching materials visible.',
    );
    await tester.tap(find.byKey(const Key('street-scrap-category-other')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-0')),
      findsNothing,
      reason: 'Choosing another category hides non-matching materials.',
    );
    await tester.tap(find.byKey(const Key('street-scrap-category-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-0')),
      findsOneWidget,
    );
    semanticsHandle.dispose();
    tester.view.physicalSize = const Size(320, 600);
    await tester.pumpAndSettle();
    final phoneFocusCard = find.byKey(
      const Key('street-scrap-wide-shelf-shelf-0'),
    );
    expect(phoneFocusCard, findsOneWidget);
    final phoneFocusBounds = tester.getRect(phoneFocusCard);
    expect(phoneFocusBounds.left, greaterThanOrEqualTo(0));
    expect(phoneFocusBounds.right, lessThanOrEqualTo(320));
    expect(phoneFocusBounds.bottom, lessThanOrEqualTo(600));
    expect(
      find.byKey(const Key('street-scrap-material-name-shelf-0')),
      findsOneWidget,
      reason:
          'Phone gallery cards keep the material name visible over the large artwork.',
    );
    final phoneFocusShelf = tester.widget<GridView>(
      find.byKey(const Key('street-scrap-wide-material-shelf')),
    );
    expect(phoneFocusShelf.physics, isA<NeverScrollableScrollPhysics>());
    expect(
      tester.getSize(firstShelfSprite.last).width,
      greaterThan(170),
      reason: 'The 320px phone keeps the material image large in focus mode.',
    );
    expect(
      find.byKey(const Key('street-scrap-keyboard-grid-focus')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('street-scrap-open-material-workspace')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('street-scrap-open-recipes')),
      findsOneWidget,
      reason: 'Useful recipe access stays available on the phone.',
    );
    expect(
      find.byKey(const Key('street-scrap-wide-page-next')),
      findsOneWidget,
      reason: 'Phone users page through materials instead of scrolling.',
    );
    await tester.tap(find.byKey(const Key('street-scrap-wide-page-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-0')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('street-scrap-wide-shelf-shelf-1')),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.byKey(const Key('street-scrap-wide-shelf-shelf-1')))
          .bottom,
      lessThanOrEqualTo(600),
    );
    // Match the current 390x844 local preview as well as the compact 320px
    // handset above. Keep the artwork dominant and the catalog page bounded.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    final previewPhoneCard = find.byKey(
      const Key('street-scrap-wide-shelf-shelf-1'),
    );
    final previewPhoneBounds = tester.getRect(previewPhoneCard);
    expect(previewPhoneBounds.left, greaterThanOrEqualTo(0));
    expect(previewPhoneBounds.right, lessThanOrEqualTo(390));
    expect(previewPhoneBounds.bottom, lessThanOrEqualTo(844));
    expect(
      tester.getSize(firstShelfSprite.last).width,
      greaterThan(190),
      reason: 'The 390px preview keeps the material image large.',
    );
    expect(
      tester
          .widget<GridView>(
            find.byKey(const Key('street-scrap-wide-material-shelf')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
      reason: 'The 390px material catalog pages without vertical scrolling.',
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('work board and recipe index follow the English locale', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final session = StreetScrapSession(
      profileScope: 'inventory-page-english',
      store: _MemoryProgressStore(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.0',
      },
      rulesetVersion: 1,
    );
    await session.load();
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {},
      packingRules: const {},
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes([
                for (var i = 0; i < 78; i++)
                  StreetScrapRecipe(
                    id: 'ss.recipe.$i',
                    phase: 0,
                    station: 'workbench',
                    operationId: 'strike',
                    durationSeconds: 1,
                    instructions: 'test',
                    inputGroups: const [
                      [
                        StreetScrapRecipeInput(
                          itemId: 'wood.chip',
                          quantity: 1,
                        ),
                      ],
                    ],
                    reusableTools: const [],
                    outputs: const [
                      StreetScrapRecipeInput(itemId: 'wood.chip', quantity: 1),
                    ],
                    quality: StreetScrapRecipeQualityRule(
                      primaryInputs: const ['wood.chip'],
                      loss: 0,
                      mode: 'weighted-primary',
                      masteryRevision: 1,
                    ),
                    retainedInputIds: const [],
                    failureMode: 'reducedQualityOutput',
                    failureOutcome: 'test failure',
                  ),
              ]),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final compactEmptyShelf = find.byKey(
      const Key('street-scrap-empty-material-explore'),
    );
    expect(compactEmptyShelf, findsOneWidget);
    expect(
      tester.getSize(compactEmptyShelf).height,
      lessThan(80),
      reason: 'The empty material shelf should leave room for larger artwork.',
    );
    expect(
      find.descendant(
        of: compactEmptyShelf,
        matching: find.byIcon(Icons.travel_explore_rounded),
      ),
      findsOneWidget,
    );
    final workspaceButton = find.byKey(
      const Key('street-scrap-open-material-workspace'),
    );
    await tester.ensureVisible(workspaceButton);
    await tester.tap(workspaceButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-cell-board-0-0')).last,
      findsOneWidget,
    );
    final workspaceCell = find
        .byKey(const Key('street-scrap-cell-board-0-0'))
        .last;
    expect(workspaceCell, findsOneWidget);
    expect(tester.getSize(workspaceCell).width, greaterThan(60));
    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();

    final firstCellKey = find.byKey(const Key('street-scrap-cell-board-0-0'));
    expect(
      find.byKey(const Key('street-scrap-inventory-scroll')),
      findsNothing,
    );
    expect(tester.getRect(firstCellKey).bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('street-scrap-nav-workshop')));
    await tester.pumpAndSettle();
    final collectionButton = find.byKey(
      const Key('street-scrap-open-collection'),
    );
    expect(collectionButton, findsOneWidget);
    await tester.tap(collectionButton);
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsOneWidget);
    expect(
      find.byKey(const Key('street-scrap-close-collection')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('street-scrap-close-collection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-nav-board')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final firstCell = find.bySemanticsLabel(
      RegExp('Work Board, row 1, column 1, empty'),
    );
    expect(firstCell, findsOneWidget);
    expect(
      tester.getSemantics(firstCell).hint,
      contains('Double-tap to place the selected item'),
    );
    semanticsHandle.dispose();
    await session.close();
  });

  testWidgets('filter recipes show each bottle water type in text and art', (
    tester,
  ) async {
    final session = StreetScrapSession(
      profileScope: 'inventory-page-filter-recipe-water-context',
      store: _MemoryProgressStore(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.59',
      },
      rulesetVersion: 1,
    );
    await session.load();
    await session.apply(
      commandId: 'seed-filter-recipe-water-context',
      expectedRevision: session.snapshot.revision,
      reduce: (_) => StreetScrapReduction(state: const {'chapter': 4}),
    );
    StreetScrapRecipe recipe(String id, String sourceWater) =>
        StreetScrapRecipe(
          id: id,
          phase: 4,
          station: 'kitchen',
          operationId: 'filter',
          durationSeconds: 10,
          instructions: 'Filter water.',
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
          failureOutcome: 'The water remains unchanged.',
          stateEffect: {
            'type': 'transformContainers',
            'containers': [
              {
                'containerItemId': 'container.clean',
                'requiredContentItemId': sourceWater,
                'successContentItemId': 'water.filtered',
                'failureContentItemId': sourceWater,
              },
            ],
          },
        );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: StreetScrapInventoryCatalog(
                footprints: const {},
                packingRules: const {},
              ),
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes([
                recipe('ss.recipe.filter_turbid', 'water.turbid'),
                recipe('ss.recipe.filter_dirty', 'water.dirty'),
              ], expectedCount: 2),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-open-recipes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-recipe-phase-4')));
    await tester.pumpAndSettle();

    expect(
      find.text('Filter: Clean container → Filtered water (Turbid water)'),
      findsOneWidget,
    );
    expect(
      find.text('Filter: Clean container → Filtered water (Dirty water)'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is StreetScrapItemSprite &&
            widget.contentItemId == 'water.turbid',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is StreetScrapItemSprite &&
            widget.contentItemId == 'water.dirty',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is StreetScrapItemSprite &&
            widget.itemId == 'container.clean' &&
            widget.contentItemId == 'water.filtered',
      ),
      findsNWidgets(2),
    );
    expect(
      tester
          .getSemantics(
            find.byKey(
              const Key('street-scrap-recipe-ss.recipe.filter_turbid'),
            ),
          )
          .label,
      contains('Clean container containing Turbid water'),
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('shared meal packing requires explicit reusable-box choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {
        'meal.shared': StreetScrapFootprint(1, 1),
        'container.meal_box': StreetScrapFootprint(1, 2),
      },
      packingRules: const {},
    );
    final session = StreetScrapSession(
      profileScope: 'inventory-shared-meal-pack',
      store: _MemoryProgressStore(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.22',
        'game.street-scrap.content.chapter-5': '0.1.19',
      },
      rulesetVersion: 1,
    );
    await session.load();
    final inventory = catalog
        .emptyInventory(
          grids: const {
            'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
            'backpack': StreetScrapGridSpec(
              id: 'backpack',
              width: 4,
              height: 4,
            ),
          },
        )
        .addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'cooked-shared-meal',
            itemId: 'meal.shared',
            source: 'crafted:ss.recipe.shared_meal',
            quality: 76,
            traits: const {'rich_ingredient': true},
            toolDurability: null,
            footprint: const StreetScrapFootprint(1, 1),
            provenance: const [
              {
                'eventId': 'craft:q5-shared-meal',
                'kind': 'craft',
                'recipeId': 'ss.recipe.shared_meal',
                'revision': 1,
                'outcome': 'success',
                'inputs': [],
              },
            ],
          ),
          'backpack',
        )
        .addAndPlaceFirstFit(
          StreetScrapObject(
            instanceId: 'reusable-meal-box',
            itemId: 'container.meal_box',
            source: 'reused:kitchen',
            quality: 63,
            traits: const {},
            toolDurability: null,
            footprint: const StreetScrapFootprint(1, 2),
            containerState: const {'cleanliness': 'clean'},
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'prepare-shared-meal-ui',
      expectedRevision: 0,
      reduce: (_) => StreetScrapReduction(
        state: {'chapter': 5, 'inventory': inventory.toJson()},
      ),
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: _testRecipeCatalog(),
              expeditionRules: expeditionRules,
              maxStamina: 60,
              chapter5Installed: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-select-backpack')));
    await tester.pumpAndSettle();
    final mealItem = find.byKey(
      const Key('street-scrap-item-cooked-shared-meal'),
    );
    await tester.ensureVisible(mealItem);
    await tester.tap(mealItem);
    await tester.pumpAndSettle();
    final packAction = find.byKey(const Key('street-scrap-pack-shared-meal'));
    await tester.tap(find.byKey(const Key('street-scrap-material-actions')));
    await tester.pumpAndSettle();
    await tester.tap(packAction);
    await tester.pumpAndSettle();
    expect(find.text('選擇要使用的餐盒'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('street-scrap-meal-box-reusable-meal-box')),
    );
    await tester.pumpAndSettle();
    expect(find.text('確認裝盒'), findsOneWidget);
    await tester.tap(find.byKey(const Key('street-scrap-confirm-meal-pack')));
    await tester.pumpAndSettle();

    final saved = catalog.inventoryFromJson(
      grids: const {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      },
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(saved.objects.containsKey('cooked-shared-meal'), isFalse);
    final returnedBox = saved.objects['reusable-meal-box']!;
    expect(returnedBox.itemId, 'container.meal_box');
    expect(returnedBox.containerState['contentItemId'], 'meal.shared');
    expect(returnedBox.containerState['contentQuality'], 76);
    expect(returnedBox.containerState['contentTraits'], {
      'rich_ingredient': true,
    });
    expect(returnedBox.provenance.map((event) => event['kind']), [
      'craft',
      'pack',
    ]);
    await session.close();
  });

  testWidgets(
    'full backpack craft reports the required output-space recovery action',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const grids = {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {
          'wood.chip': StreetScrapFootprint(1, 1),
          'cloth.rag_piece': StreetScrapFootprint(1, 1),
          'cloth.edge_scrap': StreetScrapFootprint(1, 1),
          'cloth.thread_end': StreetScrapFootprint(1, 1),
          'tool.needle': StreetScrapFootprint(1, 1),
        },
        packingRules: const {},
      );
      var inventory = catalog.emptyInventory(grids: grids);
      inventory = inventory.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'lesson-rag',
          itemId: 'cloth.rag_piece',
          source: 'tutorial:q1.02-rag',
          quality: 55,
          traits: const {},
        ),
        'backpack',
      );
      inventory = inventory.addAndPlaceFirstFit(
        catalog.createObject(
          instanceId: 'lesson-needle',
          itemId: 'tool.needle',
          source: 'tutorial:q1.02-needle',
          quality: 55,
          traits: const {},
        ),
        'backpack',
      );
      for (var index = 0; index < 14; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'filler-$index',
            itemId: 'wood.chip',
            source: 'test:full-backpack',
            quality: 55,
            traits: const {},
          ),
          'backpack',
        );
      }
      final recipe = StreetScrapRecipe(
        id: 'ss.recipe.unpick_cloth',
        phase: 1,
        station: 'recycler',
        operationId: 'unpick',
        durationSeconds: 10,
        instructions: '沿縫線拆線',
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
          loss: 10,
          mode: 'weighted-primary',
          masteryRevision: 1,
        ),
        retainedInputIds: const [],
        traitResolution: const {
          'inherit': [],
          'polarity': {},
          'success': {},
          'precise': {},
          'failure': {},
        },
        failureMode: 'explicitOutcome',
        failureOutcome: '材料已拆解',
        manualCheckpoints: const [],
      );
      final session = StreetScrapSession(
        profileScope: 'inventory-full-backpack-unpick-output',
        store: _MemoryProgressStore(),
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      await session.apply(
        commandId: 'seed-full-backpack-unpick',
        expectedRevision: 0,
        reduce: (_) => StreetScrapReduction(
          state: {
            'chapter': 1,
            'tutorialTasks': const {'q1.01': true},
            'unlockedStations': const ['recycler'],
            'q1.02KitClaimed': true,
            'inventory': inventory.toJson(),
          },
        ),
      );
      await tester.pumpWidget(
        StreetScrapLocalizationsScope(
          locale: 'zh-Hant',
          child: MaterialApp(
            home: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: catalog,
                recipeCatalog: StreetScrapRecipeCatalog.fromRecipes([
                  recipe,
                ], expectedCount: 1),
                expeditionRules: expeditionRules,
                maxStamina: 60,
                chapter5Installed: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street-scrap-select-backpack')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street-scrap-open-recipes')));
      await tester.pumpAndSettle();
      final recipeCard = find.byKey(
        const Key('street-scrap-recipe-ss.recipe.unpick_cloth'),
      );
      await tester.ensureVisible(recipeCard);
      await tester.tap(recipeCard);
      await tester.pumpAndSettle();
      final selectMaterials = find.text('選料並加工');
      await tester.ensureVisible(selectMaterials);
      await tester.tap(selectMaterials);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('street-scrap-craft-material-lesson-rag')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final revisionBeforeCraft = session.snapshot.revision;
      await tester.tap(find.text('確認並完成'));
      await tester.pumpAndSettle();

      expect(find.text('格盤空間不足。先把物品移到另一格盤或收納箱，再試一次。'), findsOneWidget);
      expect(session.snapshot.revision, revisionBeforeCraft);
      final unchanged = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        unchanged.objects.keys,
        containsAll(['lesson-rag', 'lesson-needle']),
      );
      expect(
        unchanged.objects.keys.where((id) => id.startsWith('unpick-output-')),
        isEmpty,
      );
      await session.close();
    },
  );

  testWidgets('craft material selection dialog follows the English locale', (
    tester,
  ) async {
    final session = StreetScrapSession(
      profileScope: 'inventory-craft-dialog-english',
      store: _MemoryProgressStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: StreetScrapInventoryCatalog(
                footprints: const {},
                packingRules: const {},
              ),
              recipeCatalog: _testRecipeCatalog(),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final recipes = find.byTooltip('View recipes (78)');
    await tester.tap(recipes);
    await tester.pumpAndSettle();
    final recipe = find.byKey(const Key('street-scrap-recipe-test.recipe.0'));
    await tester.ensureVisible(recipe);
    await tester.tap(recipe);
    await tester.pumpAndSettle();
    expect(find.text('Phase 0 · Woodworking bench · 1s'), findsWidgets);
    expect(find.text('Steps: test'), findsNothing);
    await tester.tap(find.byKey(const Key('street-scrap-recipe-detail-info')));
    await tester.pumpAndSettle();
    expect(find.text('Steps: test'), findsOneWidget);
    expect(find.text('Requirements: Wood chips × 1'), findsOneWidget);
    final openCraft = find.text('Select materials and craft');
    await tester.ensureVisible(openCraft);
    await tester.tap(openCraft);
    await tester.pumpAndSettle();

    expect(find.text('Craft Shape: Wood chips → Wood chips'), findsOneWidget);
    expect(
      find.byTooltip(
        'Action: test. Select each material and any reusable tools.',
      ),
      findsOneWidget,
    );
    expect(find.text('Select materials'), findsNothing);
    final woodChipProgress = tester.widget<Semantics>(
      find.byKey(const Key('street-scrap-craft-input-count-wood.chip')),
    );
    expect(woodChipProgress.properties.label, 'Wood chips: selected 0 / 1');
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
    expect(find.text('Materials are not on this grid'), findsOneWidget);
    final organizeGrid = find.byKey(
      const Key('street-scrap-craft-open-other-grid'),
    );
    expect(organizeGrid, findsOneWidget);
    await tester.tap(organizeGrid);
    await tester.pumpAndSettle();
    final openWorkspace = find.byKey(
      const Key('street-scrap-open-material-workspace'),
    );
    await tester.ensureVisible(openWorkspace);
    await tester.tap(openWorkspace);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('street-scrap-workspace-select-backpack')),
          )
          .isSelected,
      isTrue,
      reason:
          'The empty-material action should take the player to the bag grid.',
    );
    await tester.tap(
      find.byKey(const Key('street-scrap-close-material-workspace')),
    );
    await tester.pumpAndSettle();
    await session.close();
  });

  testWidgets(
    'manual craft UI completes all checkpoints against the aggregate active version',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = StreetScrapSession(
        profileScope: 'inventory-active-content-manual-craft',
        store: _MemoryProgressStore(),
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.21',
          'game.street-scrap.content.active': '0.1.21+0.1.19',
        },
        rulesetVersion: 1,
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      final grids = const {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final initial =
          StreetScrapInventory(
            catalog: catalog,
            grids: grids,
            objects: const {},
            placements: const {},
            storage: const {},
          ).addAndPlaceFirstFit(
            catalog.createObject(
              instanceId: 'manual-chip',
              itemId: 'wood.chip',
              source: 'street-find',
              quality: 60,
              traits: const {},
            ),
            'board',
          );
      await session.applyInventoryCommand(
        commandId: 'seed-active-version-manual-chip',
        expectedRevision: 0,
        catalog: catalog,
        grids: grids,
        initialInventory: initial,
        reduceInventory: (inventory) => inventory,
      );
      await session.apply(
        commandId: 'enable-assisted-manual-checkpoints',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'gameSettings': const {
              'textScale': 1.0,
              'reduceMotion': false,
              'assistedControls': true,
              'soundVolume': 100,
            },
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: _testRecipeCatalog(manual: true),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final recipesButton = find.byTooltip('查看配方（78）');
      await tester.tap(recipesButton);
      await tester.pumpAndSettle();
      final firstRecipe = find.byKey(
        const Key('street-scrap-recipe-test.recipe.0'),
      );
      await tester.ensureVisible(firstRecipe);
      await tester.tap(firstRecipe);
      await tester.pumpAndSettle();
      final craftButton = find.text('選料並加工');
      await tester.ensureVisible(craftButton);
      await tester.tap(craftButton);
      await tester.pumpAndSettle();
      final material = find.byKey(
        const Key('street-scrap-craft-material-manual-chip'),
      );
      final materialSprite = find.descendant(
        of: material,
        matching: find.byType(StreetScrapItemSprite),
      );
      expect(tester.widget<StreetScrapItemSprite>(materialSprite).size, 88);
      await tester.ensureVisible(material);
      await tester.tap(material);
      await tester.pumpAndSettle();
      final startManual = find.text('開始手動加工');
      await tester.ensureVisible(startManual);
      await tester.tap(startManual);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        (session.snapshot.state['craftOperation']! as Map)['contentVersion'],
        '0.1.21+0.1.19',
      );
      for (var step = 0; step < 3; step++) {
        expect(find.text('加工步驟 ${step + 1} / 3'), findsOneWidget);
        await tester.tap(find.text('選落點 ${step + 1}'));
        await tester.pump();
        await tester.tap(find.text('保存本步'));
        await tester.pump();
        expect(find.text('到位'), findsOneWidget);
        await tester.tap(find.text('保存並繼續'));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(session.snapshot.state['craftOperation'], isNull);
      final settledInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(settledInventory.objects.containsKey('manual-chip'), isFalse);
      expect(settledInventory.objects.values.single.itemId, 'wood.chip');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.close();
    },
  );

  testWidgets(
    'malformed inventory save is preserved without auto relief writes',
    (tester) async {
      final store = _MemoryProgressStore();
      final initial = StreetScrapSession(
        profileScope: 'inventory-page-malformed-save',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await initial.load();
      store.values[initial.slotKey] = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {},
        revision: 1,
        savedAt: DateTime.utc(2026, 10, 24),
        state: const {'collectionItemIds': 'invalid'},
        commandReceipts: const {},
      ).toJson();
      await initial.close();

      final session = StreetScrapSession(
        profileScope: 'inventory-page-malformed-save',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      await tester.pumpWidget(
        MaterialApp(
          home: StreetScrapLocalizationsScope(
            locale: 'en',
            child: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: StreetScrapInventoryCatalog(
                  footprints: const {},
                  packingRules: const {},
                ),
                recipeCatalog: _testRecipeCatalog(),
                expeditionRules: expeditionRules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Game save data could not be read. This page is paused to avoid overwriting progress, and the save is unchanged. Return to game progress and use Save Recovery to inspect backups.',
        ),
        findsOneWidget,
      );
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['collectionItemIds'], 'invalid');
      expect(session.snapshot.state.containsKey('relief'), isFalse);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets('pending craft can be resumed from the woodworking section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryProgressStore();
    final session = StreetScrapSession(
      profileScope: 'inventory-page-pending-craft-workbench',
      store: store,
      contentVersions: const {},
      rulesetVersion: 1,
    );
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {},
      packingRules: const {},
    );
    await session.load();
    await session.apply(
      commandId: 'seed-pending-craft-workbench',
      expectedRevision: session.snapshot.revision,
      reduce: (_) => StreetScrapReduction(
        state: {
          'chapter': 3,
          'tutorialTasks': const {'q2.03': true},
          'inventory': catalog.emptyInventory(grids: grids).toJson(),
          'craftOperation': const {
            'operationId': 'pending-wood-board',
            'recipeId': 'wood.strip_to_board',
            'lockedInstanceIds': <String>[],
            'answers': <int>[1, 0],
          },
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: _testRecipeCatalog(),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-nav-workshop')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('street-scrap-workbench-pending-operation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-workbench-protagonist')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('street-scrap-protagonist-pose-3')),
      findsOneWidget,
    );
    expect(find.text('Crafting is waiting to be settled'), findsOneWidget);
    expect(find.textContaining('2 / 3 action steps saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.close();
  });

  testWidgets(
    'malformed craft reservation opens recovery without rewriting save',
    (tester) async {
      final store = _MemoryProgressStore();
      final initial = StreetScrapSession(
        profileScope: 'inventory-page-malformed-craft-reservation',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await initial.load();
      store.values[initial.slotKey] = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {},
        revision: 1,
        savedAt: DateTime.utc(2026, 10, 24),
        state: const {
          'craftOperation': {'lockedInstanceIds': 'invalid'},
        },
        commandReceipts: const {},
      ).toJson();
      await initial.close();

      final session = StreetScrapSession(
        profileScope: 'inventory-page-malformed-craft-reservation',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      await tester.pumpWidget(
        MaterialApp(
          home: StreetScrapLocalizationsScope(
            locale: 'en',
            child: Scaffold(
              body: StreetScrapInventoryPage(
                session: session,
                catalog: StreetScrapInventoryCatalog(
                  footprints: const {},
                  packingRules: const {},
                ),
                recipeCatalog: _testRecipeCatalog(),
                expeditionRules: expeditionRules,
                maxStamina: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Game save data could not be read. This page is paused to avoid overwriting progress, and the save is unchanged. Return to game progress and use Save Recovery to inspect backups.',
        ),
        findsOneWidget,
      );
      expect(session.snapshot.revision, 1);
      expect(
        (session.snapshot.state['craftOperation'] as Map)['lockedInstanceIds'],
        'invalid',
      );
      expect(session.snapshot.state.containsKey('relief'), isFalse);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets(
    'workspace refreshes immediately after crafting from the recipe index',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _MemoryProgressStore();
      final session = StreetScrapSession(
        profileScope: 'inventory-page-test',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
      );
      await session.load();
      await session.apply(
        commandId: 'seed-recipe-mastery',
        expectedRevision: 0,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 3,
            'tutorialTasks': {'q2.03': true},
            'mastery': {'ss.recipe.0': 1},
          },
        ),
      );
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      final initial = StreetScrapInventory(
        catalog: catalog,
        grids: const {
          'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
          'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
        },
        objects: {
          'chip-1': catalog.createObject(
            instanceId: 'chip-1',
            itemId: 'wood.chip',
            source: 'street-find',
            quality: 72,
            traits: const {'smoky': true},
          ),
        },
        placements: const {},
        storage: const {},
      );
      await session.applyInventoryCommand(
        commandId: 'seed-test-item',
        expectedRevision: 1,
        catalog: catalog,
        grids: initial.grids,
        initialInventory: initial,
        reduceInventory: (inventory) => inventory,
      );

      final renderingErrors = <FlutterErrorDetails>[];
      final previousFlutterErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        renderingErrors.add(details);
        previousFlutterErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousFlutterErrorHandler);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes([
                for (var i = 0; i < 78; i++)
                  StreetScrapRecipe(
                    id: 'ss.recipe.$i',
                    phase: i == 0 ? 0 : 1,
                    station: 'workbench',
                    operationId: 'strike',
                    durationSeconds: 10,
                    instructions: '排列材料',
                    inputGroups: [
                      [
                        const StreetScrapRecipeInput(
                          itemId: 'wood.chip',
                          quantity: 1,
                        ),
                      ],
                    ],
                    reusableTools: const [],
                    outputs: const [
                      StreetScrapRecipeInput(itemId: 'wood.chip', quantity: 1),
                    ],
                    quality: StreetScrapRecipeQualityRule(
                      primaryInputs: const ['wood.chip'],
                      loss: 0,
                      mode: 'weighted-primary',
                      masteryRevision: 1,
                    ),
                    retainedInputIds: const [],
                    failureMode: 'reducedQualityOutput',
                    failureOutcome: '品質降低',
                    failureResolution: StreetScrapFailureResolution(
                      mode: 'sameOutputsQualityLoss',
                      qualityLoss: 10,
                    ),
                    qualityTraitEffects: i == 0
                        ? const [
                            {
                              'inputItemId': 'wood.chip',
                              'traitId': 'smoky',
                              'polarity': 'negative',
                              'modifier': -3,
                            },
                          ]
                        : const [],
                    manualCheckpoints: [
                      StreetScrapManualCheckpoint(
                        prompt: '步驟1',
                        options: const ['錯', '對', '錯'],
                        correctOption: 1,
                      ),
                      StreetScrapManualCheckpoint(
                        prompt: '步驟2',
                        options: const ['錯', '對', '錯'],
                        correctOption: 1,
                      ),
                      StreetScrapManualCheckpoint(
                        prompt: '步驟3',
                        options: const ['錯', '對', '錯'],
                        correctOption: 1,
                      ),
                    ],
                  ),
              ]),
              expeditionRules: expeditionRules,
              maxStamina: 60,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semanticsHandle = tester.ensureSemantics();
      expect(
        renderingErrors,
        isEmpty,
        reason: renderingErrors.map((error) => error.toString()).join('\n'),
      );
      Future<void> scrollTo(Finder finder, {bool towardTop = false}) async {
        for (var attempt = 0; attempt < 12; attempt++) {
          if (finder.evaluate().isNotEmpty) {
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            return;
          }
          await tester.drag(
            find.byKey(const Key('street-scrap-inventory-scroll')),
            Offset(0, towardTop ? 500 : -500),
          );
          await tester.pumpAndSettle();
        }
        expect(finder, findsWidgets);
      }

      final firstCell = find.byKey(const Key('street-scrap-cell-board-0-0'));
      await scrollTo(firstCell);
      expect(firstCell, findsOneWidget);
      expect(tester.getSemantics(firstCell).label, contains('空格'));
      expect(
        find.bySemanticsLabel('物品棋盤。方向鍵移動格位，Enter 或空白鍵選取／放置，R 旋轉，Escape 取消選取。'),
        findsOneWidget,
      );

      Future<void> revealSheetContent(Finder finder) async {
        for (var attempt = 0; attempt < 6; attempt++) {
          if (finder.evaluate().isNotEmpty) {
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            final rect = tester.getRect(finder);
            if (rect.top >= 0 && rect.bottom <= 900) return;
          }
          await tester.drag(find.byType(ListView).last, const Offset(0, -360));
          await tester.pumpAndSettle();
        }
        expect(finder, findsOneWidget);
        expect(tester.getRect(finder).bottom, lessThanOrEqualTo(900));
      }

      final collectionTile = find.byKey(
        const Key('street-scrap-collection-book'),
      );
      await tester.tap(find.byKey(const Key('street-scrap-nav-workshop')));
      await tester.pumpAndSettle();
      await scrollTo(collectionTile);
      expect(find.text('首次取得 1 / 1 種物品'), findsOneWidget);
      await tester.tap(collectionTile);
      await tester.pumpAndSettle();
      expect(find.text('碎木片'), findsWidgets);
      expect(find.text('已取得'), findsOneWidget);
      await tester.tap(find.byKey(const Key('street-scrap-close-collection')));
      await tester.pumpAndSettle();
      final knownRecipes = find.byKey(const Key('street-scrap-known-recipes'));
      await scrollTo(knownRecipes, towardTop: true);
      await tester.tap(knownRecipes);
      await tester.pumpAndSettle();
      expect(find.text('78 / 78 項已解鎖'), findsWidgets);
      expect(
        find.byKey(const Key('street-scrap-known-recipe-ss.recipe.0')),
        findsOneWidget,
      );
      expect(find.text('敲製・碎木片 → 碎木片'), findsWidgets);
      expect(find.text('已解鎖・階段 1'), findsWidgets);
      expect(
        renderingErrors,
        isEmpty,
        reason: renderingErrors.map((error) => error.toString()).join('\n'),
      );
      await tester.tap(find.byKey(const Key('street-scrap-close-recipes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('street-scrap-nav-board')));
      await tester.pumpAndSettle();

      final itemFinder = find.byKey(const Key('street-scrap-tray-chip-1'));
      expect(
        tester.getRect(itemFinder).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      final largeTraySprite = find.byKey(
        const ValueKey('street-scrap-sprite:wood.chip:street-find:null'),
      );
      expect(largeTraySprite, findsWidgets);
      expect(
        tester.getSize(largeTraySprite.first).width,
        greaterThanOrEqualTo(90),
        reason: 'The material shelf should prioritize large, readable art.',
      );
      expect(
        find.bySemanticsLabel(RegExp(r'碎木片，來源 原生／拾得，品質 良好（72），占格 1 乘 1')),
        findsOneWidget,
      );
      final listDragTarget = find.byKey(
        const Key('street-scrap-cell-board-1-0'),
      );
      expect(listDragTarget, findsOneWidget);
      expect(tester.getRect(listDragTarget).bottom, lessThanOrEqualTo(900));
      await tester.dragFrom(
        tester.getCenter(itemFinder),
        tester.getCenter(listDragTarget) - tester.getCenter(itemFinder),
      );
      await tester.pumpAndSettle();
      final listDraggedInventory = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(listDraggedInventory.placements['chip-1']?.x, 1);
      expect(listDraggedInventory.placements['chip-1']?.y, 0);
      expect(find.text('復原'), findsOneWidget);
      await tester.tap(find.text('復原'));
      await tester.pumpAndSettle();
      final listDragUndone = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(listDragUndone.placements.containsKey('chip-1'), isFalse);
      await scrollTo(itemFinder);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();
      expect(find.byTooltip('燃燒冒煙・下次熱加工成品品質 −3'), findsOneWidget);
      final keyboardControl = find.byKey(
        const Key('street-scrap-keyboard-grid-focus'),
      );
      await scrollTo(keyboardControl, towardTop: true);
      await tester.tap(keyboardControl);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final firstKeyboardMove = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(firstKeyboardMove.placements['chip-1']?.x, 1);
      expect(firstKeyboardMove.placements['chip-1']?.y, 0);
      await tester.tap(find.text('復原'));
      await tester.pumpAndSettle();
      final keyboardUndone = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(keyboardUndone.placements.containsKey('chip-1'), isFalse);
      expect(keyboardUndone.objects['chip-1']?.source, 'street-find');
      expect(keyboardUndone.objects['chip-1']?.quality, 72);
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();
      await tester.tap(keyboardControl);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      final keyboardPlaced = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(keyboardPlaced.placements['chip-1']?.x, 1);
      expect(keyboardPlaced.placements['chip-1']?.y, 0);
      expect(keyboardPlaced.placements['chip-1']?.rotation, isTrue);
      final selectedBoardItem = find.bySemanticsLabel(
        '工作棋盤，第 1 行第 2 列起始，碎木片，來源 原生／拾得，品質 良好（72），占格 1 乘 1 格',
      );
      expect(selectedBoardItem, findsOneWidget);
      expect(
        tester.getSemantics(selectedBoardItem).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      final selectionRevision = session.snapshot.revision;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(selectedBoardItem).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(selectedBoardItem).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      expect(session.snapshot.revision, selectionRevision);
      final gridItem = find.byKey(const Key('street-scrap-item-chip-1'));
      final dragTarget = find.byKey(const Key('street-scrap-cell-board-2-0'));
      await scrollTo(dragTarget, towardTop: true);
      final dragStart = tester.getCenter(gridItem);
      final dragEnd = tester.getCenter(dragTarget);
      await tester.dragFrom(dragStart, dragEnd - dragStart);
      await tester.pumpAndSettle();
      final draggedInventory = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(draggedInventory.placements['chip-1']?.x, 2);
      expect(draggedInventory.placements['chip-1']?.y, 0);
      final targetCell = find.byKey(const Key('street-scrap-cell-board-0-0'));
      await scrollTo(targetCell, towardTop: true);
      await tester.tap(targetCell);
      await tester.pumpAndSettle();

      final workspaceButton = find.byKey(
        const Key('street-scrap-open-material-workspace'),
      );
      await scrollTo(workspaceButton, towardTop: true);
      await tester.tap(workspaceButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-cell-board-0-0')).last,
        findsOneWidget,
      );
      final recipesButton = find.byTooltip('查看配方（78）').last;
      await scrollTo(recipesButton, towardTop: true);
      await tester.tap(recipesButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-recipe-pages')),
        findsOneWidget,
      );
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      await tester.tap(find.byKey(const Key('street-scrap-recipe-page-next')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('street-scrap-recipe-ss.recipe.1')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('street-scrap-recipe-page-previous')),
      );
      await tester.pumpAndSettle();
      expect(find.text('階段 1・尚未解鎖（目前階段 0）'), findsNothing);
      final firstRecipe = find.byKey(
        const Key('street-scrap-recipe-ss.recipe.0'),
      );
      await revealSheetContent(firstRecipe);
      await tester.tap(firstRecipe);
      await tester.pumpAndSettle();
      final craftButton = find.text('選料並加工');
      await revealSheetContent(craftButton);
      await tester.tap(craftButton);
      await tester.pumpAndSettle();
      final selectedMaterial = find.byKey(
        const Key('street-scrap-craft-material-chip-1'),
      );
      await revealSheetContent(selectedMaterial);
      await tester.tap(selectedMaterial);
      await tester.pumpAndSettle();
      await revealSheetContent(find.text('本次材料的品質效果預覽'));
      expect(find.text('本次材料的品質效果預覽'), findsOneWidget);
      await revealSheetContent(find.text('燃燒冒煙：下次熱加工成品品質 −3'));
      expect(find.text('燃燒冒煙：下次熱加工成品品質 −3'), findsOneWidget);
      final quickCraft = find.text('熟練快速製作');
      await revealSheetContent(quickCraft);
      await tester.tap(quickCraft);
      await tester.pumpAndSettle();

      final saved = catalog.inventoryFromJson(
        grids: initial.grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects.containsKey('chip-1'), isFalse);
      final crafted = saved.objects.values.singleWhere(
        (item) => item.source.startsWith('crafted:'),
      );
      expect(crafted.itemId, 'wood.chip');
      expect(crafted.quality, 69);
      expect(
        find.byKey(Key('street-scrap-item-${crafted.instanceId}')),
        findsNWidgets(2),
        reason:
            'The open workspace must show the committed output immediately.',
      );
      expect(session.snapshot.state['mastery'], {'ss.recipe.0': 1});
      expect(session.snapshot.revision, 11);
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      final settingsButton = find.byKey(
        const Key('street-scrap-open-settings'),
      );
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
      final textScale = tester.widget<Slider>(
        find.byKey(const Key('street-scrap-text-scale')),
      );
      textScale.onChanged!(1.5);
      await tester.pumpAndSettle();
      expect(find.text('遊戲額外字級：150%'), findsOneWidget);
      final soundVolumeFinder = find.byKey(
        const Key('street-scrap-sound-volume'),
      );
      await revealSheetContent(soundVolumeFinder);
      final soundVolume = tester.widget<Slider>(soundVolumeFinder);
      soundVolume.onChanged!(40);
      await tester.pumpAndSettle();
      expect(find.text('本機遊戲音效・40%。'), findsOneWidget);
      await revealSheetContent(
        find.byKey(const Key('street-scrap-reduce-motion')),
      );
      await tester.tap(find.byKey(const Key('street-scrap-reduce-motion')));
      await revealSheetContent(
        find.byKey(const Key('street-scrap-assisted-controls')),
      );
      await tester.tap(find.byKey(const Key('street-scrap-assisted-controls')));
      final saveSettings = find.byKey(const Key('street-scrap-save-settings'));
      await revealSheetContent(saveSettings);
      await tester.tap(saveSettings);
      await tester.pumpAndSettle();
      final savedSettings = Map<String, Object?>.from(
        session.snapshot.state['gameSettings']! as Map,
      );
      expect(savedSettings['reduceMotion'], isTrue);
      expect(savedSettings['assistedControls'], isTrue);
      expect(savedSettings['textScale'], 1.5);
      expect(savedSettings['soundVolume'], 40);
      expect(session.snapshot.revision, 12);
      final gameMediaQueries = tester
          .widgetList<MediaQuery>(
            find.ancestor(
              of: settingsButton,
              matching: find.byType(MediaQuery),
            ),
          )
          .toList();
      expect(
        gameMediaQueries.any(
          (media) =>
              (media.data.textScaler.scale(1) - 3).abs() < 0.001 &&
              media.data.disableAnimations,
        ),
        isTrue,
      );
      expect(
        renderingErrors,
        isEmpty,
        reason: renderingErrors.map((error) => error.toString()).join('\n'),
      );
      semanticsHandle.dispose();
      await session.close();
    },
  );

  testWidgets('locked woodworking preview is visible before optional tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StreetScrapSession(
      profileScope: 'woodworking-lock-first-layout',
      store: _MemoryProgressStore(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {},
      packingRules: const {},
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapInventoryPage(
              session: session,
              catalog: catalog,
              recipeCatalog: StreetScrapRecipeCatalog.fromRecipes(
                const [],
                expectedCount: 0,
              ),
              expeditionRules: expeditionRules,
              renewableSupplies:
                  StreetScrapRenewableSupplyCatalog.fromContentPayload(
                    '{"renewableSupplies":[{"item":"water.filtered","phase":0,"quantity":1,"stamina":2,"repeatable":true}]}',
                  ),
              maxStamina: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-nav-workshop')));
    await tester.pumpAndSettle();

    final lockedWorkshop = find.byKey(
      const Key('street-scrap-locked-woodworking'),
    );
    final navigation = tester.getRect(
      find.byKey(const Key('street-scrap-section-navigation')),
    );
    expect(lockedWorkshop, findsOneWidget);
    expect(
      tester.getRect(lockedWorkshop).bottom,
      lessThan(navigation.top),
      reason: 'The large unlock visual should be visible without scrolling.',
    );
    expect(find.text('接續你的進度'), findsNothing);
    expect(
      find.byKey(const Key('street-scrap-renewable-supplies')),
      findsOneWidget,
      reason: 'The public refill point must remain reachable before chapter 3.',
    );
    expect(
      find.byKey(const Key('street-scrap-inventory-scroll')),
      findsNothing,
      reason: 'The locked route remains separate from the full inventory list.',
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });
}

StreetScrapRecipeCatalog _testRecipeCatalog({bool manual = false}) =>
    StreetScrapRecipeCatalog.fromRecipes([
      for (var i = 0; i < 78; i++)
        StreetScrapRecipe(
          id: 'test.recipe.$i',
          phase: 0,
          station: 'workbench',
          operationId: 'strike',
          durationSeconds: 1,
          instructions: 'test',
          inputGroups: const [
            [StreetScrapRecipeInput(itemId: 'wood.chip', quantity: 1)],
          ],
          reusableTools: const [],
          outputs: const [
            StreetScrapRecipeInput(itemId: 'wood.chip', quantity: 1),
          ],
          quality: StreetScrapRecipeQualityRule(
            primaryInputs: const ['wood.chip'],
            loss: 0,
            mode: 'weighted-primary',
            masteryRevision: 1,
          ),
          retainedInputIds: const [],
          failureMode: 'reducedQualityOutput',
          failureOutcome: 'test failure',
          failureResolution: manual && i == 0
              ? const StreetScrapFailureResolution(
                  mode: 'sameOutputsQualityLoss',
                  qualityLoss: 10,
                )
              : null,
          manualCheckpoints: manual && i == 0
              ? [
                  for (var step = 0; step < 3; step++)
                    StreetScrapManualCheckpoint(
                      prompt: '操作步驟 ${step + 1}',
                      options: const ['錯誤', '正確', '失手'],
                      correctOption: 1,
                    ),
                ]
              : const [],
        ),
    ]);
