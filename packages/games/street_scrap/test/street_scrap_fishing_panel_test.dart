import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_fishing.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_fishing_panel.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/src/street_scrap_audio.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';

class _Store implements StreetScrapProgressStore {
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

void main() {
  testWidgets('locked fishing tab shows a large image first unlock card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {},
      packingRules: const {},
    );
    final session = StreetScrapSession(
      profileScope: 'locked-fishing-panel',
      store: _Store(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapFishingPanel(
              session: session,
              rules: const StreetScrapFishingRules(
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
                spots: [],
                failureRewards: [],
              ),
              defaultStamina: 60,
              catalog: catalog,
              grids: grids,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('street-scrap-locked-fishing')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('street-scrap-locked-art-fishing'))),
      const Size(128, 128),
    );
    expect(find.text('Dock Fishing'), findsOneWidget);
    expect(find.text('Locked · requires Phase 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('fishing failure uses localized copy and hides domain error IDs', (
    tester,
  ) async {
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'fish.raw': StreetScrapFootprint(1, 2)},
      packingRules: const {},
    );
    const rules = StreetScrapFishingRules(
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
        StreetScrapFishingSpot(id: 'dock_entrance', phase: 2, name: 'Old Dock'),
      ],
      failureRewards: ['wood.driftwood', 'cloth.thread_end'],
    );
    final session = StreetScrapSession(
      profileScope: 'fishing-localized-error',
      store: _Store(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await session.apply(
      commandId: 'seed-invalid-fishing-version',
      expectedRevision: 0,
      reduce: (_) => StreetScrapReduction(
        state: {
          'chapter': 2,
          'stamina': 12,
          'unlockedFishingSpots': ['dock_entrance'],
          'inventory': catalog.emptyInventory(grids: grids).toJson(),
          'fishingActivity': {
            'id': 'stale-activity',
            'rulesVersion': 99,
            'spotId': 'dock_entrance',
            'status': 'awaiting-signals',
            'signals': <Object?>[],
          },
        },
      ),
    );
    final beforeRender = session.snapshot.toJson();
    final panel = StreetScrapFishingPanel(
      session: session,
      rules: rules,
      defaultStamina: 60,
      catalog: catalog,
      grids: grids,
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapFishingPanel(
              session: session,
              rules: rules,
              defaultStamina: 60,
              catalog: catalog,
              grids: grids,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Old Dock Entrance'), findsOneWidget);
    expect(find.byKey(const Key('street-scrap-fishing-scene')), findsOneWidget);
    expect(find.textContaining('dock_entrance'), findsNothing);
    await tester.tap(find.byKey(const Key('street-scrap-fishing-prompt-zone')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The fishing attempt cannot continue; saved progress was not changed.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('fishingActivityMissing'), findsNothing);
    expect(session.snapshot.toJson(), beforeRender);
    await session.apply(
      commandId: 'replace-with-unknown-fishing-spot',
      expectedRevision: session.snapshot.revision,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'fishingActivity': {
            ...Map<String, Object?>.from(state['fishingActivity']! as Map),
            'spotId': 'future_internal_spot_code',
          },
        },
      ),
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(home: Scaffold(body: panel)),
      ),
    );
    expect(find.text('Unknown fishing spot'), findsOneWidget);
    expect(find.textContaining('future_internal_spot_code'), findsNothing);
    await session.close();
  });

  testWidgets('fishing primary actions use the active English locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'fish.raw': StreetScrapFootprint(1, 2)},
      packingRules: const {},
    );
    const rules = StreetScrapFishingRules(
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
        StreetScrapFishingSpot(id: 'dock_entrance', phase: 2, name: 'Old Dock'),
      ],
      failureRewards: ['wood.driftwood', 'cloth.thread_end'],
    );
    final session = StreetScrapSession(
      profileScope: 'fishing-localization-test',
      store: _Store(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await session.apply(
      commandId: 'setup-localization',
      expectedRevision: 0,
      reduce: (_) => StreetScrapReduction(
        state: {
          'chapter': 2,
          'stamina': 12,
          'unlockedFishingSpots': ['dock_entrance'],
          'inventory': catalog.emptyInventory(grids: grids).toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      StreetScrapLocalizationsScope(
        locale: 'en',
        child: MaterialApp(
          home: Scaffold(
            body: StreetScrapFishingPanel(
              session: session,
              rules: rules,
              defaultStamina: 60,
              catalog: catalog,
              grids: grids,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Dock Fishing'), findsOneWidget);
    expect(find.byKey(const Key('street-scrap-fishing-scene')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('street-scrap-fishing-scene')))
          .height,
      162,
    );
    expect(find.textContaining('Use free natural bait'), findsNothing);
    expect(find.text('Stamina: 12; casting costs 3.'), findsNothing);
    expect(find.text('Old Dock Entrance'), findsOneWidget);
    expect(find.text('Cast'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    expect(
      tester
          .getSize(find.byKey(const Key('street-scrap-fishing-scene')))
          .height,
      closeTo(384, 0.1),
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets(
    'text-assisted fishing completes cues and retains perfect quality on a narrow large-text layout',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final errors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        previousHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousHandler);
      const grids = {
        'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
        'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
      };
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'fish.raw': StreetScrapFootprint(1, 2)},
        packingRules: const {},
      );
      const rules = StreetScrapFishingRules(
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
            name: 'Old Dock',
          ),
        ],
        failureRewards: ['wood.driftwood', 'cloth.thread_end'],
      );
      final session = StreetScrapSession(
        profileScope: 'fishing-text-assistance-large-text',
        store: _Store(),
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.21',
        },
        rulesetVersion: 1,
      );
      await session.load();
      await session.apply(
        commandId: 'setup-assisted-fishing',
        expectedRevision: 0,
        reduce: (_) => StreetScrapReduction(
          state: {
            'chapter': 2,
            'stamina': 12,
            'gameSettings': const {
              'textScale': 2.0,
              'reduceMotion': false,
              'assistedControls': true,
              'soundVolume': 100,
            },
            'tutorialTasks': {'q1.03': true},
            'unlockedFishingSpots': ['dock_entrance'],
            'inventory': catalog.emptyInventory(grids: grids).toJson(),
          },
        ),
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
                child: StreetScrapFishingPanel(
                  session: session,
                  rules: rules,
                  defaultStamina: 60,
                  catalog: catalog,
                  grids: grids,
                  assistedControls: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cast = find.byKey(const Key('street-scrap-cast-dock_entrance'));
      await tester.ensureVisible(cast);
      expect(tester.getSize(cast).height, greaterThanOrEqualTo(48));
      await tester.tap(cast);
      await tester.pumpAndSettle();
      expect(find.text('Signal 1 · hold the lit area'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('text assistance is on')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('street-scrap-fishing-prompt-zone')),
        findsNothing,
      );
      final assistedSignal = find.byKey(
        const Key('street-scrap-fishing-assisted-signal'),
      );
      for (var cue = 0; cue < 3; cue++) {
        await tester.ensureVisible(assistedSignal);
        expect(tester.getSize(assistedSignal).height, greaterThanOrEqualTo(48));
        await tester.tap(assistedSignal);
        await tester.pumpAndSettle();
      }
      final pending = session.snapshot.state['fishingPendingResult']! as Map;
      expect(pending['kind'], 'fish');
      expect(pending['successfulSignals'], 3);
      expect(pending['quality'], 58);
      expect(errors, isEmpty);
      await session.close();
    },
  );

  testWidgets('fishing panel casts, records three held cues and claims fish', (
    tester,
  ) async {
    const grids = {
      'board': StreetScrapGridSpec(id: 'board', width: 6, height: 6),
      'backpack': StreetScrapGridSpec(id: 'backpack', width: 4, height: 4),
    };
    final catalog = StreetScrapInventoryCatalog(
      footprints: const {'fish.raw': StreetScrapFootprint(1, 2)},
      packingRules: const {},
    );
    const rules = StreetScrapFishingRules(
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
      ],
      failureRewards: ['wood.driftwood', 'cloth.thread_end'],
    );
    final session = StreetScrapSession(
      profileScope: 'fishing-panel',
      store: _Store(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.13',
      },
      rulesetVersion: 1,
    );
    await session.load();
    await session.apply(
      commandId: 'setup',
      expectedRevision: 0,
      reduce: (_) => StreetScrapReduction(
        state: {
          'chapter': 2,
          'stamina': 12,
          'tutorialTasks': {'q1.03': true},
          'unlockedFishingSpots': ['dock_entrance'],
          'inventory': catalog.emptyInventory(grids: grids).toJson(),
        },
      ),
    );
    final playedCues = <StreetScrapAudioCue>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetScrapFishingPanel(
            session: session,
            rules: rules,
            defaultStamina: 60,
            catalog: catalog,
            grids: grids,
            onSound: playedCues.add,
          ),
        ),
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('street-scrap-fishing-scene')))
          .height,
      288,
    );
    await tester.tap(find.byKey(const Key('street-scrap-cast-dock_entrance')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('street-scrap-fishing-scene')))
          .height,
      220,
    );
    final zone = find.byKey(const Key('street-scrap-fishing-prompt-zone'));
    expect(find.text('魚訊 1・按住亮區'), findsOneWidget);
    expect(find.text('按住'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('提示區 30%；按住 2 秒完成')), findsOneWidget);
    final trackWidth = tester
        .getSize(find.byKey(const Key('street-scrap-fishing-track')))
        .width;
    final zoneWidth = tester.getSize(zone).width;
    expect((zoneWidth / trackWidth - 0.3).abs(), lessThan(0.01));
    final center = tester.getCenter(zone);
    final slipped = await tester.startGesture(center);
    await tester.pump(const Duration(seconds: 1));
    await slipped.moveTo(center + const Offset(180, 0));
    await tester.pump(const Duration(seconds: 2));
    await slipped.up();
    await tester.pumpAndSettle();
    expect(
      ((session.snapshot.state['fishingActivity']! as Map)['signals']! as List)
          .single['success'],
      isFalse,
    );
    for (var index = 0; index < 2; index++) {
      final gesture = await tester.startGesture(tester.getCenter(zone));
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('漁獲已上岸'), findsOneWidget);
    await tester.tap(find.byKey(const Key('street-scrap-claim-fish')));
    await tester.pumpAndSettle();
    final inventory = catalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(
        session.snapshot.state['inventory']! as Map,
      ),
    );
    expect(inventory.objects.values.single.itemId, 'fish.raw');
    expect(playedCues, contains(StreetScrapAudioCue.success));
    expect(playedCues, contains(StreetScrapAudioCue.pickup));
    expect(session.snapshot.state['stamina'], 9);
    await session.close();
  });
}
