import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_supplies_panel.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_supplies.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_water.dart';

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
  'board': StreetScrapGridSpec(id: 'board', width: 4, height: 4),
  'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
};

final _inventoryCatalog = StreetScrapInventoryCatalog(
  footprints: const {
    'wood.chip': StreetScrapFootprint(1, 1),
    'container.clean': StreetScrapFootprint(1, 2),
    'container.clean_jar': StreetScrapFootprint(1, 2),
    'container.used_intact': StreetScrapFootprint(1, 2),
  },
  packingRules: const {},
);

StreetScrapRenewableSupplyCatalog _supplyCatalog() =>
    StreetScrapRenewableSupplyCatalog.fromContentPayload(
      jsonEncode({
        'renewableSupplies': [
          {
            'item': 'wood.chip',
            'phase': 0,
            'quantity': 3,
            'stamina': 3,
            'repeatable': true,
          },
          {
            'item': 'water.filtered',
            'phase': 0,
            'quantity': 1,
            'stamina': 2,
            'repeatable': true,
          },
        ],
      }),
    );

Future<StreetScrapSession> _session() async {
  final session = StreetScrapSession(
    profileScope: 'renewable-supplies',
    store: _Store(),
    contentVersions: const {'game.street-scrap.content.chapters-0-4': '0.1.26'},
    rulesetVersion: 1,
    clock: () => DateTime.utc(2026, 10, 24),
  );
  await session.load();
  final empty = _inventoryCatalog.emptyInventory(grids: _grids);
  await session.apply(
    commandId: 'setup-renewable-supplies',
    expectedRevision: 0,
    reduce: (_) => StreetScrapReduction(
      state: {'chapter': 0, 'stamina': 10, 'inventory': empty.toJson()},
    ),
  );
  return session;
}

void main() {
  test(
    'repeatable supply adds distinct sourced instances and spends stamina once',
    () async {
      final session = await _session();
      final result = await claimStreetScrapRenewableSupply(
        session: session,
        commandId: 'claim-wood-supply',
        expectedRevision: session.snapshot.revision,
        supplyCatalog: _supplyCatalog(),
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        backpackGridId: 'backpack',
        itemId: 'wood.chip',
        maxStamina: 10,
      );
      final inventory = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final chips = inventory.objects.values.toList(growable: false);
      expect(result.revision, 2);
      expect(session.snapshot.state['stamina'], 7);
      expect(chips, hasLength(3));
      expect(chips.map((item) => item.instanceId).toSet(), hasLength(3));
      expect(
        chips.every((item) => item.source == 'supply:renewable:wood.chip'),
        isTrue,
      );
      expect(chips.every((item) => item.acquiredRevision == 2), isTrue);
      await session.close();
    },
  );

  test(
    'filtered-water supply fills a selected clean jar without replacing it',
    () async {
      final session = await _session();
      var inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'clean-jar',
              itemId: 'container.clean_jar',
              source: 'fixed:container_corner',
              quality: 70,
              traits: const {},
              containerState: const {'cleanliness': 'clean'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'place-clean-jar',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': inventory.toJson()},
        ),
      );
      final result = await claimStreetScrapRenewableSupply(
        session: session,
        commandId: 'claim-filtered-water',
        expectedRevision: session.snapshot.revision,
        supplyCatalog: _supplyCatalog(),
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        backpackGridId: 'backpack',
        itemId: 'water.filtered',
        vesselInstanceId: 'clean-jar',
        maxStamina: 10,
      );
      inventory = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(result.revision, 3);
      expect(session.snapshot.state['stamina'], 8);
      expect(inventory.objects, hasLength(1));
      expect(inventory.objects['clean-jar']!.containerState, {
        'cleanliness': 'utility',
        'contentItemId': 'water.filtered',
        'contentQuality': 55,
        'contentSource': 'supply:renewable:water.filtered',
        'contentTraits': <String, Object?>{},
        'requiresBoiling': false,
      });
      expect(inventory.placements['clean-jar']!.gridId, 'backpack');
      await session.close();
    },
  );

  test(
    'public refill cleans a used empty vessel without another water bottle',
    () async {
      final session = await _session();
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'used-empty-bottle',
              itemId: 'container.used_intact',
              source: 'found:street',
              quality: 64,
              traits: const {'intact': true},
              containerState: const {
                'cleanliness': 'utility',
                'lastContentItemId': 'water.filtered',
              },
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'place-used-empty-bottle',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'stamina': 4, 'inventory': inventory.toJson()},
        ),
      );

      final result = await washStreetScrapVesselAtPublicRefill(
        session: session,
        commandId: 'wash-at-public-refill',
        expectedRevision: session.snapshot.revision,
        catalog: _inventoryCatalog,
        grids: _grids,
        vesselId: 'used-empty-bottle',
        maxStamina: 10,
      );
      final saved = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final bottle = saved.objects['used-empty-bottle']!;
      expect(result.result, {
        'vesselId': 'used-empty-bottle',
        'sourceId': 'public-refill',
        'staminaCost': 2,
      });
      expect(session.snapshot.state['stamina'], 2);
      expect(bottle.itemId, 'container.clean');
      expect(bottle.source, 'found:street');
      expect(bottle.quality, 64);
      expect(bottle.traits, {'intact': true});
      expect(bottle.containerState, {
        'cleanliness': 'clean',
        'lastContentItemId': 'water.filtered',
      });
      expect(bottle.provenance, hasLength(1));
      expect(bottle.provenance.single['kind'], 'transform');
      expect(bottle.provenance.single['sourceId'], 'public-refill');
      expect(saved.objects, hasLength(1));

      await claimStreetScrapRenewableSupply(
        session: session,
        commandId: 'refill-same-washed-bottle',
        expectedRevision: session.snapshot.revision,
        supplyCatalog: _supplyCatalog(),
        inventoryCatalog: _inventoryCatalog,
        grids: _grids,
        backpackGridId: 'backpack',
        itemId: 'water.filtered',
        vesselInstanceId: 'used-empty-bottle',
        maxStamina: 10,
      );
      final refilled = _inventoryCatalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(session.snapshot.state['stamina'], 0);
      expect(refilled.objects, hasLength(1));
      expect(
        refilled.objects['used-empty-bottle']!.containerState['contentItemId'],
        'water.filtered',
      );
      await session.close();
    },
  );

  test(
    'public refill washing failure leaves stamina and vessel unchanged',
    () async {
      final session = await _session();
      final inventory = _inventoryCatalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(
            _inventoryCatalog.createObject(
              instanceId: 'low-stamina-bottle',
              itemId: 'container.used_intact',
              source: 'found:street',
              quality: 55,
              traits: const {},
              containerState: const {'cleanliness': 'utility'},
            ),
            'backpack',
          );
      await session.apply(
        commandId: 'setup-low-stamina-bottle',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'stamina': 1, 'inventory': inventory.toJson()},
        ),
      );
      final before = session.snapshot.toJson();
      await expectLater(
        washStreetScrapVesselAtPublicRefill(
          session: session,
          commandId: 'wash-low-stamina-bottle',
          expectedRevision: session.snapshot.revision,
          catalog: _inventoryCatalog,
          grids: _grids,
          vesselId: 'low-stamina-bottle',
          maxStamina: 10,
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.toJson(), before);
      await session.close();
    },
  );

  test(
    'locked, unplaceable, or uncontained supply claims do not mutate saves',
    () async {
      final session = await _session();
      final supplies = StreetScrapRenewableSupplyCatalog([
        const StreetScrapRenewableSupply(
          itemId: 'wood.chip',
          phase: 1,
          quantity: 1,
          staminaCost: 3,
        ),
        const StreetScrapRenewableSupply(
          itemId: 'water.filtered',
          phase: 0,
          quantity: 1,
          staminaCost: 2,
        ),
      ]);
      final before = session.snapshot.toJson();
      await expectLater(
        claimStreetScrapRenewableSupply(
          session: session,
          commandId: 'locked-wood',
          expectedRevision: session.snapshot.revision,
          supplyCatalog: supplies,
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          backpackGridId: 'backpack',
          itemId: 'wood.chip',
          maxStamina: 10,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        claimStreetScrapRenewableSupply(
          session: session,
          commandId: 'water-without-vessel',
          expectedRevision: session.snapshot.revision,
          supplyCatalog: supplies,
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          backpackGridId: 'backpack',
          itemId: 'water.filtered',
          maxStamina: 10,
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.toJson(), before);
      await session.close();
    },
  );

  test(
    'full backpack rejects an entire repeatable supply without mutation',
    () async {
      final session = await _session();
      var inventory = _inventoryCatalog.emptyInventory(grids: _grids);
      for (var index = 0; index < 14; index++) {
        inventory = inventory.addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'occupied-$index',
            itemId: 'wood.chip',
            source: 'found:street',
            quality: 55,
            traits: const {},
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'setup-nearly-full-backpack',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': inventory.toJson()},
        ),
      );
      final before = session.snapshot.toJson();

      await expectLater(
        claimStreetScrapRenewableSupply(
          session: session,
          commandId: 'claim-wood-with-insufficient-space',
          expectedRevision: session.snapshot.revision,
          supplyCatalog: _supplyCatalog(),
          inventoryCatalog: _inventoryCatalog,
          grids: _grids,
          backpackGridId: 'backpack',
          itemId: 'wood.chip',
          maxStamina: 10,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'renewableSupplyNoBackpackSpace',
          ),
        ),
      );
      expect(session.snapshot.toJson(), before);
      await session.close();
    },
  );

  testWidgets('supply panel confirms and collects a repeatable item', (
    tester,
  ) async {
    final session = await _session();
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapRenewableSuppliesPanel(
              session: session,
              catalog: _supplyCatalog(),
              inventoryCatalog: _inventoryCatalog,
              grids: _grids,
              maxStamina: 10,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('street-scrap-renewable-supplies')));
    await tester.pumpAndSettle();
    final woodSupply = find.byKey(const ValueKey('renewable-supply-wood.chip'));
    expect(woodSupply, findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('renewable-supply-action-wood.chip')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('renewable-supply-action-wood.chip')),
    );
    await tester.pumpAndSettle();
    expect(find.text('確認取得補給'), findsOneWidget);
    expect(find.text('取得 碎木片 ×3，消耗體力 3。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '前往取得').last);
    await tester.pumpAndSettle();

    expect(session.snapshot.state['stamina'], 7);
    final inventory = _inventoryCatalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(inventory.objects.values, hasLength(3));
    expect(inventory.placements.values, everyElement(isNotNull));
    await session.close();
  });

  testWidgets('full-backpack supply error opens the material workspace', (
    tester,
  ) async {
    final session = await _session();
    var inventory = _inventoryCatalog.emptyInventory(grids: _grids);
    for (var index = 0; index < 14; index++) {
      inventory = inventory.addAndPlaceFirstFit(
        _inventoryCatalog.createObject(
          instanceId: 'workspace-occupied-$index',
          itemId: 'wood.chip',
          source: 'found:street',
          quality: 55,
          traits: const {},
        ),
        'backpack',
      );
    }
    await session.apply(
      commandId: 'setup-workspace-full-backpack',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'inventory': inventory.toJson()},
      ),
    );
    var organizePressed = false;
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapRenewableSuppliesPanel(
              session: session,
              catalog: _supplyCatalog(),
              inventoryCatalog: _inventoryCatalog,
              grids: _grids,
              maxStamina: 10,
              onOrganize: () => organizePressed = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('street-scrap-renewable-supplies')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('renewable-supply-action-wood.chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '前往取得').last);
    await tester.pumpAndSettle();

    expect(find.text('背包放不下這批補給；先移幾件到工作棋盤或箱櫃。'), findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, '整理'));
    expect(organizePressed, isTrue);
    await session.close();
  });

  testWidgets('supply panel exposes public-tap washing for used bottles', (
    tester,
  ) async {
    final session = await _session();
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'panel-used-bottle',
            itemId: 'container.used_intact',
            source: 'found:street',
            quality: 55,
            traits: const {},
            containerState: const {'cleanliness': 'utility'},
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'panel-used-bottle-setup',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'inventory': inventory.toJson()},
      ),
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapRenewableSuppliesPanel(
              session: session,
              catalog: _supplyCatalog(),
              inventoryCatalog: _inventoryCatalog,
              grids: _grids,
              maxStamina: 10,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('street-scrap-renewable-supplies')));
    await tester.pumpAndSettle();
    final washButton = find.byKey(
      const ValueKey('public-refill-wash-panel-used-bottle'),
    );
    expect(washButton, findsOneWidget);
    await tester.tap(washButton);
    await tester.pumpAndSettle();
    expect(find.text('使用公共水槽清洗，不消耗瓶中水；消耗體力 2。'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '清洗・2 體力'),
      ),
    );
    await tester.pumpAndSettle();

    final saved = _inventoryCatalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(session.snapshot.state['stamina'], 8);
    expect(
      saved.objects['panel-used-bottle']!.containerState['cleanliness'],
      'clean',
    );
    expect(find.text('空瓶已清洗，可再次裝水。'), findsOneWidget);
    await session.close();
  });

  testWidgets('public tap fills filtered water without a renewable item row', (
    tester,
  ) async {
    final session = await _session();
    final inventory = _inventoryCatalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(
          _inventoryCatalog.createObject(
            instanceId: 'tap-fill-bottle',
            itemId: 'container.clean',
            source: 'tutorial:starting-vessel',
            quality: 55,
            traits: const {},
            containerState: const {'cleanliness': 'clean'},
          ),
          'backpack',
        );
    await session.apply(
      commandId: 'tap-fill-bottle-setup',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'stamina': 4, 'inventory': inventory.toJson()},
      ),
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'zh-Hant',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapRenewableSuppliesPanel(
              session: session,
              catalog: _supplyCatalog(),
              inventoryCatalog: _inventoryCatalog,
              grids: _grids,
              maxStamina: 10,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('street-scrap-renewable-supplies')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('renewable-supply-water.filtered')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('renewable-supply-wood.chip')),
      findsOneWidget,
    );
    final fillButton = find.byKey(
      const ValueKey('public-refill-fill-tap-fill-bottle'),
    );
    expect(fillButton, findsOneWidget);
    await tester.tap(fillButton);
    await tester.pumpAndSettle();
    expect(find.text('使用公共補水點裝水，消耗體力 2。'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '裝水・2 體力'),
      ),
    );
    await tester.pumpAndSettle();

    final saved = _inventoryCatalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(session.snapshot.state['chapter'], 0);
    expect(session.snapshot.state['stamina'], 2);
    expect(
      saved.objects['tap-fill-bottle']!.containerState['contentItemId'],
      'water.filtered',
    );
    expect(find.text('已裝入過濾水，容器仍可重複使用。'), findsOneWidget);
    await session.close();
  });
}
