import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_inventory.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

class _MemoryProgressStore implements StreetScrapProgressStore {
  final Map<String, Map<String, Object?>> values = {};
  final Map<String, List<Map<String, Object?>>> history = {};
  bool rejectNextWrite = false;

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => values[slotKey];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    final current = values[slotKey];
    final currentRevision = current?['revision'] as int?;
    if (currentRevision != expectedRevision || rejectNextWrite) {
      rejectNextWrite = false;
      return false;
    }
    if (current != null) {
      history.putIfAbsent(slotKey, () => []).add(current);
    }
    values[slotKey] = nextSnapshot;
    return true;
  }
}

class _DelayedWriterLeaseStore
    implements StreetScrapProgressStore, StreetScrapWriterLeaseStore {
  final Map<String, Map<String, Object?>> values = {};
  final Completer<void> releaseStarted = Completer<void>();
  final Completer<void> allowRelease = Completer<void>();
  int acquisitions = 0;

  @override
  Future<Map<String, Object?>?> read(String slotKey) async => values[slotKey];

  @override
  Future<bool> compareAndSwap({
    required String slotKey,
    required int? expectedRevision,
    required Map<String, Object?> nextSnapshot,
  }) async {
    values[slotKey] = nextSnapshot;
    return true;
  }

  @override
  Future<StreetScrapWriterLease?> acquireWriterLease(String slotKey) async {
    acquisitions++;
    if (acquisitions == 1) return _DelayedWriterLease(this);
    return _ImmediateWriterLease();
  }
}

class _DelayedWriterLease implements StreetScrapWriterLease {
  _DelayedWriterLease(this.store);

  final _DelayedWriterLeaseStore store;

  @override
  Future<void> release() async {
    if (!store.releaseStarted.isCompleted) store.releaseStarted.complete();
    await store.allowRelease.future;
  }
}

class _ImmediateWriterLease implements StreetScrapWriterLease {
  @override
  Future<void> release() async {}
}

void main() {
  final now = DateTime.utc(2026, 10, 22, 1, 2, 3);
  var sessionNumber = 0;

  StreetScrapSession createSession(
    _MemoryProgressStore store, {
    String? profileScope,
  }) => StreetScrapSession(
    profileScope: profileScope ?? 'player-${sessionNumber++}',
    store: store,
    contentVersions: const {'game.street-scrap.content.chapters-0-4': '0.1.0'},
    rulesetVersion: 1,
    clock: () => now,
  );

  test('profile save key does not contain the raw profile identifier', () {
    final session = createSession(
      _MemoryProgressStore(),
      profileScope: 'player@example.invalid',
    );
    expect(session.slotKey, startsWith('game.street-scrap/'));
    expect(session.slotKey, isNot(contains('player@example.invalid')));
    expect(session.slotKey, endsWith('/slot-1'));
  });

  test(
    'saves checksummed immutable state and restores the same revision',
    () async {
      final store = _MemoryProgressStore();
      final session = createSession(store, profileScope: 'save-test');
      await session.load();
      await session.apply(
        commandId: 'cmd-1',
        expectedRevision: 0,
        reduce: (state) => StreetScrapReduction(
          state: {
            'chapter': 0,
            'bagContents': ['rag'],
          },
          result: 'accepted',
        ),
      );

      expect(session.snapshot.revision, 1);
      expect(
        () => session.snapshot.state['chapter'] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => session.snapshot.state['bagContents'] = [],
        throwsUnsupportedError,
      );
      expect(() => session.snapshot.toJson()['revision'] = 99, returnsNormally);

      final restored = createSession(store, profileScope: 'save-test');
      await restored.load();
      expect(restored.snapshot.revision, 1);
      expect(restored.snapshot.state['chapter'], 0);
      expect(restored.snapshot.commandReceipts['cmd-1']!['result'], 'accepted');
    },
  );

  test('migrates the legacy q2.03 choice out of boolean task flags', () async {
    final store = _MemoryProgressStore();
    final session = createSession(store, profileScope: 'legacy-fish-choice');
    final legacy = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.0',
      },
      revision: 7,
      savedAt: now,
      state: const {
        'chapter': 3,
        'tutorialTasks': {'q2.02': true, 'q2.03': true, 'q2.03Choice': 'keep'},
      },
      commandReceipts: const {},
    );
    store.values[session.slotKey] = legacy.toJson();

    await session.load();

    expect(session.snapshot.revision, 7);
    expect(session.snapshot.state['q2.03Choice'], 'keep');
    expect(session.snapshot.state['tutorialTasks'], {
      'q2.02': true,
      'q2.03': true,
    });
    expect(
      (session.snapshot.state['tutorialTasks']! as Map).values,
      everyElement(isA<bool>()),
    );
    await session.close();
  });

  test(
    'replayed command returns its receipt without applying reducer again',
    () async {
      final session = createSession(_MemoryProgressStore());
      await session.load();
      var reductions = 0;
      StreetScrapReduction reduce(Map<String, Object?> state) {
        reductions++;
        return StreetScrapReduction(state: {'count': 1}, result: 'one');
      }

      await session.apply(
        commandId: 'stable-id',
        expectedRevision: 0,
        reduce: reduce,
      );
      final replay = await session.apply(
        commandId: 'stable-id',
        expectedRevision: 0,
        reduce: reduce,
      );

      expect(replay.wasDuplicate, isTrue);
      expect(replay.revision, 1);
      expect(replay.result, 'one');
      expect(reductions, 1);
    },
  );

  test(
    'first-acquired inventory items persist in the local collection',
    () async {
      final session = createSession(_MemoryProgressStore());
      await session.load();
      await session.apply(
        commandId: 'discover-materials',
        expectedRevision: 0,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'inventory': {
              'objects': [
                {
                  'instanceId': 'bottle-1',
                  'itemId': 'container.bottle',
                  'containerContents': [
                    {'instanceId': 'water-1', 'itemId': 'water.muddy'},
                  ],
                },
                {'instanceId': 'wood-1', 'itemId': 'wood.chip'},
              ],
            },
          },
        ),
      );
      expect(session.snapshot.state['collectionItemIds'], [
        'container.bottle',
        'water.muddy',
        'wood.chip',
      ]);

      await session.apply(
        commandId: 'consume-wood',
        expectedRevision: 1,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'inventory': {
              'objects': [
                {
                  'instanceId': 'bottle-1',
                  'itemId': 'container.bottle',
                  'containerContents': [],
                },
              ],
            },
          },
        ),
      );
      expect(session.snapshot.state['collectionItemIds'], [
        'container.bottle',
        'water.muddy',
        'wood.chip',
      ]);
      await session.close();
    },
  );

  test(
    'a second session for the same profile is read-only until ownership is released',
    () async {
      final store = _MemoryProgressStore();
      final first = createSession(store, profileScope: 'single-writer');
      final second = createSession(store, profileScope: 'single-writer');
      await first.load();
      await second.load();

      expect(first.isReadOnly, isFalse);
      expect(second.isReadOnly, isTrue);
      await expectLater(
        second.apply(
          commandId: 'blocked-write',
          expectedRevision: 0,
          reduce: (_) => const StreetScrapReduction(state: {'value': 1}),
        ),
        throwsA(isA<StreetScrapReadOnlySession>()),
      );

      await first.close();
      await second.load();
      expect(second.isReadOnly, isFalse);
      await second.close();
    },
  );

  test(
    'a session reopening during route teardown waits for the old lease',
    () async {
      final store = _DelayedWriterLeaseStore();
      final first = StreetScrapSession(
        profileScope: 'route-reopen-race',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
        clock: () => now,
      );
      final reopened = StreetScrapSession(
        profileScope: 'route-reopen-race',
        store: store,
        contentVersions: const {},
        rulesetVersion: 1,
        clock: () => now,
      );
      await first.load();

      final closing = first.close();
      await store.releaseStarted.future;
      var reopenedLoadCompleted = false;
      final loading = reopened.load().then((_) {
        reopenedLoadCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(reopenedLoadCompleted, isFalse);

      store.allowRelease.complete();
      await closing;
      await loading;
      expect(reopened.isReadOnly, isFalse);
      expect(store.acquisitions, 2);
      await reopened.close();
    },
  );

  test(
    'stale revisions and failed compare-and-swap never mutate local state',
    () async {
      final store = _MemoryProgressStore();
      final session = createSession(store);
      await session.load();
      store.rejectNextWrite = true;

      await expectLater(
        session.apply(
          commandId: 'racing-command',
          expectedRevision: 0,
          reduce: (_) => const StreetScrapReduction(state: {'value': 1}),
        ),
        throwsA(isA<StreetScrapConcurrentWrite>()),
      );
      expect(session.snapshot.revision, 0);
      await expectLater(
        session.apply(
          commandId: 'stale-command',
          expectedRevision: 3,
          reduce: (_) => const StreetScrapReduction(state: {'value': 2}),
        ),
        throwsA(isA<StreetScrapStaleRevision>()),
      );
      expect(session.snapshot.revision, 0);
    },
  );

  test(
    'inventory commands persist through revision CAS and replay receipts',
    () async {
      final store = _MemoryProgressStore();
      final session = createSession(store, profileScope: 'inventory-save');
      await session.load();
      const grid = StreetScrapGridSpec(id: 'board', width: 4, height: 4);
      final catalog = StreetScrapInventoryCatalog(
        footprints: const {'wood.chip': StreetScrapFootprint(1, 1)},
        packingRules: const {},
      );
      final initial = StreetScrapInventory(
        catalog: catalog,
        grids: const {'board': grid},
        objects: {
          'chip-1': catalog.createObject(
            instanceId: 'chip-1',
            itemId: 'wood.chip',
            source: 'street-find',
            quality: 67,
            traits: const {'wear': 1},
          ),
        },
        placements: const {},
        storage: const {},
      );
      final result = await session.applyInventoryCommand(
        commandId: 'place-chip',
        expectedRevision: 0,
        catalog: catalog,
        grids: const {'board': grid},
        initialInventory: initial,
        result: 'placed',
        reduceInventory: (inventory) =>
            inventory.placeFirstFit('chip-1', 'board'),
      );
      expect(result.revision, 1);
      final replay = await session.applyInventoryCommand(
        commandId: 'place-chip',
        expectedRevision: 0,
        catalog: catalog,
        grids: const {'board': grid},
        reduceInventory: (_) =>
            throw StateError('duplicate command must not run'),
      );
      expect(replay.wasDuplicate, isTrue);
      expect(replay.result, 'placed');

      final reopened = createSession(store, profileScope: 'inventory-save');
      await reopened.load();
      final saved = catalog.inventoryFromJson(
        grids: const {'board': grid},
        json: Map<String, Object?>.from(
          reopened.snapshot.state['inventory']! as Map,
        ),
      );
      expect(saved.placements['chip-1']!.gridId, 'board');
      expect(saved.objects['chip-1']!.source, 'street-find');
      await session.close();
      await reopened.close();
    },
  );

  test('damaged snapshots and unsupported rulesets fail closed', () async {
    final store = _MemoryProgressStore();
    const profileScope = 'damaged-test';
    final original = createSession(store, profileScope: profileScope);
    await original.load();
    await original.apply(
      commandId: 'save',
      expectedRevision: 0,
      reduce: (_) => const StreetScrapReduction(state: {'chapter': 1}),
    );
    final damaged = Map<String, Object?>.from(store.values[original.slotKey]!);
    damaged['revision'] = 7;
    store.values[original.slotKey] = damaged;
    await expectLater(
      createSession(store, profileScope: profileScope).load(),
      throwsFormatException,
    );

    store.values[original.slotKey] = StreetScrapProgressSnapshot.create(
      rulesetVersion: 2,
      contentVersions: original.snapshot.contentVersions,
      revision: original.snapshot.revision,
      savedAt: now,
      state: original.snapshot.state,
      commandReceipts: original.snapshot.commandReceipts,
    ).toJson();
    await expectLater(
      createSession(store, profileScope: profileScope).load(),
      throwsFormatException,
    );
  });

  test(
    'save transfer is checksummed and round trips the versioned snapshot',
    () {
      final snapshot = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.0',
        },
        revision: 4,
        savedAt: now,
        state: const {'chapter': 2, 'stamina': 31},
        commandReceipts: const {
          'source-command': {'revision': 4, 'result': 'saved'},
        },
      );
      final bytes = StreetScrapSaveTransfer.fromSnapshot(
        snapshot,
      ).encodeBytes();
      final restored = StreetScrapSaveTransfer.decodeBytes(bytes).snapshot;

      expect(restored.revision, 4);
      expect(restored.state, snapshot.state);
      expect(restored.commandReceipts, snapshot.commandReceipts);
      final corrupted = List<int>.of(bytes)..[20] ^= 1;
      expect(
        () => StreetScrapSaveTransfer.decodeBytes(corrupted),
        throwsFormatException,
      );
      expect(
        () => StreetScrapSaveTransfer.decodeBytes(
          List<int>.filled(streetScrapTransferMaximumBytes + 1, 0),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'import writes a new local revision and retains the previous snapshot',
    () async {
      final store = _MemoryProgressStore();
      final session = createSession(store, profileScope: 'transfer-target');
      await session.load();
      await session.apply(
        commandId: 'target-before-import',
        expectedRevision: 0,
        reduce: (_) =>
            const StreetScrapReduction(state: {'chapter': 0, 'stamina': 20}),
      );
      final previousSnapshot = Map<String, Object?>.from(
        store.values[session.slotKey]!,
      );
      final sourceSnapshot = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: session.contentVersions,
        revision: 14,
        savedAt: now.subtract(const Duration(days: 3)),
        state: const {'chapter': 2, 'stamina': 39},
        commandReceipts: const {
          'source-command': {'revision': 14, 'result': 'claimed'},
        },
      );
      var validated = false;

      await session.importTransfer(
        transfer: StreetScrapSaveTransfer.fromSnapshot(sourceSnapshot),
        validateState: (state) {
          expect(state['chapter'], 2);
          validated = true;
        },
      );

      expect(validated, isTrue);
      expect(session.snapshot.revision, 2);
      expect(session.snapshot.state, sourceSnapshot.state);
      expect(session.snapshot.commandReceipts, isEmpty);
      expect(store.history[session.slotKey]?.single, previousSnapshot);
      await session.close();
    },
  );

  test(
    'compatible patch content imports into the current resource version',
    () async {
      const baseContent = 'game.street-scrap.content.chapters-0-4';
      const chapter5Content = 'game.street-scrap.content.chapter-5';
      final store = _MemoryProgressStore();
      final session = StreetScrapSession(
        profileScope: 'compatible-patch-transfer',
        store: store,
        contentVersions: const {
          baseContent: '0.1.31',
          chapter5Content: '0.1.23',
          'game.street-scrap.content.active': '0.1.31+0.1.23',
        },
        compatibleContentVersions: const {
          baseContent: {'0.1.30'},
        },
        rulesetVersion: 1,
        clock: () => now,
      );
      await session.load();
      final source = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {
          baseContent: '0.1.30',
          chapter5Content: '0.1.23',
          'game.street-scrap.content.active': '0.1.30+0.1.23',
        },
        revision: 126,
        savedAt: now.subtract(const Duration(minutes: 1)),
        state: const {'chapter': 5, 'stamina': 38},
        commandReceipts: const {},
      );

      await session.importTransfer(
        transfer: StreetScrapSaveTransfer.fromSnapshot(source),
        validateState: (state) => expect(state['chapter'], 5),
      );

      expect(session.snapshot.state, {'chapter': 5, 'stamina': 38});
      expect(session.snapshot.contentVersions[baseContent], '0.1.31');
      expect(session.snapshot.contentVersions[chapter5Content], '0.1.23');
      await session.close();
    },
  );

  test(
    'incompatible or invalid imports leave the current save unchanged',
    () async {
      final store = _MemoryProgressStore();
      final session = createSession(store, profileScope: 'transfer-reject');
      await session.load();
      await session.apply(
        commandId: 'target-before-reject',
        expectedRevision: 0,
        reduce: (_) =>
            const StreetScrapReduction(state: {'chapter': 1, 'stamina': 18}),
      );
      final before = session.snapshot.toJson();
      StreetScrapSaveTransfer source({
        int rulesetVersion = 1,
        String contentVersion = '0.1.0',
        int chapter = 2,
      }) => StreetScrapSaveTransfer.fromSnapshot(
        StreetScrapProgressSnapshot.create(
          rulesetVersion: rulesetVersion,
          contentVersions: {
            'game.street-scrap.content.chapters-0-4': contentVersion,
          },
          revision: 1,
          savedAt: now,
          state: {'chapter': chapter},
          commandReceipts: const {},
        ),
      );

      await expectLater(
        session.importTransfer(
          transfer: source(rulesetVersion: 2),
          validateState: (_) {},
        ),
        throwsFormatException,
      );
      await expectLater(
        session.importTransfer(
          transfer: source(contentVersion: '0.2.0'),
          validateState: (_) {},
        ),
        throwsFormatException,
      );
      await expectLater(
        session.importTransfer(
          transfer: source(chapter: 8),
          validateState: (_) {},
        ),
        throwsFormatException,
      );
      await expectLater(
        session.importTransfer(
          transfer: source(),
          validateState: (_) => throw const FormatException('invalid state'),
        ),
        throwsFormatException,
      );
      expect(session.snapshot.toJson(), before);
      expect(store.history[session.slotKey] ?? [], isEmpty);
      await session.close();
    },
  );
}
