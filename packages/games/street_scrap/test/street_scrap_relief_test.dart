import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_relief.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_relief_panel.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_localizations.dart';

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

void main() {
  final created = DateTime.utc(2026, 1, 1);

  test('fourteen offline days preserve visible and reserve relief claims', () {
    final progress = StreetScrapReliefProgress.start(
      created,
    ).accrue(created.add(const Duration(days: 14)));
    expect(progress.totalClaims, 15);
    expect(progress.visibleClaims, 7);
    expect(progress.reserveClaims, 8);
    expect(
      StreetScrapReliefProgress.fromJson(progress.toJson()).totalClaims,
      15,
    );
  });

  test('claim spends one existing right and does not erase reserve claims', () {
    final progress = StreetScrapReliefProgress.start(
      created,
    ).accrue(created.add(const Duration(days: 14))).claim();
    expect(progress.totalClaims, 14);
    expect(progress.visibleClaims, 7);
    expect(progress.reserveClaims, 7);
  });

  test(
    'clock rollback holds the high-water mark and grants no duplicate day',
    () {
      final fourteenDays = StreetScrapReliefProgress.start(
        created,
      ).accrue(created.add(const Duration(days: 14)));
      final rolledBack = fourteenDays.accrue(
        created.add(const Duration(days: 7)),
      );
      expect(rolledBack.totalClaims, 15);
      expect(rolledBack.highWater, created.add(const Duration(days: 14)));
      expect(rolledBack.clockRollbackEvents, 1);
      expect(
        rolledBack
            .accrue(created.add(const Duration(days: 8)))
            .clockRollbackEvents,
        1,
      );
      final afterRecovery = rolledBack.accrue(
        created.add(const Duration(days: 15)),
      );
      expect(afterRecovery.totalClaims, 16);
      expect(afterRecovery.clockRollbackActive, isFalse);
      expect(
        afterRecovery
            .accrue(created.add(const Duration(days: 10)))
            .clockRollbackEvents,
        2,
      );
    },
  );

  test('partial time is retained and malformed saves fail closed', () {
    final halfway = StreetScrapReliefProgress.start(
      created,
    ).accrue(created.add(const Duration(hours: 23)));
    expect(halfway.totalClaims, 1);
    final completed = halfway.accrue(created.add(const Duration(days: 1)));
    expect(completed.totalClaims, 2);
    expect(
      () => StreetScrapReliefProgress.fromJson({'totalClaims': -1}),
      throwsFormatException,
    );
  });

  test(
    'persisted relief claim catches up offline and is receipt-idempotent',
    () async {
      final session = StreetScrapSession(
        profileScope: 'relief-claim',
        store: _Store(),
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.21',
        },
        rulesetVersion: 1,
        clock: () => created,
      );
      await session.load();
      await session.apply(
        commandId: 'set-low-stamina',
        expectedRevision: 0,
        reduce: (state) =>
            StreetScrapReduction(state: {...state, 'stamina': 10}),
      );
      final first = await claimStreetScrapRelief(
        session: session,
        commandId: 'claim-relief',
        expectedRevision: 1,
        now: created.add(const Duration(days: 14)),
        maxStamina: 60,
      );
      expect((first.result! as Map)['actualRestored'], 40);
      expect(session.snapshot.state['stamina'], 50);
      final relief = StreetScrapReliefProgress.fromJson(
        Map<String, Object?>.from(session.snapshot.state['relief']! as Map),
      );
      expect(relief.totalClaims, 14);
      expect(relief.visibleClaims, 7);
      expect(relief.reserveClaims, 7);
      final duplicate = await claimStreetScrapRelief(
        session: session,
        commandId: 'claim-relief',
        expectedRevision: 1,
        now: created.add(const Duration(days: 30)),
        maxStamina: 60,
      );
      expect((duplicate.result! as Map)['actualRestored'], 40);
      expect(session.snapshot.state['stamina'], 50);
      await session.close();
    },
  );

  testWidgets('relief panel displays and atomically claims the initial meal', (
    tester,
  ) async {
    final session = StreetScrapSession(
      profileScope: 'relief-panel',
      store: _Store(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.21',
      },
      rulesetVersion: 1,
    );
    await session.load();
    await session.apply(
      commandId: 'panel-stamina',
      expectedRevision: 0,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'stamina': 10,
          'relief': StreetScrapReliefProgress.start(
            session.snapshot.savedAt,
          ).toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetScrapReliefPanel(
            session: session,
            maxStamina: 60,
            onChanged: () {},
          ),
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('street-scrap-relief-summary')))
          .label,
      contains('可領 1 份'),
    );
    expect(
      find.byKey(const Key('street-scrap-relief-metric-visible')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-relief-metric-restore')),
      findsOneWidget,
    );
    expect(find.textContaining('不要求每天登入'), findsNothing);
    await tester.tap(find.text('領用救助便當'));
    await tester.pumpAndSettle();
    expect(session.snapshot.state['stamina'], 50);
    expect(session.snapshot.state['relief'], isNotNull);
    await session.close();
  });

  testWidgets('relief and chapter supply panel follows the English locale', (
    tester,
  ) async {
    final session = StreetScrapSession(
      profileScope: 'relief-panel-english',
      store: _Store(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.21',
      },
      rulesetVersion: 1,
    );
    await session.load();
    await tester.pumpWidget(
      MaterialApp(
        home: StreetScrapLocalizationsScope(
          locale: 'en',
          child: Scaffold(
            body: StreetScrapReliefPanel(
              session: session,
              maxStamina: 60,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Government Relief'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('street-scrap-relief-summary')))
          .label,
      contains('No daily login is required'),
    );
    expect(find.text('Claim relief meal'), findsOneWidget);
    expect(find.text('政府救助'), findsNothing);
    await session.close();
  });

  testWidgets('relief graphic summary fits a narrow screen at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = StreetScrapSession(
      profileScope: 'relief-panel-compact-200',
      store: _Store(),
      contentVersions: const {},
      rulesetVersion: 1,
    );
    await session.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: StreetScrapLocalizationsScope(
            locale: 'zh-Hant',
            child: StreetScrapReliefPanel(
              session: session,
              maxStamina: 60,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('street-scrap-relief-metric-visible')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('street-scrap-relief-metric-interval')),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.byKey(const Key('street-scrap-relief-summary')))
          .right,
      lessThanOrEqualTo(320),
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('q5.02 shutdown requires confirmation and grants supply once', (
    tester,
  ) async {
    final now = DateTime.now();
    final session = StreetScrapSession(
      profileScope: 'relief-transition-panel',
      store: _Store(),
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.21',
      },
      rulesetVersion: 1,
      clock: () => now,
    );
    await session.load();
    await session.apply(
      commandId: 'prepare-relief-transition-panel',
      expectedRevision: 0,
      reduce: (state) => StreetScrapReduction(
        state: {
          ...state,
          'chapter': 5,
          'tutorialTasks': {'q5.02': true},
          'stamina': 10,
          'relief': StreetScrapReliefProgress.start(now).toJson(),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetScrapReliefPanel(
            session: session,
            maxStamina: 60,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const Key('street-scrap-finish-relief-transition')),
    );
    await tester.pumpAndSettle();
    expect(find.text('停止新增政府救助？'), findsOneWidget);
    expect(
      session.snapshot.state['reliefStopWarningAcknowledged'],
      isNot(true),
    );
    await tester.tap(find.text('暫不停止'));
    await tester.pumpAndSettle();
    expect(
      session.snapshot.state['reliefTransitionSupplyGranted'],
      isNot(true),
    );

    await tester.tap(
      find.byKey(const Key('street-scrap-finish-relief-transition')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('street-scrap-confirm-relief-stop')));
    await tester.pumpAndSettle();
    expect(session.snapshot.state['reliefStopWarningAcknowledged'], isTrue);
    expect(session.snapshot.state['reliefTransitionSupplyGranted'], isTrue);
    expect(session.snapshot.state['chapterSupplyBalance'], 80);
    final relief = StreetScrapReliefProgress.fromJson(
      Map<String, Object?>.from(session.snapshot.state['relief']! as Map),
    );
    expect(relief.ended, isTrue);
    await session.close();
  });

  test(
    'q5.02 warning gates one-time relief shutdown and 80-point supply',
    () async {
      final session = StreetScrapSession(
        profileScope: 'relief-transition',
        store: _Store(),
        contentVersions: const {
          'game.street-scrap.content.chapters-0-4': '0.1.21',
        },
        rulesetVersion: 1,
        clock: () => created,
      );
      await session.load();
      await session.apply(
        commandId: 'prepare-relief-transition',
        expectedRevision: 0,
        reduce: (state) => StreetScrapReduction(
          state: {
            ...state,
            'chapter': 5,
            'tutorialTasks': {'q5.02': true},
            'stamina': 10,
            'relief': StreetScrapReliefProgress.start(created).toJson(),
          },
        ),
      );
      await expectLater(
        finishStreetScrapRelief(
          session: session,
          commandId: 'finish-without-warning',
          expectedRevision: 1,
          now: created.add(const Duration(days: 14)),
        ),
        throwsStateError,
      );
      await acknowledgeStreetScrapReliefStop(
        session: session,
        commandId: 'acknowledge-relief-stop-warning',
        expectedRevision: 1,
      );
      final finish = await finishStreetScrapRelief(
        session: session,
        commandId: 'finish-relief-once',
        expectedRevision: 2,
        now: created.add(const Duration(days: 14)),
      );
      expect((finish.result! as Map)['reliefClaims'], 15);
      expect(session.snapshot.state['chapterSupplyBalance'], 80);
      final progress = StreetScrapReliefProgress.fromJson(
        Map<String, Object?>.from(session.snapshot.state['relief']! as Map),
      );
      expect(progress.ended, isTrue);
      expect(
        progress.accrue(created.add(const Duration(days: 40))).totalClaims,
        15,
      );
      await expectLater(
        finishStreetScrapRelief(
          session: session,
          commandId: 'finish-relief-twice',
          expectedRevision: session.snapshot.revision,
          now: created.add(const Duration(days: 40)),
        ),
        throwsStateError,
      );
      final retainedMeal = await claimStreetScrapRelief(
        session: session,
        commandId: 'use-reserved-relief-after-stop',
        expectedRevision: session.snapshot.revision,
        now: created.add(const Duration(days: 40)),
        maxStamina: 60,
      );
      expect((retainedMeal.result! as Map)['actualRestored'], 40);
      expect(
        StreetScrapReliefProgress.fromJson(
          Map<String, Object?>.from(session.snapshot.state['relief']! as Map),
        ).totalClaims,
        14,
      );
      final firstSupplyClaim = await claimStreetScrapChapterSupply(
        session: session,
        commandId: 'claim-transition-supply-one',
        expectedRevision: session.snapshot.revision,
        maxStamina: 60,
      );
      expect((firstSupplyClaim.result! as Map)['actualRestored'], 10);
      expect(session.snapshot.state['stamina'], 60);
      expect(session.snapshot.state['chapterSupplyBalance'], 70);
      await session.close();
    },
  );
}
