import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_crafting.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_fishing.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_woodworking.dart';

StreetScrapExpeditionRules rules({
  Map<String, Object?>? phaseSurprisePools,
  Map<int, Map<String, List<String>>>? typedPhaseSurprisePools,
}) => StreetScrapExpeditionRules.fromJson({
  'nodeCount': 3,
  'investigationsPerNode': 1,
  'movementCost': 1,
  'investigationCost': 2,
  'fixedWrongQuantity': 1,
  'fixedLocations': [
    {
      'id': 'clothing',
      'phase': 0,
      'options': [
        {'item': 'cloth.rag_piece', 'quantity': 3},
      ],
    },
    {
      'id': 'wood',
      'phase': 0,
      'options': [
        {'item': 'wood.chip', 'quantity': 3},
      ],
    },
    {
      'id': 'container',
      'phase': 0,
      'options': [
        {'item': 'container.used_intact', 'quantity': 1},
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
    'intactBase': ['cloth.thread_spool'],
    'containers': ['wood.chip'],
    'optionalSpecial': [],
  },
  if (typedPhaseSurprisePools != null)
    'phaseSurprisePools': {
      for (final entry in typedPhaseSurprisePools.entries)
        '${entry.key}': entry.value,
    }
  else 'phaseSurprisePools': ?phaseSurprisePools,
  'surpriseTraitPools': {
    'positive': [
      {'prefix': 'cloth.', 'id': 'intact_fibre', 'minimumQuality': 70},
    ],
    'negative': [
      {'prefix': 'cloth.', 'id': 'frayed'},
      {'prefix': 'wood.', 'id': 'cracked'},
      {'prefix': 'metal.', 'id': 'rusted'},
    ],
    'chancePercent': 20,
  },
  'scrapQualities': [30, 55],
  'intactQualities': [55, 80, 95],
});

class MemoryStore implements StreetScrapProgressStore {
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

void main() {
  test(
    'phase-zero starter bottles are granted once as an atomic pair',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'phase-zero-starter-bottles',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'container.used_intact': StreetScrapFootprint(1, 2)},
        packingRules: const {},
      );

      await claimStreetScrapStarterVessels(
        session: session,
        commandId: 'claim-starter-vessels',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );

      final inventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(inventory.objects, hasLength(2));
      expect(
        inventory.objects.values.every(
          (item) =>
              item.itemId == 'container.used_intact' &&
              item.source == 'tutorial:q0-starter-vessels' &&
              item.containerState['cleanliness'] == 'soiled',
        ),
        isTrue,
      );
      expect(
        inventory.placements.values.every(
          (placement) => placement.gridId == 'backpack',
        ),
        isTrue,
      );
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q0.vesselsClaimed'],
        isTrue,
      );

      final beforeDuplicate = session.snapshot.toJson();
      await expectLater(
        claimStreetScrapStarterVessels(
          session: session,
          commandId: 'claim-starter-vessels-again',
          expectedRevision: session.snapshot.revision,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsA(isA<StateError>()),
      );
      expect(session.snapshot.toJson(), beforeDuplicate);
      await session.close();
    },
  );

  test(
    'phase-zero starter bottles do not partially fill a cramped backpack',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'phase-zero-starter-bottles-no-space',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
      );
      await session.load();
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 1, height: 2),
      };
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'container.used_intact': StreetScrapFootprint(1, 2)},
        packingRules: const {},
      );
      final before = session.snapshot.toJson();

      await expectLater(
        claimStreetScrapStarterVessels(
          session: session,
          commandId: 'claim-starter-vessels-no-space',
          expectedRevision: session.snapshot.revision,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsA(isA<StateError>()),
      );

      expect(session.snapshot.toJson(), before);
      await session.close();
    },
  );

  test('scavenged clean jars retain usable vessel state', () async {
    final store = MemoryStore();
    final session = StreetScrapSession(
      profileScope: 'scavenged-clean-vessel',
      store: store,
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.0',
      },
      rulesetVersion: 1,
      clock: () => DateTime.utc(2026, 10, 24),
    );
    await session.load();
    const grids = {
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 2, height: 2),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {
        'container.clean_jar': StreetScrapFootprint(1, 1),
        'container.used_intact': StreetScrapFootprint(1, 1),
      },
      packingRules: const {},
    );
    final routeRules = StreetScrapExpeditionRules.fromJson({
      'nodeCount': 3,
      'investigationsPerNode': 1,
      'movementCost': 1,
      'investigationCost': 2,
      'fixedWrongQuantity': 1,
      'fixedLocations': [
        for (var node = 0; node < 3; node++)
          {
            'id': 'container-alley-$node',
            'phase': 0,
            'nodeIndex': node,
            'options': [
              {
                'item': node == 1
                    ? 'container.used_intact'
                    : 'container.clean_jar',
                'quantity': 1,
              },
            ],
          },
      ],
      'surpriseWeights': rules().surpriseWeights,
      'surprisePools': rules().surprisePools,
      'surpriseTraitPools': {
        'positive': [],
        'negative': [],
        'chancePercent': 0,
      },
      'scrapQualities': [30, 55],
      'intactQualities': [55, 80],
    });
    final expedition = StreetScrapExpedition.start(
      id: 'clean-jar-trip',
      phase: 0,
      seed: 4,
      stamina: 10,
      rules: routeRules,
    );
    var active = expedition
        .investigateFixed(
          rules: routeRules,
          optionIndex: 0,
          selectedVisibleTarget: true,
        )
        .expedition;
    active = active.move(routeRules);
    active = active
        .investigateFixed(
          rules: routeRules,
          optionIndex: 0,
          selectedVisibleTarget: true,
        )
        .expedition
        .returnHome();
    await session.apply(
      commandId: 'seed-clean-jar-trip',
      expectedRevision: 0,
      reduce: (_) => StreetScrapReduction(
        state: {
          'chapter': 0,
          'stamina': 10,
          'inventory': catalog.emptyInventory(grids: grids).toJson(),
          'expedition': active.toJson(),
        },
      ),
    );
    await claimStreetScrapExpeditionRewards(
      session: session,
      commandId: 'claim-clean-jar',
      expectedRevision: session.snapshot.revision,
      rules: routeRules,
      catalog: catalog,
      grids: grids,
      backpackGridId: 'backpack',
    );
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    final jar = inventory.objects.values.singleWhere(
      (item) => item.itemId == 'container.clean_jar',
    );
    final oldBottle = inventory.objects.values.singleWhere(
      (item) => item.itemId == 'container.used_intact',
    );
    expect(jar.itemId, 'container.clean_jar');
    expect(jar.containerState['cleanliness'], 'clean');
    expect(oldBottle.containerState['cleanliness'], 'soiled');
    await fillStreetScrapVessel(
      session: session,
      commandId: 'fill-recovered-clean-jar',
      expectedRevision: session.snapshot.revision,
      catalog: catalog,
      grids: grids,
      vesselId: jar.instanceId,
      sourceId: 'public-refill',
      maxStamina: 10,
    );
    final filled = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(filled.objects, hasLength(2));
    expect(
      filled.objects[jar.instanceId]!.containerState['contentItemId'],
      'water.filtered',
    );
    expect(filled.placements[jar.instanceId]!.gridId, 'backpack');
    expect(
      filled.placements[jar.instanceId]!.x,
      inventory.placements[jar.instanceId]!.x,
    );
    expect(
      filled.placements[jar.instanceId]!.y,
      inventory.placements[jar.instanceId]!.y,
    );
    final beforeRejectedFill = session.snapshot.toJson();
    await expectLater(
      fillStreetScrapVessel(
        session: session,
        commandId: 'refill-unwashed-old-bottle',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        vesselId: oldBottle.instanceId,
        sourceId: 'public-refill',
        maxStamina: 10,
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.toJson(), beforeRejectedFill);
    await session.close();
  });

  test(
    'one investigation per node, movement and investigation spend stamina',
    () {
      final routeRules = rules();
      var route = StreetScrapExpedition.start(
        id: 'trip-1',
        phase: 0,
        seed: 4,
        stamina: 9,
        rules: routeRules,
      );
      final fixed = route.investigateFixed(
        rules: routeRules,
        optionIndex: 0,
        selectedVisibleTarget: true,
      );
      route = fixed.expedition;
      expect(route.stamina, 6);
      expect(fixed.reward['quantity'], 3);
      expect(
        () => route.investigateFixed(
          rules: routeRules,
          optionIndex: 0,
          selectedVisibleTarget: true,
        ),
        throwsStateError,
      );
      route = route.move(routeRules);
      final surprise = route.investigateSurprise(routeRules);
      route = surprise.expedition.move(routeRules);
      final third = route.investigateFixed(
        rules: routeRules,
        optionIndex: 0,
        selectedVisibleTarget: false,
      );
      expect(third.reward['quantity'], 1);
      expect(third.expedition.investigated, [0, 1, 2]);
      expect(() => third.expedition.move(routeRules), throwsStateError);
    },
  );

  test(
    'phase-one third node selects the fixed rack and marks its item as intact provenance',
    () {
      final base = rules();
      final routeRules = StreetScrapExpeditionRules(
        nodeCount: base.nodeCount,
        investigationsPerNode: base.investigationsPerNode,
        movementCost: base.movementCost,
        investigationCost: base.investigationCost,
        fixedWrongQuantity: base.fixedWrongQuantity,
        fixedLocations: [
          ...base.fixedLocations,
          const StreetScrapFixedLocation(
            id: 'metal_recycling_rack',
            label: '金屬回收架',
            nodeIndex: 2,
            phase: 1,
            options: [
              StreetScrapFixedOption(
                itemId: 'metal.sheet',
                quantity: 1,
                label: '完整金屬片',
                qualityType: 'intact',
              ),
            ],
          ),
        ],
        surprisePools: base.surprisePools,
        surpriseWeights: base.surpriseWeights,
        surpriseTraitPools: base.surpriseTraitPools,
        surpriseTraitChancePercent: base.surpriseTraitChancePercent,
        scrapQualities: base.scrapQualities,
        intactQualities: base.intactQualities,
      );
      final route = StreetScrapExpedition.start(
        id: 'phase-one-rack',
        phase: 1,
        seed: 55,
        stamina: 9,
        rules: routeRules,
      ).move(routeRules).move(routeRules);
      final investigation = route.investigateFixed(
        rules: routeRules,
        optionIndex: 0,
        selectedVisibleTarget: true,
      );
      expect(investigation.reward['itemId'], 'metal.sheet');
      expect(investigation.reward['source'], 'fixed:metal_recycling_rack');
      expect(investigation.reward['quality'], isIn(routeRules.intactQualities));
    },
  );

  test(
    'surprise provenance traits are deterministic, material-scoped and saved',
    () {
      final routeRules = rules();
      final found = <String>{};
      for (var seed = 1; seed <= 500; seed++) {
        final route = StreetScrapExpedition.start(
          id: 'trait-seed-$seed',
          phase: 0,
          seed: seed,
          stamina: 9,
          rules: routeRules,
        );
        final result = route.investigateSurprise(routeRules);
        final traits = Map<String, Object?>.from(
          result.reward['traits'] as Map? ?? const {},
        );
        final itemId = result.reward['itemId'] as String;
        expect(
          traits.keys.toSet().difference({
            'intact_fibre',
            'frayed',
            'cracked',
            'damp',
          }),
          isEmpty,
        );
        if (traits.containsKey('intact_fibre')) {
          expect(itemId, startsWith('cloth.'));
          expect(result.reward['quality'], greaterThanOrEqualTo(70));
          expect(traits['intact_fibre'], isTrue);
        }
        if (traits.containsKey('frayed')) {
          expect(itemId, startsWith('cloth.'));
          expect(traits['frayed'], isTrue);
        }
        if (traits.containsKey('cracked')) {
          expect(itemId, startsWith('wood.'));
          expect(traits['cracked'], isTrue);
        }
        found.addAll(traits.keys);
        expect(result.expedition.drawIndex, 7);
        final reopened = StreetScrapExpedition.fromJson(
          result.expedition.toJson(),
        );
        expect(reopened.pendingRewards.single, result.reward);
      }
      expect(found, containsAll(['intact_fibre', 'frayed', 'cracked']));
    },
  );

  test('phase-one metal surprise can carry the configured rusted trait', () {
    final base = rules();
    final phasePools = <int, Map<String, List<String>>>{
      for (var phase = 0; phase <= 5; phase++)
        phase: {
          for (final category in base.surpriseWeights.keys)
            category: phase == 0
                ? base.surprisePools[category]!
                : const ['metal.scrap'],
        },
    };
    final routeRules = rules(typedPhaseSurprisePools: phasePools);
    var foundRusted = false;
    for (var seed = 1; seed <= 500 && !foundRusted; seed++) {
      final route = StreetScrapExpedition.start(
        id: 'rusted-seed-$seed',
        phase: 1,
        seed: seed,
        stamina: 9,
        rules: routeRules,
      );
      final reward = route.investigateSurprise(routeRules).reward;
      expect(reward['itemId'], 'metal.scrap');
      final traits = Map<String, Object?>.from(
        reward['traits'] as Map? ?? const {},
      );
      if (traits.containsKey('rusted')) {
        expect(traits['rusted'], isTrue);
        foundRusted = true;
      }
    }
    expect(foundRusted, isTrue);
  });

  test(
    'legacy saved scavenging polarity traits migrate to canonical trait IDs',
    () {
      final routeRules = rules();
      final route = StreetScrapExpedition.start(
        id: 'legacy-trait-save',
        phase: 0,
        seed: 1,
        stamina: 3,
        rules: routeRules,
      ).investigateSurprise(routeRules).expedition;
      final legacyJson = Map<String, Object?>.from(route.toJson());
      final rewards = (legacyJson['pendingRewards'] as List)
          .map((reward) => Map<String, Object?>.from(reward as Map))
          .toList();
      rewards.single['traits'] = const {
        'positive': 'intact_fibre',
        'negative': 'frayed',
      };
      legacyJson['pendingRewards'] = rewards;

      final reopened = StreetScrapExpedition.fromJson(legacyJson);
      expect(reopened.pendingRewards.single['traits'], {
        'intact_fibre': true,
        'frayed': true,
      });
    },
  );

  test('fixed scavenging supplies never roll surprise provenance traits', () {
    final routeRules = rules();
    final route = StreetScrapExpedition.start(
      id: 'fixed-no-trait',
      phase: 0,
      seed: 3,
      stamina: 9,
      rules: routeRules,
    );
    final result = route.investigateFixed(
      rules: routeRules,
      optionIndex: 0,
      selectedVisibleTarget: true,
    );
    expect(result.reward.containsKey('traits'), isFalse);
  });

  test('surprise pools use the expedition phase and keep fixed draw slots', () {
    final phasePools = <String, Object?>{
      for (var phase = 0; phase < 6; phase++)
        '$phase': {
          'commonScraps': [phase == 0 ? 'cloth.rag_piece' : 'metal.scrap'],
          'intactBase': [phase == 0 ? 'cloth.rag_piece' : 'metal.scrap'],
          'containers': [phase == 0 ? 'cloth.rag_piece' : 'metal.scrap'],
          'optionalSpecial': <String>[],
        },
    };
    final routeRules = rules(phaseSurprisePools: phasePools);
    final early = StreetScrapExpedition.start(
      id: 'phase-pool-early',
      phase: 0,
      seed: 19,
      stamina: 3,
      rules: routeRules,
    ).investigateSurprise(routeRules);
    final later = StreetScrapExpedition.start(
      id: 'phase-pool-later',
      phase: 1,
      seed: 19,
      stamina: 3,
      rules: routeRules,
    ).investigateSurprise(routeRules);

    expect(early.reward['itemId'], 'cloth.rag_piece');
    expect(later.reward['itemId'], 'metal.scrap');
    expect(early.expedition.drawIndex, 7);
    expect(later.expedition.drawIndex, 7);
  });

  test(
    'return is free and serializing/reopening never rerolls a pending reward',
    () {
      final routeRules = rules();
      final started = StreetScrapExpedition.start(
        id: 'trip-2',
        phase: 0,
        seed: 987,
        stamina: 3,
        rules: routeRules,
      );
      final found = started.investigateSurprise(routeRules).expedition;
      final reopened = StreetScrapExpedition.fromJson(found.toJson());
      expect(reopened.pendingRewards, found.pendingRewards);
      expect(reopened.drawIndex, found.drawIndex);
      final returned = reopened.returnHome();
      expect(returned.stamina, 0);
      expect(returned.claimed, isFalse);
      expect(() => returned.investigateSurprise(routeRules), throwsStateError);
    },
  );

  test(
    'expedition transition is saved with session CAS and receipt replay',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'trip-save',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final routeRules = rules();
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'start-trip',
        expectedRevision: 0,
        rules: routeRules,
        transition: (_) => StreetScrapExpedition.start(
          id: 'trip-3',
          phase: 0,
          seed: 13,
          stamina: 3,
          rules: routeRules,
        ),
      );
      final result = await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'survey-trip',
        expectedRevision: 1,
        rules: routeRules,
        transition: (current) =>
            current!.investigateSurprise(routeRules).expedition,
      );
      final replay = await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'survey-trip',
        expectedRevision: 1,
        rules: routeRules,
        transition: (_) => throw StateError('must not reroll'),
      );
      expect(replay.wasDuplicate, isTrue);
      expect(replay.result, result.result);
      final restored = StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(
          Map<String, Object?>.from(
            session.snapshot.state['expedition']! as Map,
          ),
        ),
      );
      expect(restored.pendingRewards, isNotEmpty);
      expect(restored.stamina, 0);
      await session.close();
    },
  );

  test(
    'claim atomically places returned rewards into backpack and is idempotent',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'trip-claim',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final routeRules = rules();
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'claim-start',
        expectedRevision: 0,
        rules: routeRules,
        transition: (_) => StreetScrapExpedition.start(
          id: 'claim-trip',
          phase: 0,
          seed: 19,
          stamina: 3,
          rules: routeRules,
        ),
      );
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'claim-search',
        expectedRevision: 1,
        rules: routeRules,
        transition: (current) => current!
            .investigateFixed(
              rules: routeRules,
              optionIndex: 0,
              selectedVisibleTarget: true,
            )
            .expedition,
      );
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'claim-return',
        expectedRevision: 2,
        rules: routeRules,
        transition: (current) => current!.returnHome(),
      );
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'cloth.rag_piece': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final claimed = await claimStreetScrapExpeditionRewards(
        session: session,
        commandId: 'claim-rewards',
        expectedRevision: 3,
        rules: routeRules,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      expect(claimed.result, {
        'claimedObjects': 3,
        'filledVessels': <String>[],
      });
      final tutorial = session.snapshot.state['tutorialTasks']! as Map;
      expect(tutorial['q0.01'], isTrue);
      expect(tutorial['q0.02'], isTrue);
      final inventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(inventory.objects.length, 3);
      expect(
        inventory.objects.values.every(
          (item) => item.acquiredRevision == claimed.revision,
        ),
        isTrue,
      );
      expect(inventory.placements.length, 3);
      final duplicate = await claimStreetScrapExpeditionRewards(
        session: session,
        commandId: 'claim-rewards',
        expectedRevision: 3,
        rules: routeRules,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      expect(duplicate.wasDuplicate, isTrue);
      await session.close();
    },
  );

  test(
    'fresh novice save completes chapters 0 to 4 with a real craft miss',
    () async {
      final store = MemoryStore();
      final profileScope = 'fresh-novice-journey-q0-to-q2';
      final contentFile = File(
        'resources/data/street-scrap-content-v1.json',
      );
      expect(contentFile.existsSync(), isTrue);
      final contentSource = await contentFile.readAsString();
      final contentPayload = jsonDecode(contentSource) as Map<String, dynamic>;
      final contentVersions = {
        contentPayload['packId'] as String:
            contentPayload['packVersion'] as String,
      };
      final session = StreetScrapSession(
        profileScope: profileScope,
        store: store,
        contentVersions: contentVersions,
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 26),
      );
      await session.load();
      expect(session.snapshot.revision, 0);
      expect(session.snapshot.state, isEmpty);
      var activeSession = session;

      final catalog = StreetScrapInventoryCatalog.fromContentPayload(
        contentSource,
      );
      final recipeCatalog = StreetScrapRecipeCatalog.fromContentPayload(
        contentSource,
      );
      const grids = {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final routeRules = StreetScrapExpeditionRules.fromJson(
        Map<String, Object?>.from(contentPayload['scavenging']! as Map),
      );

      Future<void> routeCommand(
        String commandId,
        StreetScrapExpedition Function(StreetScrapExpedition?) transition,
      ) async {
        await applyStreetScrapExpeditionCommand(
          session: session,
          commandId: commandId,
          expectedRevision: session.snapshot.revision,
          rules: routeRules,
          transition: transition,
        );
      }

      Future<void> craftProductionRecipe(
        String recipeId, {
        required String commandId,
        required String gridId,
        required List<String> inputs,
        List<String> tools = const [],
        int groupIndex = 0,
      }) async {
        final craftInventory = catalog.inventoryFromJson(
          grids: grids,
          json: Map<String, Object?>.from(
            activeSession.snapshot.state['inventory']! as Map,
          ),
        );
        for (final instanceId in inputs) {
          expect(
            craftInventory.placements[instanceId]?.gridId,
            gridId,
            reason: '$recipeId input $instanceId must be carried on one grid',
          );
        }
        await StreetScrapCrafting.craft(
          session: activeSession,
          inventoryCatalog: catalog,
          recipe: recipeCatalog[recipeId]!,
          grids: grids,
          gridId: gridId,
          inputGroupIndex: groupIndex,
          inputInstanceIds: inputs,
          toolInstanceIds: tools,
          commandId: commandId,
          expectedRevision: activeSession.snapshot.revision,
          manual: true,
          manualPoints: 3,
          outputInstanceId: (index) => '$commandId-output-$index',
        );
      }

      // Chapter 0: enter the first node, collect its fixed cloth source,
      // return for free, claim the saved rewards, and deliver two rags.
      await startStreetScrapExpeditionCommand(
        session: session,
        commandId: 'journey-q0-start',
        expectedRevision: session.snapshot.revision,
        phase: 0,
        seed: 19,
        defaultStamina: 60,
        rules: routeRules,
      );
      await routeCommand(
        'journey-q0-search-cloth',
        (current) => current!
            .investigateFixed(
              rules: routeRules,
              optionIndex: 0,
              selectedVisibleTarget: true,
            )
            .expedition,
      );
      await routeCommand(
        'journey-q0-return',
        (current) => current!.returnHome(),
      );
      await claimStreetScrapExpeditionRewards(
        session: session,
        commandId: 'journey-q0-claim',
        expectedRevision: session.snapshot.revision,
        rules: routeRules,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      await deliverStreetScrapTutorialMaterials(
        session: session,
        commandId: 'journey-q0-deliver',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
        eligibleItemIds: const ['cloth.rag_piece'],
        quantity: 2,
      );
      expect(session.snapshot.state['chapter'], 1);

      // Chapter 1: take the real four-sample teaching grant and classify each
      // sample, then claim the one-time sewing supplies unlocked by q1.01.
      await claimStreetScrapRecyclingSamples(
        session: session,
        commandId: 'journey-q1-claim-samples',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      const samples = {
        'q1-sample-paper': ('paper.scrap', 'paper'),
        'q1-sample-metal': ('metal.scrap', 'metal'),
        'q1-sample-cloth': ('cloth.rag_piece', 'cloth'),
        'q1-sample-plastic': ('plastic.scrap', 'plastic'),
      };
      for (final entry in samples.entries) {
        await classifyStreetScrapRecyclingSample(
          session: session,
          commandId: 'journey-classify-${entry.key}',
          expectedRevision: session.snapshot.revision,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
          instanceId: entry.key,
          category: entry.value.$2,
        );
      }
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q1.01'],
        isTrue,
      );
      await claimStreetScrapSewingTutorialKit(
        session: session,
        commandId: 'journey-q1-claim-sewing-kit',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );

      final unpick = recipeCatalog['ss.recipe.unpick_cloth']!;
      final joinThread = recipeCatalog['ss.recipe.join_thread']!;
      final sew = recipeCatalog['ss.recipe.sew_strip']!;

      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: unpick,
        grids: grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: const ['expedition-journey-q0-start:reward:0:2'],
        toolInstanceIds: const ['q1-kit-needle'],
        commandId: 'journey-q1-unpick',
        expectedRevision: session.snapshot.revision,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'journey-unpick-$index',
      );
      await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: joinThread,
        grids: grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: const [
          'journey-unpick-1',
          'journey-unpick-2',
          'q1-kit-thread',
        ],
        toolInstanceIds: const [],
        commandId: 'journey-q1-join-thread',
        expectedRevision: session.snapshot.revision,
        manual: false,
        manualPoints: 0,
        outputInstanceId: (index) => 'journey-thread-spool-$index',
      );
      final missedSew = await StreetScrapCrafting.craft(
        session: session,
        inventoryCatalog: catalog,
        recipe: sew,
        grids: grids,
        gridId: 'backpack',
        inputGroupIndex: 0,
        inputInstanceIds: const [
          'q1-sample-cloth',
          'q1-kit-rag',
          'journey-thread-spool-0',
        ],
        toolInstanceIds: const ['q1-kit-needle'],
        commandId: 'journey-q1-sew-missed',
        expectedRevision: session.snapshot.revision,
        manual: true,
        manualPoints: 0,
        outputInstanceId: (index) => 'journey-repair-strip-$index',
      );
      expect((missedSew.result as Map)['succeeded'], isFalse);
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q1.02'],
        isTrue,
      );

      // q1.03 must use the actual phase-1 fixed rack, not a seeded board item.
      await startStreetScrapExpeditionCommand(
        session: session,
        commandId: 'journey-q1-rack-start',
        expectedRevision: session.snapshot.revision,
        phase: 1,
        seed: 23,
        defaultStamina: 60,
        rules: routeRules,
      );
      await routeCommand(
        'journey-q1-rack-move-1',
        (current) => current!.move(routeRules),
      );
      await routeCommand(
        'journey-q1-rack-move-2',
        (current) => current!.move(routeRules),
      );
      await routeCommand(
        'journey-q1-rack-search',
        (current) => current!
            .investigateFixed(
              rules: routeRules,
              optionIndex: 4,
              selectedVisibleTarget: true,
            )
            .expedition,
      );
      await routeCommand(
        'journey-q1-rack-return',
        (current) => current!.returnHome(),
      );
      await claimStreetScrapExpeditionRewards(
        session: session,
        commandId: 'journey-q1-rack-claim',
        expectedRevision: session.snapshot.revision,
        rules: routeRules,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      const rackInstanceId = 'expedition-journey-q1-rack-start:reward:0:0';
      final rackItemBeforeChoice = catalog
          .inventoryFromJson(
            grids: grids,
            json: Map<String, Object?>.from(
              session.snapshot.state['inventory']! as Map,
            ),
          )
          .objects[rackInstanceId]!;
      expect(rackItemBeforeChoice.source, 'fixed:metal_recycling_rack');
      await chooseStreetScrapIntactMaterial(
        session: session,
        commandId: 'journey-q1-keep-rack-sheet',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        instanceId: rackInstanceId,
        choice: 'keep',
      );
      expect(session.snapshot.state['chapter'], 2);

      final tasks = Map<String, Object?>.from(
        session.snapshot.state['tutorialTasks']! as Map,
      );
      expect(tasks['q0.01'], isTrue);
      expect(tasks['q0.02'], isTrue);
      expect(tasks['q0.03'], isTrue);
      expect(tasks['q1.01'], isTrue);
      expect(tasks['q1.02.unpicked'], isTrue);
      expect(tasks['q1.02.threadReady'], isTrue);
      expect(tasks['q1.02.sewn'], isTrue);
      expect(tasks['q1.02'], isTrue);
      expect(tasks['q1.03'], isTrue);
      final finalInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        finalInventory.objects['journey-repair-strip-0']!.quality,
        lessThan(55),
      );
      expect(
        finalInventory.objects[rackInstanceId]!.source,
        'fixed:metal_recycling_rack',
      );
      expect(finalInventory.objects[rackInstanceId]!.itemId, 'metal.sheet');

      // Chapter 2: use the unlocked dock, free natural bait and loaner rod,
      // resolve the saved signals, claim the fish and keep its identity.
      final fishingRules = StreetScrapFishingRules.fromJson(
        Map<String, Object?>.from(contentPayload['fishing']! as Map),
      );
      await castStreetScrapLine(
        session: session,
        commandId: 'journey-q2-cast',
        expectedRevision: session.snapshot.revision,
        rules: fishingRules,
        spotId: 'dock_entrance',
        defaultStamina: 60,
      );
      for (var signal = 1; signal <= fishingRules.signalsPerCast; signal++) {
        await resolveStreetScrapFishingSignal(
          session: session,
          commandId: 'journey-q2-signal-$signal',
          expectedRevision: session.snapshot.revision,
          rules: fishingRules,
          heldMilliseconds: fishingRules.signalHoldMilliseconds,
        );
      }
      expect(
        (session.snapshot.state['fishingPendingResult']! as Map)['kind'],
        'fish',
      );
      await claimStreetScrapFishingResult(
        session: session,
        commandId: 'journey-q2-claim-fish',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      await keepStreetScrapWholeFish(
        session: session,
        commandId: 'journey-q2-keep-fish',
        expectedRevision: session.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      expect(session.snapshot.state['chapter'], 3);
      final completedTasks = Map<String, Object?>.from(
        session.snapshot.state['tutorialTasks']! as Map,
      );
      expect(completedTasks['q2.01'], isTrue);
      expect(completedTasks['q2.02'], isTrue);
      expect(completedTasks['q2.03'], isTrue);

      await session.close();
      final reopened = StreetScrapSession(
        profileScope: profileScope,
        store: store,
        contentVersions: contentVersions,
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 26),
      );
      await reopened.load();
      expect(reopened.snapshot.state['chapter'], 3);
      expect(reopened.snapshot.state['tutorialTasks'], completedTasks);
      activeSession = reopened;

      // Chapter 3: process the tutorial kit through the production recipes,
      // repair the same crowbar, then make and use a real storage crate.
      await claimStreetScrapWoodPressKit(
        session: reopened,
        commandId: 'journey-q3-claim-press-kit',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      await craftProductionRecipe(
        'ss.recipe.press_rod',
        commandId: 'journey-q3-press-rod',
        gridId: 'backpack',
        inputs: const [
          'q301-chip-0',
          'q301-chip-1',
          'q301-chip-2',
          'q301-adhesive',
        ],
      );
      await claimStreetScrapNailBoardKit(
        session: reopened,
        commandId: 'journey-q3-claim-nails',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      var chapterThreeInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      final rodIds = chapterThreeInventory.objects.values
          .where((item) => item.itemId == 'wood.rod')
          .map((item) => item.instanceId)
          .toList(growable: false);
      expect(rodIds, hasLength(3));
      final nailId = chapterThreeInventory.objects.values
          .singleWhere((item) => item.itemId == 'metal.nail_bundle')
          .instanceId;
      final nailGrid = chapterThreeInventory.placements[rodIds.first]!.gridId;
      expect(
        rodIds.every(
          (id) => chapterThreeInventory.placements[id]?.gridId == nailGrid,
        ),
        isTrue,
      );
      expect(chapterThreeInventory.placements[nailId]?.gridId, nailGrid);
      await craftProductionRecipe(
        'ss.recipe.nail_board',
        commandId: 'journey-q3-nail-board',
        gridId: nailGrid,
        inputs: [...rodIds, nailId],
      );
      await claimStreetScrapToolRepairKit(
        session: reopened,
        commandId: 'journey-q3-claim-repair-kit',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      await repairStreetScrapTutorialCrowbar(
        session: reopened,
        commandId: 'journey-q3-repair-crowbar',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
        toolInstanceId: 'q303-crowbar',
        metalShardInstanceId: 'q303-metal-shard',
        bindingInstanceId: 'q303-binding',
        gridId: 'backpack',
      );
      final repairedInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      expect(repairedInventory.objects['q303-crowbar']!.toolDurability, 11);
      expect(
        (reopened.snapshot.state['tutorialTasks']! as Map)['q3.03'],
        isTrue,
      );
      await claimStreetScrapCrateKit(
        session: reopened,
        commandId: 'journey-q3-claim-crate-kit',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      chapterThreeInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      final crateInputs = <String>[];
      for (final itemId in const [
        'wood.board',
        'metal.nail_bundle',
        'adhesive.recycled',
      ]) {
        final matching = chapterThreeInventory.objects.values
            .where((item) => item.itemId == itemId)
            .toList(growable: false);
        final quantity = switch (itemId) {
          'wood.board' => 4,
          'metal.nail_bundle' => 2,
          _ => 1,
        };
        expect(matching, hasLength(quantity));
        crateInputs.addAll(matching.map((item) => item.instanceId));
      }
      final crateGrid =
          chapterThreeInventory.placements[crateInputs.first]!.gridId;
      expect(
        crateInputs.every(
          (id) => chapterThreeInventory.placements[id]?.gridId == crateGrid,
        ),
        isTrue,
      );
      await craftProductionRecipe(
        'ss.recipe.wooden_crate',
        commandId: 'journey-q3-craft-crate',
        gridId: crateGrid,
        inputs: crateInputs,
      );
      final crateId = 'journey-q3-craft-crate-output-0';
      await placeStreetScrapTutorialCrate(
        session: reopened,
        commandId: 'journey-q3-place-crate',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
        crateInstanceId: crateId,
        gridId: crateGrid,
      );
      await storeStreetScrapInTutorialCrate(
        session: reopened,
        commandId: 'journey-q3-store-native-sheet',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
        instanceId: rackInstanceId,
        gridId: 'backpack',
      );
      expect(
        catalog
            .inventoryFromJson(
              grids: grids,
              json: Map<String, Object?>.from(
                reopened.snapshot.state['inventory']! as Map,
              ),
            )
            .storage[streetScrapTutorialCrateStorageId],
        [rackInstanceId],
      );
      await withdrawStreetScrapFromTutorialCrate(
        session: reopened,
        commandId: 'journey-q3-withdraw-native-sheet',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
        instanceId: rackInstanceId,
        gridId: 'backpack',
      );
      expect(reopened.snapshot.state['chapter'], 4);
      expect(
        (reopened.snapshot.state['tutorialTasks']! as Map)['q3.04'],
        isTrue,
      );

      // Chapter 4: filter the tutorial's turbid water using the real filter
      // recipe, cook soup into its reusable box, then deliver that same box.
      await claimStreetScrapWaterFilterKit(
        session: reopened,
        commandId: 'journey-q4-claim-filter-kit',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      await craftProductionRecipe(
        'ss.recipe.filter_turbid',
        commandId: 'journey-q4-filter-water',
        gridId: 'backpack',
        inputs: const ['q401-water-bottle', 'q401-charcoal'],
        tools: const ['q401-filter-cloth'],
      );
      var chapterFourTasks = Map<String, Object?>.from(
        reopened.snapshot.state['tutorialTasks']! as Map,
      );
      expect(chapterFourTasks['q4.01'], isTrue);
      chapterThreeInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        chapterThreeInventory
            .objects['q401-water-bottle']!
            .containerState['contentItemId'],
        'water.filtered',
      );
      expect(
        chapterThreeInventory.objects['q401-filter-cloth']!.toolDurability,
        19,
      );
      await claimStreetScrapBasicSoupKit(
        session: reopened,
        commandId: 'journey-q4-claim-soup-kit',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
      );
      var soupInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      for (final instanceId in const [
        'q402-food',
        'q402-water-bottle',
        'q402-fuel',
        'q402-meal-box',
      ]) {
        if (soupInventory.placements[instanceId]?.gridId != 'board') {
          soupInventory = soupInventory.placeFirstFit(instanceId, 'board');
        }
      }
      await reopened.apply(
        commandId: 'journey-q4-arrange-soup-kit',
        expectedRevision: reopened.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': soupInventory.toJson()},
        ),
      );
      await craftProductionRecipe(
        'ss.recipe.soup_basic',
        commandId: 'journey-q4-cook-soup',
        gridId: 'board',
        inputs: const [
          'q402-food',
          'q402-water-bottle',
          'q402-fuel',
          'q402-meal-box',
        ],
      );
      chapterThreeInventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        chapterThreeInventory
            .objects['q402-meal-box']!
            .containerState['contentItemId'],
        'meal.soup_basic',
      );
      expect(
        chapterThreeInventory
            .objects['q402-water-bottle']!
            .containerState['contentItemId'],
        isNull,
      );
      final mealDelivery = await deliverStreetScrapMeal(
        session: reopened,
        commandId: 'journey-q4-deliver-meal',
        expectedRevision: reopened.snapshot.revision,
        catalog: catalog,
        grids: grids,
        mealBoxInstanceId: 'q402-meal-box',
      );
      expect((mealDelivery.result! as Map)['exchangeTickets'], 4);
      chapterFourTasks = Map<String, Object?>.from(
        reopened.snapshot.state['tutorialTasks']! as Map,
      );
      expect(chapterFourTasks['q4.02'], isTrue);
      expect(chapterFourTasks['q4.03'], isTrue);
      expect(reopened.snapshot.state['exchangeTickets'], 4);
      final returnedMealBox = catalog
          .inventoryFromJson(
            grids: grids,
            json: Map<String, Object?>.from(
              reopened.snapshot.state['inventory']! as Map,
            ),
          )
          .objects['q402-meal-box']!;
      expect(returnedMealBox.containerState['contentItemId'], isNull);
      expect(returnedMealBox.containerState['cleanliness'], 'soiled');
      expect(
        returnedMealBox.containerState['lastContentItemId'],
        'meal.soup_basic',
      );

      await reopened.close();
      final completed = StreetScrapSession(
        profileScope: profileScope,
        store: store,
        contentVersions: contentVersions,
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 26),
      );
      await completed.load();
      expect(completed.snapshot.state['chapter'], 4);
      expect(completed.snapshot.state['tutorialTasks'], chapterFourTasks);
      expect(completed.snapshot.state['exchangeTickets'], 4);
      await completed.close();
    },
  );

  test(
    'mineral-water surprise fills the selected clean vessel in place',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'mineral-water-claim',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 23),
      );
      await session.load();
      final baseRules = rules();
      final mineralRules = StreetScrapExpeditionRules.fromJson({
        'nodeCount': 3,
        'investigationsPerNode': 1,
        'movementCost': 1,
        'investigationCost': 2,
        'fixedWrongQuantity': 1,
        'fixedLocations': [
          for (var node = 0; node < 3; node++)
            {
              'id': 'route-$node',
              'phase': 0,
              'options': [
                {'item': 'container.clean_jar', 'quantity': 1},
              ],
            },
        ],
        'surpriseWeights': baseRules.surpriseWeights,
        'surprisePools': {
          for (final category in baseRules.surpriseWeights.keys)
            category: ['water.mineral'],
        },
        'phaseSurprisePools': {
          for (var phase = 0; phase <= 5; phase++)
            '$phase': {
              for (final category in baseRules.surpriseWeights.keys)
                category: ['water.mineral'],
            },
        },
        'surpriseTraitPools': {
          'positive': [],
          'negative': [],
          'chancePercent': 0,
        },
        'scrapQualities': [30, 55],
        'intactQualities': [55, 80, 95],
      });
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 2, height: 1),
      };
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'container.clean_jar': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      final vessel = catalog.createObject(
        instanceId: 'empty-jar',
        itemId: 'container.clean_jar',
        source: 'test',
        quality: 70,
        traits: const {},
        containerState: const {'cleanliness': 'clean'},
      );
      var inventory = catalog
          .emptyInventory(grids: grids)
          .addAndPlaceFirstFit(vessel, 'backpack');
      var route = StreetScrapExpedition.start(
        id: 'mineral-trip',
        phase: 5,
        seed: 1,
        stamina: 7,
        rules: mineralRules,
      ).investigateSurprise(mineralRules).expedition.returnHome();
      expect(route.pendingRewards.single['traits'], {'mineral_rich': true});
      await session.apply(
        commandId: 'seed-mineral-test',
        expectedRevision: 0,
        reduce: (_) => StreetScrapReduction(
          state: {
            'expedition': route.toJson(),
            'inventory': inventory.toJson(),
          },
          result: null,
        ),
      );
      final result = await claimStreetScrapExpeditionRewards(
        session: session,
        commandId: 'claim-mineral-test',
        expectedRevision: 1,
        rules: mineralRules,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
        mineralWaterVessels: const {0: 'empty-jar'},
      );
      inventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect((result.result! as Map)['filledVessels'], ['empty-jar']);
      expect(inventory.objects, hasLength(1));
      expect(
        inventory.objects['empty-jar']!.containerState['contentItemId'],
        'water.mineral',
      );
      expect(inventory.objects['empty-jar']!.containerState['contentTraits'], {
        'mineral_rich': true,
      });
      expect(
        (inventory.objects['empty-jar']!.containerState['contentSource']!
                as String)
            .startsWith('surprise:'),
        isTrue,
      );
      expect(inventory.placements, hasLength(1));
      await session.close();
    },
  );

  test(
    'chapter 1 recycling classifications persist, allow correction, and complete only with four correct held samples',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'recycling-sort',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {
          'paper.scrap': StreetScrapFootprint(1, 1),
          'metal.scrap': StreetScrapFootprint(1, 1),
          'cloth.rag_piece': StreetScrapFootprint(1, 1),
          'plastic.scrap': StreetScrapFootprint(1, 1),
        },
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      var inventory = catalog.emptyInventory(grids: grids);
      for (final sample in streetScrapRecyclingTutorialSamples.entries) {
        inventory = inventory.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'found-${sample.key}',
            itemId: sample.value,
            source: 'expedition:ordinary-find',
            quality: 40,
            traits: const {},
          ),
          'backpack',
        );
      }
      await session.apply(
        commandId: 'chapter-one-setup',
        expectedRevision: 0,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'chapter': 1, 'inventory': inventory.toJson()},
        ),
      );
      final supplied = await claimStreetScrapRecyclingSamples(
        session: session,
        commandId: 'sort-samples',
        expectedRevision: 1,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      expect(supplied.result, {'sampleCount': 4});
      await expectLater(
        claimStreetScrapRecyclingSamples(
          session: session,
          commandId: 'sort-samples-duplicate',
          expectedRevision: 2,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsStateError,
      );
      var revision = 2;
      for (final sample in streetScrapRecyclingTutorialSamples.entries) {
        final category = streetScrapRecyclingCategoryForItem(sample.value)!;
        final result = await classifyStreetScrapRecyclingSample(
          session: session,
          commandId: 'sort-found-${sample.key}',
          expectedRevision: revision++,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
          instanceId: 'found-${sample.key}',
          category: category,
        );
        expect((result.result as Map)['completed'], isFalse);
      }
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q1.01'],
        isNot(true),
      );
      expect(
        session.snapshot.state['unlockedStations'],
        isNot(contains('recycler')),
      );

      final wrong = await classifyStreetScrapRecyclingSample(
        session: session,
        commandId: 'sort-paper-wrong',
        expectedRevision: revision++,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
        instanceId: 'q1-sample-paper',
        category: 'metal',
      );
      expect((wrong.result as Map)['completed'], isFalse);
      await classifyStreetScrapRecyclingSample(
        session: session,
        commandId: 'sort-paper-correct',
        expectedRevision: revision++,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
        instanceId: 'q1-sample-paper',
        category: 'paper',
      );
      for (final entry in streetScrapRecyclingTutorialSamples.entries.skip(1)) {
        final category = streetScrapRecyclingCategoryForItem(entry.value)!;
        final result = await classifyStreetScrapRecyclingSample(
          session: session,
          commandId: 'sort-${entry.key}',
          expectedRevision: revision++,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
          instanceId: entry.key,
          category: category,
        );
        expect((result.result as Map)['completed'], revision == 11);
      }
      expect(session.snapshot.state['recyclingClassifications'], {
        'found-q1-sample-paper': 'paper',
        'found-q1-sample-metal': 'metal',
        'found-q1-sample-cloth': 'cloth',
        'found-q1-sample-plastic': 'plastic',
        'q1-sample-paper': 'paper',
        'q1-sample-metal': 'metal',
        'q1-sample-cloth': 'cloth',
        'q1-sample-plastic': 'plastic',
      });
      expect(session.snapshot.state['tutorialTasks'], {'q1.01': true});
      expect(session.snapshot.state['unlockedStations'], ['recycler']);
      await session.close();
    },
  );

  test(
    'recycling teaching samples are not partially granted when the backpack is full',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'recycling-sort-no-space',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {
          'paper.scrap': StreetScrapFootprint(1, 1),
          'metal.scrap': StreetScrapFootprint(1, 1),
          'cloth.rag_piece': StreetScrapFootprint(1, 1),
          'plastic.scrap': StreetScrapFootprint(1, 1),
        },
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 1, height: 1),
      };
      await session.apply(
        commandId: 'chapter-one-full-bag',
        expectedRevision: 0,
        reduce: (state) =>
            StreetScrapReduction(state: {...state, 'chapter': 1}),
      );
      await expectLater(
        claimStreetScrapRecyclingSamples(
          session: session,
          commandId: 'sort-samples-no-space',
          expectedRevision: 1,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsStateError,
      );
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['inventory'], isNull);
      expect(session.snapshot.state['recyclingSamplesClaimed'], isNull);
      await session.close();
    },
  );

  test(
    'q1.02 sewing kit is gated by q1.01 and delivered atomically once',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'sewing-kit-test',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {
          'cloth.rag_piece': StreetScrapFootprint(1, 1),
          'cloth.thread_end': StreetScrapFootprint(1, 1),
          'tool.needle': StreetScrapFootprint(1, 1),
        },
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      await session.apply(
        commandId: 'sewing-kit-chapter',
        expectedRevision: 0,
        reduce: (state) =>
            StreetScrapReduction(state: {...state, 'chapter': 1}),
      );
      await expectLater(
        claimStreetScrapSewingTutorialKit(
          session: session,
          commandId: 'sewing-kit-locked',
          expectedRevision: 1,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsStateError,
      );
      await session.apply(
        commandId: 'sewing-kit-q101',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'tutorialTasks': {'q1.01': true},
          },
        ),
      );
      final result = await claimStreetScrapSewingTutorialKit(
        session: session,
        commandId: 'sewing-kit-claim',
        expectedRevision: 2,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
      );
      expect(result.result, {'supplyCount': 3});
      final inventory = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(
        inventory.objects.keys,
        containsAll(['q1-kit-rag', 'q1-kit-thread', 'q1-kit-needle']),
      );
      await expectLater(
        claimStreetScrapSewingTutorialKit(
          session: session,
          commandId: 'sewing-kit-duplicate',
          expectedRevision: 3,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsStateError,
      );
      expect(session.snapshot.revision, 3);
      await session.close();
    },
  );

  test(
    'q1.02 kit remains unclaimed if all required supplies cannot fit',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'sewing-kit-no-space',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {
          'cloth.rag_piece': StreetScrapFootprint(1, 1),
          'cloth.thread_end': StreetScrapFootprint(1, 1),
          'tool.needle': StreetScrapFootprint(1, 1),
        },
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 2, height: 1),
      };
      await session.apply(
        commandId: 'sewing-kit-small-chapter',
        expectedRevision: 0,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 1,
            'tutorialTasks': {'q1.01': true},
          },
        ),
      );
      await expectLater(
        claimStreetScrapSewingTutorialKit(
          session: session,
          commandId: 'sewing-kit-small-claim',
          expectedRevision: 1,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsStateError,
      );
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['inventory'], isNull);
      expect(session.snapshot.state['q1.02KitClaimed'], isNull);
      await session.close();
    },
  );

  test(
    'q1.03 keep or deliver atomically completes the mission and unlocks the use index',
    () async {
      for (final choice in ['keep', 'deliver']) {
        final store = MemoryStore();
        final session = StreetScrapSession(
          profileScope: 'intact-choice-$choice',
          store: store,
          contentVersions: const {
            'game.street-scrap.content.chapters-0-4': '0.1.2',
          },
          rulesetVersion: 1,
          clock: () => DateTime.utc(2026, 10, 22),
        );
        await session.load();
        final catalog = StreetScrapInventoryCatalog(
          footprints: const {
            'metal.sheet': StreetScrapFootprint(1, 1),
            'wood.board': StreetScrapFootprint(1, 2),
          },
          packingRules: const {},
        );
        const grids = {
          'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
          'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
        };
        var inventory = catalog.emptyInventory(grids: grids);
        inventory = inventory.addAndPlaceFirstFit(
          catalog.createObject(
            instanceId: 'rack-sheet',
            itemId: 'metal.sheet',
            source: 'fixed:metal_recycling_rack',
            quality: 80,
            traits: const {},
          ),
          'board',
        );
        await session.apply(
          commandId: 'setup-intact-$choice',
          expectedRevision: 0,
          reduce: (state) => StreetScrapReduction(
            state: {
              ...state,
              'chapter': 1,
              'inventory': inventory.toJson(),
              'tutorialTasks': {'q1.02': true},
            },
          ),
        );
        final result = await chooseStreetScrapIntactMaterial(
          session: session,
          commandId: 'choose-intact-$choice',
          expectedRevision: 1,
          catalog: catalog,
          grids: grids,
          instanceId: 'rack-sheet',
          choice: choice,
        );
        expect((result.result as Map)['choice'], choice);
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q1.03'],
          isTrue,
        );
        expect(session.snapshot.state['q1.03Choice'], choice);
        expect(session.snapshot.state['unlockedIndexes'], [
          'material_use_index',
        ]);
        expect(session.snapshot.state['chapter'], 2);
        expect(session.snapshot.state['unlockedFishingSpots'], [
          'dock_entrance',
        ]);
        final saved = catalog.inventoryFromJson(
          grids: grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        expect(saved.objects.containsKey('rack-sheet'), choice == 'keep');
        await session.close();
      }
    },
  );

  test(
    'full backpack rejects a claim without consuming pending rewards',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'trip-full',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final routeRules = rules();
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'full-start',
        expectedRevision: 0,
        rules: routeRules,
        transition: (_) => StreetScrapExpedition.start(
          id: 'full-trip',
          phase: 0,
          seed: 29,
          stamina: 3,
          rules: routeRules,
        ),
      );
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'full-search',
        expectedRevision: 1,
        rules: routeRules,
        transition: (current) => current!
            .investigateFixed(
              rules: routeRules,
              optionIndex: 0,
              selectedVisibleTarget: true,
            )
            .expedition,
      );
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'full-return',
        expectedRevision: 2,
        rules: routeRules,
        transition: (current) => current!.returnHome(),
      );
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'cloth.rag_piece': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 2, height: 1),
      };
      await expectLater(
        claimStreetScrapExpeditionRewards(
          session: session,
          commandId: 'full-claim',
          expectedRevision: 3,
          rules: routeRules,
          catalog: catalog,
          grids: grids,
          backpackGridId: 'backpack',
        ),
        throwsStateError,
      );
      expect(session.snapshot.revision, 3);
      final saved = StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(
          Map<String, Object?>.from(
            session.snapshot.state['expedition']! as Map,
          ),
        ),
      );
      expect(saved.returned, isTrue);
      expect(saved.claimed, isFalse);
      expect(saved.pendingRewards.single['quantity'], 3);
      expect(session.snapshot.state.containsKey('inventory'), isFalse);
      await session.close();
    },
  );

  test(
    'zero stamina cannot survey but may return; invalid weights fail closed',
    () {
      final routeRules = rules();
      final exhausted = StreetScrapExpedition.start(
        id: 'trip-4',
        phase: 0,
        seed: 2,
        stamina: 1,
        rules: routeRules,
      );
      expect(() => exhausted.investigateSurprise(routeRules), throwsStateError);
      expect(exhausted.returnHome().returned, isTrue);
      expect(
        () => StreetScrapExpeditionRules.fromJson({
          'nodeCount': 3,
          'investigationsPerNode': 1,
          'movementCost': 1,
          'investigationCost': 2,
          'fixedWrongQuantity': 1,
          'fixedLocations': [],
          'surpriseWeights': {'a': 99},
          'surprisePools': {
            'a': ['x'],
          },
          'scrapQualities': [30],
          'intactQualities': [55],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'start spends route-entry stamina and refuses a second unclaimed activity',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'trip-start-guard',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final routeRules = rules();
      await startStreetScrapExpeditionCommand(
        session: session,
        commandId: 'start-one',
        expectedRevision: 0,
        phase: 0,
        seed: 3,
        defaultStamina: 60,
        rules: routeRules,
      );
      expect(session.snapshot.state['stamina'], 59);
      await expectLater(
        startStreetScrapExpeditionCommand(
          session: session,
          commandId: 'start-two',
          expectedRevision: 1,
          phase: 0,
          seed: 5,
          defaultStamina: 60,
          rules: routeRules,
        ),
        throwsStateError,
      );
      expect(session.snapshot.revision, 1);
      expect(session.snapshot.state['stamina'], 59);
      await session.close();
    },
  );

  test(
    'phase-0 hand-in consumes exactly two eligible backpack objects once',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'tutorial-delivery',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'cloth.rag_piece': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      const grids = {
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final initial = StreetScrapInventory(
        catalog: catalog,
        grids: grids,
        objects: {
          for (final id in ['rag-1', 'rag-2'])
            id: catalog.createObject(
              instanceId: id,
              itemId: 'cloth.rag_piece',
              source: 'street-find',
              quality: 40,
              traits: const {},
            ),
        },
        placements: const {
          'rag-1': StreetScrapPlacement(
            instanceId: 'rag-1',
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
      await session.apply(
        commandId: 'seed-tutorial-delivery',
        expectedRevision: 0,
        reduce: (_) => StreetScrapReduction(
          state: {
            'tutorialTasks': {'q0.01': true, 'q0.02': true},
            'inventory': initial.toJson(),
          },
        ),
      );
      final delivered = await deliverStreetScrapTutorialMaterials(
        session: session,
        commandId: 'deliver-rags',
        expectedRevision: 1,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
        eligibleItemIds: const ['cloth.rag_piece'],
        quantity: 2,
      );
      expect(delivered.result, {
        'itemIds': ['rag-1', 'rag-2'],
        'quantity': 2,
      });
      expect(
        (session.snapshot.state['tutorialTasks']! as Map)['q0.03'],
        isTrue,
      );
      expect(session.snapshot.state['chapter'], 1);
      final saved = catalog.inventoryFromJson(
        grids: grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.objects, isEmpty);
      final replay = await deliverStreetScrapTutorialMaterials(
        session: session,
        commandId: 'deliver-rags',
        expectedRevision: 1,
        catalog: catalog,
        grids: grids,
        backpackGridId: 'backpack',
        eligibleItemIds: const ['cloth.rag_piece'],
        quantity: 2,
      );
      expect(replay.wasDuplicate, isTrue);
      await session.close();
    },
  );

  test(
    'discarding a returned reward is confirmed by a distinct persisted command and cannot reroll',
    () async {
      final store = MemoryStore();
      final session = StreetScrapSession(
        profileScope: 'expedition-discard',
        store: store,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        rulesetVersion: 1,
        clock: () => DateTime.utc(2026, 10, 22),
      );
      await session.load();
      final routeRules = rules();
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'discard-start',
        expectedRevision: 0,
        rules: routeRules,
        transition: (_) => StreetScrapExpedition.start(
          id: 'discard-trip',
          phase: 0,
          seed: 37,
          stamina: 3,
          rules: routeRules,
        ),
      );
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'discard-search',
        expectedRevision: 1,
        rules: routeRules,
        transition: (current) =>
            current!.investigateSurprise(routeRules).expedition,
      );
      await applyStreetScrapExpeditionCommand(
        session: session,
        commandId: 'discard-return',
        expectedRevision: 2,
        rules: routeRules,
        transition: (current) => current!.returnHome(),
      );
      final discarded = await discardStreetScrapExpeditionReward(
        session: session,
        commandId: 'discard-one',
        expectedRevision: 3,
        rules: routeRules,
        rewardIndex: 0,
      );
      expect(discarded.wasDuplicate, isFalse);
      final restored = StreetScrapExpedition.fromJson(
        Map<String, Object?>.from(
          Map<String, Object?>.from(
            session.snapshot.state['expedition']! as Map,
          ),
        ),
      );
      expect(restored.pendingRewards, isEmpty);
      expect(restored.discardedCount, 1);
      expect(session.snapshot.revision, 4);
      await expectLater(
        discardStreetScrapExpeditionReward(
          session: session,
          commandId: 'discard-twice',
          expectedRevision: 4,
          rules: routeRules,
          rewardIndex: 0,
        ),
        throwsStateError,
      );
      expect(session.snapshot.revision, 4);
      await session.close();
    },
  );
}
