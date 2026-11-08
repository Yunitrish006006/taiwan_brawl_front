import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_fishing.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

class _MemoryStore implements StreetScrapProgressStore {
  final values = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => values[slotKey];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    if ((values[slotKey]?['revision'] as int?) != expectedRevision) {
      return false;
    }
    values[slotKey] = nextSnapshot;
    return true;
  }
}

const _rules = StreetScrapFishingRules(
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
    StreetScrapFishingSpot(id: 'dock_entrance', phase: 2, name: '舊碼頭入口'),
    StreetScrapFishingSpot(
      id: streetScrapRaftFishingSpotId,
      phase: 3,
      name: '浮架釣點',
      failureRewards: ['fish.bone', 'wood.driftwood'],
    ),
  ],
  failureRewards: ['wood.driftwood', 'cloth.thread_end'],
);

const _grids = {
  'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
  'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
};
final _catalog = StreetScrapInventoryCatalog(
  footprints: const {
    'fish.raw': StreetScrapFootprint(1, 2),
    'fish.bone': StreetScrapFootprint(1, 1),
    'wood.driftwood': StreetScrapFootprint(1, 2),
    'cloth.thread_end': StreetScrapFootprint(1, 1),
    'container.clean': StreetScrapFootprint(1, 1),
    'toolpart.float': StreetScrapFootprint(1, 2),
    'structure.raft': StreetScrapFootprint(2, 2),
    'test.full-grid': StreetScrapFootprint(6, 6),
  },
  packingRules: const {},
);

Future<StreetScrapSession> _session(
  String scope, {
  int stamina = 8,
  int chapter = 2,
}) async {
  final session = StreetScrapSession(
    profileScope: scope,
    store: _MemoryStore(),
    contentVersions: const {'game.street-scrap.content.chapters-0-4': '0.1.13'},
    rulesetVersion: 1,
  );
  await session.load();
  await session.apply(
    commandId: 'setup-$scope',
    expectedRevision: 0,
    reduce: (_) => StreetScrapReduction(
      state: {
        'chapter': chapter,
        'stamina': stamina,
        'tutorialTasks': {'q1.03': true},
        'unlockedFishingSpots': ['dock_entrance'],
        'inventory': _catalog.emptyInventory(grids: _grids).toJson(),
      },
    ),
  );
  return session;
}

Future<void> _signal(StreetScrapSession session, String id, int held) async {
  final revision = session.snapshot.revision;
  await resolveStreetScrapFishingSignal(
    session: session,
    commandId: id,
    expectedRevision: revision,
    rules: _rules,
    heldMilliseconds: held,
  );
}

Future<void> _cast(StreetScrapSession session, String id) async {
  final revision = session.snapshot.revision;
  await castStreetScrapLine(
    session: session,
    commandId: id,
    expectedRevision: revision,
    rules: _rules,
    spotId: 'dock_entrance',
    defaultStamina: 60,
  );
}

void main() {
  test(
    'q2.01 cast saves free equipment, cost and pending activity once',
    () async {
      final session = await _session('fishing-cast');
      final result = await castStreetScrapLine(
        session: session,
        commandId: 'first-cast',
        expectedRevision: 1,
        rules: _rules,
        spotId: 'dock_entrance',
        defaultStamina: 60,
      );
      expect(result.wasDuplicate, isFalse);
      expect(session.snapshot.state['stamina'], 5);
      expect(
        session.snapshot.state['tutorialTasks']! as Map,
        containsPair('q2.01', true),
      );
      final activity = session.snapshot.state['fishingActivity']! as Map;
      expect(activity['bait'], 'natural-free');
      expect(activity['rod'], 'loaner');
      expect(activity['signals'], isEmpty);

      final replay = await castStreetScrapLine(
        session: session,
        commandId: 'first-cast',
        expectedRevision: 1,
        rules: _rules,
        spotId: 'dock_entrance',
        defaultStamina: 60,
      );
      expect(replay.wasDuplicate, isTrue);
      expect(session.snapshot.revision, 2);
      expect(session.snapshot.state['stamina'], 5);
      await session.close();
    },
  );

  test(
    'insufficient stamina and an unresolved cast cannot charge again',
    () async {
      final tired = await _session('fishing-tired', stamina: 2);
      await expectLater(
        castStreetScrapLine(
          session: tired,
          commandId: 'tired-cast',
          expectedRevision: 1,
          rules: _rules,
          spotId: 'dock_entrance',
          defaultStamina: 60,
        ),
        throwsA(isA<StateError>()),
      );
      expect(tired.snapshot.revision, 1);
      expect(tired.snapshot.state['stamina'], 2);
      await tired.close();

      final active = await _session('fishing-active');
      await castStreetScrapLine(
        session: active,
        commandId: 'cast-a',
        expectedRevision: 1,
        rules: _rules,
        spotId: 'dock_entrance',
        defaultStamina: 60,
      );
      await expectLater(
        castStreetScrapLine(
          session: active,
          commandId: 'cast-b',
          expectedRevision: 2,
          rules: _rules,
          spotId: 'dock_entrance',
          defaultStamina: 60,
        ),
        throwsA(isA<StateError>()),
      );
      expect(active.snapshot.state['stamina'], 5);
      expect(active.snapshot.revision, 2);
      await active.close();
    },
  );

  test('chapter and spot gates reject casts before charging stamina', () async {
    final session = await _session('fishing-locked', chapter: 1);
    await expectLater(
      castStreetScrapLine(
        session: session,
        commandId: 'locked-cast',
        expectedRevision: 1,
        rules: _rules,
        spotId: 'dock_entrance',
        defaultStamina: 60,
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.state['stamina'], 8);
    await session.close();
  });

  test(
    'two of three signals catch fish; three grant the documented quality bonus',
    () async {
      for (final entry in [(2, 50), (3, 58)]) {
        final session = await _session('fishing-count-${entry.$1}');
        await _cast(session, 'cast-${entry.$1}');
        await _signal(session, 'signal-${entry.$1}-1', 2000);
        await _signal(session, 'signal-${entry.$1}-2', 2000);
        await _signal(
          session,
          'signal-${entry.$1}-3',
          entry.$1 == 3 ? 2000 : 500,
        );
        final pending = session.snapshot.state['fishingPendingResult']! as Map;
        expect(pending['kind'], 'fish');
        expect(pending['quality'], entry.$2);
        await claimStreetScrapFishingResult(
          session: session,
          commandId: 'claim-${entry.$1}',
          expectedRevision: session.snapshot.revision,
          catalog: _catalog,
          grids: _grids,
          backpackGridId: 'backpack',
        );
        expect(
          (session.snapshot.state['tutorialTasks']! as Map)['q2.02'],
          isTrue,
        );
        final inventory = _catalog.inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        );
        expect(inventory.objects.values.single.itemId, 'fish.raw');
        expect(inventory.objects.values.single.quality, entry.$2);
        await session.close();
      }
    },
  );

  test(
    'missed casts save shore scrap and the entry-spot third cast guarantees fish',
    () async {
      final session = await _session('fishing-guarantee', stamina: 20);
      for (var attempt = 1; attempt <= 2; attempt++) {
        await _cast(session, 'miss-cast-$attempt');
        await _signal(session, 'miss-$attempt-1', 0);
        await _signal(session, 'miss-$attempt-2', 0);
        await _signal(session, 'miss-$attempt-3', 0);
        final pending = session.snapshot.state['fishingPendingResult']! as Map;
        expect(pending['kind'], 'shore-scrap');
        await expectLater(
          _cast(session, 'blocked-before-claim-$attempt'),
          throwsA(isA<StateError>()),
        );
        await claimStreetScrapFishingResult(
          session: session,
          commandId: 'claim-miss-$attempt',
          expectedRevision: session.snapshot.revision,
          catalog: _catalog,
          grids: _grids,
          backpackGridId: 'backpack',
          failureRewardItemId: 'wood.driftwood',
        );
        expect(session.snapshot.state['fishingConsecutiveFailures'], attempt);
      }
      await _cast(session, 'guaranteed-cast');
      final activity = session.snapshot.state['fishingActivity']! as Map;
      expect(activity['guided'], isTrue);
      await _signal(session, 'guided-signal', 0);
      expect(
        (session.snapshot.state['fishingPendingResult']! as Map)['kind'],
        'fish',
      );
      await session.close();
    },
  );

  test(
    'q2.03 keep path preserves the caught whole-fish identity and quality',
    () async {
      final session = await _session('fishing-keep');
      await _cast(session, 'keep-cast');
      await _signal(session, 'keep-1', 2000);
      await _signal(session, 'keep-2', 2000);
      await _signal(session, 'keep-3', 2000);
      await claimStreetScrapFishingResult(
        session: session,
        commandId: 'claim-whole-fish',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        backpackGridId: 'backpack',
      );
      final before = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final fishBefore = before.objects.values.single;
      await keepStreetScrapWholeFish(
        session: session,
        commandId: 'keep-q2-fish',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
      );
      final after = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final fishAfter = after.objects[fishBefore.instanceId]!;
      expect(fishAfter.instanceId, fishBefore.instanceId);
      expect(fishAfter.itemId, fishBefore.itemId);
      expect(fishAfter.source, fishBefore.source);
      expect(fishAfter.quality, fishBefore.quality);
      expect(fishAfter.traits, fishBefore.traits);
      expect(session.snapshot.state['q2.03Choice'], 'keep');
      expect(
        (session.snapshot.state['tutorialTasks']! as Map).values,
        everyElement(isA<bool>()),
      );
      expect(session.snapshot.state['chapter'], 3);
      await session.close();
    },
  );

  test('float and rod tolerance bonuses use max instead of stacking', () {
    expect(
      streetScrapFishingPromptWidthPercent(
        basePromptWidthPercent: 30,
        floatEquipped: true,
      ),
      35,
    );
    expect(
      streetScrapFishingPromptWidthPercent(
        basePromptWidthPercent: 30,
        rodBonusPercentagePoints: 6,
      ),
      36,
    );
    expect(
      streetScrapFishingPromptWidthPercent(
        basePromptWidthPercent: 30,
        floatEquipped: true,
        rodBonusPercentagePoints: 6,
      ),
      36,
      reason: 'The float bonus and improved-rod bonus must not add together.',
    );
  });

  test(
    'equipping a float preserves its bottle and widens the saved cue',
    () async {
      final session = await _session('fishing-float-equipment', stamina: 12);
      final bottle = _catalog.createObject(
        instanceId: 'float-original-bottle',
        itemId: 'container.clean',
        source: 'scavenged:glass-corner',
        quality: 73,
        traits: const {'dry-seal': true},
        containerState: const {'cleanliness': 'clean'},
      );
      final float = _catalog.createObject(
        instanceId: 'crafted-float-instance',
        itemId: 'toolpart.float',
        source: 'crafted:ss.recipe.float',
        quality: 66,
        traits: const {'stitched': true},
        containerContents: [bottle],
      );
      final carried = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(float, 'board');
      await session.apply(
        commandId: 'seed-crafted-float',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'inventory': carried.toJson()},
        ),
      );
      await equipStreetScrapFishingFloat(
        session: session,
        commandId: 'equip-crafted-float',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        floatInstanceId: float.instanceId,
      );
      final installed = session.snapshot.state['fishingEquipment']! as Map;
      final rawFloat = installed['float']! as Map;
      expect(rawFloat['instanceId'], float.instanceId);
      final child = (rawFloat['containerContents']! as List).single as Map;
      expect(child['instanceId'], bottle.instanceId);
      expect(child['source'], bottle.source);
      expect(child['quality'], bottle.quality);
      expect(child['traits'], bottle.traits);

      await castStreetScrapLine(
        session: session,
        commandId: 'cast-with-float',
        expectedRevision: session.snapshot.revision,
        rules: _rules,
        spotId: 'dock_entrance',
        defaultStamina: 60,
      );
      expect(
        (session.snapshot.state['fishingActivity']!
            as Map)['promptWidthPercent'],
        35,
      );
      await expectLater(
        unequipStreetScrapFishingFloat(
          session: session,
          commandId: 'remove-float-mid-cast',
          expectedRevision: session.snapshot.revision,
          catalog: _catalog,
          grids: _grids,
          targetGridId: 'backpack',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (session.snapshot.state['fishingEquipment']! as Map)['float'],
        isNotNull,
      );

      await _signal(session, 'float-fish-1', 2000);
      await _signal(session, 'float-fish-2', 2000);
      await _signal(session, 'float-fish-3', 2000);
      await claimStreetScrapFishingResult(
        session: session,
        commandId: 'claim-float-fish',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        backpackGridId: 'backpack',
      );
      await unequipStreetScrapFishingFloat(
        session: session,
        commandId: 'remove-float-after-cast',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        targetGridId: 'backpack',
      );
      final restored = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      final restoredFloat = restored.objects[float.instanceId]!;
      expect(restored.placements[float.instanceId]!.gridId, 'backpack');
      expect(restoredFloat.quality, float.quality);
      expect(restoredFloat.traits, float.traits);
      expect(
        restoredFloat.containerContents.single.instanceId,
        bottle.instanceId,
      );
      expect(restoredFloat.containerContents.single.quality, bottle.quality);
      expect(
        (session.snapshot.state['fishingEquipment']! as Map).containsKey(
          'float',
        ),
        isFalse,
      );
      await session.close();
    },
  );

  test(
    'raft facility unlocks its fishing spot and uses spot rewards',
    () async {
      final session = await _session('fishing-raft-facility', stamina: 15);
      final raft = _catalog.createObject(
        instanceId: 'crafted-raft-instance',
        itemId: 'structure.raft',
        source: 'crafted:ss.recipe.raft',
        quality: 62,
        traits: const {'reinforced-corner': true},
      );
      final carried = _catalog
          .emptyInventory(grids: _grids)
          .addAndPlaceFirstFit(raft, 'board');
      await session.apply(
        commandId: 'seed-raft-for-install',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => StreetScrapReduction(
          state: {...state, 'chapter': 3, 'inventory': carried.toJson()},
        ),
      );
      await placeStreetScrapRaft(
        session: session,
        commandId: 'install-crafted-raft',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        raftInstanceId: raft.instanceId,
      );
      final state = session.snapshot.state;
      expect((state['fishingFacilities']! as Map)['dockRaft'], isA<Map>());
      expect(
        state['unlockedFishingSpots'],
        contains(streetScrapRaftFishingSpotId),
      );
      expect((state['storageFurniture'] as List?) ?? const [], isEmpty);

      await castStreetScrapLine(
        session: session,
        commandId: 'cast-at-raft-point',
        expectedRevision: session.snapshot.revision,
        rules: _rules,
        spotId: streetScrapRaftFishingSpotId,
        defaultStamina: 60,
      );
      await _signal(session, 'raft-miss-1', 0);
      await _signal(session, 'raft-miss-2', 0);
      await _signal(session, 'raft-miss-3', 0);
      final pending = session.snapshot.state['fishingPendingResult']! as Map;
      expect(pending['choices'], ['fish.bone', 'wood.driftwood']);
      await claimStreetScrapFishingResult(
        session: session,
        commandId: 'claim-raft-fish-bone',
        expectedRevision: session.snapshot.revision,
        catalog: _catalog,
        grids: _grids,
        backpackGridId: 'backpack',
        failureRewardItemId: 'fish.bone',
      );
      final rewards = _catalog.inventoryFromJson(
        grids: _grids,
        json: Map<String, Object?>.from(
          session.snapshot.state['inventory']! as Map,
        ),
      );
      expect(rewards.objects.values.single.itemId, 'fish.bone');
      await session.close();
    },
  );

  test('recalling raft is atomic when 2x2 space is unavailable', () async {
    final session = await _session('fishing-raft-recall', chapter: 3);
    final raft = _catalog.createObject(
      instanceId: 'raft-to-recall',
      itemId: 'structure.raft',
      source: 'crafted:ss.recipe.raft',
      quality: 81,
      traits: const {'patched': true},
    );
    final carried = _catalog
        .emptyInventory(grids: _grids)
        .addAndPlaceFirstFit(raft, 'board');
    await session.apply(
      commandId: 'seed-raft-recall',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'inventory': carried.toJson()},
      ),
    );
    await placeStreetScrapRaft(
      session: session,
      commandId: 'install-before-recall',
      expectedRevision: session.snapshot.revision,
      catalog: _catalog,
      grids: _grids,
      raftInstanceId: raft.instanceId,
    );
    final blocker = _catalog.createObject(
      instanceId: 'block-all-board-space',
      itemId: 'test.full-grid',
      source: 'test',
      quality: 50,
      traits: const {},
    );
    final fullBoard = _catalog
        .inventoryFromJson(
          grids: _grids,
          json: Map<String, Object?>.from(
            session.snapshot.state['inventory']! as Map,
          ),
        )
        .addAndPlaceFirstFit(blocker, 'board');
    await session.apply(
      commandId: 'fill-board-before-recall',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {...state, 'inventory': fullBoard.toJson()},
      ),
    );
    final revisionBeforeFailure = session.snapshot.revision;
    final facilityBeforeFailure =
        (session.snapshot.state['fishingFacilities']! as Map)['dockRaft'];
    await expectLater(
      recallStreetScrapRaft(
        session: session,
        commandId: 'failed-recall-to-full-board',
        expectedRevision: revisionBeforeFailure,
        catalog: _catalog,
        grids: _grids,
        targetGridId: 'board',
      ),
      throwsA(isA<StateError>()),
    );
    expect(session.snapshot.revision, revisionBeforeFailure);
    expect(
      (session.snapshot.state['fishingFacilities']! as Map)['dockRaft'],
      facilityBeforeFailure,
    );
    expect(
      session.snapshot.state['unlockedFishingSpots'],
      contains(streetScrapRaftFishingSpotId),
    );

    await recallStreetScrapRaft(
      session: session,
      commandId: 'successful-recall-to-backpack',
      expectedRevision: revisionBeforeFailure,
      catalog: _catalog,
      grids: _grids,
      targetGridId: 'backpack',
    );
    final restored = _catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    final restoredRaft = restored.objects[raft.instanceId]!;
    expect(restored.placements[raft.instanceId]!.gridId, 'backpack');
    expect(restoredRaft.quality, raft.quality);
    expect(restoredRaft.traits, raft.traits);
    expect((session.snapshot.state['fishingFacilities']! as Map), isEmpty);
    expect(session.snapshot.state['unlockedFishingSpots'], ['dock_entrance']);
    await session.close();
  });
}
